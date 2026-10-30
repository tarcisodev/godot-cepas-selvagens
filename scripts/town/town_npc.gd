class_name TownNPC
extends Node3D

## NPC da vila com corpo procedural (CharacterDNA, B09) e animação do rig UAL, no lugar dos
## modelos prontos que ficavam em T-pose. Assenta no relevo, olha para quem chega perto e,
## se tiver `prompt`, entra no grupo "talkable" e emite `talked` no [E]. Com `profile` (GDD-17),
## o [E] abre a Ficha do NPC (retrato 3D, papel e ações) em vez da fala solta.

const _WorldLabel = preload("res://scripts/ui/world_label.gd")
const _NpcProfile = preload("res://scripts/npc/npc_profile.gd")
const _NpcDialog = preload("res://scripts/ui/npc_dialog.gd")

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
## Ícone que fica no lugar do nome de 6 a 15 m (WorldLabel)
@export var icon: String = "💬"
## false = fica na altura dada (pescador no píer); true = assenta no relevo
@export var snap_to_ground: bool = true
## Ficha do NPC (GDD-17 §8); null = comportamento antigo (fala solta ou `talked`).
## Pode chegar depois do _ready (o `_npc` da vila já adicionou o nó): os rótulos se refazem.
var profile: _NpcProfile:
	set(value):
		profile = value
		if is_node_ready():
			_build_labels()

var visual: CharacterVisual
var _name_label: _WorldLabel
var _prompt_label: _WorldLabel

func _ready() -> void:
	visual = CharacterVisual.new()
	visual.weapon_scene = tool_scene
	visual.dna = dna if dna else CharacterDNA.randomized(hash(name))
	add_child(visual)
	visual.play(idle_anim)
	_build_labels()
	if snap_to_ground:
		_snap_to_ground.call_deferred()

## Nome (com o papel, se houver Ficha) e o prompt do [E]
func _build_labels() -> void:
	for l in [_name_label, _prompt_label]:
		if l:
			l.queue_free()
	_name_label = null
	_prompt_label = null
	var shown_name := display_name
	var shown_prompt := prompt
	if profile:
		if shown_name.is_empty():
			shown_name = profile.display_name
		if not profile.title.is_empty() and not shown_name.contains(profile.title):
			shown_name = "%s · %s" % [shown_name, profile.title]
		if shown_prompt.is_empty():
			shown_prompt = "[E] Falar"
		if profile.greetings.is_empty() and not line.is_empty():
			profile.greet("sempre", line)
	if not shown_name.is_empty():
		_name_label = _WorldLabel.make(_WorldLabel.Kind.NAME, shown_name, icon)
		_name_label.position.y = 2.25
		add_child(_name_label)
	if not shown_prompt.is_empty():
		add_to_group("talkable")
		_prompt_label = _WorldLabel.make(_WorldLabel.Kind.PROMPT, shown_prompt)
		_prompt_label.position.y = 2.0
		add_child(_prompt_label)

func _process(_delta: float) -> void:
	if not is_inside_tree():
		return
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return
	var dist := player.global_position.distance_to(global_position)
	if look_at_player and dist < 6.0:
		var to_player: Vector3 = player.global_position - global_position
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-to_player.x, -to_player.z) - rotation.y, 0.1)

## Chamado pelo player ao apertar [E] perto do NPC.
func talk_to(player: Node) -> void:
	if profile:
		_NpcDialog.open_for(self, player)
		talked.emit(player)
		return
	if talked.get_connections().is_empty():
		if not line.is_empty() and player and player.has_signal("posture_changed"):
			player.posture_changed.emit("%s: '%s'" % [display_name, line])
	talked.emit(player)

func _snap_to_ground() -> void:
	var scene := get_tree().current_scene if is_inside_tree() else null
	var landscape := scene.get_node_or_null("Landscape") if scene else null
	if landscape and landscape.has_method("get_height_at"):
		global_position.y = landscape.get_height_at(global_position.x, global_position.z)
