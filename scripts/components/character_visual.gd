extends Node3D
class_name CharacterVisual

## Visual do personagem: modelo rigado (Quaternius) + bibliotecas de animação UAL1/UAL2.
# O modelo e as animações compartilham o mesmo esqueleto (65 ossos, "Armature/Skeleton3D"),
# então as bibliotecas tocam direto em qualquer personagem do kit.
# Trocar o visual = trocar `model_scene` (Male_Ranger, Female_Ranger, Male_Peasant…).

@export var model_scene: PackedScene = preload("res://assets/models/character/Male_Ranger.gltf")
## Bibliotecas de animação; ao tocar um nome, vale a primeira que o tiver.
@export var animation_sources: Array[PackedScene] = [
	preload("res://assets/models/character/animations/UAL1_Standard.glb"),
	preload("res://assets/models/character/animations/UAL2_Standard.glb"),
]
@export var weapon_scene: PackedScene = preload("res://assets/models/tools/axe.gltf")
@export var weapon_bone: StringName = &"hand_r"
## Encaixe da arma no osso da mão: cabo (eixo Y do modelo) passando pelo punho, cabeça para cima.
@export var weapon_transform: Transform3D = Transform3D(Basis(Vector3.RIGHT, PI).scaled(Vector3.ONE * 0.7), Vector3(0.0, 0.05, 0.0))
@export var blend_time: float = 0.18

var model: Node3D
var skeleton: Skeleton3D
var anim_player: AnimationPlayer
var weapon: Node3D
var _current: StringName = &""

func _ready() -> void:
	_build()

func _build() -> void:
	if model_scene == null:
		return
	model = model_scene.instantiate() as Node3D
	model.name = "Model"
	# Os modelos do kit olham para +Z; no Godot o "frente" do player é -Z.
	model.rotation.y = PI
	add_child(model)
	skeleton = _find_skeleton(model)

	anim_player = AnimationPlayer.new()
	anim_player.name = "AnimationPlayer"
	model.add_child(anim_player)
	anim_player.root_node = NodePath("..")
	_load_animations()
	_attach_weapon()
	play(&"Idle")

func _load_animations() -> void:
	for i in animation_sources.size():
		if animation_sources[i] == null:
			continue
		var source := animation_sources[i].instantiate()
		var source_player := source.find_child("AnimationPlayer", true, false) as AnimationPlayer
		# O importador do Godot tira o sufixo "_Loop" do nome e já marca o loop
		# (ex.: "Walk_Loop" vira "Walk"), então a biblioteca entra como está.
		if source_player and source_player.has_animation_library(&""):
			anim_player.add_animation_library(StringName("ual%d" % (i + 1)), source_player.get_animation_library(&""))
		source.free()

## Nome completo ("ual2/Sword_Regular_A") da primeira biblioteca que tem a animação; vazio se nenhuma.
func _resolve(anim: StringName) -> StringName:
	if anim_player == null:
		return &""
	for library in anim_player.get_animation_library_list():
		var full := StringName("%s/%s" % [library, anim])
		if anim_player.has_animation(full):
			return full
	return &""

func has(anim: StringName) -> bool:
	return _resolve(anim) != &""

func _attach_weapon() -> void:
	if skeleton == null or weapon_scene == null:
		return
	var attachment := BoneAttachment3D.new()
	attachment.name = "WeaponSocket"
	attachment.bone_name = weapon_bone
	skeleton.add_child(attachment)
	weapon = weapon_scene.instantiate() as Node3D
	weapon.transform = weapon_transform
	attachment.add_child(weapon)

## Toca uma animação pelo nome (ex.: &"Walk"); ignora se já está tocando.
func play(anim: StringName, speed: float = 1.0, restart: bool = false) -> void:
	var full := _resolve(anim)
	if full == &"":
		return
	anim_player.speed_scale = speed
	if _current == anim and not restart:
		return
	_current = anim
	anim_player.play(full, blend_time)
	if restart:
		anim_player.seek(0.0, true)

## Toca a animação inteira dentro de `duration` segundos (para golpes, esquiva e cast).
func play_timed(anim: StringName, duration: float, restart: bool = false) -> void:
	var full := _resolve(anim)
	if full == &"" or duration <= 0.0:
		return
	play(anim, anim_player.get_animation(full).length / duration, restart)

func current() -> StringName:
	return _current

## true enquanto a animação atual não terminou (animações em loop nunca terminam).
func is_playing() -> bool:
	return anim_player != null and anim_player.is_playing()

## Prende um nó a um osso do esqueleto, mantendo a posição global atual dele.
func attach_to_bone(node: Node3D, bone: StringName) -> void:
	if skeleton == null or skeleton.find_bone(bone) < 0:
		return
	var socket := BoneAttachment3D.new()
	socket.name = "%sSocket" % node.name
	socket.bone_name = bone
	skeleton.add_child(socket)
	node.reparent(socket, true)

func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found:
			return found
	return null
