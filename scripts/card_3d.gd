class_name Card3D
extends Node3D

## Representação 3D interativa de uma Carta Colecionável (GDD-07 e B08).
## Suporta tilt holográfico suave, giro (flip) em 180° e inspeção 3D orbital.
## O diorama fica "dentro" da carta: só aparece pela janela da moldura (portal via stencil).

signal card_clicked()
signal flip_completed(is_front: bool)

@export var max_tilt_angle: float = 22.0
@export var tilt_lerp_speed: float = 12.0
@export var flip_speed: float = 8.0
@export var auto_spin: bool = false
@export var auto_spin_speed: float = 0.8
## Balanço suave quando o cursor não está sobre o palco, para mostrar a profundidade do diorama
@export var idle_sway_angle: float = 9.0
@export var idle_float_height: float = 0.05

@onready var pivot: Node3D = $Pivot
@onready var card_root: Node3D = $Pivot/CardRoot
@onready var container_anchor: Node3D = $Pivot/CardRoot/ContainerAnchor
@onready var front_anchor: Node3D = $Pivot/CardRoot/FrontAnchor
@onready var mask_anchor: Node3D = $Pivot/CardRoot/MaskAnchor
@onready var back_anchor: Node3D = $Pivot/CardRoot/BackAnchor
@onready var diorama_anchor: Node3D = $Pivot/CardRoot/DioramaAnchor
@onready var holo_sheen: MeshInstance3D = $Pivot/CardRoot/HoloSheen
@onready var rim_light: OmniLight3D = $Pivot/RimLight
@onready var sparkles: GPUParticles3D = $Sparkles

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
var _is_hovered: bool = false
var _time: float = 0.0
var _reveal: float = 1.0

const CARD_FRONT_SCENE = preload("res://assets/cards_3d/card_kit/glTF/0_Card_Front.gltf")
const CARD_BACK_SCENE = preload("res://assets/cards_3d/card_kit/glTF/0_Card_Back.gltf")
const CARD_CONTAINER_SCENE = preload("res://assets/cards_3d/card_kit/glTF/0_Card_Container.gltf")
const CARD_MASK_SCENE = preload("res://assets/cards_3d/card_kit/glTF/0_Card_Mask.gltf")

# A janela grava o stencil e o diorama só desenha onde ele foi gravado.
# Ambos vão na passada transparente para que a ordem (máscara antes do conteúdo) seja garantida.
const PORTAL_STENCIL_REF: int = 1
const PORTAL_MASK_PRIORITY: int = -20
const PORTAL_CONTENT_PRIORITY: int = -10

# Brilho de foil por raridade: [força, arco-íris]
const HOLO_BY_RARITY: Dictionary = {
	CardData.Rarity.COMMON: [0.0, 0.0],
	CardData.Rarity.UNCOMMON: [0.10, 0.0],
	CardData.Rarity.RARE: [0.22, 0.25],
	CardData.Rarity.LEGENDARY: [0.38, 1.0],
}
const SPARKLE_RATIO_BY_RARITY: Dictionary = {
	CardData.Rarity.COMMON: 0.15,
	CardData.Rarity.UNCOMMON: 0.35,
	CardData.Rarity.RARE: 0.65,
	CardData.Rarity.LEGENDARY: 1.0,
}

func _ready() -> void:
	_setup_anchors()
	_setup_base_meshes()
	if sparkles and sparkles.process_material:
		sparkles.process_material = sparkles.process_material.duplicate()
	if holo_sheen and holo_sheen.mesh:
		holo_sheen.mesh = holo_sheen.mesh.duplicate()
		holo_sheen.mesh.material = holo_sheen.mesh.material.duplicate()

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
		if mask_anchor == null:
			mask_anchor = card_root.get_node_or_null("MaskAnchor")
		if back_anchor == null:
			back_anchor = card_root.get_node_or_null("BackAnchor")
		if diorama_anchor == null:
			diorama_anchor = card_root.get_node_or_null("DioramaAnchor")
		if holo_sheen == null:
			holo_sheen = card_root.get_node_or_null("HoloSheen")
	if rim_light == null and pivot != null:
		rim_light = pivot.get_node_or_null("RimLight")
	if sparkles == null:
		sparkles = get_node_or_null("Sparkles")

func _setup_base_meshes() -> void:
	_setup_anchors()
	# Caixa externa do kit: só serve para o truque sem stencil, fica oculta
	if container_anchor and container_anchor.get_child_count() == 0 and CARD_CONTAINER_SCENE:
		var c = CARD_CONTAINER_SCENE.instantiate()
		container_anchor.add_child(c)

	# Instancia face frontal
	if front_anchor and front_anchor.get_child_count() == 0 and CARD_FRONT_SCENE:
		var f = CARD_FRONT_SCENE.instantiate()
		front_anchor.add_child(f)

	# Janela do portal
	if mask_anchor and mask_anchor.get_child_count() == 0 and CARD_MASK_SCENE:
		var m = CARD_MASK_SCENE.instantiate()
		mask_anchor.add_child(m)
		_apply_material_recursive(m, _make_mask_material())

	# Instancia verso da carta
	if back_anchor and back_anchor.get_child_count() == 0 and CARD_BACK_SCENE:
		var b = CARD_BACK_SCENE.instantiate()
		back_anchor.add_child(b)

func _process(delta: float) -> void:
	_time += delta
	_reveal = minf(_reveal + delta * 2.2, 1.0)

	# Rotação suave do giro (flip)
	_current_flip_angle = lerp_angle(_current_flip_angle, _target_flip_angle, flip_speed * delta)

	if auto_spin and not _is_manual_orbit:
		_manual_yaw += auto_spin_speed * delta

	# Interpolação suave do tilt do cursor
	_current_tilt_x = lerp(_current_tilt_x, _target_tilt_x, tilt_lerp_speed * delta)
	_current_tilt_y = lerp(_current_tilt_y, _target_tilt_y, tilt_lerp_speed * delta)

	var sway_yaw := 0.0
	var sway_pitch := 0.0
	if not _is_hovered and not _is_manual_orbit:
		sway_yaw = deg_to_rad(idle_sway_angle) * sin(_time * 0.7)
		sway_pitch = deg_to_rad(idle_sway_angle * 0.35) * sin(_time * 0.53 + 1.0)

	if pivot:
		pivot.rotation.x = _current_tilt_x + _manual_pitch + sway_pitch
		pivot.rotation.y = _current_tilt_y + _current_flip_angle + _manual_yaw + sway_yaw

	if card_root:
		# Pulo no meio do giro e flutuação contínua
		var flip_progress: float = absf(angle_difference(_current_flip_angle, _target_flip_angle)) / PI
		var hop: float = sin(flip_progress * PI) * 0.35
		card_root.position = Vector3(0.0, sin(_time * 1.3) * idle_float_height, hop)
		var pop: float = 1.0 - pow(1.0 - _reveal, 3.0)
		card_root.scale = Vector3.ONE * lerpf(0.82, 1.0, pop)

	_update_face_visibility()

## Mostra só a face voltada para a câmera (o verso tapa o diorama pelo lado de dentro)
func _update_face_visibility() -> void:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null or pivot == null:
		return
	var to_cam: Vector3 = cam.global_position - pivot.global_position
	var front_visible: bool = pivot.global_basis.z.dot(to_cam) > 0.0
	if front_anchor:
		front_anchor.visible = front_visible
	if mask_anchor:
		mask_anchor.visible = front_visible
	if diorama_anchor:
		diorama_anchor.visible = front_visible
	if holo_sheen:
		holo_sheen.visible = front_visible
	if back_anchor:
		back_anchor.visible = not front_visible

## Carrega e exibe os dados de uma carta (null = carta bloqueada, mostra o verso)
func display_card(card: CardData) -> void:
	_setup_anchors()
	current_card_data = card
	_setup_base_meshes()

	# Limpa diorama anterior
	if diorama_anchor:
		for child in diorama_anchor.get_children():
			diorama_anchor.remove_child(child)
			child.free()

	_reveal = 0.0

	if card == null:
		set_flipped(true)
		_current_flip_angle = PI
		_apply_rarity_fx(null)
		return

	# Entra girando: começa de costas e vira para a frente
	set_flipped(false)
	_current_flip_angle = PI * 0.999

	# Carrega modelo 3D do diorama interno
	if not card.model_path.is_empty() and ResourceLoader.exists(card.model_path):
		var scene: PackedScene = load(card.model_path) as PackedScene
		if scene:
			var diorama = scene.instantiate()
			diorama.name = "DioramaMesh"
			diorama_anchor.add_child(diorama)
			_make_portal_content(diorama)

	_apply_rarity_fx(card)

func _apply_rarity_fx(card: CardData) -> void:
	var color: Color = card.get_rarity_color() if card else Color(0.5, 0.5, 0.6)

	# Ajusta luz da moldura com a cor de raridade
	if rim_light:
		rim_light.light_color = color
		rim_light.light_energy = 1.2 if card and card.rarity >= CardData.Rarity.RARE else 0.7

	if holo_sheen and holo_sheen.mesh and holo_sheen.mesh.material is ShaderMaterial:
		var holo: Array = HOLO_BY_RARITY.get(card.rarity, [0.0, 0.0]) if card else [0.0, 0.0]
		var mat := holo_sheen.mesh.material as ShaderMaterial
		mat.set_shader_parameter("strength", holo[0])
		mat.set_shader_parameter("rainbow", holo[1])
		mat.set_shader_parameter("tint", color)

	if sparkles:
		sparkles.emitting = card != null
		sparkles.amount_ratio = SPARKLE_RATIO_BY_RARITY.get(card.rarity, 0.2) if card else 0.0
		if sparkles.process_material is ParticleProcessMaterial:
			(sparkles.process_material as ParticleProcessMaterial).color = color.lightened(0.25)

func _make_mask_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.0, 0.0, 0.0, 0.0)
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.cull_mode = BaseMaterial3D.CULL_BACK
	m.render_priority = PORTAL_MASK_PRIORITY
	m.stencil_mode = BaseMaterial3D.STENCIL_MODE_CUSTOM
	m.stencil_flags = BaseMaterial3D.STENCIL_FLAG_WRITE
	m.stencil_compare = BaseMaterial3D.STENCIL_COMPARE_ALWAYS
	m.stencil_reference = PORTAL_STENCIL_REF
	return m

## Converte os materiais do diorama para só desenharem dentro da janela da carta
func _make_portal_content(root: Node) -> void:
	for mi in _find_meshes(root):
		for i in mi.mesh.get_surface_count():
			var src := mi.get_active_material(i) as BaseMaterial3D
			if src == null:
				continue
			var m := src.duplicate() as BaseMaterial3D
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
			m.render_priority = PORTAL_CONTENT_PRIORITY
			m.stencil_mode = BaseMaterial3D.STENCIL_MODE_CUSTOM
			m.stencil_flags = BaseMaterial3D.STENCIL_FLAG_READ
			m.stencil_compare = BaseMaterial3D.STENCIL_COMPARE_EQUAL
			m.stencil_reference = PORTAL_STENCIL_REF
			mi.set_surface_override_material(i, m)

func _apply_material_recursive(root: Node, mat: Material) -> void:
	for mi in _find_meshes(root):
		for i in mi.mesh.get_surface_count():
			mi.set_surface_override_material(i, mat)

func _find_meshes(root: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if root is MeshInstance3D and (root as MeshInstance3D).mesh != null:
		out.append(root)
	for child in root.get_children():
		out.append_array(_find_meshes(child))
	return out

## Aplica inclinação holográfica proporcional ao mouse (-1.0 a +1.0)
func set_tilt_normalized(offset: Vector2) -> void:
	_target_tilt_x = deg_to_rad(-offset.y * max_tilt_angle)
	_target_tilt_y = deg_to_rad(offset.x * max_tilt_angle)

## Cursor entrou/saiu do palco: com cursor fora, a carta balança sozinha
func set_hovered(hovered: bool) -> void:
	_is_hovered = hovered
	if not hovered:
		_target_tilt_x = 0.0
		_target_tilt_y = 0.0

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
