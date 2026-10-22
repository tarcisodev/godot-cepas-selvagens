class_name ClaimTotem
extends StaticBody3D

## Totem de Território (Estaca de Reivindicação de Base / Guilda)
## Demarca uma área circular de posse onde o jogador pode construir livremente.

const BuildablePieceClass = preload("res://scripts/buildable_piece.gd")

const DISPLAY_NAME: String = "Totem de Território"
const COSTS: Dictionary = { &"madeira": 4, &"pedra": 4 }
const SIZE: Vector3 = Vector3(0.8, 2.4, 0.8)
const DEFAULT_RADIUS: float = 14.0

@export var owner_name: String = "Andarilho"
@export var guild_name: String = ""
@export var radius: float = DEFAULT_RADIUS
## Ticks (ms) de quando foi fincado; -1 = sem janela de reembolso total
var placed_at_msec: int = -1

var label_prompt: Label3D
var ring_mesh: MeshInstance3D

func _ready() -> void:
	add_to_group("claim_totems")
	add_to_group("talkable")
	
	_build_visual()
	_build_boundary_ring()
	_build_label()
	
	# Registra no ZoneManager se estiver presente na árvore
	var zm := _get_zone_manager()
	if zm and zm.has_method("register_totem"):
		zm.register_totem(self)

func _exit_tree() -> void:
	var zm := _get_zone_manager()
	if zm and zm.has_method("unregister_totem"):
		zm.unregister_totem(self)

func _get_zone_manager() -> Node:
	if not is_inside_tree():
		return null
	var node := get_tree().get_first_node_in_group("zone_manager")
	if node == null and get_node_or_null("/root/ZoneManager") != null:
		node = get_node_or_null("/root/ZoneManager")
	return node

func _build_visual() -> void:
	# Colisão do Totem
	var col := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.35
	cyl.height = 2.4
	col.shape = cyl
	col.position.y = 1.2
	add_child(col)
	
	# Base de pedra
	var base := MeshInstance3D.new()
	var base_mesh := CylinderMesh.new()
	base_mesh.top_radius = 0.5
	base_mesh.bottom_radius = 0.65
	base_mesh.height = 0.5
	base.mesh = base_mesh
	base.position.y = 0.25
	var stone_mat := StandardMaterial3D.new()
	stone_mat.albedo_color = Color(0.42, 0.42, 0.45)
	stone_mat.roughness = 0.95
	base.material_override = stone_mat
	add_child(base)
	
	# Poste de tora entalhada
	var pole := MeshInstance3D.new()
	var pole_mesh := CylinderMesh.new()
	pole_mesh.top_radius = 0.24
	pole_mesh.bottom_radius = 0.28
	pole_mesh.height = 2.0
	pole.mesh = pole_mesh
	pole.position.y = 1.3
	var wood_mat := StandardMaterial3D.new()
	wood_mat.albedo_color = Color(0.38, 0.24, 0.14)
	wood_mat.roughness = 0.85
	pole.material_override = wood_mat
	add_child(pole)
	
	# Cristal / Luz no topo do totem
	var crystal := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(0.35, 0.45, 0.35)
	crystal.mesh = prism
	crystal.position.y = 2.4
	var rune_mat := StandardMaterial3D.new()
	rune_mat.albedo_color = Color(0.2, 0.85, 0.6)
	rune_mat.emission_enabled = true
	rune_mat.emission = Color(0.15, 0.95, 0.65)
	rune_mat.emission_energy_multiplier = 1.5
	crystal.material_override = rune_mat
	add_child(crystal)
	
	var light := OmniLight3D.new()
	light.light_color = Color(0.3, 0.9, 0.65)
	light.light_energy = 0.8
	light.omni_range = 5.0
	light.position.y = 2.4
	add_child(light)

func _build_boundary_ring() -> void:
	ring_mesh = MeshInstance3D.new()
	ring_mesh.name = "PerimeterRing"
	
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_LINES)
	
	var segments := 48
	for i in segments:
		var a0 := TAU * float(i) / float(segments)
		var a1 := TAU * float(i + 1) / float(segments)
		var p0 := Vector3(cos(a0) * radius, 0.1, sin(a0) * radius)
		var p1 := Vector3(cos(a1) * radius, 0.1, sin(a1) * radius)
		st.set_color(Color(0.2, 0.9, 0.6, 0.45))
		st.add_vertex(p0)
		st.set_color(Color(0.2, 0.9, 0.6, 0.45))
		st.add_vertex(p1)
	
	ring_mesh.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mesh.material_override = mat
	ring_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring_mesh)

func _build_label() -> void:
	label_prompt = Label3D.new()
	label_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label_prompt.font_size = 22
	label_prompt.outline_size = 5
	label_prompt.outline_modulate = Color(0, 0, 0, 0.9)
	label_prompt.modulate = Color(0.7, 1.0, 0.85)
	label_prompt.visibility_range_end = 8.0
	label_prompt.position.y = 2.85
	add_child(label_prompt)
	_update_label()

func _update_label() -> void:
	if label_prompt:
		var g_text := " [%s]" % guild_name if not guild_name.is_empty() else ""
		label_prompt.text = "🏕️ Território de %s%s\nRaio: %.0fm • [E] Gerenciar Base" % [owner_name, g_text, radius]

## Interação ao apertar [E] perto do totem
func talk_to(player: Node) -> void:
	if player and player.has_signal("posture_changed"):
		player.posture_changed.emit("🏕️ Base de %s: indestrutível fora da Zona Selvagem; só o dono constrói" % owner_name)

## Desmonta o totem (mudar de lugar = desmontar). Quem chama garante que o território está vazio.
func dismantle(player: Node) -> Dictionary:
	var refunds := BuildablePieceClass.refund_costs(COSTS, placed_at_msec, player)
	queue_free()
	return refunds
