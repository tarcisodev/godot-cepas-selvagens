class_name CharacterStylist
extends Node3D

const _WorldLabel = preload("res://scripts/ui/world_label.gd")

## Barbeiro do acampamento (B09): [E] abre o editor de aparência do jogador.
## "Aplicar" remonta o Player com o DNA editado e salva o jogo.

## Salva o jogo ao aplicar (os testes desligam para não tocar no save do jogador).
@export var save_on_apply: bool = true

@onready var visual: CharacterVisual = $CharacterVisual
var prompt_label: _WorldLabel

var is_open: bool = false
var editor: AppearanceEditor
var _player: Player
var _layer: CanvasLayer

func _ready() -> void:
	add_to_group("talkable")
	if visual:
		visual.play(&"Idle_FoldArms")
	_WorldLabel.replace($NameLabel, _WorldLabel.Kind.NAME, "✂️")
	prompt_label = _WorldLabel.replace($PromptLabel, _WorldLabel.Kind.PROMPT)
	_snap_to_ground.call_deferred()
	_build_layer()

func _snap_to_ground() -> void:
	var landscape := get_tree().current_scene.get_node_or_null("Landscape") if get_tree().current_scene else null
	if landscape and landscape.has_method("get_height_at"):
		global_position.y = landscape.get_height_at(global_position.x, global_position.z)

func _process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	prompt_label.active = not is_open
	if player and player.global_position.distance_to(global_position) < 6.0:
		var to_player: Vector3 = player.global_position - global_position
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-to_player.x, -to_player.z), 0.1)

## Chamado pelo player ao apertar [E] perto do NPC.
func talk_to(player: Player) -> void:
	_player = player
	open_editor()

func open_editor() -> void:
	editor.edit(_player.character_visual.dna if _player and _player.character_visual else null)
	is_open = true
	_layer.visible = true
	add_to_group("open_menus")
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if visual:
		visual.play(&"Idle_Talking")

func close_editor() -> void:
	is_open = false
	_layer.visible = false
	remove_from_group("open_menus")
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if visual:
		visual.play(&"Idle_FoldArms")

func _on_confirmed(dna: CharacterDNA) -> void:
	if _player and _player.character_visual:
		_player.character_visual.rebuild(dna)
		var save_game := get_node_or_null("/root/SaveGame")
		if save_on_apply and save_game:
			save_game.save_game()
	close_editor()

func _unhandled_input(event: InputEvent) -> void:
	if is_open and event.is_action_pressed("ui_cancel"):
		close_editor()
		get_viewport().set_input_as_handled()

func _build_layer() -> void:
	_layer = CanvasLayer.new()
	# Acima do HUD (objetivos), que cobriria a prévia.
	_layer.layer = 20
	_layer.visible = false
	add_child(_layer)

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(dim)

	editor = AppearanceEditor.new()
	editor.title_text = "✂ Barbeiro"
	editor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 24)
	editor.confirmed.connect(_on_confirmed)
	editor.cancelled.connect(close_editor)
	_layer.add_child(editor)
