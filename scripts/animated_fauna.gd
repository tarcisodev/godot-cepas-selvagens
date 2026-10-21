extends Node3D
class_name AnimatedFauna

## Fauna Animada dos Campos (Farm Animals Animated, Quaternius)
# Rebanhos que pastam: alternam entre parado (Idle) e caminhar (WalkSlow/Walk)
# perto de um ponto de pasto, sempre fora do rio. Espécies sem animação de andar
# só ficam pastando e girando devagar.
# A escala é calculada pelo tamanho real do modelo (os FBX vêm em escalas diferentes).

const RiverClass = preload("res://scripts/river_system.gd")

## Espécie: cena, altura alvo (m), tamanho do bando e velocidade de caminhada.
const SPECIES := [
	{"scene": preload("res://assets/models/fauna/farm_animals/Horse.fbx"), "height": 1.7, "count": 3, "speed": 1.1},
	{"scene": preload("res://assets/models/fauna/farm_animals/Zebra.fbx"), "height": 1.5, "count": 3, "speed": 1.2},
	{"scene": preload("res://assets/models/fauna/farm_animals/Cow.fbx"), "height": 1.45, "count": 3, "speed": 0.7},
	{"scene": preload("res://assets/models/fauna/farm_animals/Sheep.fbx"), "height": 0.9, "count": 5, "speed": 0.0},
	{"scene": preload("res://assets/models/fauna/farm_animals/Pig.fbx"), "height": 0.8, "count": 3, "speed": 0.0},
	{"scene": preload("res://assets/models/fauna/farm_animals/Llama.fbx"), "height": 1.8, "count": 2, "speed": 0.0},
]

## Centros de pasto (x, z); cada espécie pega um, em ordem.
@export var pastures: Array[Vector2] = [
	Vector2(-16.0, 14.0), Vector2(-24.0, -4.0), Vector2(-12.0, 26.0),
	Vector2(-6.0, 16.0), Vector2(-20.0, 8.0), Vector2(-28.0, 18.0),
]
@export var landscape: MeshInstance3D
@export var herd_radius: float = 6.0
@export var seed_value: int = 777

class Animal:
	var holder: Node3D
	var anim: AnimationPlayer
	var idle: StringName
	var walk: StringName
	var home: Vector3
	var target: Vector3
	var speed: float
	var timer: float
	var walking: bool = false

var animals: Array[Animal] = []
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	if landscape == null:
		landscape = get_parent().get_node_or_null("Landscape")
	rng.seed = seed_value
	for i in SPECIES.size():
		var species: Dictionary = SPECIES[i]
		var center: Vector2 = pastures[i % pastures.size()]
		for n in int(species.count):
			_spawn(species, center)

func _get_ground_y(x: float, z: float) -> float:
	if landscape and landscape.has_method("get_height_at"):
		return landscape.get_height_at(x, z)
	return 0.0

func _is_dry(x: float, z: float) -> bool:
	return RiverClass.get_distance_to_river(x, z) > RiverClass.get_water_half_width(z) * 1.3

func _random_point_near(center: Vector2) -> Vector3:
	for attempt in 12:
		var p := center + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.0, herd_radius)
		if _is_dry(p.x, p.y):
			return Vector3(p.x, _get_ground_y(p.x, p.y), p.y)
	return Vector3(center.x, _get_ground_y(center.x, center.y), center.y)

func _spawn(species: Dictionary, center: Vector2) -> void:
	var a := Animal.new()
	a.holder = Node3D.new()
	a.holder.name = "%s_%d" % [species.scene.resource_path.get_file().get_basename(), animals.size()]
	add_child(a.holder)
	var model: Node3D = species.scene.instantiate()
	a.holder.add_child(model)
	_fit_height(a.holder, model, float(species.height))

	a.anim = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	a.idle = _find_anim(a.anim, "Idle")
	a.walk = _find_anim(a.anim, "WalkSlow") if float(species.speed) > 0.0 else &""
	a.speed = float(species.speed)
	a.home = _random_point_near(center)
	a.holder.position = a.home
	a.holder.rotation.y = rng.randf() * TAU
	a.timer = rng.randf_range(1.0, 6.0)
	_play(a, a.idle)
	if a.anim and a.idle != &"":
		# Dessincroniza o rebanho
		a.anim.seek(rng.randf() * a.anim.get_animation(a.idle).length, true)
	animals.append(a)

## Escala o modelo para a altura alvo, medindo as malhas já na árvore.
func _fit_height(holder: Node3D, model: Node3D, height: float) -> void:
	var box := AABB()
	var first := true
	for m in model.find_children("*", "MeshInstance3D", true, false):
		var g: AABB = (m as MeshInstance3D).global_transform * (m as MeshInstance3D).get_aabb()
		box = g if first else box.merge(g)
		first = false
	if first or box.size.y <= 0.0:
		return
	var s: float = height / box.size.y
	model.scale *= s
	model.position.y -= (box.position.y - holder.global_position.y) * s

func _find_anim(anim: AnimationPlayer, suffix: String) -> StringName:
	if anim == null:
		return &""
	for n in anim.get_animation_list():
		if String(n).ends_with("|" + suffix) or String(n) == suffix:
			anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR
			return n
	return &""

func _play(a: Animal, n: StringName) -> void:
	if a.anim and n != &"" and a.anim.current_animation != n:
		a.anim.play(n, 0.3)

func _process(delta: float) -> void:
	for a in animals:
		a.timer -= delta
		if a.walking:
			var to := a.target - a.holder.position
			to.y = 0.0
			if to.length() < 0.2 or a.timer <= 0.0:
				a.walking = false
				a.timer = rng.randf_range(3.0, 9.0)
				_play(a, a.idle)
				continue
			var dir := to.normalized()
			var p := a.holder.position + dir * a.speed * delta
			p.y = _get_ground_y(p.x, p.z)
			a.holder.position = p
			# Os modelos do kit olham para +Z
			a.holder.rotation.y = lerp_angle(a.holder.rotation.y, atan2(dir.x, dir.z), 3.0 * delta)
		elif a.timer <= 0.0:
			if a.walk != &"":
				a.walking = true
				a.target = _random_point_near(Vector2(a.home.x, a.home.z))
				a.timer = 12.0
				_play(a, a.walk)
			else:
				# Quem não anda só muda de posição de pasto devagar
				a.holder.rotation.y += rng.randf_range(-0.8, 0.8)
				a.timer = rng.randf_range(4.0, 10.0)
