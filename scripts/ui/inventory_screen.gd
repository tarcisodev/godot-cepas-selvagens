class_name InventoryScreen
extends Control

const _Player = preload("res://scripts/player.gd")
const _EquipmentPanel = preload("res://scripts/ui/equipment_panel.gd")
const _MaterialData = preload("res://scripts/data/material_data.gd")
const _InventoryComponent = preload("res://scripts/components/inventory_component.gd")

## Tela de inventário ([I]): à esquerda o equipamento (boneco 3D e os 7 encaixes, GDD-12); à direita
## a grade de pilhas de material (ADR-0005) com organizador automático
## (raridade, quantidade, peso, cor, nome, manual), filtro por grupo, borda por raridade ou grupo,
## menu de contexto no botão direito do mouse e suporte a clicar e arrastar para jogar itens no chão
## ou reorganizar a mochila.

enum SortMode { RARIDADE, QUANTIDADE, PESO, COR, NOME, MANUAL }
enum BorderMode { RARIDADE, GRUPO }

const SORT_LABELS: Array[String] = ["★ Raridade", "# Quantidade", "⚖ Peso", "🎨 Cor", "Aa Nome", "✋ Manual"]
const BORDER_LABELS: Array[String] = ["Raridade", "Grupo"]
const COLUMNS: int = 5
const SLOT_SIZE: Vector2 = Vector2(86, 94)
const PANEL_BG := Color(0.07, 0.075, 0.09, 0.96)
const TEXT := Color(0.9, 0.9, 0.94)
const TEXT_DIM := Color(0.55, 0.57, 0.64)

enum ContextAction {
	USE_ITEM = 1,
	SELECT_SEED = 2,
	DROP_ONE = 10,
	DROP_HALF = 11,
	DROP_ALL = 12,
	DESTROY_ALL = 20,
}

@export var player: Player

## Escolhas da sessão (sobrevivem a fechar e abrir a tela)
static var sort_mode: SortMode = SortMode.RARIDADE
static var descending: bool = true
static var border_mode: BorderMode = BorderMode.RARIDADE
static var group_filter: int = -1  # -1 = todos; senão MaterialData.Category

var _inventory: InventoryComponent
var _grid: GridContainer
var _empty_hint: Label
var _weight_label: Label
var _relieve_btn: Button
var _count_label: Label
var _sort_bar: HBoxContainer
var _border_bar: HBoxContainer
var _group_bar: HBoxContainer
var _dir_button: Button
var _detail: VBoxContainer
var _selected_key: String = ""
var _equipment: EquipmentPanel
var _context_menu: PopupMenu
var _context_stack: Dictionary = {}
var _drop_zone_bar: GroundDropZone

func _ready() -> void:
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 20
	_build_ui()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_I:
		if visible or get_tree().get_nodes_in_group("open_menus").is_empty():
			toggle()
			get_viewport().set_input_as_handled()
	elif visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

func toggle() -> void:
	if visible:
		close()
	else:
		open()

func open() -> void:
	CustomCursor.ensure_installed(get_tree())
	_bind_inventory()
	if _equipment and player:
		_equipment.bind(player)
	visible = true
	add_to_group("open_menus")
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	refresh()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.15)

func close() -> void:
	if _context_menu and _context_menu.visible:
		_context_menu.hide()
	visible = false
	remove_from_group("open_menus")
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _bind_inventory() -> void:
	if player == null and is_inside_tree():
		player = get_tree().get_first_node_in_group("player") as Player
	var inv: InventoryComponent = player.inventory if player else null
	if inv == _inventory:
		return
	if _inventory and _inventory.stacks_changed.is_connected(refresh):
		_inventory.stacks_changed.disconnect(refresh)
	_inventory = inv
	if _inventory:
		_inventory.stacks_changed.connect(refresh)

## Ordena pilhas pelo critério; empate cai no nome e depois na qualidade.
## `desc` = maior primeiro; no modo NOME, `desc` = A → Z; no modo MANUAL, preserva a ordem da mochila.
static func sort_stacks(list: Array, mode: SortMode, desc: bool) -> Array:
	var out := list.duplicate()
	if mode == SortMode.MANUAL:
		if not desc:
			out.reverse()
		return out
	out.sort_custom(func(a, b):
		var na := MaterialData.of(a.id).display_name.to_lower()
		var nb := MaterialData.of(b.id).display_name.to_lower()
		if mode == SortMode.NOME:
			if na != nb:
				return (na < nb) if desc else (na > nb)
			return a.quality > b.quality
		var ka := _sort_key(a, mode)
		var kb := _sort_key(b, mode)
		if ka != kb:
			return (ka > kb) if desc else (ka < kb)
		if na != nb:
			return na < nb
		return a.quality > b.quality)
	return out

static func _sort_key(s: Dictionary, mode: SortMode) -> float:
	var data := MaterialData.of(s.id)
	match mode:
		SortMode.RARIDADE:
			return float(s.quality)
		SortMode.QUANTIDADE:
			return float(s.amount)
		SortMode.PESO:
			return data.unit_weight * s.amount
		_:
			# Cor: matiz (0 = vermelho … 1 = violeta) invertido para "maior primeiro" começar
			# no vermelho; cores apagadas (cinza, osso) vão para o fim do arco-íris
			return -(data.color.h if data.color.s > 0.18 else 1.0 + data.color.v)

static func stack_key(s: Dictionary) -> String:
	return "%s|%d|%s|%s" % [s.id, s.quality, ",".join(s.traits), MaterialData.memory_text(s.get("memory", {}))]

func refresh() -> void:
	if _grid == null:
		return
	for c in _grid.get_children():
		c.queue_free()
	var all: Array = _inventory.get_stacks() if _inventory else []
	var shown: Array = all.filter(func(s): return group_filter < 0 or MaterialData.of(s.id).category == group_filter)
	shown = sort_stacks(shown, sort_mode, descending)
	for s in shown:
		_grid.add_child(_make_slot(s))
	_empty_hint.visible = shown.is_empty()
	_empty_hint.text = "Nada aqui ainda.\nColete recursos com [E] pelo vale." if all.is_empty() else "Nenhum item neste grupo."

	# Peso contra o limite da mochila (GDD-12 §6.4) + alerta de sobrecarga
	if _inventory:
		var total_w: float = _inventory.get_total_weight()
		var cap_w: float = _inventory.carry_capacity()
		var ratio: float = _inventory.carry_ratio()
		if ratio > Player.OVERLOAD_HARD:
			_weight_label.text = "🛑 SOBRECARGA: %.1f / %.0f kg" % [total_w, cap_w]
			_style_chip(_weight_label, Color(1.0, 0.36, 0.32))
		elif ratio > 1.0:
			_weight_label.text = "⚠️ PESADO: %.1f / %.0f kg" % [total_w, cap_w]
			_style_chip(_weight_label, Color(1.0, 0.72, 0.24))
		else:
			_weight_label.text = "⚖ %.1f / %.0f kg" % [total_w, cap_w]
			_style_chip(_weight_label, Color(0.95, 0.85, 0.6))
		if _relieve_btn:
			_relieve_btn.visible = total_w > cap_w
			if _relieve_btn.visible:
				_relieve_btn.text = "🪶 Aliviar Excesso (−%.1f kg)" % (total_w - cap_w)
	else:
		_weight_label.text = "⚖ 0 kg"
		if _relieve_btn:
			_relieve_btn.visible = false

	if _equipment and visible:
		_equipment.refresh()
	_count_label.text = "%d pilhas" % all.size()
	_refresh_bars(all)
	var still_there := shown.filter(func(s): return stack_key(s) == _selected_key)
	_show_detail(still_there[0] if not still_there.is_empty() else (shown[0] if not shown.is_empty() else {}))

# ---------------------------------------------------------------- ações de jogar no chão / botão direito / arrastar

## Joga `amount` unidades da pilha no chão (criando DroppedLoot no mundo se houver player)
func drop_stack_to_ground(s: Dictionary, amount: int = -1) -> bool:
	if _inventory == null or s.is_empty():
		return false
	if player != null and player.has_method("drop_material_stack"):
		return player.drop_material_stack(s, amount) != null
	return not _inventory.drop_stack(s, amount).is_empty()

## Descarta automaticamente os materiais brutos mais pesados/comuns até voltar ao limite de peso da mochila
func relieve_excess_weight() -> int:
	if _inventory == null:
		return 0
	var excess: float = _inventory.get_total_weight() - _inventory.carry_capacity()
	if excess <= 0.0:
		return 0
	var candidates: Array[Dictionary] = _inventory.get_stacks()
	candidates.sort_custom(func(a, b):
		var da := MaterialData.of(a.id)
		var db := MaterialData.of(b.id)
		var ca: int = 1 if da.is_consumable() else 0
		var cb: int = 1 if db.is_consumable() else 0
		if ca != cb:
			return ca < cb
		if a.quality != b.quality:
			return a.quality < b.quality
		return da.unit_weight > db.unit_weight
	)
	var dropped_units: int = 0
	for s in candidates:
		excess = _inventory.get_total_weight() - _inventory.carry_capacity()
		if excess <= 0.001:
			break
		var unit_w: float = maxf(MaterialData.of(s.id).unit_weight, 0.05)
		var need: int = clampi(ceili(excess / unit_w), 1, int(s.amount))
		if drop_stack_to_ground(s, need):
			dropped_units += need
	return dropped_units

## Processa um drop vindo de clicar e arrastar (na zona de descarte ou fora da janela)
## `mode`: 0 = automático (Ctrl=1, Shift=metade, normal=tudo), 1 = 1 unidade, 2 = metade, 3 = tudo
func handle_ground_drop(data: Variant, mode: int = 0) -> bool:
	if not (data is Dictionary):
		return false
	var d := data as Dictionary
	var kind := StringName(d.get("type", &""))
	if kind == &"forged_item":
		var item := d.get("item") as ForgedItem
		if item == null:
			return false
		if player != null and player.has_method("drop_forged_item"):
			return player.drop_forged_item(item) != null
		elif _inventory != null:
			return _inventory.drop_forged_item(item)
		return false
	if kind == &"material_stack":
		var s: Dictionary = d.get("stack", {})
		if s.is_empty():
			return false
		var total: int = int(s.get("amount", 1))
		var amount: int = total
		if mode == 1 or (mode == 0 and Input.is_key_pressed(KEY_CTRL)):
			amount = 1
		elif mode == 2 or (mode == 0 and Input.is_key_pressed(KEY_SHIFT)):
			amount = maxi(1, total / 2)
		return drop_stack_to_ground(s, amount)
	return false

func _open_context_menu(s: Dictionary, screen_pos: Vector2) -> void:
	if _context_menu == null or s.is_empty():
		return
	_context_stack = s
	_selected_key = stack_key(s)
	refresh()

	var data := MaterialData.of(s.id)
	var amt: int = int(s.amount)
	var unit_w: float = data.unit_weight
	_context_menu.clear()
	_context_menu.add_item("%s %s  (×%d · %.1f kg)" % [data.icon, data.display_name, amt, unit_w * amt], 999)
	_context_menu.set_item_disabled(0, true)
	_context_menu.add_separator()

	if data.is_consumable():
		_context_menu.add_item("🧪 Usar agora (%s)" % data.effect_text(), ContextAction.USE_ITEM)
		_context_menu.add_separator()
	elif data.tool_action == &"plantar":
		_context_menu.add_item("🌱 Escolher para plantar com [G]", ContextAction.SELECT_SEED)
		_context_menu.add_separator()

	_context_menu.add_item("📤 Jogar 1 no chão (−%.2f kg)" % unit_w, ContextAction.DROP_ONE)
	if amt >= 2:
		var half: int = maxi(1, amt / 2)
		_context_menu.add_item("📤 Jogar metade ×%d no chão (−%.1f kg)" % [half, unit_w * half], ContextAction.DROP_HALF)
	_context_menu.add_item("🎒 Jogar pilha toda ×%d no chão (−%.1f kg)" % [amt, unit_w * amt], ContextAction.DROP_ALL)
	_context_menu.add_separator()
	_context_menu.add_item("🗑️ Destruir pilha permanentemente", ContextAction.DESTROY_ALL)

	_context_menu.position = Vector2i(screen_pos)
	_context_menu.popup()

func _on_context_menu_id_pressed(id: int) -> void:
	if _context_stack.is_empty() or _inventory == null:
		return
	var s := _context_stack
	var amt: int = int(s.get("amount", 1))
	match id:
		ContextAction.USE_ITEM:
			if player and player.pools:
				_inventory.use_item(s, player.pools)
		ContextAction.SELECT_SEED:
			if player:
				player.set_meta("seed_traits", s.get("traits", []).duplicate())
				refresh()
		ContextAction.DROP_ONE:
			drop_stack_to_ground(s, 1)
		ContextAction.DROP_HALF:
			drop_stack_to_ground(s, maxi(1, amt / 2))
		ContextAction.DROP_ALL:
			drop_stack_to_ground(s, amt)
		ContextAction.DESTROY_ALL:
			_inventory.consume_stack(s, amt)

# ---------------------------------------------------------------- montagem

func _build_ui() -> void:
	var dim := BackdropDropControl.new()
	dim.screen = self
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.offset_top = 8.0
	center.offset_bottom = -72.0
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(1140, 520)
	panel.add_theme_stylebox_override("panel", _box(PANEL_BG, Color(1, 1, 1, 0.08), 14, 1))
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 8)
	panel.add_child(margin)

	var root_box := VBoxContainer.new()
	root_box.add_theme_constant_override("separation", 8)
	margin.add_child(root_box)

	root_box.add_child(_build_header())
	root_box.add_child(_build_toolbar())

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	root_box.add_child(body)

	_equipment = EquipmentPanel.new()
	body.add_child(_equipment)
	body.add_child(VSeparator.new())

	var middle_col := VBoxContainer.new()
	middle_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	middle_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle_col.add_theme_constant_override("separation", 8)
	body.add_child(middle_col)

	var grid_frame := PanelContainer.new()
	grid_frame.custom_minimum_size = Vector2(470, 0)
	grid_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid_frame.add_theme_stylebox_override("panel", _box(Color(0, 0, 0, 0.25), Color(1, 1, 1, 0.05), 10, 1))
	middle_col.add_child(grid_frame)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	grid_frame.add_child(scroll)

	var grid_margin := MarginContainer.new()
	grid_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		grid_margin.add_theme_constant_override("margin_" + side, 12)
	scroll.add_child(grid_margin)

	var stack_box := VBoxContainer.new()
	grid_margin.add_child(stack_box)
	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 10)
	stack_box.add_child(_grid)

	_empty_hint = Label.new()
	_empty_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_hint.custom_minimum_size = Vector2(0, 200)
	_empty_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_empty_hint.add_theme_color_override("font_color", TEXT_DIM)
	stack_box.add_child(_empty_hint)

	_drop_zone_bar = _build_drop_zone_bar()
	middle_col.add_child(_drop_zone_bar)

	body.add_child(_build_detail_panel())

	_context_menu = PopupMenu.new()
	_context_menu.name = "ItemContextMenu"
	_context_menu.id_pressed.connect(_on_context_menu_id_pressed)
	add_child(_context_menu)

func _build_drop_zone_bar() -> GroundDropZone:
	var zone := GroundDropZone.new()
	zone.name = "GroundDropZone"
	zone.screen = self
	zone.drop_mode = 0
	zone.mouse_default_cursor_shape = Control.CURSOR_CAN_DROP
	zone.add_theme_stylebox_override("panel", _box(Color(0.16, 0.11, 0.06, 0.55), Color(0.95, 0.68, 0.28, 0.45), 10, 1, Vector2(12, 7)))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	zone.add_child(row)

	var hint := Label.new()
	hint.text = "📤 Arraste para o chão  ·  [Dir.] Ações"
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.96, 0.84, 0.62))
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(hint)

	for cfg in [
		{"label": "📤 Soltar 1", "mode": 1, "tip": "Arraste aqui ou clique para jogar 1 unidade do item selecionado"},
		{"label": "📤 Metade", "mode": 2, "tip": "Arraste aqui ou clique para jogar metade da pilha selecionada"},
		{"label": "🎒 Soltar Tudo", "mode": 3, "tip": "Arraste aqui ou clique para jogar a pilha inteira no chão"},
	]:
		var target := DropTargetButton.new()
		target.screen = self
		target.drop_mode = int(cfg["mode"])
		target.text = str(cfg["label"])
		target.tooltip_text = str(cfg["tip"])
		target.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_style_pill(target, Color(0.95, 0.68, 0.28), false)
		target.pressed.connect(_on_quick_drop_pressed.bind(int(cfg["mode"])))
		row.add_child(target)

	return zone

func _on_quick_drop_pressed(mode: int) -> void:
	if _inventory == null or _selected_key.is_empty():
		return
	var found := _inventory.get_stacks().filter(func(s): return stack_key(s) == _selected_key)
	if found.is_empty():
		return
	var s: Dictionary = found[0]
	var amt: int = int(s.get("amount", 1))
	if mode == 1:
		drop_stack_to_ground(s, 1)
	elif mode == 2:
		drop_stack_to_ground(s, maxi(1, amt / 2))
	else:
		drop_stack_to_ground(s, amt)

func _build_header() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var title := Label.new()
	title.text = "🎒  Inventário"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", TEXT)
	row.add_child(title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	_count_label = _chip_label("", TEXT_DIM)
	row.add_child(_count_label)
	_weight_label = _chip_label("", Color(0.95, 0.85, 0.6))
	row.add_child(_weight_label)
	_relieve_btn = Button.new()
	_relieve_btn.name = "RelieveWeightButton"
	_relieve_btn.text = "🪶 Aliviar Excesso"
	_relieve_btn.tooltip_text = "Joga automaticamente no chão os materiais brutos mais pesados/comuns até voltar ao limite da mochila"
	_relieve_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_style_pill(_relieve_btn, Color(1.0, 0.68, 0.24), true)
	_relieve_btn.visible = false
	_relieve_btn.pressed.connect(relieve_excess_weight)
	row.add_child(_relieve_btn)
	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.tooltip_text = "Fechar [I] / [Esc]"
	close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_style_pill(close_btn, Color(0.9, 0.4, 0.4), false)
	close_btn.pressed.connect(close)
	row.add_child(close_btn)
	return row

func _build_toolbar() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)

	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 6)
	row1.add_child(_caption("Organizar"))
	_sort_bar = HBoxContainer.new()
	_sort_bar.add_theme_constant_override("separation", 6)
	row1.add_child(_sort_bar)
	for i in SORT_LABELS.size():
		var b := Button.new()
		b.text = SORT_LABELS[i]
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.pressed.connect(func(): sort_mode = i as SortMode; refresh())
		_sort_bar.add_child(b)
	_dir_button = Button.new()
	_dir_button.tooltip_text = "Inverter a ordem"
	_dir_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_dir_button.pressed.connect(func(): descending = not descending; refresh())
	row1.add_child(_dir_button)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row1.add_child(spacer)
	row1.add_child(_caption("Borda"))
	_border_bar = HBoxContainer.new()
	_border_bar.add_theme_constant_override("separation", 6)
	row1.add_child(_border_bar)
	for i in BORDER_LABELS.size():
		var b := Button.new()
		b.text = BORDER_LABELS[i]
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.pressed.connect(func(): border_mode = i as BorderMode; refresh())
		_border_bar.add_child(b)
	box.add_child(row1)

	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 6)
	row2.add_child(_caption("Grupo"))
	_group_bar = HBoxContainer.new()
	_group_bar.add_theme_constant_override("separation", 6)
	row2.add_child(_group_bar)
	for cat in [-1] + Array(MaterialData.Category.values()):
		var b := Button.new()
		b.set_meta("cat", cat)
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.pressed.connect(func(): group_filter = cat; refresh())
		_group_bar.add_child(b)
	box.add_child(row2)
	return box

func _build_detail_panel() -> Control:
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(240, 0)
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.add_theme_stylebox_override("panel", _box(Color(1, 1, 1, 0.03), Color(1, 1, 1, 0.06), 10, 1))

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.add_child(scroll)

	var m := MarginContainer.new()
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right"]:
		m.add_theme_constant_override("margin_" + side, 12)
	for side in ["top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 8)
	scroll.add_child(m)

	_detail = VBoxContainer.new()
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail.add_theme_constant_override("separation", 6)
	m.add_child(_detail)
	return frame

func _refresh_bars(all: Array) -> void:
	for i in _sort_bar.get_child_count():
		_style_pill(_sort_bar.get_child(i), Color(0.95, 0.78, 0.35), i == sort_mode)
	_dir_button.text = "↓ Maior primeiro" if descending else "↑ Menor primeiro"
	if sort_mode == SortMode.NOME:
		_dir_button.text = "↓ A → Z" if descending else "↑ Z → A"
	elif sort_mode == SortMode.COR:
		_dir_button.text = "↓ Vermelho → Violeta" if descending else "↑ Violeta → Vermelho"
	elif sort_mode == SortMode.MANUAL:
		_dir_button.text = "↓ Ordem Normal" if descending else "↑ Ordem Inversa"
	_style_pill(_dir_button, Color(0.7, 0.75, 0.9), false)
	for i in _border_bar.get_child_count():
		_style_pill(_border_bar.get_child(i), Color(0.6, 0.8, 1.0), i == border_mode)
	for b in _group_bar.get_children():
		var cat: int = b.get_meta("cat")
		var n := all.filter(func(s): return cat < 0 or MaterialData.of(s.id).category == cat).size()
		b.text = "%s  %d" % ["Todos" if cat < 0 else MaterialData.category_name(cat), n]
		var accent := Color(0.75, 0.78, 0.9) if cat < 0 else MaterialData.category_color(cat)
		_style_pill(b, accent, cat == group_filter)

# ---------------------------------------------------------------- slot e detalhe

func _make_slot(s: Dictionary) -> Button:
	var data := MaterialData.of(s.id)
	var rarity := MaterialData.rarity_color(s.quality)
	var group := MaterialData.category_color(data.category)
	var accent := rarity if border_mode == BorderMode.RARIDADE else group
	var selected := stack_key(s) == _selected_key

	var btn := InventorySlotButton.new()
	btn.screen = self
	btn.stack = s
	btn.custom_minimum_size = SLOT_SIZE
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.tooltip_text = "%s · %s · %d un. (%.1f kg)\n[Clique Esq.] Selecionar / Arrastar\n[Clique Dir.] Menu de ações · [Shift+Dir.] Jogar tudo no chão" % [
		data.display_name, MaterialData.rarity_name(s.quality), s.amount, data.unit_weight * s.amount
	]
	var memory := MaterialData.memory_text(s.get("memory", {}))
	if not memory.is_empty():
		btn.tooltip_text = memory + "\n" + btn.tooltip_text
	for st in ["normal", "pressed", "focus"]:
		btn.add_theme_stylebox_override(st, _slot_box(accent, selected, false))
	btn.add_theme_stylebox_override("hover", _slot_box(accent, selected, true))
	btn.pressed.connect(func(): _selected_key = stack_key(s); refresh())
	btn.gui_input.connect(_on_slot_gui_input.bind(s, btn))

	# Faixa do outro critério no topo: grupo quando a borda é raridade, e vice-versa
	var band := ColorRect.new()
	band.color = group if border_mode == BorderMode.RARIDADE else rarity
	band.position = Vector2(8, 6)
	band.size = Vector2(SLOT_SIZE.x - 16, 3)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(band)

	var disc := Panel.new()
	disc.add_theme_stylebox_override("panel", _box(Color(data.color.r, data.color.g, data.color.b, 0.35), Color(data.color.r, data.color.g, data.color.b, 0.6), 24, 1))
	disc.position = Vector2(SLOT_SIZE.x * 0.5 - 24, 13)
	disc.size = Vector2(48, 48)
	disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(disc)

	var icon := Label.new()
	icon.text = data.icon
	icon.add_theme_font_size_override("font_size", 26)
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon.position = disc.position
	icon.size = disc.size
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(icon)

	var stars := Label.new()
	stars.text = "★".repeat(s.quality)
	stars.add_theme_font_size_override("font_size", 10)
	stars.add_theme_color_override("font_color", rarity)
	stars.position = Vector2(7, SLOT_SIZE.y - 20)
	stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(stars)

	var qty := Label.new()
	qty.text = "×%d" % s.amount
	qty.add_theme_font_size_override("font_size", 13)
	qty.add_theme_color_override("font_color", TEXT)
	qty.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	qty.add_theme_constant_override("outline_size", 3)
	qty.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	qty.position = Vector2(0, SLOT_SIZE.y - 21)
	qty.size = Vector2(SLOT_SIZE.x - 7, 18)
	qty.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(qty)

	if not s.traits.is_empty():
		var badge := Label.new()
		badge.text = "✦"
		badge.tooltip_text = ", ".join(s.traits.map(func(t): return MaterialData.trait_name(t)))
		badge.add_theme_color_override("font_color", Color(1.0, 0.85, 0.45))
		badge.position = Vector2(SLOT_SIZE.x - 22, 12)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(badge)
	return btn

func _on_slot_gui_input(event: InputEvent, s: Dictionary, btn: Button) -> void:
	if event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			if mb.shift_pressed:
				drop_stack_to_ground(s, int(s.amount))
			elif mb.ctrl_pressed:
				drop_stack_to_ground(s, 1)
			else:
				_open_context_menu(s, btn.get_screen_position() + mb.position)
			get_viewport().set_input_as_handled()

func _make_drag_preview(s: Dictionary) -> Control:
	var data := MaterialData.of(s.id)
	var rarity := MaterialData.rarity_color(s.quality)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _box(Color(0.06, 0.09, 0.08, 0.94), rarity, 10, 2, Vector2(10, 6)))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	card.add_child(v)
	var top := Label.new()
	top.text = "%s %s ×%d (%.1f kg)" % [data.icon, data.display_name, int(s.amount), data.unit_weight * int(s.amount)]
	top.add_theme_font_size_override("font_size", 13)
	top.add_theme_color_override("font_color", rarity.lightened(0.2))
	v.add_child(top)
	var sub := Label.new()
	sub.text = "📤 Solte fora ou na barra inferior para jogar no chão"
	sub.add_theme_font_size_override("font_size", 10)
	sub.add_theme_color_override("font_color", Color(0.95, 0.82, 0.55))
	v.add_child(sub)
	return card

func _show_detail(s: Dictionary) -> void:
	for c in _detail.get_children():
		c.queue_free()
	if s.is_empty():
		_selected_key = ""
		_detail.add_child(_caption("Selecione um item"))
		return
	_selected_key = stack_key(s)
	var data := MaterialData.of(s.id)
	var rarity := MaterialData.rarity_color(s.quality)

	var icon := Label.new()
	icon.text = data.icon
	icon.add_theme_font_size_override("font_size", 42)
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail.add_child(icon)

	var name_l := Label.new()
	name_l.text = data.display_name
	name_l.add_theme_font_size_override("font_size", 18)
	name_l.add_theme_color_override("font_color", rarity.lightened(0.15))
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.add_child(name_l)

	var chips := HBoxContainer.new()
	chips.alignment = BoxContainer.ALIGNMENT_CENTER
	chips.add_theme_constant_override("separation", 6)
	chips.add_child(_chip_label("%s %s" % ["★".repeat(s.quality), MaterialData.rarity_name(s.quality)], rarity))
	chips.add_child(_chip_label(MaterialData.category_name(data.category), MaterialData.category_color(data.category)))
	_detail.add_child(chips)

	_detail.add_child(HSeparator.new())
	_detail.add_child(_stat_row("Quantidade", "%d" % s.amount))
	_detail.add_child(_stat_row("Peso unitário", "%.2f kg" % data.unit_weight))
	_detail.add_child(_stat_row("Peso da pilha", "%.1f kg" % (data.unit_weight * s.amount)))
	if not s.traits.is_empty():
		_detail.add_child(_stat_row("Traits", ", ".join(s.traits.map(func(t): return MaterialData.trait_name(t)))))
	if s.has("memory"):
		_detail.add_child(_stat_row("Memória", MaterialData.memory_text(s.memory)))

	# Pinhão-Lume: escolhe qual genoma a roda rápida planta com [G] (GDD-10 §9)
	if data.tool_action == &"plantar" and player:
		var chosen: bool = player.get_meta("seed_traits", []) == s.traits
		var seed_btn := Button.new()
		seed_btn.text = "Plantar este com [G]" if not chosen else "Escolhido para plantar"
		seed_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_style_pill(seed_btn, MaterialData.category_color(MaterialData.Category.PLANTA), not chosen)
		seed_btn.pressed.connect(func():
			player.set_meta("seed_traits", s.traits.duplicate())
			seed_btn.text = "Escolhido para plantar")
		_detail.add_child(seed_btn)

	if data.is_consumable():
		_detail.add_child(_stat_row("Efeito", data.effect_text()))
		var use_btn := Button.new()
		use_btn.text = "Usar  (%s)" % data.effect_text()
		use_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_style_pill(use_btn, MaterialData.category_color(MaterialData.Category.CONSUMIVEL), true)
		use_btn.disabled = player == null or player.pools == null
		use_btn.pressed.connect(func():
			if not _inventory.use_item(s, player.pools):
				use_btn.text = "Já está cheio")
		_detail.add_child(use_btn)

	# Ações rápidas para jogar no chão e aliviar peso
	_detail.add_child(HSeparator.new())
	var drop_row := HBoxContainer.new()
	drop_row.add_theme_constant_override("separation", 6)
	var drop_one_btn := Button.new()
	drop_one_btn.name = "DropOneButton"
	drop_one_btn.text = "📤 Jogar 1"
	drop_one_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	drop_one_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_style_pill(drop_one_btn, Color(0.92, 0.68, 0.32), false)
	drop_one_btn.pressed.connect(func(): drop_stack_to_ground(s, 1))
	drop_row.add_child(drop_one_btn)

	if int(s.amount) >= 2:
		var half: int = maxi(1, int(s.amount) / 2)
		var drop_half_btn := Button.new()
		drop_half_btn.name = "DropHalfButton"
		drop_half_btn.text = "📤 ×%d" % half
		drop_half_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		drop_half_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_style_pill(drop_half_btn, Color(0.95, 0.64, 0.28), false)
		drop_half_btn.pressed.connect(func(): drop_stack_to_ground(s, half))
		drop_row.add_child(drop_half_btn)
	_detail.add_child(drop_row)

	var drop_all_btn := Button.new()
	drop_all_btn.name = "DropAllButton"
	drop_all_btn.text = "🎒 Jogar Pilha no Chão (−%.1f kg)" % (data.unit_weight * int(s.amount))
	drop_all_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_style_pill(drop_all_btn, Color(0.96, 0.52, 0.28), false)
	drop_all_btn.pressed.connect(func(): drop_stack_to_ground(s, int(s.amount)))
	_detail.add_child(drop_all_btn)

	_detail.add_child(HSeparator.new())
	var desc := Label.new()
	desc.text = data.description if not data.description.is_empty() else "Sem descrição."
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_color_override("font_color", TEXT_DIM)
	desc.add_theme_font_size_override("font_size", 14)
	_detail.add_child(desc)

# ---------------------------------------------------------------- estilos

func _stat_row(label: String, value: String) -> Control:
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_theme_color_override("font_color", TEXT_DIM)
	l.add_theme_font_size_override("font_size", 14)
	row.add_child(l)
	var v := Label.new()
	v.text = value
	v.add_theme_color_override("font_color", TEXT)
	v.add_theme_font_size_override("font_size", 14)
	row.add_child(v)
	return row

func _caption(text: String) -> Label:
	var l := Label.new()
	l.text = text.to_upper()
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_color_override("font_color", TEXT_DIM)
	l.custom_minimum_size = Vector2(78, 0)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l

func _chip_label(text: String, accent: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 13)
	_style_chip(l, accent)
	return l

func _style_chip(l: Label, accent: Color) -> void:
	l.add_theme_color_override("font_color", accent)
	l.add_theme_stylebox_override("normal", _box(Color(accent.r, accent.g, accent.b, 0.12), Color(accent.r, accent.g, accent.b, 0.4), 10, 1, Vector2(10, 3)))

func _style_pill(btn: Button, accent: Color, active: bool) -> void:
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 13)
	var fg := Color(0.1, 0.08, 0.05) if active else Color(0.78, 0.8, 0.86)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		btn.add_theme_color_override(c, fg)
	var bg := accent if active else Color(1, 1, 1, 0.05)
	var border := accent if active else Color(accent.r, accent.g, accent.b, 0.35)
	btn.add_theme_stylebox_override("normal", _box(bg, border, 12, 1, Vector2(12, 5)))
	btn.add_theme_stylebox_override("pressed", _box(bg, border, 12, 1, Vector2(12, 5)))
	btn.add_theme_stylebox_override("hover", _box(accent.lightened(0.1) if active else Color(1, 1, 1, 0.1), accent, 12, 1, Vector2(12, 5)))

func _slot_box(accent: Color, selected: bool, hovered: bool) -> StyleBoxFlat:
	var s := _box(Color(accent.r, accent.g, accent.b, 0.16 if selected else (0.1 if hovered else 0.05)), Color(accent.r, accent.g, accent.b, 1.0 if selected else (0.85 if hovered else 0.55)), 10, 3 if selected else 2)
	s.border_width_bottom = 4
	s.shadow_color = Color(accent.r, accent.g, accent.b, 0.35 if selected else 0.12)
	s.shadow_size = 8 if selected else 3
	return s

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

# ---------------------------------------------------------------- controles de arrastar e soltar (Drag & Drop)

class InventorySlotButton extends Button:
	var screen: InventoryScreen
	var stack: Dictionary = {}

	func _get_drag_data(_at_position: Vector2) -> Variant:
		if screen == null or stack.is_empty():
			return null
		screen._selected_key = InventoryScreen.stack_key(stack)
		if get_viewport() and get_viewport().gui_is_dragging():
			set_drag_preview(screen._make_drag_preview(stack))
		return {
			"type": &"material_stack",
			"stack": stack,
			"screen": screen,
		}

	func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
		if not (data is Dictionary) or screen == null:
			return false
		var d := data as Dictionary
		return d.get("type") == &"material_stack"

	func _drop_data(_at_position: Vector2, data: Variant) -> void:
		if not (data is Dictionary) or screen == null or screen._inventory == null:
			return
		var d := data as Dictionary
		var src_stack: Dictionary = d.get("stack", {})
		if src_stack.is_empty() or InventoryScreen.stack_key(src_stack) == InventoryScreen.stack_key(stack):
			return
		InventoryScreen.sort_mode = InventoryScreen.SortMode.MANUAL
		screen._inventory.swap_stacks(src_stack, stack)

class GroundDropZone extends PanelContainer:
	var screen: InventoryScreen
	var drop_mode: int = 0

	func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
		if not (data is Dictionary):
			return false
		var kind := StringName((data as Dictionary).get("type", &""))
		return kind == &"material_stack" or kind == &"forged_item"

	func _drop_data(_at_position: Vector2, data: Variant) -> void:
		if screen:
			screen.handle_ground_drop(data, drop_mode)

class DropTargetButton extends Button:
	var screen: InventoryScreen
	var drop_mode: int = 0

	func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
		if not (data is Dictionary):
			return false
		var kind := StringName((data as Dictionary).get("type", &""))
		return kind == &"material_stack" or kind == &"forged_item"

	func _drop_data(_at_position: Vector2, data: Variant) -> void:
		if screen:
			screen.handle_ground_drop(data, drop_mode)

class BackdropDropControl extends ColorRect:
	var screen: InventoryScreen

	func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
		if not (data is Dictionary):
			return false
		var kind := StringName((data as Dictionary).get("type", &""))
		return kind == &"material_stack" or kind == &"forged_item"

	func _drop_data(_at_position: Vector2, data: Variant) -> void:
		if screen:
			screen.handle_ground_drop(data, 0)
