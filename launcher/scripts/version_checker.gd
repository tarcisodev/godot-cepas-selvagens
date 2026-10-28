class_name VersionChecker
extends Node

## Verifica atualizações remotas via GitHub Releases API (/releases?per_page=10) ou manifesto customizado.
## Seleciona exclusivamente o pacote oficial CepaSelvagem-<versao>-windows.zip e manifest.json.

signal check_completed(info: Dictionary)
signal check_failed(error_message: String)

enum Phase {
	IDLE,
	FETCHING_RELEASES_OR_MANIFEST,
	FETCHING_RELEASE_MANIFEST
}

var _http: HTTPRequest
var _phase: Phase = Phase.IDLE
var _pending_release: Dictionary = {}
var _pending_zip_asset: Dictionary = {}

func _ready() -> void:
	_http = HTTPRequest.new()
	_http.use_threads = true
	_http.timeout = 10.0
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)

## Inicia a verificação de versão
func check_for_updates(github_repo: String, custom_manifest_url: String = "") -> void:
	var url: String = custom_manifest_url.strip_edges()
	var headers: PackedStringArray = PackedStringArray([
		"User-Agent: CepasSelvagensLauncher/1.0",
		"Accept: application/vnd.github.v3+json"
	])
	
	if url.is_empty():
		# Consulta até 10 releases recentes (aceita pré-releases e releases normais ordenadas por semver)
		url = "https://api.github.com/repos/%s/releases?per_page=10" % github_repo
		_phase = Phase.FETCHING_RELEASES_OR_MANIFEST
	else:
		_phase = Phase.FETCHING_RELEASES_OR_MANIFEST
	
	var err := _http.request(url, headers)
	if err != OK:
		_phase = Phase.IDLE
		check_failed.emit("Falha ao iniciar conexão HTTP (código: %d)" % err)

func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		_phase = Phase.IDLE
		check_failed.emit("Erro de rede ao buscar atualizações (código: %d)" % result)
		return
	
	if response_code == 403:
		_phase = Phase.IDLE
		check_failed.emit("Limite de requisições da API do GitHub atingido (HTTP 403). Você pode jogar a versão instalada.")
		return
	elif response_code == 404:
		_phase = Phase.IDLE
		check_failed.emit("Nenhuma versão de lançamento encontrada no repositório (HTTP 404).")
		return
	elif response_code < 200 or response_code >= 300:
		_phase = Phase.IDLE
		check_failed.emit("Servidor de atualização retornou HTTP %d." % response_code)
		return
	
	var text := body.get_string_from_utf8()
	var json := JSON.new()
	var parse_err := json.parse(text)
	if parse_err != OK:
		_phase = Phase.IDLE
		check_failed.emit("Resposta de atualização em formato JSON inválido.")
		return
	
	# Fase 2: Recebimento do manifest.json da release selecionada
	if _phase == Phase.FETCHING_RELEASE_MANIFEST:
		_phase = Phase.IDLE
		if not (json.data is Dictionary):
			check_failed.emit("Manifesto manifest.json em formato inválido.")
			return
		
		var mdata: Dictionary = json.data
		var sha: String = str(mdata.get("sha256", "")).strip_edges().to_lower()
		if sha.is_empty():
			check_failed.emit("Manifesto de release rejeitado: hash SHA-256 ausente.")
			return
		
		var final_info := {
			"version": clean_version(str(mdata.get("version", _pending_release.get("tag_name", "0.0.0")))),
			"title": str(_pending_release.get("name", "Versão " + _pending_release.get("tag_name", ""))),
			"changelog": str(_pending_release.get("body", "Sem notas de atualização.")),
			"download_url": str(_pending_zip_asset.get("browser_download_url", "")),
			"asset_name": str(_pending_zip_asset.get("name", "")),
			"size_bytes": int(mdata.get("size", _pending_zip_asset.get("size", 0))),
			"sha256": sha,
			"release_date": str(_pending_release.get("published_at", "")),
			"is_zip": true
		}
		
		check_completed.emit(final_info)
		return
	
	# Fase 1: Resposta de /releases?per_page=10 (Array) ou manifesto direto (Dictionary)
	if json.data is Array:
		var releases: Array = json.data
		var best_match: Dictionary = find_best_release(releases)
		if best_match.is_empty():
			_phase = Phase.IDLE
			check_failed.emit("Nenhuma release oficial com asset CepaSelvagem-<versao>-windows.zip e manifest.json encontrada.")
			return
		
		_pending_release = best_match["release"]
		_pending_zip_asset = best_match["zip_asset"]
		var manifest_asset: Dictionary = best_match.get("manifest_asset", {})
		
		var manifest_url: String = str(manifest_asset.get("browser_download_url", "")).strip_edges()
		if manifest_url.is_empty():
			_phase = Phase.IDLE
			check_failed.emit("Release não contém asset de manifesto (manifest.json).")
			return
		
		# Faz a requisição do manifest.json da mesma release
		_phase = Phase.FETCHING_RELEASE_MANIFEST
		var headers := PackedStringArray(["User-Agent: CepasSelvagensLauncher/1.0"])
		var m_err := _http.request(manifest_url, headers)
		if m_err != OK:
			_phase = Phase.IDLE
			check_failed.emit("Falha ao consultar manifest.json da release (código: %d)" % m_err)
		return
	
	elif json.data is Dictionary:
		_phase = Phase.IDLE
		var data: Dictionary = json.data
		var parsed := parse_release_data(data)
		if parsed.is_empty():
			check_failed.emit("Formato de release desconhecido ou nenhum arquivo compatível anexado.")
			return
		check_completed.emit(parsed)
	else:
		_phase = Phase.IDLE
		check_failed.emit("Resposta inesperada do servidor de versões.")

## Localiza a release mais recente por semver em uma lista de releases do GitHub
static func find_best_release(releases: Array) -> Dictionary:
	var best_release: Dictionary = {}
	var best_zip: Dictionary = {}
	var best_manifest: Dictionary = {}
	var best_version: String = ""
	
	for r in releases:
		if not (r is Dictionary):
			continue
		# Ignora releases marcadas como rascunho (draft)
		if bool(r.get("draft", false)):
			continue
		
		var tag: String = str(r.get("tag_name", "")).strip_edges()
		var ver: String = clean_version(tag)
		if ver.is_empty():
			continue
		
		var expected_zip_name: String = ("CepaSelvagem-%s-windows.zip" % ver).to_lower()
		var assets: Array = r.get("assets", [])
		var found_zip: Dictionary = {}
		var found_manifest: Dictionary = {}
		
		for a in assets:
			if not (a is Dictionary):
				continue
			var aname: String = str(a.get("name", "")).strip_edges().to_lower()
			if aname == expected_zip_name:
				found_zip = a
			elif aname == "manifest.json":
				found_manifest = a
		
		# Exige o asset com o nome exato da versão e o manifest.json
		if found_zip.is_empty() or found_manifest.is_empty():
			continue
		
		if best_version.is_empty() or compare_versions(best_version, ver) < 0:
			best_version = ver
			best_release = r
			best_zip = found_zip
			best_manifest = found_manifest
	
	if best_release.is_empty():
		return {}
	
	return {
		"release": best_release,
		"zip_asset": best_zip,
		"manifest_asset": best_manifest,
		"version": best_version
	}

## Converte JSON do GitHub ou Manifesto customizado em um dicionário padronizado
static func parse_release_data(data: Dictionary) -> Dictionary:
	var result := {
		"version": "0.0.0",
		"title": "",
		"changelog": "",
		"download_url": "",
		"asset_name": "",
		"size_bytes": 0,
		"sha256": "",
		"release_date": "",
		"is_zip": true
	}
	
	# Caso 1: Manifesto customizado direto
	if data.has("version") and (data.has("download_url") or data.has("file")):
		result["version"] = clean_version(str(data["version"]))
		result["title"] = str(data.get("title", "Versão " + result["version"]))
		result["changelog"] = str(data.get("changelog", ""))
		result["download_url"] = str(data.get("download_url", ""))
		result["sha256"] = str(data.get("sha256", "")).strip_edges().to_lower()
		result["size_bytes"] = int(data.get("size", data.get("size_bytes", 0)))
		result["release_date"] = str(data.get("release_date", ""))
		result["asset_name"] = str(data.get("file", result["download_url"].get_file()))
		result["is_zip"] = result["asset_name"].ends_with(".zip")
		return result
	
	# Caso 2: GitHub Releases API (Release individual)
	if data.has("tag_name"):
		var ver: String = clean_version(str(data["tag_name"]))
		result["version"] = ver
		result["title"] = str(data.get("name", "Release " + result["version"]))
		result["changelog"] = str(data.get("body", "Sem notas de atualização."))
		result["release_date"] = str(data.get("published_at", ""))
		result["sha256"] = str(data.get("sha256", "")).strip_edges().to_lower()
		
		var expected_zip_name: String = ("CepaSelvagem-%s-windows.zip" % ver).to_lower()
		var assets: Array = data.get("assets", [])
		var chosen_asset: Dictionary = {}
		
		for a in assets:
			if not (a is Dictionary):
				continue
			var aname: String = str(a.get("name", "")).strip_edges().to_lower()
			if aname == expected_zip_name:
				chosen_asset = a
				break
		
		if not chosen_asset.is_empty():
			result["download_url"] = str(chosen_asset.get("browser_download_url", ""))
			result["asset_name"] = str(chosen_asset.get("name", ""))
			result["size_bytes"] = int(chosen_asset.get("size", 0))
			result["is_zip"] = true
			return result
	
	return {}

## Limpa prefixo 'v' e sufixos
static func clean_version(v: String) -> String:
	var s := v.strip_edges()
	if s.begins_with("v") or s.begins_with("V"):
		s = s.substr(1)
	return s

## Compara duas versões semânticas (ex: "0.1.0" vs "0.2.0")
## Retorna: -1 se v1 < v2, 0 se v1 == v2, 1 se v1 > v2
static func compare_versions(v1: String, v2: String) -> int:
	var clean1 := clean_version(v1).split("-")[0]
	var clean2 := clean_version(v2).split("-")[0]
	
	var parts1 := clean1.split(".")
	var parts2 := clean2.split(".")
	
	var max_len: int = maxi(parts1.size(), parts2.size())
	for i in range(max_len):
		var num1: int = int(parts1[i]) if i < parts1.size() else 0
		var num2: int = int(parts2[i]) if i < parts2.size() else 0
		if num1 < num2:
			return -1
		elif num1 > num2:
			return 1
	
	return 0
