class_name CityHub
extends Node3D

## Vila da Esperança (GDD-08 §6.1): começa em obras e cresce com o material doado pelos jogadores.
## Monta a praça (placa, estrada, carroça), as obras (TownProject), o Quadro de Obras e os
## NPCs com corpo procedural (TownNPC). Guarda a Reputação da Vila e o estado das obras no save.

const _WorldLabel = preload("res://scripts/ui/world_label.gd")
const PATH_SCENE = preload("res://assets/models/nature/RockPath_Square_Wide.gltf")
const CART_SCENE = preload("res://assets/models/props/fantasy/Stall_Cart_Empty.gltf")
const PEBBLE_SCENE = preload("res://assets/models/nature/Pebble_Round_1.gltf")
const STALL_SCENE = preload("res://assets/models/props/fantasy/Stall_Empty.gltf")
const WORKBENCH_SCENE = preload("res://assets/models/props/fantasy/Workbench.gltf")
const CAULDRON_SCENE = preload("res://assets/models/props/fantasy/Cauldron.gltf")
const POTION1_SCENE = preload("res://assets/models/props/fantasy/Potion_1.gltf")
const POTION2_SCENE = preload("res://assets/models/props/fantasy/Potion_2.gltf")
const CHEST_SCENE = preload("res://assets/models/props/fantasy/Chest_Wood.gltf")
const FENCE_SCENE = preload("res://assets/models/village/Prop_WoodenFence_Single.gltf")
const CRATE_APPLE_SCENE = preload("res://assets/models/props/fantasy/FarmCrate_Apple.gltf")
const CRATE_CARROT_SCENE = preload("res://assets/models/props/fantasy/FarmCrate_Carrot.gltf")
const BANNER1_SCENE = preload("res://assets/models/props/fantasy/Banner_1.gltf")
const BANNER2_SCENE = preload("res://assets/models/props/fantasy/Banner_2.gltf")
const AXE_SCENE = preload("res://assets/models/tools/axe.gltf")
const ALCHEMIST_DNA = preload("res://resources/characters/alchemist_dna.tres")
const BUILDER_DNA = preload("res://resources/characters/builder_dna.tres")

## Centro e raio da vila (o ZoneManager usa os mesmos valores)
const CENTER: Vector2 = Vector2(1.5, 4.5)
const PALISADE_RADIUS: float = 13.5

signal reputation_changed(value: int)

## true dentro da paliçada (+ margem): vegetação, rochas e recursos não nascem aqui
static func in_village(x: float, z: float, margin: float = 1.0) -> bool:
	return Vector2(x, z).distance_to(CENTER) < PALISADE_RADIUS + margin

@export var landscape: MeshInstance3D

## Reputação da Vila do jogador: 1 por unidade doada
var reputation: int = 0
## Mercado da Vila (GDD-05 §6): encomendas e ordens de venda atendidas pela caravana
var market := VillageMarket.new()
var _market_screen: MarketScreen
var _last_hour: int = -1

## Contratos da Vila (GDD-05 §5): sempre 3 pedidos "entregue N de um material comum"
const CONTRACT_SLOTS: int = 3
const CONTRACT_BONUS: float = 1.5
const CONTRACT_POOL: Dictionary = {
	&"madeira": Vector2i(6, 12), &"galho": Vector2i(8, 16), &"folha": Vector2i(6, 12),
	&"fibra": Vector2i(6, 10), &"pedra": Vector2i(6, 12), &"frutinha": Vector2i(4, 8),
	&"besouro": Vector2i(2, 5), &"ossos": Vector2i(2, 5), &"erva": Vector2i(4, 8), &"mel": Vector2i(1, 3),
}
## Loja da Alquimista: o ralo de moeda do slice; não compra nada de volta
const SHOP_PRICES: Dictionary = {
	&"pocao": 15, &"mega_pocao": 40, &"carne_bem_passada": 8, &"cannabis_sativa": 12, &"cannabis_indica": 14,
	&"sedativo_erva": 12,
}
signal contracts_changed()

## [{"id": material, "amount": n, "reward": $S}]
var contracts: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()

var _projects: Array[TownProject] = []
var _workers: Dictionary = {}  # project_id -> TownNPC
var _board: TownBoard
var _board_layer: CanvasLayer

func _ready() -> void:
	add_to_group("city_hub")
	if landscape == null:
		landscape = get_parent().get_node_or_null("Landscape")
	_rng.randomize()
	_fill_contracts()
	_build_town_sign()
	_build_plaza()
	_build_activity_pockets()
	_build_projects()
	_build_board()
	_spawn_city_npcs()
	_refresh_workers()

func _process(_delta: float) -> void:
	# A caravana passa pelo Mercado às 8h e às 17h (só com o Mercado pronto)
	var sun := get_parent().get_node_or_null("Sun") if get_parent() else null
	if sun == null or not "current_time_hours" in sun:
		return
	var hour := int(sun.current_time_hours)
	if hour == _last_hour:
		return
	var first := _last_hour == -1
	_last_hour = hour
	if not first and VillageMarket.CARAVAN_HOURS.has(hour) and market_open():
		var report := market.caravan_visit()
		var player := get_tree().get_first_node_in_group("player")
		if player and player.has_signal("posture_changed"):
			player.posture_changed.emit("🐪 A caravana passou pelo Mercado" + ("" if report.is_empty() else ": " + report[0] + (" e mais" if report.size() > 1 else "")))

func market_open() -> bool:
	var m := get_project(&"mercado")
	return m == null or m.is_complete()

func open_market(player: Node) -> void:
	var p := player as Player
	if p == null:
		return
	if not market_open():
		p.posture_changed.emit("Mercadora: 'As bancas ainda estão em obras. Termine o Mercado no Quadro de Obras!'")
		return
	_market_screen.open(p)

func _get_ground_y(x: float, z: float) -> float:
	if landscape and landscape.has_method("get_height_at"):
		return landscape.get_height_at(x, z)
	return 0.0

func get_projects() -> Array[TownProject]:
	return _projects

func get_project(id: StringName) -> TownProject:
	for p in _projects:
		if p.project_id == id:
			return p
	return null

## Doa material do jogador para uma obra; soma Reputação. Devolve as unidades doadas.
func donate(project: TownProject, player: Node, material_id: StringName, amount: int) -> int:
	var inv: InventoryComponent = player.get("inventory") if player else null
	var n := project.donate(inv, material_id, amount)
	if n > 0:
		reputation += n
		reputation_changed.emit(reputation)
	return n

## Entrega o contrato `index`: gasta o material (pior ★ primeiro), paga em $S e abre outro pedido.
func deliver_contract(index: int, player: Node) -> bool:
	if index < 0 or index >= contracts.size() or player == null:
		return false
	var c: Dictionary = contracts[index]
	var inv: InventoryComponent = player.get("inventory")
	var wallet: WalletComponent = player.get("wallet")
	if inv == null or wallet == null or not inv.consume_materials({c.id: c.amount}):
		return false
	wallet.add(c.reward)
	contracts.remove_at(index)
	_fill_contracts()
	contracts_changed.emit()
	return true

## Preço na loja com o desconto da Reputação: −1% a cada 25, até −10%
func shop_price(item_id: StringName) -> int:
	var base: int = SHOP_PRICES.get(item_id, 0)
	return maxi(1, roundi(base * (1.0 - shop_discount())))

func shop_discount() -> float:
	return minf(0.10, floorf(reputation / 25.0) * 0.01)

## Compra 1 item na loja da Alquimista
func buy(item_id: StringName, player: Node) -> bool:
	var wallet: WalletComponent = player.get("wallet") if player else null
	var inv: InventoryComponent = player.get("inventory") if player else null
	if not SHOP_PRICES.has(item_id) or wallet == null or inv == null:
		return false
	if not wallet.spend(shop_price(item_id)):
		return false
	inv.add_material(item_id, 1)
	return true

static func contract_reward(material_id: StringName, amount: int) -> int:
	return maxi(1, roundi(MaterialData.of(material_id).base_value * amount * CONTRACT_BONUS))

func _fill_contracts() -> void:
	while contracts.size() < CONTRACT_SLOTS:
		var options: Array = CONTRACT_POOL.keys().filter(func(id): return not contracts.any(func(c): return c.id == id))
		var id: StringName = options[_rng.randi() % options.size()]
		var range_: Vector2i = CONTRACT_POOL[id]
		var amount := _rng.randi_range(range_.x, range_.y)
		contracts.append({"id": id, "amount": amount, "reward": contract_reward(id, amount)})

func open_board(player: Node) -> void:
	if _board:
		_board.open(player as Player)

func open_shop(player: Node) -> void:
	if _board:
		_board.open_shop(player as Player)

func get_state() -> Dictionary:
	var projects := {}
	for p in _projects:
		projects[String(p.project_id)] = p.get_state()
	var saved_contracts: Array = []
	for c in contracts:
		saved_contracts.append({"id": String(c.id), "amount": c.amount, "reward": c.reward})
	return {"reputation": reputation, "projects": projects, "contracts": saved_contracts, "market": market.get_state()}

func apply_state(state: Dictionary) -> void:
	reputation = int(state.get("reputation", 0))
	if state.has("contracts"):
		contracts.clear()
		for c in state["contracts"]:
			contracts.append({"id": StringName(c.get("id", "madeira")), "amount": int(c.get("amount", 1)), "reward": int(c.get("reward", 1))})
		_fill_contracts()
		contracts_changed.emit()
	if state.has("market"):
		market.apply_state(state["market"])
	var projects: Dictionary = state.get("projects", {})
	for p in _projects:
		if projects.has(String(p.project_id)):
			p.apply_state(projects[String(p.project_id)])
	_refresh_workers()
	reputation_changed.emit(reputation)

# ---------------------------------------------------------------- obras

func _build_projects() -> void:
	_add_project({
		"id": &"poco", "start": 0, "name": "Poço da Praça", "icon": "⛲", "kind": TownProject.Kind.WELL,
		"pos": Vector2(-0.8, 2.6),
		"purpose": "Água limpa no centro da vila. Quando houver cultivo e cura, é daqui que vem a água.",
		"costs": [{&"pedra": 8}, {&"pedra": 10, &"madeira": 2}, {&"madeira": 4, &"fibra": 4}],
	})
	_add_project({
		"id": &"palicada", "start": 1, "name": "Paliçada", "icon": "🛡️", "kind": TownProject.Kind.PALISADE,
		"pos": CENTER,
		"purpose": "Cerca de toras em volta da vila, com portões ao norte e a oeste. Defesa contra o que vem dos ermos.",
		"costs": [{&"galho": 10, &"fibra": 6}, {&"madeira": 8, &"galho": 10}, {&"madeira": 6, &"pedra": 6, &"fibra": 6}],
	})
	_add_project({
		"id": &"mercado", "start": 1, "name": "Mercado", "icon": "🏪", "kind": TownProject.Kind.PAVILION,
		"pos": Vector2(5.5, 11.0), "modules": Vector2i(2, 3), "yaw": 0.0,
		"purpose": "Pavilhão coberto com bancas. Vai abrigar as ordens de compra e venda entre jogadores (GDD-05).",
		"costs": [{&"pedra": 6, &"madeira": 4}, {&"madeira": 10, &"fibra": 4}, {&"folha": 10, &"fibra": 6, &"madeira": 4}],
	})
	_add_project({
		"id": &"forja", "start": 2, "name": "Forja Pública", "icon": "⚒️", "kind": TownProject.Kind.HOUSE,
		"pos": Vector2(-4.5, -1.5), "modules": Vector2i(2, 2), "brick": true, "chimney": true, "yaw": PI * 0.5,
		"purpose": "Forja de tijolo com chaminé. Vai permitir forjar e reparar equipamento na cidade (GDD-06).",
		"costs": [{&"pedra": 10}, {&"pedra": 8, &"madeira": 6}, {&"ossos": 4, &"madeira": 6}],
	})
	_add_project({
		"id": &"taverna", "start": 1, "name": "Taverna", "icon": "🍺", "kind": TownProject.Kind.HOUSE,
		"pos": Vector2(-7.5, 5.0), "modules": Vector2i(3, 3), "chimney": true, "yaw": PI * 0.5,
		"purpose": "Casa grande de reboco e madeira. Vai ter a mesa do jogo de cartas (GDD-07) e descanso.",
		"costs": [{&"pedra": 10, &"madeira": 6}, {&"madeira": 14, &"fibra": 6}, {&"folha": 12, &"mel": 2, &"frutinha": 6}],
	})

func _add_project(d: Dictionary) -> void:
	var p := TownProject.new()
	p.name = "Obra_" + String(d["id"])
	p.project_id = d["id"]
	p.display_name = d["name"]
	p.icon = d["icon"]
	p.kind = d["kind"]
	p.purpose = d["purpose"]
	var costs: Array[Dictionary] = []
	costs.assign(d["costs"])
	p.stage_costs = costs
	p.modules = d.get("modules", Vector2i(2, 2))
	p.brick_walls = d.get("brick", false)
	p.chimney = d.get("chimney", false)
	# Jogo novo: a vila já começou (lotes, pisos, paredes); o resto depende das doações
	p.stage = d.get("start", 0)
	var pos: Vector2 = d["pos"]
	if p.kind == TownProject.Kind.PALISADE:
		p.ring_center = CENTER
		p.ring_radius = PALISADE_RADIUS
		p.gate_angles.assign([0.0, 270.0])  # norte (morro da besta) e oeste (arena)
		p.position = Vector3.ZERO
	else:
		p.position = Vector3(pos.x, _get_ground_y(pos.x, pos.y), pos.y)
		p.rotation.y = d.get("yaw", 0.0)
	p.stage_completed.connect(_on_stage_completed)
	add_child(p)
	_projects.append(p)

func _on_stage_completed(project: TownProject, stage: int) -> void:
	_refresh_workers()
	var player := get_tree().get_first_node_in_group("player") if is_inside_tree() else null
	if player and player.has_signal("posture_changed"):
		var msg := "✅ %s concluída!" % project.display_name if project.is_complete() else "🏗️ %s: %s pronta!" % [project.display_name, TownProject.STAGE_NAMES[stage - 1]]
		player.posture_changed.emit(msg)

## Um trabalhador em cada obra em andamento, com o gesto da etapa
func _refresh_workers() -> void:
	var anims: Array[StringName] = [&"Interact", &"Fixing_Kneeling", &"TreeChopping"]
	for p in _projects:
		var w: TownNPC = _workers.get(p.project_id)
		if p.is_complete():
			if w:
				w.queue_free()
				_workers.erase(p.project_id)
			continue
		if w == null:
			w = TownNPC.new()
			w.name = "Trabalhador_" + String(p.project_id)
			w.dna = CharacterDNA.randomized(hash(p.project_id) % 100000)
			w.tool_scene = AXE_SCENE
			w.look_at_player = false
			var spot := _worker_spot(p)
			w.position = Vector3(spot.x, _get_ground_y(spot.x, spot.y), spot.y)
			w.rotation.y = atan2(-(p.global_position.x - spot.x), -(p.global_position.z - spot.y)) if p.kind != TownProject.Kind.PALISADE else 0.0
			add_child(w)
			_workers[p.project_id] = w
		w.idle_anim = anims[clampi(p.stage, 0, 2)]
		if w.visual:
			w.visual.play(w.idle_anim)

func _worker_spot(p: TownProject) -> Vector2:
	match p.kind:
		TownProject.Kind.PALISADE:
			return CENTER + Vector2(-PALISADE_RADIUS + 1.6, 3.0)
		TownProject.Kind.WELL:
			return Vector2(p.position.x + 1.8, p.position.z - 0.8)
		_:
			var h := Vector2(p.modules) * TownProject.MODULE * 0.5
			var local := Vector3(h.x + 1.0, 0, h.y * 0.4).rotated(Vector3.UP, p.rotation.y)
			return Vector2(p.position.x + local.x, p.position.z + local.z)

# ---------------------------------------------------------------- praça e NPCs

func _build_town_sign() -> void:
	var sign_label := _WorldLabel.make(_WorldLabel.Kind.SIGN, "")
	sign_label.name = "TownSign"
	sign_label.full_text = "🏛️ VILA DA ESPERANÇA\nEm obras • ajude a construir"
	sign_label.modulate = Color(1.0, 0.9, 0.6)
	sign_label.sign_range = 30.0
	sign_label.position = Vector3(1.5, _get_ground_y(1.5, -7.5) + 3.6, -7.5)
	add_child(sign_label)

func _build_plaza() -> void:
	var cart := CART_SCENE.instantiate() as Node3D
	cart.position = Vector3(6.2, _get_ground_y(6.2, 8.5), 8.5)
	cart.rotation.y = deg_to_rad(-45.0)
	cart.scale = Vector3.ONE * 0.75
	add_child(cart)
	for b in [[BANNER1_SCENE, Vector2(-1.8, -3.2)], [BANNER2_SCENE, Vector2(4.8, -3.2)]]:
		var banner := (b[0] as PackedScene).instantiate() as Node3D
		var p: Vector2 = b[1]
		banner.position = Vector3(p.x, _get_ground_y(p.x, p.y), p.y)
		banner.scale = Vector3.ONE * 0.8
		add_child(banner)

	# Estrada do portão norte até a praça e o mercado com ancoragem de terra batida e seixos
	var dirt_mat := StandardMaterial3D.new()
	dirt_mat.albedo_color = Color(0.33, 0.27, 0.18)
	dirt_mat.roughness = 0.95

	var points: Array[Vector2] = [
		Vector2(1.5, -8.5), Vector2(1.5, -6.5), Vector2(1.5, -4.5),
		Vector2(1.5, -2.5), Vector2(1.5, -0.5), Vector2(1.5, 1.5),
		Vector2(1.5, 3.5), Vector2(2.5, 5.0), Vector2(3.8, 6.8), Vector2(4.8, 8.4)
	]
	for i in points.size():
		var p: Vector2 = points[i]
		var gy := _get_ground_y(p.x, p.y)

		# Ancoragem de terreno: base de terra batida mais larga que a pedra
		var dirt_base := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(2.1, 0.06, 2.1)
		dirt_base.mesh = bm
		dirt_base.material_override = dirt_mat
		dirt_base.position = Vector3(p.x, gy - 0.015, p.y)
		dirt_base.rotation.y = deg_to_rad(float(i * 15))
		add_child(dirt_base)

		# Calçamento de pedras
		var road := PATH_SCENE.instantiate() as Node3D
		road.position = Vector3(p.x, gy + 0.03, p.y)
		road.scale = Vector3.ONE * 0.85
		road.rotation.y = deg_to_rad(float(i * 15))
		add_child(road)

		# Seixos nas bordas exteriores que integram organicamente pedra, terra e grama
		var side_offset := 1.2 if (i % 2 == 0) else -1.2
		var pebble := PEBBLE_SCENE.instantiate() as Node3D
		if pebble:
			pebble.position = Vector3(p.x + side_offset, _get_ground_y(p.x + side_offset, p.y), p.y)
			pebble.scale = Vector3.ONE * (0.32 + (i % 3) * 0.06)
			pebble.rotation.y = float(i) * 1.3
			add_child(pebble)

func _build_activity_pockets() -> void:
	# --- 1. Boutique de Cosméticos do Estilista Astral (Bolsa Leste / Margem do Rio) ---
	var stall := STALL_SCENE.instantiate() as Node3D
	stall.position = Vector3(7.2, _get_ground_y(7.2, -2.4), -2.4)
	stall.rotation.y = deg_to_rad(-65.0)
	stall.scale = Vector3.ONE * 0.9
	add_child(stall)

	# Tapete decorativo de veludo que acolhe o cliente
	var rug := MeshInstance3D.new()
	var rm := BoxMesh.new()
	rm.size = Vector3(2.4, 0.02, 1.8)
	rug.mesh = rm
	var rug_mat := StandardMaterial3D.new()
	rug_mat.albedo_color = Color(0.55, 0.20, 0.35)
	rug_mat.roughness = 0.85
	rug.material_override = rug_mat
	rug.position = Vector3(6.5, _get_ground_y(6.5, -2.1) + 0.02, -2.1)
	rug.rotation.y = deg_to_rad(-65.0)
	add_child(rug)

	var chest := CHEST_SCENE.instantiate() as Node3D
	chest.position = Vector3(7.8, _get_ground_y(7.8, -1.6), -1.6)
	chest.rotation.y = deg_to_rad(-110.0)
	chest.scale = Vector3.ONE * 0.65
	add_child(chest)

	# --- 2. Ateliê Botânico da Alquimista (Bolsa Noroeste) ---
	var bench := WORKBENCH_SCENE.instantiate() as Node3D
	bench.position = Vector3(-3.8, _get_ground_y(-3.8, -3.2), -3.2)
	bench.rotation.y = deg_to_rad(45.0)
	bench.scale = Vector3.ONE * 0.85
	add_child(bench)

	var cauldron := CAULDRON_SCENE.instantiate() as Node3D
	cauldron.position = Vector3(-4.6, _get_ground_y(-4.6, -2.8), -2.8)
	cauldron.scale = Vector3.ONE * 0.75
	add_child(cauldron)

	var pot1 := POTION1_SCENE.instantiate() as Node3D
	pot1.position = Vector3(-3.6, _get_ground_y(-3.6, -3.2) + 0.78, -3.3)
	pot1.scale = Vector3.ONE * 0.65
	add_child(pot1)

	var pot2 := POTION2_SCENE.instantiate() as Node3D
	pot2.position = Vector3(-3.9, _get_ground_y(-3.9, -3.2) + 0.78, -3.1)
	pot2.scale = Vector3.ONE * 0.65
	add_child(pot2)

	# --- 3. Área Agrícola e Cercas Rústicas (Bolsa Dedicada no Fundo da Vila) ---
	# Cercado de madeira rústica delimitando o cultivo no quadrante sul
	var fence_spots: Array[Vector3] = [
		Vector3(-2.2, 0, 12.8),
		Vector3(-0.2, 0, 12.8),
		Vector3(1.8, 0, 12.8)
	]
	for fp in fence_spots:
		var fence := FENCE_SCENE.instantiate() as Node3D
		fence.position = Vector3(fp.x, _get_ground_y(fp.x, fp.z), fp.z)
		fence.rotation.y = deg_to_rad(90.0)
		fence.scale = Vector3.ONE * 0.95
		add_child(fence)

	var bed := MeshInstance3D.new()
	var bed_mesh := BoxMesh.new()
	bed_mesh.size = Vector3(4.2, 0.12, 2.2)
	bed.mesh = bed_mesh
	var soil_mat := StandardMaterial3D.new()
	soil_mat.albedo_color = Color(0.24, 0.18, 0.12)
	soil_mat.roughness = 0.95
	bed.material_override = soil_mat
	bed.position = Vector3(-0.2, _get_ground_y(-0.2, 14.0) + 0.05, 14.0)
	add_child(bed)

	var apple_crate := CRATE_APPLE_SCENE.instantiate() as Node3D
	apple_crate.position = Vector3(-2.7, _get_ground_y(-2.7, 13.8), 13.8)
	apple_crate.scale = Vector3.ONE * 0.8
	add_child(apple_crate)

	var carrot_crate := CRATE_CARROT_SCENE.instantiate() as Node3D
	carrot_crate.position = Vector3(2.3, _get_ground_y(2.3, 13.9), 13.9)
	carrot_crate.scale = Vector3.ONE * 0.8
	add_child(carrot_crate)

func _build_board() -> void:
	# Quadro de Obras: placa de madeira ao lado do Mestre Construtor
	var board: StaticBody3D = preload("res://scripts/town/town_board_sign.gd").new()
	board.name = "QuadroDeObras"
	board.position = Vector3(5.2, _get_ground_y(5.2, 1.4), 1.4)
	board.rotation.y = deg_to_rad(-70.0)
	board.set("city", self)
	add_child(board)

	# Bigorna do acampamento: a forja de verdade (GDD-06 §6)
	var anvil := ForgeStation.new()
	anvil.name = "Bigorna"
	anvil.city = self
	anvil.position = Vector3(4.5, _get_ground_y(4.5, 4.6), 4.6)
	add_child(anvil)

	# Fogueira pública do acampamento: descanso de 2%/s e buff Descansado para todos (GDD-10 §10.2)
	var fire := Campfire.new()
	fire.name = "FogueiraDoAcampamento"
	fire.position = Vector3(-0.6, _get_ground_y(-0.6, 5.6), 5.6)
	add_child(fire)

	_board_layer = CanvasLayer.new()
	_board_layer.layer = 12
	add_child(_board_layer)
	_board = TownBoard.new()
	_board.city = self
	_board_layer.add_child(_board)
	_market_screen = MarketScreen.new()
	_market_screen.city = self
	_board_layer.add_child(_market_screen)

func _spawn_city_npcs() -> void:
	var builder := TownNPC.new()
	builder.name = "MestreConstrutor"
	builder.dna = BUILDER_DNA
	builder.display_name = "Mestre Construtor"
	builder.icon = "🔨"
	builder.prompt = "[E] Quadro de Obras"
	builder.idle_anim = &"Idle_FoldArms"
	builder.position = Vector3(4.4, _get_ground_y(4.4, 0.4), 0.4)
	builder.talked.connect(open_board)
	add_child(builder)

	var alchemist := TownNPC.new()
	alchemist.name = "Alquimista"
	alchemist.dna = ALCHEMIST_DNA
	alchemist.display_name = "Alquimista Botânica"
	alchemist.icon = "⚗️"
	alchemist.idle_anim = &"Idle_Talking"
	alchemist.prompt = "[E] Loja de Poções"
	alchemist.talked.connect(open_shop)
	alchemist.position = Vector3(-3.0, _get_ground_y(-3.0, -2.6), -2.6)
	add_child(alchemist)

	var merchant := TownNPC.new()
	merchant.name = "Mercadora"
	merchant.display_name = "Mercadora"
	merchant.icon = "💰"
	merchant.idle_anim = &"Idle_Talking"
	merchant.prompt = "[E] Mercado: Encomendas e Vendas"
	merchant.talked.connect(open_market)
	merchant.position = Vector3(4.6, _get_ground_y(4.6, 9.4), 9.4)
	add_child(merchant)

	# Mesa do Duelo de Cepas na porta da Taverna (GDD-07 §7)
	var cards := TavernTable.new()
	cards.name = "MesaDeCartas"
	cards.city = self
	cards.position = Vector3(-3.4, _get_ground_y(-3.4, 7.2), 7.2)
	cards.rotation.y = PI * 0.5
	add_child(cards)

	# Estilista Astral: Loja de Cosméticos da Vila (Chapéus, Capas, Auras e PIX)
	var couturier_dna := CharacterDNA.randomized(777)
	couturier_dna.femininity = 0.92
	couturier_dna.beard = CharacterDNA.Beard.NONE
	couturier_dna.hair_style = CharacterDNA.HairStyle.LONG
	couturier_dna.hair_length = 0.85
	couturier_dna.shirt_color = Color("#c85a7c")
	couturier_dna.cosmetic_hat = "coroa_flores"
	couturier_dna.cosmetic_cape = "manto_rosa_real"
	var couturier := TownNPC.new()
	couturier.name = "EstilistaAstral"
	couturier.dna = couturier_dna
	couturier.display_name = "Estilista Astral"
	couturier.icon = "✨"
	couturier.idle_anim = &"Idle_Talking"
	couturier.prompt = "[E] Loja de Cosméticos [F9]"
	couturier.position = Vector3(5.8, _get_ground_y(5.8, -1.8), -1.8)
	couturier.talked.connect(open_cosmetics_shop)
	add_child(couturier)

	# Guardião do Mural: Feedback dos Jogadores & Guia de Exploração
	var chronicler_dna := CharacterDNA.randomized(888)
	chronicler_dna.cosmetic_hat = "chapeu_cacador"
	chronicler_dna.cosmetic_cape = "manto_andarilho"
	var chronicler := TownNPC.new()
	chronicler.name = "CronistaDoMural"
	chronicler.dna = chronicler_dna
	chronicler.display_name = "Mural de Feedback & Guia"
	chronicler.icon = "📜"
	chronicler.idle_anim = &"Idle_FoldArms"
	chronicler.prompt = "[E] Deixar Feedback [F8] / Guia [J]"
	chronicler.position = Vector3(-2.6, _get_ground_y(-2.6, 1.8), 1.8)
	chronicler.talked.connect(open_feedback_modal)
	add_child(chronicler)

func open_cosmetics_shop(player: Node) -> void:
	if not is_inside_tree() or get_tree().current_scene == null:
		return
	var shop := get_tree().current_scene.find_child("CosmeticsShop", true, false)
	if shop and shop.has_method("open_shop"):
		shop.open_shop(player as Player)

func open_feedback_modal(_player: Node) -> void:
	if not is_inside_tree() or get_tree().current_scene == null:
		return
	var modal := get_tree().current_scene.find_child("FeedbackModal", true, false)
	if modal and modal.has_method("open_modal"):
		modal.open_modal()
