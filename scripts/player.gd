extends CharacterBody3D
class_name Player

## Controlador do Personagem: Andarilho Contemplativo
# Suporte a agachar (Ctrl), andar lento (Alt), correr (Shift),
# sentar/descansar e animação procedural suave.

@export_group("Velocidades")
@export var slow_walk_speed: float = 2.0
@export var walk_speed: float = 3.8
@export var sprint_speed: float = 7.0
@export var crouch_speed: float = 1.7
@export var acceleration: float = 8.0
@export var friction: float = 10.0
@export var jump_velocity: float = 4.2
@export var rotation_speed: float = 10.0

const CameraRigScript = preload("res://scripts/camera_rig.gd")

@export_group("Referências")
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var camera_rig: Node3D = $CameraRig
@onready var visual_mesh: Node3D = $VisualMesh
@onready var character_visual: CharacterVisual = get_node_or_null("VisualMesh/CharacterVisual")
@onready var stats: StatsComponent = $StatsComponent
@onready var pools: PoolsComponent = $PoolsComponent
@onready var attack_hitbox: HitboxComponent = $VisualMesh/AttackHitbox
@onready var mastery: MasteryComponent = get_node_or_null("MasteryComponent")
@onready var inventory: InventoryComponent = get_node_or_null("InventoryComponent")
@onready var card_collection: CardCollectionComponent = get_node_or_null("CardCollectionComponent")

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var is_first_person: bool = false
var is_crouching: bool = false
var is_sitting: bool = false
var is_dodging: bool = false
var is_attacking: bool = false
var is_casting: bool = false
var dodge_timer: float = 0.0
var attack_timer: float = 0.0
var cast_timer: float = 0.0
var dodge_dir: Vector3 = Vector3.FORWARD
const DODGE_DURATION: float = 0.36
const DODGE_SPEED: float = 8.5
const ATTACK_DURATION: float = 0.32
const ATTACK_VIGOR_COST: float = 14.0
const CAST_DURATION: float = 0.48
const CAST_ETHER_COST: float = 20.0
# Golpes seguidos dentro da janela alternam a animação (combo A → B do UAL2)
const COMBO_ANIMS: Array[StringName] = [&"Sword_Regular_A", &"Sword_Regular_B"]
const COMBO_WINDOW_MS: int = 700
var combo_step: int = 0
var last_attack_ms: int = -100000

var footstep_player: AudioStreamPlayer3D
var dodge_player: AudioStreamPlayer3D
var attack_whoosh_player: AudioStreamPlayer3D
var footstep_sounds: Array[AudioStream] = []
var footstep_timer: float = 0.4

# Alturas da câmera
const STAND_CAM_Y: float = 1.5
const CROUCH_CAM_Y: float = 0.85
const SIT_CAM_Y: float = 0.65

signal posture_changed(state_name: String)

func _ready() -> void:
	add_to_group("player")
	_setup_components()

	if camera_rig and camera_rig.has_signal("camera_mode_changed"):
		camera_rig.camera_mode_changed.connect(_on_camera_mode_changed)

	_setup_footsteps()
	_setup_combat_audio()

func _setup_components() -> void:
	if not is_in_group("player"):
		add_to_group("player")
	if stats == null:
		stats = get_node_or_null("StatsComponent") as StatsComponent
	if pools == null:
		pools = get_node_or_null("PoolsComponent") as PoolsComponent
	if pools and stats:
		pools.stats = stats
	if mastery == null:
		mastery = get_node_or_null("MasteryComponent") as MasteryComponent
		if mastery == null:
			mastery = MasteryComponent.new()
			mastery.name = "MasteryComponent"
			add_child(mastery)
	if inventory == null:
		inventory = get_node_or_null("InventoryComponent") as InventoryComponent
		if inventory == null:
			inventory = InventoryComponent.new()
			inventory.name = "InventoryComponent"
			add_child(inventory)
	if inventory and stats:
		inventory.stats = stats
	if card_collection == null:
		card_collection = get_node_or_null("CardCollectionComponent") as CardCollectionComponent
		if card_collection == null:
			card_collection = CardCollectionComponent.new()
			card_collection.name = "CardCollectionComponent"
			add_child(card_collection)

func _setup_footsteps() -> void:
	if footstep_player != null:
		return
	footstep_player = AudioStreamPlayer3D.new()
	footstep_player.name = "FootstepAudio"
	footstep_player.bus = &"Efeitos"
	footstep_player.volume_db = -8.0
	footstep_player.max_distance = 18.0
	add_child(footstep_player)
	
	# Carrega 4 passos naturais na grama do kit
	for i in range(1, 5):
		var p: String = "res://assets/audio/Small_Sound_Kit/Small Sound Kit/Footsteps/S_Grass_Mono_Without_Hitting_Boot_%d.wav" % i
		var s = load(p)
		if s:
			footstep_sounds.append(s)

func _setup_combat_audio() -> void:
	if attack_whoosh_player != null:
		return
	# Áudio de corte / swing de ataque
	attack_whoosh_player = AudioStreamPlayer3D.new()
	attack_whoosh_player.name = "AttackWhooshAudio"
	attack_whoosh_player.bus = &"Efeitos"
	var whoosh_stream = load("res://assets/audio/Small_Sound_Kit/Small Sound Kit/Magic/Mgc_Ice_Arrow_Cast_01.wav")
	if whoosh_stream:
		attack_whoosh_player.stream = whoosh_stream
		attack_whoosh_player.volume_db = -6.0
		attack_whoosh_player.max_distance = 25.0
		add_child(attack_whoosh_player)
	
	# Áudio de esquiva / foley de movimento rápido
	dodge_player = AudioStreamPlayer3D.new()
	dodge_player.name = "DodgeAudio"
	dodge_player.bus = &"Efeitos"
	var dodge_stream = load("res://assets/audio/Small_Sound_Kit/Small Sound Kit/Clothes/Army_RUN_01.wav")
	if dodge_stream:
		dodge_player.stream = dodge_stream
		dodge_player.volume_db = -5.0
		dodge_player.max_distance = 20.0
		add_child(dodge_player)

func _physics_process(delta: float) -> void:
	# Aplicar gravidade
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Obter input de movimentação
	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")

	# Se estava sentado e pressionou mover, levanta automaticamente
	if is_sitting and input_dir != Vector2.ZERO:
		toggle_sit(false)

	# Agachar com Ctrl
	var wants_crouch: bool = Input.is_action_pressed("crouch") and not is_sitting
	if wants_crouch != is_crouching:
		is_crouching = wants_crouch
		_update_collision_for_crouch()
		posture_changed.emit("Agachado" if is_crouching else "Em Pé")

	# Direção no espaço 3D relativa à câmera
	var cam_yaw: float = camera_rig.global_rotation.y
	var move_direction: Vector3 = (Transform3D.IDENTITY.rotated(Vector3.UP, cam_yaw) * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	# Processar Ataque (Clique Esquerdo)
	if is_attacking:
		attack_timer -= delta
		if attack_timer <= 0.0:
			is_attacking = false
			posture_changed.emit("Em Pé")
	elif Input.is_action_just_pressed("attack") and not is_sitting and not is_dodging and not is_casting:
		if pools and pools.consume_vigor(ATTACK_VIGOR_COST):
			is_attacking = true
			attack_timer = ATTACK_DURATION
			var now_ms: int = Time.get_ticks_msec()
			combo_step = (combo_step + 1) % COMBO_ANIMS.size() if now_ms - last_attack_ms < COMBO_WINDOW_MS else 0
			last_attack_ms = now_ms
			if attack_hitbox:
				attack_hitbox.activate_with_params(0.24, 25.0, DamageType.Type.SLASH, 15.0, 1.2)
			if attack_whoosh_player and is_inside_tree() and attack_whoosh_player.is_inside_tree():
				attack_whoosh_player.pitch_scale = randf_range(0.96, 1.12)
				attack_whoosh_player.play()
			posture_changed.emit("Golpe")

	# Processar Magia com Cajado (Clique Direito / Ação 'cast') - GDD-01 §4 e B07
	if is_casting:
		cast_timer -= delta
		if cast_timer <= 0.0:
			is_casting = false
			posture_changed.emit("Em Pé")
	elif Input.is_action_just_pressed("cast") and not is_sitting and not is_dodging and not is_attacking and not is_casting:
		if pools and pools.consume_ether(CAST_ETHER_COST):
			is_casting = true
			cast_timer = CAST_DURATION
			if attack_hitbox:
				# Magia telúrica: 40 de dano TERRA e 25 de postura, cast enraizado
				attack_hitbox.activate_with_params(0.38, 40.0, DamageType.Type.EARTH, 25.0, 1.4)
			if attack_whoosh_player and is_inside_tree() and attack_whoosh_player.is_inside_tree():
				attack_whoosh_player.pitch_scale = 0.75 # Som mais grave/arcano
				attack_whoosh_player.play()
			posture_changed.emit("Conjuração")

	# Processar Esquiva / Rolamento (tecla C ou Esquiva)
	if is_dodging:
		dodge_timer -= delta
		if dodge_timer <= 0.0:
			is_dodging = false
			posture_changed.emit("Em Pé")
	elif Input.is_action_just_pressed("dodge") and is_on_floor() and not is_sitting and not is_attacking:
		var dodge_cost: float = stats.get_stat(&"dodge_cost") if stats else 25.0
		if pools and pools.consume_vigor(dodge_cost):
			is_dodging = true
			dodge_timer = DODGE_DURATION
			dodge_dir = move_direction if move_direction != Vector3.ZERO else -Transform3D.IDENTITY.rotated(Vector3.UP, cam_yaw).basis.z
			if dodge_player and is_inside_tree() and dodge_player.is_inside_tree():
				dodge_player.pitch_scale = randf_range(1.05, 1.25)
				dodge_player.play()
			posture_changed.emit("Esquiva")

	# Pulo suave (consome 12 de vigor)
	if Input.is_action_just_pressed("jump") and is_on_floor() and not is_crouching and not is_sitting and not is_dodging and not is_attacking:
		if pools == null or pools.consume_vigor(12.0):
			velocity.y = jump_velocity

	# Definir velocidade alvo
	var target_speed: float = walk_speed
	if is_dodging:
		target_speed = DODGE_SPEED
		move_direction = dodge_dir
	elif is_casting:
		target_speed = walk_speed * 0.1 # Enraizado / mobilidade severamente reduzida durante o cast (GDD-01 §4)
	elif is_attacking:
		target_speed = walk_speed * 0.4 # Reduz mobilidade durante o golpe (GDD-01 §4)
	elif is_sitting:
		target_speed = 0.0
	elif is_crouching:
		target_speed = crouch_speed
	elif Input.is_action_pressed("slow_walk"):
		target_speed = slow_walk_speed
	elif Input.is_action_pressed("sprint") and input_dir != Vector2.ZERO:
		var sprint_vigor_cost: float = 16.0 * delta
		if pools != null and pools.consume_vigor(sprint_vigor_cost):
			target_speed = sprint_speed
		else:
			target_speed = walk_speed

	# Penalidade de peso do equipamento na velocidade (Carga - GDD-01 §4 e B07)
	if not is_dodging and stats != null:
		var current_load: float = stats.get_stat(&"load")
		var load_cap: float = maxf(stats.get_stat(&"load_capacity"), 1.0)
		var load_penalty: float = clampf(1.0 - ((current_load / load_cap) * 0.35), 0.5, 1.0)
		target_speed *= load_penalty

	var target_velocity_xz: Vector3 = move_direction * target_speed
	var current_velocity_xz: Vector3 = Vector3(velocity.x, 0, velocity.z)
	var rate: float = acceleration if move_direction != Vector3.ZERO else friction
	if is_dodging:
		rate = 20.0
	var new_velocity_xz: Vector3 = current_velocity_xz.lerp(target_velocity_xz, rate * delta)

	velocity.x = new_velocity_xz.x
	velocity.z = new_velocity_xz.z

	move_and_slide()

	# Altura da câmera e colisão suaves
	_update_camera_height(delta)

	# Animação e passos
	_update_animation(Vector3(velocity.x, 0, velocity.z).length())
	_handle_footsteps(delta, input_dir)
	_handle_rotation(delta, move_direction)

func _update_collision_for_crouch() -> void:
	var shape = collision_shape.shape as CapsuleShape3D
	if shape:
		shape.height = 1.15 if is_crouching else 1.75
		collision_shape.position.y = 0.58 if is_crouching else 0.875

func _update_camera_height(delta: float) -> void:
	var target_cam_y: float = STAND_CAM_Y
	if is_sitting:
		target_cam_y = SIT_CAM_Y
	elif is_crouching:
		target_cam_y = CROUCH_CAM_Y

	camera_rig.position.y = lerp(camera_rig.position.y, target_cam_y, 8.0 * delta)

## Escolhe a animação do UAL1 pelo estado atual (prioridade: ações > postura > locomoção).
func _update_animation(speed: float) -> void:
	if character_visual == null:
		return
	var moving: bool = speed > 0.15

	if is_dodging:
		character_visual.play_timed(&"Roll", DODGE_DURATION)
	elif is_attacking:
		character_visual.play_timed(COMBO_ANIMS[combo_step], ATTACK_DURATION)
	elif is_casting:
		character_visual.play_timed(&"Spell_Simple_Shoot", CAST_DURATION)
	elif is_sitting:
		character_visual.play(&"Sitting_Idle")
	elif not is_on_floor():
		character_visual.play(&"Jump")
	elif is_crouching:
		character_visual.play(&"Crouch_Fwd" if moving else &"Crouch_Idle")
	elif not moving:
		character_visual.play(&"Idle")
	elif speed > walk_speed + 0.5:
		character_visual.play(&"Sprint", speed / sprint_speed)
	elif speed > slow_walk_speed + 0.3:
		character_visual.play(&"Jog_Fwd", speed / walk_speed)
	else:
		character_visual.play(&"Walk", maxf(speed / slow_walk_speed, 0.4))

func _handle_footsteps(delta: float, input_dir: Vector2) -> void:
	if is_on_floor() and input_dir != Vector2.ZERO and not is_sitting:
		var speed_mult: float = 1.0
		if Input.is_action_pressed("sprint"):
			speed_mult = 1.6
		elif is_crouching or Input.is_action_pressed("slow_walk"):
			speed_mult = 0.55

		footstep_timer -= delta * speed_mult
		if footstep_timer <= 0.0:
			footstep_timer = 0.44
			if footstep_player:
				if not footstep_sounds.is_empty():
					footstep_player.stream = footstep_sounds.pick_random()
				footstep_player.pitch_scale = randf_range(0.95, 1.05)
				footstep_player.volume_db = -12.0 if is_crouching else -7.0
				footstep_player.play()
	else:
		footstep_timer = 0.15

func _handle_rotation(delta: float, move_dir: Vector3) -> void:
	if is_first_person:
		visual_mesh.rotation.y = lerp_angle(visual_mesh.rotation.y, camera_rig.rotation.y, rotation_speed * 2.0 * delta)
	else:
		if move_dir.length_squared() > 0.001 and not is_sitting:
			var target_angle: float = atan2(-move_dir.x, -move_dir.z)
			visual_mesh.rotation.y = lerp_angle(visual_mesh.rotation.y, target_angle, rotation_speed * delta)

func _on_camera_mode_changed(first_person: bool) -> void:
	is_first_person = first_person
	visual_mesh.visible = !first_person

## Alterna entre sentar e levantar
func toggle_sit(force_state = null) -> void:
	if force_state != null:
		is_sitting = force_state
	else:
		is_sitting = !is_sitting
	posture_changed.emit("Sentado / Meditando" if is_sitting else "Em Pé")
