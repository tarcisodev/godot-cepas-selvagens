class_name Patcher
extends RefCounted

## Responsável pela verificação de integridade (SHA-256) e descompactação de pacotes (ZIPReader).

static func verify_sha256(file_path: String, expected_sha256: String) -> bool:
	var expected: String = expected_sha256.strip_edges().to_lower()
	if expected.is_empty():
		# Se o manifesto não forneceu SHA-256, considera válido
		return true
	
	if not FileAccess.file_exists(file_path):
		return false
	
	var actual_hash: String = FileAccess.get_sha256(file_path).to_lower()
	return actual_hash == expected

static func extract_zip(zip_path: String, destination_dir: String, progress_callback: Callable = Callable()) -> Dictionary:
	var result := {
		"success": false,
		"files_extracted": 0,
		"error": ""
	}
	
	if not FileAccess.file_exists(zip_path):
		result["error"] = "Arquivo ZIP de atualização não encontrado: %s" % zip_path
		return result
	
	var reader := ZIPReader.new()
	var err := reader.open(zip_path)
	if err != OK:
		result["error"] = "Falha ao abrir pacote ZIP (código de erro: %d)" % err
		return result
	
	# Garante que a pasta de destino exista
	if not DirAccess.dir_exists_absolute(destination_dir):
		var mkdir_err := DirAccess.make_dir_recursive_absolute(destination_dir)
		if mkdir_err != OK:
			reader.close()
			result["error"] = "Não foi possível criar o diretório de destino: %s" % destination_dir
			return result
	
	var files: PackedStringArray = reader.get_files()
	var total_files: int = files.size()
	var extracted_count: int = 0
	
	for i in range(total_files):
		var raw_name: String = files[i]
		# Normaliza separadores
		var relative_path: String = raw_name.replace("\\", "/").strip_edges()
		if relative_path.is_empty():
			continue
		
		var target_file_path: String = destination_dir.path_join(relative_path)
		
		# Se for uma entrada de diretório
		if relative_path.ends_with("/"):
			if not DirAccess.dir_exists_absolute(target_file_path):
				DirAccess.make_dir_recursive_absolute(target_file_path)
			continue
		
		# Cria pasta pai do arquivo se não existir
		var parent_dir := target_file_path.get_base_dir()
		if not DirAccess.dir_exists_absolute(parent_dir):
			DirAccess.make_dir_recursive_absolute(parent_dir)
		
		# Lê conteúdo do ZIP e grava no destino
		var buffer: PackedByteArray = reader.read_file(raw_name)
		var out_file := FileAccess.open(target_file_path, FileAccess.WRITE)
		if not out_file:
			reader.close()
			result["error"] = "Erro ao gravar arquivo descompactado: %s" % target_file_path
			return result
		
		out_file.store_buffer(buffer)
		out_file.close()
		extracted_count += 1
		
		if progress_callback.is_valid():
			progress_callback.call(extracted_count, total_files, relative_path)
	
	reader.close()
	result["success"] = true
	result["files_extracted"] = extracted_count
	return result

static func cleanup(file_path: String) -> void:
	if FileAccess.file_exists(file_path):
		DirAccess.remove_absolute(file_path)
