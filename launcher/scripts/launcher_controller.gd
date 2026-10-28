class_name LauncherController
extends Control

## Controlador principal de interface e fluxo do Launcher de Cepas Selvagens.

const _LauncherConfig = preload("res://scripts/launcher_config.gd")
const _VersionChecker = preload("res://scripts/version_checker.gd")
const _Downloader = preload("res://scripts/downloader.gd")
const _Patcher = preload("res://scripts/patcher.gd")
const _GameRunner = preload("res://scripts/game_runner.gd")

enum State {
	INITIALIZING,
	CHECKING_UPDATES,
	READY_TO_PLAY,
	UPDATE_AVAILABLE,
	NOT_INSTALLED,
	DOWNLOADING,
	EXTRACTING,
	ERROR,
	LAUNCHING
}

var current_state: State = State.INITIALIZING

var _config: _LauncherConfig
var _checker: _VersionChecker
var _downloader: _Downloader

var _remote_info: Dictionary = {}
var _temp_download_path: String = ""

@onready var status_label: Label = %StatusLabel
@onready var substatus_label: Label = %SubstatusLabel
@onready var progress_bar: ProgressBar = %ProgressBar
@onready var action_button: Button = %ActionButton
@onready var check_updates_button: Button = %CheckUpdatesButton
@onready var open_folder_button: Button = %OpenFolderButton
@onready var website_button: Button = %WebsiteButton

@onready var installed_version_label: Label = %InstalledVersionLabel
@onready var latest_version_label: Label = %LatestVersionLabel
@onready var server_info_label: Label = %ServerInfoLabel
@onready var news_rich_text: RichTextLabel = %NewsRichText

func _ready() -> void:
	_config = _LauncherConfig.new()
	
	_checker = _VersionChecker.new()
	add_child(_checker)
	_checker.check_completed.connect(_on_check_completed)
	_checker.check_failed.connect(_on_check_failed)
	
	_downloader = _Downloader.new()
	add_child(_downloader)
	_downloader.download_progress.connect(_on_download_progress)
	_downloader.download_completed.connect(_on_download_completed)
	_downloader.download_failed.connect(_on_download_failed)
	
	action_button.pressed.connect(_on_action_button_pressed)
	check_updates_button.pressed.connect(start_update_check)
	open_folder_button.pressed.connect(_on_open_folder_pressed)
	website_button.pressed.connect(_on_website_pressed)
	
	_update_static_ui()
	start_update_check()

func _update_static_ui() -> void:
	var local_ver: String = _config.read_installed_version()
	var is_installed: bool = _GameRunner.is_game_installed(_config.get_executable_path())
	
	if is_installed:
		installed_version_label.text = "Instalado: v%s" % local_ver
	else:
		installed_version_label.text = "Instalado: Nenhum"
	
	latest_version_label.text = "Disponível: Verificando..."
	server_info_label.text = "Servidor Oficial: %s:%d" % [_LauncherConfig.DEFAULT_SERVER_HOST, _LauncherConfig.DEFAULT_SERVER_PORT]
	
	news_rich_text.text = "[b]Conectando ao repositório oficial...[/b]\nBuscando as últimas atualizações de [i]Cepas Selvagens[/i]."

func start_update_check() -> void:
	_set_state(State.CHECKING_UPDATES)
	status_label.text = "Verificando se há atualizações disponíveis..."
	substatus_label.text = "Consultando repositório oficial no GitHub..."
	progress_bar.value = 0
	progress_bar.indeterminate = true
	
	_checker.check_for_updates(_config.github_repo, _config.custom_manifest_url)

func _on_check_completed(info: Dictionary) -> void:
	_remote_info = info
	progress_bar.indeterminate = false
	
	var remote_ver: String = str(info.get("version", "0.0.0"))
	var local_ver: String = _config.read_installed_version()
	var is_installed: bool = _GameRunner.is_game_installed(_config.get_executable_path())
	
	latest_version_label.text = "Disponível: v%s" % remote_ver
	
	# Monta painel de notícias e changelog formatado com BBCode
	var changelog_text: String = str(info.get("changelog", "")).strip_edges()
	var title: String = str(info.get("title", "Versão " + remote_ver))
	var bb: String = "[font_size=18][color=#b8e994][b]%s[/b][/color][/font_size]\n" % title
	if info.get("release_date"):
		bb += "[color=#7f8c8d][i]Lançado em: %s[/i][/color]\n\n" % str(info["release_date"]).substr(0, 10)
	
	if changelog_text.is_empty():
		bb += "Melhorias de desempenho, correções e novos conteúdos do ecossistema selvagem."
	else:
		bb += changelog_text
	
	news_rich_text.text = bb
	
	var comparison: int = _VersionChecker.compare_versions(local_ver, remote_ver)
	
	if not is_installed:
		_set_state(State.NOT_INSTALLED)
		status_label.text = "O jogo ainda não está instalado."
		substatus_label.text = "Clique abaixo para baixar e instalar a versão v%s automaticamente." % remote_ver
	elif comparison < 0:
		_set_state(State.UPDATE_AVAILABLE)
		status_label.text = "Nova atualização disponível: v%s!" % remote_ver
		substatus_label.text = "Sua versão: v%s. Clique em Atualizar para sincronizar com o servidor." % local_ver
	else:
		_set_state(State.READY_TO_PLAY)
		status_label.text = "Seu jogo está 100% atualizado!"
		substatus_label.text = "Versão instalada: v%s. Pronto para explorar o ermo." % local_ver

func _on_check_failed(error_msg: String) -> void:
	progress_bar.indeterminate = false
	var is_installed: bool = _GameRunner.is_game_installed(_config.get_executable_path())
	
	if is_installed:
		# Modo offline: se o jogo já está no disco, permite jogar mesmo sem internet ou com rate limit 403
		_set_state(State.READY_TO_PLAY)
		var local_ver: String = _config.read_installed_version()
		status_label.text = "Modo Offline (Verificação indisponível)"
		substatus_label.text = "%s. Você pode jogar a versão instalada (v%s)." % [error_msg, local_ver]
		latest_version_label.text = "Disponível: Offline"
	else:
		_set_state(State.ERROR)
		status_label.text = "Erro ao verificar atualizações"
		substatus_label.text = error_msg
		latest_version_label.text = "Disponível: Indisponível"
	
	news_rich_text.text = "[color=#e74c3c][b]Aviso de Conexão:[/b][/color]\n" + error_msg + "\n\nSe estiver sem internet ou com limite de requisições, você pode tentar novamente mais tarde."

func _on_action_button_pressed() -> void:
	match current_state:
		State.READY_TO_PLAY:
			_launch_game()
		
		State.UPDATE_AVAILABLE, State.NOT_INSTALLED:
			_start_download()
		
		State.DOWNLOADING:
			_downloader.cancel_download()
			_set_state(State.READY_TO_PLAY if _GameRunner.is_game_installed(_config.get_executable_path()) else State.NOT_INSTALLED)
		
		State.ERROR:
			start_update_check()

func _start_download() -> void:
	# Valida se o jogo está em execução antes de iniciar
	if _GameRunner.is_game_running(_config.get_executable_path()):
		status_label.text = "O jogo já está em execução!"
		substatus_label.text = "Feche o Cepas Selvagens antes de iniciar a atualização."
		return
	
	var url: String = str(_remote_info.get("download_url", "")).strip_edges()
	if url.is_empty():
		_set_state(State.ERROR)
		status_label.text = "Erro: URL de download não encontrada na release."
		return
	
	var expected_size: int = int(_remote_info.get("size_bytes", 0))
	_temp_download_path = _config.get_absolute_game_dir().path_join("update_download.zip")
	
	_set_state(State.DOWNLOADING)
	status_label.text = "Baixando Cepas Selvagens v%s..." % str(_remote_info.get("version", ""))
	substatus_label.text = "Iniciando conexão de download..."
	progress_bar.value = 0.0
	
	_downloader.start_download(url, _temp_download_path, expected_size)

func _on_download_progress(downloaded: int, total: int, percent: float, speed_bps: float, eta_seconds: float) -> void:
	progress_bar.value = percent
	
	var down_str: String = _Downloader.format_bytes(downloaded)
	var tot_str: String = _Downloader.format_bytes(total) if total > 0 else "?"
	var speed_str: String = _Downloader.format_speed(speed_bps)
	var eta_str: String = _Downloader.format_time(eta_seconds) if eta_seconds > 0 else "--"
	
	substatus_label.text = "%s / %s (%.1f%%) • %s • Restante: %s" % [down_str, tot_str, percent, speed_str, eta_str]

func _on_download_failed(error_msg: String) -> void:
	_set_state(State.ERROR)
	status_label.text = "Falha no download da atualização."
	substatus_label.text = error_msg
	progress_bar.value = 0.0

func _on_download_completed(downloaded_file: String) -> void:
	# Valida se o jogo foi aberto durante o download
	if _GameRunner.is_game_running(_config.get_executable_path()):
		_set_state(State.ERROR)
		status_label.text = "O jogo foi aberto durante o processo!"
		substatus_label.text = "Feche o Cepas Selvagens antes de extrair a atualização."
		progress_bar.indeterminate = false
		return
	
	_set_state(State.EXTRACTING)
	status_label.text = "Validando e instalando arquivos..."
	substatus_label.text = "Verificando integridade SHA-256 e descompactando..."
	progress_bar.indeterminate = true
	
	# Valida SHA-256 estritamente: sem hash ou com hash diferente, RECUSA e apaga
	var expected_sha: String = str(_remote_info.get("sha256", "")).strip_edges().to_lower()
	if expected_sha.is_empty() or not _Patcher.verify_sha256(downloaded_file, expected_sha):
		_set_state(State.ERROR)
		status_label.text = "Erro de integridade do pacote"
		substatus_label.text = "O hash SHA-256 é inválido ou ausente. O download foi descartado por segurança."
		_Patcher.cleanup(downloaded_file)
		progress_bar.indeterminate = false
		return
	
	# Extrai arquivos para o diretório de destino de forma atômica
	var target_dir: String = _config.get_absolute_game_dir()
	var extract_result: Dictionary = _Patcher.extract_zip(downloaded_file, target_dir)
	progress_bar.indeterminate = false
	
	if not extract_result.get("success", false):
		_set_state(State.ERROR)
		status_label.text = "Erro ao descompactar atualização"
		substatus_label.text = str(extract_result.get("error", "Falha desconhecida."))
		_Patcher.cleanup(downloaded_file)
		return
	
	# Remove zip temporário
	_Patcher.cleanup(downloaded_file)
	
	# Salva a nova versão localmente
	var new_ver: String = str(_remote_info.get("version", "0.1.1"))
	_config.write_installed_version(new_ver)
	
	installed_version_label.text = "Instalado: v%s" % new_ver
	progress_bar.value = 100.0
	
	_set_state(State.READY_TO_PLAY)
	status_label.text = "Instalação concluída com sucesso!"
	substatus_label.text = "Versão v%s pronta para jogar." % new_ver
	
	if _config.auto_play_on_ready:
		_launch_game()

func _launch_game() -> void:
	_set_state(State.LAUNCHING)
	status_label.text = "Iniciando Cepas Selvagens..."
	substatus_label.text = "Abrindo o jogo e conectando ao mundo..."
	
	var res: Dictionary = _GameRunner.launch_game(_config.get_executable_path())
	if not res.get("success", false):
		_set_state(State.ERROR)
		status_label.text = "Falha ao iniciar o jogo"
		substatus_label.text = str(res.get("error", "Executável não encontrado."))
		return
	
	if _config.close_launcher_on_play:
		# Aguarda breve instante para o processo filho subir antes de fechar o launcher
		await get_tree().create_timer(1.2).timeout
		get_tree().quit()
	else:
		_set_state(State.READY_TO_PLAY)
		status_label.text = "Jogo em execução (PID: %d)" % int(res.get("pid", 0))

func _on_open_folder_pressed() -> void:
	_GameRunner.open_game_folder(_config.get_absolute_game_dir())

func _on_website_pressed() -> void:
	OS.shell_open(_LauncherConfig.DEFAULT_WEBSITE_URL)

func _set_state(new_state: State) -> void:
	current_state = new_state
	
	match current_state:
		State.CHECKING_UPDATES:
			action_button.text = "Verificando..."
			action_button.disabled = true
			check_updates_button.disabled = true
		
		State.READY_TO_PLAY:
			action_button.text = "▶ JOGAR"
			action_button.disabled = false
			check_updates_button.disabled = false
		
		State.UPDATE_AVAILABLE:
			action_button.text = "⬇ ATUALIZAR"
			action_button.disabled = false
			check_updates_button.disabled = false
		
		State.NOT_INSTALLED:
			action_button.text = "⬇ BAIXAR JOGO"
			action_button.disabled = false
			check_updates_button.disabled = false
		
		State.DOWNLOADING:
			action_button.text = "✕ CANCELAR"
			action_button.disabled = false
			check_updates_button.disabled = true
		
		State.EXTRACTING:
			action_button.text = "INSTALANDO..."
			action_button.disabled = true
			check_updates_button.disabled = true
		
		State.ERROR:
			action_button.text = "TENTAR NOVAMENTE"
			action_button.disabled = false
			check_updates_button.disabled = false
		
		State.LAUNCHING:
			action_button.text = "INICIANDO..."
			action_button.disabled = true
			check_updates_button.disabled = true
