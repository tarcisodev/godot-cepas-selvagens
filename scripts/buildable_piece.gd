class_name BuildablePiece
extends StaticBody3D

const _CookingStation = preload("res://scripts/town/cooking_station.gd")
const _GuildTotem = preload("res://scripts/town/guild_totem.gd")
const _InventoryComponent = preload("res://scripts/components/inventory_component.gd")
const _BreedingPen = preload("res://scripts/systems/breeding_pen.gd")
const _BreedingPenScreen = preload("res://scripts/ui/breeding_pen_screen.gd")

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
	CAMA,
	CALDEIRAO,
	TOTEM_GUILDA,
	COMPOSTEIRA,
	TANQUE_PEIXE,
	CERCADO_BREEDING
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
	},
	PieceType.CALDEIRAO: {
		"id": &"caldeirao",
		"name": "Caldeirão Culinário",
		"costs": { &"barra_ferro": 2, &"pedra": 3 },
		"size": Vector3(1.2, 0.9, 1.2)
	},
	PieceType.TOTEM_GUILDA: {
		"id": &"totem_guilda",
		"name": "Totem da Guilda",
		"costs": { &"madeira": 15, &"pedra": 12, &"barra_ferro": 4 },
		"size": Vector3(1.6, 3.6, 1.6)
	},
	PieceType.COMPOSTEIRA: {
		"id": &"composteira",
		"name": "Composteira de Monstros",
		"costs": { &"madeira": 4, &"pedra": 2, &"ossos": 2 },
		"size": Vector3(1.4, 0.9, 1.4)
	},
	PieceType.TANQUE_PEIXE: {
		"id": &"tanque_peixe",
		"name": "Tanque de Aquicultura",
		"costs": { &"madeira": 4, &"pedra": 4, &"quartzo_lume": 2 },
		"size": Vector3(1.8, 1.1, 1.8)
	},
	PieceType.CERCADO_BREEDING: {
		"id": &"cercado_breeding",
		"name": "Cercado de Reprodução",
		"costs": { &"madeira": 6, &"galho": 4, &"fibra": 2, &"folha": 2 },
		"size": Vector3(4.0, 1.4, 4.0)
	}
}

@export var piece_type: PieceType = PieceType.PISO_MADEIRA
@export var owner_name: String = ""
## Ticks (ms) de quando foi colocada; -1 = sem janela de reembolso total (ex.: veio do save).
var placed_at_msec: int = -1

var is_door_open: bool = false
var door_pivot: Node3D
var label_prompt: Label3D
var pen: _BreedingPen = null
var _pen_screen: _BreedingPenScreen = null

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

		PieceType.CALDEIRAO:
			var cauldron := _CookingStation.new()
			cauldron.name = "CookingStation"
			add_child(cauldron)

		PieceType.TOTEM_GUILDA:
			var gtotem := _GuildTotem.new()
			gtotem.name = "GuildTotem"
			gtotem.owner_name = owner_name
			add_child(gtotem)

		PieceType.COMPOSTEIRA:
			_build_composter(sz)

		PieceType.TANQUE_PEIXE:
			_build_fish_tank(sz)

		PieceType.CERCADO_BREEDING:
			_build_breeding_pen(sz)

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

## Composteira: caixa de madeira com adubo orgânico fumegante
func _build_composter(sz: Vector3) -> void:
	_build_box(sz, Vector3(0, sz.y * 0.5, 0), Color(0.42, 0.28, 0.16))
	var soil := MeshInstance3D.new()
	var s_box := BoxMesh.new()
	s_box.size = Vector3(sz.x * 0.8, 0.2, sz.z * 0.8)
	soil.mesh = s_box
	var s_mat := StandardMaterial3D.new()
	s_mat.albedo_color = Color(0.2, 0.14, 0.08)
	s_mat.roughness = 0.95
	soil.material_override = s_mat
	soil.position = Vector3(0, sz.y * 0.85, 0)
	add_child(soil)
	add_to_group("composters")
	_add_prompt("[E] Composteira (Adubar)", sz.y + 0.4)

## Tanque de Aquicultura: bacia de pedra com visor de quartzo e água
func _build_breeding_pen(sz: Vector3) -> void:
	var wood := Color(0.48, 0.33, 0.18)
	var post_sz := Vector3(0.18, sz.y, 0.18)
	for x_side in [-1.0, 1.0]:
		for z_side in [-1.0, 1.0]:
			_build_box(post_sz, Vector3(x_side * (sz.x * 0.5 - 0.1), sz.y * 0.5, z_side * (sz.z * 0.5 - 0.1)), wood)
	
	var side_rail_sz := Vector3(0.1, 0.1, sz.z - 0.2)
	for x_side in [-1.0, 1.0]:
		_build_box(side_rail_sz, Vector3(x_side * (sz.x * 0.5 - 0.1), sz.y * 0.35, 0), wood.darkened(0.1))
		_build_box(side_rail_sz, Vector3(x_side * (sz.x * 0.5 - 0.1), sz.y * 0.75, 0), wood.darkened(0.1))
	
	var back_rail_sz := Vector3(sz.x - 0.2, 0.1, 0.1)
	_build_box(back_rail_sz, Vector3(0, sz.y * 0.35, -sz.z * 0.5 + 0.1), wood.darkened(0.1))
	_build_box(back_rail_sz, Vector3(0, sz.y * 0.75, -sz.z * 0.5 + 0.1), wood.darkened(0.1))
	
	var front_rail_sz := Vector3((sz.x - 1.4) * 0.5, 0.1, 0.1)
	_build_box(front_rail_sz, Vector3(-sz.x * 0.5 + front_rail_sz.x * 0.5 + 0.1, sz.y * 0.35, sz.z * 0.5 - 0.1), wood.darkened(0.1))
	_build_box(front_rail_sz, Vector3(-sz.x * 0.5 + front_rail_sz.x * 0.5 + 0.1, sz.y * 0.75, sz.z * 0.5 - 0.1), wood.darkened(0.1))
	_build_box(front_rail_sz, Vector3(sz.x * 0.5 - front_rail_sz.x * 0.5 - 0.1, sz.y * 0.35, sz.z * 0.5 - 0.1), wood.darkened(0.1))
	_build_box(front_rail_sz, Vector3(sz.x * 0.5 - front_rail_sz.x * 0.5 - 0.1, sz.y * 0.75, sz.z * 0.5 - 0.1), wood.darkened(0.1))
	
	_build_box(Vector3(1.1, 0.45, 0.55), Vector3(-sz.x * 0.5 + 0.8, 0.225, -sz.z * 0.5 + 0.5), Color(0.38, 0.25, 0.14))
	_build_box(Vector3(0.95, 0.18, 0.42), Vector3(-sz.x * 0.5 + 0.8, 0.36, -sz.z * 0.5 + 0.5), Color(0.72, 0.65, 0.35))
	_build_box(Vector3(1.3, 0.08, 1.3), Vector3(sz.x * 0.5 - 0.9, 0.04, -sz.z * 0.5 + 0.9), Color(0.68, 0.58, 0.38))
	
	if pen == null:
		pen = _BreedingPen.new()
		pen.name = "BreedingPen"
		add_child(pen)
	
	add_to_group("breeding_pens")
	_add_prompt("[E] Cercado de Reprodução", sz.y + 0.4)

func _interact_breeding_pen(player: Node) -> void:
	if pen == null:
		pen = _BreedingPen.new()
		pen.name = "BreedingPen"
		add_child(pen)
	if _pen_screen == null:
		var layer := CanvasLayer.new()
		layer.layer = 12
		add_child(layer)
		_pen_screen = _BreedingPenScreen.new()
		layer.add_child(_pen_screen)
	_pen_screen.open(pen, player)

func _build_fish_tank(sz: Vector3) -> void:
	_build_box(sz, Vector3(0, sz.y * 0.5, 0), Color(0.45, 0.45, 0.48))
	var water := MeshInstance3D.new()
	var w_box := BoxMesh.new()
	w_box.size = Vector3(sz.x * 0.85, 0.1, sz.z * 0.85)
	water.mesh = w_box
	var w_mat := StandardMaterial3D.new()
	w_mat.albedo_color = Color(0.25, 0.65, 0.85, 0.8)
	w_mat.roughness = 0.1
	water.material_override = w_mat
	water.position = Vector3(0, sz.y * 0.8, 0)
	add_child(water)
	add_to_group("fish_tanks")
	_add_prompt("[E] Tanque de Peixes (Aquicultura)", sz.y + 0.4)

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

## Interação com porta (abrir / fechar), banco (sentar), cama, composteira e tanque
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
		return
	if piece_type == PieceType.COMPOSTEIRA:
		_interact_composter(player)
		return
	if piece_type == PieceType.TANQUE_PEIXE:
		_interact_fish_tank(player)
		return
	if piece_type == PieceType.CERCADO_BREEDING:
		_interact_breeding_pen(player)
		return

func _interact_composter(player: Node) -> void:
	if compost(player):
		if player and player.has_signal("posture_changed"):
			player.posture_changed.emit("🌱 Composteira: 1x Adubo de Monstro produzido!")
	else:
		if player and player.has_signal("posture_changed"):
			player.posture_changed.emit("🌱 Composteira: Precisa de 2x Ossos, 4x Folhas ou 1x Carne/Víscera.")

func _get_inventory(player: Node) -> _InventoryComponent:
	if player == null:
		return null
	if player.has_meta("inventory") and player.get_meta("inventory") is _InventoryComponent:
		return player.get_meta("inventory") as _InventoryComponent
	if player.get("inventory") is _InventoryComponent:
		return player.get("inventory") as _InventoryComponent
	var comp = player.get_node_or_null("InventoryComponent") as _InventoryComponent
	if comp:
		return comp
	for c in player.get_children():
		if c is _InventoryComponent:
			return c as _InventoryComponent
	return null

## Decompõe matéria orgânica/ossos em Adubo de Monstro mineralizado
func compost(player: Node, specific_mat: StringName = &"") -> bool:
	var inv := _get_inventory(player)
	if inv == null:
		return false
	
	if not specific_mat.is_empty():
		var cost: int = 2 if specific_mat == &"ossos" else (4 if specific_mat == &"folha" else 1)
		if inv.has_materials({specific_mat: cost}):
			inv.consume_materials({specific_mat: cost})
			inv.add_material(&"adubo_organico", 1, 3, [&"mineralizado"])
			return true
		return false
	
	var options := [
		{ &"ossos": 2 },
		{ &"visceras": 1 },
		{ &"carne_pequena": 1 },
		{ &"carne_media": 1 },
		{ &"folha": 4 }
	]
	for req in options:
		if inv.has_materials(req):
			inv.consume_materials(req)
			inv.add_material(&"adubo_organico", 1, 3, [&"mineralizado"])
			return true
	return false

func _interact_fish_tank(player: Node) -> void:
	if process_fish(player):
		if player and player.has_signal("posture_changed"):
			player.posture_changed.emit("🐟 Tanque: Óleo de Peixe Purificado extraído!")
	else:
		if player and player.has_signal("posture_changed"):
			player.posture_changed.emit("🐟 Tanque de Aquicultura: Precisa de 1x Peixe (Lambari, Traíra ou Dourado).")

## Processa peixes criados/depositados para extração de óleo purificado
func process_fish(player: Node) -> bool:
	var inv := _get_inventory(player)
	if inv == null:
		return false
	
	var fish_types := [&"peixe_dourado", &"peixe_traira", &"peixe_lambari"]
	for fish_id in fish_types:
		if inv.has_materials({fish_id: 1}):
			var stacks := inv.get_stacks(fish_id)
			var bonus_yield: int = 1
			if not stacks.is_empty() and stacks[0].get("quality", 1) >= 3:
				bonus_yield = 2
			elif fish_id == &"peixe_dourado":
				bonus_yield = 2
			inv.consume_materials({fish_id: 1})
			inv.add_material(&"oleo_peixe", bonus_yield, 3, [&"purificado"])
			return true
	return false

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
