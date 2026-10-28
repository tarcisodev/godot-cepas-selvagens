class_name Patcher
extends RefCounted

## Responsável pela verificação de integridade (SHA-256) e descompactação atômica e segura (ZIPReader).

## Valida SHA-256 de um arquivo local contra o hash esperado.
## Recusa estritamente caso o hash esperado esteja vazio ou seja divergente.
static func verify_sha256(file_path: String, expected_sha256: String) -> bool:
	var expected: String = expected_sha256.strip_edges().to_lower()
	if expected.is_empty():
		# Hash vazio NUNCA é aceito
		return false
	
	if not FileAccess.file_exists(file_path):
		return false
	
	var actual_hash: String = FileAccess.get_sha256(file_path).to_lower()
	return actual_hash == expected

## Extrai pacote ZIP com proteção estrita contra ZipSlip e troca atômica via pasta temporária.
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
	
	var files: PackedStringArray = reader.get_files()
	var total_files: int = files.size()
	
	# 1. Validação estrita de segurança contra ZipSlip e caminhos inseguros
	for i in range(total_files):
		var raw_name: String = files[i]
		var rel: String = raw_name.replace("\\", "/").strip_edges()
		if rel.is_empty():
			continue
		
		if rel.begins_with("/") or rel.begins_with("\\"):
			reader.close()
			result["error"] = "Arquivo compactado rejeitado: caminho absoluto não permitido (%s)" % rel
			return result
		
		if ":" in rel:
			reader.close()
			result["error"] = "Arquivo compactado rejeitado: letra de unidade/drive não permitida (%s)" % rel
			return result
		
		var segments := rel.split("/")
		for seg in segments:
			if seg == "..":
				reader.close()
				result["error"] = "Tentativa de ZipSlip detectada e bloqueada (%s)" % rel
				return result
	
	# 2. Descompactação em diretório temporário de transição (staging)
	var staging_dir := destination_dir + "_staging"
	var backup_dir := destination_dir + "_backup"
	
	# Garante que staging anterior esteja limpo
	_remove_dir_recursive(staging_dir)
	
	var mkdir_err := DirAccess.make_dir_recursive_absolute(staging_dir)
	if mkdir_err != OK:
		reader.close()
		result["error"] = "Não foi possível criar o diretório de staging: %s" % staging_dir
		return result
	
	var extracted_count: int = 0
	for i in range(total_files):
		var raw_name: String = files[i]
		var relative_path: String = raw_name.replace("\\", "/").strip_edges()
		if relative_path.is_empty():
			continue
		
		var target_file_path: String = staging_dir.path_join(relative_path)
		
		if relative_path.ends_with("/"):
			if not DirAccess.dir_exists_absolute(target_file_path):
				DirAccess.make_dir_recursive_absolute(target_file_path)
			continue
		
		var parent_dir := target_file_path.get_base_dir()
		if not DirAccess.dir_exists_absolute(parent_dir):
			DirAccess.make_dir_recursive_absolute(parent_dir)
		
		var buffer: PackedByteArray = reader.read_file(raw_name)
		var out_file := FileAccess.open(target_file_path, FileAccess.WRITE)
		if not out_file:
			reader.close()
			_remove_dir_recursive(staging_dir)
			result["error"] = "Erro ao gravar arquivo no staging: %s" % target_file_path
			return result
		
		out_file.store_buffer(buffer)
		out_file.close()
		extracted_count += 1
		
		if progress_callback.is_valid():
			progress_callback.call(extracted_count, total_files, relative_path)
	
	reader.close()
	
	# 3. Troca Atômica (Atomic Swap com Rollback de Backup)
	_remove_dir_recursive(backup_dir)
	
	var had_existing_dir: bool = DirAccess.dir_exists_absolute(destination_dir)
	if had_existing_dir:
		var rename_backup_err := DirAccess.rename_absolute(destination_dir, backup_dir)
		if rename_backup_err != OK:
			_remove_dir_recursive(staging_dir)
			result["error"] = "Falha ao mover versão anterior para backup (código: %d)" % rename_backup_err
			return result
	
	var rename_staging_err := DirAccess.rename_absolute(staging_dir, destination_dir)
	if rename_staging_err != OK:
		# Rollback imediato se a troca do staging falhar
		if had_existing_dir and DirAccess.dir_exists_absolute(backup_dir):
			DirAccess.rename_absolute(backup_dir, destination_dir)
		_remove_dir_recursive(staging_dir)
		result["error"] = "Falha ao promover staging para versão oficial (código: %d). Rollback executado." % rename_staging_err
		return result
	
	# Sucesso: limpa o backup da versão anterior
	if DirAccess.dir_exists_absolute(backup_dir):
		_remove_dir_recursive(backup_dir)
	
	result["success"] = true
	result["files_extracted"] = extracted_count
	return result

## Remove um arquivo de forma segura se existir
static func cleanup(file_path: String) -> void:
	if FileAccess.file_exists(file_path):
		DirAccess.remove_absolute(file_path)

## Remove recursivamente um diretório e todos os seus arquivos internos
static func _remove_dir_recursive(dir_path: String) -> void:
	if not DirAccess.dir_exists_absolute(dir_path):
		return
	
	var dir := DirAccess.open(dir_path)
	if dir:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while not file_name.is_empty():
			if file_name != "." and file_name != "..":
				var full_path := dir_path.path_join(file_name)
				if dir.current_is_dir():
					_remove_dir_recursive(full_path)
				else:
					DirAccess.remove_absolute(full_path)
			file_name = dir.get_next()
		dir.list_dir_end()
	
	DirAccess.remove_absolute(dir_path)
