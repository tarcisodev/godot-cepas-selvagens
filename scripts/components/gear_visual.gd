class_name GearVisual
extends Node

## Mostra no corpo as peças forjadas equipadas (GDD-06 §6): elmo com chifre, capuz de penas,
## gibão de couro e braçadeiras de galhada. Cada peça é montada com primitivas e presa a um
## osso do rig UAL; a posição é calculada na pose de descanso, então serve para qualquer DNA.
## Reconstrói quando o equipamento muda ou quando o corpo é refeito (Barbeiro).

@export var visual: CharacterVisual
@export var inventory: InventoryComponent

var _sockets: Array[Node] = []
var _skeleton_seen: Skeleton3D

func _ready() -> void:
	if inventory:
		inventory.equipment_changed.connect(func(_s, _n): refresh())
	refresh.call_deferred()

func _process(_delta: float) -> void:
	# Corpo refeito (aparência nova): as peças sumiram com o esqueleto antigo
	if visual and visual.skeleton != _skeleton_seen:
		refresh()

func refresh() -> void:
	for s in _sockets:
		if is_instance_valid(s):
			s.queue_free()
	_sockets.clear()
	if visual == null or visual.skeleton == null or inventory == null:
		return
	_skeleton_seen = visual.skeleton
	for slot in inventory.equipped_items:
		var item: ForgedItem = inventory.equipped_items[slot]
		match item.recipe_id:
			&"elmo_chifre_de_pedra":
				_helmet(item)
			&"capuz_penacho":
				_hood(item)
			&"gibao_andarilho":
				_vest(item)
			&"bracadeiras_galhada":
				_bracer(item, &"lowerarm_l")
				_bracer(item, &"lowerarm_r")

# ---------------------------------------------------------------- peças

func _helmet(item: ForgedItem) -> void:
	var root := _piece(&"Head", Vector3(0, 0.1, 0))
	if root == null:
		return
	var stone := _mat(Color(0.5, 0.48, 0.45) if not item.is_broken() else Color(0.35, 0.3, 0.28), 0.8)
	var cap := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.16
	sm.height = 0.16
	sm.is_hemisphere = true
	cap.mesh = sm
	cap.material_override = stone
	root.add_child(cap)
	var horn := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = 0.035
	cm.height = 0.22
	horn.mesh = cm
	horn.position = Vector3(0, 0.12, -0.1)
	horn.rotation.x = -0.6
	horn.material_override = _mat(Color(0.88, 0.82, 0.68), 0.6)
	root.add_child(horn)
	_glow_if_iridescent(item, root)

func _hood(item: ForgedItem) -> void:
	var root := _piece(&"Head", Vector3(0, 0.06, 0.02))
	if root == null:
		return
	var feather_color := MaterialData.of(&"pena_penacho").color
	var hood := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.04
	cm.bottom_radius = 0.17
	cm.height = 0.26
	hood.mesh = cm
	hood.position.y = 0.06
	hood.material_override = _mat(feather_color.darkened(0.25), 0.9)
	root.add_child(hood)
	for i in 5:
		var f := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.5
		sm.height = 1.0
		f.mesh = sm
		f.scale = Vector3(0.03, 0.2, 0.06)
		f.position = Vector3((i - 2) * 0.045, 0.24, 0.06)
		f.rotation.x = 0.5
		f.rotation.z = (i - 2) * 0.2
		f.material_override = _mat(feather_color.lightened(0.15 * (i % 2)), 0.9)
		root.add_child(f)
	_glow_if_iridescent(item, root)

func _vest(item: ForgedItem) -> void:
	var root := _piece(&"spine_03", Vector3(0, -0.05, 0))
	if root == null:
		return
	var vest := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.19
	cm.height = 0.62
	vest.mesh = cm
	vest.scale = Vector3(1.08, 1.0, 0.8)
	vest.material_override = _mat(MaterialData.of(&"couro_trotador").color.darkened(0.1), 0.85)
	root.add_child(vest)
	# Cinto de tendão
	var belt := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.18
	tm.outer_radius = 0.21
	belt.mesh = tm
	belt.position.y = -0.22
	belt.scale = Vector3(1.08, 1.0, 0.82)
	belt.material_override = _mat(Color(0.3, 0.2, 0.12), 0.8)
	root.add_child(belt)
	_glow_if_iridescent(item, root)

func _bracer(item: ForgedItem, bone: StringName) -> void:
	var root := _piece(bone, Vector3.ZERO, true)
	if root == null:
		return
	var sleeve := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.05
	cm.bottom_radius = 0.06
	cm.height = 0.18
	sleeve.mesh = cm
	sleeve.material_override = _mat(MaterialData.of(&"couro_trotador").color, 0.85)
	root.add_child(sleeve)
	var spike := MeshInstance3D.new()
	var sp := CylinderMesh.new()
	sp.top_radius = 0.0
	sp.bottom_radius = 0.02
	sp.height = 0.1
	spike.mesh = sp
	spike.position = Vector3(0.05, 0.02, 0)
	spike.rotation.z = -1.2
	spike.material_override = _mat(Color(0.86, 0.8, 0.66), 0.6)
	root.add_child(spike)
	_glow_if_iridescent(item, root)

# ---------------------------------------------------------------- encaixe no osso

## Cria o soquete no osso e devolve o nó da peça já no lugar (em pé, no espaço do esqueleto).
## `along_bone` = alinha a peça ao comprimento do osso (braçadeiras)
func _piece(bone: StringName, offset: Vector3, along_bone: bool = false) -> Node3D:
	var sk := visual.skeleton
	var idx := sk.find_bone(bone)
	if idx < 0:
		return null
	var rest := sk.get_bone_global_rest(idx)
	var want := Transform3D(Basis.IDENTITY, rest.origin + offset)
	if along_bone:
		# Meio do antebraço, cilindro deitado na direção do osso
		var child := -1
		for c in sk.get_bone_children(idx):
			child = c
			break
		var end: Vector3 = sk.get_bone_global_rest(child).origin if child >= 0 else rest.origin + rest.basis.y * 0.25
		var dir := (end - rest.origin).normalized()
		var side := dir.cross(Vector3.FORWARD if absf(dir.dot(Vector3.FORWARD)) < 0.95 else Vector3.RIGHT).normalized()
		want = Transform3D(Basis(side, dir, side.cross(dir)), (rest.origin + end) * 0.5)
	var socket := BoneAttachment3D.new()
	socket.name = "Gear_%s" % bone
	socket.bone_name = bone
	sk.add_child(socket)
	_sockets.append(socket)
	var node := Node3D.new()
	node.transform = rest.affine_inverse() * want
	socket.add_child(node)
	return node

func _glow_if_iridescent(item: ForgedItem, root: Node3D) -> void:
	if not item.traits.has(&"iridescente"):
		return
	for c in root.get_children():
		if c is MeshInstance3D:
			var m := (c.material_override as StandardMaterial3D).duplicate() as StandardMaterial3D
			m.emission_enabled = true
			m.emission = Color(0.55, 0.85, 0.95)
			m.emission_energy_multiplier = 0.4
			m.metallic = 0.4
			c.material_override = m

func _mat(c: Color, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m
