class_name QuickItemWheel
extends Control

## Roda rápida de consumíveis: segure [F] para abrir a roda, aponte com o mouse e solte para
## escolher. O tempo NÃO para nem desacelera (no online não haveria essa folga). [G] usa o item escolhido; [Z]/[X] passam para o anterior/próximo.
## Um indicador fixo no canto mostra o item escolhido e quantos restam.

const KEY_WHEEL: Key = KEY_F
const KEY_USE: Key = KEY_G
const KEY_PREV: Key = KEY_Z
const KEY_NEXT: Key = KEY_X
const WHEEL_RADIUS: float = 170.0
const TEXT := Color(0.92, 0.92, 0.95)
const TEXT_DIM := Color(0.6, 0.62, 0.68)
const ACCENT := Color(0.95, 0.45, 0.75)

@export var player: Player

## Consumível escolhido (id do material)
var selected_id: StringName = &""
var is_open: bool = false

var _wheel: Control
var _center_name: Label
var _center_effect: Label
var _slots: Array[Control] = []
var _options: Array[StringName] = []
var _hover: int = -1
var _indicator: PanelContainer
var _ind_icon: Label
var _ind_name: Label
var _ind_qty: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_indicator()
	_build_wheel()
	_wheel.visible = false

func _process(_delta: float) -> void:
	if player == null and is_inside_tree():
		player = get_tree().get_first_node_in_group("player") as Player
	_refresh_indicator()
	if is_open:
		_update_hover()

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or event.echo:
		return
	var key: Key = event.keycode
	if key == KEY_WHEEL:
		if event.pressed and not is_open and _menus_closed():
			open_wheel()
			get_viewport().set_input_as_handled()
		elif not event.pressed and is_open:
			close_wheel(true)
			get_viewport().set_input_as_handled()
		return
	if not event.pressed or is_open or not _menus_closed():
		return
	if key == KEY_USE:
		use_selected()
		get_viewport().set_input_as_handled()
	elif key == KEY_PREV or key == KEY_NEXT:
		cycle(-1 if key == KEY_PREV else 1)
		get_viewport().set_input_as_handled()

## Ids dos consumíveis no inventário, em ordem estável (grupo de efeito e nome)
func consumable_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	if player == null or player.inventory == null:
		return out
	for s in player.inventory.get_stacks():
		var d := MaterialData.of(s.id)
		if (d.is_consumable() or d.is_tool()) and not out.has(s.id):
			out.append(s.id)
	out.sort_custom(func(a, b):
		var da := MaterialData.of(a)
		var db := MaterialData.of(b)
		var ka := _effect_rank(da)
		var kb := _effect_rank(db)
		return da.display_name < db.display_name if ka == kb else ka < kb)
	return out

## Passa para o consumível anterior (-1) ou próximo (+1)
func cycle(step: int) -> void:
	var ids := consumable_ids()
	if ids.is_empty():
		selected_id = &""
		return
	var i := ids.find(selected_id)
	selected_id = ids[posmod(i + step, ids.size()) if i >= 0 else 0]
	_notify("%s %s selecionado" % [MaterialData.of(selected_id).icon, MaterialData.of(selected_id).display_name])

## Usa uma unidade do escolhido (pior qualidade primeiro). Recusa com barra cheia.
func use_selected() -> bool:
	_ensure_selection()
	if selected_id.is_empty() or player == null or player.pools == null or player.is_downed:
		_notify("Nenhum consumível na mochila")
		return false
	# Vara de pesca: lança ou recolhe a linha (GDD-10 §8)
	if MaterialData.of(selected_id).tool_action == &"pesca":
		return player.fishing != null and player.fishing.toggle()
	# Ferramenta de captura (laço, sedativo): age no bicho mais próximo
	if MaterialData.of(selected_id).is_tool():
		return WildCreature.use_tool(player, selected_id)
	var stacks: Array[Dictionary] = player.inventory.get_stacks(selected_id)
	if stacks.is_empty() or not player.inventory.use_item(stacks[0], player.pools):
		_notify("%s: nada para repor agora" % MaterialData.of(selected_id).display_name)
		return false
	return true

func open_wheel() -> void:
	_options = consumable_ids()
	if _options.is_empty():
		_notify("Nenhum consumível na mochila")
		return
	is_open = true
	_ensure_selection()
	_hover = _options.find(selected_id)
	_layout_slots()
	_wheel.visible = true
	add_to_group("open_menus")
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_viewport().warp_mouse(get_viewport_rect().size * 0.5)

func close_wheel(pick: bool) -> void:
	if pick and _hover >= 0 and _hover < _options.size():
		selected_id = _options[_hover]
	is_open = false
	_wheel.visible = false
	remove_from_group("open_menus")
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _ensure_selection() -> void:
	var ids := consumable_ids()
	if not ids.has(selected_id):
		selected_id = ids[0] if not ids.is_empty() else &""

func _menus_closed() -> bool:
	for n in get_tree().get_nodes_in_group("open_menus"):
		if n != self:
			return false
	return true

func _notify(msg: String) -> void:
	if player and player.has_signal("posture_changed"):
		player.posture_changed.emit(msg)

## Ordem na roda: cura, vigor, éter, ferramentas
static func _effect_rank(d: MaterialData) -> int:
	if d.is_tool():
		return 3
	if d.restore_health > 0.0 and d.restore_ether <= 0.0:
		return 0
	if d.restore_vigor > 0.0:
		return 1
	return 2

# ---------------------------------------------------------------- roda

func _build_wheel() -> void:
	_wheel = Control.new()
	_wheel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_wheel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_wheel)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.35)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wheel.add_child(dim)

	var hub := Panel.new()
	_center_on(hub, Vector2.ZERO, Vector2(190, 190))
	hub.add_theme_stylebox_override("panel", _box(Color(0.07, 0.07, 0.09, 0.92), Color(1, 1, 1, 0.12), 95, 2))
	hub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wheel.add_child(hub)
	_center_name = _label("", 17, TEXT)
	_center_name.position = Vector2(10, 62)
	_center_name.size = Vector2(170, 40)
	hub.add_child(_center_name)
	_center_effect = _label("", 13, ACCENT)
	_center_effect.position = Vector2(10, 102)
	_center_effect.size = Vector2(170, 30)
	hub.add_child(_center_effect)
	var hint := _label("solte [F] para escolher", 11, TEXT_DIM)
	hint.position = Vector2(10, 136)
	hint.size = Vector2(170, 20)
	hub.add_child(hint)

func _layout_slots() -> void:
	for s in _slots:
		s.queue_free()
	_slots.clear()
	var n := _options.size()
	for i in n:
		var id := _options[i]
		var data := MaterialData.of(id)
		var slot := Panel.new()
		var a := -PI * 0.5 + TAU * i / n
		_center_on(slot, Vector2(cos(a), sin(a)) * WHEEL_RADIUS, Vector2(92, 92))
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var icon := _label(data.icon, 34, TEXT)
		icon.position = Vector2(0, 10)
		icon.size = Vector2(92, 46)
		slot.add_child(icon)
		var qty := _label("×%d" % player.inventory.get_material_count(id), 14, TEXT)
		qty.position = Vector2(0, 60)
		qty.size = Vector2(92, 22)
		slot.add_child(qty)
		_wheel.add_child(slot)
		_slots.append(slot)
	_style_slots()

func _update_hover() -> void:
	var center := get_viewport_rect().size * 0.5
	var v := get_viewport().get_mouse_position() - center
	if v.length() > 40.0 and not _options.is_empty():
		var a := fposmod(v.angle() + PI * 0.5 + PI / _options.size(), TAU)
		var idx := int(a / (TAU / _options.size())) % _options.size()
		if idx != _hover:
			_hover = idx
			_style_slots()
	if _hover >= 0 and _hover < _options.size():
		var d := MaterialData.of(_options[_hover])
		_center_name.text = d.display_name
		_center_effect.text = d.effect_text() if d.is_consumable() else {&"laco": "Prende bicho exausto", &"pesca": "Lança / recolhe a linha"}.get(d.tool_action, "Captura bicho preso")

func _style_slots() -> void:
	for i in _slots.size():
		var on := i == _hover
		_slots[i].add_theme_stylebox_override("panel", _box(Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.28) if on else Color(0.08, 0.08, 0.1, 0.88), ACCENT if on else Color(1, 1, 1, 0.15), 46, 3 if on else 1))
		_slots[i].scale = Vector2.ONE * (1.12 if on else 1.0)
		_slots[i].pivot_offset = Vector2(46, 46)

# ---------------------------------------------------------------- indicador

func _build_indicator() -> void:
	_indicator = PanelContainer.new()
	_indicator.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_indicator.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_indicator.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_indicator.position = Vector2(-24, -24)
	_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_indicator.add_theme_stylebox_override("panel", _box(Color(0.06, 0.06, 0.08, 0.8), Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.5), 12, 1, Vector2(12, 8)))
	add_child(_indicator)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_indicator.add_child(row)
	_ind_icon = _label("", 30, TEXT)
	row.add_child(_ind_icon)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	_ind_name = _label("", 15, TEXT)
	_ind_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	col.add_child(_ind_name)
	_ind_qty = _label("", 12, TEXT_DIM)
	_ind_qty.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	col.add_child(_ind_qty)

func _refresh_indicator() -> void:
	if _indicator == null:
		return
	_ensure_selection()
	_indicator.visible = not selected_id.is_empty() and not is_open and _menus_closed()
	if selected_id.is_empty():
		return
	var d := MaterialData.of(selected_id)
	_ind_icon.text = d.icon
	_ind_name.text = "%s  ×%d" % [d.display_name, player.inventory.get_material_count(selected_id)]
	_ind_qty.text = "[G] usar · [Z]/[X] trocar · segure [F] roda"
	# Mantém o canto inferior direito mesmo quando o texto muda de largura
	_indicator.reset_size()
	_indicator.position = get_viewport_rect().size - _indicator.size - Vector2(24, 24)

## Prende o controle ao centro da tela, deslocado de `offset`, com o tamanho dado
func _center_on(c: Control, offset: Vector2, size_px: Vector2) -> void:
	c.anchor_left = 0.5
	c.anchor_right = 0.5
	c.anchor_top = 0.5
	c.anchor_bottom = 0.5
	c.offset_left = offset.x - size_px.x * 0.5
	c.offset_right = offset.x + size_px.x * 0.5
	c.offset_top = offset.y - size_px.y * 0.5
	c.offset_bottom = offset.y + size_px.y * 0.5

func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _box(bg: Color, border: Color, radius: int, border_w: int, pad: Vector2 = Vector2.ZERO) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(radius)
	s.content_margin_left = pad.x
	s.content_margin_right = pad.x
	s.content_margin_top = pad.y
	s.content_margin_bottom = pad.y
	return s
