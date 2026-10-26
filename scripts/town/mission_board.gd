class_name MissionBoard
extends Node3D

## Quadro Físico de Missões e Contratos da Vila (GDD-05 §5, GDD-03, GDD-13).
## Fica na praça da vila, exibindo pergaminhos afixados com pregos e iluminado por lampião.
## [E] abre a tela MissionBoardScreen para aceitar e entregar contratos.

const _Player = preload("res://scripts/player.gd")
const _MissionBoardScreen = preload("res://scripts/ui/mission_board_screen.gd")
const _MissionBoardSystem = preload("res://scripts/systems/mission_board_system.gd")

const USE_RANGE: float = 3.8

var city: Node
var mission_system: _MissionBoardSystem
var _screen: _MissionBoardScreen
var _prompt: Label3D
var _t: float = 0.0

func _ready() -> void:
	add_to_group("talkable")
	add_to_group("mission_board")
	if mission_system == null:
		mission_system = _MissionBoardSystem.new()
	_build_visuals()

	var layer := CanvasLayer.new()
	layer.layer = 12
	add_child(layer)
	_screen = _MissionBoardScreen.new()
	layer.add_child(_screen)

	_prompt = Label3D.new()
	_prompt.text = "📋 [E] Quadro de Missões & Contratos"
	_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt.font_size = 14
	_prompt.outline_size = 4
	_prompt.modulate = Color(0.95, 0.85, 0.4)
	_prompt.position.y = 1.9
	_prompt.visible = false
	add_child(_prompt)

func _build_visuals() -> void:
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.42, 0.28, 0.16)
	wood.roughness = 0.75

	var board_mat := StandardMaterial3D.new()
	board_mat.albedo_color = Color(0.68, 0.52, 0.35)
	board_mat.roughness = 0.85

	var paper_mat := StandardMaterial3D.new()
	paper_mat.albedo_color = Color(0.92, 0.88, 0.78)
	paper_mat.roughness = 0.9

	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.25, 0.25, 0.28)
	metal.metallic = 0.8
	metal.roughness = 0.4

	# Postes de sustentação
	for x_offset in [-1.1, 1.1]:
		var post := MeshInstance3D.new()
		var p_cyl := CylinderMesh.new()
		p_cyl.top_radius = 0.08
		p_cyl.bottom_radius = 0.10
		p_cyl.height = 2.4
		post.mesh = p_cyl
		post.material_override = wood
		post.position = Vector3(x_offset, 1.2, 0)
		add_child(post)

	# Tabuleiro principal de madeira/cortiça
	var board := MeshInstance3D.new()
	var b_box := BoxMesh.new()
	b_box.size = Vector3(2.3, 1.3, 0.12)
	board.mesh = b_box
	board.material_override = board_mat
	board.position = Vector3(0, 1.45, 0)
	add_child(board)

	# Telhadinho para proteção contra chuva
	var roof := MeshInstance3D.new()
	var r_prism := PrismMesh.new()
	r_prism.size = Vector3(2.6, 0.5, 0.6)
	roof.mesh = r_prism
	roof.material_override = wood
	roof.position = Vector3(0, 2.25, 0)
	add_child(roof)

	# Pergaminhos pregados no quadro
	var paper_offsets := [
		Vector3(-0.65, 1.55, 0.07), Vector3(0.0, 1.58, 0.07), Vector3(0.65, 1.52, 0.07),
		Vector3(-0.45, 1.25, 0.07), Vector3(0.35, 1.22, 0.07)
	]
	for pos in paper_offsets:
		var note := MeshInstance3D.new()
		var n_box := BoxMesh.new()
		n_box.size = Vector3(0.42, 0.48, 0.01)
		note.mesh = n_box
		note.material_override = paper_mat
		note.position = pos
		add_child(note)

	# Lampião a óleo no topo
	var lantern_light := OmniLight3D.new()
	lantern_light.light_color = Color(1.0, 0.85, 0.5)
	lantern_light.light_energy = 0.95
	lantern_light.omni_range = 4.5
	lantern_light.position = Vector3(0, 1.9, 0.25)
	add_child(lantern_light)

	# Colisão estática
	var sb := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.5, 2.2, 0.5)
	col.shape = shape
	col.position.y = 1.1
	sb.add_child(col)
	add_child(sb)

func _process(_delta: float) -> void:
	if _prompt:
		var player := get_tree().get_first_node_in_group("player") as Node3D if is_inside_tree() else null
		_prompt.visible = player != null and player.global_position.distance_to(global_position) < USE_RANGE

func talk_to(player_node: Node) -> void:
	if _screen:
		var sys := mission_system
		if city and "mission_system" in city and city.mission_system != null:
			sys = city.mission_system
		_screen.open(player_node as _Player, sys, city)

static func nearest_in_range(player_node: Node3D) -> MissionBoard:
	if player_node == null or not player_node.is_inside_tree():
		return null
	for n in player_node.get_tree().get_nodes_in_group("mission_board"):
		var st := n as MissionBoard
		if st and st.global_position.distance_to(player_node.global_position) < USE_RANGE + 1.0:
			return st
	return null
