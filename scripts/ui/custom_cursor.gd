class_name CustomCursor
extends CanvasLayer

## Cursor criativo "Espinho de Quartzo-Lume" para Cepas Selvagens.
## Combina:
## 1. cursores de hardware desenhados proceduralmente (seta de cristal/folha, mão rúnica em botões,
##    garra âmbar ao arrastar itens e runa selada quando bloqueado);
## 2. camada visual reativa (halo rúnico giratório, rastro bioluminescente de esporos e ondas de
##    pulso ao clicar com botão esquerdo ou direito).

const CURSOR_SIZE: int = 32
const TRAIL_MAX_POINTS: int = 10
const TRAIL_LIFETIME: float = 0.22

static var _instance: CustomCursor = null
static var _cursors_applied: bool = false
static var _tex_arrow: ImageTexture = null
static var _tex_pointing: ImageTexture = null
static var _tex_drag: ImageTexture = null
static var _tex_forbidden: ImageTexture = null

var _canvas: Control
var _mouse_pos: Vector2 = Vector2(-100.0, -100.0)
var _halo_angle: float = 0.0
var _hover_blend: float = 0.0
var _drag_blend: float = 0.0
var _trail: Array[Dictionary] = []
var _ripples: Array[Dictionary] = []

static func ensure_installed(tree: SceneTree) -> CustomCursor:
	apply_hardware_cursors()
	if DisplayServer.get_name() == "headless" or tree == null or tree.root == null:
		return _instance
	if _instance != null and is_instance_valid(_instance):
		return _instance
	var existing := tree.root.get_node_or_null("CustomCursor") as CustomCursor
	if existing != null:
		_instance = existing
		return _instance
	var cursor := CustomCursor.new()
	cursor.name = "CustomCursor"
	tree.root.add_child.call_deferred(cursor)
	_instance = cursor
	return cursor

static func apply_hardware_cursors() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if _tex_arrow == null:
		_tex_arrow = _build_arrow_cursor()
		_tex_pointing = _build_pointing_cursor()
		_tex_drag = _build_drag_cursor()
		_tex_forbidden = _build_forbidden_cursor()
	Input.set_custom_mouse_cursor(_tex_arrow, Input.CURSOR_ARROW, Vector2(2, 2))
	Input.set_custom_mouse_cursor(_tex_pointing, Input.CURSOR_POINTING_HAND, Vector2(3, 2))
	Input.set_custom_mouse_cursor(_tex_drag, Input.CURSOR_DRAG, Vector2(14, 14))
	Input.set_custom_mouse_cursor(_tex_drag, Input.CURSOR_CAN_DROP, Vector2(14, 14))
	Input.set_custom_mouse_cursor(_tex_forbidden, Input.CURSOR_FORBIDDEN, Vector2(14, 14))
	_cursors_applied = true

func _ready() -> void:
	layer = 125
	process_mode = Node.PROCESS_MODE_ALWAYS
	apply_hardware_cursors()

	_canvas = Control.new()
	_canvas.name = "CursorCanvas"
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_on_canvas_draw)
	add_child(_canvas)

func _input(event: InputEvent) -> void:
	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		return
	if event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		_mouse_pos = mm.position
		_push_trail_point(_mouse_pos)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and (mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_RIGHT):
			_mouse_pos = mb.position
			_spawn_ripple(_mouse_pos, mb.button_index == MOUSE_BUTTON_RIGHT)

func _process(delta: float) -> void:
	if _canvas == null:
		return
	var cursor_visible: bool = Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED
	_canvas.visible = cursor_visible
	if not cursor_visible:
		if not _trail.is_empty() or not _ripples.is_empty():
			_trail.clear()
			_ripples.clear()
		return

	var vp := get_viewport()
	if vp:
		_mouse_pos = vp.get_mouse_position()

	var hovered: Control = vp.gui_get_hovered_control() if vp else null
	var is_interactive: bool = hovered != null and (hovered is BaseButton or hovered.get_default_cursor_shape() == Control.CURSOR_POINTING_HAND)
	var is_dragging: bool = vp != null and vp.gui_is_dragging()

	_hover_blend = move_toward(_hover_blend, 1.0 if is_interactive else 0.0, delta * 7.5)
	_drag_blend = move_toward(_drag_blend, 1.0 if is_dragging else 0.0, delta * 8.0)
	_halo_angle = fposmod(_halo_angle + delta * (1.2 + _hover_blend * 1.8 + _drag_blend * 2.2), TAU)

	for i in range(_trail.size() - 1, -1, -1):
		var pt: Dictionary = _trail[i]
		pt["age"] = float(pt["age"]) + delta
		if float(pt["age"]) >= TRAIL_LIFETIME:
			_trail.remove_at(i)

	for i in range(_ripples.size() - 1, -1, -1):
		var rp: Dictionary = _ripples[i]
		rp["age"] = float(rp["age"]) + delta
		if float(rp["age"]) >= float(rp["duration"]):
			_ripples.remove_at(i)

	_canvas.queue_redraw()

func _push_trail_point(pos: Vector2) -> void:
	if not _trail.is_empty():
		var last_pos: Vector2 = _trail[_trail.size() - 1]["pos"]
		if last_pos.distance_squared_to(pos) < 16.0:
			return
	_trail.append({"pos": pos, "age": 0.0})
	while _trail.size() > TRAIL_MAX_POINTS:
		_trail.remove_at(0)

func _spawn_ripple(pos: Vector2, is_right_click: bool) -> void:
	_ripples.append({
		"pos": pos,
		"age": 0.0,
		"duration": 0.34 if is_right_click else 0.26,
		"right": is_right_click,
		"seed": _halo_angle,
	})

func _on_canvas_draw() -> void:
	if _mouse_pos.x < -50.0:
		return

	var base_col := Color(0.32, 0.92, 0.72, 0.75)
	var hover_col := Color(0.98, 0.84, 0.36, 0.88)
	var drag_col := Color(1.0, 0.58, 0.22, 0.92)
	var active_col := base_col.lerp(hover_col, _hover_blend).lerp(drag_col, _drag_blend)

	# 1. Rastro de esporos bioluminescentes
	if _trail.size() >= 2:
		for i in range(_trail.size() - 1):
			var p0: Vector2 = _trail[i]["pos"]
			var p1: Vector2 = _trail[i + 1]["pos"]
			var life: float = 1.0 - clampf(float(_trail[i]["age"]) / TRAIL_LIFETIME, 0.0, 1.0)
			var c := Color(active_col.r, active_col.g, active_col.b, life * 0.42)
			var width: float = lerpf(1.0, 3.2, life)
			_canvas.draw_line(p0, p1, c, width, true)
			if i % 2 == 0:
				_canvas.draw_circle(p0, 1.6 * life, Color(1.0, 0.96, 0.82, life * 0.55))

	# 2. Halo rúnico giratório em torno da ponta do ponteiro
	var radius: float = lerpf(14.0, 10.5, _hover_blend) + _drag_blend * 4.0
	var ring_alpha: float = lerpf(0.28, 0.72, maxf(_hover_blend, _drag_blend))
	var ring_col := Color(active_col.r, active_col.g, active_col.b, ring_alpha)
	_canvas.draw_arc(_mouse_pos, radius, 0.0, TAU, 24, ring_col, 1.25, true)

	var ticks: int = 4
	for i in ticks:
		var a: float = _halo_angle + float(i) * (TAU / float(ticks))
		var dir := Vector2(cos(a), sin(a))
		var inner: Vector2 = _mouse_pos + dir * (radius - 2.2)
		var outer: Vector2 = _mouse_pos + dir * (radius + 2.6)
		_canvas.draw_line(inner, outer, Color(active_col.r, active_col.g, active_col.b, ring_alpha * 1.25), 1.6, true)

	if _drag_blend > 0.05:
		for i in 3:
			var a: float = -_halo_angle * 1.6 + float(i) * (TAU / 3.0)
			var orb_pos: Vector2 = _mouse_pos + Vector2(cos(a), sin(a)) * (radius + 4.5)
			_canvas.draw_circle(orb_pos, 2.4 * _drag_blend, Color(1.0, 0.78, 0.32, 0.85 * _drag_blend))

	# 3. Ondas de impacto ao clicar (M1 = verde-dourado, M2 = âmbar-violeta rúnico)
	for rp in _ripples:
		var t: float = clampf(float(rp["age"]) / float(rp["duration"]), 0.0, 1.0)
		var ease_t: float = 1.0 - pow(1.0 - t, 2.4)
		var pos: Vector2 = rp["pos"]
		var is_right: bool = bool(rp["right"])
		var r_col: Color = Color(0.98, 0.68, 0.28, (1.0 - t) * 0.85) if is_right else Color(0.45, 0.96, 0.74, (1.0 - t) * 0.82)
		var r_rad: float = lerpf(4.0, 26.0 if is_right else 20.0, ease_t)
		_canvas.draw_arc(pos, r_rad, 0.0, TAU, 24, r_col, lerpf(2.4, 0.8, t), true)
		if is_right:
			_canvas.draw_arc(pos, r_rad * 0.62, 0.0, TAU, 20, Color(0.76, 0.56, 0.98, (1.0 - t) * 0.72), 1.4, true)
		var spark_count: int = 8 if is_right else 6
		var base_seed: float = float(rp["seed"])
		for s in spark_count:
			var sa: float = base_seed + float(s) * (TAU / float(spark_count))
			var s_dir := Vector2(cos(sa), sin(sa))
			var s_start: Vector2 = pos + s_dir * (r_rad * 0.65)
			var s_end: Vector2 = pos + s_dir * (r_rad * 1.15)
			_canvas.draw_line(s_start, s_end, Color(1.0, 0.95, 0.78, (1.0 - t) * 0.75), 1.5, true)

# ---------------------------------------------------------------- cursores procedurais

## Seta "Espinho de Quartzo-Lume": lança-folha de cristal verde-esmeralda com engaste dourado
static func _build_arrow_cursor() -> ImageTexture:
	var img := Image.create(CURSOR_SIZE, CURSOR_SIZE, false, Image.FORMAT_RGBA8)
	var outline := Color(0.03, 0.05, 0.04, 0.98)
	var blade_light := Color(0.36, 0.94, 0.74, 1.0)
	var blade_dark := Color(0.14, 0.54, 0.44, 1.0)
	var gold := Color(0.96, 0.78, 0.32, 1.0)
	var tip_glow := Color(0.82, 0.99, 1.0, 1.0)

	for y: int in range(1, 27):
		for x: int in range(1, 27):
			# Geometria de ponta de lança assimétrica (aponta para (2, 2))
			var dx: int = x - 2
			var dy: int = y - 2
			if dx < 0 or dy < 0:
				continue
			# Dentro do triângulo principal da lâmina
			var in_upper: bool = dy <= dx and dx <= 19 and dy * 2 <= dx + 4
			var in_lower: bool = dx <= dy and dy <= 19 and dx * 2 <= dy + 4
			var in_core: bool = dx + dy <= 22 and absi(dx - dy) <= 5 and dx <= 14 and dy <= 14
			# Entalhe traseiro em V
			var notch: bool = dx + dy > 21 and absi(dx - dy) <= 3
			if (in_upper or in_lower or in_core) and not notch:
				var is_edge: bool = dx == 0 or dy == 0 or (in_upper and (dy * 2 >= dx + 3 or dx == 19)) \
					or (in_lower and (dx * 2 >= dy + 3 or dy == 19)) or (dx + dy >= 20)
				if is_edge:
					img.set_pixel(x, y, outline)
				elif dx + dy <= 4:
					img.set_pixel(x, y, tip_glow)
				elif absi(dx - dy) <= 1 and dx + dy <= 18:
					img.set_pixel(x, y, gold)
				elif dy < dx:
					img.set_pixel(x, y, blade_light)
				else:
					img.set_pixel(x, y, blade_dark)

	# Pequeno cristal flutuante na cauda da seta
	for y: int in range(16, 22):
		for x: int in range(16, 22):
			var dist: int = absi(x - 19) + absi(y - 19)
			if dist == 2:
				img.set_pixel(x, y, outline)
			elif dist < 2:
				img.set_pixel(x, y, gold)

	return ImageTexture.create_from_image(img)

## Cursor de interação (CURSOR_POINTING_HAND): ponta dourada rúnica com estrela de seleção
static func _build_pointing_cursor() -> ImageTexture:
	var img := Image.create(CURSOR_SIZE, CURSOR_SIZE, false, Image.FORMAT_RGBA8)
	var outline := Color(0.04, 0.04, 0.03, 0.98)
	var gold_bright := Color(1.0, 0.90, 0.46, 1.0)
	var gold_deep := Color(0.86, 0.58, 0.18, 1.0)
	var emerald := Color(0.32, 0.94, 0.72, 1.0)

	for y: int in range(1, 27):
		for x: int in range(1, 27):
			var dx: int = x - 3
			var dy: int = y - 2
			if dx < 0 or dy < 0:
				continue
			var in_blade: bool = (dy <= dx and dx <= 18 and dy * 2 <= dx + 5) or (dx <= dy and dy <= 18 and dx * 2 <= dy + 5)
			if in_blade and dx + dy <= 21:
				var edge: bool = dx == 0 or dy == 0 or dx + dy >= 19 or (dy > dx and dx * 2 >= dy + 4) or (dx > dy and dy * 2 >= dx + 4)
				if edge:
					img.set_pixel(x, y, outline)
				elif dx + dy <= 5:
					img.set_pixel(x, y, Color(1.0, 0.99, 0.88, 1.0))
				elif absi(dx - dy) <= 1:
					img.set_pixel(x, y, emerald)
				elif dy < dx:
					img.set_pixel(x, y, gold_bright)
				else:
					img.set_pixel(x, y, gold_deep)

	# Diamante luminoso ao lado da ponta indicando clique/interação
	for y: int in range(1, 8):
		for x: int in range(12, 19):
			var d: int = absi(x - 15) + absi(y - 4)
			if d == 3:
				img.set_pixel(x, y, outline)
			elif d < 3:
				img.set_pixel(x, y, emerald if d == 0 else gold_bright)

	return ImageTexture.create_from_image(img)

## Cursor de arraste (CURSOR_DRAG / CURSOR_CAN_DROP): garra rúnica segurando orbe de item
static func _build_drag_cursor() -> ImageTexture:
	var img := Image.create(CURSOR_SIZE, CURSOR_SIZE, false, Image.FORMAT_RGBA8)
	var outline := Color(0.04, 0.04, 0.03, 0.98)
	var amber := Color(1.0, 0.72, 0.24, 1.0)
	var core := Color(0.42, 0.96, 0.76, 1.0)

	for y: int in range(4, 28):
		for x: int in range(4, 28):
			var dx: int = x - 16
			var dy: int = y - 16
			var d2: int = dx * dx + dy * dy
			if d2 <= 20:
				img.set_pixel(x, y, outline if d2 >= 14 else ( Color(1, 1, 1, 1) if d2 <= 3 else core ))
			elif d2 >= 42 and d2 <= 76 and (absi(dx) <= 3 or absi(dy) <= 3):
				img.set_pixel(x, y, outline if d2 >= 64 else amber)

	return ImageTexture.create_from_image(img)

## Cursor de ação bloqueada (CURSOR_FORBIDDEN)
static func _build_forbidden_cursor() -> ImageTexture:
	var img := Image.create(CURSOR_SIZE, CURSOR_SIZE, false, Image.FORMAT_RGBA8)
	var outline := Color(0.05, 0.02, 0.02, 0.98)
	var crimson := Color(0.95, 0.28, 0.28, 1.0)

	for y: int in range(4, 28):
		for x: int in range(4, 28):
			var dx: int = x - 16
			var dy: int = y - 16
			var d2: int = dx * dx + dy * dy
			var on_ring: bool = d2 >= 56 and d2 <= 100
			var on_slash: bool = d2 <= 80 and absi(dx - dy) <= 2
			if on_ring or on_slash:
				var edge: bool = d2 > 88 or (on_ring and d2 < 64)
				img.set_pixel(x, y, outline if edge else crimson)

	return ImageTexture.create_from_image(img)
