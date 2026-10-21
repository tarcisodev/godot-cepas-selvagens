class_name Card3D
extends Node3D

## Representação 3D interativa de uma Carta Colecionável (GDD-07 e B08).
## Suporta tilt holográfico suave, giro (flip) em 180° e inspeção 3D orbital.

signal card_clicked()
signal flip_completed(is_front: bool)

@export var max_tilt_angle: float = 22.0
@export var tilt_lerp_speed: float = 12.0
@export var flip_speed: float = 8.0
@export var auto_spin: bool = false
@export var auto_spin_speed: float = 0.8

@onready var pivot: Node3D = $Pivot
@onready var card_root: Node3D = $Pivot/CardRoot
@onready var container_anchor: Node3D = $Pivot/CardRoot/ContainerAnchor
@onready var front_anchor: Node3D = $Pivot/CardRoot/FrontAnchor
@onready var back_anchor: Node3D = $Pivot/CardRoot/BackAnchor
@onready var diorama_anchor: Node3D = $Pivot/CardRoot/DioramaAnchor
@onready var rim_light: OmniLight3D = $Pivot/RimLight

var current_card_data: CardData
var is_flipped: bool = false

var _target_tilt_x: float = 0.0
var _target_tilt_y: float = 0.0
var _current_tilt_x: float = 0.0
var _current_tilt_y: float = 0.0

var _target_flip_angle: float = 0.0
var _current_flip_angle: float = 0.0

var _manual_yaw: float = 0.0
var _manual_pitch: float = 0.0
var _is_manual_orbit: bool = false

const CARD_FRONT_SCENE = preload("res://assets/cards_3d/card_kit/glTF/0_Card_Front.gltf")
const CARD_BACK_SCENE = preload("res://assets/cards_3d/card_kit/glTF/0_Card_Back.gltf")
const CARD_CONTAINER_SCENE = preload("res://assets/cards_3d/card_kit/glTF/0_Card_Container.gltf")

func _ready() -> void:
	_setup_anchors()
	_setup_base_meshes()

func _setup_anchors() -> void:
	if pivot == null:
		pivot = get_node_or_null("Pivot")
	if card_root == null and pivot != null:
		card_root = pivot.get_node_or_null("CardRoot")
	if card_root != null:
		if container_anchor == null:
			container_anchor = card_root.get_node_or_null("ContainerAnchor")
		if front_anchor == null:
			front_anchor = card_root.get_node_or_null("FrontAnchor")
		if back_anchor == null:
			back_anchor = card_root.get_node_or_null("BackAnchor")
		if diorama_anchor == null:
			diorama_anchor = card_root.get_node_or_null("DioramaAnchor")
	if rim_light == null and pivot != null:
		rim_light = pivot.get_node_or_null("RimLight")

func _setup_base_meshes() -> void:
	_setup_anchors()
	# Instancia container da moldura
	if container_anchor and container_anchor.get_child_count() == 0 and CARD_CONTAINER_SCENE:
		var c = CARD_CONTAINER_SCENE.instantiate()
		container_anchor.add_child(c)
	
	# Instancia face frontal
	if front_anchor and front_anchor.get_child_count() == 0 and CARD_FRONT_SCENE:
		var f = CARD_FRONT_SCENE.instantiate()
		front_anchor.add_child(f)
	
	# Instancia verso da carta
	if back_anchor and back_anchor.get_child_count() == 0 and CARD_BACK_SCENE:
		var b = CARD_BACK_SCENE.instantiate()
		back_anchor.add_child(b)

func _process(delta: float) -> void:
	# Rotação suave do giro (flip)
	_current_flip_angle = lerp_angle(_current_flip_angle, _target_flip_angle, flip_speed * delta)
	
	if auto_spin and not _is_manual_orbit:
		_manual_yaw += auto_spin_speed * delta
	
	# Interpolação suave do tilt do cursor
	_current_tilt_x = lerp(_current_tilt_x, _target_tilt_x, tilt_lerp_speed * delta)
	_current_tilt_y = lerp(_current_tilt_y, _target_tilt_y, tilt_lerp_speed * delta)
	
	if pivot:
		pivot.rotation.x = _current_tilt_x + _manual_pitch
		pivot.rotation.y = _current_tilt_y + _current_flip_angle + _manual_yaw

## Carrega e exibe os dados de uma carta
func display_card(card: CardData) -> void:
	_setup_anchors()
	current_card_data = card
	_setup_base_meshes()
	
	# Limpa diorama anterior
	if diorama_anchor:
		for child in diorama_anchor.get_children():
			diorama_anchor.remove_child(child)
			child.free()
	
	if card == null:
		return
	
	# Carrega modelo 3D do diorama interno
	if not card.model_path.is_empty() and ResourceLoader.exists(card.model_path):
		var scene: PackedScene = load(card.model_path) as PackedScene
		if scene:
			var diorama = scene.instantiate()
			diorama.name = "DioramaMesh"
			diorama_anchor.add_child(diorama)
	
	# Ajusta luz da moldura com a cor de raridade
	if rim_light:
		rim_light.light_color = card.get_rarity_color()
		rim_light.light_energy = 1.2 if card.rarity >= CardData.Rarity.RARE else 0.7

## Aplica inclinação holográfica proporcional ao mouse (-1.0 a +1.0)
func set_tilt_normalized(offset: Vector2) -> void:
	_target_tilt_x = deg_to_rad(-offset.y * max_tilt_angle)
	_target_tilt_y = deg_to_rad(offset.x * max_tilt_angle)

## Alterna entre frente e verso da carta
func toggle_flip() -> void:
	set_flipped(!is_flipped)

## Define o estado de giro (frente = false, verso = true)
func set_flipped(flipped: bool) -> void:
	is_flipped = flipped
	_target_flip_angle = PI if is_flipped else 0.0
	flip_completed.emit(!is_flipped)

## Define rotação orbital manual (ao arrastar com o mouse)
func add_manual_orbit(delta_x: float, delta_y: float) -> void:
	_is_manual_orbit = true
	_manual_yaw += delta_x * 0.012
	_manual_pitch = clampf(_manual_pitch + (delta_y * 0.012), deg_to_rad(-60.0), deg_to_rad(60.0))

## Restaura o ângulo padrão da carta
func reset_orientation() -> void:
	_is_manual_orbit = false
	_manual_yaw = 0.0
	_manual_pitch = 0.0
	_target_tilt_x = 0.0
	_target_tilt_y = 0.0
	_current_tilt_x = 0.0
	_current_tilt_y = 0.0

## Retorna se a face visível é a frontal
func is_front_facing() -> bool:
	return !is_flipped
