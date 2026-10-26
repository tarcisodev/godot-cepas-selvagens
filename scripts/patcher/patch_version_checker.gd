class_name PatchVersionChecker
extends Node

## Verifica atualizações remotas via GitHub Releases ou manifesto customizado.
## Detecta se há nova versão disponível, priorizando assets .pck para patching in-game,
## ou sinalizando se uma atualização principal (binário) está disponível.

signal check_completed(info: Dictionary)
signal check_failed(error_message: String)

enum Phase {
	IDLE,
	FETCHING_RELEASES_OR_MANIFEST,
	FETCHING_RELEASE_MANIFEST
}

var _http: HTTPRequest
var _phase: Phase = Phase.IDLE
var _current_version: String = "0.1.0"
var _pending_release: Dictionary = {}
var _pending_pck_asset: Dictionary = {}

func _ready() -> void:
	_http = HTTPRequest.new()
	_http.use_threads = true
	_http.timeout = 10.0
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)

## Inicia checagem de atualizações
func check_for_updates(current_version: String, github_repo: String = "tarcisodev/godot-cepas-selvagens", custom_manifest_url: String = "") -> void:
	_current_version = clean_version(current_version)
	var url: String = custom_manifest_url.strip_edges()
	var headers: PackedStringArray = PackedStringArray([
		"User-Agent: CepaSelvagemGame/1.0",
		"Accept: application/vnd.github.v3+json"
	])
	
	if url.is_empty():
		url = "https://api.github.com/repos/%s/releases?per_page=10" % github_repo
	
	_phase = Phase.FETCHING_RELEASES_OR_MANIFEST
	var err := _http.request(url, headers)
	if err != OK:
		_phase = Phase.IDLE
		check_failed.emit("Falha ao iniciar requisição HTTP (código: %d)" % err)

func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		_phase = Phase.IDLE
		check_failed.emit("Erro de rede ao buscar atualizações (código: %d)" % result)
		return
	
	if response_code == 403:
		_phase = Phase.IDLE
		check_failed.emit("Limite de requisições do GitHub atingido (HTTP 403).")
		return
	elif response_code == 404:
		_phase = Phase.IDLE
		check_failed.emit("Nenhuma release encontrada no repositório (HTTP 404).")
		return
	elif response_code < 200 or response_code >= 300:
		_phase = Phase.IDLE
		check_failed.emit("Servidor retornou HTTP %d." % response_code)
		return
	
	var text := body.get_string_from_utf8()
	var json := JSON.new()
	if json.parse(text) != OK:
		_phase = Phase.IDLE
		check_failed.emit("Resposta em formato JSON inválido.")
		return
	
	# Fase 2: Recebimento de manifest.json específico
	if _phase == Phase.FETCHING_RELEASE_MANIFEST:
		_phase = Phase.IDLE
		if not (json.data is Dictionary):
			check_failed.emit("Manifesto manifest.json em formato inválido.")
			return
		
		var mdata: Dictionary = json.data
		var sha: String = str(mdata.get("sha256", "")).strip_edges().to_lower()
		var pck_name: String = str(mdata.get("pck_file", _pending_pck_asset.get("name", "")))
		var pck_url: String = str(_pending_pck_asset.get("browser_download_url", ""))
		
		var final_info := {
			"has_update": true,
			"is_pck": not pck_url.is_empty(),
			"version": clean_version(str(mdata.get("version", _pending_release.get("tag_name", "")))),
			"title": str(_pending_release.get("name", "Versão " + _pending_release.get("tag_name", ""))),
			"changelog": str(_pending_release.get("body", "Sem notas.")),
			"download_url": pck_url,
			"asset_name": pck_name,
			"size_bytes": int(mdata.get("size", _pending_pck_asset.get("size", 0))),
			"sha256": sha,
			"is_major_update": pck_url.is_empty()
		}
		check_completed.emit(final_info)
		return
	
	# Fase 1: Resposta de /releases
	if json.data is Array:
		var releases: Array = json.data
		var candidate: Dictionary = find_latest_release(releases)
		if candidate.is_empty():
			_phase = Phase.IDLE
			check_completed.emit({"has_update": false, "version": _current_version})
			return
		
		var remote_ver: String = candidate["version"]
		if compare_versions(remote_ver, _current_version) <= 0:
			_phase = Phase.IDLE
			check_completed.emit({
				"has_update": false,
				"version": _current_version,
				"latest_version": remote_ver
			})
			return
		
		_pending_release = candidate["release"]
		_pending_pck_asset = candidate.get("pck_asset", {})
		var manifest_asset: Dictionary = candidate.get("manifest_asset", {})
		
		# Se tiver manifest.json na release, baixa para checar SHA-256 e detalhes
		var manifest_url: String = str(manifest_asset.get("browser_download_url", "")).strip_edges()
		if not manifest_url.is_empty():
			_phase = Phase.FETCHING_RELEASE_MANIFEST
			var headers := PackedStringArray(["User-Agent: CepaSelvagemGame/1.0"])
			var m_err := _http.request(manifest_url, headers)
			if m_err != OK:
				_phase = Phase.IDLE
				# Prossegue mesmo se falhar o manifest com os dados brutos do asset
				_emit_candidate_directly(candidate)
			return
		
		_phase = Phase.IDLE
		_emit_candidate_directly(candidate)
		return
	
	elif json.data is Dictionary:
		_phase = Phase.IDLE
		var mdata: Dictionary = json.data
		var r_ver := clean_version(str(mdata.get("version", "0.0.0")))
		if compare_versions(r_ver, _current_version) > 0:
			check_completed.emit({
				"has_update": true,
				"is_pck": str(mdata.get("file", "")).ends_with(".pck"),
				"version": r_ver,
				"title": str(mdata.get("title", "Versão " + r_ver)),
				"changelog": str(mdata.get("changelog", "")),
				"download_url": str(mdata.get("download_url", "")),
				"asset_name": str(mdata.get("file", "")),
				"size_bytes": int(mdata.get("size", 0)),
				"sha256": str(mdata.get("sha256", "")).to_lower(),
				"is_major_update": not str(mdata.get("file", "")).ends_with(".pck")
			})
		else:
			check_completed.emit({"has_update": false, "version": _current_version})
	else:
		_phase = Phase.IDLE
		check_failed.emit("Formato de resposta inesperado.")

func _emit_candidate_directly(candidate: Dictionary) -> void:
	var pck_asset: Dictionary = candidate.get("pck_asset", {})
	var rel: Dictionary = candidate["release"]
	var has_pck: bool = not pck_asset.is_empty()
	
	check_completed.emit({
		"has_update": true,
		"is_pck": has_pck,
		"version": candidate["version"],
		"title": str(rel.get("name", "Versão " + candidate["version"])),
		"changelog": str(rel.get("body", "")),
		"download_url": str(pck_asset.get("browser_download_url", "")),
		"asset_name": str(pck_asset.get("name", "")),
		"size_bytes": int(pck_asset.get("size", 0)),
		"sha256": "",
		"is_major_update": not has_pck
	})

## Encontra a release mais recente com suporte a .pck ou zip
static func find_latest_release(releases: Array) -> Dictionary:
	var candidates: Array[Dictionary] = []
	for r in releases:
		if not (r is Dictionary):
			continue
		var rel: Dictionary = r
		if rel.get("draft", false) == true:
			continue
		
		var tag: String = clean_version(str(rel.get("tag_name", "")))
		if tag.is_empty():
			continue
		
		var assets: Array = rel.get("assets", [])
		var pck_asset: Dictionary = {}
		var manifest_asset: Dictionary = {}
		var zip_asset: Dictionary = {}
		
		for a in assets:
			if not (a is Dictionary):
				continue
			var asset_dict: Dictionary = a
			var aname: String = str(asset_dict.get("name", "")).strip_edges()
			if aname.ends_with(".pck"):
				pck_asset = asset_dict
			elif aname == "manifest.json":
				manifest_asset = asset_dict
			elif aname.ends_with(".zip"):
				zip_asset = asset_dict
		
		candidates.append({
			"version": tag,
			"release": rel,
			"pck_asset": pck_asset,
			"manifest_asset": manifest_asset,
			"zip_asset": zip_asset
		})
	
	if candidates.is_empty():
		return {}
	
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return compare_versions(a["version"], b["version"]) > 0
	)
	
	return candidates[0]

## Limpa prefixos 'v' e espaços da versão
static func clean_version(v: String) -> String:
	var s := v.strip_edges()
	if s.begins_with("v") or s.begins_with("V"):
		s = s.substr(1).strip_edges()
	return s

## Compara duas versões em formato semver
static func compare_versions(v1: String, v2: String) -> int:
	var clean1 := clean_version(v1)
	var clean2 := clean_version(v2)
	
	if clean1 == clean2:
		return 0
	
	var parts1 := clean1.split(".")
	var parts2 := clean2.split(".")
	var max_len := maxi(parts1.size(), parts2.size())
	
	for i in range(max_len):
		var n1 := parts1[i].to_int() if i < parts1.size() and parts1[i].is_valid_int() else 0
		var n2 := parts2[i].to_int() if i < parts2.size() and parts2[i].is_valid_int() else 0
		
		if n1 > n2:
			return 1
		elif n1 < n2:
			return -1
	
	return 0
