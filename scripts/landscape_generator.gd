@tool
extends MeshInstance3D
class_name LandscapeGenerator

## Relevo com Pico Majestoso, Penhasco, Cachoeira e Vale
# Gera o relevo com montanha imponente, escarpa rochosa onde a água despenca,
# bacia da lagoa e rio sinuoso pelo vale.

const RiverClass = preload("res://scripts/river_system.gd")
const RIVER_SHADER: Shader = preload("res://materials/river_water.gdshader")
const WATERFALL_SHADER: Shader = preload("res://materials/waterfall.gdshader")

@export var terrain_size: Vector2 = Vector2(WorldBounds.HALF * 2.0, WorldBounds.HALF * 2.0)
@export var subdivisions: Vector2i = Vector2i(300, 300)
@export var max_height: float = 7.5
@export var noise_frequency: float = 0.016

# Cores do bioma e relevo
@export var peak_rock_color: Color = Color(0.34, 0.33, 0.32)    # Rocha nua do pico
@export var cliff_rock_color: Color = Color(0.26, 0.26, 0.28)   # Paredão da cachoeira
@export var lush_bank_color: Color = Color(0.27, 0.44, 0.22)    # Margens úmidas da mata ciliar
@export var grass_color: Color = Color(0.32, 0.46, 0.28)        # Verde musgo natural
@export var earth_color: Color = Color(0.48, 0.38, 0.28)        # Terra avermelhada nos cumes secos
@export var riverbed_color: Color = Color(0.22, 0.21, 0.18)     # Seixos e cascalho do fundo

var noise: FastNoiseLite
## Alturas da grade do terreno (malha e colisão)
var _heights := PackedFloat32Array()

func _ready() -> void:
	_init_noise()
	generate_landscape()

func _init_noise() -> void:
	if noise == null:
		noise = FastNoiseLite.new()
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		noise.frequency = noise_frequency
		noise.fractal_octaves = 4
		noise.fractal_gain = 0.45

## Função pública para consultar a altura exata da superfície do terreno
func get_height_at(x: float, z: float) -> float:
	_init_noise()
	var half_size: Vector2 = terrain_size * 0.5
	if abs(x) > half_size.x or abs(z) > half_size.y:
		return 0.0

	# 1. Base procedural suave
	var dist_from_center: float = Vector2(x, z).length()
	var center_clearing_factor: float = clamp((dist_from_center - 6.0) / 22.0, 0.0, 1.0)
	# Longe do vale central o relevo fica mais bravo (o mapa dobrou de lado)
	var wild_factor: float = 1.0 + clamp((dist_from_center - 90.0) / 90.0, 0.0, 1.0) * 1.3
	var h: float = noise.get_noise_2d(x, z) * max_height * center_clearing_factor * wild_factor

	# Picos e serras novos nas terras de fora: [x, z, raio, altura]
	for peak in [[95.0, 115.0, 45.0, 15.0], [135.0, -55.0, 55.0, 12.0], [-115.0, 95.0, 42.0, 10.0], [-130.0, -120.0, 50.0, 13.0]]:
		var dp: float = Vector2(x - peak[0], z - peak[1]).length()
		if dp < peak[2]:
			h += pow(1.0 - dp / peak[2], 1.6) * peak[3]

	# 2. O Grande Pico (Noroeste: X ~ -28, Z ~ -52)
	var dist_to_peak: float = Vector2(x - (-28.0), z - (-52.0)).length()
	if dist_to_peak < 38.0:
		var peak_factor: float = clamp(1.0 - (dist_to_peak / 38.0), 0.0, 1.0)
		# Curva íngreme de cúpula montanhosa
		h += pow(peak_factor, 1.8) * 17.5

	# 3. Platô Norte e Penhasco da Cachoeira (Z < -28)
	var waterfall_z: float = RiverClass.WATERFALL_Z
	if z < waterfall_z:
		var plateau_factor: float = clamp((waterfall_z - z) / 8.0, 0.0, 1.0)
		h += plateau_factor * 8.2

	# 4. Leito do Rio e Cachoeira: corte em "U" com margem nítida.
	# t = distância ao centro / meia-largura da água. t < 1: fundo em curva até `depth` abaixo
	# da superfície; 1 ≤ t < BANK_END: barranco que sobe acima da água e encontra o relevo.
	var river_center_x: float = RiverClass.get_river_center_x(z)
	var dist_river: float = abs(x - river_center_x)
	var water_half_w: float = RiverClass.get_water_half_width(z)
	var t: float = dist_river / water_half_w
	const BANK_END: float = 1.6
	if t < BANK_END:
		var surface: float = RiverClass.get_water_height(z) - RiverClass.flood # relevo não muda com a cheia
		var depth: float = 2.8
		if z < (waterfall_z - 3.0):
			depth = 1.8
		elif z <= (waterfall_z + 8.0):
			depth = 3.6 # bacia funda onde a água cai
		if t < 1.0:
			# Fundo: borda já submersa (0,25 m) descendo em curva até o meio
			var bed: float = surface - 0.25 - (depth - 0.25) * pow(1.0 - t * t, 0.7)
			h = minf(bed, surface - 0.25)
		else:
			# Barranco: sai de baixo d'água e sobe pelo menos 0,45 m acima dela
			var bank_top: float = maxf(h, surface + 0.45)
			var k: float = smoothstep(1.0, BANK_END, t)
			h = lerpf(surface - 0.25, bank_top, sqrt(k))
	elif t < 2.4:
		# Várzea: chão baixo ao lado do rio, que só alaga na cheia
		h = maxf(h, RiverClass.get_water_height(z) - RiverClass.flood + 0.3)

	return h

func generate_landscape() -> void:
	_init_noise()

	var half_size: Vector2 = terrain_size * 0.5
	var step_x: float = terrain_size.x / float(subdivisions.x)
	var step_z: float = terrain_size.y / float(subdivisions.y)
	var row: int = subdivisions.x + 1
	var count: int = row * (subdivisions.y + 1)

	# Grade de vértices compartilhados: altura e cor uma vez por ponto (malha indexada)
	_heights.resize(count)
	var verts := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	verts.resize(count)
	colors.resize(count)
	uvs.resize(count)
	for zi in range(subdivisions.y + 1):
		for xi in range(row):
			var i: int = zi * row + xi
			var x: float = -half_size.x + xi * step_x
			var z: float = -half_size.y + zi * step_z
			var y: float = get_height_at(x, z)
			_heights[i] = y
			var v := Vector3(x, y, z)
			verts[i] = v
			colors[i] = _vertex_color(v)
			uvs[i] = Vector2(x * 0.1, z * 0.1)

	# Normais pela diferença das alturas vizinhas (relevo suave, sem custo de generate_normals)
	var normals := PackedVector3Array()
	normals.resize(count)
	for zi in range(subdivisions.y + 1):
		for xi in range(row):
			var hl: float = _heights[zi * row + maxi(xi - 1, 0)]
			var hr: float = _heights[zi * row + mini(xi + 1, row - 1)]
			var hd: float = _heights[maxi(zi - 1, 0) * row + xi]
			var hu: float = _heights[mini(zi + 1, subdivisions.y) * row + xi]
			normals[zi * row + xi] = Vector3((hl - hr) / (2.0 * step_x), 1.0, (hd - hu) / (2.0 * step_z)).normalized()

	var indices := PackedInt32Array()
	indices.resize(subdivisions.x * subdivisions.y * 6)
	var k: int = 0
	for zi in range(subdivisions.y):
		for xi in range(subdivisions.x):
			var a: int = zi * row + xi
			# Dois triângulos por quadrado (mesma ordem de antes: v00, v10, v01 / v10, v11, v01)
			indices[k] = a
			indices[k + 1] = a + 1
			indices[k + 2] = a + row
			indices[k + 3] = a + 1
			indices[k + 4] = a + row + 1
			indices[k + 5] = a + row
			k += 6

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh = am

	# Configurar material natural
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true # as cores exportadas são sRGB; sem isso o verde sai lavado
	mat.roughness = 0.95
	mat.metallic_specular = 0.1
	material_override = mat

	_rebuild_collision()
	_build_river_and_waterfall()

func _vertex_color(pos: Vector3) -> Color:
	var col: Color = grass_color
	var dist_river: float = RiverClass.get_distance_to_river(pos.x, pos.z)
	var water_hw: float = RiverClass.get_water_half_width(pos.z)
	var water_y: float = RiverClass.get_water_height(pos.z)

	if pos.y > 11.0:
		# Rocha exposta do Pico Majestoso
		var t_rock: float = clamp((pos.y - 11.0) / 8.0, 0.0, 1.0)
		col = grass_color.lerp(peak_rock_color, t_rock)
	elif pos.z >= (RiverClass.WATERFALL_Z - 2.5) and pos.z <= (RiverClass.WATERFALL_Z + 3.0) and pos.y > 1.0:
		# Escarpa do penhasco da cachoeira
		col = cliff_rock_color
	elif dist_river < (water_hw * 0.9) and pos.y < (water_y + 0.1):
		# Fundo do leito submerso
		col = riverbed_color
	elif dist_river <= (water_hw * 1.6):
		# Margem fértil e úmida da mata ciliar
		col = lush_bank_color
	else:
		# Colinas e relevo geral
		var t_hill: float = clamp(pos.y / (max_height * 0.9), 0.0, 1.0)
		col = grass_color.lerp(earth_color, t_hill)
	return col

func _rebuild_collision() -> void:
	for child in get_children():
		if child is StaticBody3D:
			child.queue_free()

	var static_body: StaticBody3D = StaticBody3D.new()
	static_body.name = "TerrainCollision"
	static_body.collision_layer = 1
	# Mapa de alturas: bem mais leve que malha de triângulos para física e para montar
	var col_shape: CollisionShape3D = CollisionShape3D.new()
	var hm := HeightMapShape3D.new()
	hm.map_width = subdivisions.x + 1
	hm.map_depth = subdivisions.y + 1
	hm.map_data = _heights
	col_shape.shape = hm
	col_shape.scale = Vector3(terrain_size.x / float(subdivisions.x), 1.0, terrain_size.y / float(subdivisions.y))
	static_body.add_child(col_shape)

	# 1. Paredes invisíveis nos 4 limites do mapa para evitar queda no abismo/limbo
	var half_x: float = terrain_size.x * 0.5
	var half_z: float = terrain_size.y * 0.5
	var wall_height: float = 60.0
	var wall_thickness: float = 6.0
	var wall_y: float = 15.0

	# Norte (Z-) e Sul (Z+)
	_add_wall_shape(static_body, Vector3(0.0, wall_y, -half_z - wall_thickness * 0.5), Vector3(terrain_size.x + wall_thickness * 2.0, wall_height, wall_thickness))
	_add_wall_shape(static_body, Vector3(0.0, wall_y, half_z + wall_thickness * 0.5), Vector3(terrain_size.x + wall_thickness * 2.0, wall_height, wall_thickness))
	# Oeste (X-) e Leste (X+)
	_add_wall_shape(static_body, Vector3(-half_x - wall_thickness * 0.5, wall_y, 0.0), Vector3(wall_thickness, wall_height, terrain_size.y + wall_thickness * 2.0))
	_add_wall_shape(static_body, Vector3(half_x + wall_thickness * 0.5, wall_y, 0.0), Vector3(wall_thickness, wall_height, terrain_size.y + wall_thickness * 2.0))

	# 2. Piso de segurança inferior (rede que intercepta qualquer um que atravesse a malha)
	_add_wall_shape(static_body, Vector3(0.0, -10.0, 0.0), Vector3(terrain_size.x * 1.5, 2.0, terrain_size.y * 1.5))

	add_child(static_body)

func _add_wall_shape(parent: StaticBody3D, center: Vector3, size: Vector3) -> void:
	var shape_node := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape_node.shape = box
	shape_node.position = center
	parent.add_child(shape_node)

func _build_river_and_waterfall() -> void:
	# Remover água antiga se houver
	for child in get_children():
		if child.name in ["RiverWater", "Waterfall", "WaterfallSplash", "RiverRocks"]:
			child.queue_free()

	# 1. Rio Horizontal (Superior, Lagoa e Inferior)
	var water_mesh_instance: MeshInstance3D = MeshInstance3D.new()
	water_mesh_instance.name = "RiverWater"

	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var half_z: float = terrain_size.y * 0.5
	var segments_z: int = 140
	var step_z: float = terrain_size.y / float(segments_z)

	for i in range(segments_z):
		var z0: float = -half_z + i * step_z
		var z1: float = z0 + step_z

		# Pula a abertura exata da queda vertical (ela será a malha da cachoeira)
		if z1 >= (RiverClass.WATERFALL_Z - 1.8) and z0 <= (RiverClass.WATERFALL_Z + 1.8):
			continue

		var cx0: float = RiverClass.get_river_center_x(z0)
		var cx1: float = RiverClass.get_river_center_x(z1)
		# Um pouco mais larga que a água "oficial": a borda some debaixo do barranco
		# Larga até a várzea: na vazante a borda some debaixo do barranco; na cheia cobre a várzea
		var hw0: float = RiverClass.get_water_half_width(z0) * 2.2
		var hw1: float = RiverClass.get_water_half_width(z1) * 2.2
		var y0: float = RiverClass.get_water_height(z0) - RiverClass.flood
		var y1: float = RiverClass.get_water_height(z1) - RiverClass.flood

		var l0: Vector3 = Vector3(cx0 - hw0, y0, z0)
		var r0: Vector3 = Vector3(cx0 + hw0, y0, z0)
		var l1: Vector3 = Vector3(cx1 - hw1, y1, z1)
		var r1: Vector3 = Vector3(cx1 + hw1, y1, z1)

		st.set_uv(Vector2(0.0, float(i)))
		st.add_vertex(l0)
		st.set_uv(Vector2(1.0, float(i)))
		st.add_vertex(r0)
		st.set_uv(Vector2(0.0, float(i + 1)))
		st.add_vertex(l1)

		st.set_uv(Vector2(1.0, float(i)))
		st.add_vertex(r0)
		st.set_uv(Vector2(1.0, float(i + 1)))
		st.add_vertex(r1)
		st.set_uv(Vector2(0.0, float(i + 1)))
		st.add_vertex(l1)

	st.generate_normals()
	water_mesh_instance.mesh = st.commit()

	var water_mat := ShaderMaterial.new()
	water_mat.shader = RIVER_SHADER
	water_mesh_instance.material_override = water_mat
	water_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water_mesh_instance)

	# 2. Cortina Vertical da Cachoeira
	var waterfall_instance: MeshInstance3D = MeshInstance3D.new()
	waterfall_instance.name = "Waterfall"

	var st_wf: SurfaceTool = SurfaceTool.new()
	st_wf.begin(Mesh.PRIMITIVE_TRIANGLES)

	var wf_z: float = RiverClass.WATERFALL_Z
	var wf_x: float = RiverClass.get_river_center_x(wf_z)
	var wf_w: float = RiverClass.get_water_half_width(wf_z - 2.0) * 2.2 # Largura da queda
	var top_y: float = RiverClass.UPPER_WATER_Y
	var bot_y: float = RiverClass.LOWER_WATER_Y

	# Lâmina d'água caindo com leve curva
	var wf_v0: Vector3 = Vector3(wf_x - wf_w * 0.5, top_y, wf_z - 0.8)
	var wf_v1: Vector3 = Vector3(wf_x + wf_w * 0.5, top_y, wf_z - 0.8)
	var wf_v2: Vector3 = Vector3(wf_x - wf_w * 0.6, bot_y, wf_z + 1.6)
	var wf_v3: Vector3 = Vector3(wf_x + wf_w * 0.6, bot_y, wf_z + 1.6)

	st_wf.set_uv(Vector2(0, 0))
	st_wf.add_vertex(wf_v0)
	st_wf.set_uv(Vector2(1, 0))
	st_wf.add_vertex(wf_v1)
	st_wf.set_uv(Vector2(0, 1))
	st_wf.add_vertex(wf_v2)

	st_wf.set_uv(Vector2(1, 0))
	st_wf.add_vertex(wf_v1)
	st_wf.set_uv(Vector2(1, 1))
	st_wf.add_vertex(wf_v3)
	st_wf.set_uv(Vector2(0, 1))
	st_wf.add_vertex(wf_v2)

	st_wf.generate_normals()
	waterfall_instance.mesh = st_wf.commit()

	# Material de espuma e queda espumante
	var wf_mat := ShaderMaterial.new()
	wf_mat.shader = WATERFALL_SHADER
	waterfall_instance.material_override = wf_mat
	waterfall_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# Luz suave no spray da cachoeira
	var mist_light: OmniLight3D = OmniLight3D.new()
	mist_light.light_color = Color(0.65, 0.85, 1.0)
	mist_light.light_energy = 0.8
	mist_light.omni_range = 10.0
	mist_light.position = Vector3(wf_x, bot_y + 1.2, wf_z + 1.2)
	waterfall_instance.add_child(mist_light)

	add_child(waterfall_instance)
	_build_splash(Vector3(wf_x, bot_y + 0.2, wf_z + 1.8), wf_w)
	_scatter_river_rocks()

## Respingo e névoa no pé da cachoeira
func _build_splash(pos: Vector3, width: float) -> void:
	var splash := CPUParticles3D.new()
	splash.name = "WaterfallSplash"
	splash.position = pos
	splash.amount = 90
	splash.lifetime = 1.4
	splash.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	splash.emission_box_extents = Vector3(width * 0.45, 0.1, 0.8)
	splash.direction = Vector3(0, 1, 0.4)
	splash.spread = 35.0
	splash.initial_velocity_min = 1.5
	splash.initial_velocity_max = 3.5
	splash.gravity = Vector3(0, -3.0, 0)
	splash.scale_amount_min = 0.4
	splash.scale_amount_max = 1.1
	var quad := QuadMesh.new()
	quad.size = Vector2(0.6, 0.6)
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.albedo_color = Color(0.92, 0.97, 1.0, 0.35)
	quad.material = m
	splash.mesh = quad
	splash.color_ramp = Gradient.new()
	splash.color_ramp.set_color(0, Color(1, 1, 1, 0.9))
	splash.color_ramp.set_color(1, Color(1, 1, 1, 0.0))
	add_child(splash)

## Pedras nas margens e no paredão da cachoeira (posições determinísticas pela seed do ruído)
func _scatter_river_rocks() -> void:
	var rocks: Array[PackedScene] = []
	for i in [1, 2, 3]:
		var path := "res://assets/models/nature/Rock_Medium_%d.gltf" % i
		if ResourceLoader.exists(path):
			rocks.append(load(path))
	var pebbles: Array[PackedScene] = []
	for i in [1, 2, 3, 4, 5]:
		var path := "res://assets/models/nature/Pebble_Round_%d.gltf" % i
		if ResourceLoader.exists(path):
			pebbles.append(load(path))
	if rocks.is_empty():
		return
	var holder := Node3D.new()
	holder.name = "RiverRocks"
	add_child(holder)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7331
	var half_z: float = terrain_size.y * 0.5
	var z := -half_z + 4.0
	while z < half_z - 4.0:
		z += rng.randf_range(2.5, 5.5)
		var near_fall: bool = absf(z - RiverClass.WATERFALL_Z) < 4.0
		var side: float = -1.0 if rng.randf() < 0.5 else 1.0
		var hw: float = RiverClass.get_water_half_width(z)
		var t: float = rng.randf_range(0.85, 1.35)
		var x: float = RiverClass.get_river_center_x(z) + side * hw * t
		if CityHub.in_village(x, z, 0.0) and not near_fall:
			continue
		var big: bool = near_fall or rng.randf() < 0.45
		var scene: PackedScene = rocks[rng.randi() % rocks.size()] if big or pebbles.is_empty() else pebbles[rng.randi() % pebbles.size()]
		var rock := scene.instantiate() as Node3D
		rock.position = Vector3(x, get_height_at(x, z) - 0.15, z)
		rock.rotation = Vector3(rng.randf_range(-0.2, 0.2), rng.randf() * TAU, rng.randf_range(-0.2, 0.2))
		rock.scale = Vector3.ONE * (rng.randf_range(0.8, 1.6) if big else rng.randf_range(1.5, 3.0))
		holder.add_child(rock)
		if near_fall:
			# Paredão: mais pedras subindo pela queda
			for k in 3:
				var rz := RiverClass.WATERFALL_Z + rng.randf_range(-1.5, 1.5)
				var rx := RiverClass.get_river_center_x(rz) + side * rng.randf_range(hw * 0.8, hw * 1.4)
				var r2 := rocks[rng.randi() % rocks.size()].instantiate() as Node3D
				r2.position = Vector3(rx, get_height_at(rx, rz) - 0.2, rz)
				r2.rotation.y = rng.randf() * TAU
				r2.scale = Vector3.ONE * rng.randf_range(1.2, 2.2)
				holder.add_child(r2)
