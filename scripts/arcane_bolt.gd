class_name ArcaneBolt
extends Node3D

## Dardo arcano do cajado (B10): voa reto, some ao acertar algo ou o chão.

var attacker: Node
var attack: StyleAttack
var velocity: Vector3 = Vector3.ZERO
var life: float = 1.4
var hitbox: HitboxComponent

## Cria o dardo já voando; `direction` é normalizada aqui.
static func spawn(parent: Node, p_attacker: Node, origin: Vector3, direction: Vector3, p_attack: StyleAttack) -> ArcaneBolt:
	var bolt := ArcaneBolt.new()
	bolt.attacker = p_attacker
	bolt.attack = p_attack
	bolt.velocity = direction.normalized() * p_attack.reach
	bolt.life = p_attack.active_time
	parent.add_child(bolt)
	bolt.global_position = origin
	return bolt

func _ready() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.6, 0.9, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.35, 0.8, 1.0)
	mat.emission_energy_multiplier = 4.0
	var core := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.09
	sphere.height = 0.18
	core.mesh = sphere
	core.material_override = mat
	add_child(core)

	var light := OmniLight3D.new()
	light.light_color = Color(0.45, 0.8, 1.0)
	light.light_energy = 1.2
	light.omni_range = 3.0
	add_child(light)

	hitbox = HitboxComponent.new()
	hitbox.attacker = attacker
	var shape := CollisionShape3D.new()
	var ball := SphereShape3D.new()
	ball.radius = 0.3
	shape.shape = ball
	hitbox.add_child(shape)
	add_child(hitbox)
	hitbox.activate_with_params(life, attack.damage, attack.damage_type, attack.poise_damage, attack.break_mult)
	hitbox.hit_landed.connect(func(_h, _r): queue_free())

func _physics_process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	var from := global_position
	var to := from + velocity * delta
	# Bate no terreno/rochas (camada 1)
	var query := PhysicsRayQueryParameters3D.create(from, to, 1)
	if get_world_3d().direct_space_state.intersect_ray(query):
		queue_free()
		return
	global_position = to
