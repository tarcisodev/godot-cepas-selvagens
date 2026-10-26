class_name VersionChecker
extends Node

## Verifica atualizações remotas via GitHub Releases API ou manifesto customizado.

signal check_completed(info: Dictionary)
signal check_failed(error_message: String)

var _http: HTTPRequest

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
		url = "https://api.github.com/repos/%s/releases/latest" % github_repo
	
	var err := _http.request(url, headers)
	if err != OK:
		check_failed.emit("Falha ao iniciar conexão HTTP (código: %d)" % err)

func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		check_failed.emit("Erro de rede ao buscar atualizações (código: %d)" % result)
		return
	
	if response_code == 404:
		check_failed.emit("Nenhuma versão de lançamento encontrada no repositório.")
		return
	elif response_code < 200 or response_code >= 300:
		check_failed.emit("Servidor de atualização retornou HTTP %d." % response_code)
		return
	
	var text := body.get_string_from_utf8()
	var json := JSON.new()
	if json.parse(text) != OK or not (json.data is Dictionary):
		check_failed.emit("Resposta de atualização em formato JSON inválido.")
		return
	
	var data: Dictionary = json.data
	var parsed := parse_release_data(data)
	if parsed.is_empty():
		check_failed.emit("Formato de release desconhecido ou nenhum arquivo compatível anexado.")
		return
	
	check_completed.emit(parsed)

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
	if data.has("version") and data.has("download_url"):
		result["version"] = clean_version(str(data["version"]))
		result["title"] = str(data.get("title", "Versão " + result["version"]))
		result["changelog"] = str(data.get("changelog", ""))
		result["download_url"] = str(data["download_url"])
		result["sha256"] = str(data.get("sha256", ""))
		result["size_bytes"] = int(data.get("size_bytes", 0))
		result["release_date"] = str(data.get("release_date", ""))
		result["asset_name"] = result["download_url"].get_file()
		result["is_zip"] = result["download_url"].ends_with(".zip")
		return result
	
	# Caso 2: GitHub Releases API
	if data.has("tag_name"):
		result["version"] = clean_version(str(data["tag_name"]))
		result["title"] = str(data.get("name", "Release " + result["version"]))
		result["changelog"] = str(data.get("body", "Sem notas de atualização."))
		result["release_date"] = str(data.get("published_at", ""))
		
		var assets: Array = data.get("assets", [])
		var chosen_asset: Dictionary = {}
		
		# Procura primeiro por zip de windows ou CepaSelvagem
		for a in assets:
			if not (a is Dictionary):
				continue
			var aname: String = str(a.get("name", "")).to_lower()
			if aname.ends_with(".zip") and ("windows" in aname or "cepa" in aname):
				chosen_asset = a
				break
		
		# Fallback: qualquer .zip nos assets
		if chosen_asset.is_empty():
			for a in assets:
				if not (a is Dictionary):
					continue
				var aname: String = str(a.get("name", "")).to_lower()
				if aname.ends_with(".zip"):
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
