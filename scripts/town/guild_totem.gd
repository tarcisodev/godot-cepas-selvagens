class_name GuildTotem
extends StaticBody3D

const _GuildData = preload("res://scripts/data/guild_data.gd")
const _GuildBanner3D = preload("res://scripts/world/guild_banner_3d.gd")
const _GuildScreen = preload("res://scripts/ui/guild_screen.gd")
const _Player = preload("res://scripts/player.gd")
const _BuildablePiece = preload("res://scripts/buildable_piece.gd")

## Totem de Território de Guilda (GDD-15 §1).
## Peça monumental fincada na natureza que delimita o território do clã
## (40 m no Nível 1 a 80 m no Nível 3). Membros da guilda podem construir
## livremente dentro da área delimitada.

const DISPLAY_NAME: String = "Totem da Guilda"
const COSTS: Dictionary = { &"madeira": 15, &"pedra": 12, &"barra_ferro": 4 }
const USE_RANGE: float = 4.0

@export var guild_data: _GuildData
@export var owner_name: String = ""

var radius: float = 40.0
var placed_at_msec: int = -1

var _prompt: Label3D
var _ring_mesh: MeshInstance3D
var _banner: _GuildBanner3D
var _screen: _GuildScreen

func _ready() -> void:
	add_to_group("claim_totems")
	add_to_group("guild_totems")
	add_to_group("talkable")

	if guild_data:
		radius = guild_data.get_territory_radius()

	_build_visual()
	_build_boundary_ring()
	_setup_screen()

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
	# Colisão sólida central
	var col := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.55
	cyl.height = 3.6
	col.shape = cyl
	col.position.y = 1.8
	add_child(col)

	# Base de pedra talhada
	var stone_mat := StandardMaterial3D.new()
	stone_mat.albedo_color = Color(0.38, 0.36, 0.35)
	stone_mat.roughness = 0.9

	var base := MeshInstance3D.new()
	var base_m := CylinderMesh.new()
	base_m.top_radius = 0.8
	base_m.bottom_radius = 0.95
	base_m.height = 0.5
	base.mesh = base_m
	base.material_override = stone_mat
	base.position.y = 0.25
	add_child(base)

	# Pilar de madeira maciça
	var wood_mat := StandardMaterial3D.new()
	wood_mat.albedo_color = Color(0.32, 0.22, 0.14)
	wood_mat.roughness = 0.85

	var pillar := MeshInstance3D.new()
	var pil_m := CylinderMesh.new()
	pil_m.top_radius = 0.4
	pil_m.bottom_radius = 0.45
	pil_m.height = 3.2
	pillar.mesh = pil_m
	pillar.material_override = wood_mat
	pillar.position.y = 1.85
	add_child(pillar)

	# Estandarte 3D heráldico no topo do totem
	_banner = _GuildBanner3D.new()
	_banner.position = Vector3(0, 2.8, 0)
	if guild_data:
		_banner.set_guild(guild_data)
	add_child(_banner)

	# Prompt 3D de interação
	_prompt = Label3D.new()
	_prompt.text = "🏰 [E] Sede da Guilda"
	_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt.font_size = 14
	_prompt.outline_size = 4
	_prompt.modulate = Color(1.0, 0.82, 0.35)
	_prompt.position.y = 1.6
	_prompt.visible = false
	add_child(_prompt)

func _build_boundary_ring() -> void:
	_ring_mesh = MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = radius - 0.12
	tor.outer_radius = radius + 0.12
	_ring_mesh.mesh = tor

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var col_prim: Color = guild_data.primary_color if guild_data else Color(0.55, 0.12, 0.14)
	mat.albedo_color = Color(col_prim.r, col_prim.g, col_prim.b, 0.55)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring_mesh.material_override = mat
	_ring_mesh.position.y = 0.05
	add_child(_ring_mesh)

func _setup_screen() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 12
	add_child(layer)
	_screen = _GuildScreen.new()
	layer.add_child(_screen)

func _process(_delta: float) -> void:
	if guild_data and radius != guild_data.get_territory_radius():
		radius = guild_data.get_territory_radius()
		if _ring_mesh and _ring_mesh.mesh is TorusMesh:
			var tor: TorusMesh = _ring_mesh.mesh
			tor.inner_radius = radius - 0.12
			tor.outer_radius = radius + 0.12

	var player := get_tree().get_first_node_in_group("player") as Node3D if is_inside_tree() else null
	if _prompt:
		_prompt.visible = player != null and player.global_position.distance_to(global_position) < USE_RANGE

func talk_to(player_node: Node) -> void:
	if _screen:
		_screen.open(player_node as _Player, guild_data)

## Verifica permissão de um jogador construir dentro deste território de guilda
func can_member_build(p_username: String) -> bool:
	if guild_data:
		return guild_data.can_build(p_username)
	return p_username == owner_name
