class_name RockCollision
extends RefCounted

## Colisão de pedra no formato da pedra: casca convexa tirada da própria malha (uma por malha,
## reaproveitada entre as cópias). Antes as pedras do rio não tinham colisão e as do campo usavam
## uma esfera baixa, e o personagem entrava dentro delas.

## Pedrinhas mais baixas que isso (m, já com a escala) ficam sem colisão: dá para passar por cima
const MIN_HEIGHT: float = 0.35

static var _shapes: Dictionary = {}

## Põe um StaticBody3D com a casca convexa em cada malha da pedra. Devolve quantas ganhou.
static func add(rock: Node3D) -> int:
	var count := 0
	var meshes: Array[Node] = rock.find_children("*", "MeshInstance3D", true, false)
	if rock is MeshInstance3D:
		meshes.append(rock)
	for n in meshes:
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			continue
		var height := mi.mesh.get_aabb().size.y * absf(_chain_scale(mi, rock) * rock.scale.y)
		if height < MIN_HEIGHT:
			continue
		var shape: Shape3D = _shapes.get(mi.mesh)
		if shape == null:
			shape = mi.mesh.create_convex_shape(true, true)
			_shapes[mi.mesh] = shape
		var body := StaticBody3D.new()
		body.name = "RockCollision"
		var col := CollisionShape3D.new()
		col.shape = shape
		body.add_child(col)
		mi.add_child(body)
		count += 1
	return count

## Escala acumulada entre a malha e a raiz da pedra (funciona antes de entrar na árvore)
static func _chain_scale(node: Node3D, root: Node3D) -> float:
	var s := 1.0
	var n: Node = node
	while n != null and n != root:
		if n is Node3D:
			s *= (n as Node3D).scale.y
		n = n.get_parent()
	return s
