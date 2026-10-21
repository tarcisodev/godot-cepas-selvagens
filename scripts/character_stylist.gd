class_name CharacterStylist
extends Node3D

## Barbeiro do acampamento (B09): [E] abre o editor de aparência do jogador.
## Edita uma cópia do CharacterDNA com prévia 3D ao vivo; "Aplicar" remonta o Player e salva o jogo.
## Gênero escolhe o conjunto de traços do corpo; cabelo e barba ficam livres para qualquer um.

const HAIR_STYLES: Array[String] = ["Careca", "Raspado", "Curto", "Rabo de cavalo", "Longo", "Moicano", "Coque", "Juba"]
const BEARDS: Array[String] = ["Sem barba", "Bigode", "Cavanhaque", "Cheia"]
const FEMININITY_MALE := 0.1
const FEMININITY_FEMALE := 0.88
## Espera entre um ajuste e a remontagem da prévia (arrastar slider não remonta a cada pixel).
const REBUILD_DELAY := 0.08

## Salva o jogo ao aplicar (os testes desligam para não tocar no save do jogador).
@export var save_on_apply: bool = true

@onready var visual: CharacterVisual = $CharacterVisual
@onready var prompt_label: Label3D = $PromptLabel

var is_open: bool = false
var _player: Player
var _draft: CharacterDNA
var _layer: CanvasLayer
var _preview: CharacterVisual
var _preview_camera: Camera3D
var _close_up := false
var _rebuild_in := -1.0
## prop -> controle, para sincronizar depois de "Sortear" ou da troca de gênero.
var _controls := {}
var _male_button: Button
var _female_button: Button

func _ready() -> void:
	add_to_group("talkable")
	if visual:
		visual.play(&"Idle_FoldArms")
	prompt_label.visible = false
	_snap_to_ground.call_deferred()
	_build_editor()

func _snap_to_ground() -> void:
	var landscape := get_tree().current_scene.get_node_or_null("Landscape") if get_tree().current_scene else null
	if landscape and landscape.has_method("get_height_at"):
		global_position.y = landscape.get_height_at(global_position.x, global_position.z)

func _process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	prompt_label.visible = not is_open and player != null and player.global_position.distance_to(global_position) < Player.TALK_RANGE
	if player and player.global_position.distance_to(global_position) < 6.0:
		var to_player: Vector3 = player.global_position - global_position
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-to_player.x, -to_player.z), 0.1)
	if _rebuild_in >= 0.0:
		_rebuild_in -= delta
		if _rebuild_in < 0.0:
			_preview.rebuild(_draft)

## Chamado pelo player ao apertar [E] perto do NPC.
func talk_to(player: Player) -> void:
	_player = player
	open_editor()

func open_editor() -> void:
	var current: CharacterDNA = _player.character_visual.dna if _player and _player.character_visual else null
	_draft = current.duplicate() if current else CharacterDNA.randomized(randi())
	_sync_controls()
	_preview.rebuild(_draft)
	is_open = true
	_layer.visible = true
	add_to_group("open_menus")
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if visual:
		visual.play(&"Idle_Talking")

func close_editor() -> void:
	is_open = false
	_layer.visible = false
	_rebuild_in = -1.0
	remove_from_group("open_menus")
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if visual:
		visual.play(&"Idle_FoldArms")

func apply() -> void:
	if _player and _player.character_visual:
		_player.character_visual.rebuild(_draft.duplicate())
		var save_game := get_node_or_null("/root/SaveGame")
		if save_on_apply and save_game:
			save_game.save_game()
	close_editor()

func randomize_draft() -> void:
	# Mantém o gênero escolhido; o resto é sorteado.
	var female := _draft.femininity >= 0.5
	_draft = CharacterDNA.randomized(randi())
	_draft.femininity = FEMININITY_FEMALE if female else FEMININITY_MALE
	_sync_controls()
	_queue_rebuild()

func set_gender(female: bool) -> void:
	_draft.femininity = FEMININITY_FEMALE if female else FEMININITY_MALE
	_sync_controls()
	_queue_rebuild()

func _unhandled_input(event: InputEvent) -> void:
	if is_open and event.is_action_pressed("ui_cancel"):
		close_editor()
		get_viewport().set_input_as_handled()

func _set_prop(value: Variant, prop: String) -> void:
	_draft.set(prop, value)
	if prop == "femininity":
		_sync_gender_buttons()
	_queue_rebuild()

func _queue_rebuild() -> void:
	_rebuild_in = REBUILD_DELAY

# --- Interface -------------------------------------------------------------------------------

func _build_editor() -> void:
	_layer = CanvasLayer.new()
	# Acima do HUD (objetivos), que cobriria a prévia.
	_layer.layer = 20
	_layer.visible = false
	add_child(_layer)

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(dim)

	var root := HBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		root.set("offset_" + side, 24.0 if side in ["left", "top"] else -24.0)
	root.add_theme_constant_override("separation", 16)
	_layer.add_child(root)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(440, 0)
	root.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)

	var title := Label.new()
	title.text = "✂ Barbeiro"
	title.add_theme_font_size_override("font_size", 22)
	box.add_child(title)

	var gender_row := HBoxContainer.new()
	var gender_label := Label.new()
	gender_label.text = "Gênero"
	gender_label.custom_minimum_size = Vector2(120, 0)
	gender_row.add_child(gender_label)
	var group := ButtonGroup.new()
	_male_button = _gender_button("Masculino", group, false)
	_female_button = _gender_button("Feminino", group, true)
	gender_row.add_child(_male_button)
	gender_row.add_child(_female_button)
	box.add_child(gender_row)

	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(tabs)

	var body := _tab(tabs, "Corpo")
	_slider(body, "Traços", "femininity", 0.0, 1.0)
	_slider(body, "Altura", "stature", 0.85, 1.12)
	_slider(body, "Massa", "mass", 0.0, 1.0)
	_slider(body, "Músculo", "muscle", 0.0, 1.0)
	_slider(body, "Pernas", "leg_length", 0.88, 1.12)
	_slider(body, "Tronco", "torso_length", 0.88, 1.12)
	_slider(body, "Braços", "arm_length", 0.9, 1.1)
	_slider(body, "Pescoço", "neck_length", 0.8, 1.25)

	var face := _tab(tabs, "Rosto")
	_swatches(face, "Pele", "skin_color", CharacterDNA.SKIN_TONES)
	_swatches(face, "Olhos", "eye_color", CharacterDNA.EYE_COLORS)
	_slider(face, "Cabeça", "head_size", 0.88, 1.15)
	_slider(face, "Mandíbula", "jaw_width", 0.0, 1.0)
	_slider(face, "Nariz", "nose_size", 0.0, 1.0)

	var hair := _tab(tabs, "Cabelo e barba")
	_choice(hair, "Cabelo", "hair_style", HAIR_STYLES)
	_slider(hair, "Comprimento", "hair_length", 0.0, 1.0)
	_swatches(hair, "Cor", "hair_color", CharacterDNA.HAIR_COLORS)
	_choice(hair, "Barba", "beard", BEARDS)
	_slider(hair, "Comp. da barba", "beard_length", 0.0, 1.0)

	var clothes := _tab(tabs, "Roupa")
	_swatches(clothes, "Camisa", "shirt_color", CharacterDNA.CLOTH_COLORS)
	_slider(clothes, "Manga", "sleeve_length", 0.0, 1.0)
	_swatches(clothes, "Calça", "pants_color", CharacterDNA.CLOTH_COLORS)
	_slider(clothes, "Comp. da calça", "pants_length", 0.0, 1.0)
	_swatches(clothes, "Bota", "boots_color", CharacterDNA.LEATHER_COLORS)
	_slider(clothes, "Cano da bota", "boot_height", 0.0, 1.0)
	_swatches(clothes, "Cinto", "belt_color", CharacterDNA.LEATHER_COLORS)
	_toggle(clothes, "Luvas", "gloves")

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	box.add_child(buttons)
	for entry in [["Sortear", randomize_draft], ["Cancelar [Esc]", close_editor], ["Aplicar", apply]]:
		var b := Button.new()
		b.text = entry[0]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(entry[1])
		buttons.add_child(b)

	root.add_child(_build_preview())

func _gender_button(text: String, group: ButtonGroup, female: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.button_group = group
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(set_gender.bind(female))
	return b

## Prévia num mundo 3D próprio; arrastar com o mouse gira o personagem.
func _build_preview() -> Control:
	var container := SubViewportContainer.new()
	container.stretch = true
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.gui_input.connect(_on_preview_input)

	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	container.add_child(viewport)

	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#2b2a26")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#8c8f99")
	environment.ambient_light_energy = 0.6
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.environment = environment
	viewport.add_child(world)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35.0, 25.0, 0.0)
	key.light_energy = 1.3
	viewport.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-20.0, 200.0, 0.0)
	rim.light_energy = 0.5
	viewport.add_child(rim)

	var stand := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.7
	disc.bottom_radius = 0.7
	disc.height = 0.04
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color("#4a4438")
	disc.material = floor_material
	stand.mesh = disc
	stand.position.y = -0.02
	viewport.add_child(stand)

	_preview = CharacterVisual.new()
	_preview.weapon_scene = null
	_preview.dna = CharacterDNA.new()
	# O CharacterVisual olha para -Z; a câmera da prévia está em +Z.
	_preview.rotation.y = PI
	viewport.add_child(_preview)

	_preview_camera = Camera3D.new()
	_preview_camera.fov = 35.0
	viewport.add_child(_preview_camera)
	_frame_camera()

	var zoom := Button.new()
	zoom.text = "Zoom no rosto"
	zoom.toggle_mode = true
	zoom.position = Vector2(12, 12)
	zoom.toggled.connect(func(on: bool) -> void:
		_close_up = on
		_frame_camera())
	container.add_child(zoom)
	var hint := Label.new()
	hint.text = "Arraste para girar"
	hint.modulate = Color(1, 1, 1, 0.6)
	hint.position = Vector2(14, 48)
	container.add_child(hint)
	return container

func _frame_camera() -> void:
	# Sem look_at: a câmera é posicionada antes de a prévia entrar na árvore.
	if _close_up:
		_preview_camera.transform = Transform3D(Basis(), Vector3(0.0, 1.62, 1.05)).looking_at(Vector3(0.0, 1.56, 0.0))
	else:
		_preview_camera.transform = Transform3D(Basis(), Vector3(0.0, 1.15, 4.0)).looking_at(Vector3(0.0, 0.95, 0.0))

func _on_preview_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion and motion.button_mask & MOUSE_BUTTON_MASK_LEFT:
		_preview.rotation.y += motion.relative.x * 0.01

func _tab(tabs: TabContainer, title: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 6)
	scroll.add_child(box)
	return box

func _row(parent: Control, text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(120, 0)
	row.add_child(label)
	parent.add_child(row)
	return row

func _slider(parent: Control, text: String, prop: String, lo: float, hi: float) -> void:
	var slider := HSlider.new()
	slider.min_value = lo
	slider.max_value = hi
	slider.step = 0.01
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.value_changed.connect(_set_prop.bind(prop))
	_row(parent, text).add_child(slider)
	_controls[prop] = slider

func _choice(parent: Control, text: String, prop: String, options: Array[String]) -> void:
	var option := OptionButton.new()
	for o in options:
		option.add_item(o)
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	option.item_selected.connect(_set_prop.bind(prop))
	_row(parent, text).add_child(option)
	_controls[prop] = option

func _toggle(parent: Control, text: String, prop: String) -> void:
	var check := CheckBox.new()
	check.toggled.connect(_set_prop.bind(prop))
	_row(parent, text).add_child(check)
	_controls[prop] = check

## Amostras da paleta mais um seletor livre.
func _swatches(parent: Control, text: String, prop: String, palette: Array[Color]) -> void:
	var row := _row(parent, text)
	var flow := HFlowContainer.new()
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(flow)
	var picker := ColorPickerButton.new()
	picker.custom_minimum_size = Vector2(30, 22)
	picker.edit_alpha = false
	picker.color_changed.connect(_set_prop.bind(prop))
	for color in palette:
		var swatch := Button.new()
		swatch.custom_minimum_size = Vector2(22, 22)
		swatch.tooltip_text = "#" + color.to_html(false)
		for state in ["normal", "hover", "pressed", "focus"]:
			var style := StyleBoxFlat.new()
			style.bg_color = color
			style.set_corner_radius_all(4)
			if state != "normal":
				style.set_border_width_all(2)
				style.border_color = Color.WHITE
			swatch.add_theme_stylebox_override(state, style)
		swatch.pressed.connect(func() -> void:
			picker.color = color
			_set_prop(color, prop))
		flow.add_child(swatch)
	flow.add_child(picker)
	_controls[prop] = picker

func _sync_controls() -> void:
	if _draft == null:
		return
	for prop in _controls:
		var control: Control = _controls[prop]
		var value: Variant = _draft.get(prop)
		if control is Range:
			(control as Range).set_value_no_signal(value)
		elif control is OptionButton:
			(control as OptionButton).select(value)
		elif control is CheckBox:
			(control as CheckBox).set_pressed_no_signal(value)
		elif control is ColorPickerButton:
			(control as ColorPickerButton).color = value
	_sync_gender_buttons()

func _sync_gender_buttons() -> void:
	var female := _draft.femininity >= 0.5
	_male_button.set_pressed_no_signal(not female)
	_female_button.set_pressed_no_signal(female)
