class_name GameRunner
extends RefCounted

## Localiza e executa o binário do jogo Cepas Selvagens de forma desacoplada.

static func is_game_installed(executable_path: String) -> bool:
	return FileAccess.file_exists(find_actual_executable(executable_path))

static func find_actual_executable(hint_path: String) -> String:
	if FileAccess.file_exists(hint_path):
		return hint_path
	
	var base_dir: String = hint_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(base_dir):
		return ""
	
	var candidates: PackedStringArray = PackedStringArray([
		"CepaSelvagem.exe",
		"CepasSelvagens.exe",
		"CepaSelvagem.x86_64",
		"CepasSelvagens.x86_64",
		"CepaSelvagem",
		"CepasSelvagens"
	])
	
	for c in candidates:
		var p: String = base_dir.path_join(c)
		if FileAccess.file_exists(p):
			return p
	
	return ""

static func launch_game(executable_path: String, extra_args: PackedStringArray = PackedStringArray()) -> Dictionary:
	var result := {
		"success": false,
		"pid": -1,
		"error": ""
	}
	
	var actual_path: String = find_actual_executable(executable_path)
	if actual_path.is_empty():
		result["error"] = "Executável do jogo não encontrado em: %s" % executable_path
		return result
	
	var global_exe_path: String = ProjectSettings.globalize_path(actual_path)
	var pid: int = OS.create_process(global_exe_path, extra_args)
	if pid <= 0:
		result["error"] = "Falha do sistema operacional ao criar processo para: %s" % global_exe_path
		return result
	
	result["success"] = true
	result["pid"] = pid
	return result

static func open_game_folder(folder_path: String) -> void:
	var global_path: String = ProjectSettings.globalize_path(folder_path)
	if not DirAccess.dir_exists_absolute(global_path):
		DirAccess.make_dir_recursive_absolute(global_path)
	OS.shell_open(global_path)
