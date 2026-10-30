class_name NpcDialog
extends Control

## Ficha do NPC (GDD-17 §8): [E] num NPC com `profile` abre o NPC em 3D à esquerda e, à
## direita, nome, papel, bairro, horário, a fala da hora e a lista de ações (atalhos 1–9).
## Ação com `panel` desenha dentro da Ficha (o retrato fica e reage); com `handler` a Ficha
## fecha e abre a outra tela. Não pausa nada: o mundo segue e a Ficha fecha se o jogador
## se afastar. Padrão das telas: CanvasLayer 12 + grupo "open_menus".

const _NpcProfile = preload("res://scripts/npc/npc_profile.gd")
const _NpcAction = preload("res://scripts/npc/npc_action.gd")
const _Player = preload("res://scripts/player.gd")

const ZOOM_MIN: float = 0.9
const ZOOM_MAX: float = 3.2
## Folga além do alcance do [E] antes de a Ficha fechar sozinha
const WALK_AWAY_MARGIN: float = 1.0

static var instance: NpcDialog

var npc: Node3D
var player: Node
var profile: _NpcProfile
var portrait: CharacterVisual
## Ação aberta dentro da Ficha; null = lista de ações
var current_action: _NpcAction

var _panel_style: StyleBoxFlat
var _viewport: SubViewport
var _environment: Environment
var _camera: Camera3D
var _zoom: float = 1.6
var _name_label: Label
var _title_label: Label
var _status_label: Label
var _speech_label: Label
var _content: VBoxContainer
var _gesture_left: float = 0.0
var _buttons: Array[Button] = []

## Abre a Ficha de `p_npc` (precisa de `profile`). Cria a tela na primeira vez.
static func open_for(p_npc: Node3D, p_player: Node) -> NpcDialog:
	if not is_instance_valid(instance):
		var tree := p_npc.get_tree()
		var host: Node = tree.current_scene if tree.current_scene else tree.root
		var layer := CanvasLayer.new()
		layer.name = "NpcDialogLayer"
		layer.layer = 12
		host.add_child(layer)
		instance = NpcDialog.new()
		instance.name = "NpcDialog"
		layer.add_child(instance)
	instance.open(p_npc, p_player)
	return instance

func _ready() -> void:
	visible = false
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	_build_ui()

func _exit_tree() -> void:
	if instance == self:
		instance = null

func is_open() -> bool:
	return visible

func open(p_npc: Node3D, p_player: Node) -> void:
	npc = p_npc
	player = p_player
	profile = p_npc.get("profile")
	if profile == null:
		return
	current_action = null
	visible = true
	add_to_group("open_menus")
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_setup_portrait()
	_name_label.text = "%s  %s" % [profile.icon, profile.display_name]
	_title_label.text = profile.title + ("  ·  " + profile.district if not profile.district.is_empty() else "")
	_panel_style.border_color = profile.color
	_environment.background_color = profile.color.darkened(0.78)
	say(profile.greeting_at(hour(), hash(str(profile.id)) + _day()))
	gesture(&"Interact")
	refresh()

func close() -> void:
	if not visible:
		return
	visible = false
	current_action = null
	remove_from_group("open_menus")
	if is_inside_tree() and get_tree().get_nodes_in_group("open_menus").is_empty():
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

## Hora do relógio único; sem sol (testes) é meio-dia
func hour() -> float:
	return DayNightCycle.instance.current_time_hours if is_instance_valid(DayNightCycle.instance) else 12.0

func _day() -> int:
	return DayNightCycle.instance.day_count if is_instance_valid(DayNightCycle.instance) else 0

## Fala do NPC no balão da Ficha
func say(text: String) -> void:
	_speech_label.text = "“%s”" % text if not text.is_empty() else ""
	_speech_label.visible = not text.is_empty()

## O retrato faz um gesto e volta para a animação de conversa
func gesture(anim: StringName, duration: float = 1.4) -> void:
	if portrait == null or not portrait.has(anim):
		return
	portrait.play_timed(anim, duration, true)
	_gesture_left = duration

## Redesenha status e conteúdo (lista de ações ou a ação aberta)
func refresh() -> void:
	if profile == null:
		return
	var open_now := profile.is_open_at(hour())
	_status_label.text = "🕗 %s  ·  %s" % [profile.hours_text(), "ABERTO" if open_now else "FECHADO"]
	_status_label.add_theme_color_override("font_color", Color(0.55, 0.9, 0.55) if open_now else Color(0.95, 0.5, 0.45))
	for c in _content.get_children():
		_content.remove_child(c)
		c.queue_free()
	_buttons.clear()
	if current_action == null:
		_build_action_list()
	else:
		_build_action_panel(current_action)

func actions() -> Array[_NpcAction]:
	return profile.all_actions() if profile else []

## Escolhe a ação pelo índice (0 = atalho [1]); devolve false se indisponível
func choose(index: int) -> bool:
	var list := actions()
	if index < 0 or index >= list.size():
		return false
	var action := list[index]
	var reason := profile.action_reason(action, player, hour())
	if not reason.is_empty():
		say(reason)
		return false
	gesture(action.gesture)
	if action.panel.is_valid() or action.kind == _NpcAction.Kind.TALK:
		current_action = action
		refresh()
	elif action.handler.is_valid():
		var p := player
		close()
		action.handler.call(p)
	return true

## Volta da ação aberta para a lista
func back() -> void:
	current_action = null
	refresh()

func _process(delta: float) -> void:
	if not visible:
		return
	if _gesture_left > 0.0:
		_gesture_left -= delta
		if _gesture_left <= 0.0 and portrait and profile:
			portrait.play(profile.talk_anim if portrait.has(profile.talk_anim) else &"Idle")
	if not is_instance_valid(npc) or not is_instance_valid(player):
		close()
		return
	if player is Node3D and _Player.talk_distance((player as Node3D).global_position, npc) > _Player.TALK_RANGE + WALK_AWAY_MARGIN:
		close()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"interact"):
		if current_action != null and event.is_action_pressed(&"ui_cancel"):
			back()
		else:
			close()
		get_viewport().set_input_as_handled()
		return
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and current_action == null:
		var n := key.keycode - KEY_1
		if n >= 0 and n < 9:
			choose(n)
			get_viewport().set_input_as_handled()

# ---------------------------------------------------------------- conteúdo

func _build_action_list() -> void:
	var list := actions()
	var h := hour()
	for i in list.size():
		var action := list[i]
		var reason := profile.action_reason(action, player, h)
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 0)
		var button := Button.new()
		button.text = "[%d]  %s  %s" % [i + 1, action.icon, action.label]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(0, 34)
		button.disabled = not reason.is_empty()
		button.pressed.connect(choose.bind(i))
		row.add_child(button)
		_buttons.append(button)
		if not reason.is_empty():
			var why := Label.new()
			why.text = "      " + reason
			why.add_theme_font_size_override("font_size", 11)
			why.add_theme_color_override("font_color", Color(0.7, 0.66, 0.6))
			why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			row.add_child(why)
		_content.add_child(row)
	var leave := Button.new()
	leave.text = "[Esc]  Sair"
	leave.alignment = HORIZONTAL_ALIGNMENT_LEFT
	leave.flat = true
	leave.pressed.connect(close)
	_content.add_child(leave)

func _build_action_panel(action: _NpcAction) -> void:
	var header := HBoxContainer.new()
	var back_btn := Button.new()
	back_btn.text = "← Voltar"
	back_btn.pressed.connect(back)
	header.add_child(back_btn)
	var title := Label.new()
	title.text = "  %s  %s" % [action.icon, action.label]
	title.add_theme_font_size_override("font_size", 15)
	header.add_child(title)
	_content.add_child(header)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	_content.add_child(box)
	if action.panel.is_valid():
		action.panel.call(box, player, self)
	elif action.kind == _NpcAction.Kind.TALK:
		_build_topics(box)

func _build_topics(box: VBoxContainer) -> void:
	for t in profile.topics:
		var b := Button.new()
		b.text = "💬  " + str(t["q"])
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(func():
			say(str(t["a"]))
			gesture(&"Idle_Talking", 2.0)
		)
		box.add_child(b)
		_buttons.append(b)

# ---------------------------------------------------------------- montagem

func _build_ui() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.35)
	backdrop.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	center.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(860, 520)
	_panel_style = StyleBoxFlat.new()
	_panel_style.bg_color = Color(0.10, 0.09, 0.11, 0.97)
	_panel_style.border_color = Color(0.85, 0.72, 0.35)
	_panel_style.set_border_width_all(2)
	_panel_style.set_corner_radius_all(10)
	_panel_style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", _panel_style)
	center.add_child(panel)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 18)
	panel.add_child(columns)
	columns.add_child(_build_portrait())

	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(480, 0)
	right.size_flags_horizontal = SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 8)
	columns.add_child(right)

	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 22)
	_name_label.add_theme_color_override("font_color", Color(0.98, 0.88, 0.55))
	right.add_child(_name_label)
	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 14)
	_title_label.add_theme_color_override("font_color", Color(0.82, 0.8, 0.76))
	right.add_child(_title_label)
	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 13)
	right.add_child(_status_label)
	right.add_child(HSeparator.new())
	_speech_label = Label.new()
	_speech_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_speech_label.add_theme_font_size_override("font_size", 15)
	_speech_label.add_theme_color_override("font_color", Color(0.95, 0.93, 0.88))
	_speech_label.custom_minimum_size = Vector2(0, 44)
	right.add_child(_speech_label)
	right.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 4)
	scroll.add_child(_content)

	var hint := Label.new()
	hint.text = "1–9: escolher  ·  Esc: voltar/sair  ·  arraste o retrato para girar"
	hint.modulate = Color(1, 1, 1, 0.5)
	hint.add_theme_font_size_override("font_size", 11)
	right.add_child(hint)

func _build_portrait() -> Control:
	var container := SubViewportContainer.new()
	container.stretch = true
	container.custom_minimum_size = Vector2(300, 480)
	container.gui_input.connect(_on_portrait_input)

	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	container.add_child(_viewport)

	_environment = Environment.new()
	_environment.background_mode = Environment.BG_COLOR
	_environment.background_color = Color("#1d1f24")
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.ambient_light_color = Color("#8c8f99")
	_environment.ambient_light_energy = 0.6
	_environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.environment = _environment
	_viewport.add_child(world)
	# Três pontos: chave quente, preenchimento frio e contra-luz no recorte
	for l in [[Vector3(-30.0, 30.0, 0.0), 1.3, Color(1.0, 0.92, 0.8)], [Vector3(-10.0, -40.0, 0.0), 0.45, Color(0.7, 0.8, 1.0)], [Vector3(-20.0, 200.0, 0.0), 0.8, Color(1.0, 0.85, 0.6)]]:
		var light := DirectionalLight3D.new()
		light.rotation_degrees = l[0]
		light.light_energy = l[1]
		light.light_color = l[2]
		_viewport.add_child(light)

	var stand := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.6
	disc.bottom_radius = 0.6
	disc.height = 0.04
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color("#3a3630")
	disc.material = floor_material
	stand.mesh = disc
	stand.position.y = -0.02
	_viewport.add_child(stand)

	_camera = Camera3D.new()
	_camera.fov = 35.0
	_viewport.add_child(_camera)
	_frame_camera()
	return container

## Cópia do corpo do NPC (mesmo DNA e ferramenta) no mundo próprio do retrato
func _setup_portrait() -> void:
	if portrait:
		portrait.queue_free()
		portrait = null
	var source: CharacterVisual = npc.get("visual")
	portrait = CharacterVisual.new()
	portrait.weapon_scene = source.weapon_scene if source else null
	portrait.dna = source.dna if source and source.dna else CharacterDNA.randomized(hash(npc.name))
	# O CharacterVisual olha para -Z; a câmera está em +Z
	portrait.rotation.y = PI - 0.35
	_viewport.add_child(portrait)
	portrait.play(profile.talk_anim if portrait.has(profile.talk_anim) else &"Idle")
	_zoom = 1.6
	_frame_camera()

func _frame_camera() -> void:
	# Perto mira o rosto; longe, o corpo inteiro
	var t := inverse_lerp(ZOOM_MAX, ZOOM_MIN, _zoom)
	var look_y := lerpf(0.95, 1.5, t)
	_camera.transform = Transform3D(Basis(), Vector3(0.0, look_y + 0.1, _zoom)).looking_at(Vector3(0.0, look_y, 0.0))

func _on_portrait_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion and motion.button_mask & MOUSE_BUTTON_MASK_LEFT and portrait:
		portrait.rotation.y += motion.relative.x * 0.01
	var button := event as InputEventMouseButton
	if button and button.pressed:
		if button.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom = clampf(_zoom - 0.25, ZOOM_MIN, ZOOM_MAX)
			_frame_camera()
		elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom = clampf(_zoom + 0.25, ZOOM_MIN, ZOOM_MAX)
			_frame_camera()
