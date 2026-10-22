class_name PlantBody
extends Node3D

## Planta procedural (GDD-09 §3) montada a partir do PlantDNA. Todas as partes viram UMA
## malha com cor por vértice (1 chamada de desenho por planta), para caber centenas no vale.
## Árvores ganham colisão no tronco; o cogumelo-lume tem chapéu que brilha à noite.
## Ciclo de vida (GDD-10 §4): semente → broto → jovem → adulta → florida → com fruto → (semeia)
## → volta a adulta; cresce com água, nutriente e luz da célula de solo (Ecology); definha sem
## isso e morre de velhice ou de penúria, devolvendo nutriente.

enum Stage { SEMENTE, BROTO, JOVEM, ADULTA, FLORIDA, FRUTO }

## Dias de jogo em cada estágio [semente, broto, jovem, adulta→flor, florida, fruto] e vida total
const TIMES: Dictionary = {
	PlantDNA.Kind.ARVORE: [0.3, 0.8, 2.0, 1.5, 0.6, 0.8, 20.0],
	PlantDNA.Kind.ARBUSTO: [0.2, 0.5, 1.0, 0.8, 0.5, 0.6, 12.0],
	PlantDNA.Kind.CEPA: [0.1, 0.25, 0.4, 0.3, 0.3, 0.3, 5.0],
	PlantDNA.Kind.COGUMELO: [0.1, 0.15, 0.2, 0.4, 0.2, 0.2, 3.0],
}
## Escala visual por estágio
const STAGE_SCALE: Array[float] = [0.0, 0.18, 0.5, 1.0, 1.0, 1.0]
## Quanto aguenta sem água/nutriente antes de morrer (dias)
const STARVE_DAYS: float = 1.5

@export var dna: PlantDNA
@export var stage: Stage = Stage.ADULTA

var age: float = 0.0
var progress: float = 0.0
var stress: float = 0.0

var _st: SurfaceTool
var _rng := RandomNumberGenerator.new()
var _crown: Array[Vector3] = []
static var _material: StandardMaterial3D
static var _glow_material: StandardMaterial3D

func _ready() -> void:
	add_to_group("plants")
	if dna == null:
		dna = PlantDNA.randomized(PlantDNA.Kind.ARVORE, 1)
	build()

func lifespan() -> float:
	return TIMES[dna.kind][6] * (1.2 if dna.mutant else 1.0)

## Um passo de vida: `cell` = {"moisture", "nutrients"} da célula; `light` = é dia.
## Devolve o que a planta tirou do solo e o que aconteceu: {"water", "food", "event"},
## event = "", "grew", "seeds" ou "died".
func life_tick(days: float, cell: Dictionary, light: bool) -> Dictionary:
	age += days
	var out := {"water": 0.0, "food": 0.0, "event": ""}
	var need_w := 0.3 if dna.kind == PlantDNA.Kind.COGUMELO else 0.2
	var ok: bool = cell.get("moisture", 0.0) >= need_w and cell.get("nutrients", 0.0) >= 0.12
	if dna.kind == PlantDNA.Kind.COGUMELO:
		light = true # cogumelo não precisa de sol
	if age > lifespan() or stress > STARVE_DAYS:
		out.event = "died"
		return out
	if not light:
		return out
	if not ok:
		stress += days
		return out
	stress = maxf(0.0, stress - days * 0.5)
	var growing := stage < Stage.ADULTA
	out.water = days * (0.25 if growing else 0.12)
	out.food = days * (0.12 if growing else 0.05)
	progress += days / float(TIMES[dna.kind][stage])
	if progress >= 1.0:
		progress = 0.0
		if stage == Stage.FRUTO:
			stage = Stage.ADULTA
			out.event = "seeds"
		else:
			stage = (stage + 1) as Stage
			out.event = "grew"
		build()
	return out

func build() -> void:
	for c in get_children():
		c.free()
	scale = Vector3.ONE * maxf(STAGE_SCALE[stage], 0.001)
	if stage == Stage.SEMENTE:
		return
	_rng.seed = dna.dna_seed
	_crown.clear()
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
	# Plantas baixas e novas: a sombra quase não aparece e dobra o custo de desenho
	if dna.kind == PlantDNA.Kind.CEPA or dna.kind == PlantDNA.Kind.COGUMELO or stage < Stage.ADULTA:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	if dna.mutant and stage >= Stage.JOVEM:
		_add_mutant_glow()

## Brilho de esporos em volta da planta mutante (o "raro" que se vê de longe)
func _add_mutant_glow() -> void:
	if _glow_material == null:
		_glow_material = StandardMaterial3D.new()
		_glow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_glow_material.vertex_color_use_as_albedo = true
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var height := 4.0 if dna.kind == PlantDNA.Kind.ARVORE else 1.2
	var sm := SphereMesh.new()
	sm.radius = 0.06
	sm.height = 0.12
	sm.radial_segments = 6
	sm.rings = 3
	var arrays := sm.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for i in 10:
		var p := Vector3(_rng.randf_range(-0.8, 0.8), _rng.randf_range(0.3, 1.0) * height, _rng.randf_range(-0.8, 0.8))
		for idx in indices:
			st.set_color(dna.flower_color.lightened(0.3))
			st.add_vertex(verts[idx] + p)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _glow_material
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
		var blob_size := h * _rng.randf_range(0.2, 0.28)
		_add_blob(end + Vector3(0, 0.25 * f, 0), Vector3.ONE * blob_size, _leaf_variant())
		_crown.append(end + Vector3(0, 0.25 * f, 0))
		_crown.append(Vector3(blob_size * 0.5, 0, 0))
	_add_blob(Vector3(0, h * 0.85, 0), Vector3(h * 0.38, h * 0.32, h * 0.38), _leaf_variant())
	_crown.append(Vector3(0, h * 0.85, 0))
	_crown.append(Vector3(h * 0.19, 0, 0))
	_add_blossoms_or_fruit(0.09 * f, 0.13 * f)
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
		var blob := _rng.randf_range(0.55, 0.8) * f
		_add_blob(p, Vector3.ONE * blob, _leaf_variant())
		_crown.append(p)
		_crown.append(Vector3(blob * 0.5, 0, 0))
	_add_blossoms_or_fruit(0.07 * f, 0.08 * f)

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
	var bud := dna.leaf_color.lerp(dna.flower_color, 0.6) if stage >= Stage.FLORIDA else dna.leaf_color.darkened(0.1)
	_add_blob(Vector3(0, h + 0.08 * f, 0), Vector3(0.2, 0.34, 0.2) * f, bud)

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

## Florida: flores na copa; com fruto: frutos pendurados
func _add_blossoms_or_fruit(flower_size: float, fruit_size: float) -> void:
	if stage < Stage.FLORIDA or _crown.is_empty():
		return
	var fruit_color := Color(0.75, 0.12, 0.2).lerp(dna.flower_color, 0.25)
	for i in 14:
		var k := (_rng.randi() % (_crown.size() / 2)) * 2
		var c: Vector3 = _crown[k]
		var r: float = _crown[k + 1].x
		var dir := Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-0.6, 1.0), _rng.randf_range(-1, 1)).normalized()
		var p := c + dir * r * 0.95
		if stage == Stage.FLORIDA:
			_add_flower(p, flower_size)
		else:
			_add_sphere(Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * fruit_size), p - Vector3(0, fruit_size * 0.5, 0)), fruit_color)

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
