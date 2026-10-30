class_name ExplorerGuide
extends Control

## Guia Interativo do Explorador & Tutorial de Novo Jogo ([J]).
## Apresenta tudo o que há para explorar e testar em Cepa Selvagem, com
## bússola/marcador de direção ao vivo para guiar o jogador até cada atividade.

@export var player: Player

var is_open: bool = false
var active_target_name: String = ""
var active_target_pos: Vector3 = Vector3.ZERO
var has_active_target: bool = false

var _compass_banner: PanelContainer
var _compass_label: Label
var _welcome_title: Label

const GUIDE_SECTIONS: Array[Dictionary] = [
	{
		"icon": "🏛️",
		"title": "1. Vila da Esperança, Estilo & Cosméticos",
		"desc": "Você começou na Vila da Esperança! Fale com o Barbeiro para mudar cabelo/rosto, abra o Ateliê Estelar [F9] para vestir Coroas de Flores, Capas e Auras com seu ouro inicial, ou doe materiais no Quadro de Obras.",
		"target_name": "Praça da Vila & Barbeiro",
		"target_pos": Vector3(1.5, 0.0, 2.5),
		"action": "cosmetics",
		"action_text": "✨ Abrir Ateliê [F9]",
	},
	{
		"icon": "🦴",
		"title": "Costelária, a Cidade dentro do Colosso",
		"desc": "A oeste, depois da Arena, fica a Costelária: lojas sob as costelas, compradores com bolsa do dia, encomendas, mestres que ensinam Técnicas no Pátio e o Arquivista com o Compêndio. [E] em qualquer morador abre a Ficha dele.",
		"target_name": "Portão da Cauda (Costelária)",
		"target_pos": Vector3(-52.0, 0.0, -10.0),
		"action": "",
		"action_text": "",
	},
	{
		"icon": "⚔️",
		"title": "2. Mestre de Armas, Estilos & Arena",
		"desc": "Aperte [E] no Mestre de Armas para testar os 3 estilos: Espada e Escudo (combo + bloqueio), Martelo Pesado (investida) e Cajado Arcano (botão direito mira no ombro + esquerdo dispara dardo!).",
		"target_name": "Mestre de Armas & Arena",
		"target_pos": Vector3(-12.0, 0.0, 4.0),
		"action": "guide_target",
		"action_text": "📍 Guiar ao Mestre de Armas",
	},
	{
		"icon": "🌲",
		"title": "3. Natureza Viva, Coleta & Pinheira-Lume",
		"desc": "Explore os ermos fora da paliçada: colete madeira, pedra, fibras e ervas com [E]. As plantas têm genética real, respondem à chuva e as árvores Pinheira-Lume brilham à noite!",
		"target_name": "Bosque das Pinheiras-Lume",
		"target_pos": Vector3(22.0, 0.0, -18.0),
		"action": "guide_target",
		"action_text": "📍 Guiar ao Bosque",
	},
	{
		"icon": "🦅",
		"title": "4. Fauna, Captura de Bichos & Montarias",
		"desc": "No menu [TAB] você fabrica Laços e Sedativos. Use-os nos bichos selvagens para capturá-los e depois aperte [E] para montar e cavalgar pelo mundo!",
		"target_name": "Campos da Fauna Selvagem",
		"target_pos": Vector3(-20.0, 0.0, -24.0),
		"action": "guide_target",
		"action_text": "📍 Guiar aos Campos",
	},
	{
		"icon": "🌊",
		"title": "5. Rio Fundo, Nado, Mergulho & Pesca",
		"desc": "Caminhe até o rio a leste: pule na água para nadar, mergulhe para explorar o fundo e use a Vara de Pesca para fisgar peixes procedurais. Quando chove, o rio sobe de verdade!",
		"target_name": "Margem do Rio & Cachoeira",
		"target_pos": Vector3(28.0, 0.0, 12.0),
		"action": "guide_target",
		"action_text": "📍 Guiar até o Rio",
	},
	{
		"icon": "🔨",
		"title": "6. Caçada à Besta & Forja na Bigorna",
		"desc": "No morro a noroeste vive a Besta de Sucata. Quebre o chifre dela, esfole com [E] e use a Bigorna da Vila para forjar equipamentos com habilidades ativas ([4], [5], [R]).",
		"target_name": "Covil da Besta de Sucata",
		"target_pos": Vector3(-28.0, 0.0, -35.0),
		"action": "guide_target",
		"action_text": "📍 Guiar até a Besta",
	},
	{
		"icon": "🪐",
		"title": "7. Fogueira, Cartas & O Céu com Planeta Anelado",
		"desc": "Jogue Duelo de Cepas na mesa da Taverna ([K] abre seu Álbum 3D), sente-se na Fogueira, acenda sua Tocha [T] à noite e OLHE PARA CIMA para admirar as Estrelas Procedurais e o Planeta com Anéis!",
		"target_name": "Fogueira & Mesa da Taverna",
		"target_pos": Vector3(-1.2, 0.0, 6.2),
		"action": "feedback",
		"action_text": "💬 Deixar Feedback [F8]",
	},
]

func _ready() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_build_compass_banner()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_J or event.keycode == KEY_F1:
			if is_open:
				close_guide()
			else:
				open_guide(player)
			get_viewport().set_input_as_handled()
		elif is_open and event.keycode == KEY_ESCAPE:
			close_guide()
			get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if not has_active_target or _compass_banner == null:
		if _compass_banner:
			_compass_banner.visible = false
		return
	if player == null and is_inside_tree():
		player = get_tree().get_first_node_in_group("player") as Player
	if player == null:
		return

	var p_pos := player.global_position
	var flat_delta := Vector2(active_target_pos.x - p_pos.x, active_target_pos.z - p_pos.z)
	var dist := flat_delta.length()
	if dist < 5.5:
		has_active_target = false
		_compass_banner.visible = false
		if player.has_signal("posture_changed"):
			player.posture_changed.emit("📍 Chegou em: %s!" % active_target_name)
		return

	_compass_banner.visible = not is_open
	var dir_str := _cardinal_from_vec(flat_delta)
	_compass_label.text = "🧭 Destino: %s  ·  %.0f m ao %s   ([J] Guia)" % [active_target_name, dist, dir_str]

func _cardinal_from_vec(v: Vector2) -> String:
	# -Z = Norte, +Z = Sul, +X = Leste, -X = Oeste
	var ns := "Norte" if v.y < -0.35 * v.length() else ("Sul" if v.y > 0.35 * v.length() else "")
	var ew := "Leste" if v.x > 0.35 * v.length() else ("Oeste" if v.x < -0.35 * v.length() else "")
	if not ns.is_empty() and not ew.is_empty():
		return ns + "-" + ew
	return ns if not ns.is_empty() else (ew if not ew.is_empty() else "Frente")

## Liga a bússola até um ponto (Guarda, Cartógrafa e Compêndio da Costelária, B38)
func point_to(target_name: String, pos: Vector3) -> void:
	active_target_name = target_name
	active_target_pos = pos
	has_active_target = true

func open_guide(p: Player = null) -> void:
	if p != null:
		player = p
	if player == null and is_inside_tree():
		player = get_tree().get_first_node_in_group("player") as Player

	var sg := get_node_or_null("/root/SaveGame")
	var cname := str(sg.get("character_name")) if sg else ""
	if _welcome_title:
		_welcome_title.text = "🧭 GUIA DO EXPLORADOR — BEM-VINDO(A)%s A CEPA SELVAGEM!" % ((", " + cname.to_upper()) if not cname.is_empty() else "")

	is_open = true
	visible = true
	add_to_group("open_menus")
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func close_guide() -> void:
	if not is_open:
		return
	is_open = false
	visible = false
	remove_from_group("open_menus")
	if get_tree().get_nodes_in_group("open_menus").is_empty():
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.04, 0.78)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := MarginContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.add_theme_constant_override("margin_left", 64)
	center.add_theme_constant_override("margin_right", 64)
	center.add_theme_constant_override("margin_top", 36)
	center.add_theme_constant_override("margin_bottom", 36)
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

	_welcome_title = Label.new()
	_welcome_title.text = "🧭 GUIA DO EXPLORADOR — BEM-VINDO(A) A CEPA SELVAGEM!"
	_welcome_title.add_theme_font_size_override("font_size", 20)
	_welcome_title.add_theme_color_override("font_color", Color(0.98, 0.86, 0.52))
	_welcome_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_welcome_title)

	var close_btn := Button.new()
	close_btn.text = "▶ Começar a Explorar [Esc / J]"
	close_btn.pressed.connect(close_guide)
	header.add_child(close_btn)

	var intro := Label.new()
	intro.text = "🎁 Você recebeu um Kit Inicial de Explorador (150 $S de Ouro, Tocha [T], Vara de Pesca, Laços e Poção)!\nEscolha abaixo o que deseja conhecer e clique em '📍 Guiar' para ativar a bússola até o local:"
	intro.add_theme_font_size_override("font_size", 14)
	intro.add_theme_color_override("font_color", Color(0.78, 0.90, 0.80))
	root_vbox.add_child(intro)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root_vbox.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)

	for sec in GUIDE_SECTIONS:
		var card := PanelContainer.new()
		var csb := StyleBoxFlat.new()
		csb.bg_color = Color(0.11, 0.15, 0.13, 0.92)
		csb.border_color = Color(0.32, 0.44, 0.36, 0.7)
		csb.set_border_width_all(1)
		csb.set_corner_radius_all(8)
		csb.content_margin_left = 14
		csb.content_margin_right = 14
		csb.content_margin_top = 10
		csb.content_margin_bottom = 10
		card.add_theme_stylebox_override("panel", csb)
		list.add_child(card)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		card.add_child(row)

		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)

		var t := Label.new()
		t.text = "%s  %s" % [sec.icon, sec.title]
		t.add_theme_font_size_override("font_size", 16)
		t.add_theme_color_override("font_color", Color(0.98, 0.88, 0.58))
		info.add_child(t)

		var d := Label.new()
		d.text = sec.desc
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.add_theme_font_size_override("font_size", 13)
		d.add_theme_color_override("font_color", Color(0.82, 0.86, 0.82))
		info.add_child(d)

		var btn_box := VBoxContainer.new()
		btn_box.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_child(btn_box)

		var pin_btn := Button.new()
		pin_btn.text = "📍 Guiar no Mapa"
		pin_btn.custom_minimum_size = Vector2(150, 32)
		pin_btn.pressed.connect(func() -> void:
			active_target_name = sec.target_name
			active_target_pos = sec.target_pos
			has_active_target = true
			close_guide()
		)
		btn_box.add_child(pin_btn)

		if sec.action == "cosmetics" or sec.action == "feedback":
			var extra_btn := Button.new()
			extra_btn.text = sec.action_text
			extra_btn.custom_minimum_size = Vector2(150, 32)
			extra_btn.pressed.connect(func() -> void:
				close_guide()
				var hud := get_parent()
				if sec.action == "cosmetics" and hud and hud.has_node("CosmeticsShop"):
					hud.get_node("CosmeticsShop").open_shop(player)
				elif sec.action == "feedback" and hud and hud.has_node("FeedbackModal"):
					hud.get_node("FeedbackModal").open_modal()
			)
			btn_box.add_child(extra_btn)

func _build_compass_banner() -> void:
	var compass_layer := CanvasLayer.new()
	compass_layer.layer = 6
	add_child(compass_layer)

	_compass_banner = PanelContainer.new()
	_compass_banner.visible = false
	_compass_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_compass_banner.position = Vector2(-220, 14)
	_compass_banner.custom_minimum_size = Vector2(440, 36)
	_compass_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.10, 0.08, 0.88)
	sb.border_color = Color(0.85, 0.72, 0.35, 0.85)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(18)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	_compass_banner.add_theme_stylebox_override("panel", sb)

	_compass_label = Label.new()
	_compass_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_compass_label.add_theme_font_size_override("font_size", 14)
	_compass_label.add_theme_color_override("font_color", Color(0.98, 0.90, 0.58))
	_compass_banner.add_child(_compass_label)

	compass_layer.add_child(_compass_banner)
