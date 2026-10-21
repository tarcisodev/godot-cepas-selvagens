class_name WeaponTrainer
extends Node3D

## Mestre de Armas do acampamento (B10): [E] abre o menu e troca o estilo de batalha
## na hora, de graça. É só para teste; a regra real (inventário, forja, Carga) vem depois.
## Conversar também cura e repõe os recursos, para voltar logo para os monstros.

@export var styles: Array[WeaponStyle] = []

@onready var visual: CharacterVisual = $CharacterVisual
@onready var prompt_label: Label3D = $PromptLabel

var _player: Player
var _layer: CanvasLayer
var _panel: PanelContainer
var _list: VBoxContainer
var _info: Label
var is_open: bool = false

func _ready() -> void:
	add_to_group("talkable")
	if visual:
		visual.play(&"Idle_FoldArms")
	prompt_label.visible = false
	_snap_to_ground.call_deferred()
	_build_menu()

func _snap_to_ground() -> void:
	var landscape := get_tree().current_scene.get_node_or_null("Landscape") if get_tree().current_scene else null
	if landscape and landscape.has_method("get_height_at"):
		global_position.y = landscape.get_height_at(global_position.x, global_position.z)

func _process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	prompt_label.visible = not is_open and player != null and player.global_position.distance_to(global_position) < Player.TALK_RANGE
	# Olha para quem chega perto
	if player and player.global_position.distance_to(global_position) < 6.0:
		var to_player: Vector3 = player.global_position - global_position
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-to_player.x, -to_player.z), 0.1)

## Chamado pelo player ao apertar [E] perto do NPC.
func talk_to(player: Player) -> void:
	_player = player
	if player.pools:
		player.pools.reset_all()
	open_menu()

func open_menu() -> void:
	is_open = true
	_refresh()
	_layer.visible = true
	add_to_group("open_menus")
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if visual:
		visual.play(&"Idle_Talking")

func close_menu() -> void:
	is_open = false
	_layer.visible = false
	remove_from_group("open_menus")
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if visual:
		visual.play(&"Idle_FoldArms")

func _unhandled_input(event: InputEvent) -> void:
	if is_open and event.is_action_pressed("ui_cancel"):
		close_menu()
		get_viewport().set_input_as_handled()

func choose(style: WeaponStyle) -> void:
	if _player:
		_player.equip_style(style)
	close_menu()

func _build_menu() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 5
	_layer.visible = false
	add_child(_layer)

	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_panel.custom_minimum_size = Vector2(460, 0)
	_layer.add_child(_panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	_panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)

	var title := Label.new()
	title.text = "⚔ Mestre de Armas"
	title.add_theme_font_size_override("font_size", 22)
	box.add_child(title)

	var hint := Label.new()
	hint.text = "Escolha um estilo de batalha. Clique esquerdo e direito mudam com a arma."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.modulate = Color(0.8, 0.8, 0.8)
	box.add_child(hint)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	box.add_child(_list)

	_info = Label.new()
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.custom_minimum_size = Vector2(0, 60)
	box.add_child(_info)

	var close := Button.new()
	close.text = "Fechar [Esc]"
	close.pressed.connect(close_menu)
	box.add_child(close)

func _refresh() -> void:
	for child in _list.get_children():
		child.free()
	var current: WeaponStyle = _player.weapon_style if _player else null
	for style in styles:
		var b := Button.new()
		var equipped: bool = style == current
		b.text = "%s%s" % [style.display_name, "  (equipado)" if equipped else ""]
		b.tooltip_text = style.description
		b.disabled = equipped
		b.pressed.connect(choose.bind(style))
		b.mouse_entered.connect(_show_info.bind(style))
		_list.add_child(b)
	_show_info(current if current else (styles[0] if not styles.is_empty() else null))

func _show_info(style: WeaponStyle) -> void:
	if style == null:
		_info.text = ""
		return
	_info.text = "%s\nEsq.: %s · Dir.: %s · Peso %.0f" % [
		style.description, style.primary.display_name, style.secondary.display_name, style.weight]
