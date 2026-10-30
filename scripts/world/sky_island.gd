class_name SkyIsland
extends Node3D

## Uma ilha voadora no mundo (GDD-18). Quem decide onde ela está é a agenda (SkyIslandSchedule);
## este nó só desenha, colide e mostra a Corrente de vento. O corpo é um AnimatableBody3D para
## carregar quem está em cima quando a ilha gira, deriva, surge ou afunda.

## Tubo da Corrente: quase transparente, some nas pontas e "escorre" para cima
const CURRENT_SHADER: Shader = preload("res://materials/sky_current.gdshader")
## Som de pedra rachando e caindo, quando a ilha começa a tremer e quando começa a descer
const CRUMBLE_SOUND: AudioStream = preload("res://assets/audio/Small_Sound_Kit/Small Sound Kit/Ambience/Amb_Drop_Debris_01.wav")
## Tremor da malha (m) antes de afundar e afundando
const SHAKE_WARN: float = 0.06
const SHAKE_SINK: float = 0.18

var data: Dictionary
var shape: SkyIslandShape
## Flora, veios, baú e ninho; só existe com jogador perto (SkyIslandField)
var content: SkyIslandContent
var body: AnimatableBody3D
var _mesh: MeshInstance3D
var _current: Node3D
var _current_mesh: MeshInstance3D
var _beacon: Node3D
var _label: Label3D
var _debris: CPUParticles3D
var _crumble: AudioStreamPlayer3D
## Etapa do afundamento já mostrada (&"", &"tremendo", &"afundando")
var _stage: StringName = &""

func setup(island: Dictionary) -> void:
	data = island
	name = String(island.id)
	shape = SkyIslandShape.new(island)
	body = AnimatableBody3D.new()
	body.sync_to_physics = false
	add_child(body)
	_mesh = MeshInstance3D.new()
	_mesh.mesh = shape.build_mesh()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 0.95
	_mesh.material_override = mat
	body.add_child(_mesh)
	var col := CollisionShape3D.new()
	var tri := ConcavePolygonShape3D.new()
	tri.set_faces(_mesh.mesh.get_faces())
	tri.backface_collision = true
	col.shape = tri
	body.add_child(col)
	_build_current()
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font_size = 48
	_label.outline_size = 10
	_label.modulate = Color(0.95, 0.92, 0.8)
	_label.position.y = 4.0
	_label.visibility_range_begin = 6.0
	_label.visibility_range_end = 70.0
	_label.text = "%s · %s" % [SkyIslandSchedule.NAMES[rarity()], SkyIslandSchedule.RARITY_NAMES[rarity()]]
	add_child(_label)
	apply(island)

## Novo estado da agenda (mesma ilha): posição, fase, sólida ou não
func apply(island: Dictionary) -> void:
	data = island
	global_position = island.center
	var solid: bool = island.solid
	body.visible = solid
	body.process_mode = Node.PROCESS_MODE_INHERIT if solid else Node.PROCESS_MODE_DISABLED
	for c in body.get_children():
		if c is CollisionShape3D:
			c.disabled = not solid
	_label.visible = solid
	_current.visible = solid
	_current.position = current_offset()
	_update_beacon(island.phase == &"anunciada")
	_update_sinking(&"afundando" if island.phase == &"afundando" else (&"tremendo" if island.warning else &""))

func _process(_delta: float) -> void:
	if _stage.is_empty():
		return
	var amp := SHAKE_SINK if _stage == &"afundando" else SHAKE_WARN
	_mesh.position = Vector3(randf_range(-amp, amp), randf_range(-amp, amp) * 0.5, randf_range(-amp, amp))

## Antes de afundar (GDD-18 §5): a malha treme, pedras caem da base e a rocha range. Só o desenho
## treme; o chão onde se pisa (colisão) fica firme, para ninguém escorregar por causa do efeito.
func _update_sinking(stage: StringName) -> void:
	if stage == _stage:
		return
	_stage = stage
	if stage.is_empty():
		_mesh.position = Vector3.ZERO
		if _debris:
			_debris.emitting = false
		return
	if _debris == null:
		_debris = CPUParticles3D.new()
		_debris.name = "PedrasCaindo"
		var rock := BoxMesh.new()
		rock.size = Vector3.ONE * 0.35
		var mat := StandardMaterial3D.new()
		mat.albedo_color = SkyIslandShape.ROCK_COLORS[rarity()]
		rock.material = mat
		_debris.mesh = rock
		_debris.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		_debris.emission_sphere_radius = shape.radius * 0.6
		_debris.position.y = -shape.depth * 0.6
		_debris.gravity = Vector3(0, -18, 0)
		_debris.lifetime = 4.0
		_debris.scale_amount_min = 0.5
		_debris.scale_amount_max = 2.0
		add_child(_debris)
		_crumble = AudioStreamPlayer3D.new()
		_crumble.stream = CRUMBLE_SOUND
		_crumble.unit_size = 40.0
		_crumble.max_distance = 250.0
		add_child(_crumble)
	_debris.amount = 80 if stage == &"afundando" else 24
	_debris.emitting = true
	if is_inside_tree():
		_crumble.play()

func rarity() -> int:
	return int(data.rarity)

func is_solid() -> bool:
	return bool(data.solid)

## Altura (mundo) do chão da ilha
func top_y() -> float:
	return global_position.y

## Topo em (x, z) do mundo, ou -INF fora da ilha
func top_at(x: float, z: float) -> float:
	var t := shape.top_at(x - global_position.x, z - global_position.z)
	return t + global_position.y if t > -INF else -INF

## Base em (x, z) do mundo, ou INF fora da ilha
func bottom_at(x: float, z: float) -> float:
	var b := shape.bottom_at(x - global_position.x, z - global_position.z)
	return b + global_position.y if b < INF else INF

## Centro da Corrente, relativo à ilha (encosta na borda, por fora)
func current_offset() -> Vector3:
	var a: float = data.current_angle
	var d := shape.edge_radius(a) + SkyIslandField.CURRENT_RADIUS - SkyIslandField.CURRENT_OVERLAP
	return Vector3(cos(a) * d, 0.0, sin(a) * d)

## (x, y, z) está dentro da Corrente desta ilha?
func in_current(p: Vector3) -> bool:
	if not is_solid():
		return false
	var c := global_position + current_offset()
	return Vector2(p.x - c.x, p.z - c.z).length() <= SkyIslandField.CURRENT_RADIUS and p.y <= top_y() + SkyIslandField.CURRENT_OVERSHOOT

## Coluna de vento: tubo translúcido e fiapos subindo, do chão do vale até a ilha
func _build_current() -> void:
	_current = Node3D.new()
	_current.name = "Corrente"
	add_child(_current)
	var h: float = float(data.center.y) + 10.0
	_current_mesh = MeshInstance3D.new()
	var tube := CylinderMesh.new()
	tube.top_radius = SkyIslandField.CURRENT_RADIUS
	tube.bottom_radius = SkyIslandField.CURRENT_RADIUS * 0.8
	tube.height = h
	tube.cap_top = false
	tube.cap_bottom = false
	_current_mesh.mesh = tube
	var mat := ShaderMaterial.new()
	mat.shader = CURRENT_SHADER
	_current_mesh.material_override = mat
	_current_mesh.position.y = -h * 0.5 + 10.0
	_current_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_current.add_child(_current_mesh)
	var wisps := CPUParticles3D.new()
	wisps.amount = 60
	wisps.lifetime = h / 9.0
	wisps.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	wisps.emission_sphere_radius = SkyIslandField.CURRENT_RADIUS * 0.7
	wisps.direction = Vector3.UP
	wisps.spread = 4.0
	wisps.gravity = Vector3.ZERO
	wisps.initial_velocity_min = 8.0
	wisps.initial_velocity_max = 10.0
	wisps.scale_amount_min = 0.4
	wisps.scale_amount_max = 0.9
	var quad := QuadMesh.new()
	quad.size = Vector2(0.25, 1.4)
	var wmat := StandardMaterial3D.new()
	wmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wmat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	wmat.albedo_color = Color(1, 1, 1, 0.35)
	quad.material = wmat
	wisps.mesh = quad
	wisps.position.y = -h + 10.0
	_current.add_child(wisps)

## Mítica anunciada (GDD-18 §7): coluna de luz no ponto onde ela vai subir
func _update_beacon(on: bool) -> void:
	if on and _beacon == null:
		_beacon = Node3D.new()
		_beacon.name = "ColunaDeLuz"
		var m := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 3.0
		cyl.bottom_radius = 3.0
		cyl.height = 400.0
		m.mesh = cyl
		var mat := StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(0.75, 0.85, 1.0, 0.35)
		mat.emission_enabled = true
		mat.emission = Color(0.6, 0.75, 1.0)
		m.material_override = mat
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_beacon.add_child(m)
		var light := OmniLight3D.new()
		light.light_color = Color(0.7, 0.8, 1.0)
		light.light_energy = 4.0
		light.omni_range = 60.0
		_beacon.add_child(light)
		add_child(_beacon)
	if _beacon:
		_beacon.visible = on
