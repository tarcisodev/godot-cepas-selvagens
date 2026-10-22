class_name BuildablePiece
extends StaticBody3D

## Peça Modular de Construção (Piso, Parede, Porta, Telhado, Cerca, Canteiro, Bancada)
## Possui colisão sólida, custos de materiais, abertura de portas e desmontagem.

enum PieceType {
	PISO_MADEIRA,
	PAREDE_MADEIRA,
	PAREDE_PORTA,
	TELHADO,
	CERCA,
	CANTEIRO,
	BANCADA
}

const PIECE_CONFIG: Dictionary = {
	PieceType.PISO_MADEIRA: {
		"id": &"piso_madeira",
		"name": "Piso de Madeira",
		"costs": { &"madeira": 2 },
		"size": Vector3(2.0, 0.12, 2.0)
	},
	PieceType.PAREDE_MADEIRA: {
		"id": &"parede_madeira",
		"name": "Parede de Madeira",
		"costs": { &"madeira": 3, &"fibra": 1 },
		"size": Vector3(2.0, 2.4, 0.16)
	},
	PieceType.PAREDE_PORTA: {
		"id": &"parede_porta",
		"name": "Parede com Porta",
		"costs": { &"madeira": 4, &"fibra": 1 },
		"size": Vector3(2.0, 2.4, 0.16)
	},
	PieceType.TELHADO: {
		"id": &"telhado",
		"name": "Telhado de Palha e Madeira",
		"costs": { &"madeira": 2, &"folha": 2 },
		"size": Vector3(2.0, 0.9, 2.0)
	},
	PieceType.CERCA: {
		"id": &"cerca",
		"name": "Cerca Rústica",
		"costs": { &"galho": 2, &"fibra": 1 },
		"size": Vector3(2.0, 0.9, 0.12)
	},
	PieceType.CANTEIRO: {
		"id": &"canteiro",
		"name": "Canteiro de Cultivo",
		"costs": { &"madeira": 2, &"erva": 2 },
		"size": Vector3(1.4, 0.35, 1.4)
	},
	PieceType.BANCADA: {
		"id": &"bancada",
		"name": "Bancada do Rancho",
		"costs": { &"madeira": 4, &"pedra": 2 },
		"size": Vector3(1.6, 0.85, 0.8)
	}
}

@export var piece_type: PieceType = PieceType.PISO_MADEIRA
@export var owner_name: String = ""

var is_door_open: bool = false
var door_pivot: Node3D
var label_prompt: Label3D

func _ready() -> void:
	add_to_group("built_structures")
	_build_piece()

func _build_piece() -> void:
	# Limpa filhos antigos se houver
	for c in get_children():
		c.queue_free()
	
	var cfg: Dictionary = PIECE_CONFIG.get(piece_type, PIECE_CONFIG[PieceType.PISO_MADEIRA])
	var sz: Vector3 = cfg["size"]
	
	match piece_type:
		PieceType.PISO_MADEIRA:
			_build_box(sz, Vector3(0, sz.y * 0.5, 0), Color(0.48, 0.32, 0.18))
		
		PieceType.PAREDE_MADEIRA:
			_build_box(sz, Vector3(0, sz.y * 0.5, 0), Color(0.42, 0.28, 0.16))
		
		PieceType.PAREDE_PORTA:
			_build_door_wall(sz)
		
		PieceType.TELHADO:
			_build_roof(sz)
		
		PieceType.CERCA:
			_build_fence(sz)
		
		PieceType.CANTEIRO:
			_build_garden_plot(sz)
		
		PieceType.BANCADA:
			_build_workbench(sz)

func _build_box(size: Vector3, offset: Vector3, color: Color) -> void:
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	col.shape = box
	col.position = offset
	add_child(col)
	
	var mesh_inst := MeshInstance3D.new()
	var box_m := BoxMesh.new()
	box_m.size = size
	mesh_inst.mesh = box_m
	mesh_inst.position = offset
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	mesh_inst.material_override = mat
	add_child(mesh_inst)

func _build_door_wall(sz: Vector3) -> void:
	# Batente esquerdo e direito
	var post_w := 0.45
	var post_sz := Vector3(post_w, sz.y, sz.z)
	var beam_sz := Vector3(sz.x, 0.4, sz.z)
	
	# Batente Esquerdo
	_build_box(post_sz, Vector3(-sz.x * 0.5 + post_w * 0.5, sz.y * 0.5, 0), Color(0.42, 0.28, 0.16))
	# Batente Direito
	_build_box(post_sz, Vector3(sz.x * 0.5 - post_w * 0.5, sz.y * 0.5, 0), Color(0.42, 0.28, 0.16))
	# Viga Superior
	_build_box(beam_sz, Vector3(0, sz.y - 0.2, 0), Color(0.38, 0.25, 0.15))
	
	# Folha da porta móvel
	var door_w: float = sz.x - (post_w * 2.0)
	var door_h: float = sz.y - 0.4
	
	door_pivot = Node3D.new()
	door_pivot.name = "DoorPivot"
	door_pivot.position = Vector3(-sz.x * 0.5 + post_w, 0, 0)
	
	var door_mesh := MeshInstance3D.new()
	var dm := BoxMesh.new()
	dm.size = Vector3(door_w, door_h, 0.08)
	door_mesh.mesh = dm
	door_mesh.position = Vector3(door_w * 0.5, door_h * 0.5, 0)
	var dmat := StandardMaterial3D.new()
	dmat.albedo_color = Color(0.55, 0.36, 0.22)
	door_mesh.material_override = dmat
	door_pivot.add_child(door_mesh)
	
	# Colisão da porta
	var door_col := CollisionShape3D.new()
	var dcol_shape := BoxShape3D.new()
	dcol_shape.size = dm.size
	door_col.shape = dcol_shape
	door_col.position = door_mesh.position
	door_pivot.add_child(door_col)
	
	add_child(door_pivot)
	add_to_group("talkable")
	
	label_prompt = Label3D.new()
	label_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label_prompt.font_size = 18
	label_prompt.outline_size = 4
	label_prompt.text = "[E] Abrir Porta"
	label_prompt.position = Vector3(0, 1.2, 0.2)
	label_prompt.visibility_range_end = 3.0
	add_child(label_prompt)

func _build_roof(sz: Vector3) -> void:
	var mesh_inst := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = sz
	mesh_inst.mesh = prism
	mesh_inst.position.y = sz.y * 0.5
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.62, 0.52, 0.32) # Palha e folhas secas
	mat.roughness = 0.95
	mesh_inst.material_override = mat
	add_child(mesh_inst)
	
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = sz
	col.shape = box
	col.position.y = sz.y * 0.5
	add_child(col)

func _build_fence(sz: Vector3) -> void:
	# Dois mourões e duas travessas
	var post_sz := Vector3(0.14, sz.y, 0.14)
	_build_box(post_sz, Vector3(-sz.x * 0.5 + 0.1, sz.y * 0.5, 0), Color(0.48, 0.33, 0.18))
	_build_box(post_sz, Vector3(sz.x * 0.5 - 0.1, sz.y * 0.5, 0), Color(0.48, 0.33, 0.18))
	
	# Travessas horizontais
	var rail_sz := Vector3(sz.x, 0.08, 0.08)
	_build_box(rail_sz, Vector3(0, sz.y * 0.35, 0), Color(0.44, 0.30, 0.16))
	_build_box(rail_sz, Vector3(0, sz.y * 0.75, 0), Color(0.44, 0.30, 0.16))

func _build_garden_plot(sz: Vector3) -> void:
	# Borda de tábuas de madeira
	var rim_mat := StandardMaterial3D.new()
	rim_mat.albedo_color = Color(0.42, 0.28, 0.16)
	
	var soil := MeshInstance3D.new()
	var soil_m := BoxMesh.new()
	soil_m.size = sz
	soil.mesh = soil_m
	soil.position.y = sz.y * 0.5
	var soil_mat := StandardMaterial3D.new()
	soil_mat.albedo_color = Color(0.24, 0.17, 0.12) # Terra fértil escura
	soil_mat.roughness = 0.98
	soil.material_override = soil_mat
	add_child(soil)
	
	var col := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = sz
	col.shape = b
	col.position.y = sz.y * 0.5
	add_child(col)

func _build_workbench(sz: Vector3) -> void:
	_build_box(sz, Vector3(0, sz.y * 0.5, 0), Color(0.45, 0.30, 0.18))

## Interação com porta (abrir / fechar)
func talk_to(player: Node) -> void:
	if piece_type == PieceType.PAREDE_PORTA and door_pivot != null:
		is_door_open = not is_door_open
		var target_angle: float = deg_to_rad(95.0) if is_door_open else 0.0
		var tw := create_tween()
		tw.tween_property(door_pivot, "rotation:y", target_angle, 0.3).set_trans(Tween.TRANS_SINE)
		if label_prompt:
			label_prompt.text = "[E] Fechar Porta" if is_door_open else "[E] Abrir Porta"
		if player and player.has_signal("posture_changed"):
			player.posture_changed.emit("🚪 Porta %s" % ("Aberta" if is_door_open else "Fechada"))

## Devolve 50% dos materiais na desmontagem
func dismantle(player: Node) -> Dictionary:
	var cfg: Dictionary = PIECE_CONFIG.get(piece_type, {})
	var refunds: Dictionary = {}
	if cfg.has("costs"):
		for mat_id in cfg["costs"]:
			var cost: int = cfg["costs"][mat_id]
			var refund: int = maxi(1, cost / 2)
			refunds[mat_id] = refund
			if player and "inventory" in player and player.inventory != null:
				player.inventory.add_material(mat_id, refund)
	queue_free()
	return refunds
