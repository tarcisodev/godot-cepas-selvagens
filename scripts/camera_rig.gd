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
@export var zoom_step: float = 0.5
@export var zoom_smoothness: float = 12.0

@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D

var target_distance: float = 3.5
var is_first_person: bool = false
var pitch: float = 0.0
var yaw: float = 0.0

signal camera_mode_changed(is_first_person: bool)

func _ready() -> void:
	# Captura o mouse na tela para controle suave de visão
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	target_distance = default_distance
	spring_arm.spring_length = target_distance
	_update_camera_mode()

func _input(event: InputEvent) -> void:
	# O ESC agora abre o Menu de Pausa (pause_menu.gd), que libera o mouse.

	# Se clicou na tela com mouse solto (ex.: após alt-tab), recaptura,
	# exceto quando algum menu está aberto e precisa do cursor
	if event is InputEventMouseButton and event.pressed and Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
		if get_tree().get_nodes_in_group("open_menus").is_empty():
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		return

	# Rotação da visão pelo mouse (sensibilidade e inversão vêm das Configurações)
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		var gs: Node = get_node_or_null("/root/GameSettings")
		var sens_mult: float = float(gs.get_value("controls", "mouse_sensitivity")) if gs != null and gs.has_method("get_value") else 1.0
		var is_invert: bool = bool(gs.get_value("controls", "invert_y")) if gs != null and gs.has_method("get_value") else false
		var sensitivity: float = mouse_sensitivity * sens_mult
		var invert: float = -1.0 if is_invert else 1.0
		yaw -= event.relative.x * sensitivity
		pitch -= event.relative.y * sensitivity * invert
		pitch = clamp(pitch, min_pitch, max_pitch)

		rotation.y = yaw
		spring_arm.rotation.x = pitch

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

func _process(delta: float) -> void:
	# Interpolação suave da distância da câmera
	spring_arm.spring_length = lerp(spring_arm.spring_length, target_distance, zoom_smoothness * delta)

func _update_camera_mode() -> void:
	var was_first_person = is_first_person
	is_first_person = target_distance <= 0.25
	if was_first_person != is_first_person:
		camera_mode_changed.emit(is_first_person)
