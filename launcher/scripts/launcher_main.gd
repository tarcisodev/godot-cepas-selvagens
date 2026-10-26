class_name LauncherMain
extends Control

## Controlador principal e interface do Launcher de Cepas Selvagens.
## Coordena verificação de versão, download, integridade, descompactação e execução do jogo.

const _LauncherConfig = preload("res://scripts/launcher_config.gd")
const _VersionChecker = preload("res://scripts/version_checker.gd")
const _Downloader = preload("res://scripts/downloader.gd")
const _Patcher = preload("res://scripts/patcher.gd")

enum State {
	IDLE,
	CHECKING_VERSION,
	READY_TO_PLAY,
	UPDATE_AVAILABLE,
	DOWNLOADING,
	VERIFYING,
	EXTRACTING,
	LAUNCHING,
	ERROR
}

var config: _LauncherConfig
var version_checker: _VersionChecker
var downloader: _Downloader

var current_state: State = State.IDLE
var remote_release_info: Dictionary = {}

# Elementos de UI
var _status_label: Label
var _version_label: Label
var _server_label: Label
var _progress_bar: ProgressBar
var _progress_details_label: Label
var _action_button: Button
var _settings_button: Button
var _website_button: Button
var _notes_text: RichTextLabel
var _settings_dialog: PanelContainer

# Campos de configurações
var _input_game_dir: LineEdit
var _input_repo: LineEdit
var _check_close_on_play: CheckBox

func _ready() -> void:
	config = _LauncherConfig.new()
	version_checker = _VersionChecker.new()
	add_child(version_checker)
	version_checker.check_completed.connect(_on_version_check_completed)
	version_checker.check_failed.connect(_on_version_check_failed)

	downloader = _Downloader.new()
	add_child(downloader)
	downloader.download_progress.connect(_on_download_progress)
	downloader.download_completed.connect(_on_download_completed)
	downloader.download_failed.connect(_on_download_failed)

	_build_ui()
	_update_installed_version_display()
	start_version_check()

func start_version_check() -> void:
	_set_state(State.CHECKING_VERSION)
	_status_label.text = "Buscando atualizações..."
	version_checker.check_for_updates(config.github_repo, config.custom_manifest_url)

func _set_state(new_state: State) -> void:
	current_state = new_state
	_refresh_ui_for_state()

func _refresh_ui_for_state() -> void:
	match current_state:
		State.CHECKING_VERSION:
			_action_button.disabled = true
			_action_button.text = "VERIFICANDO..."
			_progress_bar.visible = false
			_progress_details_label.visible = false

		State.READY_TO_PLAY:
			_action_button.disabled = false
			_action_button.text = "▶ JOGAR"
			_action_button.modulate = Color(0.3, 1.2, 0.5)
			_status_label.text = "O jogo está atualizado e pronto para jogar."
			_progress_bar.visible = false
			_progress_details_label.visible = false
			if config.auto_play_on_ready:
				launch_game()

		State.UPDATE_AVAILABLE:
			_action_button.disabled = false
			var v_name: String = remote_release_info.get("version", "")
			_action_button.text = "⬇ ATUALIZAR (v%s)" % v_name if not v_name.is_empty() else "⬇ INSTALAR"
			_action_button.modulate = Color(1.2, 0.9, 0.3)
			_status_label.text = "Nova versão disponível: v%s" % v_name
			_progress_bar.visible = false
			_progress_details_label.visible = false

		State.DOWNLOADING:
			_action_button.disabled = true
			_action_button.text = "BAIXANDO..."
			_action_button.modulate = Color(0.5, 0.8, 1.2)
			_progress_bar.visible = true
			_progress_details_label.visible = true

		State.VERIFYING:
			_action_button.disabled = true
			_action_button.text = "VERIFICANDO..."
			_status_label.text = "Validando integridade criptográfica (SHA-256)..."
			_progress_bar.visible = true
			_progress_bar.value = 100.0
			_progress_details_label.visible = false

		State.EXTRACTING:
			_action_button.disabled = true
			_action_button.text = "INSTALANDO..."
			_status_label.text = "Descompactando arquivos do jogo..."
			_progress_bar.visible = true
			_progress_details_label.visible = false

		State.LAUNCHING:
			_action_button.disabled = true
			_action_button.text = "INICIANDO..."
			_status_label.text = "Executando Cepas Selvagens..."

		State.ERROR:
			_action_button.disabled = false
			_action_button.text = "🔄 TENTAR NOVAMENTE"
			_action_button.modulate = Color(1.2, 0.4, 0.4)
			_progress_bar.visible = false
			_progress_details_label.visible = false

func _on_action_button_pressed() -> void:
	match current_state:
		State.READY_TO_PLAY:
			launch_game()
		State.UPDATE_AVAILABLE:
			start_update_download()
		State.ERROR:
			start_version_check()
		_:
			pass

func launch_game() -> bool:
	var exe_path := config.get_executable_path()
	if not FileAccess.file_exists(exe_path):
		_status_label.text = "Executável não encontrado em: %s" % exe_path
		_set_state(State.UPDATE_AVAILABLE)
		return false

	_set_state(State.LAUNCHING)
	
	# Parâmetros de inicialização automática no servidor oficial
	var args: PackedStringArray = PackedStringArray([
		"--connect-to", "%s:%d" % [config.DEFAULT_SERVER_HOST, config.DEFAULT_SERVER_PORT]
	])
	
	var pid := OS.create_process(exe_path, args)
	if pid <= 0:
		_status_label.text = "Falha ao iniciar o processo do jogo."
		_set_state(State.ERROR)
		return false

	if config.close_launcher_on_play:
		get_tree().quit()
	else:
		_status_label.text = "Jogo em execução (PID: %d)" % pid
		_set_state(State.READY_TO_PLAY)
	return true

func start_update_download() -> void:
	var url: String = remote_release_info.get("download_url", "")
	if url.is_empty():
		_status_label.text = "URL de download inválida no pacote de lançamento."
		_set_state(State.ERROR)
		return

	var temp_zip_path := "user://temp_update.zip"
	var expected_size: int = int(remote_release_info.get("size_bytes", 0))
	_set_state(State.DOWNLOADING)
	downloader.start_download(url, temp_zip_path, expected_size)

func _on_download_progress(downloaded: int, total: int, percent: float, speed: float, eta: float) -> void:
	_progress_bar.value = percent
	var down_str := _Downloader.format_bytes(downloaded)
	var tot_str := _Downloader.format_bytes(total) if total > 0 else "..."
	var spd_str := _Downloader.format_speed(speed)
	var eta_str := _Downloader.format_time(eta) if eta > 0 else "--"

	_status_label.text = "Baixando atualização: %s / %s (%s)" % [down_str, tot_str, spd_str]
	_progress_details_label.text = "%.1f%% · Tempo estimado restante: %s" % [percent, eta_str]

func _on_download_completed(zip_path: String) -> void:
	_set_state(State.VERIFYING)
	
	# 1. Verificação de integridade SHA-256
	var expected_sha: String = remote_release_info.get("sha256", "")
	if not expected_sha.is_empty():
		if not _Patcher.verify_sha256(zip_path, expected_sha):
			DirAccess.remove_absolute(zip_path)
			_status_label.text = "Erro: Assinatura SHA-256 do arquivo corrompida."
			_set_state(State.ERROR)
			return

	# 2. Descompactação dos arquivos do jogo
	_set_state(State.EXTRACTING)
	var target_dir := config.get_absolute_game_dir()
	var extract_result := _Patcher.extract_zip(zip_path, target_dir)

	# Remove o arquivo temporário
	if FileAccess.file_exists(zip_path):
		DirAccess.remove_absolute(zip_path)

	if not extract_result.get("success", false):
		_status_label.text = "Erro na instalação: %s" % extract_result.get("error", "Desconhecido")
		_set_state(State.ERROR)
		return

	# 3. Atualiza versão gravada no version.json
	var new_v: String = remote_release_info.get("version", "0.1.0")
	config.write_installed_version(new_v)
	_update_installed_version_display()

	_status_label.text = "Instalação concluída com sucesso! (%d arquivos)" % int(extract_result.get("files_extracted", 0))
	_set_state(State.READY_TO_PLAY)

func _on_download_failed(err_msg: String) -> void:
	_status_label.text = "Falha no download: %s" % err_msg
	_set_state(State.ERROR)

func _on_version_check_completed(info: Dictionary) -> void:
	remote_release_info = info
	var remote_v: String = info.get("version", "0.0.0")
	var installed_v := config.read_installed_version()
	_update_installed_version_display()

	# Atualiza changelog / notas de release na tela
	var notes: String = info.get("changelog", "")
	if not notes.is_empty() and _notes_text:
		_notes_text.text = "[b]Novidades da Versão %s:[/b]\n\n%s" % [remote_v, notes]

	var cmp := _VersionChecker.compare_versions(installed_v, remote_v)
	var exe_exists := FileAccess.file_exists(config.get_executable_path())

	if cmp < 0 or not exe_exists:
		_set_state(State.UPDATE_AVAILABLE)
	else:
		_set_state(State.READY_TO_PLAY)

func _on_version_check_failed(err_msg: String) -> void:
	# Se a verificação falhar, mas o jogo local já existir, permite jogar offline
	var exe_exists := FileAccess.file_exists(config.get_executable_path())
	if exe_exists:
		_status_label.text = "Aviso: Sem conexão com servidor de versão. Modo offline pronto."
		_set_state(State.READY_TO_PLAY)
	else:
		_status_label.text = "Erro ao buscar versão: %s" % err_msg
		_set_state(State.ERROR)

func _update_installed_version_display() -> void:
	if _version_label:
		var v := config.read_installed_version()
		_version_label.text = "Versão Instalada: v%s" % v

# ---------------------------------------------------------------- Construção de UI

func _build_ui() -> void:
	# Fundo estilizado com gradiente escuro de fantasia
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.05, 0.08)
	bg.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg)

	var main_vbox := VBoxContainer.new()
	main_vbox.set_anchors_preset(PRESET_FULL_RECT)
	main_vbox.add_theme_constant_override("separation", 0)
	add_child(main_vbox)

	# 1. Barra de Topo
	var top_bar := PanelContainer.new()
	var top_sb := StyleBoxFlat.new()
	top_sb.bg_color = Color(0.09, 0.08, 0.12, 0.95)
	top_sb.content_margin_left = 24
	top_sb.content_margin_right = 24
	top_sb.content_margin_top = 16
	top_sb.content_margin_bottom = 16
	top_bar.add_theme_stylebox_override("panel", top_sb)
	main_vbox.add_child(top_bar)

	var top_hbox := HBoxContainer.new()
	top_bar.add_child(top_hbox)

	var brand_title := Label.new()
	brand_title.text = "CEPAS SELVAGENS"
	brand_title.add_theme_font_size_override("font_size", 22)
	brand_title.add_theme_color_override("font_color", Color(0.92, 0.78, 0.55))
	top_hbox.add_child(brand_title)

	var brand_sub := Label.new()
	brand_sub.text = " · Launcher & Atualizador Oficial"
	brand_sub.add_theme_font_size_override("font_size", 13)
	brand_sub.add_theme_color_override("font_color", Color(0.65, 0.65, 0.7))
	top_hbox.add_child(brand_sub)

	var spacer := Control.new()
	spacer.size_flags_horizontal = SIZE_EXPAND_FILL
	top_hbox.add_child(spacer)

	_server_label = Label.new()
	_server_label.text = "🟢 Servidor Oficial: %s" % config.DEFAULT_SERVER_HOST
	_server_label.add_theme_font_size_override("font_size", 12)
	_server_label.add_theme_color_override("font_color", Color(0.4, 0.85, 0.5))
	top_hbox.add_child(_server_label)

	_website_button = Button.new()
	_website_button.text = " 🌐 Site "
	_website_button.pressed.connect(func(): OS.shell_open(config.DEFAULT_WEBSITE_URL))
	top_hbox.add_child(_website_button)

	_settings_button = Button.new()
	_settings_button.text = " ⚙ Configurações "
	_settings_button.pressed.connect(_toggle_settings)
	top_hbox.add_child(_settings_button)

	# 2. Painel Central (Notas de Atualização & Arte)
	var center_margin := MarginContainer.new()
	center_margin.size_flags_vertical = SIZE_EXPAND_FILL
	center_margin.add_theme_constant_override("margin_left", 24)
	center_margin.add_theme_constant_override("margin_right", 24)
	center_margin.add_theme_constant_override("margin_top", 16)
	center_margin.add_theme_constant_override("margin_bottom", 16)
	main_vbox.add_child(center_margin)

	var center_panel := PanelContainer.new()
	var c_sb := StyleBoxFlat.new()
	c_sb.bg_color = Color(0.11, 0.1, 0.15, 0.85)
	c_sb.corner_radius_top_left = 6
	c_sb.corner_radius_top_right = 6
	c_sb.corner_radius_bottom_left = 6
	c_sb.corner_radius_bottom_right = 6
	c_sb.content_margin_left = 20
	c_sb.content_margin_right = 20
	c_sb.content_margin_top = 16
	c_sb.content_margin_bottom = 16
	center_panel.add_theme_stylebox_override("panel", c_sb)
	center_margin.add_child(center_panel)

	_notes_text = RichTextLabel.new()
	_notes_text.bbcode_enabled = true
	_notes_text.text = "[b]Bem-vindo a Cepas Selvagens![/b]\n\nExplore o vale aberto, monte seu acampamento, cace presas ancestrais e forje seus equipamentos.\n\nConectando aos servidores oficiais para sincronizar dados da versão..."
	center_panel.add_child(_notes_text)

	# 3. Barra Inferior de Ação
	var bottom_bar := PanelContainer.new()
	var b_sb := StyleBoxFlat.new()
	b_sb.bg_color = Color(0.08, 0.07, 0.11, 0.98)
	b_sb.border_color = Color(0.2, 0.18, 0.28)
	b_sb.border_width_top = 1
	b_sb.content_margin_left = 24
	b_sb.content_margin_right = 24
	b_sb.content_margin_top = 16
	b_sb.content_margin_bottom = 16
	bottom_bar.add_theme_stylebox_override("panel", b_sb)
	main_vbox.add_child(bottom_bar)

	var bottom_hbox := HBoxContainer.new()
	bottom_hbox.add_theme_constant_override("separation", 20)
	bottom_bar.add_child(bottom_hbox)

	var status_vbox := VBoxContainer.new()
	status_vbox.size_flags_horizontal = SIZE_EXPAND_FILL
	status_vbox.add_theme_constant_override("separation", 4)
	bottom_hbox.add_child(status_vbox)

	var status_top_hbox := HBoxContainer.new()
	status_vbox.add_child(status_top_hbox)

	_status_label = Label.new()
	_status_label.text = "Iniciando launcher..."
	_status_label.size_flags_horizontal = SIZE_EXPAND_FILL
	_status_label.add_theme_font_size_override("font_size", 13)
	status_top_hbox.add_child(_status_label)

	_version_label = Label.new()
	_version_label.text = "Versão Instalada: v0.0.0"
	_version_label.add_theme_font_size_override("font_size", 12)
	_version_label.add_theme_color_override("font_color", Color(0.65, 0.65, 0.7))
	status_top_hbox.add_child(_version_label)

	_progress_bar = ProgressBar.new()
	_progress_bar.custom_minimum_size = Vector2(0, 14)
	_progress_bar.show_percentage = false
	status_vbox.add_child(_progress_bar)

	_progress_details_label = Label.new()
	_progress_details_label.text = ""
	_progress_details_label.add_theme_font_size_override("font_size", 11)
	_progress_details_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	status_vbox.add_child(_progress_details_label)

	# Botão de Ação Principal (JOGAR / ATUALIZAR)
	_action_button = Button.new()
	_action_button.text = "VERIFICANDO..."
	_action_button.custom_minimum_size = Vector2(220, 52)
	_action_button.add_theme_font_size_override("font_size", 17)
	_action_button.pressed.connect(_on_action_button_pressed)
	bottom_hbox.add_child(_action_button)

	_build_settings_dialog()

func _build_settings_dialog() -> void:
	_settings_dialog = PanelContainer.new()
	_settings_dialog.visible = false
	_settings_dialog.set_anchors_preset(PRESET_CENTER)
	_settings_dialog.custom_minimum_size = Vector2(500, 320)
	
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.11, 0.17, 0.98)
	sb.border_color = Color(0.5, 0.4, 0.7)
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_width_top = 2
	sb.border_width_bottom = 2
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 16
	sb.content_margin_bottom = 16
	_settings_dialog.add_theme_stylebox_override("panel", sb)
	add_child(_settings_dialog)

	var svbox := VBoxContainer.new()
	svbox.add_theme_constant_override("separation", 12)
	_settings_dialog.add_child(svbox)

	var stitle := Label.new()
	stitle.text = "Configurações do Launcher"
	stitle.add_theme_font_size_override("font_size", 16)
	svbox.add_child(stitle)

	var lbl_dir := Label.new()
	lbl_dir.text = "Pasta de Instalação do Jogo:"
	lbl_dir.add_theme_font_size_override("font_size", 12)
	svbox.add_child(lbl_dir)

	_input_game_dir = LineEdit.new()
	_input_game_dir.text = config.game_directory
	svbox.add_child(_input_game_dir)

	var lbl_repo := Label.new()
	lbl_repo.text = "Repositório GitHub (Atualizações):"
	lbl_repo.add_theme_font_size_override("font_size", 12)
	svbox.add_child(lbl_repo)

	_input_repo = LineEdit.new()
	_input_repo.text = config.github_repo
	svbox.add_child(_input_repo)

	_check_close_on_play = CheckBox.new()
	_check_close_on_play.text = "Fechar launcher ao iniciar o jogo"
	_check_close_on_play.button_pressed = config.close_launcher_on_play
	svbox.add_child(_check_close_on_play)

	var shbox := HBoxContainer.new()
	shbox.alignment = BoxContainer.ALIGNMENT_END
	svbox.add_child(shbox)

	var btn_save := Button.new()
	btn_save.text = " Salvar "
	btn_save.pressed.connect(_save_settings_dialog)
	shbox.add_child(btn_save)

	var btn_cancel := Button.new()
	btn_cancel.text = " Cancelar "
	btn_cancel.pressed.connect(func(): _settings_dialog.visible = false)
	shbox.add_child(btn_cancel)

func _toggle_settings() -> void:
	_settings_dialog.visible = not _settings_dialog.visible
	if _settings_dialog.visible:
		_input_game_dir.text = config.game_directory
		_input_repo.text = config.github_repo
		_check_close_on_play.button_pressed = config.close_launcher_on_play

func _save_settings_dialog() -> void:
	config.game_directory = _input_game_dir.text.strip_edges()
	config.github_repo = _input_repo.text.strip_edges()
	config.close_launcher_on_play = _check_close_on_play.button_pressed
	config.save_settings()
	_settings_dialog.visible = false
	start_version_check()
