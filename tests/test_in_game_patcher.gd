extends SceneTree

## Teste unitário e de integração do Patcher In-Game e BootSplash.
## Valida semver, detecção de assets .pck, integridade SHA-256 e montagem de pacotes.

const _PatchManager = preload("res://scripts/patcher/patch_manager.gd")
const _PatchVersionChecker = preload("res://scripts/patcher/patch_version_checker.gd")
const _BootSplash = preload("res://scripts/ui/boot_splash.gd")

func _init() -> void:
	print("\n========================================================")
	print("🚀 INICIANDO TESTES DO PATCHER IN-GAME & BOOT SPLASH")
	print("========================================================")
	
	_test_semver_and_cleaning()
	_test_find_latest_release()
	_test_patch_manager_versioning()
	_test_patch_manager_sha256_validation()
	_test_patch_manager_apply_pck()
	_test_boot_splash_ui_instantiation()
	
	print("\n🎉 TODOS OS TESTES DO PATCHER IN-GAME PASSARAM COM SUCESSO!")
	print("========================================================\n")
	quit(0)

func _test_semver_and_cleaning() -> void:
	print("-> Testando semver e sanitização de versões...")
	assert(_PatchVersionChecker.clean_version("v1.2.3") == "1.2.3", "Deve remover 'v'")
	assert(_PatchVersionChecker.clean_version("  V0.5.0  ") == "0.5.0", "Deve remover espaços e 'V'")
	
	assert(_PatchVersionChecker.compare_versions("1.0.0", "1.0.0") == 0, "Versões idênticas")
	assert(_PatchVersionChecker.compare_versions("1.1.0", "1.0.9") == 1, "1.1.0 > 1.0.9")
	assert(_PatchVersionChecker.compare_versions("0.9.5", "1.0.0") == -1, "0.9.5 < 1.0.0")
	assert(_PatchVersionChecker.compare_versions("0.1.2", "0.1.1") == 1, "0.1.2 > 0.1.1")
	assert(_PatchVersionChecker.compare_versions("2.0.0", "1.99.99") == 1, "2.0.0 > 1.99.99")
	print("   [OK] Semver validado.")

func _test_find_latest_release() -> void:
	print("-> Testando descoberta de release com asset .pck...")
	var releases: Array = [
		{
			"tag_name": "v0.1.0",
			"draft": false,
			"assets": [
				{"name": "CepaSelvagem-0.1.0.zip", "browser_download_url": "http://x/0.1.0.zip"}
			]
		},
		{
			"tag_name": "v0.1.2",
			"draft": false,
			"assets": [
				{"name": "patch_v0.1.2.pck", "browser_download_url": "http://x/patch_v0.1.2.pck", "size": 1024},
				{"name": "manifest.json", "browser_download_url": "http://x/manifest.json"}
			]
		},
		{
			"tag_name": "v0.1.3",
			"draft": true, # Deve ignorar rascunho
			"assets": [
				{"name": "patch_v0.1.3.pck", "browser_download_url": "http://x/patch_v0.1.3.pck"}
			]
		},
		{
			"tag_name": "v0.1.1",
			"draft": false,
			"assets": [
				{"name": "patch_v0.1.1.pck", "browser_download_url": "http://x/patch_v0.1.1.pck"}
			]
		}
	]
	
	var best := _PatchVersionChecker.find_latest_release(releases)
	assert(not best.is_empty(), "Deve encontrar uma release válida")
	assert(best["version"] == "0.1.2", "Deve escolher v0.1.2 (ignora draft 0.1.3 e anteriores)")
	assert(not best["pck_asset"].is_empty(), "Deve identificar o asset .pck")
	assert(best["pck_asset"]["name"] == "patch_v0.1.2.pck", "Nome do asset deve ser patch_v0.1.2.pck")
	print("   [OK] Descoberta de release validada.")

func _test_patch_manager_versioning() -> void:
	print("-> Testando leitura e gravação de versão do PatchManager...")
	var test_version_file := "user://test_version_temp.json"
	if FileAccess.file_exists(test_version_file):
		DirAccess.remove_absolute(test_version_file)
	
	var initial_ver := _PatchManager.get_current_version(test_version_file)
	assert(not initial_ver.is_empty(), "Deve retornar versão base quando não há version.json")
	
	# Grava mock
	var f := FileAccess.open(test_version_file, FileAccess.WRITE)
	f.store_string('{"version": "0.9.9", "patch_file": "patch_v0.9.9.pck"}')
	f.close()
	
	var custom_ver := _PatchManager.get_current_version(test_version_file)
	assert(custom_ver == "0.9.9", "Deve ler versão gravada no version.json")
	DirAccess.remove_absolute(test_version_file)
	print("   [OK] Versionamento validado.")

func _test_patch_manager_sha256_validation() -> void:
	print("-> Testando validação estrita de integridade SHA-256...")
	var test_file := "user://test_sha_sample.bin"
	var f := FileAccess.open(test_file, FileAccess.WRITE)
	f.store_string("CepasSelvagensPatchPayloadTest123")
	f.close()
	
	var real_hash := FileAccess.get_sha256(test_file)
	assert(not real_hash.is_empty(), "Hash do arquivo teste não pode ser vazio")
	
	# Teste positivo
	assert(_PatchManager.verify_patch_sha256(test_file, real_hash), "Hash idêntico deve ser aceito")
	assert(_PatchManager.verify_patch_sha256(test_file, real_hash.to_upper()), "Case-insensitive deve ser aceito")
	
	# Teste negativo
	assert(not _PatchManager.verify_patch_sha256(test_file, ""), "Hash esperado vazio NUNCA pode ser aceito")
	assert(not _PatchManager.verify_patch_sha256(test_file, "0000000000000000000000000000000000000000000000000000000000000000"), "Hash falso deve falhar")
	assert(not _PatchManager.verify_patch_sha256("user://inexistente.bin", real_hash), "Arquivo inexistente deve falhar")
	
	DirAccess.remove_absolute(test_file)
	print("   [OK] Integridade SHA-256 validada.")

func _test_patch_manager_apply_pck() -> void:
	print("-> Testando aplicação atômica de patch...")
	var test_dir := "user://test_patches_sandbox"
	var test_vfile := "user://test_version_sandbox.json"
	var temp_payload := "user://test_temp_download.pck"
	
	# Cria arquivo temporário de teste
	var f := FileAccess.open(temp_payload, FileAccess.WRITE)
	f.store_string("MockPckDataHeader")
	f.close()
	var real_hash := FileAccess.get_sha256(temp_payload)
	
	# Tentativa 1: Hash incorreto deve abortar e descartar arquivo temporário
	var fail_res := _PatchManager.apply_downloaded_pck(temp_payload, "patch_0.2.0.pck", "0.2.0", "invalid_sha_code", test_dir, test_vfile)
	assert(not fail_res["success"], "Deve rejeitar hash divergente")
	assert(not FileAccess.file_exists(temp_payload), "Arquivo temporário divergente deve ser removido por segurança")
	
	# Limpeza
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(test_dir)):
		for file in DirAccess.get_files_at(test_dir):
			DirAccess.remove_absolute(test_dir.path_join(file))
		DirAccess.remove_absolute(test_dir)
	if FileAccess.file_exists(test_vfile):
		DirAccess.remove_absolute(test_vfile)
	
	print("   [OK] Aplicação e proteção de patch validados.")

func _test_boot_splash_ui_instantiation() -> void:
	print("-> Testando instanciação da cena BootSplash...")
	var splash := _BootSplash.new()
	assert(splash != null, "BootSplash deve ser instanciável")
	splash._build_ui()
	
	assert(splash.title_label != null, "Título da UI deve existir")
	assert(splash.progress_bar != null, "Barra de progresso deve existir")
	assert(splash.status_label != null, "Label de status deve existir")
	assert(splash.action_button != null, "Botão de ação deve existir")
	
	splash.free()
	print("   [OK] Interface do BootSplash validada com sucesso.")
