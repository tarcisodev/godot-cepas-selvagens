@tool
class_name AstralSanctuarySpawner
extends Node3D

## Gerador Procedural & Ferramenta de Editor (@tool) do Santuário Astral do Mirante.
## 1. Varre a hierarquia do spawn, identifica assets estáticos colocados manualmente
##    (árvores, pedras, arbustos avulsos) e os remove com segurança.
## 2. Constrói o Altar Central e o anel de Pilares Rúnicos com iluminação dinâmica
##    pulsante (OmniLight3D) e aura mágica azul em partículas (GPUParticles3D).
## 3. Distribui densamente a flora e rochas procedurais ao redor do spawn usando
##    FastNoiseLite + MultiMeshInstance3D (zero overhead de draw calls).

const GOLDEN_ANGLE: float = 2.39996323
const MANUAL_ASSET_PATTERNS: PackedStringArray = [
	"tree", "pinheir", "arvore", "rock", "stone", "pedra", "boulder",
	"bush", "arbusto", "grass", "grama", "fern", "samambaia", "flower", "flor", "staticprop"
]

@export_group("Ferramenta de Editor (@tool)")
## Clique no Inspector para varrer assets manuais e regerar o Santuário proceduralmente
@export var rebuild_in_editor: bool = false:
	set(value):
		rebuild_in_editor = false
		if value:
			rebuild_sanctuary()

@export var terrain_provider: Node3D
@export var seed_value: int = 20261025

@export_group("Geometria & Densidade do Spawn")
@export var sanctuary_center: Vector3 = Vector3(82.0, 0.0, -38.0)
@export var inner_plaza_radius: float = 4.2
@export var pillar_ring_radius: float = 6.8
@export var outer_flora_radius: float = 26.0
@export var pillar_count: int = 8
@export var tree_instance_count: int = 48
@export var rock_instance_count: int = 64
@export var foliage_instance_count: int = 320

@export_group("Iluminação & Aura Mágica")
@export var aura_primary_color: Color = Color(0.22, 0.72, 1.0, 1.0)
@export var aura_secondary_color: Color = Color(0.48, 0.88, 1.0, 1.0)
@export var altar_light_energy: float = 2.8
@export var pillar_light_energy: float = 1.45

var _noise: FastNoiseLite
var _altar_light: OmniLight3D
var _altar_core: MeshInstance3D
var _pillar_lights: Array[OmniLight3D] = []
var _pillar_crystals: Array[MeshInstance3D] = []
var _time: float = 0.0
var last_purged_manual_count: int = 0

func _ready() -> void:
	add_to_group("astral_sanctuary")
	if terrain_provider == null and get_parent():
		terrain_provider = get_parent().get_node_or_null("Landscape")
		if terrain_provider == null and get_parent().get_parent():
			terrain_provider = get_parent().get_parent().get_node_or_null("Landscape")
	rebuild_sanctuary()

func _process(delta: float) -> void:
	_time += delta
	# Pulso orgânico do Altar Central (luz + cristal flutuante)
	if _altar_light and is_instance_valid(_altar_light):
		var pulse := 0.85 + 0.25 * sin(_time * 2.2) + 0.08 * sin(_time * 5.7)
		_altar_light.light_energy = altar_light_energy * pulse
	if _altar_core and is_instance_valid(_altar_core):
		_altar_core.position.y = 2.15 + sin(_time * 2.0) * 0.14
		_altar_core.rotate_y(delta * 0.9)

	# Onda defasada nos Pilares Rúnicos (efeito de constelação viva)
	for i in _pillar_lights.size():
		var pl := _pillar_lights[i]
		if pl and is_instance_valid(pl):
			var phase := _time * 2.6 + float(i) * (TAU / float(maxi(1, _pillar_lights.size())))
			pl.light_energy = pillar_light_energy * (0.78 + 0.32 * sin(phase))
		if i < _pillar_crystals.size() and is_instance_valid(_pillar_crystals[i]):
			var cr := _pillar_crystals[i]
			var phase := _time * 2.6 + float(i) * 0.8
			cr.position.y = 2.85 + sin(phase) * 0.09
			cr.rotate_y(delta * 1.1)

## Executa o pipeline completo: limpa assets manuais -> ergue Altar/Pilares -> popula MultiMeshes
func rebuild_sanctuary() -> void:
	_init_noise()
	last_purged_manual_count = purge_manual_static_assets(get_parent() if get_parent() else self)
	_clear_generated_children()
	_build_altar_and_runic_pillars()
	_build_procedural_multimesh_flora()

func _init_noise() -> void:
	_noise = FastNoiseLite.new()
	_noise.seed = seed_value
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 0.065
	_noise.fractal_octaves = 3
	_noise.fractal_gain = 0.5

func _ground_y(wx: float, wz: float) -> float:
	if terrain_provider and terrain_provider.has_method("get_height_at"):
		return float(terrain_provider.call("get_height_at", wx, wz))
	return sanctuary_center.y

## Varre `scan_root` procurando nós estáticos colocados manualmente (árvores, rochas, arbustos)
## dentro ou próximos ao Santuário e os remove para dar lugar à geração procedural.
func purge_manual_static_assets(scan_root: Node) -> int:
	if scan_root == null:
		return 0
	var to_remove: Array[Node] = []
	_collect_manual_assets_recursive(scan_root, to_remove)
	var removed_count := 0
	for n in to_remove:
		if is_instance_valid(n):
			if n.get_parent():
				n.get_parent().remove_child(n)
			n.queue_free()
			removed_count += 1
	return removed_count

func _collect_manual_assets_recursive(node: Node, out_list: Array[Node]) -> void:
	for child in node.get_children():
		if child == self or self.is_ancestor_of(child):
			continue
		if _is_manual_environment_asset(child):
			out_list.append(child)
			continue
		_collect_manual_assets_recursive(child, out_list)

func _is_manual_environment_asset(node: Node) -> bool:
	if not (node is Node3D):
		return false
	if node.is_in_group("manual_env_props"):
		return true
	# Protege sistemas procedurais e interativos
	if node is MultiMeshInstance3D or node is TownNPC or node is Campfire:
		return false
	var n_lower := String(node.name).to_lower()
	if n_lower.begins_with("procedural_") or n_lower.begins_with("waystone_") or n_lower.begins_with("sabio"):
		return false
	for pat in MANUAL_ASSET_PATTERNS:
		if n_lower.contains(pat):
			var n3d := node as Node3D
			# Só substitui se estiver na região do Santuário (ou se for filho direto do hub do spawn)
			if n3d.global_position.distance_to(sanctuary_center) <= outer_flora_radius + 12.0 or n3d.position.length() <= outer_flora_radius + 12.0:
				return true
	return false

func _clear_generated_children() -> void:
	_pillar_lights.clear()
	_pillar_crystals.clear()
	_altar_light = null
	_altar_core = null
	for child in get_children():
		remove_child(child)
		child.queue_free()

# ---------------------------------------------------------------- Altar Central, Pilares Rúnicos, Luzes & Partículas

func _build_altar_and_runic_pillars() -> void:
	var root_altar := Node3D.new()
	root_altar.name = "Procedural_AltarAndPillars"
	add_child(root_altar)

	var stone_mat := StandardMaterial3D.new()
	stone_mat.albedo_color = Color(0.26, 0.28, 0.36)
	stone_mat.roughness = 0.82

	var rune_mat := StandardMaterial3D.new()
	rune_mat.albedo_color = aura_primary_color
	rune_mat.emission_enabled = true
	rune_mat.emission = aura_primary_color
	rune_mat.emission_energy_multiplier = 3.2

	var center_y := _ground_y(sanctuary_center.x, sanctuary_center.z)
	var altar_node := Node3D.new()
	altar_node.name = "AltarCentral"
	altar_node.position = Vector3(sanctuary_center.x, center_y, sanctuary_center.z) - global_position
	root_altar.add_child(altar_node)

	# Degraus octogonais do Altar
	for step_i in 2:
		var step_mesh := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 1.65 - float(step_i) * 0.42
		cyl.bottom_radius = 1.85 - float(step_i) * 0.42
		cyl.height = 0.38
		cyl.radial_segments = 8
		step_mesh.mesh = cyl
		step_mesh.material_override = stone_mat
		step_mesh.position.y = 0.19 + float(step_i) * 0.38
		altar_node.add_child(step_mesh)

	# Anel rúnico emissivo no topo do altar
	var ring_mesh := MeshInstance3D.new()
	var ring_cyl := CylinderMesh.new()
	ring_cyl.top_radius = 1.15
	ring_cyl.bottom_radius = 1.15
	ring_cyl.height = 0.08
	ring_cyl.radial_segments = 12
	ring_mesh.mesh = ring_cyl
	ring_mesh.material_override = rune_mat
	ring_mesh.position.y = 0.78
	altar_node.add_child(ring_mesh)

	# Cristal Astral Flutuante do Altar
	_altar_core = MeshInstance3D.new()
	_altar_core.name = "AltarCrystalCore"
	var prism := SphereMesh.new()
	prism.radius = 0.38
	prism.height = 0.88
	prism.radial_segments = 6
	prism.rings = 3
	_altar_core.mesh = prism
	_altar_core.material_override = rune_mat
	_altar_core.position.y = 2.15
	altar_node.add_child(_altar_core)

	# OmniLight3D dinâmica do Altar
	_altar_light = OmniLight3D.new()
	_altar_light.name = "AltarOmniLight"
	_altar_light.light_color = aura_primary_color
	_altar_light.light_energy = altar_light_energy
	_altar_light.omni_range = 14.0
	_altar_light.omni_attenuation = 1.25
	_altar_light.position.y = 2.25
	altar_node.add_child(_altar_light)

	# GPUParticles3D da Aura Mágica Azul do Altar
	var altar_particles := _create_magic_aura_particles("AltarAuraParticles", 36, Vector3(1.35, 0.3, 1.35), 2.6, 0.14)
	altar_particles.position.y = 0.9
	altar_node.add_child(altar_particles)

	# Anel de Pilares Rúnicos
	for i in pillar_count:
		var angle := TAU * float(i) / float(pillar_count)
		var px := sanctuary_center.x + cos(angle) * pillar_ring_radius
		var pz := sanctuary_center.z + sin(angle) * pillar_ring_radius
		var py := _ground_y(px, pz)

		var p_node := Node3D.new()
		p_node.name = "RunicPillar_%d" % i
		p_node.position = Vector3(px, py, pz) - global_position
		p_node.rotation.y = -angle
		root_altar.add_child(p_node)

		# Corpo do Obelisco Rúnico
		var body_mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.76, 2.65, 0.48)
		body_mesh.mesh = box
		body_mesh.material_override = stone_mat
		body_mesh.position.y = 1.32
		p_node.add_child(body_mesh)

		# Faixa Rúnica Brilhante entalhada no pilar
		var rune_band := MeshInstance3D.new()
		var rbox := BoxMesh.new()
		rbox.size = Vector3(0.80, 0.24, 0.52)
		rune_band.mesh = rbox
		rune_band.material_override = rune_mat
		rune_band.position.y = 1.85
		p_node.add_child(rune_band)

		# Cristal no topo do Pilar
		var crystal := MeshInstance3D.new()
		crystal.name = "RunicCrystal"
		var c_mesh := SphereMesh.new()
		c_mesh.radius = 0.20
		c_mesh.height = 0.48
		c_mesh.radial_segments = 6
		c_mesh.rings = 3
		crystal.mesh = c_mesh
		crystal.material_override = rune_mat
		crystal.position.y = 2.85
		p_node.add_child(crystal)
		_pillar_crystals.append(crystal)

		# OmniLight3D de cada Pilar Rúnico
		var p_light := OmniLight3D.new()
		p_light.name = "PillarOmniLight"
		p_light.light_color = aura_secondary_color
		p_light.light_energy = pillar_light_energy
		p_light.omni_range = 6.5
		p_light.omni_attenuation = 1.4
		p_light.position.y = 2.75
		p_node.add_child(p_light)
		_pillar_lights.append(p_light)

		# GPUParticles3D sutis subindo de cada Pilar Rúnico
		var p_particles := _create_magic_aura_particles("PillarAuraParticles", 14, Vector3(0.45, 0.5, 0.45), 2.0, 0.09)
		p_particles.position.y = 1.9
		p_node.add_child(p_particles)

func _create_magic_aura_particles(node_name: String, amount: int, box_extents: Vector3, lifetime: float, particle_radius: float) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.name = node_name
	particles.amount = amount
	particles.lifetime = lifetime
	particles.preprocess = 0.5
	particles.visibility_aabb = AABB(Vector3(-4, -1, -4), Vector3(8, 7, 8))
	# Desativa emissão apenas no renderer Dummy (headless CI) para evitar avisos de shader
	particles.emitting = DisplayServer.get_name() != "headless"

	var proc := ParticleProcessMaterial.new()
	proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	proc.emission_box_extents = box_extents
	proc.direction = Vector3(0.0, 1.0, 0.0)
	proc.spread = 22.0
	proc.gravity = Vector3(0.0, 0.38, 0.0)
	proc.initial_velocity_min = 0.25
	proc.initial_velocity_max = 0.75
	proc.damping_min = 0.1
	proc.damping_max = 0.3
	proc.scale_min = 0.65
	proc.scale_max = 1.35
	proc.color = aura_primary_color
	particles.process_material = proc

	var pass_mat := StandardMaterial3D.new()
	pass_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pass_mat.vertex_color_use_as_albedo = true
	pass_mat.albedo_color = aura_secondary_color
	pass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pass_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	pass_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES

	var sphere := SphereMesh.new()
	sphere.radius = particle_radius
	sphere.height = particle_radius * 2.0
	sphere.radial_segments = 6
	sphere.rings = 3
	sphere.material = pass_mat
	particles.draw_pass_1 = sphere
	return particles

# ---------------------------------------------------------------- Flora & Rochas Procedurais (MultiMeshInstance3D)

func _build_procedural_multimesh_flora() -> void:
	var flora_root := Node3D.new()
	flora_root.name = "Procedural_FloraAndRocks"
	add_child(flora_root)

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value

	# 1. MultiMesh de Árvores Astrais (Pinheiros Low-Poly com copa azul-esmeralda)
	var tree_mmi := MultiMeshInstance3D.new()
	tree_mmi.name = "Procedural_MultiMesh_Trees"
	var tree_mm := MultiMesh.new()
	tree_mm.transform_format = MultiMesh.TRANSFORM_3D
	tree_mm.use_colors = true
	tree_mm.mesh = _build_lowpoly_astral_tree_mesh()
	tree_mm.instance_count = tree_instance_count
	tree_mmi.multimesh = tree_mm
	flora_root.add_child(tree_mmi)

	var placed_trees := 0
	var attempt := 0
	while placed_trees < tree_instance_count and attempt < tree_instance_count * 6:
		attempt += 1
		var t_ratio := float(attempt) / float(tree_instance_count * 2)
		var r := lerpf(pillar_ring_radius + 2.4, outer_flora_radius, clampf(sqrt(fmod(t_ratio * 0.618, 1.0)), 0.0, 1.0))
		var theta := float(attempt) * GOLDEN_ANGLE + _noise.get_noise_2d(float(attempt) * 3.1, 0.0) * 0.8
		var wx := sanctuary_center.x + cos(theta) * r
		var wz := sanctuary_center.z + sin(theta) * r
		var n_val := _noise.get_noise_2d(wx, wz)
		if n_val < -0.22:
			continue
		var wy := _ground_y(wx, wz)
		var sc := rng.randf_range(0.85, 1.45) * (1.0 + maxf(0.0, n_val) * 0.35)
		var basis := Basis.from_euler(Vector3(rng.randf_range(-0.05, 0.05), rng.randf() * TAU, rng.randf_range(-0.05, 0.05))).scaled(Vector3.ONE * sc)
		var local_pos := Vector3(wx, wy, wz) - global_position
		tree_mm.set_instance_transform(placed_trees, Transform3D(basis, local_pos))
		var tint := Color(0.20, 0.58, 0.52).lerp(Color(0.28, 0.78, 0.92), clampf(n_val + 0.5, 0.0, 1.0))
		tree_mm.set_instance_color(placed_trees, tint)
		placed_trees += 1
	tree_mm.visible_instance_count = placed_trees

	# 2. MultiMesh de Rochas Rúnicas Low-Poly
	var rock_mmi := MultiMeshInstance3D.new()
	rock_mmi.name = "Procedural_MultiMesh_Rocks"
	var rock_mm := MultiMesh.new()
	rock_mm.transform_format = MultiMesh.TRANSFORM_3D
	rock_mm.use_colors = true
	rock_mm.mesh = _build_lowpoly_rock_mesh()
	rock_mm.instance_count = rock_instance_count
	rock_mmi.multimesh = rock_mm
	flora_root.add_child(rock_mmi)

	for i in rock_instance_count:
		var u := float(i + 1) / float(rock_instance_count)
		var r := lerpf(inner_plaza_radius + 1.2, outer_flora_radius, sqrt(u))
		var theta := float(i) * GOLDEN_ANGLE * 1.37
		var wx := sanctuary_center.x + cos(theta) * r + rng.randf_range(-1.2, 1.2)
		var wz := sanctuary_center.z + sin(theta) * r + rng.randf_range(-1.2, 1.2)
		var wy := _ground_y(wx, wz)
		var sc := Vector3(rng.randf_range(0.55, 1.35), rng.randf_range(0.45, 1.15), rng.randf_range(0.55, 1.35))
		var basis := Basis.from_euler(Vector3(rng.randf_range(-0.2, 0.2), rng.randf() * TAU, rng.randf_range(-0.2, 0.2))).scaled(sc)
		rock_mm.set_instance_transform(i, Transform3D(basis, Vector3(wx, wy + sc.y * 0.18, wz) - global_position))
		var shade := rng.randf_range(0.26, 0.42)
		rock_mm.set_instance_color(i, Color(shade, shade * 1.04, shade * 1.18))

	# 3. MultiMesh de Vegetação Rasteira Densa & Samambaias Bioluminescentes
	var fol_mmi := MultiMeshInstance3D.new()
	fol_mmi.name = "Procedural_MultiMesh_LushFoliage"
	var fol_mm := MultiMesh.new()
	fol_mm.transform_format = MultiMesh.TRANSFORM_3D
	fol_mm.use_colors = true
	fol_mm.mesh = _build_lowpoly_foliage_tuft_mesh()
	fol_mm.instance_count = foliage_instance_count
	fol_mmi.multimesh = fol_mm
	flora_root.add_child(fol_mmi)

	for i in foliage_instance_count:
		var u := float(i + 1) / float(foliage_instance_count)
		var r := lerpf(inner_plaza_radius * 0.85, outer_flora_radius, pow(u, 0.62))
		var theta := float(i) * GOLDEN_ANGLE
		var jitter := _noise.get_noise_2d(float(i) * 1.7, float(i) * 0.9) * 1.8
		var wx := sanctuary_center.x + cos(theta) * (r + jitter)
		var wz := sanctuary_center.z + sin(theta) * (r + jitter)
		var wy := _ground_y(wx, wz)
		var sc := rng.randf_range(0.65, 1.45)
		var basis := Basis.from_euler(Vector3(0.0, rng.randf() * TAU, 0.0)).scaled(Vector3(sc, sc * rng.randf_range(0.8, 1.3), sc))
		fol_mm.set_instance_transform(i, Transform3D(basis, Vector3(wx, wy, wz) - global_position))
		var glow_mix := clampf((_noise.get_noise_2d(wx * 1.5, wz * 1.5) + 0.6) * 0.65, 0.0, 1.0)
		var grass_col := Color(0.20, 0.52, 0.36).lerp(Color(0.25, 0.82, 0.96), glow_mix)
		fol_mm.set_instance_color(i, grass_col)

func _build_lowpoly_astral_tree_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.82
	mat.emission_enabled = true
	mat.emission = Color(0.08, 0.24, 0.32)
	mat.emission_energy_multiplier = 0.55

	# Copa em 2 cones low-poly sobrepostos (6 lados)
	for tier in 2:
		var y0 := 1.1 + float(tier) * 1.15
		var y1 := y0 + 1.85
		var rad := 1.25 - float(tier) * 0.32
		var top := Vector3(0.0, y1, 0.0)
		for s in 6:
			var a0 := TAU * float(s) / 6.0
			var a1 := TAU * float(s + 1) / 6.0
			var p0 := Vector3(cos(a0) * rad, y0, sin(a0) * rad)
			var p1 := Vector3(cos(a1) * rad, y0, sin(a1) * rad)
			var n := (p1 - p0).cross(top - p0).normalized()
			st.set_normal(n)
			st.add_vertex(p0)
			st.set_normal(n)
			st.add_vertex(p1)
			st.set_normal(n)
			st.add_vertex(top)
	var mesh := st.commit()
	mesh.surface_set_material(0, mat)
	return mesh

func _build_lowpoly_rock_mesh() -> Mesh:
	var sm := SphereMesh.new()
	sm.radius = 0.58
	sm.height = 0.92
	sm.radial_segments = 6
	sm.rings = 3
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.92
	sm.material = mat
	return sm

func _build_lowpoly_foliage_tuft_mesh() -> Mesh:
	var cm := CylinderMesh.new()
	cm.top_radius = 0.04
	cm.bottom_radius = 0.36
	cm.height = 0.55
	cm.radial_segments = 5
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.78
	mat.emission_enabled = true
	mat.emission = Color(0.08, 0.28, 0.36)
	mat.emission_energy_multiplier = 0.45
	cm.material = mat
	return cm
