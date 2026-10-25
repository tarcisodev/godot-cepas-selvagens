class_name CoopMenu
extends Control

## Painel de Sessão Cooperativa / Multijogador LAN ([F7]).
## Permite abrir uma sala no PC principal (Host para até 16 jogadores)
## e entrar a partir de outros PCs da casa (Wi-Fi/Cabo) ou via VPN/IP direto.

@export var player: Player

var is_open: bool = false
var _status_label: Label
var _lan_ip_label: Label
var _ip_input: LineEdit
var _port_input: LineEdit
var _players_box: VBoxContainer
var _host_btn: Button
var _join_btn: Button
var _disconnect_btn: Button

func _ready() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	var net := _net()
	if net:
		net.network_state_changed.connect(func(_s): _refresh_ui())
		net.players_updated.connect(_refresh_ui)
		net.connection_established.connect(func():
			_status_label.text = "✅ Conectado com sucesso ao mundo do Host!"
			_refresh_ui()
		)
		net.connection_lost.connect(func():
			_status_label.text = "⚠️ Conexão encerrada ou falhou. Voltando ao modo local."
			_refresh_ui()
		)

func _net() -> NetworkManagerAutoload:
	return get_node_or_null("/root/NetworkManager") as NetworkManagerAutoload

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F7:
			if is_open:
				close_menu()
			else:
				open_menu(player)
			get_viewport().set_input_as_handled()
		elif is_open and event.keycode == KEY_ESCAPE:
			close_menu()
			get_viewport().set_input_as_handled()

func open_menu(p: Player = null) -> void:
	if p != null:
		player = p
	if player == null and is_inside_tree():
		player = get_tree().get_first_node_in_group("player") as Player
	is_open = true
	visible = true
	add_to_group("open_menus")
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_refresh_ui()

func close_menu() -> void:
	if not is_open:
		return
	is_open = false
	visible = false
	remove_from_group("open_menus")
	if get_tree().get_nodes_in_group("open_menus").is_empty():
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.05, 0.78)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := MarginContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.add_theme_constant_override("margin_left", 90)
	center.add_theme_constant_override("margin_right", 90)
	center.add_theme_constant_override("margin_top", 50)
	center.add_theme_constant_override("margin_bottom", 50)
	add_child(center)

	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.10, 0.09, 0.96)
	sb.border_color = Color(0.78, 0.64, 0.34, 0.88)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 24
	sb.content_margin_right = 24
	sb.content_margin_top = 18
	sb.content_margin_bottom = 18
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 12)
	panel.add_child(root_vbox)

	var header := HBoxContainer.new()
	root_vbox.add_child(header)

	var title := Label.new()
	title.text = "🌐 JOGAR JUNTO — MULTIJOGADOR LAN & COOP [F7]"
	title.add_theme_font_size_override("font_size", 21)
	title.add_theme_color_override("font_color", Color(0.98, 0.86, 0.52))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var close_btn := Button.new()
	close_btn.text = "✕ Fechar [Esc]"
	close_btn.pressed.connect(close_menu)
	header.add_child(close_btn)

	var split := HBoxContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_theme_constant_override("separation", 24)
	root_vbox.add_child(split)

	# Coluna Esquerda: Criar ou Entrar na Sala
	var left_col := VBoxContainer.new()
	left_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_col.add_theme_constant_override("separation", 10)
	split.add_child(left_col)

	var host_title := Label.new()
	host_title.text = "🏠 OPÇÃO 1: Hospedar neste PC (Host)"
	host_title.add_theme_font_size_override("font_size", 16)
	host_title.add_theme_color_override("font_color", Color(0.96, 0.84, 0.50))
	left_col.add_child(host_title)

	var ip_row := HBoxContainer.new()
	ip_row.add_theme_constant_override("separation", 10)
	left_col.add_child(ip_row)

	_lan_ip_label = Label.new()
	_lan_ip_label.text = "📡 Seu IP na Rede Local (Wi-Fi/Cabo): %s" % NetworkManagerAutoload.get_lan_ip()
	_lan_ip_label.add_theme_font_size_override("font_size", 14)
	_lan_ip_label.add_theme_color_override("font_color", Color(0.65, 0.95, 0.75))
	_lan_ip_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ip_row.add_child(_lan_ip_label)

	var copy_btn := Button.new()
	copy_btn.text = "📋 Copiar IP"
	copy_btn.pressed.connect(func() -> void:
		DisplayServer.clipboard_set(NetworkManagerAutoload.get_lan_ip())
		_status_label.text = "📋 IP %s copiado para a área de transferência!" % NetworkManagerAutoload.get_lan_ip()
	)
	ip_row.add_child(copy_btn)

	_host_btn = Button.new()
	_host_btn.text = "🟢 Abrir Sala neste PC (Até 16 Jogadores)"
	_host_btn.custom_minimum_size = Vector2(0, 42)
	_host_btn.pressed.connect(_on_host_pressed)
	left_col.add_child(_host_btn)

	var sep := HSeparator.new()
	left_col.add_child(sep)

	var join_title := Label.new()
	join_title.text = "🤝 OPÇÃO 2: Entrar no PC de outro jogador"
	join_title.add_theme_font_size_override("font_size", 16)
	join_title.add_theme_color_override("font_color", Color(0.96, 0.84, 0.50))
	left_col.add_child(join_title)

	var join_row := HBoxContainer.new()
	join_row.add_theme_constant_override("separation", 8)
	left_col.add_child(join_row)

	var ip_lbl := Label.new()
	ip_lbl.text = "IP do Host:"
	join_row.add_child(ip_lbl)

	_ip_input = LineEdit.new()
	_ip_input.text = NetworkManagerAutoload.get_lan_ip()
	_ip_input.placeholder_text = "Ex: 192.168.1.15"
	_ip_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	join_row.add_child(_ip_input)

	var port_lbl := Label.new()
	port_lbl.text = "Porta:"
	join_row.add_child(port_lbl)

	_port_input = LineEdit.new()
	_port_input.text = str(NetworkManagerAutoload.DEFAULT_PORT)
	_port_input.custom_minimum_size = Vector2(75, 0)
	join_row.add_child(_port_input)

	_join_btn = Button.new()
	_join_btn.text = "🚀 Conectar ao Mundo do Host"
	_join_btn.custom_minimum_size = Vector2(0, 42)
	_join_btn.pressed.connect(_on_join_pressed)
	left_col.add_child(_join_btn)

	_disconnect_btn = Button.new()
	_disconnect_btn.text = "🔌 Desconectar / Voltar ao Modo Solo"
	_disconnect_btn.custom_minimum_size = Vector2(0, 36)
	_disconnect_btn.pressed.connect(_on_disconnect_pressed)
	left_col.add_child(_disconnect_btn)

	_status_label = Label.new()
	_status_label.text = "Dica: Na mesma casa (Wi-Fi/Cabo), um PC clica em 'Abrir Sala' e o outro digita o IP mostrado acima!"
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_font_size_override("font_size", 13)
	_status_label.add_theme_color_override("font_color", Color(0.82, 0.92, 0.84))
	left_col.add_child(_status_label)

	# Coluna Direita: Jogadores na Sessão & Teleporte Rápido
	var right_col := VBoxContainer.new()
	right_col.custom_minimum_size = Vector2(340, 0)
	right_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_col.add_theme_constant_override("separation", 8)
	split.add_child(right_col)

	var right_title := Label.new()
	right_title.text = "👥 Exploradores na Sessão (Máx: 16)"
	right_title.add_theme_font_size_override("font_size", 16)
	right_title.add_theme_color_override("font_color", Color(0.96, 0.84, 0.50))
	right_col.add_child(right_title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right_col.add_child(scroll)

	_players_box = VBoxContainer.new()
	_players_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_players_box.add_theme_constant_override("separation", 8)
	scroll.add_child(_players_box)

func _on_host_pressed() -> void:
	var net := _net()
	if net == null:
		return
	var port := int(_port_input.text) if _port_input and _port_input.text.is_valid_int() else NetworkManagerAutoload.DEFAULT_PORT
	var err := net.start_server(port, 16)
	if err == OK:
		_status_label.text = "🟢 Sala aberta na porta %d! No outro PC, digite o IP %s e clique em Conectar!" % [port, NetworkManagerAutoload.get_lan_ip()]
	else:
		_status_label.text = "❌ Não foi possível abrir a porta %d (já está em uso?)." % port
	_refresh_ui()

func _on_join_pressed() -> void:
	var net := _net()
	if net == null:
		return
	var host_ip := _ip_input.text.strip_edges()
	if host_ip.is_empty():
		host_ip = "127.0.0.1"
	var port := int(_port_input.text) if _port_input and _port_input.text.is_valid_int() else NetworkManagerAutoload.DEFAULT_PORT
	var err := net.start_client(host_ip, port)
	if err == OK:
		_status_label.text = "⏳ Conectando a %s:%d..." % [host_ip, port]
	else:
		_status_label.text = "❌ Falha ao iniciar conexão com %s:%d." % [host_ip, port]
	_refresh_ui()

func _on_disconnect_pressed() -> void:
	var net := _net()
	if net:
		net.setup_offline_host()
		_status_label.text = "🔌 Sessão de rede encerrada. Você está no modo local."
	_refresh_ui()

func _refresh_ui() -> void:
	var net := _net()
	if _lan_ip_label:
		_lan_ip_label.text = "📡 Seu IP na Rede Local (Wi-Fi/Cabo): %s" % NetworkManagerAutoload.get_lan_ip()
	if net == null or _players_box == null:
		return

	var active := net.state == NetworkManagerAutoload.NetworkState.HOSTING_SERVER or net.state == NetworkManagerAutoload.NetworkState.CONNECTED_CLIENT
	if _disconnect_btn:
		_disconnect_btn.visible = active

	for c in _players_box.get_children():
		c.queue_free()

	if not active:
		var solo := Label.new()
		solo.text = "• Modo Solo Local (Offline)\nAbra uma sala ou conecte-se a outro PC para ver os outros jogadores aqui!"
		solo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		solo.add_theme_color_override("font_color", Color(0.72, 0.78, 0.74))
		_players_box.add_child(solo)
		return

	for peer_id in net.players_info:
		var info: Dictionary = net.players_info[peer_id]
		var card := PanelContainer.new()
		var csb := StyleBoxFlat.new()
		csb.bg_color = Color(0.12, 0.16, 0.14, 0.92)
		csb.set_corner_radius_all(8)
		csb.content_margin_left = 10
		csb.content_margin_right = 10
		csb.content_margin_top = 8
		csb.content_margin_bottom = 8
		card.add_theme_stylebox_override("panel", csb)
		_players_box.add_child(card)

		var row := HBoxContainer.new()
		card.add_child(row)

		var role_icon := "👑" if peer_id == 1 else "👤"
		var l := Label.new()
		l.text = "%s %s (#%d)" % [role_icon, info.get("name", "Explorador"), peer_id]
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)

		if net.remote_avatars.has(peer_id):
			var tp_btn := Button.new()
			tp_btn.text = "📍 Ir até lá"
			tp_btn.pressed.connect(func() -> void:
				var av: Node3D = net.remote_avatars.get(peer_id)
				if player and is_instance_valid(av):
					player.global_position = av.global_position + Vector3(1.5, 0.2, 1.5)
					close_menu()
			)
			row.add_child(tp_btn)
