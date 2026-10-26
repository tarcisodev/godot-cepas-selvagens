extends SceneTree

## Suíte de Testes Automatizados do Launcher de Cepas Selvagens.

const _LauncherConfig = preload("res://scripts/launcher_config.gd")
const _VersionChecker = preload("res://scripts/version_checker.gd")
const _Downloader = preload("res://scripts/downloader.gd")
const _Patcher = preload("res://scripts/patcher.gd")
const _LauncherMain = preload("res://scripts/launcher_main.gd")

var _started := false

func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false

func _run() -> void:
	print("\n========================================================")
	print("🚀 TESTANDO LAUNCHER OFICIAL DE CEPAS SELVAGENS")
	print("========================================================")
	test_launcher_config()
	test_version_checker()
	test_downloader_formatting()
	test_patcher_integrity_and_zip()
	test_launcher_main_states()
	print("\n🎉 TODOS OS TESTES DO LAUNCHER PASSARAM COM SUCESSO!")
	print("========================================================\n")
	quit(0)

func test_launcher_config() -> void:
	print("\n[1/5] LauncherConfig: Caminhos, Versionamento e Configurações...")
	var config := _LauncherConfig.new()
	assert(not config.get_executable_path().is_empty(), "Caminho do executável gerado")
	assert(not config.get_local_version_file_path().is_empty(), "Caminho do version.json gerado")
	assert(config.github_repo == "tarcisodev/godot-cepas-selvagens", "Repositório padrão configurado")
	assert(config.DEFAULT_SERVER_HOST == "jogar.tarciso.dev", "Host do servidor padrão correto")
	assert(config.DEFAULT_SERVER_PORT == 8787, "Porta do servidor padrão correta")

	# Teste de escrita e leitura de versão
	config.write_installed_version("0.1.5")
	var read_v := config.read_installed_version()
	assert(read_v == "0.1.5", "Versão instalada lida com sucesso")

	# Teste de persistência de configurações
	config.game_directory = "custom_game_dir"
	config.auto_play_on_ready = true
	config.save_settings()

	var config2 := _LauncherConfig.new()
	assert(config2.game_directory == "custom_game_dir", "Configuração de pasta persistida")
	assert(config2.auto_play_on_ready == true, "Configuração de auto play persistida")

	# Limpeza de teste
	config.game_directory = "game"
	config.auto_play_on_ready = false
	config.save_settings()
	print("  -> Caminhos locais, version.json e persistência validados.")

func test_version_checker() -> void:
	print("\n[2/5] VersionChecker: Comparação Semântica e Parsing de Releases...")
	# Comparação semântica
	assert(_VersionChecker.clean_version("v1.2.3") == "1.2.3", "Limpeza de prefixo 'v'")
	assert(_VersionChecker.clean_version("V0.1.0-alpha") == "0.1.0-alpha", "Limpeza de maiúsculo 'V'")

	assert(_VersionChecker.compare_versions("0.1.0", "0.2.0") == -1, "0.1.0 < 0.2.0")
	assert(_VersionChecker.compare_versions("0.2.0", "0.1.0") == 1, "0.2.0 > 0.1.0")
	assert(_VersionChecker.compare_versions("0.1.0", "0.1.0") == 0, "0.1.0 == 0.1.0")
	assert(_VersionChecker.compare_versions("1.0.0", "0.9.9") == 1, "1.0.0 > 0.9.9")
	assert(_VersionChecker.compare_versions("v0.1.5", "0.1.5") == 0, "v0.1.5 == 0.1.5")

	# Parsing de manifesto customizado direto
	var custom_manifest := {
		"version": "v0.2.0",
		"title": "Atualização Grande",
		"changelog": "Adicionado novo mapa e forja",
		"download_url": "https://cepas.tarciso.dev/builds/cepa_windows.zip",
		"sha256": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
		"size_bytes": 104857600
	}
	var parsed_custom := _VersionChecker.parse_release_data(custom_manifest)
	assert(parsed_custom.version == "0.2.0", "Versão do manifesto lida")
	assert(parsed_custom.download_url == custom_manifest.download_url, "URL do manifesto lida")
	assert(parsed_custom.size_bytes == 104857600, "Tamanho em bytes lido")

	# Parsing de GitHub Release API mock
	var github_release := {
		"tag_name": "v0.1.0",
		"name": "Playtest v0.1.0 Oficial",
		"body": "- Primeira versão jogável",
		"assets": [
			{
				"name": "CepaSelvagem_v0.1.0_Windows.zip",
				"browser_download_url": "https://github.com/tarcisodev/godot-cepas-selvagens/releases/download/v0.1.0/CepaSelvagem_v0.1.0_Windows.zip",
				"size": 52428800
			}
		]
	}
	var parsed_gh := _VersionChecker.parse_release_data(github_release)
	assert(parsed_gh.version == "0.1.0", "Versão da release do GitHub lida")
	assert(parsed_gh.asset_name == "CepaSelvagem_v0.1.0_Windows.zip", "Ativo Windows selecionado")
	assert(parsed_gh.size_bytes == 52428800, "Tamanho do ativo correto")
	print("  -> Versões semânticas e parsing de manifests/Releases validados.")

func test_downloader_formatting() -> void:
	print("\n[3/5] Downloader: Cálculos de Formatação e ETA...")
	assert(_Downloader.format_bytes(512) == "512 B", "Bytes")
	assert(_Downloader.format_bytes(1024 * 15) == "15.0 KB", "Kilobytes")
	assert(_Downloader.format_bytes(1024 * 1024 * 45) == "45.0 MB", "Megabytes")
	assert(_Downloader.format_bytes(1024 * 1024 * 1024 * 2) == "2.00 GB", "Gigabytes")

	assert(_Downloader.format_speed(1024 * 1024 * 3) == "3.0 MB/s", "Velocidade MB/s")
	assert(_Downloader.format_time(45) == "45s", "Tempo em segundos")
	assert(_Downloader.format_time(125) == "2m 05s", "Tempo em minutos e segundos")
	print("  -> Formatadores de bytes, velocidade e ETA validados.")

func test_patcher_integrity_and_zip() -> void:
	print("\n[4/5] Patcher: Verificação SHA-256 e ZIPReader...")
	# Cria um arquivo de teste para validação de SHA-256
	var test_file := "user://test_patcher_data.txt"
	var f := FileAccess.open(test_file, FileAccess.WRITE)
	f.store_string("Cepas Selvagens Test Integrity 2026")
	f.close()

	var actual_sha := FileAccess.get_sha256(test_file).to_lower()
	assert(_Patcher.verify_sha256(test_file, actual_sha), "SHA-256 idêntico aceito")
	assert(not _Patcher.verify_sha256(test_file, "1111222233334444555566667777888899990000aaaa"), "SHA-256 divergente rejeitado")
	assert(_Patcher.verify_sha256(test_file, ""), "SHA-256 vazio aceito como opcional")

	DirAccess.remove_absolute(test_file)

	# Teste de extração com arquivo inexistente
	var res := _Patcher.extract_zip("user://non_existent.zip", "user://test_dest/")
	assert(not res.success, "Extração de arquivo inexistente falha graciosamente")
	assert(not res.error.is_empty(), "Mensagem de erro retornada")
	print("  -> Validação criptográfica de SHA-256 e integridade de arquivos validados.")

func test_launcher_main_states() -> void:
	print("\n[5/5] LauncherMain: Estados da Interface e Fluxo de Execução...")
	var launcher := _LauncherMain.new()
	root.add_child(launcher)

	# Simulação de resposta de versão disponível
	var mock_info := {
		"version": "0.9.0",
		"download_url": "https://example.com/build.zip",
		"changelog": "Versão de teste automatizada",
		"size_bytes": 1024
	}
	launcher._on_version_check_completed(mock_info)

	assert(launcher.current_state == _LauncherMain.State.UPDATE_AVAILABLE, "Estado transiciona para UPDATE_AVAILABLE quando há versão mais nova")
	assert(launcher._action_button.text.begins_with("⬇ ATUALIZAR"), "Botão atualiza texto de ação")

	# Simulação de versão já atualizada
	launcher.config.write_installed_version("0.9.0")
	# Cria mock temporário do executável
	var exe_path := launcher.config.get_executable_path()
	var parent_dir := exe_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(parent_dir):
		DirAccess.make_dir_recursive_absolute(parent_dir)
	var exe_file := FileAccess.open(exe_path, FileAccess.WRITE)
	exe_file.store_string("mock exe")
	exe_file.close()

	launcher._on_version_check_completed(mock_info)
	assert(launcher.current_state == _LauncherMain.State.READY_TO_PLAY, "Estado transiciona para READY_TO_PLAY quando versão bate e exe existe")
	assert(launcher._action_button.text == "▶ JOGAR", "Botão exibe '▶ JOGAR'")

	# Limpeza
	DirAccess.remove_absolute(exe_path)
	launcher.queue_free()
	print("  -> Máquina de estados do launcher e fluxo de atualização validados.")
