class_name MobileTouchControls
extends Control

## Controles de Toque para Celular / Mobile ([F6] alterna no PC).
## Ativa automaticamente no Android/iOS (OS.has_feature("mobile")).
## Inclui: Analógico Virtual Esquerdo (Andar/Correr), Giro de Câmera por Toque,
## Botões Táteis de Combate/Interação e Barra Rápida de Menus (incluindo Sala Coop).

@export var player: Player

const JOY_RADIUS: float = 68.0
const SPRINT_THRESHOLD: float = 0.78

var is_enabled: bool = false
var _joy_touch_idx: int = -1
var _look_touch_idx: int = -1
var _joy_vector: Vector2 = Vector2.ZERO

var _joy_base: Panel
var _joy_knob: Panel
var _action_cluster: Control
var _top_menu_bar: PanelContainer

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()

	# Ativa sozinho em dispositivos móveis (Android / iOS / Web Mobile)
	if OS.has_feature("mobile") or OS.get_name() in ["Android", "iOS"]:
		set_touch_enabled(true)
	else:
		set_touch_enabled(false)

func set_touch_enabled(enable: bool) -> void:
	is_enabled = enable
	visible = enable
	if enable:
		add_to_group("touch_controls_active")
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		remove_from_group("touch_controls_active")
		_release_move_actions()
		if is_inside_tree() and get_tree().get_nodes_in_group("open_menus").is_empty():
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func toggle_touch_mode() -> void:
	set_touch_enabled(not is_enabled)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F6:
		toggle_touch_mode()
		get_viewport().set_input_as_handled()
		return

	if not is_enabled:
		return
	if is_inside_tree() and not get_tree().get_nodes_in_group("open_menus").is_empty():
		_release_move_actions()
		return

	# Suporte a multi-toque real (Android/iOS)
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			if _is_in_joy_zone(st.position) and _joy_touch_idx == -1:
				_joy_touch_idx = st.index
				_update_joystick(st.position)
			elif st.position.x > get_viewport_rect().size.x * 0.38 and _look_touch_idx == -1:
				_look_touch_idx = st.index
		else:
			if st.index == _joy_touch_idx:
				_joy_touch_idx = -1
				_reset_joystick()
			elif st.index == _look_touch_idx:
				_look_touch_idx = -1
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		if sd.index == _joy_touch_idx:
			_update_joystick(sd.position)
		elif sd.index == _look_touch_idx:
			_rotate_camera(sd.relative * 1.4)

	# Também permite testar com o mouse no PC quando [F6] está ativo
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			if _is_in_joy_zone(mb.position):
				_joy_touch_idx = 99
				_update_joystick(mb.position)
			elif mb.position.x > get_viewport_rect().size.x * 0.38:
				_look_touch_idx = 99
		else:
			if _joy_touch_idx == 99:
				_joy_touch_idx = -1
				_reset_joystick()
			if _look_touch_idx == 99:
				_look_touch_idx = -1
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
		var mm := event as InputEventMouseMotion
		if _joy_touch_idx == 99:
			_update_joystick(mm.position)
		elif _look_touch_idx == 99:
			_rotate_camera(mm.relative * 1.4)

func _process(_delta: float) -> void:
	if not is_enabled:
		return
	var menu_open := is_inside_tree() and not get_tree().get_nodes_in_group("open_menus").is_empty()
	if _joy_base:
		_joy_base.visible = not menu_open
	if _action_cluster:
		_action_cluster.visible = not menu_open

func _is_in_joy_zone(screen_pos: Vector2) -> bool:
	if _joy_base == null:
		return false
	var center := _joy_base.global_position + _joy_base.size * 0.5
	return screen_pos.distance_to(center) <= JOY_RADIUS * 1.65

func _update_joystick(screen_pos: Vector2) -> void:
	if _joy_base == null or _joy_knob == null:
		return
	var center := _joy_base.global_position + _joy_base.size * 0.5
	var delta := screen_pos - center
	var dist := delta.length()
	var clamped := delta.normalized() * minf(dist, JOY_RADIUS) if dist > 0.001 else Vector2.ZERO
	_joy_knob.position = (_joy_base.size - _joy_knob.size) * 0.5 + clamped
	_joy_vector = clamped / JOY_RADIUS
	_apply_move_actions(_joy_vector)

func _reset_joystick() -> void:
	if _joy_base and _joy_knob:
		_joy_knob.position = (_joy_base.size - _joy_knob.size) * 0.5
	_joy_vector = Vector2.ZERO
	_release_move_actions()

func _apply_move_actions(v: Vector2) -> void:
	if v.x < -0.18:
		Input.action_press("move_left", clampf(-v.x, 0.0, 1.0))
		Input.action_release("move_right")
	elif v.x > 0.18:
		Input.action_press("move_right", clampf(v.x, 0.0, 1.0))
		Input.action_release("move_left")
	else:
		Input.action_release("move_left")
		Input.action_release("move_right")

	if v.y < -0.18:
		Input.action_press("move_forward", clampf(-v.y, 0.0, 1.0))
		Input.action_release("move_backward")
	elif v.y > 0.18:
		Input.action_press("move_backward", clampf(v.y, 0.0, 1.0))
		Input.action_release("move_forward")
	else:
		Input.action_release("move_forward")
		Input.action_release("move_backward")

	if v.length() >= SPRINT_THRESHOLD:
		Input.action_press("sprint")
	else:
		Input.action_release("sprint")

func _release_move_actions() -> void:
	for act in ["move_left", "move_right", "move_forward", "move_backward", "sprint"]:
		if Input.is_action_pressed(act):
			Input.action_release(act)

func _rotate_camera(rel: Vector2) -> void:
	if player == null and is_inside_tree():
		player = get_tree().get_first_node_in_group("player") as Player
	if player and player.camera_rig and player.camera_rig.has_method("rotate_by_delta"):
		player.camera_rig.rotate_by_delta(rel)

func _build_ui() -> void:
	# 1. Analógico Virtual Esquerdo
	_joy_base = Panel.new()
	_joy_base.name = "VirtualJoystick"
	_joy_base.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_joy_base.position = Vector2(46, -196)
	_joy_base.size = Vector2(JOY_RADIUS * 2.0, JOY_RADIUS * 2.0)
	_joy_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var base_sb := StyleBoxFlat.new()
	base_sb.bg_color = Color(0.06, 0.10, 0.08, 0.55)
	base_sb.border_color = Color(0.78, 0.64, 0.34, 0.72)
	base_sb.set_border_width_all(2)
	base_sb.set_corner_radius_all(int(JOY_RADIUS))
	_joy_base.add_theme_stylebox_override("panel", base_sb)
	add_child(_joy_base)

	_joy_knob = Panel.new()
	_joy_knob.size = Vector2(54, 54)
	_joy_knob.position = (_joy_base.size - _joy_knob.size) * 0.5
	_joy_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var knob_sb := StyleBoxFlat.new()
	knob_sb.bg_color = Color(0.95, 0.80, 0.38, 0.85)
	knob_sb.set_corner_radius_all(27)
	_joy_knob.add_theme_stylebox_override("panel", knob_sb)
	_joy_base.add_child(_joy_knob)

	# 2. Cluster de Botões de Ação Táteis (Direita Inferior)
	_action_cluster = Control.new()
	_action_cluster.name = "TouchActionCluster"
	_action_cluster.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_action_cluster.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_action_cluster)

	_make_hold_button(_action_cluster, "⚔️\nATACAR", Vector2(-130, -145), Vector2(88, 88), "attack", Color(0.78, 0.22, 0.20, 0.85))
	_make_hold_button(_action_cluster, "🛡️\nDEF/MIRA", Vector2(-232, -125), Vector2(74, 74), "cast", Color(0.20, 0.48, 0.78, 0.85))
	_make_hold_button(_action_cluster, "🖐️\nUSAR [E]", Vector2(-225, -212), Vector2(74, 74), "interact", Color(0.24, 0.65, 0.38, 0.85))
	_make_hold_button(_action_cluster, "⬆️\nPULAR", Vector2(-125, -238), Vector2(68, 68), "jump", Color(0.32, 0.55, 0.42, 0.82))
	_make_hold_button(_action_cluster, "💨\nESQUIVA", Vector2(-315, -155), Vector2(68, 68), "dodge", Color(0.68, 0.52, 0.20, 0.82))

	# Botão de Tocha e Cura rápida
	var torch_btn := _make_styled_btn("🔦 Tocha", Vector2(-315, -235), Vector2(72, 44), Color(0.82, 0.52, 0.18, 0.85))
	torch_btn.pressed.connect(func() -> void:
		if player == null and is_inside_tree():
			player = get_tree().get_first_node_in_group("player") as Player
		if player and player.torch:
			player.torch.toggle()
	)
	_action_cluster.add_child(torch_btn)

	# 3. Barra Superior de Menus Táteis (para abrir salas Coop, Loja, Mochila no celular!)
	_top_menu_bar = PanelContainer.new()
	_top_menu_bar.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_top_menu_bar.position = Vector2(335, 20)
	var bar_sb := StyleBoxFlat.new()
	bar_sb.bg_color = Color(0.05, 0.08, 0.07, 0.84)
	bar_sb.border_color = Color(0.75, 0.62, 0.34, 0.78)
	bar_sb.set_border_width_all(1)
	bar_sb.set_corner_radius_all(10)
	bar_sb.content_margin_left = 8
	bar_sb.content_margin_right = 8
	bar_sb.content_margin_top = 4
	bar_sb.content_margin_bottom = 4
	_top_menu_bar.add_theme_stylebox_override("panel", bar_sb)
	add_child(_top_menu_bar)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 6)
	_top_menu_bar.add_child(top_row)

	var menu_entries := [
		["🌐 Coop", "CoopMenu", "open_menu"],
		["⛺ Central", "ActionsMenu", "toggle_menu"],
		["🎒 Mochila", "InventoryScreen", "open"],
		["✨ Loja", "CosmeticsShop", "open_shop"],
		["🧭 Guia", "ExplorerGuide", "open_guide"],
		["💬 Nota", "FeedbackModal", "open_modal"],
	]
	for entry in menu_entries:
		var b := Button.new()
		b.text = entry[0]
		b.custom_minimum_size = Vector2(74, 34)
		b.pressed.connect(func() -> void:
			var hud := get_parent()
			if hud == null:
				return
			var node := hud.get_node_or_null(entry[1])
			if node and node.has_method(entry[2]):
				node.call(entry[2])
		)
		top_row.add_child(b)

func _make_hold_button(parent: Control, label_text: String, pos: Vector2, sz: Vector2, action_name: String, col: Color) -> Button:
	var btn := _make_styled_btn(label_text, pos, sz, col)
	btn.button_down.connect(func() -> void:
		Input.action_press(action_name)
		var ev := InputEventAction.new()
		ev.action = action_name
		ev.pressed = true
		Input.parse_input_event(ev)
	)
	btn.button_up.connect(func() -> void:
		Input.action_release(action_name)
		var ev := InputEventAction.new()
		ev.action = action_name
		ev.pressed = false
		Input.parse_input_event(ev)
	)
	parent.add_child(btn)
	return btn

func _make_styled_btn(label_text: String, pos: Vector2, sz: Vector2, col: Color) -> Button:
	var btn := Button.new()
	btn.text = label_text
	btn.position = pos
	btn.size = sz
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 13)
	for st in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = col.lightened(0.18) if st == "pressed" else col
		sb.border_color = Color(0.95, 0.85, 0.55, 0.85)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(int(minf(sz.x, sz.y) * 0.5))
		btn.add_theme_stylebox_override(st, sb)
	return btn
