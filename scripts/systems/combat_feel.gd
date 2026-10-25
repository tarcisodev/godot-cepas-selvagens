class_name CombatFeel
extends RefCounted

## Peso dos golpes (GDD-12 §10). Chamado pela Hurtbox depois que o golpe é resolvido.
## Tudo é local de quem bate e de quem apanha: hitstop congela só as duas animações (e o relógio
## do golpe delas), o empurrão mexe só no alvo, o tranco é só na câmera de quem participa.
## Nada mexe em Engine.time_scale: no online o mundo não para por causa de um golpe (ADR-0006).

const HITSTOP_MIN: float = 0.05
const HITSTOP_MAX: float = 0.13
## Postura do golpe que conta como "golpe cheio" (peso 1)
const FULL_POISE: float = 40.0
## Empurrão por ponto de Postura (m/s)
const KNOCKBACK_PER_POISE: float = 0.09

const SOUNDS: Dictionary = {
	&"flesh": ["res://assets/audio/Small_Sound_Kit/Small Sound Kit/Dark/Impact_Guts_Gore_01.wav",
		"res://assets/audio/Small_Sound_Kit/Small Sound Kit/Dark/Blood_Bone_Smash_01.wav"],
	&"heavy": ["res://assets/audio/Small_Sound_Kit/Small Sound Kit/Doors/Drs_MetalDoor_Close_01.wav"],
	&"magic": ["res://assets/audio/Small_Sound_Kit/Small Sound Kit/Magic/Mgc_Electric_Hit_01.wav",
		"res://assets/audio/Small_Sound_Kit/Small Sound Kit/Magic/Mgc_Glacier_Impact_01.wav"],
}
static var _streams: Dictionary = {}

## Peso do golpe de 0 a 1,5 pela Postura (o martelo pesa mais que a espada)
static func weight_of(hit: HitEvent) -> float:
	return clampf(hit.poise_damage / FULL_POISE, 0.15, 1.5)

static func hitstop_of(weight: float) -> float:
	return lerpf(HITSTOP_MIN, HITSTOP_MAX, clampf(weight, 0.0, 1.0))

static func on_hit(hit: HitEvent, result: Dictionary) -> void:
	if hit == null or hit.target == null or not result.get(&"success", false):
		return
	var landed: bool = result.get(&"effective_damage", 0.0) > 0.0
	var weight := weight_of(hit)
	if not landed:
		weight *= 0.4 # bloqueado ou na esquiva: tranco pequeno, sem empurrão
	var stop := hitstop_of(weight)
	for who in [hit.attacker, hit.target]:
		if is_instance_valid(who) and who.has_method("apply_hitstop"):
			who.apply_hitstop(stop)
	var target := hit.target as Node3D
	var attacker := hit.attacker as Node3D
	if landed and target and attacker and is_instance_valid(attacker) and target.has_method("apply_knockback"):
		var dir := target.global_position - attacker.global_position
		dir.y = 0.0
		if dir.length_squared() > 0.0001:
			target.apply_knockback(dir.normalized() * hit.poise_damage * KNOCKBACK_PER_POISE * hit.knockback_mult * (2.0 if result.get(&"poise_broken", false) else 1.0))
	# Câmera: quem bate sente pouco, quem apanha sente mais
	if attacker is Player:
		(attacker as Player).shake_camera(0.12 * weight)
	if target is Player and landed:
		(target as Player).shake_camera(0.3 * weight + (0.25 if result.get(&"poise_broken", false) else 0.0))
	if target and target.is_inside_tree():
		var at: Vector3 = hit.hit_position if hit.hit_position != Vector3.ZERO else target.global_position + Vector3.UP
		# A faísca nasce entre o golpe e o corpo, não no centro da hitbox
		at = at.lerp(target.global_position + Vector3.UP * 0.9, 0.5)
		_spawn_sparks(target.get_parent(), at, hit.damage_type, weight, landed)
		if target.get("hit_audio_player") == null: # quem já tem som de golpe próprio (besta de treino) toca o seu
			_play_sound(target, at, hit.damage_type, weight, landed)

static func _type_color(t: DamageType.Type) -> Color:
	match t:
		DamageType.Type.IMPACT:
			return Color(1.0, 0.85, 0.55)
		DamageType.Type.PIERCE:
			return Color(1.0, 0.95, 0.9)
		DamageType.Type.FIRE:
			return Color(1.0, 0.45, 0.15)
		DamageType.Type.LIGHTNING:
			return Color(0.65, 0.8, 1.0)
		DamageType.Type.EARTH:
			return Color(0.75, 0.6, 0.35)
	return Color(1.0, 0.35, 0.25)

static func _spawn_sparks(parent: Node, at: Vector3, t: DamageType.Type, weight: float, landed: bool) -> void:
	if parent == null:
		return
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = int(lerpf(8.0, 26.0, clampf(weight, 0.0, 1.0)))
	p.lifetime = 0.35
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 80.0
	p.initial_velocity_min = 2.0 + weight * 2.0
	p.initial_velocity_max = 4.0 + weight * 4.0
	p.gravity = Vector3(0, -12.0, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.2
	var mesh := SphereMesh.new()
	mesh.radius = 0.03
	mesh.height = 0.06
	mesh.radial_segments = 4
	mesh.rings = 2
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = _type_color(t) if landed else Color(0.85, 0.9, 1.0)
	mesh.material = mat
	p.mesh = mesh
	parent.add_child(p)
	p.global_position = at
	p.emitting = true
	p.finished.connect(p.queue_free)

static func _stream(path: String) -> AudioStream:
	if not _streams.has(path):
		_streams[path] = load(path) if ResourceLoader.exists(path) else null
	return _streams[path]

static func _play_sound(owner: Node3D, at: Vector3, t: DamageType.Type, weight: float, landed: bool) -> void:
	var kind: StringName = &"flesh"
	if t in [DamageType.Type.FIRE, DamageType.Type.LIGHTNING, DamageType.Type.EARTH]:
		kind = &"magic"
	elif not landed or (t == DamageType.Type.IMPACT and weight > 0.9):
		kind = &"heavy"
	var paths: Array = SOUNDS[kind]
	var stream := _stream(paths[randi() % paths.size()])
	if stream == null or owner.get_parent() == null:
		return
	var a := AudioStreamPlayer3D.new()
	a.stream = stream
	a.bus = &"Efeitos"
	a.max_distance = 30.0
	a.volume_db = lerpf(-10.0, -1.0, clampf(weight, 0.0, 1.0))
	# Golpe pesado soa mais grave
	a.pitch_scale = lerpf(1.2, 0.75, clampf(weight, 0.0, 1.5) / 1.5) * randf_range(0.95, 1.05)
	owner.get_parent().add_child(a)
	a.global_position = at
	a.play()
	a.finished.connect(a.queue_free)
