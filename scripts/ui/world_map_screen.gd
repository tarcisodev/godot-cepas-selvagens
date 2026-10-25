class_name WorldMapScreen
extends Control

## Mapa Cartográfico Interativo do Vale & Viagem Rápida ([M]).
## Desenha em tempo real a geografia de 360x360m (Rio, Cachoeira, Serras, Estradas),
## todas as 4 Cidades/Assentamentos, Marcos de Caça/Natureza, a Trilha do Tutorial,
## a posição do Jogador, Amigos do Coop LAN e Totens de Território.

@export var player: Player

var is_open: bool = false
var selected_entry: Dictionary = {}

var _map_canvas: MapCanvasControl
var _detail_title: Label
var _detail_sub: Label
var _detail_coords: Label
var _travel_btn: Button
var _pin_btn: Button
var _status_lbl: Label

func _ready() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	if not WorldSettlements.SETTLEMENTS.is_empty():
		_select_entry(WorldSettlements.SETTLEMENTS[0])

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_M:
			if is_open:
				close_map()
			else:
				open_map(player)
			get_viewport().set_input_as_handled()
		elif is_open and event.keycode == KEY_ESCAPE:
			close_map()
			get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if is_open and _map_canvas:
		_map_canvas.queue_redraw()

func open_map(p: Player = null) -> void:
	if p != null:
		player = p
	if player == null and is_inside_tree():
		player = get_tree().get_first_node_in_group("player") as Player
	is_open = true
	visible = true
	add_to_group("open_menus")
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if _map_canvas:
		_map_canvas.player = player
		_map_canvas.queue_redraw()

func close_map() -> void:
	if not is_open:
		return
	is_open = false
	visible = false
	remove_from_group("open_menus")
	if is_inside_tree() and get_tree().get_nodes_in_group("open_menus").is_empty():
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.04, 0.80)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 42)
	margin.add_theme_constant_override("margin_right", 42)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_bottom", 28)
	add_child(margin)

	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.10, 0.09, 0.97)
	sb.border_color = Color(0.82, 0.68, 0.36, 0.90)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 16
	sb.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", sb)
	margin.add_child(panel)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 12)
	panel.add_child(root_vbox)

	# Cabeçalho
	var header := HBoxContainer.new()
	root_vbox.add_child(header)

	var title := Label.new()
	title.text = "🗺️ CARTA GEOGRÁFICA DO VALE — CIDADES, REGIÕES & VIAGEM RÁPIDA [M]"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.98, 0.86, 0.52))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var close_btn := Button.new()
	close_btn.text = "✕ Fechar Mapa [M / Esc]"
	close_btn.pressed.connect(close_map)
	header.add_child(close_btn)

	# Corpo: Esquerda = Mapa Cartográfico, Direita = Cidades, Marcos & Trilha do Tutorial
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 18)
	root_vbox.add_child(body)

	var map_frame := PanelContainer.new()
	map_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_frame.size_flags_stretch_ratio = 1.25
	var msb := StyleBoxFlat.new()
	msb.bg_color = Color(0.11, 0.16, 0.13, 1.0)
	msb.border_color = Color(0.55, 0.46, 0.28, 0.85)
	msb.set_border_width_all(2)
	msb.set_corner_radius_all(10)
	map_frame.add_theme_stylebox_override("panel", msb)
	body.add_child(map_frame)

	_map_canvas = MapCanvasControl.new()
	_map_canvas.map_screen = self
	_map_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_map_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_frame.add_child(_map_canvas)

	# Coluna direita
	var right_col := VBoxContainer.new()
	right_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_col.size_flags_stretch_ratio = 0.95
	right_col.add_theme_constant_override("separation", 10)
	body.add_child(right_col)

	# Card do local selecionado
	var sel_card := PanelContainer.new()
	var ssb := StyleBoxFlat.new()
	ssb.bg_color = Color(0.11, 0.15, 0.13, 0.95)
	ssb.border_color = Color(0.78, 0.64, 0.34, 0.8)
	ssb.set_border_width_all(1)
	ssb.set_corner_radius_all(8)
	ssb.content_margin_left = 12
	ssb.content_margin_right = 12
	ssb.content_margin_top = 10
	ssb.content_margin_bottom = 10
	sel_card.add_theme_stylebox_override("panel", ssb)
	right_col.add_child(sel_card)

	var sel_vbox := VBoxContainer.new()
	sel_vbox.add_theme_constant_override("separation", 5)
	sel_card.add_child(sel_vbox)

	_detail_title = Label.new()
	_detail_title.add_theme_font_size_override("font_size", 17)
	_detail_title.add_theme_color_override("font_color", Color(0.98, 0.88, 0.54))
	sel_vbox.add_child(_detail_title)

	_detail_sub = Label.new()
	_detail_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_sub.add_theme_font_size_override("font_size", 13)
	_detail_sub.add_theme_color_override("font_color", Color(0.84, 0.88, 0.84))
	sel_vbox.add_child(_detail_sub)

	_detail_coords = Label.new()
	_detail_coords.add_theme_font_size_override("font_size", 12)
	_detail_coords.add_theme_color_override("font_color", Color(0.68, 0.88, 0.74))
	sel_vbox.add_child(_detail_coords)

	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 10)
	sel_vbox.add_child(action_row)

	_pin_btn = Button.new()
	_pin_btn.text = "📍 Guiar na Bússola"
	_pin_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pin_btn.custom_minimum_size = Vector2(0, 34)
	_pin_btn.pressed.connect(_on_pin_selected)
	action_row.add_child(_pin_btn)

	_travel_btn = Button.new()
	_travel_btn.text = "⚡ Viajar Agora"
	_travel_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_travel_btn.custom_minimum_size = Vector2(0, 34)
	_travel_btn.pressed.connect(_on_travel_selected)
	action_row.add_child(_travel_btn)

	_status_lbl = Label.new()
	_status_lbl.add_theme_font_size_override("font_size", 12)
	_status_lbl.add_theme_color_override("font_color", Color(0.95, 0.84, 0.48))
	sel_vbox.add_child(_status_lbl)

	# Lista rolável de Assentamentos, Regiões e Trilha do Tutorial
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right_col.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)

	var sec_cities := Label.new()
	sec_cities.text = "🏘️ Cidades & Assentamentos (Viagem Rápida)"
	sec_cities.add_theme_font_size_override("font_size", 14)
	sec_cities.add_theme_color_override("font_color", Color(0.96, 0.84, 0.48))
	list.add_child(sec_cities)

	for s in WorldSettlements.SETTLEMENTS:
		var btn := Button.new()
		btn.text = "%s   ·   (%.0f, %.0f)" % [s.name, s.pos.x, s.pos.z]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.pressed.connect(_select_entry.bind(s))
		list.add_child(btn)

	var sec_landmarks := Label.new()
	sec_landmarks.text = "🧭 Regiões, Covis & Pontos Notáveis"
	sec_landmarks.add_theme_font_size_override("font_size", 14)
	sec_landmarks.add_theme_color_override("font_color", Color(0.75, 0.92, 0.78))
	list.add_child(sec_landmarks)

	for lm in WorldSettlements.LANDMARKS:
		var btn := Button.new()
		btn.text = "%s   ·   (%.0f, %.0f)" % [lm.name, lm.pos.x, lm.pos.z]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.pressed.connect(_select_entry.bind(lm))
		list.add_child(btn)

	var sec_tut := Label.new()
	sec_tut.text = "🎓 Caminho do Tutorial (Trilha do Iniciado)"
	sec_tut.add_theme_font_size_override("font_size", 14)
	sec_tut.add_theme_color_override("font_color", Color(0.58, 0.88, 0.98))
	list.add_child(sec_tut)

	for i in TutorialTrail.TRAIL_STEPS.size():
		var st: Dictionary = TutorialTrail.TRAIL_STEPS[i]
		var t_btn := Button.new()
		t_btn.text = "%s %s" % [st.icon, st.title]
		t_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		t_btn.pressed.connect(func() -> void:
			_select_entry({
				"id": st.id,
				"name": "%s %s" % [st.icon, st.title],
				"subtitle": st.detail,
				"pos": st.pos,
				"can_fast_travel": false,
				"tutorial_index": i,
			})
		)
		list.add_child(t_btn)

func _select_entry(entry: Dictionary) -> void:
	selected_entry = entry
	if _detail_title:
		_detail_title.text = str(entry.get("name", ""))
	if _detail_sub:
		_detail_sub.text = str(entry.get("subtitle", ""))
	var pos: Vector3 = entry.get("pos", Vector3.ZERO)
	if _detail_coords:
		_detail_coords.text = "Coordenadas: X %.0f, Z %.0f" % [pos.x, pos.z]
	if _travel_btn:
		var can_ft: bool = entry.get("can_fast_travel", false)
		_travel_btn.disabled = not can_ft
		_travel_btn.text = "⚡ Viajar para Cidade" if can_ft else "🔒 Viagem Só para Vilas"
	if _map_canvas:
		_map_canvas.queue_redraw()

func _on_pin_selected() -> void:
	if selected_entry.is_empty() or not is_inside_tree():
		return
	var scene := get_tree().current_scene
	if scene == null:
		return
	if selected_entry.has("tutorial_index"):
		var trail := scene.get_node_or_null("TutorialTrail") as TutorialTrail
		if trail:
			trail.jump_to_step(int(selected_entry["tutorial_index"]))
	var guide := scene.find_child("ExplorerGuide", true, false) as ExplorerGuide
	if guide:
		guide.active_target_name = str(selected_entry.get("name", "Destino"))
		guide.active_target_pos = selected_entry.get("pos", Vector3.ZERO)
		guide.has_active_target = true
	if _status_lbl:
		_status_lbl.text = "📍 Destino marcado na Bússola Superior!"
	close_map()

func _on_travel_selected() -> void:
	if selected_entry.is_empty() or not selected_entry.get("can_fast_travel", false):
		return
	if not is_inside_tree() or get_tree().current_scene == null:
		return
	var ws := get_tree().current_scene.get_node_or_null("WorldSettlements") as WorldSettlements
	if ws and ws.fast_travel_to(selected_entry.get("id", &""), player):
		close_map()


## Canvas customizado que desenha o mapa de 360x360m e trata cliques nos ícones
class MapCanvasControl extends Control:
	var map_screen: WorldMapScreen
	var player: Player

	func _world_to_map(wx: float, wz: float, rect_size: Vector2) -> Vector2:
		var pad := 24.0
		var usable := rect_size - Vector2(pad * 2.0, pad * 2.0)
		var nx := (wx + WorldBounds.HALF) / (WorldBounds.HALF * 2.0)
		var nz := (wz + WorldBounds.HALF) / (WorldBounds.HALF * 2.0)
		return Vector2(pad + nx * usable.x, pad + nz * usable.y)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var click_pos: Vector2 = event.position
			var best_entry: Dictionary = {}
			var best_dist: float = 22.0
			for s in WorldSettlements.SETTLEMENTS:
				var mp := _world_to_map(s.pos.x, s.pos.z, size)
				var d := click_pos.distance_to(mp)
				if d < best_dist:
					best_dist = d
					best_entry = s
			for lm in WorldSettlements.LANDMARKS:
				var mp := _world_to_map(lm.pos.x, lm.pos.z, size)
				var d := click_pos.distance_to(mp)
				if d < best_dist:
					best_dist = d
					best_entry = lm
			if not best_entry.is_empty() and map_screen:
				map_screen._select_entry(best_entry)

	func _draw() -> void:
		var r := size
		if r.x < 40 or r.y < 40:
			return

		# Grade cartográfica sutil
		var grid_col := Color(0.22, 0.30, 0.25, 0.45)
		for i in range(1, 6):
			var gx := r.x * float(i) / 6.0
			var gy := r.y * float(i) / 6.0
			draw_line(Vector2(gx, 0), Vector2(gx, r.y), grid_col, 1.0)
			draw_line(Vector2(0, gy), Vector2(r.x, gy), grid_col, 1.0)

		# Relevo de montanhas (círculos de contorno)
		for peak in [[-28.0, -52.0, 36.0], [95.0, 115.0, 42.0], [135.0, -55.0, 48.0], [-115.0, 95.0, 38.0], [-130.0, -120.0, 44.0]]:
			var pc := _world_to_map(peak[0], peak[1], r)
			var pr := float(peak[2]) / (WorldBounds.HALF * 2.0) * minf(r.x, r.y)
			draw_circle(pc, pr, Color(0.24, 0.26, 0.24, 0.42))
			draw_arc(pc, pr * 0.65, 0.0, TAU, 24, Color(0.38, 0.40, 0.36, 0.55), 1.5)

		# Curso do Rio e Lagoa da Cachoeira
		var prev_pt := Vector2.ZERO
		for i in 72:
			var wz := -WorldBounds.HALF + float(i) / 71.0 * (WorldBounds.HALF * 2.0)
			var wx := RiverSystem.get_river_center_x(wz)
			var pt := _world_to_map(wx, wz, r)
			if i > 0:
				var w := 6.5 if absf(wz - RiverSystem.WATERFALL_Z) > 10.0 else 11.0
				draw_line(prev_pt, pt, Color(0.18, 0.52, 0.78, 0.85), w)
			prev_pt = pt

		# Estradas principais ligando a Vila da Esperança aos 3 povoados
		var cap := _world_to_map(1.5, 4.5, r)
		for dest in [Vector2(42, 48), Vector2(-32, -72), Vector2(82, -38), Vector2(-27, 3)]:
			var dp := _world_to_map(dest.x, dest.y, r)
			draw_dashed_line(cap, dp, Color(0.82, 0.70, 0.42, 0.65), 2.0, 6.0)

		# Pontos de Interesse (Landmarks)
		var font := ThemeDB.fallback_font
		for lm in WorldSettlements.LANDMARKS:
			var mp := _world_to_map(lm.pos.x, lm.pos.z, r)
			var col: Color = lm.get("color", Color.ORANGE)
			draw_circle(mp, 5.5, col)
			draw_arc(mp, 7.5, 0.0, TAU, 16, Color(0, 0, 0, 0.8), 1.5)

		# Assentamentos / Vilas
		for s in WorldSettlements.SETTLEMENTS:
			var mp := _world_to_map(s.pos.x, s.pos.z, r)
			var col: Color = s.get("color", Color.GOLD)
			var rad := 8.5 if s.kind == "capital" else 7.0
			draw_circle(mp, rad + 2.0, Color(0.05, 0.07, 0.06, 0.9))
			draw_circle(mp, rad, col)
			if map_screen and map_screen.selected_entry.get("id") == s.id:
				draw_arc(mp, rad + 5.5, 0.0, TAU, 24, Color(1.0, 0.95, 0.55), 2.2)
			if font:
				var short_name := str(s.name).get_slice(" ", 1) + " " + str(s.name).get_slice(" ", 2)
				draw_string(font, mp + Vector2(-28, -12), short_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.98, 0.94, 0.78))

		# Totens de Território construídos
		if is_inside_tree():
			for totem in get_tree().get_nodes_in_group("claim_totems"):
				if is_instance_valid(totem) and totem is Node3D:
					var tp := _world_to_map(totem.global_position.x, totem.global_position.z, r)
					draw_circle(tp, 6.0, Color(0.35, 0.95, 0.65))

			# Jogadores Remotos (Coop LAN)
			for child in get_tree().current_scene.get_children():
				if child is Node3D and str(child.name).begins_with("RemotePlayer_"):
					var rp := _world_to_map(child.global_position.x, child.global_position.z, r)
					draw_circle(rp, 5.5, Color(0.38, 0.82, 1.0))

		# Jogador Local
		if player == null and is_inside_tree():
			player = get_tree().get_first_node_in_group("player") as Player
		if player:
			var pp := _world_to_map(player.global_position.x, player.global_position.z, r)
			draw_circle(pp, 7.5, Color(0.1, 0.1, 0.1, 0.9))
			draw_circle(pp, 5.5, Color(1.0, 0.96, 0.35))
			if font:
				draw_string(font, pp + Vector2(8, 4), "VOCÊ", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1.0, 0.96, 0.35))
