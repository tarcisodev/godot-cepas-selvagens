class_name TrapSystem
extends Node

## Gerenciador de Armadilhas e Iscas de Caça no Mundo (GDD-03 §8).
## Controla o posicionamento, validação e interação de armadilhas no terreno.

const _HuntingTrap = preload("res://scripts/systems/hunting_trap.gd")
const _HuntingBait = preload("res://scripts/systems/hunting_bait.gd")
const _InventoryComponent = preload("res://scripts/components/inventory_component.gd")

signal trap_deployed(trap: _HuntingTrap, player: Node)
signal bait_deployed(bait: _HuntingBait, player: Node)

static var _instance: Node = null

func _ready() -> void:
	add_to_group("trap_system")
	_instance = self

static func get_instance(tree: SceneTree = null) -> Node:
	if _instance != null and is_instance_valid(_instance):
		return _instance
	if tree != null:
		var found := tree.get_first_node_in_group("trap_system")
		if found != null:
			_instance = found
			return found
		var root := tree.current_scene
		if root != null:
			var script = load("res://scripts/systems/trap_system.gd")
			var new_sys = script.new()
			new_sys.name = "TrapSystem"
			root.add_child(new_sys)
			_instance = new_sys
			return new_sys
	return null

## Arma uma mandíbula de ferro à frente do jogador consumindo 1 material
func deploy_trap_by_player(player: Node, material_id: StringName = &"armadilha_mola") -> bool:
	if player == null:
		return false
	
	var inv: _InventoryComponent = _get_inventory(player)
	if inv == null or inv.get_material_count(material_id) < 1:
		return false
	
	if not inv.consume_material(material_id, 1):
		return false

	var trap := _HuntingTrap.new()
	trap.placed_by = player

	# Adiciona à cena
	var parent_node := player.get_parent() if player.get_parent() else self
	parent_node.add_child(trap)

	# Posiciona ~1.5m à frente do jogador
	var p3d := player as Node3D
	if p3d and p3d.is_inside_tree() and trap.is_inside_tree():
		var forward := -p3d.global_transform.basis.z.normalized()
		forward.y = 0.0
		if forward.length_squared() < 0.01:
			forward = Vector3.FORWARD
		else:
			forward = forward.normalized()
		trap.global_position = p3d.global_position + forward * 1.5
	elif p3d:
		trap.position = p3d.position + Vector3(0, 0, 1.5)
	elif "global_position" in player and trap.is_inside_tree():
		trap.global_position = player.global_position + Vector3(0, 0, 1.5)

	trap_deployed.emit(trap, player)
	return true

## Coloca uma isca odorífera no chão consumindo 1 material
func deploy_bait_by_player(player: Node, material_id: StringName = &"isca_feromonio") -> bool:
	if player == null:
		return false
	
	var inv: _InventoryComponent = _get_inventory(player)
	if inv == null or inv.get_material_count(material_id) < 1:
		return false

	if not inv.consume_material(material_id, 1):
		return false

	var bait := _HuntingBait.new()
	bait.placed_by = player

	# Adiciona à cena
	var parent_node := player.get_parent() if player.get_parent() else self
	parent_node.add_child(bait)

	var p3d := player as Node3D
	if p3d and p3d.is_inside_tree() and bait.is_inside_tree():
		var forward := -p3d.global_transform.basis.z.normalized()
		forward.y = 0.0
		if forward.length_squared() < 0.01:
			forward = Vector3.FORWARD
		else:
			forward = forward.normalized()
		bait.global_position = p3d.global_position + forward * 1.2
	elif p3d:
		bait.position = p3d.position + Vector3(0, 0, 1.2)
	elif "global_position" in player and bait.is_inside_tree():
		bait.global_position = player.global_position + Vector3(0, 0, 1.2)

	bait_deployed.emit(bait, player)
	return true

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
