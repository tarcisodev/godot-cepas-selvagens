class_name VillageChapel
extends Node3D

## Capela da Vila da Esperança (GDD-14 §4.1).
## Prédio comunitário onde são realizados casamentos, trocas de votos e divórcios.
## [E] abre a tela do Altar de Votos.

const _Player = preload("res://scripts/player.gd")
const _MarriageScreen = preload("res://scripts/ui/marriage_screen.gd")

const USE_RANGE: float = 4.0

var city: Node
var _screen: _MarriageScreen
var _prompt: Label3D
var _bell: MeshInstance3D
var _t: float = 0.0

func _ready() -> void:
	add_to_group("talkable")
	add_to_group("village_chapel")
	_build_visuals()

	var layer := CanvasLayer.new()
	layer.layer = 12
	add_child(layer)
	_screen = _MarriageScreen.new()
	layer.add_child(_screen)

	_prompt = Label3D.new()
	_prompt.text = "💍 [E] Altar de Votos (Capela)"
	_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt.font_size = 14
	_prompt.outline_size = 4
	_prompt.modulate = Color(1.0, 0.9, 0.4)
	_prompt.position.y = 1.6
	_prompt.visible = false
	add_child(_prompt)

func _build_visuals() -> void:
	# Materiais
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.45, 0.43, 0.42)
	stone.roughness = 0.85

	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.42, 0.28, 0.16)
	wood.roughness = 0.7

	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(0.9, 0.78, 0.25)
	gold.metallic = 0.85
	gold.roughness = 0.3

	# Base de pedra da capela
	var base := MeshInstance3D.new()
	var base_box := BoxMesh.new()
	base_box.size = Vector3(4.0, 0.4, 5.0)
	base.mesh = base_box
	base.material_override = stone
	base.position.y = 0.2
	add_child(base)

	# Pilares de madeira sagrada
	var pilar_positions := [
		Vector3(-1.8, 1.6, -2.2), Vector3(1.8, 1.6, -2.2),
		Vector3(-1.8, 1.6, 2.2), Vector3(1.8, 1.6, 2.2),
	]
	for pos in pilar_positions:
		var p := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.15
		cyl.bottom_radius = 0.18
		cyl.height = 2.8
		p.mesh = cyl
		p.material_override = wood
		p.position = pos
		add_child(p)

	# Telhado em arco
	var roof := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(4.4, 1.4, 5.4)
	roof.mesh = prism
	roof.material_override = wood
	roof.position = Vector3(0, 3.6, 0)
	add_child(roof)

	# Torre do sino
	var tower := MeshInstance3D.new()
	var t_box := BoxMesh.new()
	t_box.size = Vector3(1.2, 1.6, 1.2)
	tower.mesh = t_box
	tower.material_override = wood
	tower.position = Vector3(0, 4.8, 0)
	add_child(tower)

	# Sino de ouro
	_bell = MeshInstance3D.new()
	var b_cyl := CylinderMesh.new()
	b_cyl.top_radius = 0.12
	b_cyl.bottom_radius = 0.28
	b_cyl.height = 0.45
	_bell.mesh = b_cyl
	_bell.material_override = gold
	_bell.position = Vector3(0, 4.6, 0)
	add_child(_bell)

	# Altar de votos
	var altar := MeshInstance3D.new()
	var a_box := BoxMesh.new()
	a_box.size = Vector3(1.4, 0.9, 0.8)
	altar.mesh = a_box
	altar.material_override = stone
	altar.position = Vector3(0, 0.85, -1.2)
	add_child(altar)

	# Luz suave do altar
	var candle_light := OmniLight3D.new()
	candle_light.light_color = Color(1.0, 0.85, 0.45)
	candle_light.light_energy = 1.2
	candle_light.omni_range = 5.0
	candle_light.position = Vector3(0, 1.4, -1.2)
	add_child(candle_light)

	# Colisão estática para o jogador não atravessar
	var sb := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(4.2, 3.0, 5.2)
	col.shape = shape
	col.position.y = 1.5
	sb.add_child(col)
	add_child(sb)

func _process(delta: float) -> void:
	_t += delta
	if _bell:
		_bell.rotation.z = sin(_t * 1.5) * 0.08

	var player := get_tree().get_first_node_in_group("player") as Node3D if is_inside_tree() else null
	_prompt.visible = player != null and player.global_position.distance_to(global_position) < USE_RANGE

func talk_to(player_node: Node) -> void:
	if _screen:
		_screen.open(player_node as _Player)

static func nearest_in_range(player_node: Node3D) -> VillageChapel:
	if player_node == null or not player_node.is_inside_tree():
		return null
	for n in player_node.get_tree().get_nodes_in_group("village_chapel"):
		var st := n as VillageChapel
		if st and st.global_position.distance_to(player_node.global_position) < USE_RANGE + 1.0:
			return st
	return null
