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
@onready var body_group: Node3D = $VisualMesh/BodyGroup
@onready var left_leg: MeshInstance3D = $VisualMesh/LeftLeg
@onready var right_leg: MeshInstance3D = $VisualMesh/RightLeg

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var is_first_person: bool = false
var is_crouching: bool = false
var is_sitting: bool = false

var footstep_player: AudioStreamPlayer3D
var footstep_timer: float = 0.4
var walk_phase: float = 0.0

# Alturas da câmera
const STAND_CAM_Y: float = 1.5
const CROUCH_CAM_Y: float = 0.85
const SIT_CAM_Y: float = 0.65

signal posture_changed(state_name: String)

func _ready() -> void:
	if camera_rig:
		camera_rig.camera_mode_changed.connect(_on_camera_mode_changed)

	_setup_footsteps()

func _setup_footsteps() -> void:
	footstep_player = AudioStreamPlayer3D.new()
	footstep_player.name = "FootstepAudio"
	footstep_player.bus = &"Efeitos"
	var stream = load("res://assets/audio/footstep_grass.wav")
	if stream:
		footstep_player.stream = stream
		footstep_player.volume_db = -8.0
		footstep_player.max_distance = 18.0
		add_child(footstep_player)

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

	# Pulo suave (apenas se em pé)
	if Input.is_action_just_pressed("jump") and is_on_floor() and not is_crouching and not is_sitting:
		velocity.y = jump_velocity

	# Direção no espaço 3D relativa à câmera
	var cam_yaw: float = camera_rig.global_rotation.y
	var move_direction: Vector3 = (Transform3D.IDENTITY.rotated(Vector3.UP, cam_yaw) * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	# Definir velocidade alvo
	var target_speed: float = walk_speed
	if is_sitting:
		target_speed = 0.0
	elif is_crouching:
		target_speed = crouch_speed
	elif Input.is_action_pressed("slow_walk"):
		target_speed = slow_walk_speed
	elif Input.is_action_pressed("sprint") and input_dir != Vector2.ZERO:
		target_speed = sprint_speed

	var target_velocity_xz: Vector3 = move_direction * target_speed
	var current_velocity_xz: Vector3 = Vector3(velocity.x, 0, velocity.z)
	var rate: float = acceleration if move_direction != Vector3.ZERO else friction
	var new_velocity_xz: Vector3 = current_velocity_xz.lerp(target_velocity_xz, rate * delta)

	velocity.x = new_velocity_xz.x
	velocity.z = new_velocity_xz.z

	move_and_slide()

	# Altura da câmera e colisão suaves
	_update_camera_height(delta)

	# Animação procedural e passos
	_handle_procedural_animation(delta, move_direction, current_velocity_xz.length())
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

func _handle_procedural_animation(delta: float, move_dir: Vector3, speed: float) -> void:
	if not body_group:
		return

	var is_moving: bool = speed > 0.15 and is_on_floor() and not is_sitting

	if is_sitting:
		# Posição sentada no chão
		visual_mesh.position.y = lerp(visual_mesh.position.y, -0.45, 6.0 * delta)
		left_leg.rotation.x = deg_to_rad(-80.0)
		right_leg.rotation.x = deg_to_rad(-80.0)
		body_group.position.y = lerp(body_group.position.y, -0.15, 6.0 * delta)
		return

	visual_mesh.position.y = lerp(visual_mesh.position.y, 0.0, 8.0 * delta)

	if is_moving:
		walk_phase += delta * speed * 3.4
		# Gingado do tronco e cabeça ao caminhar
		var bob_y: float = abs(sin(walk_phase)) * 0.04
		var sway_z: float = sin(walk_phase * 0.5) * 0.02
		body_group.position.y = (0.2 if is_crouching else 0.0) + bob_y
		body_group.rotation.z = sway_z

		# Movimento alternado das pernas
		var leg_swing: float = sin(walk_phase) * (0.35 if not is_crouching else 0.2)
		left_leg.rotation.x = leg_swing
		right_leg.rotation.x = -leg_swing
	else:
		# Respiração sutil parado (idle)
		var t: float = Time.get_ticks_msec() * 0.001
		var idle_breath: float = sin(t * 1.8) * 0.012
		body_group.position.y = (0.2 if is_crouching else 0.0) + idle_breath
		body_group.rotation.z = lerp(body_group.rotation.z, 0.0, 6.0 * delta)
		left_leg.rotation.x = lerp(left_leg.rotation.x, 0.0, 8.0 * delta)
		right_leg.rotation.x = lerp(right_leg.rotation.x, 0.0, 8.0 * delta)

func _handle_footsteps(delta: float, input_dir: Vector2) -> void:
	if is_on_floor() and input_dir != Vector2.ZERO and not is_sitting:
		var speed_mult: float = 1.0
		if Input.is_action_pressed("sprint"):
			speed_mult = 1.6
		elif is_crouching or Input.is_action_pressed("slow_walk"):
			speed_mult = 0.55

		footstep_timer -= delta * speed_mult
		if footstep_timer <= 0.0:
			footstep_timer = 0.46
			if footstep_player:
				footstep_player.pitch_scale = randf_range(0.92, 1.08)
				footstep_player.volume_db = -12.0 if is_crouching else -8.0
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
