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

## Distância (horizontal) do fantasma até a peça que [X] desmonta
const DISMANTLE_REACH: float = 1.6

var is_building: bool = false
var current_piece_index: int = 0
var current_rotation_y: float = 0.0

## Opções do modo construção: o totem primeiro, depois as peças na ordem do enum.
## Nome, custo e tamanho vêm de ClaimTotem e BuildablePiece.PIECE_CONFIG (uma fonte só).
var catalog: Array[Dictionary] = build_catalog()

static func build_catalog() -> Array[Dictionary]:
	var out: Array[Dictionary] = [{
		"id": &"claim_totem",
		"name": ClaimTotemClass.DISPLAY_NAME,
		"costs": ClaimTotemClass.COSTS,
		"is_totem": true,
		"size": ClaimTotemClass.SIZE
	}]
	for t in BuildablePieceClass.PieceType.values():
		var entry: Dictionary = BuildablePieceClass.PIECE_CONFIG[t].duplicate()
		entry["type"] = t
		out.append(entry)
	return out

var ghost_root: Node3D
var ghost_mesh: MeshInstance3D
var ghost_mat_valid: StandardMaterial3D
var ghost_mat_invalid: StandardMaterial3D
var hud_panel: CanvasLayer
var status_label: Label
var ghost_label: Label3D
## Giro final da prévia: direção da câmera alinhada a 90° + giro escolhido com [R]
var _ghost_yaw: float = 0.0

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
	# Motivo do bloqueio (ou "pode construir") em cima da prévia
	ghost_label = Label3D.new()
	ghost_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	ghost_label.font_size = 20
	ghost_label.outline_size = 6
	ghost_label.no_depth_test = true
	ghost_root.add_child(ghost_label)
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
	
	# Troca de peça com as teclas numéricas (1 = totem)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode >= KEY_1 and event.keycode < KEY_1 + catalog.size():
			current_piece_index = event.keycode - KEY_1
			_update_ghost_mesh()
			get_viewport().set_input_as_handled()
			return
		elif event.keycode == KEY_X:
			try_dismantle_at(ghost_root.global_position)
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
	
	# O corpo do player não gira (só o modelo e a câmera): a prévia segue a câmera
	var cam_yaw := _camera_yaw()
	var forward := Vector3(-sin(cam_yaw), 0.0, -cos(cam_yaw))
	_ghost_yaw = snappedf(cam_yaw, PI * 0.5) + current_rotation_y
	
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
	ghost_root.rotation.y = _ghost_yaw
	
	_validate_and_update_hud(target_pos)

func _update_ghost_mesh() -> void:
	var entry: Dictionary = catalog[current_piece_index]
	var sz: Vector3 = entry["size"]
	
	var box_m := BoxMesh.new()
	box_m.size = sz
	ghost_mesh.mesh = box_m
	ghost_mesh.position.y = sz.y * 0.5

func _validate_and_update_hud(pos: Vector3) -> Dictionary:
	var entry: Dictionary = catalog[current_piece_index]
	var zm := _zone_manager()

	var p_name := _owner_name()
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
	if ghost_label:
		ghost_label.position.y = entry["size"].y + 0.6
		ghost_label.modulate = Color(0.6, 1.0, 0.7) if can_place else Color(1.0, 0.55, 0.5)
		ghost_label.text = "✅ %s" % entry["name"] if can_place else ("❌ " + (validation["reason"].get_slice(":", 0) if not validation["allowed"] else "Faltam materiais"))
	
	if status_label:
		var cost_str := ""
		for mat_id in entry["costs"]:
			cost_str += "%dx %s  " % [entry["costs"][mat_id], mat_id.capitalize()]
		
		var n := catalog.size()
		var msg := "🏗️ [%d/%d] %s  |  Custo: %s\n" % [current_piece_index + 1, n, entry["name"], cost_str]
		if not validation["allowed"]:
			msg += "❌ %s" % validation["reason"]
		elif not has_mats:
			msg += "❌ Faltam materiais: %s" % " · ".join(missing)
		else:
			msg += "✅ [Clique Esquerdo] Construir  |  [R] Girar (90°)  |  [1-%d] Trocar  |  [X] Desmontar  |  [B] Sair" % n
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
	var node: Node3D
	if entry.get("is_totem", false):
		node = ClaimTotemClass.new()
	else:
		node = BuildablePieceClass.new()
		node.set("piece_type", entry["type"])
	node.set("owner_name", _owner_name())
	node.set("placed_at_msec", Time.get_ticks_msec())
	node.position = pos
	node.rotation.y = _ghost_yaw
	get_parent().add_child(node)

	_notify("✨ Construído: %s" % entry["name"])
	return true

## Desmonta a peça ou o totem do jogador mais perto de `pos`. O totem só sai com o território vazio.
func try_dismantle_at(pos: Vector3) -> bool:
	var tree := get_tree()
	if tree == null:
		return false
	var me := _owner_name()
	var best: Node3D = null
	var best_d := DISMANTLE_REACH
	for n in tree.get_nodes_in_group("built_structures") + tree.get_nodes_in_group("claim_totems"):
		var s := n as Node3D
		if s == null or s.is_queued_for_deletion():
			continue
		var d := Vector2(s.global_position.x - pos.x, s.global_position.z - pos.z).length()
		if d <= best_d:
			best = s
			best_d = d
	if best == null:
		_notify("Nada para desmontar aqui")
		return false
	var owner_of: String = best.get("owner_name")
	if not owner_of.is_empty() and owner_of != me:
		_notify("❌ Propriedade de %s" % owner_of)
		return false
	if best is ClaimTotemClass and _pieces_inside(best) > 0:
		_notify("❌ Desmonte as construções do território antes do totem")
		return false
	var refunds: Dictionary = best.call("dismantle", player)
	var parts: Array[String] = []
	for mat_id in refunds:
		parts.append("%dx %s" % [refunds[mat_id], String(mat_id).capitalize()])
	_notify("🔨 Desmontado • Devolvido: %s" % (" · ".join(parts) if not parts.is_empty() else "nada"))
	return true

func _pieces_inside(totem: Node3D) -> int:
	var count := 0
	for n in get_tree().get_nodes_in_group("built_structures"):
		var s := n as Node3D
		if s and not s.is_queued_for_deletion():
			var d := Vector2(s.global_position.x - totem.global_position.x, s.global_position.z - totem.global_position.z).length()
			if d <= float(totem.get("radius")):
				count += 1
	return count

func _zone_manager() -> Node:
	if zone_manager == null and is_inside_tree():
		return get_tree().get_first_node_in_group("zone_manager")
	return zone_manager

## Dono = nome do personagem (criação de personagem/save); sem nome, o do nó do player
func _owner_name() -> String:
	var save := get_tree().root.get_node_or_null("SaveGame") if is_inside_tree() else null
	var character: String = save.get("character_name") if save else ""
	if not character.is_empty():
		return character
	return String(player.name) if player else "Andarilho"

func _notify(msg: String) -> void:
	if player and player.has_signal("posture_changed"):
		player.posture_changed.emit(msg)

## Lista serializável das construções do mundo (para o SaveGame). Totens primeiro.
static func collect_structures(tree: SceneTree) -> Array:
	var out: Array = []
	for group in [&"claim_totems", &"built_structures"]:
		for n in tree.get_nodes_in_group(group):
			var s := n as Node3D
			if s == null or s.is_queued_for_deletion():
				continue
			var p := s.global_position
			var entry := {
				"kind": "totem" if group == &"claim_totems" else "piece",
				"owner": s.get("owner_name"),
				"position": [p.x, p.y, p.z],
				"rotation_y": s.rotation.y
			}
			if s is BuildablePieceClass:
				entry["type"] = BuildablePieceClass.PieceType.keys()[s.get("piece_type")]
			out.append(entry)
	return out

## Recria as construções salvas como filhos de `parent` (o mundo). Totens antes das peças.
static func restore_structures(parent: Node, list: Array) -> void:
	for entry in list:
		if not entry is Dictionary:
			continue
		var node: Node3D
		if entry.get("kind") == "totem":
			node = ClaimTotemClass.new()
		else:
			var type_name := str(entry.get("type", ""))
			if not BuildablePieceClass.PieceType.has(type_name):
				continue
			node = BuildablePieceClass.new()
			node.set("piece_type", BuildablePieceClass.PieceType[type_name])
		node.set("owner_name", str(entry.get("owner", "")))
		var p: Array = entry.get("position", [0, 0, 0])
		node.position = Vector3(float(p[0]), float(p[1]), float(p[2]))
		node.rotation.y = float(entry.get("rotation_y", 0.0))
		parent.add_child(node)

func _camera_yaw() -> float:
	var rig = player.get("camera_rig") if player else null
	if rig is Node3D:
		return (rig as Node3D).global_rotation.y
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	return cam.global_rotation.y if cam else 0.0
