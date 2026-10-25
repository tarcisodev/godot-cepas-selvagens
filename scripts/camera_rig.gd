extends Node3D
class_name CameraRig

## Sistema de Câmera Híbrida: 3ª Pessoa e 1ª Pessoa
# Permite orbitar ao redor do personagem, fazer zoom contínuo com o scroll do mouse
# e entrar em 1ª pessoa ao aproximar totalmente (ou pela tecla 'V').

@export var mouse_sensitivity: float = 0.0025
@export var min_pitch: float = deg_to_rad(-80.0) # Olhar para cima
@export var max_pitch: float = deg_to_rad(75.0)  # Olhar para baixo

# Distâncias da câmera
@export var min_distance: float = 0.0      # 0 = 1ª pessoa (nos olhos)
@export var max_distance: float = 6.0      # Distância máxima de 3ª pessoa
@export var default_distance: float = 3.5  # Distância inicial agradável
@export var aim_distance: float = 1.9      # Distância aproximada durante a mira
@export var aim_offset: Vector3 = Vector3(0.55, 0.15, 0.0) # Offset no ombro direito
@export var normal_fov: float = 75.0
@export var aim_fov: float = 58.0          # Zoom tático durante a mira
@export var zoom_step: float = 0.5
@export var zoom_smoothness: float = 12.0

@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D

var target_distance: float = 3.5
var is_first_person: bool = false
var is_aiming: bool = false
var _current_offset: Vector3 = Vector3.ZERO
var pitch: float = 0.0
var yaw: float = 0.0
## Tranco de golpe (GDD-12 §10): 0–1, cai rápido; o deslocamento é trauma² (golpe fraco quase não mexe)
var trauma: float = 0.0
const TRAUMA_DECAY: float = 2.6
const SHAKE_OFFSET: float = 0.22
var _shake_t: float = 0.0

signal camera_mode_changed(is_first_person: bool)
signal aim_mode_changed(is_aiming: bool)

func _ready() -> void:
	# Captura o mouse na tela para controle suave de visão
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	target_distance = default_distance
	spring_arm.spring_length = target_distance
	if camera:
		camera.fov = normal_fov
	_update_camera_mode()

func _input(event: InputEvent) -> void:
	# O ESC agora abre o Menu de Pausa (pause_menu.gd), que libera o mouse.

	# Segurar ou apertar [Alt] libera o cursor do mouse para interagir com os botões do HUD
	if event is InputEventKey and event.keycode == KEY_ALT and not event.echo:
		if event.pressed:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		elif get_tree().get_nodes_in_group("open_menus").is_empty() and get_tree().get_nodes_in_group("touch_controls_active").is_empty():
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		return

	# Se clicou na tela com mouse solto (ex.: após alt-tab), recaptura apenas se NÃO clicou num controle de UI/HUD
	if event is InputEventMouseButton and event.pressed and Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
		if get_viewport() and get_viewport().gui_get_hovered_control() != null:
			return
		if get_tree().get_nodes_in_group("open_menus").is_empty() and get_tree().get_nodes_in_group("touch_controls_active").is_empty():
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		return

	# Rotação da visão pelo mouse (sensibilidade e inversão vêm das Configurações)
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_by_delta(event.relative)

	# Zoom suave via scroll
	if event.is_action_pressed("zoom_in"):
		target_distance = max(min_distance, target_distance - zoom_step)
		_update_camera_mode()
	elif event.is_action_pressed("zoom_out"):
		target_distance = min(max_distance, target_distance + zoom_step)
		_update_camera_mode()

	# Tecla 'V' para alternar instantaneamente entre 1ª e 3ª pessoa
	if event.is_action_pressed("toggle_camera"):
		if is_first_person:
			target_distance = default_distance
		else:
			target_distance = min_distance
		_update_camera_mode()

## Gira a câmera por um delta de mouse ou arraste de dedo na tela (Mobile Touch)
func rotate_by_delta(relative: Vector2) -> void:
	var gs: Node = get_node_or_null("/root/GameSettings") if is_inside_tree() else null
	var sens_mult: float = float(gs.get_value("controls", "mouse_sensitivity")) if gs != null and gs.has_method("get_value") else 1.0
	var is_invert: bool = bool(gs.get_value("controls", "invert_y")) if gs != null and gs.has_method("get_value") else false
	var sensitivity: float = mouse_sensitivity * sens_mult
	var invert: float = -1.0 if is_invert else 1.0
	yaw -= relative.x * sensitivity
	pitch -= relative.y * sensitivity * invert
	pitch = clamp(pitch, min_pitch, max_pitch)
	rotation.y = yaw
	if spring_arm:
		spring_arm.rotation.x = pitch

func _process(delta: float) -> void:
	# Interpolação suave da distância da câmera, offset do ombro e FOV
	var target_dist: float = aim_distance if is_aiming and not is_first_person else target_distance
	var target_off: Vector3 = aim_offset if is_aiming and not is_first_person else Vector3.ZERO
	var target_f: float = aim_fov if is_aiming and not is_first_person else normal_fov
	var weight: float = clampf(zoom_smoothness * delta, 0.0, 1.0)

	spring_arm.spring_length = lerp(spring_arm.spring_length, target_dist, weight)
	_current_offset = _current_offset.lerp(target_off, weight)
	spring_arm.position = _current_offset
	if camera:
		camera.fov = lerp(camera.fov, target_f, weight)
		trauma = maxf(0.0, trauma - TRAUMA_DECAY * delta)
		_shake_t += delta * 38.0
		var amount: float = trauma * trauma * SHAKE_OFFSET
		camera.h_offset = sin(_shake_t * 1.3) * amount
		camera.v_offset = cos(_shake_t * 1.7) * amount

## Soma tranco na câmera (no máximo 1)
func add_trauma(amount: float) -> void:
	trauma = clampf(trauma + amount, 0.0, 1.0)

func set_aiming(aiming: bool) -> void:
	if is_aiming != aiming:
		is_aiming = aiming
		aim_mode_changed.emit(is_aiming)

## Retorna o ponto 3D no mundo para onde a retícula do centro da tela aponta
func get_aim_target(max_range: float = 60.0) -> Vector3:
	if camera == null or not is_inside_tree() or get_viewport() == null:
		return global_position + (-global_basis.z * max_range)
	
	var world_3d := get_world_3d()
	var screen_center := get_viewport().get_visible_rect().size * 0.5
	var ray_origin := camera.project_ray_origin(screen_center)
	var ray_normal := camera.project_ray_normal(screen_center)
	var ray_end := ray_origin + (ray_normal * max_range)
	if world_3d == null:
		return ray_end
	
	var space_state := world_3d.direct_space_state
	
	# Raycast contra colisão de cenário e hurtboxes de monstros (camadas 1 e 16)
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end, 1 | 16)
	var player_node := get_parent()
	if player_node:
		query.exclude = [player_node]
	
	var result := space_state.intersect_ray(query)
	if not result.is_empty():
		return result.position
	
	return ray_end

func _update_camera_mode() -> void:
	var was_first_person = is_first_person
	is_first_person = target_distance <= 0.25
	if was_first_person != is_first_person:
		camera_mode_changed.emit(is_first_person)
