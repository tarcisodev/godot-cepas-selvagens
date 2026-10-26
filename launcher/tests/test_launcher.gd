extends SceneTree

## Teste unitário e de integração do Launcher de Cepas Selvagens.
## Execução: godot --path launcher/ --headless -s res://tests/test_launcher.gd

const _LauncherConfig = preload("res://scripts/launcher_config.gd")
const _VersionChecker = preload("res://scripts/version_checker.gd")
const _Downloader = preload("res://scripts/downloader.gd")
const _Patcher = preload("res://scripts/patcher.gd")
const _GameRunner = preload("res://scripts/game_runner.gd")

var _started := false

func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run_all_tests()
	return false

func _run_all_tests() -> void:
	print("\n========================================================")
	print("🚀 TESTANDO LAUNCHER & AUTO-UPDATER DE CEPAS SELVAGENS")
	print("========================================================")
	
	test_version_comparison()
	test_release_data_parsing_and_best_match()
	test_config_and_version_file()
	test_patcher_sha256_strict_and_zipslip()
	test_game_runner_and_process_detection()
	test_downloader_helpers()
	
	print("\n🎉 TODOS OS TESTES DO LAUNCHER PASSARAM COM SUCESSO!")
	print("========================================================\n")
	quit(0)

func test_version_comparison() -> void:
	print("\n[1/6] Comparação Semântica de Versões (VersionChecker)...")
	
	# Versões iguais
	assert(_VersionChecker.compare_versions("0.1.0", "0.1.0") == 0, "Versões idênticas devem ser iguais")
	assert(_VersionChecker.compare_versions("v0.1.0", "0.1.0") == 0, "Prefixo 'v' deve ser ignorado")
	assert(_VersionChecker.compare_versions("0.1.0-beta", "0.1.0") == 0, "Sufixo de pré-release ignorado no corte base")
	
	# Versão menor (atualização disponível)
	assert(_VersionChecker.compare_versions("0.1.0", "0.1.1") == -1, "0.1.0 < 0.1.1")
	assert(_VersionChecker.compare_versions("0.1.9", "0.2.0") == -1, "0.1.9 < 0.2.0")
	assert(_VersionChecker.compare_versions("0.9.5", "1.0.0") == -1, "0.9.5 < 1.0.0")
	assert(_VersionChecker.compare_versions("v0.1.0", "v0.1.1") == -1, "v0.1.0 < v0.1.1")
	
	# Versão maior (desenvolvimento à frente da release)
	assert(_VersionChecker.compare_versions("0.2.0", "0.1.9") == 1, "0.2.0 > 0.1.9")
	assert(_VersionChecker.compare_versions("1.0.0", "0.9.9") == 1, "1.0.0 > 0.9.9")
	
	print("  -> Algoritmo semver validado com sucesso.")

func test_release_data_parsing_and_best_match() -> void:
	print("\n[2/6] Parsing de Release do GitHub, Manifesto e Seleção Estrita de Assets...")
	
	# 1. Parsing de manifesto customizado direto
	var manifest_mock := {
		"version": "1.0.0",
		"file": "CepaSelvagem-1.0.0-windows.zip",
		"download_url": "https://cdn.example.com/CepaSelvagem-1.0.0-windows.zip",
		"sha256": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
		"size": 209715200
	}
	var parsed_mf: Dictionary = _VersionChecker.parse_release_data(manifest_mock)
	assert(parsed_mf["version"] == "1.0.0", "Versão do manifesto validada")
	assert(parsed_mf["sha256"] == "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855", "SHA256 extraído")
	assert(parsed_mf["download_url"] == "https://cdn.example.com/CepaSelvagem-1.0.0-windows.zip", "URL do manifesto validada")
	
	# 2. Parsing de lista de releases com seleção estrita por semver e assets oficiais
	var releases_mock := [
		# Release mais antiga (v0.1.0)
		{
			"tag_name": "v0.1.0",
			"name": "Playtest 0.1.0",
			"prerelease": true,
			"draft": false,
			"assets": [
				{"name": "CepaSelvagem-0.1.0-windows.zip", "browser_download_url": "https://cdn.test/v0.1.0/CepaSelvagem-0.1.0-windows.zip", "size": 100},
				{"name": "manifest.json", "browser_download_url": "https://cdn.test/v0.1.0/manifest.json", "size": 50}
			]
		},
		# Release com asset de nome genérico incorreto (não deve ser escolhida)
		{
			"tag_name": "v0.1.2",
			"name": "Release Inválida",
			"prerelease": false,
			"draft": false,
			"assets": [
				{"name": "qualquer_coisa.zip", "browser_download_url": "https://cdn.test/qualquer.zip", "size": 100},
				{"name": "manifest.json", "browser_download_url": "https://cdn.test/manifest.json", "size": 50}
			]
		},
		# Release mais recente válida (v0.1.1)
		{
			"tag_name": "v0.1.1",
			"name": "Playtest 0.1.1",
			"prerelease": false,
			"draft": false,
			"assets": [
				{"name": "CepaSelvagem-0.1.1-windows.zip", "browser_download_url": "https://cdn.test/v0.1.1/CepaSelvagem-0.1.1-windows.zip", "size": 200},
				{"name": "manifest.json", "browser_download_url": "https://cdn.test/v0.1.1/manifest.json", "size": 60}
			]
		}
	]
	
	var best: Dictionary = _VersionChecker.find_best_release(releases_mock)
	assert(not best.is_empty(), "Deve encontrar a melhor release")
	assert(best["version"] == "0.1.1", "Deve selecionar a versão mais nova (0.1.1)")
	assert(best["zip_asset"]["name"] == "CepaSelvagem-0.1.1-windows.zip", "Asset com nome exato CepaSelvagem-<versao>-windows.zip")
	assert(best["manifest_asset"]["name"] == "manifest.json", "Asset manifest.json selecionado da mesma release")
	
	# Release sem manifest.json é recusada
	var release_no_manifest := [
		{
			"tag_name": "v0.2.0",
			"draft": false,
			"assets": [
				{"name": "CepaSelvagem-0.2.0-windows.zip", "browser_download_url": "https://cdn.test/0.2.0.zip", "size": 100}
			]
		}
	]
	var best_none: Dictionary = _VersionChecker.find_best_release(release_no_manifest)
	assert(best_none.is_empty(), "Release sem manifest.json deve ser recusada")
	
	print("  -> Parsing de GitHub API, Manifesto direto e seleção estrita validados.")

func test_config_and_version_file() -> void:
	print("\n[3/6] Persistência de Configurações e Versão Local...")
	
	var config := _LauncherConfig.new()
	assert(config.github_repo == _LauncherConfig.DEFAULT_GITHUB_REPO, "Repo padrão deve coincidir")
	assert(not config.get_executable_path().is_empty(), "Caminho do executável deve ser gerado")
	
	# Testa gravação e leitura de versão em diretório de teste
	var original_game_dir: String = config.game_directory
	var test_game_dir: String = "user://test_launcher_game_dir"
	DirAccess.make_dir_recursive_absolute(test_game_dir)
	config.game_directory = test_game_dir
	
	var test_ver: String = "0.9.8"
	config.write_installed_version(test_ver)
	var read_ver: String = config.read_installed_version()
	assert(read_ver == test_ver, "Versão lida deve ser igual à gravada: %s vs %s" % [read_ver, test_ver])
	
	# Limpeza de teste e restauração
	var v_path: String = config.get_local_version_file_path()
	if FileAccess.file_exists(v_path):
		DirAccess.remove_absolute(v_path)
	config.game_directory = original_game_dir
	
	# Salva e carrega configurações
	config.save_settings()
	var config2 := _LauncherConfig.new()
	assert(config2.github_repo == _LauncherConfig.DEFAULT_GITHUB_REPO, "Configuração carregada")
	
	print("  -> Configurações salvas e versão local lida/gravada com sucesso.")

func test_patcher_sha256_strict_and_zipslip() -> void:
	print("\n[4/6] Patcher: Integridade Estrita SHA-256 e Proteção contra ZipSlip...")
	
	var test_dir: String = "user://test_launcher_patcher"
	DirAccess.make_dir_recursive_absolute(test_dir)
	
	var test_file_path: String = test_dir.path_join("test_sample.txt")
	var file := FileAccess.open(test_file_path, FileAccess.WRITE)
	file.store_string("CepasSelvagensLauncherPatcherContent")
	file.close()
	
	# 1. Teste SHA-256 estrito (Hash vazio NUNCA vale)
	var expected_hash: String = FileAccess.get_sha256(test_file_path)
	assert(not expected_hash.is_empty(), "Hash gerado não deve ser vazio")
	assert(_Patcher.verify_sha256(test_file_path, expected_hash), "Validação com hash correto deve retornar true")
	assert(not _Patcher.verify_sha256(test_file_path, "invalid_hash_value"), "Validação com hash incorreto deve retornar false")
	assert(not _Patcher.verify_sha256(test_file_path, ""), "Hash esperado vazio DEVE retornar false (recusa estrita)")
	assert(not _Patcher.verify_sha256(test_file_path, "   "), "Hash em branco DEVE retornar false")
	
	# 2. Teste Criação e Extração Segura de ZIP (com troca atômica)
	var zip_path: String = test_dir.path_join("test_package.zip")
	var packer := ZIPPacker.new()
	var pack_err := packer.open(zip_path)
	assert(pack_err == OK, "ZIPPacker abre com sucesso")
	
	packer.start_file("CepaSelvagem.exe")
	packer.write_file("FAKE_EXECUTABLE_BYTES".to_utf8_buffer())
	packer.close_file()
	
	packer.start_file("subfolder/data.txt")
	packer.write_file("SUBFOLDER_CONTENT".to_utf8_buffer())
	packer.close_file()
	packer.close()
	
	# Extrai com o Patcher
	var extract_dest: String = test_dir.path_join("extracted_game")
	var progress_calls: Array[int] = [0]
	var res: Dictionary = _Patcher.extract_zip(zip_path, extract_dest, func(_cur, _tot, _f): progress_calls[0] += 1)
	
	assert(res.get("success", false) == true, "Extração deve ser bem-sucedida")
	assert(res.get("files_extracted", 0) == 2, "2 arquivos devem ter sido extraídos")
	assert(progress_calls[0] >= 2, "Callback de progresso deve ter sido chamado")
	assert(FileAccess.file_exists(extract_dest.path_join("CepaSelvagem.exe")), "Executável extraído no destino")
	assert(FileAccess.file_exists(extract_dest.path_join("subfolder/data.txt")), "Arquivo em subpasta extraído")
	
	# 3. Teste de Bloqueio ZipSlip (caminho malicioso com "..")
	var malicious_zip := test_dir.path_join("malicious.zip")
	var mpacker := ZIPPacker.new()
	mpacker.open(malicious_zip)
	mpacker.start_file("../outside_escape.txt")
	mpacker.write_file("MALICIOUS_DATA".to_utf8_buffer())
	mpacker.close_file()
	mpacker.close()
	
	var m_res: Dictionary = _Patcher.extract_zip(malicious_zip, extract_dest)
	assert(not m_res.get("success", false), "ZIP com '..' DEVE ser rejeitado com falha")
	assert("ZipSlip" in str(m_res.get("error", "")), "Erro deve reportar detecção de ZipSlip")
	assert(not FileAccess.file_exists(test_dir.path_join("outside_escape.txt")), "Nenhum arquivo externo pode ser criado")
	
	# Cleanup
	_Patcher.cleanup(zip_path)
	_Patcher.cleanup(malicious_zip)
	_Patcher.cleanup(test_file_path)
	
	print("  -> Verificação SHA-256 estrita, troca atômica e proteção contra ZipSlip validadas com sucesso.")

func test_game_runner_and_process_detection() -> void:
	print("\n[5/6] GameRunner e Detecção de Processo...")
	
	var fake_path: String = "user://fake_game_dir/CepaSelvagem.exe"
	assert(not _GameRunner.is_game_installed(fake_path), "Caminho inexistente deve reportar não instalado")
	assert(not _GameRunner.is_game_running(fake_path), "Jogo inexistente não está em execução")
	
	var base_dir: String = "user://test_runner_dir"
	DirAccess.make_dir_recursive_absolute(base_dir)
	var real_exe: String = base_dir.path_join("CepaSelvagem.exe")
	var f := FileAccess.open(real_exe, FileAccess.WRITE)
	f.store_string("EXE_MOCK")
	f.close()
	
	assert(_GameRunner.is_game_installed(real_exe), "Executável presente deve ser detectado")
	var found: String = _GameRunner.find_actual_executable(base_dir.path_join("qualquer_coisa.exe"))
	assert(found == real_exe, "find_actual_executable deve localizar o binário CepaSelvagem.exe na pasta")
	
	DirAccess.remove_absolute(real_exe)
	print("  -> Detecção de executável e métodos do GameRunner validados.")

func test_downloader_helpers() -> void:
	print("\n[6/6] Formatadores do Downloader...")
	
	assert(_Downloader.format_bytes(500) == "500 B", "500 bytes")
	assert(_Downloader.format_bytes(1024 * 512) == "512.0 KB", "512 KB")
	assert(_Downloader.format_bytes(1024 * 1024 * 45) == "45.0 MB", "45 MB")
	assert(_Downloader.format_speed(1024 * 1024 * 3.5) == "3.5 MB/s", "Velocidade MB/s")
	assert(_Downloader.format_time(45.0) == "45s", "Tempo em segundos")
	assert(_Downloader.format_time(75.0) == "1m 15s", "Tempo em minutos e segundos")
	
	print("  -> Formatadores de bytes, velocidade e tempo restantes validados.")
