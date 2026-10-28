class_name CookingStation
extends Node3D

const _Player = preload("res://scripts/player.gd")
const _CookingScreen = preload("res://scripts/ui/cooking_screen.gd")

## Estação de Culinária / Caldeirão (GDD-13 §4).
## [E] abre a tela de culinária para combinar ingredientes em pratos com buffs.

const USE_RANGE: float = 3.5

var city: Node
var _screen: _CookingScreen
var _prompt: Label3D
var _soup_mesh: MeshInstance3D
var _t: float = 0.0

func _ready() -> void:
	add_to_group("talkable")
	add_to_group("cooking_station")
	_build_visuals()

	var layer := CanvasLayer.new()
	layer.layer = 12
	add_child(layer)
	_screen = _CookingScreen.new()
	layer.add_child(_screen)

	_prompt = Label3D.new()
	_prompt.text = "🍲 [E] Caldeirão Culinário"
	_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt.font_size = 14
	_prompt.outline_size = 4
	_prompt.modulate = Color(1.0, 0.8, 0.4)
	_prompt.position.y = 1.3
	_prompt.visible = false
	add_child(_prompt)

func _build_visuals() -> void:
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.2, 0.2, 0.22)
	iron.metallic = 0.7
	iron.roughness = 0.5

	# Tripé de ferro
	for i in 3:
		var leg := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.03
		cm.bottom_radius = 0.03
		cm.height = 0.9
		leg.mesh = cm
		leg.material_override = iron
		var a := TAU * i / 3.0
		leg.position = Vector3(cos(a) * 0.25, 0.42, sin(a) * 0.25)
		leg.rotation = Vector3(deg_to_rad(15.0), a + PI * 0.5, 0.0)
		add_child(leg)

	# Caldeirão bojudo de ferro fundido
	var pot := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.32
	sm.height = 0.42
	pot.mesh = sm
	pot.material_override = iron
	pot.position = Vector3(0, 0.52, 0)
	add_child(pot)

	# Borda superior do caldeirão
	var rim := MeshInstance3D.new()
	var rm := CylinderMesh.new()
	rm.top_radius = 0.30
	rm.bottom_radius = 0.30
	rm.height = 0.06
	rim.mesh = rm
	rim.material_override = iron
	rim.position = Vector3(0, 0.72, 0)
	add_child(rim)

	# Caldo borbulhante no topo
	_soup_mesh = MeshInstance3D.new()
	var soup_cyl := CylinderMesh.new()
	soup_cyl.top_radius = 0.28
	soup_cyl.bottom_radius = 0.28
	soup_cyl.height = 0.02
	_soup_mesh.mesh = soup_cyl
	var soup_mat := StandardMaterial3D.new()
	soup_mat.albedo_color = Color(0.72, 0.45, 0.2)
	soup_mat.roughness = 0.3
	_soup_mesh.material_override = soup_mat
	_soup_mesh.position = Vector3(0, 0.71, 0)
	add_child(_soup_mesh)

	# Brasas e foguinho embaixo
	var fire_light := OmniLight3D.new()
	fire_light.light_color = Color(1.0, 0.5, 0.15)
	fire_light.omni_range = 3.0
	fire_light.light_energy = 0.9
	fire_light.position = Vector3(0, 0.2, 0)
	add_child(fire_light)

	# Colisão estática
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.4
	shape.height = 0.8
	col.shape = shape
	col.position.y = 0.4
	body.add_child(col)
	add_child(body)

func _process(delta: float) -> void:
	_t += delta
	if _soup_mesh:
		# Respiração do caldo borbulhando levemente
		_soup_mesh.position.y = 0.71 + sin(_t * 4.0) * 0.005

	var player := get_tree().get_first_node_in_group("player") as Node3D if is_inside_tree() else null
	_prompt.visible = player != null and player.global_position.distance_to(global_position) < USE_RANGE

func talk_to(player_node: Node) -> void:
	if _screen:
		_screen.open(player_node as _Player)

static func nearest_in_range(player_node: Node3D) -> CookingStation:
	if player_node == null or not player_node.is_inside_tree():
		return null
	for n in player_node.get_tree().get_nodes_in_group("cooking_station"):
		var st := n as CookingStation
		if st and st.global_position.distance_to(player_node.global_position) < USE_RANGE + 1.0:
			return st
	return null
