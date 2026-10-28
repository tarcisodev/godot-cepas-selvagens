class_name VultureFlock3D
extends Node3D

## Bando de Urubus Carniceiros Procedurais (GDD-10 §11.2).
## Atuam como "Farol Natural" no horizonte sobre carcaças no chão:
## voam em círculos contínuos a 18–25 m de altura, sinalizando visualmente
## à distância onde há carcaça para esfolar ou predadores rondando.
## Quando a carcaça é consumida ou decomposta, dispersam voando para o alto.

const FLOCK_COUNT: int = 3
const BASE_ALTITUDE: float = 20.0
const ORBIT_RADIUS: float = 10.0
const FLIGHT_SPEED: float = 1.2

enum State { CIRCLING, DISPERSING }

var state: State = State.CIRCLING
var _vultures: Array[Node3D] = []
var _angles: Array[float] = []
var _radii: Array[float] = []
var _altitudes: Array[float] = []
var _speeds: Array[float] = []
var _wing_nodes: Array[Array] = []
var _t: float = 0.0
var _disperse_timer: float = 0.0

func _ready() -> void:
	_build_flock()

func _build_flock() -> void:
	var dark_feathers := StandardMaterial3D.new()
	dark_feathers.albedo_color = Color(0.12, 0.12, 0.14)
	dark_feathers.roughness = 0.9

	var beak_mat := StandardMaterial3D.new()
	beak_mat.albedo_color = Color(0.85, 0.45, 0.2)

	for i in FLOCK_COUNT:
		var root := Node3D.new()
		root.name = "Vulture_%d" % i
		add_child(root)

		# Corpo
		var body := MeshInstance3D.new()
		var bm := SphereMesh.new()
		bm.radius = 0.22
		bm.height = 0.65
		bm.radial_segments = 6
		bm.rings = 3
		body.mesh = bm
		body.material_override = dark_feathers
		body.rotation.x = PI * 0.5
		root.add_child(body)

		# Bico
		var beak := MeshInstance3D.new()
		var bkm := CylinderMesh.new()
		bkm.top_radius = 0.01
		bkm.bottom_radius = 0.07
		bkm.height = 0.22
		beak.mesh = bkm
		beak.material_override = beak_mat
		beak.position = Vector3(0, 0, -0.42)
		beak.rotation.x = -PI * 0.5
		root.add_child(beak)

		# Asas batendo (esquerda e direita)
		var wings: Array = []
		for side in [-1.0, 1.0]:
			var wing_pivot := Node3D.new()
			wing_pivot.position = Vector3(side * 0.15, 0.05, 0.0)
			root.add_child(wing_pivot)

			var wing := MeshInstance3D.new()
			var wm := BoxMesh.new()
			wm.size = Vector3(0.75, 0.03, 0.35)
			wing.mesh = wm
			wing.material_override = dark_feathers
			wing.position = Vector3(side * 0.375, 0, 0)
			wing_pivot.add_child(wing)
			wings.append(wing_pivot)

		_vultures.append(root)
		_angles.append(TAU * i / float(FLOCK_COUNT))
		_radii.append(ORBIT_RADIUS + (i - 1) * 2.2)
		_altitudes.append(BASE_ALTITUDE + (i - 1) * 1.8)
		_speeds.append(FLIGHT_SPEED + i * 0.15)
		_wing_nodes.append(wings)

func _process(delta: float) -> void:
	_t += delta

	if state == State.DISPERSING:
		_disperse_timer += delta
		# Sobe e afasta suavemente
		position.y += delta * 7.0
		scale = scale.move_toward(Vector3.ZERO, delta * 0.4)
		if _disperse_timer >= 3.5:
			queue_free()
			return

	for i in _vultures.size():
		var v := _vultures[i]
		_angles[i] += _speeds[i] * delta
		var a: float = _angles[i]
		var r: float = _radii[i]
		var h: float = _altitudes[i] + sin(_t * 2.0 + i) * 0.8

		var pos := Vector3(cos(a) * r, h, sin(a) * r)
		v.position = pos

		# Alinha urubu com a tangente da órbita circular
		var tangent := Vector3(-sin(a), 0, cos(a)).normalized()
		v.look_at(pos + tangent, Vector3.UP)

		# Bate as asas suavemente
		var wing_flap: float = sin(_t * 5.0 + i * 1.5) * 0.35
		var wings: Array = _wing_nodes[i]
		wings[0].rotation.z = -wing_flap
		wings[1].rotation.z = wing_flap

## Acionado quando a carcaça é esfolada ou decomposta: o bando alça voo e dispersa
func disperse() -> void:
	if state == State.DISPERSING:
		return
	state = State.DISPERSING
	_disperse_timer = 0.0
