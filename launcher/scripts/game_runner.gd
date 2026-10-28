class_name GameRunner
extends RefCounted

## Localiza e executa o binário do jogo Cepas Selvagens de forma desacoplada.
## Fornece detecção ativa de processos em execução para proteção de integridade.

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

## Detecta se o jogo está atualmente aberto / em execução no sistema.
## Impede que atualizações sobrescrevam binários bloqueados pelo SO.
static func is_game_running(executable_path: String) -> bool:
	var actual: String = find_actual_executable(executable_path)
	if actual.is_empty():
		return false
	
	# Verificação 1: No Windows, arquivos executáveis em execução não podem ser abertos para escrita (lock exclusivo do kernel)
	var file := FileAccess.open(actual, FileAccess.READ_WRITE)
	if file == null:
		var err := FileAccess.get_open_error()
		if err == ERR_FILE_CANT_OPEN or err == ERR_UNAUTHORIZED:
			return true
	else:
		file.close()
	
	# Verificação 2: Consulta direta à lista de tarefas do sistema operacional
	var exe_name: String = actual.get_file()
	if OS.get_name() == "Windows":
		var output: Array = []
		var code := OS.execute("tasklist.exe", ["/FI", "IMAGENAME eq %s" % exe_name, "/NH"], output, true)
		if code == 0 and not output.is_empty():
			var out_str: String = output[0]
			if exe_name.to_lower() in out_str.to_lower() and not ("Nenhuma tarefa" in out_str or "No tasks" in out_str):
				return true
	elif OS.get_name() in ["Linux", "FreeBSD", "NetBSD", "OpenBSD", "BSD"]:
		var output: Array = []
		var code := OS.execute("pgrep", ["-f", exe_name], output, true)
		if code == 0 and not output.is_empty():
			return true
	
	return false

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
