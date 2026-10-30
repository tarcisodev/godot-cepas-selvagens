class_name ColossoSkeleton
extends Node3D

## Esqueleto fossilizado do Colosso (B38, GDD-17 §1): espinha com vértebras e espinhos,
## 12 pares de costelas, bacia, cauda enrolada em volta do portão, quatro patas-torre e o
## crânio com chifres e órbitas de âmbar. Todo osso é tubo gerado em código e cai em poucas
## malhas (uma por material). Construído no referencial do Colosso (ver CostelariaLayout):
## o pai já está girado, então aqui x = lx e z = lz. Colisão só onde o osso toca o chão.

const _Layout = preload("res://scripts/costelaria/costelaria_layout.gd")

## Altura do chão no ponto local (lx, lz), relativa a este nó
var ground: Callable

var bone_material: StandardMaterial3D
## Órbitas, veios e o que acende de noite (o hub controla a emissão)
var amber_material: StandardMaterial3D

var _bone := SurfaceTool.new()
var _body: StaticBody3D

func _ready() -> void:
	bone_material = StandardMaterial3D.new()
	bone_material.albedo_color = Color(0.84, 0.79, 0.66)
	bone_material.roughness = 0.88
	bone_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	amber_material = StandardMaterial3D.new()
	amber_material.albedo_color = Color(0.95, 0.55, 0.12)
	amber_material.emission_enabled = true
	amber_material.emission = Color(1.0, 0.55, 0.12)
	amber_material.emission_energy_multiplier = 0.4
	amber_material.roughness = 0.25

	_body = StaticBody3D.new()
	_body.name = "ColisaoDoEsqueleto"
	add_child(_body)

	_bone.begin(Mesh.PRIMITIVE_TRIANGLES)
	_build_spine()
	_build_ribs()
	_build_pelvis_and_tail()
	_build_legs()
	_build_skull()
	var mesh := MeshInstance3D.new()
	mesh.name = "Ossos"
	mesh.mesh = _bone.commit()
	mesh.material_override = bone_material
	add_child(mesh)

# ---------------------------------------------------------------- partes

func _build_spine() -> void:
	# Vértebras: raio pulsando a cada metro, do pescoço até a bacia
	var pts := PackedVector3Array()
	var radii := PackedFloat32Array()
	var lz := -47.0
	var i := 0
	while lz <= 32.0:
		pts.append(Vector3(0.0, _Layout.spine_height(lz), lz))
		radii.append(1.2 if i % 2 == 0 else 0.85)
		lz += 1.0
		i += 1
	add_tube(_bone, pts, radii, 10)
	# Espinhos dorsais
	lz = -36.0
	while lz <= 30.0:
		var h := _Layout.spine_height(lz)
		var tall := 1.4 + 0.8 * sin((lz + 36.0) / 66.0 * PI)
		add_tube(_bone, PackedVector3Array([Vector3(0.0, h + 0.6, lz), Vector3(0.0, h + 0.6 + tall * 0.6, lz + 0.4), Vector3(0.0, h + 0.6 + tall, lz + 1.1)]),
			PackedFloat32Array([0.4, 0.25, 0.06]), 6)
		lz += 2.4

func _build_ribs() -> void:
	for i in _Layout.RIB_COUNT:
		var rz := _Layout.rib_z(i)
		var h := _Layout.spine_height(rz)
		# As costelas do meio (sobre o Coração) são as mais largas
		var mid := 1.0 - absf(float(i) - (_Layout.RIB_COUNT - 1) * 0.45) / float(_Layout.RIB_COUNT)
		var foot_x := _Layout.RIB_FOOT_X * lerpf(0.82, 1.0, mid)
		for side in [-1.0, 1.0]:
			var p0 := Vector3(side * 0.9, h - 0.3, rz)
			var p1 := Vector3(side * (foot_x + 3.5), h * 0.95, rz + 1.0)
			var p2 := Vector3(side * foot_x, _g(side * foot_x, rz + 1.6) - 0.4, rz + 1.6)
			var pts := PackedVector3Array()
			var radii := PackedFloat32Array()
			for s in 15:
				var t := float(s) / 14.0
				pts.append(p0.lerp(p1, t).lerp(p1.lerp(p2, t), t))
				radii.append(lerpf(0.6, 0.42, t))
			add_tube(_bone, pts, radii, 8)
			_collider_capsule(Vector3(side * foot_x, _g(side * foot_x, rz + 1.6) + 1.5, rz + 1.6), 0.6, 3.2)

func _build_pelvis_and_tail() -> void:
	# Duas asas da bacia saindo da espinha e voltando nela
	for side in [-1.0, 1.0]:
		add_tube(_bone, PackedVector3Array([
			Vector3(0.0, 8.6, 20.0), Vector3(side * 4.5, 10.0, 21.5), Vector3(side * 8.0, 8.5, 24.5),
			Vector3(side * 7.5, 5.8, 28.0), Vector3(side * 3.5, 6.2, 30.0), Vector3(0.0, 7.0, 31.0),
		]), PackedFloat32Array([0.9, 0.95, 1.0, 0.9, 0.75, 0.8]), 10)
	# Cauda: desce da bacia e enrola para o lado leste do portão, rente ao chão
	var tail := [Vector3(0.0, 7.0, 32.0), Vector3(1.6, 5.8, 37.0), Vector3(5.0, 4.0, 43.0), Vector3(10.0, 2.4, 48.0),
		Vector3(15.5, 1.3, 51.5), Vector3(20.5, 0.8, 53.0), Vector3(24.5, 0.6, 52.0), Vector3(27.0, 0.5, 49.5)]
	var pts := PackedVector3Array()
	var radii := PackedFloat32Array()
	for j in tail.size():
		var p: Vector3 = tail[j]
		p.y += _g(p.x, p.z) * clampf(1.0 - p.y / 4.0, 0.0, 1.0)
		pts.append(p)
		radii.append(lerpf(1.1, 0.3, float(j) / float(tail.size() - 1)))
		if p.y - _g(p.x, p.z) < 2.6:
			_collider_capsule(p, radii[j] + 0.15, 2.0)
	add_tube(_bone, pts, radii, 10)

func _build_legs() -> void:
	for leg in _Layout.LEGS:
		var front: bool = leg.y < 0.0
		var side := signf(leg.x)
		var top := Vector3(side * 4.0, _Layout.spine_height(leg.y) - 2.0, leg.y + (0.0 if front else -2.0))
		var joint := Vector3(side * (absf(leg.x) - 4.5), 6.5, leg.y + (1.5 if front else 3.0))
		var gy: float = _g(leg.x, leg.y)
		var foot := Vector3(leg.x, gy + 0.3, leg.y)
		add_tube(_bone, PackedVector3Array([top, top.lerp(joint, 0.5) + Vector3(0, 0.6, 0), joint]), PackedFloat32Array([1.3, 1.1, 0.95]), 10)
		add_tube(_bone, PackedVector3Array([joint, joint.lerp(foot, 0.5), foot]), PackedFloat32Array([0.95, 0.85, 1.0]), 10)
		_collider_capsule(Vector3(foot.x, gy + 2.0, foot.z), 1.1, 4.0)
		# Três garras viradas para fora do corpo
		for c in 3:
			var dir := Vector3(side * 0.6, 0.0, (-1.0 if front else 1.0) * 0.3 + (float(c) - 1.0) * 0.55).normalized()
			add_tube(_bone, PackedVector3Array([foot + dir * 0.6, foot + dir * 1.8 + Vector3(0, 0.15, 0), foot + dir * 2.6 + Vector3(0, -0.35, 0)]),
				PackedFloat32Array([0.32, 0.22, 0.05]), 6)

func _build_skull() -> void:
	var c := Vector3(0.0, 5.6, _Layout.SKULL.y - 3.0)
	var cranium := MeshInstance3D.new()
	cranium.name = "Cranio"
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	cranium.mesh = sphere
	cranium.scale = Vector3(5.4, 4.2, 7.2)
	cranium.position = c
	cranium.material_override = bone_material
	add_child(cranium)
	# Focinho e mandíbula apoiada no chão
	add_tube(_bone, PackedVector3Array([c + Vector3(0, -0.5, -4.0), c + Vector3(0, -1.2, -7.5), c + Vector3(0, -1.8, -10.0)]), PackedFloat32Array([3.0, 2.2, 1.4]), 12)
	for side in [-1.0, 1.0]:
		var jaw_end := Vector3(side * 1.8, _g(side * 1.8, c.z - 10.5) + 0.5, c.z - 10.5)
		add_tube(_bone, PackedVector3Array([c + Vector3(side * 3.6, -2.4, 2.0), c + Vector3(side * 3.0, -4.0, -4.0), jaw_end]), PackedFloat32Array([0.8, 0.7, 0.5]), 8)
		# Dentes na mandíbula
		for t in 5:
			var base := (c + Vector3(side * 3.0, -4.0, -4.0)).lerp(jaw_end, 0.15 + t * 0.17)
			add_tube(_bone, PackedVector3Array([base, base + Vector3(-side * 0.1, 0.8, 0), base + Vector3(-side * 0.15, 1.3, 0.05)]), PackedFloat32Array([0.22, 0.14, 0.03]), 5)
		# Chifres curvados para trás e para cima
		add_tube(_bone, PackedVector3Array([c + Vector3(side * 3.2, 2.8, 1.5), c + Vector3(side * 5.5, 5.2, 4.5), c + Vector3(side * 6.4, 7.6, 9.5), c + Vector3(side * 5.6, 9.0, 13.5)]),
			PackedFloat32Array([0.95, 0.7, 0.4, 0.12]), 10)
		# Órbitas de âmbar (acendem de noite)
		var eye := MeshInstance3D.new()
		eye.name = "Orbita" + ("E" if side < 0 else "D")
		var orb := SphereMesh.new()
		orb.radius = 1.0
		orb.height = 2.0
		eye.mesh = orb
		eye.position = c + Vector3(side * 3.9, 1.1, -3.2)
		eye.material_override = amber_material
		add_child(eye)
	var shape := BoxShape3D.new()
	shape.size = Vector3(10.0, 8.0, 16.0)
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position = c + Vector3(0, -1.5, -2.5)
	_body.add_child(col)

func _collider_capsule(center: Vector3, radius: float, height: float) -> void:
	var shape := CapsuleShape3D.new()
	shape.radius = radius
	shape.height = maxf(height, radius * 2.0)
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position = center
	_body.add_child(col)

# ---------------------------------------------------------------- tubo

## Tubo pela polilinha `pts` com raio por ponto; normais suaves, sem tampas (as pontas somem
## no chão ou dentro de outro osso; o material não tem face de trás para cortar)
static func add_tube(st: SurfaceTool, pts: PackedVector3Array, radii: PackedFloat32Array, sides: int = 8) -> void:
	var n := pts.size()
	if n < 2:
		return
	var rings: Array = []
	# Quadro transportado ao longo do tubo: o lado de cada anel vem do anterior, então o tubo
	# não torce quando o osso fica na vertical
	var side := Vector3.ZERO
	for i in n:
		var tangent: Vector3
		if i == 0:
			tangent = pts[1] - pts[0]
		elif i == n - 1:
			tangent = pts[n - 1] - pts[n - 2]
		else:
			tangent = pts[i + 1] - pts[i - 1]
		tangent = tangent.normalized()
		if i == 0:
			var up := Vector3.UP if absf(tangent.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
			side = tangent.cross(up).normalized()
		else:
			side = (side - tangent * side.dot(tangent)).normalized()
		var normal := side.cross(tangent).normalized()
		var ring: Array = []
		for s in sides:
			var a := TAU * float(s) / float(sides)
			var dir := side * cos(a) + normal * sin(a)
			ring.append([pts[i] + dir * radii[i], dir])
		rings.append(ring)
	for i in n - 1:
		for s in sides:
			var s2 := (s + 1) % sides
			var quad := [rings[i][s], rings[i + 1][s], rings[i + 1][s2], rings[i][s], rings[i + 1][s2], rings[i][s2]]
			for v in quad:
				st.set_normal(v[1])
				st.add_vertex(v[0])

func _g(x: float, z: float) -> float:
	return float(ground.call(x, z)) if ground.is_valid() else 0.0
