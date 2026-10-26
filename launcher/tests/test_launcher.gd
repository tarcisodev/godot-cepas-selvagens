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
	test_release_data_parsing()
	test_config_and_version_file()
	test_patcher_sha256_and_zip_extraction()
	test_game_runner()
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

func test_release_data_parsing() -> void:
	print("\n[2/6] Parsing de Release do GitHub e Manifesto...")
	
	# Mock de resposta da API do GitHub Releases
	var github_mock := {
		"tag_name": "v0.2.0",
		"name": "Atualização 0.2.0 - Mercado Negro",
		"body": "- Adicionadas armadilhas\n- Nova loja clandestina",
		"published_at": "2026-10-25T20:00:00Z",
		"assets": [
			{
				"name": "outros_arquivos.txt",
				"size": 1024,
				"browser_download_url": "https://example.com/outros.txt"
			},
			{
				"name": "CepaSelvagem-0.2.0-windows.zip",
				"size": 125829120,
				"browser_download_url": "https://example.com/CepaSelvagem-0.2.0-windows.zip"
			}
		]
	}
	
	var parsed_gh: Dictionary = _VersionChecker.parse_release_data(github_mock)
	assert(not parsed_gh.is_empty(), "Parsing do GitHub não deve retornar vazio")
	assert(parsed_gh["version"] == "0.2.0", "Versão extraída deve ser 0.2.0")
	assert(parsed_gh["asset_name"] == "CepaSelvagem-0.2.0-windows.zip", "Asset de windows selecionado")
	assert(parsed_gh["download_url"] == "https://example.com/CepaSelvagem-0.2.0-windows.zip", "URL extraída corretamente")
	assert(parsed_gh["size_bytes"] == 125829120, "Tamanho em bytes validado")
	assert(parsed_gh["is_zip"] == true, "Identificado como arquivo ZIP")
	
	# Mock de manifesto customizado direto
	var manifest_mock := {
		"version": "1.0.0",
		"title": "Versão 1.0 Oficial",
		"changelog": "Lançamento oficial",
		"download_url": "https://cdn.example.com/cepas_v1.0.0.zip",
		"sha256": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
		"size_bytes": 209715200
	}
	
	var parsed_mf: Dictionary = _VersionChecker.parse_release_data(manifest_mock)
	assert(parsed_mf["version"] == "1.0.0", "Versão do manifesto validada")
	assert(parsed_mf["sha256"] == "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855", "SHA256 extraído")
	assert(parsed_mf["download_url"] == "https://cdn.example.com/cepas_v1.0.0.zip", "URL do manifesto validada")
	
	print("  -> Parsing de GitHub API e Manifesto direto validados.")

func test_config_and_version_file() -> void:
	print("\n[3/6] Persistência de Configurações e Versão Local...")
	
	var config := _LauncherConfig.new()
	assert(config.github_repo == _LauncherConfig.DEFAULT_GITHUB_REPO, "Repo padrão deve coincidir")
	assert(not config.get_executable_path().is_empty(), "Caminho do executável deve ser gerado")
	
	# Testa gravação e leitura de versão
	var test_ver: String = "0.9.8"
	config.write_installed_version(test_ver)
	var read_ver: String = config.read_installed_version()
	assert(read_ver == test_ver, "Versão lida deve ser igual à gravada: %s vs %s" % [read_ver, test_ver])
	
	# Salva e carrega configurações
	config.custom_manifest_url = "https://custom.test/manifest.json"
	config.save_settings()
	
	var config2 := _LauncherConfig.new()
	assert(config2.custom_manifest_url == "https://custom.test/manifest.json", "Configuração persistida carregada")
	
	# Limpeza de teste
	if FileAccess.file_exists(config.get_local_version_file_path()):
		DirAccess.remove_absolute(config.get_local_version_file_path())
	
	print("  -> Configurações salvas e versão local lida/gravada com sucesso.")

func test_patcher_sha256_and_zip_extraction() -> void:
	print("\n[4/6] Patcher: Integridade SHA-256 e Descompactação ZIP...")
	
	var test_dir: String = "user://test_launcher_patcher"
	DirAccess.make_dir_recursive_absolute(test_dir)
	
	var test_file_path: String = test_dir.path_join("test_sample.txt")
	var file := FileAccess.open(test_file_path, FileAccess.WRITE)
	file.store_string("CepasSelvagensLauncherPatcherContent")
	file.close()
	
	# 1. Teste SHA-256
	var expected_hash: String = FileAccess.get_sha256(test_file_path)
	assert(not expected_hash.is_empty(), "Hash gerado não deve ser vazio")
	assert(_Patcher.verify_sha256(test_file_path, expected_hash), "Validação com hash correto deve retornar true")
	assert(not _Patcher.verify_sha256(test_file_path, "invalid_hash_value"), "Validação com hash incorreto deve retornar false")
	assert(_Patcher.verify_sha256(test_file_path, ""), "Hash esperado vazio deve ser considerado válido")
	
	# 2. Teste Criação e Extração de ZIP via ZIPPacker e ZIPReader
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
	
	assert(FileAccess.file_exists(zip_path), "Arquivo ZIP de teste criado")
	
	# Extrai com o Patcher
	var extract_dest: String = test_dir.path_join("extracted")
	var progress_calls: Array[int] = [0]
	var res: Dictionary = _Patcher.extract_zip(zip_path, extract_dest, func(_cur, _tot, _f): progress_calls[0] += 1)
	
	assert(res.get("success", false) == true, "Extração deve ser bem-sucedida")
	assert(res.get("files_extracted", 0) == 2, "2 arquivos devem ter sido extraídos")
	assert(progress_calls[0] >= 2, "Callback de progresso deve ter sido chamado")
	
	assert(FileAccess.file_exists(extract_dest.path_join("CepaSelvagem.exe")), "Executável extraído no destino")
	assert(FileAccess.file_exists(extract_dest.path_join("subfolder/data.txt")), "Arquivo em subpasta extraído no destino")
	
	# Cleanup
	_Patcher.cleanup(zip_path)
	_Patcher.cleanup(test_file_path)
	_Patcher.cleanup(extract_dest.path_join("CepaSelvagem.exe"))
	_Patcher.cleanup(extract_dest.path_join("subfolder/data.txt"))
	assert(not FileAccess.file_exists(zip_path), "ZIP temporário limpo com sucesso")
	
	print("  -> Verificação SHA-256 e extração recursiva de ZIP validadas com perfeição.")

func test_game_runner() -> void:
	print("\n[5/6] GameRunner e Busca de Executável...")
	
	var fake_path: String = "user://fake_game_dir/CepaSelvagem.exe"
	assert(not _GameRunner.is_game_installed(fake_path), "Caminho inexistente deve reportar não instalado")
	
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
