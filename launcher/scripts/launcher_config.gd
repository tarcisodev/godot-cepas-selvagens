class_name LauncherConfig
extends RefCounted

## Configurações e caminhos locais do Launcher de Cepas Selvagens.
## Garante integridade das URLs oficiais travando repo e manifesto em builds de produção.

const CONFIG_FILE: String = "user://launcher_settings.json"
const VERSION_FILE: String = "version.json"

const DEFAULT_GITHUB_REPO: String = "tarcisodev/godot-cepas-selvagens"
const DEFAULT_SERVER_HOST: String = "jogar.tarciso.dev"
const DEFAULT_SERVER_PORT: int = 8787
const DEFAULT_WEBSITE_URL: String = "https://cepas.tarciso.dev"
const DEFAULT_EXECUTABLE_NAME: String = "CepaSelvagem.exe"

var installed_version: String = "0.0.0"
var game_directory: String = "game"
var custom_manifest_url: String = ""
var github_repo: String = DEFAULT_GITHUB_REPO
var auto_play_on_ready: bool = false
var close_launcher_on_play: bool = true

func _init() -> void:
	load_settings()

func is_repo_locked() -> bool:
	return not OS.is_debug_build()

func get_settings_path() -> String:
	return CONFIG_FILE

func get_absolute_game_dir() -> String:
	if game_directory.is_absolute_path():
		return game_directory
	# Se for relativo, resolve a partir do diretório onde o executável do launcher está rodando
	var base_dir: String = OS.get_executable_path().get_base_dir()
	if OS.has_feature("editor"):
		# No editor, coloca o diretório "game" na pasta do launcher para testes
		base_dir = ProjectSettings.globalize_path("res://")
	return base_dir.path_join(game_directory)

func get_executable_path() -> String:
	return get_absolute_game_dir().path_join(DEFAULT_EXECUTABLE_NAME)

func get_local_version_file_path() -> String:
	return get_absolute_game_dir().path_join(VERSION_FILE)

func read_installed_version() -> String:
	var v_path: String = get_local_version_file_path()
	if not FileAccess.file_exists(v_path):
		# Se não existe version.json, mas existe o executável, assume 0.0.0 não versionado
		return "0.0.0" if not FileAccess.file_exists(get_executable_path()) else "0.1.0"
	
	var file := FileAccess.open(v_path, FileAccess.READ)
	if not file:
		return "0.0.0"
	
	var text := file.get_as_text().strip_edges()
	file.close()
	
	var json := JSON.new()
	if json.parse(text) == OK and json.data is Dictionary:
		var d: Dictionary = json.data
		installed_version = str(d.get("version", "0.0.0"))
	else:
		installed_version = text
	
	return installed_version

func write_installed_version(new_version: String) -> void:
	installed_version = new_version
	var target_dir := get_absolute_game_dir()
	if not DirAccess.dir_exists_absolute(target_dir):
		DirAccess.make_dir_recursive_absolute(target_dir)
	
	var v_path := get_local_version_file_path()
	var file := FileAccess.open(v_path, FileAccess.WRITE)
	if file:
		var data := {
			"version": new_version,
			"updated_at": Time.get_datetime_string_from_system()
		}
		file.store_string(JSON.stringify(data, "\t"))
		file.close()

func load_settings() -> void:
	if not FileAccess.file_exists(CONFIG_FILE):
		return
	
	var file := FileAccess.open(CONFIG_FILE, FileAccess.READ)
	if not file:
		return
	
	var json := JSON.new()
	if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
		var d: Dictionary = json.data
		game_directory = str(d.get("game_directory", game_directory))
		auto_play_on_ready = bool(d.get("auto_play_on_ready", auto_play_on_ready))
		close_launcher_on_play = bool(d.get("close_launcher_on_play", close_launcher_on_play))
		
		# Trava de segurança: github_repo e custom_manifest_url só aceitam override em build de debug
		if OS.is_debug_build():
			custom_manifest_url = str(d.get("custom_manifest_url", custom_manifest_url))
			github_repo = str(d.get("github_repo", github_repo))
		else:
			custom_manifest_url = ""
			github_repo = DEFAULT_GITHUB_REPO
	file.close()

func save_settings() -> void:
	var file := FileAccess.open(CONFIG_FILE, FileAccess.WRITE)
	if not file:
		return
	
	var data := {
		"game_directory": game_directory,
		"auto_play_on_ready": auto_play_on_ready,
		"close_launcher_on_play": close_launcher_on_play
	}
	
	if OS.is_debug_build():
		data["custom_manifest_url"] = custom_manifest_url
		data["github_repo"] = github_repo
	
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
