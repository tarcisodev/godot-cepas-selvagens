class_name BlackMarketStation
extends Node3D

## Estação Clandestina do Mercado Negro (GDD-05 §3).
## Localizada em ruínas ou acampamentos isolados na Zona Selvagem.
## Permite aos andarilhos negociarem ordens de compra sistêmicas e liquidarem peças forjadas.

const _BlackMarketScreen = preload("res://scripts/ui/black_market_screen.gd")
const _BlackMarketSystem = preload("res://scripts/systems/black_market_system.gd")
const _Player = preload("res://scripts/player.gd")

const USE_RANGE: float = 3.6

var market_system: _BlackMarketSystem
var _screen: _BlackMarketScreen
var _prompt: Label3D
var _lantern_light: OmniLight3D
var _pulse: float = 0.0

func _ready() -> void:
	add_to_group("talkable")
	add_to_group("black_market_station")
	
	if market_system == null:
		market_system = _BlackMarketSystem.get_instance(get_tree() if is_inside_tree() else null)
	
	_build_visuals()

	# Tela da Interface Clandestina
	var layer := CanvasLayer.new()
	layer.layer = 12
	add_child(layer)
	_screen = _BlackMarketScreen.new()
	layer.add_child(_screen)

	# Prompt flutuante
	_prompt = Label3D.new()
	_prompt.text = "🕶️ [E] Negociar com o Mercado Negro"
	_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt.font_size = 14
	_prompt.outline_size = 4
	_prompt.modulate = Color(0.85, 0.65, 1.0)
	_prompt.position.y = 1.9
	_prompt.visible = false
	add_child(_prompt)

	_snap_to_ground.call_deferred()

func _snap_to_ground() -> void:
	var landscape := get_tree().current_scene.get_node_or_null("Landscape") if (is_inside_tree() and get_tree().current_scene) else null
	if landscape and landscape.has_method("get_height_at"):
		global_position.y = landscape.get_height_at(global_position.x, global_position.z)

func _build_visuals() -> void:
	var slate_stone := StandardMaterial3D.new()
	slate_stone.albedo_color = Color(0.18, 0.17, 0.22)
	slate_stone.roughness = 0.8

	var dark_wood := StandardMaterial3D.new()
	dark_wood.albedo_color = Color(0.25, 0.18, 0.14)
	dark_wood.roughness = 0.75

	var cloth_mat := StandardMaterial3D.new()
	cloth_mat.albedo_color = Color(0.35, 0.18, 0.45)
	cloth_mat.roughness = 0.9

	# Balcão de pedra ardósia / contrabandista
	var counter := MeshInstance3D.new()
	var c_box := BoxMesh.new()
	c_box.size = Vector3(2.4, 1.0, 0.8)
	counter.mesh = c_box
	counter.material_override = slate_stone
	counter.position.y = 0.5
	add_child(counter)

	# Cobertura de tecido / manta de contrabando sobre a bancada
	var cloth := MeshInstance3D.new()
	var cl_box := BoxMesh.new()
	cl_box.size = Vector3(1.6, 0.05, 0.85)
	cloth.mesh = cl_box
	cloth.material_override = cloth_mat
	cloth.position = Vector3(0.1, 1.02, 0)
	add_child(cloth)

	# Caixotes de contrabando ao lado
	for offset in [Vector3(-1.4, 0.35, 0.2), Vector3(-1.35, 0.85, 0.15), Vector3(1.4, 0.35, -0.1)]:
		var crate := MeshInstance3D.new()
		var cr_box := BoxMesh.new()
		cr_box.size = Vector3(0.65, 0.65, 0.65)
		crate.mesh = cr_box
		crate.material_override = dark_wood
		crate.position = offset
		add_child(crate)

	# Poste de ferro com lampião violeta
	var pole := MeshInstance3D.new()
	var p_cyl := CylinderMesh.new()
	p_cyl.top_radius = 0.04
	p_cyl.bottom_radius = 0.05
	p_cyl.height = 2.2
	pole.mesh = p_cyl
	pole.position = Vector3(1.1, 1.1, 0.35)
	add_child(pole)

	_lantern_light = OmniLight3D.new()
	_lantern_light.light_color = Color(0.75, 0.3, 0.95)
	_lantern_light.light_energy = 1.1
	_lantern_light.omni_range = 5.0
	_lantern_light.position = Vector3(1.1, 2.05, 0.45)
	add_child(_lantern_light)

	# Colisor estático
	var sb := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.6, 1.5, 1.0)
	col.shape = shape
	col.position.y = 0.75
	sb.add_child(col)
	add_child(sb)

func _process(delta: float) -> void:
	if not is_inside_tree():
		return
	
	_pulse += delta * 2.0
	if _lantern_light:
		_lantern_light.light_energy = 0.95 + sin(_pulse) * 0.2

	if _prompt:
		var p := get_tree().get_first_node_in_group("player") as Node3D
		_prompt.visible = p != null and p.global_position.distance_to(global_position) < USE_RANGE

func talk_to(player_node: Node) -> void:
	if _screen:
		var sys := market_system
		if sys == null:
			sys = _BlackMarketSystem.get_instance(get_tree())
		_screen.open(player_node, sys)

static func nearest_in_range(player_node: Node3D) -> BlackMarketStation:
	if player_node == null or not player_node.is_inside_tree():
		return null
	for n in player_node.get_tree().get_nodes_in_group("black_market_station"):
		var st := n as BlackMarketStation
		if st and st.global_position.distance_to(player_node.global_position) < USE_RANGE + 1.0:
			return st
	return null
