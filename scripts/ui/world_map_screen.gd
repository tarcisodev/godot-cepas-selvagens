class_name WorldMapScreen
extends Control

## Mapa Cartográfico Interativo do Vale & Viagem Rápida ([M]).
## Renderiza o relevo em estilo pergaminho envelhecido gerado pelo MapImageBaker (GDD-11),
## zonas de perigo, territórios de jogadores, montarias e até 20 marcadores pessoais.
## Design fechado no GDD-11:
## - O mundo não pausa; o personagem fica parado; tomar dano fecha o mapa.
## - Sem minimapa, nada de jogadores alheios ou bichos vivos (anti-radar).
## - Zoom de 1× a 4× com a roda do mouse, arrastar (Pan) e [Espaço] para centralizar.

const _Player = preload("res://scripts/player.gd")
const _MapImageBaker = preload("res://scripts/systems/map_image_baker.gd")

const MAX_PERSONAL_MARKERS: int = 20
## Sombra das Ilhotas no pergaminho (GDD-18 §10)
const SKY_SHADOW_FILL: Color = Color(0.32, 0.27, 0.22, 0.16)
const SKY_SHADOW_LINE: Color = Color(0.3, 0.24, 0.18, 0.75)
static var _sky_shadows: Dictionary = {}

## Contornos das Ilhotas do mundo atual (a seed vem do céu; sem céu, a padrão), calculados uma vez
static func sky_shadows() -> Array:
	var seed: int = SkyIslandField.instance.world_seed if is_instance_valid(SkyIslandField.instance) else 2026
	if not _sky_shadows.has(seed):
		_sky_shadows[seed] = SkyIslandSchedule.common_outlines(seed)
	return _sky_shadows[seed]
const MARKER_ICONS: Array[String] = ["🚩", "💀", "🌿", "🐟", "👁️", "⭐"]

@export var player: Node

var is_open: bool = false
var selected_entry: Dictionary = {}
var zoom: float = 1.0
var pan_offset: Vector2 = Vector2.ZERO
var personal_markers: Array[Dictionary] = []
var active_marker_idx: int = -1

var _selected_marker_icon: String = "🚩"
var _map_canvas: MapCanvasControl
var _detail_title: Label
var _detail_sub: Label
var _detail_coords: Label
var _travel_btn: Button
var _pin_btn: Button
var _status_lbl: Label
var _zoom_lbl: Label
var _marker_count_lbl: Label
var _last_player_health: float = -1.0

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
		elif is_open and event.keycode == KEY_SPACE:
			center_on_player()
			get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if not is_open:
		return
	
	# Verifica se jogador tomou dano enquanto olhava o mapa (GDD-11 §2)
	_check_player_damage()

	if _map_canvas:
		_map_canvas.queue_redraw()

func _check_player_damage() -> void:
	if player == null:
		return
	var pools = player.get("pools") if "pools" in player else player.get_node_or_null("PoolsComponent")
	if pools and "current_health" in pools:
		var cur_hp: float = pools.current_health
		if _last_player_health > 0.0 and cur_hp < _last_player_health - 0.1:
			close_map()
			if player and player.has_signal("posture_changed"):
				player.posture_changed.emit("⚔️ Dano sofrido! O mapa foi fechado.")
		_last_player_health = cur_hp

func open_map(p: Node = null) -> void:
	if p != null:
		player = p
	if player == null and is_inside_tree():
		player = get_tree().get_first_node_in_group("player")
	
	is_open = true
	visible = true
	add_to_group("open_menus")
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	# Registra vida inicial para detecção de dano
	if player:
		var pools = player.get("pools") if "pools" in player else player.get_node_or_null("PoolsComponent")
		if pools and "current_health" in pools:
			_last_player_health = pools.current_health
		if "velocity" in player:
			player.velocity = Vector3.ZERO

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

func center_on_player() -> void:
	if player:
		var c_size: Vector2 = _map_canvas.size if (_map_canvas and _map_canvas.size.x > 1.0) else Vector2(512, 512)
		var base_scale: float = minf(c_size.x, c_size.y) / (WorldBounds.HALF * 2.0)
		var scale_factor: float = base_scale * zoom
		pan_offset = -Vector2(player.global_position.x * scale_factor, player.global_position.z * scale_factor)
		clamp_pan()
		if _status_lbl:
			_status_lbl.text = "🎯 Mapa centralizado na sua posição!"
		if _map_canvas:
			_map_canvas.queue_redraw()

## Ajusta o zoom mantendo fixo o ponto do mapa sob `anchor` (coords locais do canvas).
## Sem âncora, o zoom acontece em torno do centro do canvas.
func set_zoom_level(new_zoom: float, anchor: Vector2 = Vector2(NAN, NAN)) -> void:
	var old_zoom: float = zoom
	zoom = clampf(new_zoom, 1.0, 4.0)
	if _map_canvas and _map_canvas.size.x > 1.0 and not is_equal_approx(old_zoom, zoom):
		var half_size: Vector2 = _map_canvas.size * 0.5
		var rel: Vector2 = Vector2.ZERO if is_nan(anchor.x) else anchor - half_size
		pan_offset = rel - (rel - pan_offset) * (zoom / old_zoom)
	clamp_pan()
	if _zoom_lbl:
		_zoom_lbl.text = "Zoom: %.1f×" % zoom
	if _map_canvas:
		_map_canvas.queue_redraw()

## Impede que o pergaminho saia da moldura: com o mapa maior que o canvas,
## as bordas sempre cobrem a área visível; menor, ele fica centralizado.
func clamp_pan() -> void:
	if _map_canvas == null or _map_canvas.size.x <= 1.0 or _map_canvas.size.y <= 1.0:
		return
	var c_size: Vector2 = _map_canvas.size
	var map_px: float = minf(c_size.x, c_size.y) * zoom
	var limit := Vector2(maxf(map_px - c_size.x, 0.0), maxf(map_px - c_size.y, 0.0)) * 0.5
	pan_offset = pan_offset.clamp(-limit, limit)

func add_marker(world_pos: Vector2, icon: String = "🚩", label: String = "") -> bool:
	if personal_markers.size() >= MAX_PERSONAL_MARKERS:
		if _status_lbl:
			_status_lbl.text = "⚠️ Limite de 20 marcadores pessoais atingido!"
		return false
	
	personal_markers.append({
		"id": "marker_%d" % Time.get_ticks_msec(),
		"pos": world_pos,
		"icon": icon,
		"label": label if not label.is_empty() else "Ponto Notável"
	})
	_update_marker_count()
	if _status_lbl:
		_status_lbl.text = "📍 Novo marcador adicionado! (%d/20)" % personal_markers.size()
	if _map_canvas:
		_map_canvas.queue_redraw()
	return true

func remove_marker_near(world_pos: Vector2, tolerance: float = 8.0) -> bool:
	for i in personal_markers.size():
		var m := personal_markers[i]
		var m_pos: Vector2 = m.get("pos", Vector2.ZERO)
		if m_pos.distance_to(world_pos) <= tolerance:
			personal_markers.remove_at(i)
			if active_marker_idx == i:
				active_marker_idx = -1
				_clear_compass_target()
			elif active_marker_idx > i:
				active_marker_idx -= 1
			_update_marker_count()
			if _status_lbl:
				_status_lbl.text = "🗑️ Marcador removido."
			if _map_canvas:
				_map_canvas.queue_redraw()
			return true
	return false

func set_active_marker(idx: int) -> void:
	if idx >= 0 and idx < personal_markers.size():
		active_marker_idx = idx
		var m := personal_markers[idx]
		_guide_compass(str(m.get("icon", "📍")) + " " + str(m.get("label", "Destino")), Vector3(m.pos.x, 0, m.pos.y))
		if _status_lbl:
			_status_lbl.text = "🧭 Marcador guiado na Bússola Superior!"
	else:
		active_marker_idx = -1
		_clear_compass_target()
	if _map_canvas:
		_map_canvas.queue_redraw()

func _update_marker_count() -> void:
	if _marker_count_lbl:
		_marker_count_lbl.text = "Marcadores: %d/%d" % [personal_markers.size(), MAX_PERSONAL_MARKERS]

func get_markers_data() -> Array:
	return personal_markers.duplicate(true)

func load_markers_data(data: Array) -> void:
	personal_markers.clear()
	for item in data:
		if item is Dictionary:
			var p = item.get("pos", Vector2.ZERO)
			var pos_vec: Vector2 = p if p is Vector2 else Vector2(float(p[0]), float(p[1])) if p is Array else Vector2.ZERO
			personal_markers.append({
				"id": str(item.get("id", "")),
				"pos": pos_vec,
				"icon": str(item.get("icon", "🚩")),
				"label": str(item.get("label", "Marcador"))
			})
	_update_marker_count()
	if _map_canvas:
		_map_canvas.queue_redraw()

func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.04, 0.85)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 36)
	margin.add_theme_constant_override("margin_right", 36)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	add_child(margin)

	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.11, 0.10, 0.98)
	sb.border_color = Color(0.82, 0.68, 0.36, 0.90)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", sb)
	margin.add_child(panel)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 10)
	panel.add_child(root_vbox)

	# Cabeçalho
	var header := HBoxContainer.new()
	root_vbox.add_child(header)

	var title := Label.new()
	title.text = "🗺️ CARTA TOPOGRÁFICA DO VALE DAS CEPAS [M]"
	title.add_theme_font_size_override("font_size", 19)
	title.add_theme_color_override("font_color", Color(0.98, 0.86, 0.52))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	_zoom_lbl = Label.new()
	_zoom_lbl.text = "Zoom: 1.0×"
	_zoom_lbl.add_theme_font_size_override("font_size", 13)
	_zoom_lbl.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
	header.add_child(_zoom_lbl)

	var btn_center := Button.new()
	btn_center.text = "🎯 Centralizar [Espaço]"
	btn_center.pressed.connect(center_on_player)
	header.add_child(btn_center)

	var close_btn := Button.new()
	close_btn.text = "✕ Fechar [Esc]"
	close_btn.pressed.connect(close_map)
	header.add_child(close_btn)

	# Corpo: Esquerda = Canvas do Mapa, Direita = Detalhes, Viagem e Marcadores
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	root_vbox.add_child(body)

	var map_frame := PanelContainer.new()
	map_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_frame.size_flags_stretch_ratio = 1.35
	var msb := StyleBoxFlat.new()
	msb.bg_color = Color(0.12, 0.16, 0.14, 1.0)
	msb.border_color = Color(0.55, 0.46, 0.28, 0.85)
	msb.set_border_width_all(2)
	msb.set_corner_radius_all(10)
	map_frame.add_theme_stylebox_override("panel", msb)
	body.add_child(map_frame)

	_map_canvas = MapCanvasControl.new()
	_map_canvas.map_screen = self
	_map_canvas.clip_contents = true
	_map_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_map_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_frame.add_child(_map_canvas)

	# Coluna lateral
	var right_col := VBoxContainer.new()
	right_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_col.size_flags_stretch_ratio = 0.85
	right_col.add_theme_constant_override("separation", 10)
	body.add_child(right_col)

	# Painel do local selecionado
	var sel_card := PanelContainer.new()
	var ssb := StyleBoxFlat.new()
	ssb.bg_color = Color(0.11, 0.15, 0.13, 0.95)
	ssb.border_color = Color(0.78, 0.64, 0.34, 0.8)
	ssb.set_border_width_all(1)
	ssb.set_corner_radius_all(8)
	ssb.content_margin_left = 12
	ssb.content_margin_right = 12
	ssb.content_margin_top = 8
	ssb.content_margin_bottom = 8
	sel_card.add_theme_stylebox_override("panel", ssb)
	right_col.add_child(sel_card)

	var sel_vbox := VBoxContainer.new()
	sel_vbox.add_theme_constant_override("separation", 4)
	sel_card.add_child(sel_vbox)

	_detail_title = Label.new()
	_detail_title.add_theme_font_size_override("font_size", 16)
	_detail_title.add_theme_color_override("font_color", Color(0.98, 0.88, 0.54))
	sel_vbox.add_child(_detail_title)

	_detail_sub = Label.new()
	_detail_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_sub.add_theme_font_size_override("font_size", 12)
	_detail_sub.add_theme_color_override("font_color", Color(0.84, 0.88, 0.84))
	sel_vbox.add_child(_detail_sub)

	_detail_coords = Label.new()
	_detail_coords.add_theme_font_size_override("font_size", 11)
	_detail_coords.add_theme_color_override("font_color", Color(0.68, 0.88, 0.74))
	sel_vbox.add_child(_detail_coords)

	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 8)
	sel_vbox.add_child(action_row)

	_pin_btn = Button.new()
	_pin_btn.text = "📍 Bússola"
	_pin_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pin_btn.custom_minimum_size = Vector2(0, 30)
	_pin_btn.pressed.connect(_on_pin_selected)
	action_row.add_child(_pin_btn)

	_travel_btn = Button.new()
	_travel_btn.text = "⚡ Viagem Rápida"
	_travel_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_travel_btn.custom_minimum_size = Vector2(0, 30)
	_travel_btn.pressed.connect(_on_travel_selected)
	action_row.add_child(_travel_btn)

	# Seção de Marcadores Pessoais
	var marker_header := HBoxContainer.new()
	right_col.add_child(marker_header)

	var marker_title := Label.new()
	marker_title.text = "📌 Seus Marcadores (Botão Direito no Mapa)"
	marker_title.add_theme_font_size_override("font_size", 13)
	marker_title.add_theme_color_override("font_color", Color(0.98, 0.85, 0.50))
	marker_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	marker_header.add_child(marker_title)

	_marker_count_lbl = Label.new()
	_marker_count_lbl.text = "Marcadores: 0/20"
	_marker_count_lbl.add_theme_font_size_override("font_size", 12)
	_marker_count_lbl.add_theme_color_override("font_color", Color(0.7, 0.8, 0.75))
	marker_header.add_child(_marker_count_lbl)

	# Barra de seleção de ícone do marcador
	var icon_bar := HBoxContainer.new()
	icon_bar.add_theme_constant_override("separation", 6)
	right_col.add_child(icon_bar)

	for ic in MARKER_ICONS:
		var ibtn := Button.new()
		ibtn.text = ic
		ibtn.custom_minimum_size = Vector2(32, 28)
		ibtn.pressed.connect(func():
			_selected_marker_icon = ic
			if _status_lbl:
				_status_lbl.text = "Ícone selecionado para próximos cliques: %s" % ic
		)
		icon_bar.add_child(ibtn)

	_status_lbl = Label.new()
	_status_lbl.text = "Clique direito no mapa para criar marcador."
	_status_lbl.add_theme_font_size_override("font_size", 12)
	_status_lbl.add_theme_color_override("font_color", Color(0.95, 0.84, 0.48))
	right_col.add_child(_status_lbl)

	# Lista rolável de pontos notáveis
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right_col.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 5)
	scroll.add_child(list)

	for s in WorldSettlements.SETTLEMENTS:
		var btn := Button.new()
		btn.text = "%s  (%.0f, %.0f)" % [s.name, s.pos.x, s.pos.z]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.pressed.connect(_select_entry.bind(s))
		list.add_child(btn)

	for lm in WorldSettlements.LANDMARKS:
		var btn := Button.new()
		btn.text = "%s  (%.0f, %.0f)" % [lm.name, lm.pos.x, lm.pos.z]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.pressed.connect(_select_entry.bind(lm))
		list.add_child(btn)

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
		if player and player.has_meta("carrying_trade_pack") and player.get_meta("carrying_trade_pack") != null:
			_travel_btn.disabled = true
			_travel_btn.text = "🚫 Fardo Pesado (Sem Viagem Rápida)"
		else:
			_travel_btn.disabled = not can_ft
			_travel_btn.text = "⚡ Viagem Rápida" 
	if _map_canvas:
		_map_canvas.queue_redraw()

func _on_pin_selected() -> void:
	if selected_entry.is_empty():
		return
	var pos: Vector3 = selected_entry.get("pos", Vector3.ZERO)
	_guide_compass(str(selected_entry.get("name", "Destino")), pos)
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

func _guide_compass(target_name: String, target_pos: Vector3) -> void:
	if not is_inside_tree():
		return
	var scene := get_tree().current_scene
	if scene == null:
		return
	var guide := scene.find_child("ExplorerGuide", true, false) as ExplorerGuide
	if guide:
		guide.active_target_name = target_name
		guide.active_target_pos = target_pos
		guide.has_active_target = true

func _clear_compass_target() -> void:
	if not is_inside_tree():
		return
	var scene := get_tree().current_scene
	if scene == null:
		return
	var guide := scene.find_child("ExplorerGuide", true, false) as ExplorerGuide
	if guide:
		guide.has_active_target = false


## Canvas cartográfico interativo
class MapCanvasControl extends Control:
	var map_screen: WorldMapScreen
	var player: Node
	const DRAG_THRESHOLD: float = 4.0

	var _mouse_down: bool = false
	var _is_dragging: bool = false
	var _drag_start: Vector2 = Vector2.ZERO
	var _pan_start: Vector2 = Vector2.ZERO

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED and map_screen:
			map_screen.clamp_pan()

	func _world_to_map(wx: float, wz: float, rect_size: Vector2) -> Vector2:
		var center := rect_size * 0.5 + (map_screen.pan_offset if map_screen else Vector2.ZERO)
		var base_scale: float = minf(rect_size.x, rect_size.y) / (WorldBounds.HALF * 2.0)
		var scale_factor: float = base_scale * (map_screen.zoom if map_screen else 1.0)
		return center + Vector2(wx * scale_factor, wz * scale_factor)

	func _map_to_world(map_pos: Vector2, rect_size: Vector2) -> Vector2:
		var center := rect_size * 0.5 + (map_screen.pan_offset if map_screen else Vector2.ZERO)
		var base_scale: float = minf(rect_size.x, rect_size.y) / (WorldBounds.HALF * 2.0)
		var scale_factor: float = base_scale * (map_screen.zoom if map_screen else 1.0)
		var offset := map_pos - center
		return Vector2(offset.x / scale_factor, offset.y / scale_factor)

	func _gui_input(event: InputEvent) -> void:
		if map_screen == null:
			return

		# Zoom na roda do mouse (GDD-11 §3)
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
				map_screen.set_zoom_level(map_screen.zoom + 0.25, event.position)
				accept_event()
				return
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
				map_screen.set_zoom_level(map_screen.zoom - 0.25, event.position)
				accept_event()
				return

			# Clique Direito: Adicionar ou Remover Marcador Pessoal
			if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
				var world_click := _map_to_world(event.position, size)
				# Tenta remover se clicou em cima de um existente
				if not map_screen.remove_marker_near(world_click, 8.0 / map_screen.zoom):
					# Senão cria um novo
					map_screen.add_marker(world_click, map_screen._selected_marker_icon)
				accept_event()
				return

			# Clique Esquerdo: arrastar move o mapa; clique curto (sem arraste) seleciona
			if event.button_index == MOUSE_BUTTON_LEFT:
				if event.pressed:
					_mouse_down = true
					_is_dragging = false
					_drag_start = event.position
					_pan_start = map_screen.pan_offset
				else:
					if _mouse_down and not _is_dragging:
						_select_at(event.position)
					_mouse_down = false
					_is_dragging = false
					mouse_default_cursor_shape = Control.CURSOR_ARROW
				accept_event()

		elif event is InputEventMouseMotion and _mouse_down:
			var diff: Vector2 = event.position - _drag_start
			if not _is_dragging and diff.length() >= DRAG_THRESHOLD:
				_is_dragging = true
				mouse_default_cursor_shape = Control.CURSOR_DRAG
			if _is_dragging:
				map_screen.pan_offset = _pan_start + diff
				map_screen.clamp_pan()
				queue_redraw()
			accept_event()

	func _select_at(click_pos: Vector2) -> void:
		var world_click := _map_to_world(click_pos, size)
		# 1. Verifica clique em marcador pessoal para torná-lo ativo
		for i in map_screen.personal_markers.size():
			var m := map_screen.personal_markers[i]
			if m.pos.distance_to(world_click) < (10.0 / map_screen.zoom):
				map_screen.set_active_marker(i)
				return

		# 2. Verifica clique em Assentamentos ou Pontos Notáveis
		var best_entry: Dictionary = {}
		var best_dist: float = 24.0
		for s in WorldSettlements.SETTLEMENTS:
			var mp := _world_to_map(s.pos.x, s.pos.z, size)
			var d: float = click_pos.distance_to(mp)
			if d < best_dist:
				best_dist = d
				best_entry = s
		for lm in WorldSettlements.LANDMARKS:
			var mp := _world_to_map(lm.pos.x, lm.pos.z, size)
			var d: float = click_pos.distance_to(mp)
			if d < best_dist:
				best_dist = d
				best_entry = lm
		if not best_entry.is_empty():
			map_screen._select_entry(best_entry)

	func _draw() -> void:
		var r := size
		if r.x < 40 or r.y < 40:
			return

		# 1. CAMADA TERRENO EM PERGAMINHO (MapImageBaker)
		var landscape: Node = null
		if is_inside_tree() and get_tree().current_scene:
			landscape = get_tree().current_scene.get_node_or_null("Landscape")
			if not landscape:
				landscape = get_tree().current_scene.get_node_or_null("LandscapeGenerator")
		var baked_tex := _MapImageBaker.get_or_bake_map(landscape)

		var top_left := _world_to_map(-WorldBounds.HALF, -WorldBounds.HALF, r)
		var bottom_right := _world_to_map(WorldBounds.HALF, WorldBounds.HALF, r)
		var map_rect := Rect2(top_left, bottom_right - top_left)
		draw_texture_rect(baked_tex, map_rect, false)

		# 2. CAMADA ZONAS FIXAS (ZoneManager)
		var town_center := _world_to_map(0.0, 0.0, r)
		var town_rad: float = 18.0 * (minf(r.x, r.y) / (WorldBounds.HALF * 2.0)) * (map_screen.zoom if map_screen else 1.0)
		draw_circle(town_center, town_rad, Color(0.25, 0.75, 0.35, 0.22))
		draw_arc(town_center, town_rad, 0.0, TAU, 32, Color(0.35, 0.85, 0.45, 0.65), 1.5)

		var lair_center := _world_to_map(85.0, 85.0, r)
		var lair_rad: float = 24.0 * (minf(r.x, r.y) / (WorldBounds.HALF * 2.0)) * (map_screen.zoom if map_screen else 1.0)
		draw_arc(lair_center, lair_rad, 0.0, TAU, 32, Color(0.85, 0.25, 0.25, 0.6), 2.0)

		# 2.5 SOMBRAS DAS ILHOTAS (GDD-18 §10): só as comuns, que são fixas e fazem parte da
		# geografia; contorno pontilhado e sombra clara. As outras ilhas são exploração.
		for outline in WorldMapScreen.sky_shadows():
			var pts := PackedVector2Array()
			for wp in outline:
				pts.append(_world_to_map(wp.x, wp.y, r))
			draw_colored_polygon(pts, SKY_SHADOW_FILL)
			for i in pts.size() - 1:
				if i % 2 == 0:
					draw_line(pts[i], pts[i + 1], SKY_SHADOW_LINE, 1.5)

		# 3. ESTRADAS PRINCIPAIS
		var cap := _world_to_map(1.5, 4.5, r)
		for dest in [Vector2(42, 48), Vector2(-32, -72), Vector2(82, -38), Vector2(-27, 3)]:
			var dp := _world_to_map(dest.x, dest.y, r)
			draw_dashed_line(cap, dp, Color(0.55, 0.42, 0.28, 0.70), 2.0, 5.0)

		# 4. CONSTRUÇÕES DOS JOGADORES (Totens & Peças - GDD-11 §4 & §6)
		if is_inside_tree():
			for totem in get_tree().get_nodes_in_group("claim_totems"):
				if is_instance_valid(totem) and totem is Node3D:
					var tp := _world_to_map(totem.global_position.x, totem.global_position.z, r)
					var rad_totem: float = 14.0 * (minf(r.x, r.y) / (WorldBounds.HALF * 2.0)) * (map_screen.zoom if map_screen else 1.0)
					draw_circle(tp, rad_totem, Color(0.2, 0.65, 0.45, 0.18))
					draw_arc(tp, rad_totem, 0.0, TAU, 24, Color(0.3, 0.85, 0.55, 0.75), 1.5)
					draw_circle(tp, 4.0, Color(0.3, 0.9, 0.6))

			# Peças de construção (desenhadas como traços e mini-ícones)
			for piece in get_tree().get_nodes_in_group("built_structures"):
				if is_instance_valid(piece) and piece is Node3D:
					var pp := _world_to_map(piece.global_position.x, piece.global_position.z, r)
					draw_rect(Rect2(pp - Vector2(1.5, 1.5), Vector2(3, 3)), Color(0.48, 0.32, 0.22, 0.8))

		# 5. PONTOS NOTÁVEIS E CIDADES
		var font := ThemeDB.fallback_font
		for lm in WorldSettlements.LANDMARKS:
			var mp := _world_to_map(lm.pos.x, lm.pos.z, r)
			draw_circle(mp, 5.0, Color(0.85, 0.45, 0.2))
			draw_arc(mp, 6.5, 0.0, TAU, 16, Color(0.1, 0.1, 0.1, 0.7), 1.2)

		for s in WorldSettlements.SETTLEMENTS:
			var mp := _world_to_map(s.pos.x, s.pos.z, r)
			var col: Color = s.get("color", Color.GOLD)
			var rad: float = 7.5 if s.kind == "capital" else 6.0
			draw_circle(mp, rad + 2.0, Color(0.08, 0.08, 0.08, 0.85))
			draw_circle(mp, rad, col)
			if map_screen and map_screen.selected_entry.get("id") == s.id:
				draw_arc(mp, rad + 4.5, 0.0, TAU, 20, Color(1.0, 0.95, 0.4), 2.0)
			if font:
				var sname := str(s.name).get_slice(" ", 1)
				draw_string(font, mp + Vector2(-20, -10), sname, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.95, 0.90, 0.75))

		# 6. MONTARIAS DO JOGADOR (GDD-11 §4)
		if is_inside_tree() and player:
			for mount in get_tree().get_nodes_in_group("mounts"):
				if is_instance_valid(mount) and mount is Node3D:
					var mp := _world_to_map(mount.global_position.x, mount.global_position.z, r)
					draw_circle(mp, 4.5, Color(0.2, 0.75, 0.85))
					if font:
						draw_string(font, mp + Vector2(6, 4), "🐎", HORIZONTAL_ALIGNMENT_LEFT, -1, 11)

		# 7. MARCADORES PESSOAIS DO JOGADOR (GDD-11 §5)
		if map_screen:
			for i in map_screen.personal_markers.size():
				var m := map_screen.personal_markers[i]
				var mp := _world_to_map(m.pos.x, m.pos.y, r)
				var is_active := (i == map_screen.active_marker_idx)

				if is_active:
					draw_arc(mp, 10.0, 0.0, TAU, 24, Color(1.0, 0.85, 0.2), 2.5)

				draw_circle(mp, 5.0, Color(0.1, 0.1, 0.1, 0.8))
				if font:
					var icon_str: String = str(m.get("icon", "📍"))
					draw_string(font, mp + Vector2(-6, 5), icon_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 12)

		# 8. VOCÊ (JOGADOR LOCAL - GDD-11 §4)
		if player:
			var pp := _world_to_map(player.global_position.x, player.global_position.z, r)
			var facing_angle: float = player.global_rotation.y
			var dir_vec := Vector2(sin(facing_angle), cos(facing_angle))

			# Desenha seta apontando a direção da visão
			var tip := pp + dir_vec * 9.0
			var left_wing := pp + dir_vec.rotated(deg_to_rad(140)) * 6.5
			var right_wing := pp + dir_vec.rotated(deg_to_rad(-140)) * 6.5

			draw_colored_polygon([tip, left_wing, pp, right_wing], Color(0.98, 0.85, 0.25))
			draw_circle(pp, 3.5, Color(0.15, 0.12, 0.05))

			if font:
				draw_string(font, pp + Vector2(10, 4), "VOCÊ", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.98, 0.85, 0.25))
