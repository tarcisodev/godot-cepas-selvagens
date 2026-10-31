class_name CookingScreen
extends Control

const _Player = preload("res://scripts/player.gd")
const _InventoryComponent = preload("res://scripts/components/inventory_component.gd")
const _CookingSystem = preload("res://scripts/systems/cooking_system.gd")
const _LedgerExchanges = preload("res://scripts/net/ledger_exchanges.gd")
const _MaterialData = preload("res://scripts/data/material_data.gd")

## Tela Interativa do Caldeirão Culinário (GDD-13 §4).
## Permite combinar 1 Base + 1 a 3 Acompanhamentos para preparar receitas
## gastronômicas com buffs de longa duração e qualidade derivada dos insumos.

const TEXT_COLOR := Color(0.92, 0.9, 0.86)
const ACCENT_COLOR := Color(1.0, 0.72, 0.3)
const BG_DARK := Color(0.10, 0.09, 0.08, 0.96)

var player: _Player

## Itens selecionados nos slots de cozimento
var selected_base_stack: Dictionary = {}
var selected_side_stacks: Array[Dictionary] = []

var _base_slot_btn: Button
var _side_slot_btns: Array[Button] = []
var _inventory_list: VBoxContainer
var _preview_title: Label
var _preview_icon: Label
var _preview_stars: Label
var _preview_buff: Label
var _preview_desc: Label
var _cook_button: Button
var _feedback_label: Label
var _recipe_list_box: VBoxContainer

func _ready() -> void:
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.04, 0.03, 0.85)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -460
	panel.offset_top = -290
	panel.offset_right = 460
	panel.offset_bottom = 290

	var style := StyleBoxFlat.new()
	style.bg_color = BG_DARK
	style.border_color = ACCENT_COLOR
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 12)
	margin.add_child(main_vbox)

	# Cabeçalho
	var header := HBoxContainer.new()
	var title := Label.new()
	title.text = "🍲 CALDEIRÃO CULINÁRIO DO VALE"
	title.add_theme_color_override("font_color", ACCENT_COLOR)
	title.add_theme_font_size_override("font_size", 20)
	header.add_child(title)

	header.add_spacer(false)
	var close_btn := Button.new()
	close_btn.text = "✕ Fechar [Esc]"
	close_btn.pressed.connect(close)
	header.add_child(close_btn)
	main_vbox.add_child(header)

	# 3 Colunas: [Mochila / Ingredientes] | [Caldeirão & Prévia] | [Livro de Receitas]
	var cols := HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 16)
	main_vbox.add_child(cols)

	# --- COLUNA 1: INGREDIENTES DA MOCHILA ---
	var col1 := VBoxContainer.new()
	col1.custom_minimum_size = Vector2(250, 0)
	var col1_lbl := Label.new()
	col1_lbl.text = "🎒 Insumos na Mochila"
	col1_lbl.add_theme_color_override("font_color", ACCENT_COLOR)
	col1.add_child(col1_lbl)

	var scroll1 := ScrollContainer.new()
	scroll1.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col1.add_child(scroll1)

	_inventory_list = VBoxContainer.new()
	_inventory_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inventory_list.add_theme_constant_override("separation", 4)
	scroll1.add_child(_inventory_list)
	cols.add_child(col1)

	# --- COLUNA 2: CALDEIRÃO & PRÉVIA ---
	var col2 := VBoxContainer.new()
	col2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col2.add_theme_constant_override("separation", 10)

	var slots_card := PanelContainer.new()
	var slot_style := StyleBoxFlat.new()
	slot_style.bg_color = Color(0.15, 0.13, 0.11)
	slot_style.set_corner_radius_all(8)
	slots_card.add_theme_stylebox_override("panel", slot_style)
	col2.add_child(slots_card)

	var slots_margin := MarginContainer.new()
	slots_margin.add_theme_constant_override("margin_left", 12)
	slots_margin.add_theme_constant_override("margin_right", 12)
	slots_margin.add_theme_constant_override("margin_top", 10)
	slots_margin.add_theme_constant_override("margin_bottom", 10)
	slots_card.add_child(slots_margin)

	var slots_vbox := VBoxContainer.new()
	slots_vbox.add_theme_constant_override("separation", 8)
	slots_margin.add_child(slots_vbox)

	var slot_title := Label.new()
	slot_title.text = "Slots do Caldeirão (1 Base + até 3 Acompanhamentos)"
	slot_title.add_theme_font_size_override("font_size", 13)
	slots_vbox.add_child(slot_title)

	var slots_hbox := HBoxContainer.new()
	slots_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	slots_hbox.add_theme_constant_override("separation", 10)

	_base_slot_btn = Button.new()
	_base_slot_btn.custom_minimum_size = Vector2(85, 75)
	_base_slot_btn.text = "🥩\n[Base]"
	_base_slot_btn.pressed.connect(_clear_base)
	slots_hbox.add_child(_base_slot_btn)

	for i in 3:
		var side_btn := Button.new()
		side_btn.custom_minimum_size = Vector2(85, 75)
		side_btn.text = "🌿\n[Extra %d]" % (i + 1)
		var idx := i
		side_btn.pressed.connect(func(): _remove_side(idx))
		slots_hbox.add_child(side_btn)
		_side_slot_btns.append(side_btn)
	slots_vbox.add_child(slots_hbox)

	# Painel de Prévia do Prato
	var preview_card := PanelContainer.new()
	preview_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var p_style := StyleBoxFlat.new()
	p_style.bg_color = Color(0.18, 0.15, 0.12)
	p_style.set_corner_radius_all(8)
	preview_card.add_theme_stylebox_override("panel", p_style)
	col2.add_child(preview_card)

	var p_margin := MarginContainer.new()
	p_margin.add_theme_constant_override("margin_left", 14)
	p_margin.add_theme_constant_override("margin_right", 14)
	p_margin.add_theme_constant_override("margin_top", 12)
	p_margin.add_theme_constant_override("margin_bottom", 12)
	preview_card.add_child(p_margin)

	var p_vbox := VBoxContainer.new()
	p_vbox.add_theme_constant_override("separation", 6)
	p_margin.add_child(p_vbox)

	var p_top := HBoxContainer.new()
	_preview_icon = Label.new()
	_preview_icon.text = "🍲"
	_preview_icon.add_theme_font_size_override("font_size", 28)
	p_top.add_child(_preview_icon)

	var p_info := VBoxContainer.new()
	_preview_title = Label.new()
	_preview_title.text = "Adicione uma Base e Acompanhamentos"
	_preview_title.add_theme_color_override("font_color", ACCENT_COLOR)
	_preview_title.add_theme_font_size_override("font_size", 15)
	_preview_stars = Label.new()
	_preview_stars.text = "★☆☆☆☆"
	_preview_stars.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	p_info.add_child(_preview_title)
	p_info.add_child(_preview_stars)
	p_top.add_child(p_info)
	p_vbox.add_child(p_top)

	_preview_buff = Label.new()
	_preview_buff.text = "Buff gastronômico: -"
	_preview_buff.add_theme_color_override("font_color", Color(0.4, 0.9, 0.5))
	p_vbox.add_child(_preview_buff)

	_preview_desc = Label.new()
	_preview_desc.text = "Selecione insumos à esquerda ou uma receita à direita."
	_preview_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_preview_desc.add_theme_color_override("font_color", Color(0.75, 0.73, 0.7))
	_preview_desc.add_theme_font_size_override("font_size", 12)
	p_vbox.add_child(_preview_desc)

	_feedback_label = Label.new()
	_feedback_label.text = ""
	_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	p_vbox.add_child(_feedback_label)

	_cook_button = Button.new()
	_cook_button.text = "🍲 Cozinhar Refeição"
	_cook_button.custom_minimum_size = Vector2(0, 42)
	_cook_button.disabled = true
	_cook_button.pressed.connect(_on_cook_pressed)
	p_vbox.add_child(_cook_button)

	cols.add_child(col2)

	# --- COLUNA 3: LIVRO DE RECEITAS ---
	var col3 := VBoxContainer.new()
	col3.custom_minimum_size = Vector2(260, 0)
	var col3_lbl := Label.new()
	col3_lbl.text = "📜 Receitas Conhecidas"
	col3_lbl.add_theme_color_override("font_color", ACCENT_COLOR)
	col3.add_child(col3_lbl)

	var scroll3 := ScrollContainer.new()
	scroll3.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col3.add_child(scroll3)

	_recipe_list_box = VBoxContainer.new()
	_recipe_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_recipe_list_box.add_theme_constant_override("separation", 6)
	scroll3.add_child(_recipe_list_box)
	cols.add_child(col3)

func open(p_player: _Player) -> void:
	player = p_player
	visible = true
	add_to_group("open_menus")
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	selected_base_stack.clear()
	selected_side_stacks.clear()
	_feedback_label.text = ""
	_refresh_all()

func close() -> void:
	visible = false
	remove_from_group("open_menus")
	if is_inside_tree() and get_tree().get_nodes_in_group("open_menus").is_empty():
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	selected_base_stack.clear()
	selected_side_stacks.clear()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE):
		close()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		close()
		get_viewport().set_input_as_handled()

func _refresh_all() -> void:
	_refresh_inventory_list()
	_refresh_slots_ui()
	_refresh_recipes_book()
	_refresh_preview()

func _refresh_inventory_list() -> void:
	for child in _inventory_list.get_children():
		child.queue_free()

	if player == null or player.inventory == null:
		return

	var stacks := player.inventory.stacks
	var valid_found := false

	for s in stacks:
		var mat_id: StringName = s.id
		var is_base: bool = _CookingSystem.VALID_BASES.has(mat_id)
		var is_side: bool = _CookingSystem.VALID_SIDES.has(mat_id)

		if not (is_base or is_side):
			continue

		valid_found = true
		var data := _MaterialData.of(mat_id)
		var btn := Button.new()
		btn.text = "%s %s (%d★) ×%d" % [data.icon, data.display_name, s.quality, s.amount]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.add_theme_font_size_override("font_size", 12)

		var stack_ref := s
		btn.pressed.connect(func(): _on_inventory_item_clicked(stack_ref, is_base, is_side))
		_inventory_list.add_child(btn)

	if not valid_found:
		var empty_lbl := Label.new()
		empty_lbl.text = "Nenhum insumo culinário encontrado na mochila."
		empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_lbl.add_theme_font_size_override("font_size", 11)
		_inventory_list.add_child(empty_lbl)

func _on_inventory_item_clicked(stack: Dictionary, is_base: bool, is_side: bool) -> void:
	_feedback_label.text = ""
	# Se ainda não escolheu base e o item pode ser base, preenche a base
	if selected_base_stack.is_empty() and is_base:
		selected_base_stack = stack
	elif is_side and selected_side_stacks.size() < 3:
		selected_side_stacks.append(stack)
	elif is_base:
		selected_base_stack = stack
	_refresh_slots_ui()
	_refresh_preview()

func _clear_base() -> void:
	selected_base_stack.clear()
	_refresh_slots_ui()
	_refresh_preview()

func _remove_side(idx: int) -> void:
	if idx >= 0 and idx < selected_side_stacks.size():
		selected_side_stacks.remove_at(idx)
	_refresh_slots_ui()
	_refresh_preview()

func _refresh_slots_ui() -> void:
	if selected_base_stack.is_empty():
		_base_slot_btn.text = "🥩\n[Base]"
		_base_slot_btn.modulate = Color(0.7, 0.7, 0.7)
	else:
		var d := _MaterialData.of(selected_base_stack.id)
		_base_slot_btn.text = "%s\n%s\n(%d★)" % [d.icon, d.display_name, selected_base_stack.quality]
		_base_slot_btn.modulate = Color(1.0, 1.0, 1.0)

	for i in 3:
		var btn: Button = _side_slot_btns[i]
		if i < selected_side_stacks.size():
			var s: Dictionary = selected_side_stacks[i]
			var d := _MaterialData.of(s.id)
			btn.text = "%s\n%s\n(%d★)" % [d.icon, d.display_name, s.quality]
			btn.modulate = Color(1.0, 1.0, 1.0)
		else:
			btn.text = "🌿\n[Extra %d]" % (i + 1)
			btn.modulate = Color(0.6, 0.6, 0.6)

func _refresh_preview() -> void:
	if selected_base_stack.is_empty() or selected_side_stacks.is_empty():
		_preview_title.text = "Selecione 1 Base e pelo menos 1 Acompanhamento"
		_preview_stars.text = ""
		_preview_buff.text = "Buff gastronômico: -"
		_preview_desc.text = "Adicione ingredientes para antecipar o prato."
		_cook_button.disabled = true
		return

	var base_id := StringName(selected_base_stack.get("id", &""))
	var side_ids: Array[StringName] = []
	for s in selected_side_stacks:
		side_ids.append(StringName(s.get("id", &"")))

	var recipe := _CookingSystem.evaluate_recipe(base_id, side_ids)
	if recipe.is_empty():
		_preview_title.text = "Combinação incompatível"
		_preview_stars.text = ""
		_preview_buff.text = "-"
		_preview_desc.text = "Estes ingredientes não combinam."
		_cook_button.disabled = true
		return

	var q: int = _CookingSystem.calculate_quality(selected_base_stack, selected_side_stacks)
	var res_data := _MaterialData.of(recipe.get("result_id", &"ensopado_campeiro"))

	_preview_icon.text = res_data.icon
	_preview_title.text = recipe.get("name", "Prato Preparado")
	_preview_stars.text = "★".repeat(q) + "☆".repeat(5 - q)
	_preview_buff.text = "Buff: %s" % recipe.get("buff_desc", "")
	_preview_desc.text = recipe.get("desc", "")
	_cook_button.disabled = false

func _refresh_recipes_book() -> void:
	for child in _recipe_list_box.get_children():
		child.queue_free()

	for r in _CookingSystem.RECIPES:
		var panel := PanelContainer.new()
		var p_style := StyleBoxFlat.new()
		p_style.bg_color = Color(0.14, 0.12, 0.10)
		p_style.set_corner_radius_all(6)
		panel.add_theme_stylebox_override("panel", p_style)

		var m := MarginContainer.new()
		m.add_theme_constant_override("margin_left", 8)
		m.add_theme_constant_override("margin_right", 8)
		m.add_theme_constant_override("margin_top", 6)
		m.add_theme_constant_override("margin_bottom", 6)
		panel.add_child(m)

		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 2)
		m.add_child(vb)

		var r_title := Label.new()
		r_title.text = r.name
		r_title.add_theme_color_override("font_color", ACCENT_COLOR)
		r_title.add_theme_font_size_override("font_size", 12)
		vb.add_child(r_title)

		var r_reqs := Label.new()
		var req_names: Array[String] = []
		for req_id in r.required_ingredients:
			req_names.append(_MaterialData.of(req_id).display_name)
		r_reqs.text = "Requer: Base + %s" % ", ".join(req_names)
		r_reqs.add_theme_font_size_override("font_size", 10)
		r_reqs.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		vb.add_child(r_reqs)

		var r_buff := Label.new()
		r_buff.text = "✨ %s" % r.buff_name
		r_buff.add_theme_font_size_override("font_size", 10)
		r_buff.add_theme_color_override("font_color", Color(0.4, 0.9, 0.5))
		vb.add_child(r_buff)

		var auto_btn := Button.new()
		auto_btn.text = "Auto-preencher"
		auto_btn.add_theme_font_size_override("font_size", 10)
		var recipe_ref := r
		auto_btn.pressed.connect(func(): _auto_fill_recipe(recipe_ref))
		vb.add_child(auto_btn)

		_recipe_list_box.add_child(panel)

func _auto_fill_recipe(recipe: Dictionary) -> void:
	if player == null or player.inventory == null:
		return
	var inv := player.inventory
	var found_base := false

	# Busca uma base válida
	for b_id in recipe.base_candidates:
		var st := inv.get_stacks(b_id)
		if not st.is_empty():
			selected_base_stack = st[0]
			found_base = true
			break

	if not found_base:
		_feedback_label.text = "Você não possui a carne ou peixe base para esta receita!"
		return

	# Busca acompanhamentos requeridos
	selected_side_stacks.clear()
	for req_id in recipe.required_ingredients:
		var st := inv.get_stacks(req_id)
		if not st.is_empty():
			selected_side_stacks.append(st[0])

	_feedback_label.text = "Ingredientes alocados para %s!" % recipe.name
	_refresh_slots_ui()
	_refresh_preview()

func _on_cook_pressed() -> void:
	if player == null or player.inventory == null:
		return

	# No online o servidor refaz o prato no livro dele (B41)
	var res := _LedgerExchanges.cook(player, selected_base_stack, selected_side_stacks)
	if res.get("success", false):
		_feedback_label.text = "🎉 %s (%d★) cozinhado com sucesso!" % [res.recipe_name, res.quality]
		selected_base_stack.clear()
		selected_side_stacks.clear()
		_refresh_all()
	else:
		_feedback_label.text = "Falha: %s" % res.get("reason", "Erro desconhecido")
