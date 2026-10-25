class_name BuildablePiece
extends StaticBody3D

## Peça Modular de Construção (Piso, Parede, Porta, Telhado, Cerca, Canteiro, Bancada,
## Fogueira, Banco e Cama — as três últimas são de descanso, GDD-10 §10.5)
## Possui colisão sólida, custos de materiais, abertura de portas e desmontagem.
## PIECE_CONFIG é a única fonte de nome, custo e tamanho das peças (o BuildingSystem lê daqui).

## Desmontar até 2 min depois de colocar devolve tudo; depois, 50% (GDD-08 §8).
const FULL_REFUND_WINDOW_MS: int = 120000

enum PieceType {
	PISO_MADEIRA,
	PAREDE_MADEIRA,
	PAREDE_PORTA,
	TELHADO,
	CERCA,
	CANTEIRO,
	BANCADA,
	FOGUEIRA,
	BANCO,
	CAMA
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
	},
	PieceType.FOGUEIRA: {
		"id": &"fogueira",
		"name": "Fogueira",
		"costs": { &"pedra": 4, &"galho": 3 },
		"size": Vector3(1.1, 0.5, 1.1)
	},
	PieceType.BANCO: {
		"id": &"banco",
		"name": "Banco",
		"costs": { &"madeira": 3 },
		"size": Vector3(1.4, 0.45, 0.45)
	},
	PieceType.CAMA: {
		"id": &"cama",
		"name": "Cama",
		"costs": { &"madeira": 4, &"fibra": 4 },
		"size": Vector3(1.0, 0.5, 2.1)
	}
}

@export var piece_type: PieceType = PieceType.PISO_MADEIRA
@export var owner_name: String = ""
## Ticks (ms) de quando foi colocada; -1 = sem janela de reembolso total (ex.: veio do save).
var placed_at_msec: int = -1

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

		PieceType.FOGUEIRA:
			var fire := Campfire.new()
			fire.name = "Campfire"
			add_child(fire)

		PieceType.BANCO:
			_build_bench(sz)

		PieceType.CAMA:
			_build_bed(sz)

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

## Banco: assento e pés; sentar nele (ou do lado) é descanso de acampamento
func _build_bench(sz: Vector3) -> void:
	var wood := Color(0.5, 0.34, 0.2)
	_build_box(Vector3(sz.x, 0.08, sz.z), Vector3(0, sz.y - 0.04, 0), wood)
	for side in [-1.0, 1.0]:
		_build_box(Vector3(0.1, sz.y - 0.08, sz.z * 0.8), Vector3(side * (sz.x * 0.5 - 0.12), (sz.y - 0.08) * 0.5, 0), wood.darkened(0.15))
	add_to_group("rest_benches")
	_add_prompt("[E] Sentar no banco", sz.y + 0.5)

## Cama: estrado, colchão de fibra e travesseiro; só o dono deita
func _build_bed(sz: Vector3) -> void:
	_build_box(Vector3(sz.x, 0.25, sz.z), Vector3(0, 0.125, 0), Color(0.42, 0.28, 0.16))
	_build_box(Vector3(sz.x * 0.9, 0.14, sz.z * 0.95), Vector3(0, 0.32, 0), Color(0.78, 0.72, 0.55))
	_build_box(Vector3(sz.x * 0.6, 0.1, 0.32), Vector3(0, 0.44, -sz.z * 0.5 + 0.25), Color(0.9, 0.88, 0.8))
	add_to_group("beds")
	_add_prompt("[E] Deitar", sz.y + 0.5)

func _add_prompt(text: String, height: float) -> void:
	add_to_group("talkable")
	label_prompt = Label3D.new()
	label_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label_prompt.font_size = 18
	label_prompt.outline_size = 4
	label_prompt.text = text
	label_prompt.position = Vector3(0, height, 0)
	label_prompt.visibility_range_end = 3.0
	add_child(label_prompt)

## Interação com porta (abrir / fechar), banco (sentar) e cama (deitar, só o dono)
func talk_to(player: Node) -> void:
	if piece_type == PieceType.BANCO and player.has_method("toggle_sit"):
		if not player.get("is_sitting"):
			player.global_position = global_position + Vector3.UP * 0.5
			player.velocity = Vector3.ZERO
			player.toggle_sit(true)
		return
	if piece_type == PieceType.CAMA and player.has_method("lie_in_bed"):
		var me := BuildingSystem.owner_name_of(player)
		if owner_name != "" and owner_name != me:
			player.posture_changed.emit("🛏️ Essa cama é de %s" % owner_name)
		elif not player.get("is_sitting"):
			player.lie_in_bed(self)
		return
	if piece_type == PieceType.PAREDE_PORTA and door_pivot != null:
		is_door_open = not is_door_open
		var target_angle: float = deg_to_rad(95.0) if is_door_open else 0.0
		var tw := create_tween()
		tw.tween_property(door_pivot, "rotation:y", target_angle, 0.3).set_trans(Tween.TRANS_SINE)
		if label_prompt:
			label_prompt.text = "[E] Fechar Porta" if is_door_open else "[E] Abrir Porta"
		if player and player.has_signal("posture_changed"):
			player.posture_changed.emit("🚪 Porta %s" % ("Aberta" if is_door_open else "Fechada"))

## Desmonta a peça e devolve material (100% na janela de 2 min, senão 50%)
func dismantle(player: Node) -> Dictionary:
	var cfg: Dictionary = PIECE_CONFIG.get(piece_type, {})
	var refunds := refund_costs(cfg.get("costs", {}), placed_at_msec, player)
	queue_free()
	return refunds

## Reembolso comum a peças e totem. Arredonda para baixo: o que sobra é ralo de material.
static func refund_costs(costs: Dictionary, placed_at: int, player: Node) -> Dictionary:
	var full := placed_at >= 0 and Time.get_ticks_msec() - placed_at <= FULL_REFUND_WINDOW_MS
	var refunds: Dictionary = {}
	for mat_id in costs:
		var cost: int = costs[mat_id]
		var amount: int = cost if full else cost / 2
		if amount <= 0:
			continue
		refunds[mat_id] = amount
		if player and "inventory" in player and player.inventory != null:
			player.inventory.add_material(mat_id, amount)
	return refunds
