class_name HuntingBait
extends Node3D
const _LedgerSources = preload("res://scripts/net/ledger_sources.gd")

## Isca Odorífera de Caça (GDD-03 §8).
## Espalha feromônios e aroma de ervas/vísceras em um raio de até 25 metros por 90 segundos.
## Atrai criaturas selvagens que estejam pastando ou vagando, direcionando-as para a armadilha.
## Se uma criatura alcançar a isca, consome o canteiro e sacia sua fome.

const _InventoryComponent = preload("res://scripts/components/inventory_component.gd")

signal consumed(bait: Node, creature: Node)
signal expired(bait: Node)
signal retrieved(bait: Node, by: Node)

@export var scent_radius: float = 25.0
@export var lifetime: float = 90.0

var placed_by: Node = null
var is_consumed: bool = false
var _prompt: Label3D
var _scent_light: OmniLight3D
var _pulse_time: float = 0.0

func _ready() -> void:
	add_to_group("talkable")
	add_to_group("hunting_baits")
	_build_visuals()
	_snap_to_ground.call_deferred()

func _snap_to_ground() -> void:
	var landscape := get_tree().current_scene.get_node_or_null("Landscape") if (is_inside_tree() and get_tree().current_scene) else null
	if landscape and landscape.has_method("get_height_at"):
		global_position.y = landscape.get_height_at(global_position.x, global_position.z)

func _build_visuals() -> void:
	# Montículo de carne e ervas concentradas
	var meat_mat := StandardMaterial3D.new()
	meat_mat.albedo_color = Color(0.72, 0.28, 0.25)
	meat_mat.roughness = 0.65

	var herb_mat := StandardMaterial3D.new()
	herb_mat.albedo_color = Color(0.28, 0.55, 0.22)
	herb_mat.roughness = 0.8

	var mound := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.25
	sphere.height = 0.22
	mound.mesh = sphere
	mound.material_override = meat_mat
	mound.position.y = 0.1
	add_child(mound)

	# Folhas e ervas aromáticas salpicadas
	for i in range(3):
		var leaf := MeshInstance3D.new()
		var p_mesh := PrismMesh.new()
		p_mesh.size = Vector3(0.12, 0.18, 0.05)
		leaf.mesh = p_mesh
		leaf.material_override = herb_mat
		var ang := float(i) * 2.1
		leaf.position = Vector3(cos(ang) * 0.15, 0.12, sin(ang) * 0.15)
		leaf.rotation = Vector3(0.2, ang, -0.3)
		add_child(leaf)

	# Brilho sutil de vapor odorífero / feromônio
	_scent_light = OmniLight3D.new()
	_scent_light.light_color = Color(0.85, 0.45, 0.35)
	_scent_light.light_energy = 0.8
	_scent_light.omni_range = 3.0
	_scent_light.position.y = 0.3
	add_child(_scent_light)

	# Prompt para o jogador
	_prompt = Label3D.new()
	_prompt.text = "🥩 [E] Recolher Isca Odorífera"
	_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt.font_size = 13
	_prompt.outline_size = 4
	_prompt.modulate = Color(0.95, 0.7, 0.7)
	_prompt.position.y = 0.65
	_prompt.visible = false
	add_child(_prompt)

func _process(delta: float) -> void:
	if not is_inside_tree() or is_consumed:
		return
	
	_pulse_time += delta * 2.5
	if _scent_light:
		_scent_light.light_energy = 0.6 + sin(_pulse_time) * 0.3

	# Atualiza tempo de vida
	lifetime -= delta
	if lifetime <= 0.0:
		expired.emit(self)
		queue_free()
		return

	# Prompt de recolhimento
	if _prompt:
		var p := get_tree().get_first_node_in_group("player") as Node3D
		_prompt.visible = p != null and p.global_position.distance_to(global_position) < 2.5

	# Atrai criaturas selvagens próximas
	_attract_nearby_creatures(delta)

func _attract_nearby_creatures(_delta: float) -> void:
	for node in get_tree().get_nodes_in_group("wild_creatures"):
		var creature := node as Node3D
		if creature == null or not is_instance_valid(creature):
			continue
		
		var dist: float = creature.global_position.distance_to(global_position)
		if dist <= 1.6:
			# Criatura alcançou a isca: alimenta-se dela
			_feed_creature(creature)
			return
		elif dist <= scent_radius:
			# Atrai a criatura se ela puder ser direcionada
			if creature.has_method("set_bait_attraction"):
				creature.call("set_bait_attraction", global_position)

func _feed_creature(creature: Node3D) -> void:
	is_consumed = true
	if "hunger" in creature:
		creature.set("hunger", 0.0)
	elif creature.has_meta("hunger"):
		creature.set_meta("hunger", 0.0)
	
	if placed_by and placed_by.has_signal("posture_changed"):
		var species: String = "criatura"
		if "dna" in creature and creature.dna != null:
			species = creature.dna.species_name()
		placed_by.posture_changed.emit("🍃 %s devorou a isca de feromônio!" % species)

	consumed.emit(self, creature)
	queue_free()

func talk_to(player: Node) -> void:
	if is_consumed:
		return
	
	var inv: _InventoryComponent = _get_inventory(player)
	if inv:
		_LedgerSources.gain(&"bait_pickup", name, func(): inv.add_material(&"isca_feromonio", 1, 3, [&"recolhido"]))

	if player and player.has_signal("posture_changed"):
		player.posture_changed.emit("🥩 Isca Odorífera recolhida.")

	retrieved.emit(self, player)
	queue_free()

func _get_inventory(node: Node) -> _InventoryComponent:
	if node == null:
		return null
	if "inventory" in node and node.inventory is _InventoryComponent:
		return node.inventory as _InventoryComponent
	if node.has_node("InventoryComponent"):
		return node.get_node("InventoryComponent") as _InventoryComponent
	for child in node.get_children():
		if child is _InventoryComponent:
			return child as _InventoryComponent
	return null
