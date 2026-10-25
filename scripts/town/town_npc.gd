class_name TownNPC
extends Node3D

## NPC da vila com corpo procedural (CharacterDNA, B09) e animação do rig UAL, no lugar dos
## modelos prontos que ficavam em T-pose. Assenta no relevo, olha para quem chega perto e,
## se tiver `prompt`, entra no grupo "talkable" e emite `talked` no [E].

signal talked(player: Node)

@export var dna: CharacterDNA
@export var display_name: String = ""
## Texto do [E]; vazio = NPC só de cena (trabalhador), sem conversa
@export var prompt: String = ""
@export var idle_anim: StringName = &"Idle"
## Fala curta mostrada no HUD do player quando ninguém trata o `talked`
@export_multiline var line: String = ""
## Ferramenta na mão (machado nos trabalhadores); null = mãos livres
@export var tool_scene: PackedScene = null
@export var look_at_player: bool = true

var visual: CharacterVisual
var _prompt_label: Label3D

func _ready() -> void:
	visual = CharacterVisual.new()
	visual.weapon_scene = tool_scene
	visual.dna = dna if dna else CharacterDNA.randomized(hash(name))
	add_child(visual)
	visual.play(idle_anim)

	if not display_name.is_empty():
		var name_label := _label(display_name, 14, Color(1.0, 0.92, 0.7))
		name_label.position.y = 2.2
		name_label.visibility_range_end = 9.0
		add_child(name_label)
	if not prompt.is_empty():
		add_to_group("talkable")
		_prompt_label = _label(prompt, 13, Color(1, 0.9, 0.55))
		_prompt_label.position.y = 2.0
		_prompt_label.visible = false
		add_child(_prompt_label)
	_snap_to_ground.call_deferred()

func _process(_delta: float) -> void:
	if not is_inside_tree():
		return
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return
	var dist := player.global_position.distance_to(global_position)
	if _prompt_label:
		_prompt_label.visible = dist < Player.TALK_RANGE
	if look_at_player and dist < 6.0:
		var to_player: Vector3 = player.global_position - global_position
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-to_player.x, -to_player.z) - rotation.y, 0.1)

## Chamado pelo player ao apertar [E] perto do NPC.
func talk_to(player: Node) -> void:
	if talked.get_connections().is_empty():
		if not line.is_empty() and player and player.has_signal("posture_changed"):
			player.posture_changed.emit("%s: '%s'" % [display_name, line])
	talked.emit(player)

func _snap_to_ground() -> void:
	var scene := get_tree().current_scene if is_inside_tree() else null
	var landscape := scene.get_node_or_null("Landscape") if scene else null
	if landscape and landscape.has_method("get_height_at"):
		global_position.y = landscape.get_height_at(global_position.x, global_position.z)

func _label(text: String, size: int, color: Color) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.font_size = size
	l.outline_size = 5
	l.outline_modulate = Color(0, 0, 0, 0.8)
	l.modulate = color
	return l
