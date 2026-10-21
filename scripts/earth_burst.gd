class_name EarthBurst
extends Node3D

## Explosão telúrica do cajado (B10): acerta tudo no raio por um instante e some.

var attacker: Node
var attack: StyleAttack
var hitbox: HitboxComponent
var _disc: MeshInstance3D
var _age: float = 0.0
const LIFETIME: float = 0.6

static func spawn(parent: Node, p_attacker: Node, center: Vector3, p_attack: StyleAttack) -> EarthBurst:
	var burst := EarthBurst.new()
	burst.attacker = p_attacker
	burst.attack = p_attack
	parent.add_child(burst)
	burst.global_position = center
	return burst

func _ready() -> void:
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.75, 0.55, 0.25, 0.75)
	_disc = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = attack.reach
	cyl.bottom_radius = attack.reach * 0.85
	cyl.height = 0.25
	_disc.mesh = cyl
	_disc.material_override = mat
	_disc.scale = Vector3(0.2, 1.0, 0.2)
	add_child(_disc)

	hitbox = HitboxComponent.new()
	hitbox.attacker = attacker
	var shape := CollisionShape3D.new()
	var ball := SphereShape3D.new()
	ball.radius = attack.reach
	shape.shape = ball
	shape.position.y = 0.5
	hitbox.add_child(shape)
	add_child(hitbox)
	hitbox.activate_with_params(attack.active_time, attack.damage, attack.damage_type, attack.poise_damage, attack.break_mult)

func _process(delta: float) -> void:
	_age += delta
	var t: float = clampf(_age / LIFETIME, 0.0, 1.0)
	var grow: float = lerpf(0.2, 1.0, minf(t * 4.0, 1.0))
	_disc.scale = Vector3(grow, 1.0 + t, grow)
	(_disc.material_override as StandardMaterial3D).albedo_color.a = 0.75 * (1.0 - t)
	if _age >= LIFETIME:
		queue_free()
