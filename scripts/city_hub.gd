class_name CityHub
extends Node3D

## Estrutura da Cidade Principal: Vila da Esperança (Fase 2)
## Cria estradas de pedra, portões de paliçada, praça de mercado,
## banners, placas informativas e os NPCs de profissões.

const PATH_SCENE = preload("res://assets/models/nature/RockPath_Square_Wide.gltf")
const STALL_SCENE = preload("res://assets/models/props/fantasy/Stall_Empty.gltf")
const CART_SCENE = preload("res://assets/models/props/fantasy/Stall_Cart_Empty.gltf")
const BANNER1_SCENE = preload("res://assets/models/props/fantasy/Banner_1.gltf")
const BANNER2_SCENE = preload("res://assets/models/props/fantasy/Banner_2.gltf")
const PEASANT_SCENE = preload("res://assets/models/character/Female_Peasant.gltf")
const MALE_PEASANT_SCENE = preload("res://assets/models/character/Male_Peasant.gltf")

@export var landscape: MeshInstance3D

func _ready() -> void:
	if landscape == null:
		landscape = get_parent().get_node_or_null("Landscape")
	
	_build_town_sign()
	_build_market_square()
	_build_stone_roads()
	_build_palisade_gates()
	_spawn_city_npcs()

func _get_ground_y(x: float, z: float) -> float:
	if landscape and landscape.has_method("get_height_at"):
		return landscape.get_height_at(x, z)
	return 0.0

func _build_town_sign() -> void:
	var sign_pos := Vector3(1.5, _get_ground_y(1.5, -4.0), -4.0)
	var sign_label := Label3D.new()
	sign_label.name = "TownSign"
	sign_label.text = "🏛️ VILA DA ESPERANÇA\nZona Segura • Capital & Comércio"
	sign_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign_label.font_size = 28
	sign_label.outline_size = 6
	sign_label.outline_modulate = Color(0, 0, 0, 0.9)
	sign_label.modulate = Color(1.0, 0.9, 0.6)
	sign_label.visibility_range_end = 25.0
	sign_label.position = sign_pos + Vector3(0, 3.2, 0)
	add_child(sign_label)

func _build_market_square() -> void:
	# Banca de trocas e mercadorias
	if STALL_SCENE:
		var stall := STALL_SCENE.instantiate() as Node3D
		stall.position = Vector3(-4.2, _get_ground_y(-4.2, 3.2), 3.2)
		stall.rotation.y = deg_to_rad(45.0)
		stall.scale = Vector3.ONE * 0.8
		add_child(stall)
	
	# Carroça de suprimentos da guilda
	if CART_SCENE:
		var cart := CART_SCENE.instantiate() as Node3D
		cart.position = Vector3(6.5, _get_ground_y(6.5, 6.2), 6.2)
		cart.rotation.y = deg_to_rad(-60.0)
		cart.scale = Vector3.ONE * 0.75
		add_child(cart)
	
	# Banners da Vila
	if BANNER1_SCENE:
		var b1 := BANNER1_SCENE.instantiate() as Node3D
		b1.position = Vector3(-1.8, _get_ground_y(-1.8, -3.2), -3.2)
		b1.scale = Vector3.ONE * 0.8
		add_child(b1)
	
	if BANNER2_SCENE:
		var b2 := BANNER2_SCENE.instantiate() as Node3D
		b2.position = Vector3(4.8, _get_ground_y(4.8, -3.2), -3.2)
		b2.scale = Vector3.ONE * 0.8
		add_child(b2)

func _build_stone_roads() -> void:
	if PATH_SCENE == null:
		return
	
	# Estrada principal ligando a saída Norte, o centro da praça e o Acampamento
	var points: Array[Vector2] = [
		Vector2(1.5, -4.5),
		Vector2(1.5, -2.5),
		Vector2(1.5, -0.5),
		Vector2(1.5, 1.5),
		Vector2(1.5, 3.5),
		Vector2(2.5, 5.0),
		Vector2(4.5, 5.5),
		Vector2(6.5, 5.8)
	]
	
	for i in points.size():
		var p: Vector2 = points[i]
		var y := _get_ground_y(p.x, p.y) + 0.03
		var road := PATH_SCENE.instantiate() as Node3D
		road.position = Vector3(p.x, y, p.y)
		road.scale = Vector3.ONE * 0.85
		road.rotation.y = deg_to_rad(float(i * 15))
		add_child(road)

func _build_palisade_gates() -> void:
	# Portão Norte (em direção à Besta e Cume)
	_build_post_pair(Vector3(-1.2, _get_ground_y(-1.2, -4.8), -4.8), Vector3(4.2, _get_ground_y(4.2, -4.8), -4.8), "Portão Norte")
	# Portão Leste (em direção ao Rio e Pontes)
	_build_post_pair(Vector3(10.5, _get_ground_y(10.5, 1.5), 1.5), Vector3(10.5, _get_ground_y(10.5, 6.5), 6.5), "Portão Leste")

func _build_post_pair(pos_a: Vector3, pos_b: Vector3, gate_name: String) -> void:
	for p in [pos_a, pos_b]:
		var post := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.28
		cyl.bottom_radius = 0.32
		cyl.height = 3.6
		post.mesh = cyl
		post.position = p + Vector3(0, 1.8, 0)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.35, 0.22, 0.12)
		post.material_override = mat
		add_child(post)
		
		# Lanterna no topo do mourão
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.78, 0.45)
		light.light_energy = 1.0
		light.omni_range = 6.0
		light.position = p + Vector3(0, 3.6, 0)
		add_child(light)

func _spawn_city_npcs() -> void:
	# 1. Alquimista & Botânica (perto da banca de mercado)
	var alchemist := AlchemistNPC.new()
	alchemist.position = Vector3(-4.5, _get_ground_y(-4.5, 1.8), 1.8)
	alchemist.rotation.y = deg_to_rad(30.0)
	add_child(alchemist)
	
	# 2. Mestre Construtor / Arquiteto (perto do acampamento e forja)
	var architect := ArchitectNPC.new()
	architect.position = Vector3(4.2, _get_ground_y(4.2, 1.8), 1.8)
	architect.rotation.y = deg_to_rad(-45.0)
	add_child(architect)


## NPC Alquimista e Botânica da Cidade
class AlchemistNPC extends Node3D:
	var label: Label3D
	
	func _ready() -> void:
		add_to_group("talkable")
		_build_visual()
	
	func _build_visual() -> void:
		if CityHub.PEASANT_SCENE:
			var model := CityHub.PEASANT_SCENE.instantiate() as Node3D
			model.scale = Vector3.ONE * 0.95
			add_child(model)
		else:
			var mesh_inst := MeshInstance3D.new()
			var cap := CapsuleMesh.new()
			cap.radius = 0.3
			cap.height = 1.6
			mesh_inst.mesh = cap
			mesh_inst.position.y = 0.8
			add_child(mesh_inst)
		
		label = Label3D.new()
		label.text = "🌿 Alquimista Botânica\n[E] Conversar"
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.font_size = 18
		label.outline_size = 4
		label.modulate = Color(0.7, 1.0, 0.8)
		label.position.y = 1.95
		label.visibility_range_end = 5.0
		add_child(label)
	
	func talk_to(player: Node) -> void:
		if player and player.has_signal("posture_changed"):
			player.posture_changed.emit("🌿 Alquimista: 'Traga ervas e flores para cruzarmos cepas raras!'")


## NPC Arquiteto e Mestre Construtor da Cidade
class ArchitectNPC extends Node3D:
	var label: Label3D
	
	func _ready() -> void:
		add_to_group("talkable")
		_build_visual()
	
	func _build_visual() -> void:
		if CityHub.MALE_PEASANT_SCENE:
			var model := CityHub.MALE_PEASANT_SCENE.instantiate() as Node3D
			model.scale = Vector3.ONE * 0.95
			add_child(model)
		else:
			var mesh_inst := MeshInstance3D.new()
			var cap := CapsuleMesh.new()
			cap.radius = 0.32
			cap.height = 1.65
			mesh_inst.mesh = cap
			mesh_inst.position.y = 0.82
			add_child(mesh_inst)
		
		label = Label3D.new()
		label.text = "📐 Mestre Construtor\n[E] Conversar"
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.font_size = 18
		label.outline_size = 4
		label.modulate = Color(1.0, 0.85, 0.6)
		label.position.y = 2.0
		label.visibility_range_end = 5.0
		add_child(label)
	
	func talk_to(player: Node) -> void:
		if player and player.has_signal("posture_changed"):
			player.posture_changed.emit("📐 Construtor: 'Aperte [B] para abrir o modo construção e fincar seu Totem na natureza!'")
