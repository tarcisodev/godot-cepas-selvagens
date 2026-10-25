class_name CelestialSky
extends Node3D

## Céu Vivo e Cosmos (Estrelas Procedurais, Nebulosa, Estrelas Cadentes e Planeta com Anéis).
## Acompanha a câmera a grande distância para nunca cruzar o terreno, reagindo ao
## ciclo solar (DayNightCycle) e à cobertura de nuvens/chuva (WeatherSystem).

const DOME_RADIUS: float = 445.0
const PLANET_DISTANCE: float = 410.0
const PLANET_RADIUS: float = 24.0
const RING_OUTER_SIZE: float = 112.0

const STAR_SHADER: Shader = preload("res://materials/star_dome.gdshader")
const PLANET_SHADER: Shader = preload("res://materials/ringed_planet.gdshader")
const RING_SHADER: Shader = preload("res://materials/planet_rings.gdshader")

@export var sun: DirectionalLight3D
@export var weather: Node3D

var star_dome: MeshInstance3D
var planet_root: Node3D
var planet_body: MeshInstance3D
var planet_rings: MeshInstance3D

var _star_mat: ShaderMaterial
var _planet_mat: ShaderMaterial
var _ring_mat: ShaderMaterial
var _orbit_angle: float = 0.0

func _ready() -> void:
	add_to_group("celestial_sky")
	if sun == null and get_parent():
		sun = get_parent().get_node_or_null("Sun") as DirectionalLight3D
	if weather == null and get_parent():
		weather = get_parent().get_node_or_null("WeatherSystem") as Node3D

	_build_star_dome()
	_build_ringed_planet()

func _build_star_dome() -> void:
	star_dome = MeshInstance3D.new()
	star_dome.name = "StarDome"
	var sphere := SphereMesh.new()
	sphere.radius = DOME_RADIUS
	sphere.height = DOME_RADIUS * 2.0
	sphere.radial_segments = 48
	sphere.rings = 24
	star_dome.mesh = sphere

	_star_mat = ShaderMaterial.new()
	_star_mat.shader = STAR_SHADER
	_star_mat.render_priority = -3
	star_dome.material_override = _star_mat
	star_dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(star_dome)

func _build_ringed_planet() -> void:
	planet_root = Node3D.new()
	planet_root.name = "RingedPlanet"
	add_child(planet_root)

	# Corpo do Gigante Gasoso
	planet_body = MeshInstance3D.new()
	planet_body.name = "PlanetBody"
	var sm := SphereMesh.new()
	sm.radius = PLANET_RADIUS
	sm.height = PLANET_RADIUS * 2.0
	sm.radial_segments = 40
	sm.rings = 20
	planet_body.mesh = sm

	_planet_mat = ShaderMaterial.new()
	_planet_mat.shader = PLANET_SHADER
	_planet_mat.render_priority = -2
	planet_body.material_override = _planet_mat
	planet_body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	planet_root.add_child(planet_body)

	# Anéis inclinados em volta do planeta
	planet_rings = MeshInstance3D.new()
	planet_rings.name = "PlanetRings"
	var pm := PlaneMesh.new()
	pm.size = Vector2(RING_OUTER_SIZE, RING_OUTER_SIZE)
	planet_rings.mesh = pm

	_ring_mat = ShaderMaterial.new()
	_ring_mat.shader = RING_SHADER
	_ring_mat.render_priority = -2
	planet_rings.material_override = _ring_mat
	planet_rings.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Inclinação majestosa para mostrar bem os anéis ao olhar do chão
	planet_rings.rotation_degrees = Vector3(28.0, 15.0, -22.0)
	planet_body.rotation_degrees = Vector3(16.0, 0.0, -14.0)
	planet_root.add_child(planet_rings)

func _process(delta: float) -> void:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	var anchor := cam.global_position if cam else Vector3.ZERO
	global_position = anchor

	_orbit_angle = fposmod(_orbit_angle + delta * 0.004, TAU)
	if star_dome:
		star_dome.rotation.y = _orbit_angle * 0.35

	var sun_sky := Vector3(0.4, 0.7, 0.4).normalized()
	var night_vis := 0.5
	if sun and sun.has_method("sun_angle_deg"):
		var s_deg: float = sun.sun_angle_deg()
		var b := Basis.from_euler(Vector3(deg_to_rad(-s_deg), deg_to_rad(-35.0), 0.0))
		sun_sky = b.z.normalized()
		var elev := sin(deg_to_rad(s_deg))
		# Começa a surgir no fim da tarde / crepúsculo e brilha total à noite
		night_vis = clampf(0.42 - elev * 2.2, 0.0, 1.0)

	var clouds_val: float = float(weather.get("clouds")) if weather and "clouds" in weather else 0.0
	var rain_val: float = float(weather.get("rain")) if weather and "rain" in weather else 0.0
	var cloud_cover := clampf(clouds_val * 0.75 + rain_val * 0.45, 0.0, 0.92)

	# Mesmo de dia, num mundo alienígena/fantástico algumas estrelas-guia e o grande planeta
	# aparecem sutilmente no zênite limpo, e explodem de vida no crepúsculo e à noite.
	var star_alpha := clampf(maxf(night_vis, 0.14 * (1.0 - clouds_val)) * (1.0 - cloud_cover), 0.0, 1.0)
	if _star_mat:
		_star_mat.set_shader_parameter("sky_visibility", star_alpha)

	# Posição do Planeta Anelado no alto do céu (elevação ~48°, fácil de admirar olhando para cima)
	var planet_dir := Vector3(
		cos(_orbit_angle * 0.5 + 0.85) * 0.64,
		0.74,
		sin(_orbit_angle * 0.5 + 0.85) * 0.64
	).normalized()
	if planet_root:
		planet_root.position = planet_dir * PLANET_DISTANCE
		planet_body.rotation.y += delta * 0.03

	var planet_fade := clampf(lerpf(0.48, 1.0, night_vis) * (1.0 - cloud_cover * 0.82), 0.08, 1.0)
	if _planet_mat:
		_planet_mat.set_shader_parameter("sun_dir", sun_sky)
		_planet_mat.set_shader_parameter("sky_fade", planet_fade)
	if _ring_mat:
		_ring_mat.set_shader_parameter("sun_dir", sun_sky)
		_ring_mat.set_shader_parameter("sky_fade", planet_fade)
