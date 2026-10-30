class_name RoastSpitMinigame
extends Control

const _Player = preload("res://scripts/player.gd")
const _InventoryComponent = preload("res://scripts/components/inventory_component.gd")
const _FoodBuffComponent = preload("res://scripts/components/food_buff_component.gd")
const _MaterialData = preload("res://scripts/data/material_data.gd")

## Minigame do Espeto na Fogueira (GDD-13 §2).
## Estilo Monster Hunter: gira a carne no espeto sobre o fogo.
## Janela ideal:
## - 0.0s a 3.5s: Malpassada / Crua (carne_mal_passada)
## - 3.6s a 4.8s: No Ponto Perfeita! (carne_bem_passada + buff Bem Alimentado)
## - 4.9s+: Queimada (carne_torrada)

signal roast_finished(result_id: StringName, quality: int)

const TIME_SWEET_START: float = 3.6
const TIME_SWEET_END: float = 4.8
const TIME_BURNT: float = 4.9
const MAX_TIME: float = 6.0

var player: _Player
var current_meat_stack: Dictionary = {}
var is_roasting: bool = false
var elapsed: float = 0.0

var _panel: PanelContainer
var _title_label: Label
var _status_label: Label
var _progress_bar: ProgressBar
var _needle: ColorRect
var _action_button: Button
var _close_button: Button
var _spit_display: Label
var _sweet_zone_indicator: ColorRect
var _has_finished: bool = false

func _ready() -> void:
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()

func _build_ui() -> void:
	# Fundo escuro semi-transparente
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.04, 0.03, 0.82)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(520, 360)
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.anchor_left = 0.5
	_panel.anchor_top = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_bottom = 0.5
	_panel.offset_left = -260
	_panel.offset_top = -180
	_panel.offset_right = 260
	_panel.offset_bottom = 180

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.10, 0.08, 0.98)
	style.border_color = Color(0.85, 0.55, 0.22)
	style.set_border_width_all(3)
	style.set_corner_radius_all(8)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	margin.add_child(vbox)

	_title_label = Label.new()
	_title_label.text = "🔥 ESPETO DE CHURRASCO NA FOGUEIRA"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_color_override("font_color", Color(1.0, 0.75, 0.35))
	_title_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(_title_label)

	_spit_display = Label.new()
	_spit_display.text = "🥩"
	_spit_display.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_spit_display.add_theme_font_size_override("font_size", 48)
	vbox.add_child(_spit_display)

	_status_label = Label.new()
	_status_label.text = "Aguarde o ponto certo e puxe o espeto!"
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_color_override("font_color", Color(0.9, 0.88, 0.82))
	vbox.add_child(_status_label)

	# Container da Barra de Ponto
	var bar_container := Control.new()
	bar_container.custom_minimum_size = Vector2(460, 36)
	vbox.add_child(bar_container)

	# Fundo da trilha
	var bar_bg := ColorRect.new()
	bar_bg.color = Color(0.2, 0.18, 0.15)
	bar_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bar_container.add_child(bar_bg)

	# Zona Doce (No Ponto / Perfeita)
	_sweet_zone_indicator = ColorRect.new()
	_sweet_zone_indicator.color = Color(0.25, 0.85, 0.35, 0.75)
	var left_pct: float = TIME_SWEET_START / MAX_TIME
	var width_pct: float = (TIME_SWEET_END - TIME_SWEET_START) / MAX_TIME
	_sweet_zone_indicator.anchor_left = left_pct
	_sweet_zone_indicator.anchor_right = left_pct + width_pct
	_sweet_zone_indicator.anchor_top = 0.0
	_sweet_zone_indicator.anchor_bottom = 1.0
	bar_container.add_child(_sweet_zone_indicator)

	# Zona Queimada
	var burn_zone := ColorRect.new()
	burn_zone.color = Color(0.85, 0.2, 0.15, 0.6)
	burn_zone.anchor_left = TIME_BURNT / MAX_TIME
	burn_zone.anchor_right = 1.0
	burn_zone.anchor_top = 0.0
	burn_zone.anchor_bottom = 1.0
	bar_container.add_child(burn_zone)

	# Ponteiro indicador
	_needle = ColorRect.new()
	_needle.color = Color(1.0, 0.95, 0.4)
	_needle.custom_minimum_size = Vector2(6, 44)
	_needle.position = Vector2(0, -4)
	bar_container.add_child(_needle)

	# Legenda informativa
	var legend := HBoxContainer.new()
	legend.alignment = BoxContainer.ALIGNMENT_CENTER
	legend.add_theme_constant_override("separation", 24)
	var l_raw := Label.new()
	l_raw.text = "🔵 Malpassada"
	l_raw.add_theme_font_size_override("font_size", 12)
	var l_sweet := Label.new()
	l_sweet.text = "🟢 No Ponto (Perfeita!)"
	l_sweet.add_theme_font_size_override("font_size", 12)
	l_sweet.add_theme_color_override("font_color", Color(0.4, 0.95, 0.5))
	var l_burn := Label.new()
	l_burn.text = "🔴 Queimada"
	l_burn.add_theme_font_size_override("font_size", 12)
	legend.add_child(l_raw)
	legend.add_child(l_sweet)
	legend.add_child(l_burn)
	vbox.add_child(legend)

	# Botões de Ação
	var btn_box := HBoxContainer.new()
	btn_box.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_box.add_theme_constant_override("separation", 16)
	vbox.add_child(btn_box)

	_action_button = Button.new()
	_action_button.text = "🍗 Puxar o Espeto! [Espaço]"
	_action_button.custom_minimum_size = Vector2(200, 42)
	_action_button.pressed.connect(_on_action_pressed)
	btn_box.add_child(_action_button)

	_close_button = Button.new()
	_close_button.text = "Sair [Esc]"
	_close_button.custom_minimum_size = Vector2(100, 42)
	_close_button.pressed.connect(close)
	btn_box.add_child(_close_button)

func open(p_player: _Player) -> void:
	player = p_player
	if player == null or player.inventory == null:
		return
	
	add_to_group("open_menus")
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	# Busca carne crua ou peixe
	var meat_stacks: Array[Dictionary] = player.inventory.get_stacks(&"carne_crua")
	if meat_stacks.is_empty():
		meat_stacks = player.inventory.get_stacks(&"carne_mal_passada")
	if meat_stacks.is_empty():
		meat_stacks = player.inventory.get_stacks(&"peixe_lambari")

	if meat_stacks.is_empty():
		_show_no_meat()
		visible = true
		return

	current_meat_stack = meat_stacks[0]
	_start_roast()
	visible = true

func _show_no_meat() -> void:
	is_roasting = false
	_has_finished = true
	_status_label.text = "Você não possui carne crua ou peixe na mochila!"
	_spit_display.text = "❌"
	_action_button.text = "Sem carne crua"
	_action_button.disabled = true

func _start_roast() -> void:
	is_roasting = true
	_has_finished = false
	elapsed = 0.0
	_action_button.disabled = false
	_action_button.text = "🍗 Puxar o Espeto! [Espaço]"
	_status_label.text = "Assando na brasa... aguarde o momento perfeito!"
	_spit_display.text = "🥩"

func _process(delta: float) -> void:
	if not visible or not is_roasting:
		return

	elapsed += delta
	var progress: float = clampf(elapsed / MAX_TIME, 0.0, 1.0)
	_needle.position.x = progress * 454.0

	# Animação do espeto e feedback de áudio/visual
	if elapsed < TIME_SWEET_START:
		_status_label.text = "🔥 A carne está chiando e esquentando... (Malpassada)"
		_status_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		_spit_display.text = "🥩"
	elif elapsed <= TIME_SWEET_END:
		# Ponto perfeito!
		var flash: bool = int(elapsed * 8.0) % 2 == 0
		_status_label.text = "✨ CHEIRO DELICIOSO! PUXE AGORA! ✨"
		_status_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3) if flash else Color(0.4, 1.0, 0.4))
		_spit_display.text = "🍖"
	else:
		# Queimando!
		_status_label.text = "💨 FUMAÇA PRETA! A carne está queimando!"
		_status_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.3))
		_spit_display.text = "🔥"

	if elapsed >= MAX_TIME:
		# Auto-finaliza como queimada
		pull_spit()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE):
		close()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed and event.keycode == KEY_E):
		if is_roasting:
			pull_spit()
			get_viewport().set_input_as_handled()
		elif _has_finished:
			# Tenta assar outra se tiver
			_try_roast_another()
			get_viewport().set_input_as_handled()

func _on_action_pressed() -> void:
	if is_roasting:
		pull_spit()
	elif _has_finished:
		_try_roast_another()

func _try_roast_another() -> void:
	if player and player.inventory:
		var meat_stacks: Array[Dictionary] = player.inventory.get_stacks(&"carne_crua")
		if not meat_stacks.is_empty():
			current_meat_stack = meat_stacks[0]
			_start_roast()
			return
	_show_no_meat()

## Puxa o espeto e processa o resultado conforme o tempo decorrido
func pull_spit() -> Dictionary:
	if not is_roasting or current_meat_stack.is_empty() or player == null:
		return {}

	is_roasting = false
	_has_finished = true

	var inv: _InventoryComponent = player.inventory
	var base_q: int = int(current_meat_stack.get("quality", 1))
	var base_traits: Array = current_meat_stack.get("traits", []).duplicate()

	# Consome a carne crua do inventário
	inv.consume_stack(current_meat_stack, 1)

	var result_id: StringName = &"carne_mal_passada"
	var out_q: int = base_q
	var message: String = ""

	if elapsed < TIME_SWEET_START:
		result_id = &"carne_mal_passada"
		out_q = base_q
		message = "Carne Malpassada obtida. Faltou um pouco de fogo!"
		_spit_display.text = "🥩"
		_status_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.9))
	elif elapsed <= TIME_SWEET_END:
		# PONTO PERFEITO! Bônus de qualidade e buff
		result_id = &"carne_bem_passada"
		out_q = maxi(base_q, 3) # Pelo menos 3★ pela maestria do ponto
		message = "🎉 NO PONTO PERFEITO! Carne Suculenta e Dourada!"
		_spit_display.text = "🍖"
		_status_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))

		# Concede imediatamente o buff Bem Alimentado se o player tiver FoodBuffComponent
		if player.food_buff:
			player.food_buff.apply_food_buff(&"bem_alimentado", 600.0, out_q, base_traits)
	else:
		result_id = &"carne_torrada"
		out_q = 1
		message = "💀 Queimou! A carne virou carvão."
		_spit_display.text = "🪨"
		_status_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))

	inv.add_material(result_id, 1, out_q, base_traits)
	EventBusAutoload.report(player, &"cozinha", {"result": String(result_id), "quality": out_q, "burned": result_id == &"carne_torrada"})
	_status_label.text = message
	_action_button.text = "Assar mais uma [Espaço]"

	roast_finished.emit(result_id, out_q)
	return {"result_id": result_id, "quality": out_q, "message": message}

func close() -> void:
	is_roasting = false
	visible = false
	remove_from_group("open_menus")
	if is_inside_tree() and get_tree().get_nodes_in_group("open_menus").is_empty():
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
