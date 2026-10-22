class_name Moon
extends MeshInstance3D

## Lua no céu (GDD-10 §2.1): ciclo de 28 dias do DayNightCycle. Fica atrás do sol pela fase
## (nova = junto do sol, cheia = do lado oposto) e o shader acende só o lado virado para o sol,
## então a fase visível sai certa. Acompanha a câmera, bem longe, como se estivesse no céu.

const DISTANCE: float = 420.0
const SIZE: float = 16.0
const SHADER: Shader = preload("res://materials/moon.gdshader")

@export var sun: DirectionalLight3D

var _mat: ShaderMaterial

func _ready() -> void:
	if sun == null:
		sun = get_parent().get_node_or_null("Sun") as DirectionalLight3D
	var sm := SphereMesh.new()
	sm.radius = SIZE
	sm.height = SIZE * 2.0
	sm.radial_segments = 32
	sm.rings = 16
	mesh = sm
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.render_priority = -1
	material_override = _mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Transparente (some de dia) e atrás de tudo
	_mat.set_shader_parameter("sky_fade", 1.0)

func _process(_delta: float) -> void:
	if sun == null or not sun.has_method("moon_phase"):
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var sun_deg: float = sun.sun_angle_deg()
	var moon_deg: float = sun_deg - sun.moon_phase() * 360.0
	var sun_sky := _sky_dir(sun_deg)
	var moon_sky := _sky_dir(moon_deg)
	global_position = cam.global_position + moon_sky * DISTANCE
	_mat.set_shader_parameter("sun_dir", sun_sky)
	# Some de dia claro e abaixo do horizonte
	var day := clampf(sun_sky.y * 4.0 + 0.3, 0.0, 1.0)
	_mat.set_shader_parameter("sky_fade", clampf(1.0 - day * 0.85, 0.0, 1.0))
	visible = moon_sky.y > -0.08

## Direção no céu de um astro no ângulo dado (mesmo trilho inclinado do sol)
func _sky_dir(angle_deg: float) -> Vector3:
	var b := Basis.from_euler(Vector3(deg_to_rad(-angle_deg), deg_to_rad(-35.0), 0.0))
	return b.z.normalized()
