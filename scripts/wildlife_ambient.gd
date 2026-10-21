extends Node3D
class_name WildlifeAmbient

## Vida Silvestre: Sapos, Pássaros, Abelhas, Besouros e Vagalumes
# Popula o ambiente com pequenas criaturas que respiram, pulam, voam e zunem.

const RiverClass = preload("res://scripts/river_system.gd")

@export var landscape: MeshInstance3D
@export var frog_count: int = 12
@export var bird_count: int = 7
@export var bee_swarm_count: int = 8
@export var firefly_count: int = 35

# Dados dos Sapos
class FrogData:
	var node: Node3D
	var base_pos: Vector3
	var hop_timer: float
	var is_hopping: bool
	var hop_progress: float
	var hop_target: Vector3

# Dados dos Pássaros
class BirdData:
	var node: Node3D
	var wing_left: MeshInstance3D
	var wing_right: MeshInstance3D
	var center: Vector3
	var radius: float
	var angle: float
	var speed: float
	var altitude: float
	var wing_phase: float

# Dados das Abelhas
class BeeData:
	var node: Node3D
	var anchor: Vector3
	var phase_x: float
	var phase_y: float
	var phase_z: float

var frogs: Array[FrogData] = []
var birds: Array[BirdData] = []
var bees: Array[BeeData] = []
var fireflies: Array[Node3D] = []

func _ready() -> void:
	if landscape == null:
		landscape = get_parent().get_node_or_null("Landscape")

	_spawn_frogs()
	_spawn_birds()
	_spawn_bees()
	_spawn_fireflies()
	_spawn_beetles()

func _get_ground_y(x: float, z: float) -> float:
	if landscape and landscape.has_method("get_height_at"):
		return landscape.get_height_at(x, z)
	return 0.0

# --- 1. SAPOS NA BEIRA D'ÁGUA ---
func _spawn_frogs() -> void:
	var frog_mat: StandardMaterial3D = StandardMaterial3D.new()
	frog_mat.albedo_color = Color(0.28, 0.44, 0.18) # Verde oliva de sapo
	frog_mat.roughness = 0.5 # Pele úmida
	frog_mat.metallic_specular = 0.6

	var eye_mat: StandardMaterial3D = StandardMaterial3D.new()
	eye_mat.albedo_color = Color(0.1, 0.1, 0.08)

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 666

	for i in range(frog_count):
		var z: float = rng.randf_range(-RiverClass.WATERFALL_Z, 55.0)
		var rx: float = RiverClass.get_river_center_x(z)
		var hw: float = RiverClass.get_water_half_width(z)
		var side: float = 1.0 if rng.randf() > 0.5 else -1.0
		# Bem na margem úmida, a 0.5m a 2.0m da lâmina d'água
		var x: float = rx + side * rng.randf_range(hw + 0.4, hw + 2.2)
		var y: float = _get_ground_y(x, z)

		var frog: Node3D = Node3D.new()
		frog.name = "Frog_%d" % i
		frog.position = Vector3(x, y + 0.08, z)

		# Corpo abaulado
		var body: MeshInstance3D = MeshInstance3D.new()
		var sphere: SphereMesh = SphereMesh.new()
		sphere.radius = 0.12
		sphere.height = 0.16
		body.mesh = sphere
		body.material_override = frog_mat
		body.scale = Vector3(1.1, 0.75, 1.3)
		frog.add_child(body)

		# Olhinhos esbugalhados no topo da cabeça
		for eye_side in [-1.0, 1.0]:
			var eye: MeshInstance3D = MeshInstance3D.new()
			var eye_sphere: SphereMesh = SphereMesh.new()
			eye_sphere.radius = 0.035
			eye_sphere.height = 0.05
			eye.mesh = eye_sphere
			eye.material_override = eye_mat
			eye.position = Vector3(eye_side * 0.065, 0.09, 0.07)
			frog.add_child(eye)

		# Aponta de frente para a água
		var dir_to_water: float = atan2(rx - x, 0.0)
		frog.rotation.y = dir_to_water + rng.randf_range(-0.5, 0.5)

		var data: FrogData = FrogData.new()
		data.node = frog
		data.base_pos = frog.position
		data.hop_timer = rng.randf_range(2.0, 6.0)
		data.is_hopping = false
		data.hop_progress = 0.0
		data.hop_target = frog.position
		frogs.append(data)

		add_child(frog)

# --- 2. PÁSSAROS SOBREVOANDO O VALE E O PICO ---
func _spawn_birds() -> void:
	var bird_mat: StandardMaterial3D = StandardMaterial3D.new()
	bird_mat.albedo_color = Color(0.18, 0.16, 0.15) # Silhueta de andorinha/falcão

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 777

	for i in range(bird_count):
		var bird: Node3D = Node3D.new()
		bird.name = "Bird_%d" % i

		# Asas finas que batem suavemente
		var wing_l: MeshInstance3D = MeshInstance3D.new()
		var prism_l: PrismMesh = PrismMesh.new()
		prism_l.size = Vector3(0.45, 0.08, 0.12)
		wing_l.mesh = prism_l
		wing_l.material_override = bird_mat
		wing_l.position = Vector3(-0.25, 0, 0)
		bird.add_child(wing_l)

		var wing_r: MeshInstance3D = MeshInstance3D.new()
		var prism_r: PrismMesh = PrismMesh.new()
		prism_r.size = Vector3(0.45, 0.08, 0.12)
		wing_r.mesh = prism_r
		wing_r.material_override = bird_mat
		wing_r.position = Vector3(0.25, 0, 0)
		bird.add_child(wing_r)

		var data: BirdData = BirdData.new()
		data.node = bird
		data.wing_left = wing_l
		data.wing_right = wing_r
		data.center = Vector3(rng.randf_range(-25.0, 10.0), 0.0, rng.randf_range(-40.0, -10.0))
		data.radius = rng.randf_range(22.0, 48.0)
		data.angle = rng.randf_range(0.0, TAU)
		data.speed = rng.randf_range(0.4, 0.8)
		data.altitude = rng.randf_range(18.0, 32.0)
		data.wing_phase = rng.randf_range(0.0, TAU)
		birds.append(data)

		add_child(bird)

# --- 3. ABELHAS ZUNINDO NAS FLORES ---
func _spawn_bees() -> void:
	var bee_mat: StandardMaterial3D = StandardMaterial3D.new()
	bee_mat.albedo_color = Color(0.95, 0.75, 0.15) # Amarelo ouro
	bee_mat.roughness = 0.4

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 888

	for i in range(bee_swarm_count):
		var bx: float = rng.randf_range(-35.0, 35.0)
		var bz: float = rng.randf_range(-35.0, 35.0)
		var by: float = _get_ground_y(bx, bz) + 0.6

		var bee: Node3D = Node3D.new()
		bee.name = "Bee_%d" % i
		bee.position = Vector3(bx, by, bz)

		var bee_mesh: MeshInstance3D = MeshInstance3D.new()
		var sphere: SphereMesh = SphereMesh.new()
		sphere.radius = 0.03
		sphere.height = 0.06
		bee_mesh.mesh = sphere
		bee_mesh.material_override = bee_mat
		bee.add_child(bee_mesh)

		var data: BeeData = BeeData.new()
		data.node = bee
		data.anchor = bee.position
		data.phase_x = rng.randf_range(0.0, TAU)
		data.phase_y = rng.randf_range(0.0, TAU)
		data.phase_z = rng.randf_range(0.0, TAU)
		bees.append(data)

		add_child(bee)

# --- 4. VAGALUMES BRILHANTES (CREPÚSCULO E NOITE) ---
func _spawn_fireflies() -> void:
	var ff_mat: StandardMaterial3D = StandardMaterial3D.new()
	ff_mat.albedo_color = Color(0.85, 1.0, 0.4)
	ff_mat.emission_enabled = true
	ff_mat.emission = Color(0.75, 1.0, 0.3)
	ff_mat.emission_energy_multiplier = 1.6

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 999

	for i in range(firefly_count):
		var z: float = rng.randf_range(-40.0, 45.0)
		var rx: float = RiverClass.get_river_center_x(z)
		var x: float = rx + rng.randf_range(-18.0, 18.0)
		var y: float = _get_ground_y(x, z) + rng.randf_range(0.6, 2.2)

		var ff: MeshInstance3D = MeshInstance3D.new()
		ff.name = "Firefly_%d" % i
		var sphere: SphereMesh = SphereMesh.new()
		sphere.radius = 0.035
		sphere.height = 0.05
		ff.mesh = sphere
		ff.material_override = ff_mat
		ff.position = Vector3(x, y, z)
		fireflies.append(ff)
		add_child(ff)

# --- 5. BESOUROS NOS TRONCOS ---
func _spawn_beetles() -> void:
	var beetle_mat: StandardMaterial3D = StandardMaterial3D.new()
	beetle_mat.albedo_color = Color(0.12, 0.10, 0.16) # Casca escura azulada
	beetle_mat.metallic = 0.6
	beetle_mat.roughness = 0.2

	# Um besouro cascudinho explorando o tronco da fogueira
	var beetle: Node3D = Node3D.new()
	beetle.name = "CampfireBeetle"
	beetle.position = Vector3(4.0, _get_ground_y(4.0, -2.6) + 0.45, -2.6)

	var b_mesh: MeshInstance3D = MeshInstance3D.new()
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 0.04
	sphere.height = 0.09
	b_mesh.mesh = sphere
	b_mesh.material_override = beetle_mat
	beetle.add_child(b_mesh)
	add_child(beetle)

func _process(delta: float) -> void:
	_animate_frogs(delta)
	_animate_birds(delta)
	_animate_bees(delta)
	_animate_fireflies(delta)

func _animate_frogs(delta: float) -> void:
	for frog in frogs:
		if frog.is_hopping:
			frog.hop_progress += delta * 2.8
			if frog.hop_progress >= 1.0:
				frog.node.position = frog.hop_target
				frog.base_pos = frog.hop_target
				frog.is_hopping = false
				frog.hop_progress = 0.0
			else:
				var t: float = frog.hop_progress
				var current_pos: Vector3 = frog.base_pos.lerp(frog.hop_target, t)
				# Arco parabólico do pulo
				current_pos.y += sin(t * PI) * 0.35
				frog.node.position = current_pos
		else:
			frog.hop_timer -= delta
			if frog.hop_timer <= 0.0:
				frog.hop_timer = randf_range(3.0, 7.5)
				frog.is_hopping = true
				frog.hop_progress = 0.0
				var jump_dir: Vector3 = -frog.node.transform.basis.z.normalized()
				var ground_ahead: Vector3 = frog.base_pos + jump_dir * randf_range(0.4, 0.8)
				ground_ahead.y = _get_ground_y(ground_ahead.x, ground_ahead.z) + 0.08
				frog.hop_target = ground_ahead

func _animate_birds(delta: float) -> void:
	for bird in birds:
		bird.angle += bird.speed * delta
		var bx: float = bird.center.x + cos(bird.angle) * bird.radius
		var bz: float = bird.center.z + sin(bird.angle) * bird.radius
		var by: float = bird.altitude + sin(bird.angle * 2.0) * 1.5

		bird.node.position = Vector3(bx, by, bz)

		# Direção tangente da curva de voo
		var heading: float = bird.angle + (PI * 0.5)
		bird.node.rotation.y = -heading

		# Bater de asas gracioso (mescla de planar e bater)
		bird.wing_phase += delta * 6.5
		var flap: float = sin(bird.wing_phase) * deg_to_rad(28.0)
		bird.wing_left.rotation.z = flap
		bird.wing_right.rotation.z = -flap

func _animate_bees(delta: float) -> void:
	for bee in bees:
		bee.phase_x += delta * 4.5
		bee.phase_y += delta * 3.2
		bee.phase_z += delta * 5.0

		# Movimento em oito e zunido errático típico de abelha
		var offset: Vector3 = Vector3(
			sin(bee.phase_x) * 0.45,
			sin(bee.phase_y) * 0.25,
			cos(bee.phase_z) * 0.45
		)
		bee.node.position = bee.anchor + offset

func _animate_fireflies(delta: float) -> void:
	var t: float = Time.get_ticks_msec() * 0.001
	for i in range(fireflies.size()):
		var ff: MeshInstance3D = fireflies[i]
		var seed_offset: float = float(i) * 1.3
		ff.position.y += sin(t * 1.5 + seed_offset) * 0.004
		ff.position.x += cos(t * 1.1 + seed_offset) * 0.003
