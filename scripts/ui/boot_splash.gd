class_name BootSplash
extends Control

## Tela inicial (Boot Splash & Patcher in-game).
## Carrega patches .pck locais existentes, verifica atualizações remotas,
## baixa novos pacotes de recursos de forma transparente e avança para o Menu Principal.

const _PatchManager = preload("res://scripts/patcher/patch_manager.gd")
const _PatchVersionChecker = preload("res://scripts/patcher/patch_version_checker.gd")
const _PatchDownloader = preload("res://scripts/patcher/patch_downloader.gd")

const BACKGROUND: String = "res://assets/ui/menu_background.png"
const MAIN_MENU_SCENE: String = "res://scenes/main_menu.tscn"
const OFFICIAL_REPO: String = "tarcisodev/godot-cepas-selvagens"
const OFFICIAL_LANDING_PAGE: String = "https://cepas.tarciso.dev"

var _version_checker: _PatchVersionChecker
var _downloader: _PatchDownloader

var _current_version: String = "0.1.0"
var _pending_update_info: Dictionary = {}
var _is_transitioning: bool = false

# Elementos de UI
var title_label: Label
var subtitle_label: Label
var status_label: Label
var details_label: Label
var progress_bar: ProgressBar
var progress_info_label: Label
var action_button: Button
var website_button: Button

func _ready() -> void:
	# Não executa lógica de cliente se estiver rodando como servidor dedicado
	if _is_dedicated_server_mode():
		return
	
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	_build_ui()
	
	# 1. Carrega pacotes .pck já instalados localmente
	var loaded := _PatchManager.load_all_installed_patches()
	_current_version = _PatchManager.get_current_version()
	
	if loaded > 0:
		details_label.text = "Versão: v%s (%d pacote(s) de recursos ativo(s))" % [_current_version, loaded]
	else:
		details_label.text = "Versão: v%s (Cliente Base)" % _current_version
	
	# Em modo headless (testes), não dispara conexões de rede automaticamente
	if DisplayServer.get_name() == "headless":
		status_label.text = "Modo de teste headless detectado."
		return
	
	# 2. Inicializa componentes de patching
	_version_checker = _PatchVersionChecker.new()
	add_child(_version_checker)
	_version_checker.check_completed.connect(_on_check_completed)
	_version_checker.check_failed.connect(_on_check_failed)
	
	_downloader = _PatchDownloader.new()
	add_child(_downloader)
	_downloader.download_progress.connect(_on_download_progress)
	_downloader.download_completed.connect(_on_download_completed)
	_downloader.download_failed.connect(_on_download_failed)
	
	# 3. Dispara verificação de versão remota
	status_label.text = "Verificando atualizações no refúgio selvagem..."
	action_button.text = "Pular e Jogar"
	_version_checker.check_for_updates(_current_version, OFFICIAL_REPO)

func _is_dedicated_server_mode() -> bool:
	for a in OS.get_cmdline_args() + OS.get_cmdline_user_args():
		if a == "--server" or a == "-server":
			return true
	return false

func _build_ui() -> void:
	# Fundo atmosférico
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.12, 0.09)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	
	if ResourceLoader.exists(BACKGROUND):
		var tex := TextureRect.new()
		tex.texture = load(BACKGROUND)
		tex.set_anchors_preset(Control.PRESET_FULL_RECT)
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		add_child(tex)
	
	# Sombra escura suave
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.03, 0.02, 0.85)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	
	# Painel Central
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(560, 0)
	box.add_theme_constant_override("separation", 14)
	center.add_child(box)
	
	title_label = Label.new()
	title_label.text = "Cepa Selvagem"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 52)
	title_label.add_theme_color_override("font_color", Color(0.96, 0.9, 0.7))
	title_label.add_theme_constant_override("outline_size", 6)
	title_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	box.add_child(title_label)
	
	subtitle_label = Label.new()
	subtitle_label.text = "Ecologia Viva & Sobrevivência Selvagem"
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.add_theme_font_size_override("font_size", 16)
	subtitle_label.add_theme_color_override("font_color", Color(0.78, 0.86, 0.76, 0.9))
	box.add_child(subtitle_label)
	
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	box.add_child(spacer)
	
	status_label = Label.new()
	status_label.text = "Inicializando..."
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 16)
	status_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	box.add_child(status_label)
	
	progress_bar = ProgressBar.new()
	progress_bar.custom_minimum_size = Vector2(560, 24)
	progress_bar.min_value = 0.0
	progress_bar.max_value = 100.0
	progress_bar.value = 0.0
	progress_bar.show_percentage = true
	box.add_child(progress_bar)
	
	var info_row := HBoxContainer.new()
	box.add_child(info_row)
	
	details_label = Label.new()
	details_label.text = "Versão: ..."
	details_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details_label.add_theme_font_size_override("font_size", 13)
	details_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	info_row.add_child(details_label)
	
	progress_info_label = Label.new()
	progress_info_label.text = ""
	progress_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	progress_info_label.add_theme_font_size_override("font_size", 13)
	progress_info_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	info_row.add_child(progress_info_label)
	
	var btn_spacer := Control.new()
	btn_spacer.custom_minimum_size = Vector2(0, 10)
	box.add_child(btn_spacer)
	
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 16)
	box.add_child(btn_row)
	
	action_button = Button.new()
	action_button.text = "▶ Jogar Agora"
	action_button.custom_minimum_size = Vector2(220, 44)
	action_button.add_theme_font_size_override("font_size", 16)
	action_button.pressed.connect(_on_action_pressed)
	btn_row.add_child(action_button)
	
	website_button = Button.new()
	website_button.text = "🌐 Abrir Site Oficial"
	website_button.custom_minimum_size = Vector2(200, 44)
	website_button.add_theme_font_size_override("font_size", 16)
	website_button.visible = false
	website_button.pressed.connect(func(): OS.shell_open(OFFICIAL_LANDING_PAGE))
	btn_row.add_child(website_button)

func _on_check_completed(info: Dictionary) -> void:
	if not info.get("has_update", false):
		status_label.text = "Tudo pronto! Você está na versão mais recente (v%s)." % _current_version
		progress_bar.value = 100.0
		action_button.text = "▶ Entrar no Jogo"
		_auto_advance(0.8)
		return
	
	_pending_update_info = info
	var new_ver: String = str(info.get("version", ""))
	var is_pck: bool = info.get("is_pck", false)
	
	if is_pck and not str(info.get("download_url", "")).is_empty():
		status_label.text = "Atualização v%s encontrada! Baixando pacote de recursos..." % new_ver
		action_button.text = "Pular Atualização"
		
		var patch_name := str(info.get("asset_name", "patch_v%s.pck" % new_ver))
		if not patch_name.ends_with(".pck"):
			patch_name = "patch_v%s.pck" % new_ver
		
		var temp_dest := _PatchManager.PATCHES_DIR.path_join("download_temp.pck")
		var size_bytes := int(info.get("size_bytes", 0))
		_downloader.start_download(info["download_url"], temp_dest, size_bytes)
	else:
		# Atualização principal de binário (requer novo instalador/zip)
		status_label.text = "Nova versão v%s disponível com alterações no executável." % new_ver
		website_button.visible = true
		action_button.text = "▶ Jogar v%s Atual" % _current_version

func _on_check_failed(error_message: String) -> void:
	status_label.text = "Modo Offline ativo: %s" % error_message
	action_button.text = "▶ Jogar Offline"
	action_button.grab_focus()
	_auto_advance(2.0)

func _on_download_progress(downloaded: int, total: int, percent: float, speed_bps: float, eta_sec: float) -> void:
	progress_bar.value = percent
	var down_mb := float(downloaded) / (1024.0 * 1024.0)
	var total_mb := float(total) / (1024.0 * 1024.0)
	var speed_mb := speed_bps / (1024.0 * 1024.0)
	
	if total > 0:
		progress_info_label.text = "%.1f / %.1f MB (%.0f%%) · %.1f MB/s · ETA: %.0fs" % [
			down_mb, total_mb, percent, speed_mb, eta_sec
		]
	else:
		progress_info_label.text = "%.1f MB baixados · %.1f MB/s" % [down_mb, speed_mb]

func _on_download_completed(temp_file_path: String) -> void:
	status_label.text = "Validando integridade e montando pacote..."
	progress_bar.value = 100.0
	progress_info_label.text = "Instalando..."
	
	var new_ver := str(_pending_update_info.get("version", "atualizada"))
	var sha := str(_pending_update_info.get("sha256", ""))
	var final_name := "patch_v%s.pck" % new_ver
	
	var res := _PatchManager.apply_downloaded_pck(temp_file_path, final_name, new_ver, sha)
	if res.get("success", false):
		_current_version = new_ver
		details_label.text = "Versão: v%s (Atualizado!)" % _current_version
		status_label.text = "Sucesso! Versão v%s pronta para jogar." % new_ver
		action_button.text = "▶ Entrar no Jogo"
		_auto_advance(0.8)
	else:
		status_label.text = "Aviso ao instalar patch: %s" % str(res.get("error", "desconhecido"))
		action_button.text = "▶ Continuar para o Jogo"
		action_button.grab_focus()

func _on_download_failed(error_message: String) -> void:
	status_label.text = "Falha no download da atualização: %s" % error_message
	action_button.text = "▶ Jogar Versão Instalada"
	action_button.grab_focus()

func _on_action_pressed() -> void:
	if _downloader != null and _downloader.is_downloading():
		_downloader.cancel_download()
	_transition_to_menu()

func _auto_advance(delay: float) -> void:
	if _is_transitioning:
		return
	var timer := get_tree().create_timer(delay)
	timer.timeout.connect(func():
		if not _is_transitioning:
			_transition_to_menu()
	)

func _transition_to_menu() -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	
	if ResourceLoader.exists(MAIN_MENU_SCENE):
		get_tree().change_scene_to_file(MAIN_MENU_SCENE)
	else:
		push_error("[BootSplash] Cena do Menu Principal não encontrada: %s" % MAIN_MENU_SCENE)
