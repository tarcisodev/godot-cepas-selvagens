class_name PatchManager
extends RefCounted

## Gerenciador de Patches e Pacotes de Recursos (.pck) em Tempo de Execução.
## Permite ao jogo carregar dinamicamente patches baixados para user://patches/
## e validar integridade criptográfica SHA-256 antes da montagem.

const PATCHES_DIR: String = "user://patches"
const VERSION_FILE: String = "user://version.json"

## Retorna a versão base compilada no executável
static func get_base_version() -> String:
	var ver: String = str(ProjectSettings.get_setting("application/config/version", "0.1.0"))
	return ver.strip_edges()

## Retorna a versão atual instalada (do version.json ou a versão base)
static func get_current_version(version_file_path: String = VERSION_FILE) -> String:
	if not FileAccess.file_exists(version_file_path):
		return get_base_version()
	
	var file := FileAccess.open(version_file_path, FileAccess.READ)
	if file == null:
		return get_base_version()
	
	var text := file.get_as_text()
	file.close()
	
	var json := JSON.new()
	if json.parse(text) != OK or not (json.data is Dictionary):
		return get_base_version()
	
	var data: Dictionary = json.data
	var ver: String = str(data.get("version", "")).strip_edges()
	if ver.is_empty():
		return get_base_version()
	
	return ver

## Garante que o diretório de patches existe
static func ensure_patches_directory(patches_dir: String = PATCHES_DIR) -> bool:
	var global_path := ProjectSettings.globalize_path(patches_dir)
	if not DirAccess.dir_exists_absolute(global_path):
		var err := DirAccess.make_dir_recursive_absolute(global_path)
		return err == OK
	return true

## Monta todos os pacotes .pck presentes no diretório de patches
static func load_all_installed_patches(patches_dir: String = PATCHES_DIR) -> int:
	ensure_patches_directory(patches_dir)
	
	var dir := DirAccess.open(patches_dir)
	if dir == null:
		return 0
	
	var pck_files: Array[String] = []
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".pck"):
			pck_files.append(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	
	pck_files.sort()
	var loaded_count: int = 0
	for pck in pck_files:
		var full_path := patches_dir.path_join(pck)
		var ok := ProjectSettings.load_resource_pack(full_path, true)
		if ok:
			loaded_count += 1
			print("[PatchManager] Pacote de recursos montado com sucesso: %s" % pck)
		else:
			push_warning("[PatchManager] Falha ao carregar pacote: %s" % pck)
	
	return loaded_count

## Valida SHA-256 do arquivo baixado
static func verify_patch_sha256(file_path: String, expected_sha256: String) -> bool:
	var expected := expected_sha256.strip_edges().to_lower()
	if expected.is_empty():
		return false
	
	if not FileAccess.file_exists(file_path):
		return false
	
	var actual := FileAccess.get_sha256(file_path).to_lower()
	return actual == expected

## Aplica um novo patch baixado: valida SHA-256, move para o diretório oficial, monta e grava version.json
static func apply_downloaded_pck(temp_file_path: String, final_filename: String, version: String, expected_sha256: String, patches_dir: String = PATCHES_DIR, version_file_path: String = VERSION_FILE) -> Dictionary:
	var res := {
		"success": false,
		"error": ""
	}
	
	if not FileAccess.file_exists(temp_file_path):
		res["error"] = "Arquivo temporário do patch não encontrado: %s" % temp_file_path
		return res
	
	# Validação de integridade
	if not expected_sha256.strip_edges().is_empty():
		if not verify_patch_sha256(temp_file_path, expected_sha256):
			DirAccess.remove_absolute(temp_file_path)
			res["error"] = "Assinatura SHA-256 do pacote baixado diverge do manifesto. Arquivo descartado por segurança."
			return res
	
	ensure_patches_directory(patches_dir)
	var target_path := patches_dir.path_join(final_filename)
	
	# Se já existir um arquivo anterior com mesmo nome, remove
	if FileAccess.file_exists(target_path):
		DirAccess.remove_absolute(target_path)
	
	# Move arquivo temporário para o destino final
	var err := DirAccess.copy_absolute(temp_file_path, target_path)
	if err != OK:
		res["error"] = "Falha ao copiar pacote para destino oficial (código %d)" % err
		return res
	DirAccess.remove_absolute(temp_file_path)
	
	# Monta o pacote de recursos na Engine
	var load_ok := ProjectSettings.load_resource_pack(target_path, true)
	if not load_ok:
		res["error"] = "Falha ao montar o pacote .pck carregado no Godot Engine."
		return res
	
	# Atualiza o arquivo de versão
	var v_data := {
		"version": version,
		"patch_file": final_filename,
		"sha256": expected_sha256,
		"updated_at": Time.get_datetime_string_from_system()
	}
	var v_file := FileAccess.open(version_file_path, FileAccess.WRITE)
	if v_file != null:
		v_file.store_string(JSON.stringify(v_data, "  "))
		v_file.close()
	
	res["success"] = true
	return res
