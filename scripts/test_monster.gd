class_name TestMonster
extends CharacterBody3D

## Monstro de teste (B10): patrulha perto de casa, persegue o jogador, ataca e renasce.
## Sem aviso na tela (GDD-12 §11): quem lê o golpe é o jogador, pela animação de preparação.
## Usa o mesmo pipeline de dano do jogador (ADR-0003) e sente o peso do golpe (hitstop, empurrão).
## Os modelos Quaternius trazem as animações; aqui só se escolhe qual nome é qual.

enum State { WANDER, CHASE, WINDUP, ATTACK, RECOVER, STAGGER, DEAD, RETURN }

@export var display_name: String = "Monstro"
@export_group("Modelo")
@export var model_scene: PackedScene
@export var model_scale: float = 1.0
## Sufixos dos nomes das animações no modelo (ex.: &"Slime_Idle").
@export var anim_idle: StringName
@export var anim_move: StringName
@export var anim_attack: StringName
@export var anim_hit: StringName
@export var anim_death: StringName

@export_group("Corpo")
@export var body_radius: float = 0.4
@export var body_height: float = 1.0
@export var flying: bool = false
@export var fly_height: float = 1.6

@export_group("Atributos")
@export var max_health: float = 80.0
@export var max_poise: float = 40.0
@export var move_speed: float = 2.6
@export var resistances: Dictionary = {}

@export_group("Ataque")
@export var aggro_range: float = 8.0
@export var leash_range: float = 18.0
@export var attack_range: float = 1.6
@export var windup_time: float = 0.6
@export var attack_active: float = 0.2
@export var recover_time: float = 0.9
@export var damage: float = 12.0
@export var damage_type: DamageType.Type = DamageType.Type.IMPACT
@export var poise_damage: float = 15.0

@export_group("Ciclo")
@export var wander_radius: float = 5.0
@export var respawn_delay: float = 45.0
## Não renasce com o jogador a menos disso de casa: evita o bicho brotar no meio da luta
@export var respawn_clear_range: float = 14.0

const CORPSE_HIDE_TIME: float = 3.0

var stats: StatsComponent
var pools: PoolsComponent
var hurtbox: HurtboxComponent
var hitbox: HitboxComponent
var model: Node3D
var anim_player: AnimationPlayer
var status_label: Label3D

var state: State = State.WANDER
var home: Vector3
var _state_time: float = 0.0
var _wander_target: Vector3
var _wander_wait: float = 0.0
var _flash_timer: float = 0.0
var _meshes: Array[GeometryInstance3D] = []
var _hit_mat: StandardMaterial3D
## Peso dos golpes (GDD-12 §10)
var _hitstop: float = 0.0
var _knockback: Vector3 = Vector3.ZERO
## Brado (habilidade de armadura): persegue quem gritou, mesmo de longe de casa
var _taunted_until_ms: int = 0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	add_to_group("monsters")
	collision_layer = 4
	collision_mask = 1
	home = global_position
	_wander_target = home
	_rng.seed = hash(name)
	_build_components()
	_build_model()
	_build_labels()
	_update_label()

func _build_components() -> void:
	var shape := CapsuleShape3D.new()
	shape.radius = body_radius
	shape.height = maxf(body_height, body_radius * 2.0)
	var body := CollisionShape3D.new()
	body.shape = shape
	body.position.y = shape.height * 0.5
	add_child(body)

	stats = StatsComponent.new()
	stats.name = "StatsComponent"
	add_child(stats)
	stats.set_base_stat(&"max_health", max_health)
	stats.set_base_stat(&"max_poise", max_poise)
	for key in resistances:
		stats.set_base_stat(StringName(key), float(resistances[key]))

	pools = PoolsComponent.new()
	pools.name = "PoolsComponent"
	pools.stats = stats
	add_child(pools)
	pools.reset_all()
	pools.health_depleted.connect(_on_health_depleted)
	pools.poise_broken.connect(_on_poise_broken)
	pools.health_changed.connect(func(_c, _m): _update_label())

	hurtbox = HurtboxComponent.new()
	hurtbox.name = "BodyHurtbox"
	hurtbox.entity = self
	var hurt_shape := CollisionShape3D.new()
	hurt_shape.shape = shape
	hurtbox.add_child(hurt_shape)
	hurtbox.position.y = shape.height * 0.5
	add_child(hurtbox)

	hitbox = HitboxComponent.new()
	hitbox.name = "AttackHitbox"
	hitbox.attacker = self
	hitbox.ignore_group = &"monsters"
	var hit_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(body_radius * 2.0 + 0.5, maxf(body_height, 1.0), attack_range + 0.4)
	hit_shape.shape = box
	hitbox.add_child(hit_shape)
	hitbox.position = Vector3(0, shape.height * 0.5, -(attack_range + 0.4) * 0.5)
	add_child(hitbox)

func _build_model() -> void:
	if model_scene != null:
		model = model_scene.instantiate() as Node3D
		model.name = "Model"
		model.scale = Vector3.ONE * model_scale
		model.rotation.y = PI
		add_child(model)
		anim_player = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
		for anim in [anim_idle, anim_move]:
			var full := _resolve(anim)
			if full != &"":
				anim_player.get_animation(full).loop_mode = Animation.LOOP_LINEAR
		for m in model.find_children("*", "GeometryInstance3D", true, false):
			_meshes.append(m as GeometryInstance3D)
	else:
		_build_procedural_model()

	_hit_mat = StandardMaterial3D.new()
	_hit_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_hit_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_hit_mat.albedo_color = Color(1, 1, 1, 0.55)
	_play(anim_idle)

func _build_procedural_model() -> void:
	model = Node3D.new()
	model.name = "Model"
	add_child(model)

	var mesh_inst := MeshInstance3D.new()
	mesh_inst.name = "BodyMesh"

	var mat := StandardMaterial3D.new()
	mat.roughness = 0.5

	var lower_name := display_name.to_lower()
	if lower_name.contains("slime"):
		var sph := SphereMesh.new()
		sph.radius = body_radius
		sph.height = body_height
		mesh_inst.mesh = sph
		mesh_inst.position.y = body_height * 0.5
		mat.albedo_color = Color(0.2, 0.85, 0.35, 0.85)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.roughness = 0.15
	elif lower_name.contains("morcego") or lower_name.contains("bat"):
		var prism := PrismMesh.new()
		prism.size = Vector3(body_radius * 2.2, body_height * 0.4, body_radius * 1.2)
		mesh_inst.mesh = prism
		mesh_inst.position.y = body_height * 0.5
		mat.albedo_color = Color(0.25, 0.2, 0.3)
	else:
		var cyl := CylinderMesh.new()
		cyl.top_radius = body_radius * 0.7
		cyl.bottom_radius = body_radius * 0.9
		cyl.height = body_height
		mesh_inst.mesh = cyl
		mesh_inst.position.y = body_height * 0.5
		mat.albedo_color = Color(0.85, 0.82, 0.75)

	mesh_inst.material_override = mat
	model.add_child(mesh_inst)
	_meshes.append(mesh_inst)

	anim_player = AnimationPlayer.new()
	anim_player.name = "AnimationPlayer"
	model.add_child(anim_player)
	var anim_lib := AnimationLibrary.new()

	var idle_name: StringName = anim_idle if anim_idle != &"" else &"Idle"
	var move_name: StringName = anim_move if anim_move != &"" else &"Walk"
	var attack_name: StringName = anim_attack if anim_attack != &"" else &"Attack"
	var death_name: StringName = anim_death if anim_death != &"" else &"Death"

	var idle_anim := Animation.new()
	idle_anim.loop_mode = Animation.LOOP_LINEAR
	idle_anim.length = 1.0
	var t_idle := idle_anim.add_track(Animation.TYPE_VALUE)
	idle_anim.track_set_path(t_idle, "BodyMesh:scale")
	idle_anim.track_insert_key(t_idle, 0.0, Vector3.ONE)
	idle_anim.track_insert_key(t_idle, 0.5, Vector3(1.06, 0.94, 1.06))
	idle_anim.track_insert_key(t_idle, 1.0, Vector3.ONE)
	anim_lib.add_animation(idle_name, idle_anim)

	var move_anim := Animation.new()
	move_anim.loop_mode = Animation.LOOP_LINEAR
	move_anim.length = 0.6
	var t_move := move_anim.add_track(Animation.TYPE_VALUE)
	move_anim.track_set_path(t_move, "BodyMesh:position:y")
	move_anim.track_insert_key(t_move, 0.0, mesh_inst.position.y)
	move_anim.track_insert_key(t_move, 0.3, mesh_inst.position.y + 0.12)
	move_anim.track_insert_key(t_move, 0.6, mesh_inst.position.y)
	anim_lib.add_animation(move_name, move_anim)

	var atk_anim := Animation.new()
	atk_anim.length = maxf(0.5, windup_time + attack_active)
	var t_atk := atk_anim.add_track(Animation.TYPE_VALUE)
	atk_anim.track_set_path(t_atk, "BodyMesh:scale")
	atk_anim.track_insert_key(t_atk, 0.0, Vector3.ONE)
	atk_anim.track_insert_key(t_atk, windup_time * 0.8, Vector3(1.15, 0.85, 1.15))
	atk_anim.track_insert_key(t_atk, windup_time, Vector3(0.9, 1.15, 0.9))
	anim_lib.add_animation(attack_name, atk_anim)

	var death_anim := Animation.new()
	death_anim.length = 1.0
	var t_death := death_anim.add_track(Animation.TYPE_VALUE)
	death_anim.track_set_path(t_death, "BodyMesh:scale")
	death_anim.track_insert_key(t_death, 0.0, Vector3.ONE)
	death_anim.track_insert_key(t_death, 0.4, Vector3(1.3, 0.15, 1.3))
	anim_lib.add_animation(death_name, death_anim)

	anim_player.add_animation_library("", anim_lib)

func _build_labels() -> void:
	status_label = Label3D.new()
	status_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	status_label.font_size = 14
	status_label.outline_size = 4
	status_label.outline_modulate = Color(0, 0, 0, 0.8)
	status_label.visibility_range_end = 16.0
	status_label.position.y = _top() + 0.35
	add_child(status_label)

func _top() -> float:
	return maxf(body_height, body_radius * 2.0)

func _update_label() -> void:
	if status_label == null or pools == null:
		return
	if state == State.DEAD:
		status_label.text = "%s (derrotado)" % display_name
	else:
		status_label.text = "%s  %d/%d" % [display_name, ceili(pools.current_health), int(stats.get_stat(&"max_health"))]

func _physics_process(delta: float) -> void:
	if _flash_timer > 0.0:
		_flash_timer -= delta
		if _flash_timer <= 0.0:
			_set_overlay(null)
	if _hitstop > 0.0:
		# Hitstop: animação e relógio do estado param juntos (só este monstro)
		_hitstop -= delta
		if _hitstop <= 0.0 and anim_player:
			anim_player.speed_scale = 1.0
		return
	_state_time += delta

	var player := _target()
	var to_player: Vector3 = (player.global_position - global_position) if player else Vector3.ZERO
	to_player.y = 0.0
	var dist: float = to_player.length() if player else INF
	var move_dir := Vector3.ZERO
	var speed: float = 0.0

	match state:
		State.WANDER:
			if dist < aggro_range:
				_set_state(State.CHASE)
			else:
				var to_target := _wander_target - global_position
				to_target.y = 0.0
				if to_target.length() < 0.4:
					_wander_wait -= delta
					if _wander_wait <= 0.0:
						var a: float = _rng.randf() * TAU
						_wander_target = home + Vector3(cos(a), 0, sin(a)) * _rng.randf_range(1.0, wander_radius)
						_wander_wait = _rng.randf_range(1.5, 4.0)
				else:
					move_dir = to_target.normalized()
					speed = move_speed * 0.45
		State.CHASE:
			if player == null or (_dist_home() > leash_range and Time.get_ticks_msec() > _taunted_until_ms):
				_set_state(State.RETURN)
			elif dist <= attack_range:
				_set_state(State.WINDUP)
			else:
				move_dir = to_player / dist
				speed = move_speed
		State.WINDUP:
			if player:
				_face(to_player, delta * 3.0)
			if _state_time >= windup_time:
				_set_state(State.ATTACK)
		State.ATTACK:
			if _state_time >= attack_active:
				_set_state(State.RECOVER)
		State.RECOVER:
			if _state_time >= recover_time:
				_set_state(State.CHASE)
		State.STAGGER:
			if not pools.is_poise_broken:
				_set_state(State.CHASE)
		State.RETURN:
			var to_home := home - global_position
			to_home.y = 0.0
			if to_home.length() < 0.8:
				pools.reset_all()
				_set_state(State.WANDER)
			else:
				move_dir = to_home.normalized()
				speed = move_speed
		State.DEAD:
			if _state_time >= CORPSE_HIDE_TIME and model and model.visible:
				model.visible = false
			if _state_time >= respawn_delay and not _player_near_home():
				respawn()

	if move_dir != Vector3.ZERO:
		_face(move_dir, delta)
	velocity.x = move_dir.x * speed + _knockback.x
	velocity.z = move_dir.z * speed + _knockback.z
	_knockback = _knockback.move_toward(Vector3.ZERO, 14.0 * delta)
	if flying and state != State.DEAD:
		velocity.y = (_ground_y() + fly_height - global_position.y) * 4.0
	elif not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = 0.0
	move_and_slide()

	if state in [State.WANDER, State.CHASE, State.RETURN]:
		_play(anim_move if speed > 0.1 else anim_idle)

func _target() -> Player:
	var p := get_tree().get_first_node_in_group("player") as Player
	if p == null or p.is_downed:
		return null
	return p

func _player_near_home() -> bool:
	var p := get_tree().get_first_node_in_group("player") as Node3D
	return p != null and Vector2(p.global_position.x - home.x, p.global_position.z - home.z).length() < respawn_clear_range

func _dist_home() -> float:
	return Vector2(global_position.x - home.x, global_position.z - home.z).length()

func _face(dir: Vector3, weight: float) -> void:
	rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), clampf(weight * 8.0, 0.0, 1.0))

func _ground_y() -> float:
	var from := global_position + Vector3.UP * 2.0
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 30.0, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.position.y if hit else home.y

func _set_state(new_state: State) -> void:
	state = new_state
	_state_time = 0.0
	match new_state:
		State.WINDUP:
			_play_timed(anim_attack, windup_time + attack_active)
		State.ATTACK:
			hitbox.activate_with_params(attack_active, damage, damage_type, poise_damage, 1.0)
		State.STAGGER:
			_set_overlay(null)
			hitbox.deactivate()
			_play(anim_hit, 0.5, true)
		State.DEAD:
			_set_overlay(null)
			hitbox.deactivate()
			_play(anim_death, 1.0, true)

## Volta inteiro para casa.
func respawn() -> void:
	global_position = home
	velocity = Vector3.ZERO
	pools.reset_all()
	hurtbox.set_deferred(&"monitorable", true)
	if model:
		model.visible = true
	_set_state(State.WANDER)
	_update_label()

func _on_health_depleted() -> void:
	_set_state(State.DEAD)
	hurtbox.set_deferred(&"monitorable", false)
	_update_label()

func _on_poise_broken() -> void:
	if state != State.DEAD:
		_set_state(State.STAGGER)

## Chamado pela Hurtbox: pisca, reage e entra em perseguição se estava distraído.
func on_hit_feedback(_hit: HitEvent, result: Dictionary) -> void:
	if state == State.DEAD or result.get(&"effective_damage", 0.0) <= 0.0:
		return
	_set_overlay(_hit_mat)
	_flash_timer = 0.08
	if state in [State.WANDER, State.RETURN]:
		_set_state(State.CHASE)
	elif state == State.RECOVER:
		_play(anim_hit, 1.0, true)

## Peso do golpe (CombatFeel): congela a animação e o estado por um instante
func apply_hitstop(duration: float) -> void:
	if state == State.DEAD or duration <= _hitstop:
		return
	_hitstop = duration
	if anim_player:
		anim_player.speed_scale = 0.0

func apply_knockback(impulse: Vector3) -> void:
	if state == State.DEAD or flying:
		return
	_knockback += impulse
	if _knockback.length() > 9.0:
		_knockback = _knockback.normalized() * 9.0

## Brado: larga o que estava fazendo e vai atrás de quem gritou por 6 s
func taunt(_who: Node3D) -> void:
	if state == State.DEAD:
		return
	_taunted_until_ms = Time.get_ticks_msec() + 6000
	if state in [State.WANDER, State.RETURN, State.RECOVER]:
		_set_state(State.CHASE)

func _set_overlay(mat: Material) -> void:
	for m in _meshes:
		m.material_overlay = mat

func _resolve(anim: StringName) -> StringName:
	if anim_player == null or anim.is_empty():
		return &""
	for a in anim_player.get_animation_list():
		if String(a).ends_with(String(anim)):
			return a
	return &""

func _play(anim: StringName, speed: float = 1.0, restart: bool = false) -> void:
	var full := _resolve(anim)
	if full == &"":
		return
	anim_player.speed_scale = speed
	if anim_player.current_animation == full and not restart:
		return
	anim_player.play(full, 0.15)
	if restart:
		anim_player.seek(0.0, true)

func _play_timed(anim: StringName, duration: float) -> void:
	var full := _resolve(anim)
	if full == &"" or duration <= 0.0:
		return
	_play(anim, anim_player.get_animation(full).length / duration, true)
