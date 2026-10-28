class_name WeaponTrainer
extends Node3D

const _WorldLabel = preload("res://scripts/ui/world_label.gd")

## Mestre de Armas do acampamento (B10, GDD-12 §7): [E] abre o menu e dá, de graça, as armas
## de treino (Q1) do estilo escolhido, já equipadas. As armas de verdade saem da bigorna.
## Conversar também cura e repõe os recursos, para voltar logo para os monstros.

@export var styles: Array[WeaponStyle] = []

@onready var visual: CharacterVisual = $CharacterVisual
var prompt_label: _WorldLabel

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
	_WorldLabel.replace($NameLabel, _WorldLabel.Kind.NAME, "⚔️")
	prompt_label = _WorldLabel.replace($PromptLabel, _WorldLabel.Kind.PROMPT)
	_snap_to_ground.call_deferred()
	_build_menu()

func _snap_to_ground() -> void:
	var landscape := get_tree().current_scene.get_node_or_null("Landscape") if get_tree().current_scene else null
	if landscape and landscape.has_method("get_height_at"):
		global_position.y = landscape.get_height_at(global_position.x, global_position.z)

func _process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	prompt_label.active = not is_open
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

## Armas de treino de cada estilo (GDD-12 §7): o mestre dá as que faltam e já equipa
const TRAINING_BY_STYLE: Dictionary = {
	&"sword_shield": [&"espada_ferro", &"escudo"],
	&"sword": [&"espada_ferro"],
	&"heavy_hammer": [&"mangual"],
	&"arcane_staff": [&"cajado_arcano"],
	&"hunting_horn": [&"berrante_caca"],
}

func choose(style: WeaponStyle) -> void:
	if _player:
		var recipes: Array = TRAINING_BY_STYLE.get(style.id, [])
		if recipes.is_empty() or _player.inventory == null:
			_player.equip_style(style)
		else:
			for id in recipes:
				_player.inventory.equip(_training_item(id))
			if style.id == &"sword":
				_player.inventory.unequip(ForgedItem.Slot.OFF_HAND)
	close_menu()

## A peça de treino da receita que o jogador já tem, ou uma nova
func _training_item(recipe_id: StringName) -> ForgedItem:
	for it in _player.inventory.items:
		if it.recipe_id == recipe_id and it.traits.has(&"treino"):
			if it.is_broken():
				it.durability = it.max_durability # o mestre troca a peça de treino gasta
			return it
	var item := Forge.make_training(recipe_id)
	# Sem o sinal de forja: peça de treino não conta como item forjado
	_player.inventory.items.append(item)
	_player.inventory.items_changed.emit()
	return item

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
