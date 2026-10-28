class_name TownNursery
extends Node3D

## Berçário Comunitário e Casa da Parteira (GDD-14 §4.3 e §4.4).
## Acolhe os bebês recém-nascidos dos jogadores e cidadãos, cuidando
## do seu crescimento pelas 4 fases da vida (Bebê -> Jovem Aprendiz -> Adulto).

const _Player = preload("res://scripts/player.gd")
const _NurseryScreen = preload("res://scripts/ui/nursery_screen.gd")

const USE_RANGE: float = 4.0

var city: Node
var _screen: _NurseryScreen
var _prompt: Label3D
var registered_children: Array[Dictionary] = []
var _t: float = 0.0

func _ready() -> void:
	add_to_group("talkable")
	add_to_group("town_nursery")
	_build_visuals()

	var layer := CanvasLayer.new()
	layer.layer = 12
	add_child(layer)
	_screen = _NurseryScreen.new()
	layer.add_child(_screen)

	_prompt = Label3D.new()
	_prompt.text = "👶 [E] Berçário da Vila & Parteira"
	_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt.font_size = 14
	_prompt.outline_size = 4
	_prompt.modulate = Color(0.6, 0.9, 1.0)
	_prompt.position.y = 1.6
	_prompt.visible = false
	add_child(_prompt)

func _build_visuals() -> void:
	# Materiais aconchegantes
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.55, 0.38, 0.22)
	wood.roughness = 0.75

	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = Color(0.85, 0.88, 0.92)
	cloth.roughness = 0.8

	var blanket := StandardMaterial3D.new()
	blanket.albedo_color = Color(0.9, 0.6, 0.65)
	blanket.roughness = 0.9

	# Base e piso do berçário
	var floor_m := MeshInstance3D.new()
	var b_box := BoxMesh.new()
	b_box.size = Vector3(4.5, 0.3, 4.5)
	floor_m.mesh = b_box
	floor_m.material_override = wood
	floor_m.position.y = 0.15
	add_child(floor_m)

	# Berços de madeira
	var crib_positions := [Vector3(-1.4, 0.5, -1.2), Vector3(-1.4, 0.5, 0.0), Vector3(-1.4, 0.5, 1.2)]
	for cp in crib_positions:
		var crib := MeshInstance3D.new()
		var c_box := BoxMesh.new()
		c_box.size = Vector3(0.7, 0.6, 1.0)
		crib.mesh = c_box
		crib.material_override = wood
		crib.position = cp
		add_child(crib)

		# Colchãozinho e manta
		var mat := MeshInstance3D.new()
		var m_box := BoxMesh.new()
		m_box.size = Vector3(0.6, 0.15, 0.9)
		mat.mesh = m_box
		mat.material_override = blanket
		mat.position = cp + Vector3(0, 0.25, 0)
		add_child(mat)

	# Mesa da parteira Mestra Clara
	var desk := MeshInstance3D.new()
	var d_box := BoxMesh.new()
	d_box.size = Vector3(1.4, 0.8, 0.8)
	desk.mesh = d_box
	desk.material_override = wood
	desk.position = Vector3(1.2, 0.55, -1.0)
	add_child(desk)

	# Lanterna acolhedora
	var lantern := OmniLight3D.new()
	lantern.light_color = Color(1.0, 0.9, 0.7)
	lantern.light_energy = 1.1
	lantern.omni_range = 6.0
	lantern.position = Vector3(0, 2.2, 0)
	add_child(lantern)

	# Colisão estática
	var sb := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(4.6, 2.5, 4.6)
	col.shape = shape
	col.position.y = 1.25
	sb.add_child(col)
	add_child(sb)

func _process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D if is_inside_tree() else null
	_prompt.visible = player != null and player.global_position.distance_to(global_position) < USE_RANGE

func talk_to(player_node: Node) -> void:
	if _screen:
		_screen.open(player_node as _Player, self)

## Acolhe um recém-nascido no berçário
func admit_child(child_dict: Dictionary) -> void:
	if child_dict.is_empty():
		return
	if not child_dict.has("craft"):
		child_dict["craft"] = "Aprendiz de Horta"
	registered_children.append(child_dict)

func get_registered_children() -> Array[Dictionary]:
	return registered_children

## Faz as crianças do berçário crescerem com o passar dos dias (GDD-14 §2)
func advance_children_days(days: float) -> void:
	for ch in registered_children:
		var current_age: float = float(ch.get("age_days", 0.0)) + days
		ch["age_days"] = current_age
		if current_age < 3.0:
			ch["stage"] = 0 # BABY
			ch["stage_name"] = "Criança"
		elif current_age < 10.0:
			ch["stage"] = 1 # JUVENILE
			ch["stage_name"] = "Jovem Aprendiz"
		else:
			ch["stage"] = 2 # ADULT
			ch["stage_name"] = "Cidadão Pleno"

static func nearest_in_range(player_node: Node3D) -> TownNursery:
	if player_node == null or not player_node.is_inside_tree():
		return null
	for n in player_node.get_tree().get_nodes_in_group("town_nursery"):
		var st := n as TownNursery
		if st and st.global_position.distance_to(player_node.global_position) < USE_RANGE + 1.0:
			return st
	return null
