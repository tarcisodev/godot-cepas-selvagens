extends Control
class_name PauseMenu

## Menu de Pausa (ESC)
# Pausa o mundo e oferece Continuar, Configurações e Sair.
# A tela de Configurações altera o GameSettings na hora e salva ao voltar.

var is_open: bool = false
## Na tela de título o menu só serve para Configurações: "Voltar" fecha e o mouse continua livre.
var in_title_screen: bool = false

var main_panel: PanelContainer
var settings_panel: PanelContainer
var continue_button: Button
var back_button: Button

# Controles da tela de Configurações, por "secao/chave", para atualizar ao resetar
var _setting_controls: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false

	# Fundo escurecido atrás do menu
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	_build_main_panel()
	_build_settings_panel()

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if in_title_screen and not is_open:
		return
	# Outro menu aberto (inventário, álbum, obras...): o Esc é dele, para fechá-lo
	if not is_open and not get_tree().get_nodes_in_group("open_menus").is_empty():
		return
	if not is_open:
		open_menu()
	elif settings_panel.visible:
		_show_main()
	else:
		close_menu()
	get_viewport().set_input_as_handled()

func open_menu() -> void:
	is_open = true
	visible = true
	add_to_group("open_menus")
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if not in_title_screen:
		_show_main()

func close_menu() -> void:
	GameSettings.save()
	is_open = false
	visible = false
	remove_from_group("open_menus")
	get_tree().paused = false
	if not in_title_screen:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

## Abre direto nas Configurações (usado pela tela de título).
func open_settings() -> void:
	open_menu()
	_show_settings()

func _show_main() -> void:
	GameSettings.save()
	if in_title_screen:
		close_menu()
		return
	settings_panel.visible = false
	main_panel.visible = true
	_center.call_deferred(main_panel)
	continue_button.grab_focus()

func _show_settings() -> void:
	main_panel.visible = false
	settings_panel.visible = true
	_center.call_deferred(settings_panel)
	back_button.grab_focus()

## Recentraliza o painel com o tamanho atual (o menu pode ter sido criado antes de ter tamanho).
func _center(panel: Control) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_KEEP_SIZE)

# --- Construção da interface -------------------------------------------------

func _make_panel(min_width: float) -> Array:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.custom_minimum_size = Vector2(min_width, 0)
	add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)
	return [panel, box]

func _make_title(text: String) -> Label:
	var title := Label.new()
	title.text = text
	title.add_theme_font_size_override("font_size", 20)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return title

func _make_section(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color(0.75, 0.88, 0.7))
	return label

func _make_button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", 15)
	button.custom_minimum_size = Vector2(0, 36)
	button.pressed.connect(callback)
	return button

func _build_main_panel() -> void:
	var parts: Array = _make_panel(300.0)
	main_panel = parts[0]
	var box: VBoxContainer = parts[1]

	box.add_child(_make_title("🌿 Cepas Selvagens"))
	continue_button = _make_button("▶ Continuar", close_menu)
	box.add_child(continue_button)
	box.add_child(_make_button("⚙ Configurações", _show_settings))
	box.add_child(_make_button("💾 Salvar e voltar ao título", _save_and_return_to_title))
	box.add_child(_make_button("🚪 Salvar e sair do jogo", func(): GameSettings.save(); SaveGame.save_game(); get_tree().quit()))

func _save_and_return_to_title() -> void:
	SaveGame.save_game()
	GameSettings.save()
	is_open = false
	remove_from_group("open_menus")
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _build_settings_panel() -> void:
	var parts: Array = _make_panel(440.0)
	settings_panel = parts[0]
	var box: VBoxContainer = parts[1]

	box.add_child(_make_title("⚙ Configurações"))

	box.add_child(_make_section("🔊 Som"))
	box.add_child(_make_volume_row("Volume Principal", "master"))
	box.add_child(_make_volume_row("Som Ambiente", "ambient"))
	box.add_child(_make_volume_row("Música", "music"))
	box.add_child(_make_volume_row("Efeitos (passos)", "effects"))

	box.add_child(_make_section("🖱 Controles"))
	box.add_child(_make_slider_row("Sensibilidade do Mouse", "controls", "mouse_sensitivity", 0.2, 3.0, 0.1, "%.1fx"))
	box.add_child(_make_check_row("Inverter Eixo Vertical", "controls", "invert_y"))

	box.add_child(_make_section("🖥 Vídeo e Interface"))
	box.add_child(_make_check_row("Tela Cheia", "video", "fullscreen"))
	box.add_child(_make_check_row("VSync (Sincronia Vertical)", "video", "vsync"))
	box.add_child(_make_check_row("Mostrar Dicas de Controle", "video", "show_tips"))

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	var reset_button := _make_button("↺ Restaurar Padrões", _on_reset_pressed)
	reset_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back_button = _make_button("← Voltar", _show_main)
	back_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(reset_button)
	buttons.add_child(back_button)
	box.add_child(buttons)

	settings_panel.visible = false

func _make_volume_row(label_text: String, key: String) -> HBoxContainer:
	return _make_slider_row(label_text, "audio", key, 0.0, 100.0, 1.0, "%d%%")

func _make_slider_row(label_text: String, section: String, key: String, min_v: float, max_v: float, step: float, fmt: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(190, 0)
	row.add_child(label)

	var slider := HSlider.new()
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = step
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slider)

	var value_label := Label.new()
	value_label.custom_minimum_size = Vector2(52, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value_label)

	slider.value_changed.connect(func(v: float):
		value_label.text = fmt % v
		GameSettings.set_value(section, key, v))
	slider.value = GameSettings.get_value(section, key)
	value_label.text = fmt % slider.value

	_setting_controls[section + "/" + key] = slider
	return row

func _make_check_row(label_text: String, section: String, key: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	var check := CheckButton.new()
	check.text = label_text
	check.button_pressed = GameSettings.get_value(section, key)
	check.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	check.toggled.connect(func(on: bool): GameSettings.set_value(section, key, on))
	row.add_child(check)

	_setting_controls[section + "/" + key] = check
	return row

func _on_reset_pressed() -> void:
	GameSettings.reset_to_defaults()
	for id in _setting_controls:
		var parts: PackedStringArray = id.split("/")
		var control: Control = _setting_controls[id]
		var value: Variant = GameSettings.get_value(parts[0], parts[1])
		if control is HSlider:
			control.set_value_no_signal(value)
			control.value_changed.emit(value)
		elif control is CheckButton:
			control.set_pressed_no_signal(value)
