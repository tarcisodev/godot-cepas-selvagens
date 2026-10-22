class_name WeatherSystem
extends Node3D

## Ciclo da água (GDD-10 §2): o sol esquenta o rio e a lagoa, a umidade sobe, condensa em nuvens
## e as nuvens carregadas chovem. Poucos números atualizados devagar (a cada TICK s), que o
## jogador vê: camada de nuvens se movendo com o vento, céu e luz escurecendo, chuva e névoa.
## A chuva molha o solo (Ecology lê `rain`).

signal weather_changed(humidity: float, clouds: float, rain: float)

const TICK: float = 2.0
## Fração do mapa coberta por água (rio + lagoa): quanto evapora por calor
const WATER_SURFACE: float = 0.12

@export var sun: DirectionalLight3D
@export var environment: WorldEnvironment
@export var cloud_count: int = 30

## Estado do clima (0–1). Começa com o céu limpo e o ar meio úmido.
var heat: float = 0.0
var humidity: float = 0.45
var clouds: float = 0.1
var rain: float = 0.0
var wind: Vector2 = Vector2(1.0, 0.25)
## Água da chuva escorrendo para o rio (vira cheia); a vazão esvazia aos poucos
var runoff: float = 0.0

var _timer: float = 0.0
var _cloud_root: Node3D
var _cloud_mat: ShaderMaterial
var _rain: GPUParticles3D
var _sky_top: Color
var _sky_horizon: Color
var _haze_color := Color(0.72, 0.76, 0.82)
var _sky_mat: ProceduralSkyMaterial

func _ready() -> void:
	add_to_group("weather")
	if sun == null:
		sun = get_parent().get_node_or_null("Sun") as DirectionalLight3D
	if environment == null:
		environment = get_parent().get_node_or_null("WorldEnvironment") as WorldEnvironment
	if environment and environment.environment and environment.environment.sky:
		_sky_mat = environment.environment.sky.sky_material as ProceduralSkyMaterial
		if _sky_mat:
			_sky_top = _sky_mat.sky_top_color
			_sky_horizon = _sky_mat.sky_horizon_color
	_build_clouds()
	_build_rain()

func _process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_timer = TICK
		step(_hour())
	_update_visuals(delta)

## Um passo da simulação (público para os testes)
func step(hour: float) -> void:
	var sun_up := clampf(sin((hour - 6.0) / 12.0 * PI), 0.0, 1.0)
	heat = sun_up * (1.0 - clouds * 0.6)
	# Evaporação: calor × água exposta
	humidity = clampf(humidity + heat * WATER_SURFACE * 0.0375, 0.0, 1.0)
	# Condensação: acima de 55% de umidade vira nuvem
	if humidity > 0.55:
		var c := (humidity - 0.55) * 0.06
		humidity -= c
		clouds = clampf(clouds + c * 4.5, 0.0, 1.0)
	# Sem chuva, o vento dissipa; sol forte em ar seco dissipa mais
	if rain < 0.05:
		clouds = clampf(clouds - 0.0012 - heat * 0.002 * (1.0 - humidity), 0.0, 1.0)
	# Nuvem carregada (> 65%) chove até se esvaziar
	var target_rain := clampf((clouds - 0.65) / 0.25, 0.0, 1.0) if clouds > 0.65 else 0.0
	if rain > 0.05 and clouds > 0.35:
		target_rain = maxf(target_rain, 0.25)
	rain = move_toward(rain, target_rain, 0.08)
	if rain > 0.0:
		clouds = clampf(clouds - rain * 0.025, 0.0, 1.0)
		humidity = clampf(humidity - rain * 0.015, 0.0, 1.0)
	# Cheia e vazão (GDD-10 §2): chuva escorre para o rio; o rio escoa ~1,5% por passo
	runoff = clampf(runoff + rain * 0.06, 0.0, RiverSystem.FLOOD_MAX * 1.3)
	runoff *= 0.985
	RiverSystem.flood = minf(runoff, RiverSystem.FLOOD_MAX)
	weather_changed.emit(humidity, clouds, rain)

func _hour() -> float:
	return sun.get("current_time_hours") if sun else 12.0

func get_state() -> Dictionary:
	return {"humidity": humidity, "clouds": clouds, "rain": rain, "runoff": runoff, "flood": RiverSystem.flood, "wind": [wind.x, wind.y]}

func apply_state(d: Dictionary) -> void:
	humidity = float(d.get("humidity", humidity))
	clouds = float(d.get("clouds", clouds))
	rain = float(d.get("rain", rain))
	runoff = float(d.get("runoff", runoff))
	RiverSystem.flood = clampf(float(d.get("flood", 0.0)), 0.0, RiverSystem.FLOOD_MAX)
	var w: Array = d.get("wind", [wind.x, wind.y])
	wind = Vector2(float(w[0]), float(w[1]))

# ---------------------------------------------------------------- visual

func _update_visuals(delta: float) -> void:
	_update_river()
	if sun:
		sun.set("overcast", clampf(clouds * 1.1 - 0.15, 0.0, 1.0))
	if _sky_mat:
		var grey := clampf(clouds - 0.2, 0.0, 1.0) * 0.75
		var top := _sky_top.lerp(Color(0.42, 0.45, 0.5), grey)
		var horizon := _sky_horizon.lerp(Color(0.6, 0.62, 0.65), grey)
		# Noite: céu escuro (um pouco mais claro com lua cheia)
		var night := _night_factor()
		var moon: float = sun.moon_illumination() if sun and sun.has_method("moon_illumination") else 0.5
		top = top.lerp(Color(0.02, 0.03, 0.08).lerp(Color(0.07, 0.1, 0.2), moon), night)
		horizon = horizon.lerp(Color(0.05, 0.07, 0.14).lerp(Color(0.14, 0.18, 0.3), moon), night)
		_sky_mat.sky_top_color = top
		_sky_mat.sky_horizon_color = horizon
		# Abaixo do horizonte (além da borda do mapa) o "chão" do céu some na mesma névoa
		_sky_mat.ground_horizon_color = horizon
		_sky_mat.ground_bottom_color = horizon.darkened(0.15)
		_haze_color = horizon
	if environment and environment.environment:
		# Névoa de distância sempre ligada (perspectiva aérea); com chuva ela fecha bem mais perto
		var env := environment.environment
		env.fog_enabled = true
		env.fog_mode = Environment.FOG_MODE_DEPTH
		env.fog_sky_affect = 0.0
		env.fog_depth_begin = lerpf(110.0, 25.0, rain)
		env.fog_depth_end = lerpf(330.0, 120.0, maxf(rain, clampf(clouds - 0.6, 0.0, 0.4)))
		env.fog_depth_curve = 1.4
		env.fog_density = 1.0
		env.fog_light_color = _haze_color
	# Nuvens: aparecem conforme a cobertura e andam com o vento
	if _cloud_root:
		var shown := int(round(clouds * cloud_count))
		# Céu carregado escurece as nuvens; à noite ficam quase sem luz
		var storm := clampf((clouds - 0.5) * 2.0, 0.0, 1.0)
		var night := _night_factor()
		var top := Color(1, 1, 1).lerp(Color(0.62, 0.64, 0.68), storm).lerp(Color(0.16, 0.18, 0.25), night)
		var base := Color(0.74, 0.77, 0.84).lerp(Color(0.34, 0.36, 0.4), storm).lerp(Color(0.07, 0.08, 0.12), night)
		_cloud_mat.set_shader_parameter("top_color", top)
		_cloud_mat.set_shader_parameter("base_color", base)
		_cloud_mat.set_shader_parameter("opacity", 0.6 + clouds * 0.35)
		var edge := WorldBounds.HALF + 40.0
		for i in _cloud_root.get_child_count():
			var c := _cloud_root.get_child(i) as Node3D
			c.visible = i < shown
			c.position.x += wind.x * delta * 1.5
			c.position.z += wind.y * delta * 1.5
			if c.position.x > edge:
				c.position.x = -edge
			if c.position.z > edge:
				c.position.z = -edge
	if _rain:
		_rain.emitting = rain > 0.03
		_rain.amount_ratio = clampf(rain, 0.05, 1.0)
		var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
		if cam:
			_rain.global_position = cam.global_position + Vector3(0, 14.0, 0)

## 0 de dia, 1 com o sol bem abaixo do horizonte (transição no crepúsculo)
func _night_factor() -> float:
	if sun == null or not sun.has_method("sun_angle_deg"):
		return 0.0
	var elev := sin(deg_to_rad(sun.sun_angle_deg()))
	return clampf(0.25 - elev * 3.0, 0.0, 1.0)

## Rio sobe com a cheia; correnteza e espuma aumentam com a vazão
func _update_river() -> void:
	var land := get_parent().get_node_or_null("Landscape") if get_parent() else null
	var water := land.get_node_or_null("RiverWater") as MeshInstance3D if land else null
	if water == null:
		return
	water.position.y = move_toward(water.position.y, RiverSystem.flood, get_process_delta_time() * 0.2)
	var mat := water.material_override as ShaderMaterial
	if mat:
		var surge := RiverSystem.flood / RiverSystem.FLOOD_MAX
		mat.set_shader_parameter("flow_speed", 0.55 + surge * 0.9)
		mat.set_shader_parameter("foam_width", 0.45 + surge * 0.5)
		mat.set_shader_parameter("emission_strength", lerpf(0.45, 0.04, _night_factor()))
		mat.set_shader_parameter("shallow_color", Color(0.28, 0.62, 0.56).lerp(Color(0.5, 0.44, 0.3), surge * 0.6))

func _build_clouds() -> void:
	_cloud_root = Node3D.new()
	_cloud_root.name = "Clouds"
	add_child(_cloud_root)
	_cloud_mat = ShaderMaterial.new()
	_cloud_mat.shader = preload("res://materials/cloud.gdshader")
	var tex := NoiseTexture2D.new()
	tex.seamless = true
	tex.generate_mipmaps = true
	tex.width = 128
	tex.height = 128
	var fn := FastNoiseLite.new()
	fn.frequency = 0.03
	fn.fractal_octaves = 4
	tex.noise = fn
	_cloud_mat.set_shader_parameter("noise_tex", tex)
	var rng := RandomNumberGenerator.new()
	rng.seed = 909
	var edge := WorldBounds.HALF + 40.0
	for i in cloud_count:
		# Bolo de pufes: os de baixo largos e achatados, os de cima menores (forma de cúmulo)
		var verts := PackedVector3Array()
		var uvs := PackedVector2Array()
		var uv2s := PackedVector2Array()
		var colors := PackedColorArray()
		var indices := PackedInt32Array()
		var length := rng.randf_range(30.0, 70.0)
		var puffs := int(length / 3.0) + rng.randi_range(0, 6)
		for k in puffs:
			var hf := rng.randf()
			var center := Vector3(rng.randf_range(-0.5, 0.5) * length * (1.0 - hf * 0.5), hf * 9.0, rng.randf_range(-0.3, 0.3) * length)
			var size := rng.randf_range(16.0, 26.0) * (1.0 - hf * 0.35)
			var seed_off := rng.randf() * 10.0
			var b := verts.size()
			for corner in [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]:
				verts.append(center)
				uvs.append(corner)
				uv2s.append(Vector2(size, seed_off))
				colors.append(Color(hf, 0, 0))
			indices.append_array([b, b + 1, b + 2, b, b + 2, b + 3])
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		arrays[Mesh.ARRAY_TEX_UV2] = uv2s
		arrays[Mesh.ARRAY_COLOR] = colors
		arrays[Mesh.ARRAY_INDEX] = indices
		var am := ArrayMesh.new()
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var mi := MeshInstance3D.new()
		mi.mesh = am
		mi.material_override = _cloud_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# Os quadrados crescem no shader: caixa folgada para não sumirem nas bordas da tela
		mi.custom_aabb = AABB(Vector3(-55, -16, -45), Vector3(110, 40, 90))
		mi.position = Vector3(rng.randf_range(-edge, edge), rng.randf_range(48.0, 64.0), rng.randf_range(-edge, edge))
		mi.visible = false
		_cloud_root.add_child(mi)

func _build_rain() -> void:
	_rain = GPUParticles3D.new()
	_rain.name = "Rain"
	_rain.amount = 2500
	_rain.lifetime = 1.4
	_rain.emitting = false
	_rain.visibility_aabb = AABB(Vector3(-30, -30, -30), Vector3(60, 60, 60))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(28, 1, 28)
	pm.direction = Vector3(0.12, -1, 0.04)
	pm.spread = 3.0
	pm.initial_velocity_min = 16.0
	pm.initial_velocity_max = 20.0
	pm.gravity = Vector3(0, -6, 0)
	_rain.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.025, 0.55)
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	m.albedo_color = Color(0.75, 0.82, 0.92, 0.45)
	quad.material = m
	_rain.draw_pass_1 = quad
	add_child(_rain)
