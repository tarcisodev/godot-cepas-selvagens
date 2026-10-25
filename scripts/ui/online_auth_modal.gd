class_name OnlineAuthModal
extends Control

## Modal de Autenticação Online Direta (B24).
## Conecta diretamente ao servidor oficial jogar.tarciso.dev:8787 sem exigir que o jogador digite endereço.

const WORLD_SCENE: String = "res://scenes/world.tscn"
const CHARACTER_CREATION_SCENE: String = "res://scenes/character_creation.tscn"

@export var is_host_mode: bool = false

var _panel: PanelContainer
var _title_lbl: Label
var _status_lbl: Label

# Campos de Auth
var _url_input: LineEdit
var _ws_check: CheckButton
var _user_input: LineEdit
var _pass_input: LineEdit
var _mode_btn: CheckButton
var _submit_btn: Button
var _cancel_btn: Button

# Containers
var _auth_box: VBoxContainer
var _char_box: VBoxContainer
var _char_list_container: VBoxContainer

var _is_connecting: bool = false
var _pending_mode: String = "login"

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_connect_net_signals()

func _connect_net_signals() -> void:
	var net = _net()
	if net == null:
		return
	net.connection_established.connect(_on_connected)
	net.connection_lost.connect(_on_disconnected)
	net.auth_result.connect(_on_auth_result)
	net.entered_world.connect(_on_entered_world)

func _net() -> Node:
	return get_node_or_null("/root/NetworkManager")

func _build_ui() -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0.04, 0.06, 0.05, 0.92)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(440, 340)
	center.add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	_panel.add_child(margin)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 12)
	margin.add_child(main_vbox)

	_title_lbl = Label.new()
	_title_lbl.text = "🖥️  Hospedar Servidor no PC" if is_host_mode else "⚔️  Cepas Selvagens Online"
	_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_lbl.add_theme_font_size_override("font_size", 22)
	_title_lbl.add_theme_color_override("font_color", Color(0.96, 0.9, 0.7))
	main_vbox.add_child(_title_lbl)

	_status_lbl = Label.new()
	_status_lbl.text = "Inicie o servidor local e entre com sua conta." if is_host_mode else "Entre com sua conta para jogar no servidor oficial."
	_status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_lbl.add_theme_font_size_override("font_size", 13)
	_status_lbl.add_theme_color_override("font_color", Color(0.75, 0.85, 0.75))
	_status_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	main_vbox.add_child(_status_lbl)

	# --- CAIXA DE LOGIN / REGISTRO ---
	_auth_box = VBoxContainer.new()
	_auth_box.add_theme_constant_override("separation", 10)
	main_vbox.add_child(_auth_box)

	# Campo de porta APENAS se for o host local
	if is_host_mode:
		var net_lbl := Label.new()
		net_lbl.text = "Porta do Servidor Local:"
		net_lbl.add_theme_font_size_override("font_size", 13)
		_auth_box.add_child(net_lbl)

		_url_input = LineEdit.new()
		_url_input.text = "8787"
		_auth_box.add_child(_url_input)

		_ws_check = CheckButton.new()
		_ws_check.text = "Modo WebSocket (para Cloudflare Tunnel)"
		_ws_check.button_pressed = false
		_auth_box.add_child(_ws_check)

	var user_lbl := Label.new()
	user_lbl.text = "Usuário do Administrador:" if is_host_mode else "Usuário:"
	user_lbl.add_theme_font_size_override("font_size", 13)
	_auth_box.add_child(user_lbl)

	_user_input = LineEdit.new()
	_user_input.placeholder_text = "Nome de usuário da sua conta"
	_auth_box.add_child(_user_input)

	var pass_lbl := Label.new()
	pass_lbl.text = "Senha:"
	pass_lbl.add_theme_font_size_override("font_size", 13)
	_auth_box.add_child(pass_lbl)

	_pass_input = LineEdit.new()
	_pass_input.secret = true
	_pass_input.placeholder_text = "••••••••"
	_auth_box.add_child(_pass_input)

	_mode_btn = CheckButton.new()
	_mode_btn.text = "Criar nova conta (Registro)"
	_mode_btn.toggled.connect(func(on: bool):
		_pending_mode = "register" if on else "login"
		_submit_btn.text = ("Criar Conta e Iniciar" if is_host_mode else "Criar Conta e Entrar") if on else ("Iniciar Servidor e Jogar" if is_host_mode else "Entrar no Servidor")
	)
	_auth_box.add_child(_mode_btn)

	var btn_hbox := HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 10)
	_auth_box.add_child(btn_hbox)

	_submit_btn = Button.new()
	_submit_btn.text = "Iniciar Servidor e Jogar" if is_host_mode else "Entrar no Servidor"
	_submit_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_submit_btn.custom_minimum_size = Vector2(0, 42)
	_submit_btn.pressed.connect(_on_submit_pressed)
	btn_hbox.add_child(_submit_btn)

	_cancel_btn = Button.new()
	_cancel_btn.text = "Voltar"
	_cancel_btn.custom_minimum_size = Vector2(90, 42)
	_cancel_btn.pressed.connect(queue_free)
	btn_hbox.add_child(_cancel_btn)

	# --- CAIXA DE PERSONAGENS (APÓS LOGIN) ---
	_char_box = VBoxContainer.new()
	_char_box.add_theme_constant_override("separation", 10)
	_char_box.visible = false
	main_vbox.add_child(_char_box)

	var choose_lbl := Label.new()
	choose_lbl.text = "Seus Personagens no Servidor:"
	choose_lbl.add_theme_font_size_override("font_size", 14)
	_char_box.add_child(choose_lbl)

	_char_list_container = VBoxContainer.new()
	_char_list_container.add_theme_constant_override("separation", 6)
	_char_box.add_child(_char_list_container)

	var new_char_btn := Button.new()
	new_char_btn.text = "🌱  Criar Novo Personagem"
	new_char_btn.custom_minimum_size = Vector2(0, 38)
	new_char_btn.pressed.connect(_on_new_character_pressed)
	_char_box.add_child(new_char_btn)

	var disc_btn := Button.new()
	disc_btn.text = "Encerrar Sessão" if is_host_mode else "Desconectar"
	disc_btn.pressed.connect(_disconnect_and_reset)
	_char_box.add_child(disc_btn)

	_user_input.grab_focus()

func _on_submit_pressed() -> void:
	var user := _user_input.text.strip_edges()
	var pass_text := _pass_input.text

	if user.length() < 3:
		_set_status("⚠️ O usuário precisa ter pelo menos 3 letras.", Color(1, 0.6, 0.4))
		return
	if pass_text.length() < 3:
		_set_status("⚠️ Digite uma senha válida.", Color(1, 0.6, 0.4))
		return

	var net = _net()
	if net == null:
		_set_status("❌ NetworkManager não encontrado.", Color(1, 0.3, 0.3))
		return

	_submit_btn.disabled = true
	_is_connecting = true

	if is_host_mode:
		var port := int(_url_input.text.strip_edges()) if (_url_input and _url_input.text.is_valid_int()) else 8787
		var use_ws: bool = _ws_check.button_pressed if _ws_check else false
		var err := net.start_server(port, 16, use_ws)
		if err != OK:
			_set_status("❌ Falha ao iniciar servidor na porta %d: %s" % [port, error_string(err)], Color(1, 0.3, 0.3))
			_submit_btn.disabled = false
			_is_connecting = false
			return
		_set_status("Servidor ativo na porta %d! Autenticando..." % port, Color(0.6, 1, 0.6))
		net.send_auth_request(_pending_mode, user, pass_text)
	else:
		# Conecta direto no servidor oficial sem pedir URL
		var target_host: String = NetworkManagerAutoload.DEFAULT_HOST
		var target_port: int = NetworkManagerAutoload.DEFAULT_PORT
		_set_status("Conectando ao servidor oficial (%s)..." % target_host, Color(0.8, 0.9, 1))

		var err: Error = net.start_client(target_host, target_port)
		if err != OK:
			_set_status("❌ Falha na conexão com o servidor: %s" % error_string(err), Color(1, 0.3, 0.3))
			_submit_btn.disabled = false
			_is_connecting = false

func _on_connected() -> void:
	_set_status("Conectado! Autenticando conta...", Color(0.6, 1, 0.6))
	var net = _net()
	if net != null:
		net.send_auth_request(_pending_mode, _user_input.text.strip_edges(), _pass_input.text)

func _on_disconnected() -> void:
	_set_status("⚠️ Desconectado do servidor.", Color(1, 0.6, 0.4))
	_submit_btn.disabled = false
	_is_connecting = false
	_auth_box.visible = true
	_char_box.visible = false

func _on_auth_result(success: bool, message: String, characters: Array) -> void:
	_submit_btn.disabled = false
	if not success:
		_set_status("❌ %s" % message, Color(1, 0.4, 0.4))
		return

	_set_status("✅ %s" % message, Color(0.6, 1, 0.6))
	_auth_box.visible = false
	_char_box.visible = true
	_populate_characters(characters)

func _populate_characters(characters: Array) -> void:
	for child in _char_list_container.get_children():
		child.queue_free()

	if characters.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "Nenhum personagem criado nesta conta ainda."
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.add_theme_font_size_override("font_size", 12)
		empty_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 0.6))
		_char_list_container.add_child(empty_lbl)
		return

	for cname in characters:
		var char_btn := Button.new()
		char_btn.text = "🗡️  %s  ▶  Jogar" % cname
		char_btn.custom_minimum_size = Vector2(0, 42)
		char_btn.pressed.connect(func():
			_set_status("Entrando no mundo com '%s'..." % cname, Color(0.8, 1, 0.8))
			var net = _net()
			if net != null:
				net.send_enter_world_request(cname)
		)
		_char_list_container.add_child(char_btn)

func _on_new_character_pressed() -> void:
	get_tree().change_scene_to_file(CHARACTER_CREATION_SCENE)

func _on_entered_world(success: bool, _data: Dictionary) -> void:
	if success:
		get_tree().change_scene_to_file(WORLD_SCENE)
	else:
		_set_status("❌ Falha ao entrar no mundo com o personagem selecionado.", Color(1, 0.4, 0.4))

func _disconnect_and_reset() -> void:
	var net = _net()
	if net != null:
		net.cleanup_peer()
		net.setup_offline_host()
	_auth_box.visible = true
	_char_box.visible = false
	_set_status("Desconectado.", Color(0.8, 0.8, 0.8))

func _set_status(msg: String, color: Color) -> void:
	_status_lbl.text = msg
	_status_lbl.add_theme_color_override("font_color", color)
