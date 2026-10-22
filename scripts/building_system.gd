class_name BuildingSystem
extends Node3D

## Gerenciador do Modo de Construção do Jogador (Fase 2)
## Ativado com [B] ou menu TAB. Mostra preview holográfico com snap de grade,
## valida zonas de bloqueio e consome materiais do inventário.

const BuildablePieceClass = preload("res://scripts/buildable_piece.gd")
const ClaimTotemClass = preload("res://scripts/claim_totem.gd")
const ZoneManagerClass = preload("res://scripts/core/zone_manager.gd")

@export var player: Player
@export var zone_manager: Node
@export var snap_grid: float = 1.0

var is_building: bool = false
var current_piece_index: int = 0
var current_rotation_y: float = 0.0

# Lista de opções de construção:
const CATALOG: Array[Dictionary] = [
	{
		"id": &"claim_totem",
		"name": "Totem de Território",
		"costs": { &"madeira": 4, &"pedra": 4 },
		"is_totem": true,
		"size": Vector3(0.8, 2.4, 0.8)
	},
	{
		"id": &"piso_madeira",
		"name": "Piso de Madeira",
		"costs": { &"madeira": 2 },
		"type": BuildablePieceClass.PieceType.PISO_MADEIRA,
		"size": Vector3(2.0, 0.12, 2.0)
	},
	{
		"id": &"parede_madeira",
		"name": "Parede de Madeira",
		"costs": { &"madeira": 3, &"fibra": 1 },
		"type": BuildablePieceClass.PieceType.PAREDE_MADEIRA,
		"size": Vector3(2.0, 2.4, 0.16)
	},
	{
		"id": &"parede_porta",
		"name": "Parede com Porta",
		"costs": { &"madeira": 4, &"fibra": 1 },
		"type": BuildablePieceClass.PieceType.PAREDE_PORTA,
		"size": Vector3(2.0, 2.4, 0.16)
	},
	{
		"id": &"telhado",
		"name": "Telhado de Palha e Madeira",
		"costs": { &"madeira": 2, &"folha": 2 },
		"type": BuildablePieceClass.PieceType.TELHADO,
		"size": Vector3(2.0, 0.9, 2.0)
	},
	{
		"id": &"cerca",
		"name": "Cerca Rústica",
		"costs": { &"galho": 2, &"fibra": 1 },
		"type": BuildablePieceClass.PieceType.CERCA,
		"size": Vector3(2.0, 0.9, 0.12)
	},
	{
		"id": &"canteiro",
		"name": "Canteiro de Cultivo",
		"costs": { &"madeira": 2, &"erva": 2 },
		"type": BuildablePieceClass.PieceType.CANTEIRO,
		"size": Vector3(1.4, 0.35, 1.4)
	}
]

var ghost_root: Node3D
var ghost_mesh: MeshInstance3D
var ghost_mat_valid: StandardMaterial3D
var ghost_mat_invalid: StandardMaterial3D
var hud_panel: CanvasLayer
var status_label: Label

func _ready() -> void:
	add_to_group("building_system")
	_init_materials()
	_build_ghost()
	_build_hud()
	set_process(false)

func _init_materials() -> void:
	ghost_mat_valid = StandardMaterial3D.new()
	ghost_mat_valid.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost_mat_valid.albedo_color = Color(0.2, 0.9, 0.4, 0.5)
	ghost_mat_valid.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	
	ghost_mat_invalid = StandardMaterial3D.new()
	ghost_mat_invalid.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost_mat_invalid.albedo_color = Color(0.9, 0.2, 0.2, 0.5)
	ghost_mat_invalid.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

func _build_ghost() -> void:
	ghost_root = Node3D.new()
	ghost_root.name = "BuildGhost"
	ghost_mesh = MeshInstance3D.new()
	ghost_root.add_child(ghost_mesh)
	ghost_root.visible = false
	add_child(ghost_root)

func _build_hud() -> void:
	hud_panel = CanvasLayer.new()
	hud_panel.name = "BuildingHUD"
	hud_panel.layer = 10
	hud_panel.visible = false
	
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	margin.add_theme_constant_override("margin_bottom", 24)
	
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	
	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(status_label)
	
	margin.add_child(vbox)
	hud_panel.add_child(margin)
	add_child(hud_panel)

func toggle_building_mode() -> void:
	set_building_mode(not is_building)

func set_building_mode(active: bool) -> void:
	is_building = active
	set_process(is_building)
	if ghost_root:
		ghost_root.visible = is_building
	if hud_panel:
		hud_panel.visible = is_building
	
	if is_building:
		_update_ghost_mesh()
		if player and player.has_signal("posture_changed"):
			player.posture_changed.emit("🏗️ Modo Construção Ativo [B para sair]")
	else:
		if player and player.has_signal("posture_changed"):
			player.posture_changed.emit("Em Pé")

func _input(event: InputEvent) -> void:
	# Tecla B liga/desliga modo construção
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_B:
		var tree := get_tree()
		if tree == null or tree.get_nodes_in_group("open_menus").is_empty():
			toggle_building_mode()
			get_viewport().set_input_as_handled()
			return
	
	if not is_building:
		return
	
	# Troca de peça com teclas numéricas 1 a 7
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode >= KEY_1 and event.keycode <= KEY_7:
			current_piece_index = event.keycode - KEY_1
			_update_ghost_mesh()
			get_viewport().set_input_as_handled()
			return
		elif event.keycode == KEY_R:
			current_rotation_y = fmod(current_rotation_y + deg_to_rad(90.0), TAU)
			get_viewport().set_input_as_handled()
			return
		elif event.keycode == KEY_ESCAPE:
			set_building_mode(false)
			get_viewport().set_input_as_handled()
			return
	
	# Clique esquerdo coloca a peça
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_try_place_piece()
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if not is_building or player == null:
		return
	
	var cam := get_viewport().get_camera_3d()
	var forward := -player.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	
	# Posiciona na frente do jogador com snap
	var target_pos := player.global_position + (forward * 3.0)
	target_pos.x = roundf(target_pos.x / snap_grid) * snap_grid
	target_pos.z = roundf(target_pos.z / snap_grid) * snap_grid
	
	# Altura do solo
	var world_node := get_parent()
	var landscape = world_node.get_node_or_null("Landscape") if world_node else null
	if landscape and landscape.has_method("get_height_at"):
		target_pos.y = landscape.get_height_at(target_pos.x, target_pos.z)
	
	ghost_root.global_position = target_pos
	ghost_root.rotation.y = current_rotation_y
	
	_validate_and_update_hud(target_pos)

func _update_ghost_mesh() -> void:
	var entry: Dictionary = CATALOG[current_piece_index]
	var sz: Vector3 = entry["size"]
	
	var box_m := BoxMesh.new()
	box_m.size = sz
	ghost_mesh.mesh = box_m
	ghost_mesh.position.y = sz.y * 0.5

func _validate_and_update_hud(pos: Vector3) -> Dictionary:
	var entry: Dictionary = CATALOG[current_piece_index]
	var zm: Node = zone_manager
	if zm == null and get_tree() != null:
		zm = get_tree().get_first_node_in_group("zone_manager")
	
	var p_name: String = player.name if player else ""
	var validation: Dictionary = { "allowed": true, "reason": "Liberado!" }
	if zm:
		validation = zm.can_build_at(pos, entry["id"], p_name)
	
	# Verifica materiais no inventário
	var has_mats: bool = true
	var missing: Array[String] = []
	if player and player.inventory:
		for mat_id in entry["costs"]:
			var req: int = entry["costs"][mat_id]
			var count: int = player.inventory.get_material_count(mat_id)
			if count < req:
				has_mats = false
				missing.append("%dx %s (%d/%d)" % [req, mat_id.capitalize(), count, req])
	
	var can_place: bool = validation["allowed"] and has_mats
	ghost_mesh.material_override = ghost_mat_valid if can_place else ghost_mat_invalid
	
	if status_label:
		var cost_str := ""
		for mat_id in entry["costs"]:
			cost_str += "%dx %s  " % [entry["costs"][mat_id], mat_id.capitalize()]
		
		var msg := "🏗️ [%d/7] %s  |  Custo: %s\n" % [current_piece_index + 1, entry["name"], cost_str]
		if not validation["allowed"]:
			msg += "❌ %s" % validation["reason"]
		elif not has_mats:
			msg += "❌ Faltam materiais: %s" % " · ".join(missing)
		else:
			msg += "✅ [Clique Esquerdo] Construir  |  [R] Girar (90°)  |  [1-7] Trocar  |  [B] Sair"
		status_label.text = msg
	
	return { "allowed": can_place, "entry": entry, "pos": pos }

func _try_place_piece() -> bool:
	var check := _validate_and_update_hud(ghost_root.global_position)
	if not check["allowed"]:
		return false
	
	var entry: Dictionary = check["entry"]
	var pos: Vector3 = check["pos"]
	
	# Consome materiais
	if player and player.inventory:
		var ok := player.inventory.consume_materials(entry["costs"])
		if not ok:
			return false
	
	# Instancia o Totem ou a Peça
	if entry.get("is_totem", false):
		var totem := ClaimTotemClass.new()
		totem.owner_name = player.name if player else "Andarilho"
		totem.position = pos
		totem.rotation.y = current_rotation_y
		get_parent().add_child(totem)
	else:
		var piece := BuildablePieceClass.new()
		piece.piece_type = entry["type"]
		piece.owner_name = player.name if player else "Andarilho"
		piece.position = pos
		piece.rotation.y = current_rotation_y
		get_parent().add_child(piece)
	
	if player and player.has_signal("posture_changed"):
		player.posture_changed.emit("✨ Construído: %s" % entry["name"])
	
	return true
