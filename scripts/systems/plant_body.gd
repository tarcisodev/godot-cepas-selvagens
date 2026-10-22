class_name PlantBody
extends Node3D

## Planta procedural (GDD-09 §3) montada a partir do PlantDNA. Todas as partes viram UMA
## malha com cor por vértice (1 chamada de desenho por planta), para caber centenas no vale.
## Árvores ganham colisão no tronco; o cogumelo-lume tem chapéu que brilha à noite.

@export var dna: PlantDNA

var _st: SurfaceTool
var _rng := RandomNumberGenerator.new()
static var _material: StandardMaterial3D

func _ready() -> void:
	if dna == null:
		dna = PlantDNA.randomized(PlantDNA.Kind.ARVORE, 1)
	build()

func build() -> void:
	for c in get_children():
		c.free()
	_rng.seed = dna.dna_seed
	_st = SurfaceTool.new()
	_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	match dna.kind:
		PlantDNA.Kind.ARVORE:
			_build_tree()
		PlantDNA.Kind.ARBUSTO:
			_build_bush()
		PlantDNA.Kind.CEPA:
			_build_cepa()
		PlantDNA.Kind.COGUMELO:
			_build_mushrooms()
	var mi := MeshInstance3D.new()
	mi.mesh = _st.commit()
	mi.material_override = _shared_material()
	mi.visibility_range_end = 110.0
	# Plantas baixas: a sombra quase não aparece e dobra o custo de desenho
	if dna.kind == PlantDNA.Kind.CEPA or dna.kind == PlantDNA.Kind.COGUMELO:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

static func _shared_material() -> StandardMaterial3D:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.vertex_color_use_as_albedo = true
		_material.vertex_color_is_srgb = true
		_material.roughness = 0.9
	return _material

# ---------------------------------------------------------------- tipos

func _build_tree() -> void:
	var f := dna.size_factor()
	var h := (4.5 + _rng.randf() * 1.5) * f
	var trunk_r := 0.2 * f
	_add_cylinder(Vector3.ZERO, Vector3(0, h * 0.62, 0), trunk_r, trunk_r * 0.7, dna.trunk_color)
	var crown_y := h * 0.62
	for i in dna.branches:
		var a := TAU * i / dna.branches + _rng.randf() * 0.4
		var start := Vector3(0, crown_y * _rng.randf_range(0.7, 0.95), 0)
		var dir := Vector3(cos(a), _rng.randf_range(0.5, 0.9), sin(a)).normalized()
		var end := start + dir * h * _rng.randf_range(0.28, 0.4)
		_add_cylinder(start, end, trunk_r * 0.45, trunk_r * 0.25, dna.trunk_color)
		_add_blob(end + Vector3(0, 0.25 * f, 0), Vector3.ONE * h * _rng.randf_range(0.2, 0.28), _leaf_variant())
	_add_blob(Vector3(0, h * 0.85, 0), Vector3(h * 0.38, h * 0.32, h * 0.38), _leaf_variant())
	# Colisão só no tronco
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = trunk_r
	shape.height = h * 0.62
	col.shape = shape
	col.position.y = h * 0.31
	body.add_child(col)
	add_child(body)

func _build_bush() -> void:
	var f := dna.size_factor()
	var n := _rng.randi_range(3, 5)
	for i in n:
		var a := TAU * i / n
		var p := Vector3(cos(a) * 0.35 * f, 0.35 * f, sin(a) * 0.35 * f)
		_add_blob(p, Vector3.ONE * _rng.randf_range(0.55, 0.8) * f, _leaf_variant())
	for i in 9:
		var a := _rng.randf() * TAU
		var up := _rng.randf_range(0.2, 0.9)
		var p := Vector3(cos(a) * 0.55 * f, (0.3 + up * 0.5) * f, sin(a) * 0.55 * f)
		_add_flower(p, 0.1 * f)

func _build_cepa() -> void:
	var f := dna.size_factor()
	var h := (1.5 + _rng.randf() * 0.6) * f
	_add_cylinder(Vector3.ZERO, Vector3(0, h, 0), 0.05 * f, 0.03 * f, dna.leaf_color.darkened(0.3))
	var levels := 4
	for lv in levels:
		var y := h * (0.25 + 0.7 * lv / float(levels))
		var sc := (1.0 - lv * 0.18) * f
		for side in 2:
			var a := lv * 1.1 + side * PI
			_add_fan_leaf(Vector3(0, y, 0), a, 0.55 * sc)
	# Botão no topo, com a cor da "flor" do gene
	_add_blob(Vector3(0, h + 0.08 * f, 0), Vector3(0.2, 0.34, 0.2) * f, dna.leaf_color.lerp(dna.flower_color, 0.35))

## Folha em leque (5–7 folíolos), a marca visual da Cepa Selvagem
func _add_fan_leaf(origin: Vector3, yaw: float, length: float) -> void:
	var count := 7
	for i in count:
		var spread := lerpf(-1.1, 1.1, i / float(count - 1))
		var l := length * (1.0 - absf(spread) * 0.35)
		var dir := Basis(Vector3.UP, yaw) * Vector3(sin(spread) * 0.9, 0.35 + cos(spread) * 0.25, cos(spread)).normalized()
		var center := origin + dir * l * 0.55
		var rot := Basis.looking_at(dir, Vector3.UP)
		_add_sphere(Transform3D(rot.scaled(Vector3(0.18 * l, 0.03, 1.0 * l)), center), dna.leaf_color.lerp(Color(0.1, 0.25, 0.1), _rng.randf() * 0.2))

func _build_mushrooms() -> void:
	var f := dna.size_factor()
	var n := _rng.randi_range(3, 5)
	var caps := Node3D.new()
	add_child(caps)
	for i in n:
		var a := _rng.randf() * TAU
		var r := _rng.randf_range(0.0, 0.3) * f
		var base := Vector3(cos(a) * r, 0, sin(a) * r)
		var h := _rng.randf_range(0.18, 0.4) * f
		_add_cylinder(base, base + Vector3(0, h, 0), 0.04 * f, 0.035 * f, dna.leaf_color)
		# Chapéu em malha própria, emissiva, para brilhar no escuro
		var cap := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.12 * f * (h / (0.3 * f))
		sm.height = sm.radius
		sm.is_hemisphere = true
		sm.radial_segments = 10
		sm.rings = 4
		cap.mesh = sm
		cap.position = base + Vector3(0, h, 0)
		var m := StandardMaterial3D.new()
		m.albedo_color = dna.flower_color
		m.emission_enabled = true
		m.emission = dna.flower_color
		m.emission_energy_multiplier = 1.2
		cap.material_override = m
		caps.add_child(cap)

# ---------------------------------------------------------------- malha

func _leaf_variant() -> Color:
	return dna.leaf_color.lerp(Color(0.15, 0.3, 0.12) if _rng.randf() < 0.5 else Color(0.55, 0.7, 0.3), _rng.randf() * 0.18)

func _add_flower(p: Vector3, size: float) -> void:
	for i in dna.petals:
		var a := TAU * i / dna.petals
		var off := Vector3(cos(a), 0, sin(a)) * size * 0.6
		_add_sphere(Transform3D(Basis.IDENTITY.scaled(Vector3(size * 0.6, size * 0.25, size * 0.6)), p + off), dna.flower_color)
	_add_sphere(Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * size * 0.45), p + Vector3(0, size * 0.1, 0)), Color(0.98, 0.85, 0.3))

func _add_blob(center: Vector3, size: Vector3, color: Color) -> void:
	_add_sphere(Transform3D(Basis.IDENTITY.scaled(size), center), color)

func _add_sphere(xform: Transform3D, color: Color) -> void:
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 8
	sm.rings = 5
	_append(sm, xform, color)

func _add_cylinder(a: Vector3, b: Vector3, r_bottom: float, r_top: float, color: Color) -> void:
	var cm := CylinderMesh.new()
	cm.bottom_radius = r_bottom
	cm.top_radius = r_top
	cm.height = a.distance_to(b)
	cm.radial_segments = 7
	cm.rings = 1
	var up := (b - a).normalized()
	var side := up.cross(Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.95 else Vector3.RIGHT).normalized()
	var rot := Basis(side, up, side.cross(up))
	_append(cm, Transform3D(rot, (a + b) * 0.5), color)

func _append(mesh: PrimitiveMesh, xform: Transform3D, color: Color) -> void:
	var arrays := mesh.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var nb := xform.basis.inverse().transposed()
	for idx in indices:
		_st.set_color(color)
		_st.set_normal((nb * normals[idx]).normalized())
		_st.add_vertex(xform * verts[idx])
