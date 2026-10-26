class_name HuntingTrap
extends Node3D

## Armadilha de Mandíbula de Caça (GDD-03 §8 e GDD-05 §3).
## Instalada no solo pelo jogador. Quando uma criatura ou monstro entra na área:
## 1. Desfecha as mandíbulas de ferro causando dano concentrado nas pernas (HitEvent / CombatResolver).
## 2. Imobiliza o alvo por 8 segundos (State.TRAPPED), facilitando a quebra anatômica e captura.
## 3. O jogador pode desarmar e recuperar a armadilha se ainda não tiver sido disparada.

const _HitEvent = preload("res://scripts/data/hit_event.gd")
const _DamageType = preload("res://scripts/data/damage_type.gd")
const _CombatResolver = preload("res://scripts/systems/combat_resolver.gd")
const _WildCreature = preload("res://scripts/creatures/wild_creature.gd")
const _InventoryComponent = preload("res://scripts/components/inventory_component.gd")

enum State { ARMED, TRIGGERED, DISARMED }

signal triggered(trap: Node, target: Node)
signal retrieved(trap: Node, by: Node)

@export var trigger_radius: float = 1.6
@export var trap_damage: float = 45.0
@export var trap_duration: float = 8.0

var state: State = State.ARMED
var placed_by: Node = null
var trapped_target: Node = null

var _base_mesh: MeshInstance3D
var _jaw_left: Node3D
var _jaw_right: Node3D
var _prompt: Label3D
var _trigger_area: Area3D

func _ready() -> void:
	add_to_group("talkable")
	add_to_group("hunting_traps")
	_build_visuals()
	_setup_collision()
	_snap_to_ground.call_deferred()

func _snap_to_ground() -> void:
	var landscape := get_tree().current_scene.get_node_or_null("Landscape") if (is_inside_tree() and get_tree().current_scene) else null
	if landscape and landscape.has_method("get_height_at"):
		global_position.y = landscape.get_height_at(global_position.x, global_position.z)

func _build_visuals() -> void:
	var metal_dark := StandardMaterial3D.new()
	metal_dark.albedo_color = Color(0.24, 0.24, 0.26)
	metal_dark.metallic = 0.85
	metal_dark.roughness = 0.45

	var metal_teeth := StandardMaterial3D.new()
	metal_teeth.albedo_color = Color(0.65, 0.65, 0.7)
	metal_teeth.metallic = 0.95
	metal_teeth.roughness = 0.25

	# Base circular central
	_base_mesh = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.45
	cyl.bottom_radius = 0.48
	cyl.height = 0.06
	_base_mesh.mesh = cyl
	_base_mesh.material_override = metal_dark
	_base_mesh.position.y = 0.03
	add_child(_base_mesh)

	# Placa de pressão central
	var plate := MeshInstance3D.new()
	var plate_cyl := CylinderMesh.new()
	plate_cyl.top_radius = 0.18
	plate_cyl.bottom_radius = 0.18
	plate_cyl.height = 0.08
	plate.mesh = plate_cyl
	var plate_mat := StandardMaterial3D.new()
	plate_mat.albedo_color = Color(0.45, 0.35, 0.25)
	plate.material_override = plate_mat
	plate.position.y = 0.04
	add_child(plate)

	# Mandíbula Esquerda (Articulada)
	_jaw_left = Node3D.new()
	_jaw_left.position = Vector3(-0.35, 0.05, 0)
	add_child(_jaw_left)

	var jaw_l_mesh := MeshInstance3D.new()
	var box_l := BoxMesh.new()
	box_l.size = Vector3(0.1, 0.06, 0.7)
	jaw_l_mesh.mesh = box_l
	jaw_l_mesh.material_override = metal_dark
	_jaw_left.add_child(jaw_l_mesh)

	# Dentes da mandíbula esquerda
	for i in range(4):
		var tooth := MeshInstance3D.new()
		var p_mesh := PrismMesh.new()
		p_mesh.size = Vector3(0.08, 0.14, 0.08)
		tooth.mesh = p_mesh
		tooth.material_override = metal_teeth
		tooth.position = Vector3(0, 0.08, -0.25 + i * 0.16)
		_jaw_left.add_child(tooth)

	# Mandíbula Direita (Articulada)
	_jaw_right = Node3D.new()
	_jaw_right.position = Vector3(0.35, 0.05, 0)
	add_child(_jaw_right)

	var jaw_r_mesh := MeshInstance3D.new()
	var box_r := BoxMesh.new()
	box_r.size = Vector3(0.1, 0.06, 0.7)
	jaw_r_mesh.mesh = box_r
	jaw_r_mesh.material_override = metal_dark
	_jaw_right.add_child(jaw_r_mesh)

	# Dentes da mandíbula direita
	for i in range(4):
		var tooth := MeshInstance3D.new()
		var p_mesh := PrismMesh.new()
		p_mesh.size = Vector3(0.08, 0.14, 0.08)
		tooth.mesh = p_mesh
		tooth.material_override = metal_teeth
		tooth.position = Vector3(0, 0.08, -0.25 + i * 0.16)
		_jaw_right.add_child(tooth)

	# Configura abertura inicial (ARMADA: mandíbulas abertas)
	_jaw_left.rotation.z = deg_to_rad(65.0)
	_jaw_right.rotation.z = deg_to_rad(-65.0)

	# Prompt flutuante para o jogador
	_prompt = Label3D.new()
	_prompt.text = "⚙️ [E] Desarmar & Recolher Armadilha"
	_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt.font_size = 13
	_prompt.outline_size = 4
	_prompt.modulate = Color(0.9, 0.85, 0.6)
	_prompt.position.y = 0.8
	_prompt.visible = false
	add_child(_prompt)

func _setup_collision() -> void:
	_trigger_area = Area3D.new()
	_trigger_area.name = "TriggerArea"
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = trigger_radius
	shape.height = 1.0
	col.shape = shape
	col.position.y = 0.5
	_trigger_area.add_child(col)
	_trigger_area.body_entered.connect(_on_body_entered)
	_trigger_area.area_entered.connect(_on_area_entered)
	add_child(_trigger_area)

func _process(_delta: float) -> void:
	if not is_inside_tree():
		return
	
	# Atualiza visibilidade do prompt de desarme para o jogador
	if state == State.ARMED and _prompt:
		var p := get_tree().get_first_node_in_group("player") as Node3D
		_prompt.visible = p != null and p.global_position.distance_to(global_position) < 2.5
	elif _prompt:
		_prompt.visible = false

	# Verificação ativa de proximidade para criaturas selvagens
	if state == State.ARMED:
		_check_nearby_creatures()

func _check_nearby_creatures() -> void:
	for node in get_tree().get_nodes_in_group("wild_creatures"):
		var c := node as Node3D
		if c and is_instance_valid(c) and c != placed_by:
			if c.global_position.distance_to(global_position) <= trigger_radius:
				snap_shut(c)
				return

func _on_body_entered(body: Node) -> void:
	if state != State.ARMED or body == placed_by:
		return
	if body.is_in_group("wild_creatures") or body.is_in_group("dummy_creatures") or body.is_in_group("bosses"):
		snap_shut(body)

func _on_area_entered(area: Area3D) -> void:
	if state != State.ARMED:
		return
	var parent: Node = area.get_parent()
	if parent and parent != placed_by and (parent.is_in_group("wild_creatures") or parent.is_in_group("dummy_creatures")):
		snap_shut(parent)

## Dispara a armadilha contra a presa
func snap_shut(target: Node) -> bool:
	if state != State.ARMED or target == null:
		return false
	
	state = State.TRIGGERED
	trapped_target = target

	# Animação de fechar as mandíbulas abruptamente
	if _jaw_left and _jaw_right:
		var tw := create_tween().set_parallel(true)
		tw.tween_property(_jaw_left, "rotation:z", deg_to_rad(0.0), 0.08)
		tw.tween_property(_jaw_right, "rotation:z", deg_to_rad(0.0), 0.08)

	# 1. Aplica Dano Físico Concentrado nas Pernas (ADR-0003: HitEvent / CombatResolver)
	var hit := _HitEvent.new(
		placed_by,
		target,
		trap_damage,
		_DamageType.Type.IMPACT,
		40.0,
		&"leg"
	)
	hit.part_break_damage = 65.0
	hit.hit_position = global_position
	hit.hit_normal = Vector3.UP
	_CombatResolver.resolve_hit(hit)

	# 2. Imobiliza criatura selvagem ou aplica estado de aprisionamento
	if target.has_method("force_trap"):
		target.call("force_trap", placed_by, trap_duration)
	elif "state" in target:
		target.set("state", 3)

	if placed_by and placed_by.has_signal("posture_changed"):
		var target_name: String = target.name
		if "dna" in target and target.dna != null:
			target_name = target.dna.species_name()
		placed_by.posture_changed.emit("💥 Mandíbula de ferro disparou em %s! Alvo imobilizado." % target_name)

	triggered.emit(self, target)
	return true

## Interação do jogador: [E] desarma e recupera a peça para a mochila
func talk_to(player: Node) -> void:
	if state != State.ARMED:
		return
	
	state = State.DISARMED
	var inv: _InventoryComponent = _get_inventory(player)
	if inv:
		inv.add_material(&"armadilha_mola", 1, 3, [&"recolhido"])
	
	if player and player.has_signal("posture_changed"):
		player.posture_changed.emit("⚙️ Armadilha de Mandíbula recolhida.")

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
