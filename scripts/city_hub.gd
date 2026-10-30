class_name CityHub
extends Node3D

## Vila da Esperança (GDD-08 §6.1, planta nova no B36): começa em obras e cresce com o material
## doado pelos jogadores. A planta (elipse, praça, ruas, lotes) mora em VillageLayout; aqui se monta
## o que fica em cima dela: a Praça da Cepa-Mãe, os bairros (Forja e Pátio de Armas, Taverna, Feira,
## Cais e Moinho, Colina da Capela e Horta), os portais, as lanternas que acendem à noite, as obras
## (TownProject), o Quadro de Obras e os NPCs. Guarda a Reputação da Vila e o estado das obras no save.

const _NpcProfile = preload("res://scripts/npc/npc_profile.gd")
const _NpcAction = preload("res://scripts/npc/npc_action.gd")
const _WorldLabel = preload("res://scripts/ui/world_label.gd")
const _VillageLayout = preload("res://scripts/town/village_layout.gd")
const COBBLE_SHADER = preload("res://materials/village_cobble.gdshader")
const GLOW_SHADER = preload("res://materials/village_glow.gdshader")
const AXE_SCENE = preload("res://assets/models/tools/axe.gltf")
const ALCHEMIST_DNA = preload("res://resources/characters/alchemist_dna.tres")
const BUILDER_DNA = preload("res://resources/characters/builder_dna.tres")
const _CookingStation = preload("res://scripts/town/cooking_station.gd")
const _VillageChapel = preload("res://scripts/town/village_chapel.gd")
const _TownNursery = preload("res://scripts/town/town_nursery.gd")
const _MissionBoardSystem = preload("res://scripts/systems/mission_board_system.gd")
const _MissionBoard = preload("res://scripts/town/mission_board.gd")
const _PhotoModeScreen = preload("res://scripts/ui/photo_mode_screen.gd")

const FANTASY := "res://assets/models/props/fantasy/"
const KIT := "res://assets/models/village/"
const NATURE := "res://assets/models/nature/"
const TOOLS := "res://assets/models/tools/"

## Centro da elipse da vila (o raio está em VillageLayout.RADII)
const CENTER: Vector2 = _VillageLayout.CENTER

## Cores das lâmpadas do varal da praça
const BULB_COLORS: Array[Color] = [Color(1.0, 0.78, 0.4), Color(1.0, 0.55, 0.45), Color(0.6, 0.9, 0.75), Color(1.0, 0.9, 0.6)]

signal reputation_changed(value: int)

## true dentro da paliçada (+ margem): vegetação, rochas e recursos não nascem aqui
static func in_village(x: float, z: float, margin: float = 1.0) -> bool:
	return _VillageLayout.in_village(x, z, margin)

@export var landscape: MeshInstance3D

## Reputação da Vila do jogador: 1 por unidade doada
var reputation: int = 0
## Mercado da Vila (GDD-05 §6): encomendas e ordens de venda atendidas pela caravana
var market := VillageMarket.new()
var _market_screen: MarketScreen
var mission_system: _MissionBoardSystem
var _photo_screen: _PhotoModeScreen
var _last_hour: int = -1

## Contratos da Vila (GDD-05 §5): sempre 3 pedidos "entregue N de um material comum"
const CONTRACT_SLOTS: int = 3
const CONTRACT_BONUS: float = 1.5
const CONTRACT_POOL: Dictionary = {
	&"madeira": Vector2i(6, 12), &"galho": Vector2i(8, 16), &"folha": Vector2i(6, 12),
	&"fibra": Vector2i(6, 10), &"pedra": Vector2i(6, 12), &"frutinha": Vector2i(4, 8),
	&"besouro": Vector2i(2, 5), &"ossos": Vector2i(2, 5), &"erva": Vector2i(4, 8), &"mel": Vector2i(1, 3),
	&"carne_crua": Vector2i(3, 6), &"carne_bem_passada": Vector2i(2, 4), &"peixe_lambari": Vector2i(3, 6),
	&"minerio_ferro": Vector2i(3, 6), &"barra_ferro": Vector2i(2, 4), &"couro_trotador": Vector2i(2, 4),
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
## Sorteios da decoração com semente fixa: a vila sai igual em todo jogo (e nos prints)
var _decor := RandomNumberGenerator.new()

var _projects: Array[TownProject] = []
var _workers: Dictionary = {}  # project_id -> TownNPC
var _board: TownBoard
var _board_layer: CanvasLayer

## Lâmpadas (varal da praça e lanternas das ruas): pontos juntados na montagem e uma MultiMesh só
var _glow_points: Array[Vector3] = []
var _glow_colors: Array[Color] = []
var _glow_mat: ShaderMaterial
## Luzes sem sombra que só acendem à noite
var _night_lights: Array[OmniLight3D] = []
var _night: float = -1.0
var _wheel: Node3D
var _scene_cache: Dictionary = {}
var _mat_cache: Dictionary = {}

func _ready() -> void:
	add_to_group("city_hub")
	if mission_system == null:
		mission_system = _MissionBoardSystem.new()
	if landscape == null and get_parent():
		landscape = get_parent().get_node_or_null("Landscape")
	_rng.randomize()
	_decor.seed = 36
	_fill_contracts()
	_glow_mat = ShaderMaterial.new()
	_glow_mat.shader = GLOW_SHADER
	_build_gates()
	_build_plaza()
	_build_districts()
	_build_projects()
	_build_board()
	_spawn_city_npcs()
	_build_glow()
	_refresh_workers()

func _process(delta: float) -> void:
	if _wheel:
		_wheel.rotate_x(-0.85 * delta)
	var sun := get_parent().get_node_or_null("Sun") if get_parent() else null
	if sun == null or not "current_time_hours" in sun:
		return
	_update_night(float(sun.current_time_hours))
	# A caravana passa pelo Mercado às 8h e às 17h (só com o Mercado pronto)
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

## 0 de dia, 1 de noite, rampa de 1h30 no crepúsculo e no amanhecer (relógio único, B22)
static func night_factor(hours: float) -> float:
	if hours >= 19.0 or hours < 5.0:
		return 1.0
	if hours >= 17.5:
		return (hours - 17.5) / 1.5
	if hours < 6.5:
		return 1.0 - (hours - 5.0) / 1.5
	return 0.0

func _update_night(hours: float) -> void:
	var n := night_factor(hours)
	if absf(n - _night) < 0.01:
		return
	_night = n
	if _glow_mat:
		_glow_mat.set_shader_parameter("energy", lerpf(0.25, 3.2, n))
	for light in _night_lights:
		light.visible = n > 0.05
		light.light_energy = n * float(light.get_meta("energy", 1.0))

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
	return {"reputation": reputation, "projects": projects, "contracts": saved_contracts, "market": market.get_state(), "missions": mission_system.to_array() if mission_system else []}

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
	if state.has("missions") and mission_system != null:
		mission_system.load_from_array(state["missions"])
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
		"pos": Vector2(4.8, 9.6),
		"purpose": "Água limpa no centro da vila. Quando houver cultivo e cura, é daqui que vem a água.",
		"costs": [{&"pedra": 8}, {&"pedra": 10, &"madeira": 2}, {&"madeira": 4, &"fibra": 4}],
	})
	_add_project({
		"id": &"palicada", "start": 1, "name": "Paliçada", "icon": "🛡️", "kind": TownProject.Kind.PALISADE,
		"pos": CENTER,
		"purpose": "Cerca de toras em volta da vila, com portões ao norte, a oeste e ao sul; a leste o rio faz a muralha. Defesa contra o que vem dos ermos.",
		"costs": [{&"galho": 10, &"fibra": 6}, {&"madeira": 8, &"galho": 10}, {&"madeira": 6, &"pedra": 6, &"fibra": 6}],
	})
	_add_project({
		"id": &"mercado", "start": 1, "name": "Mercado", "icon": "🏪", "kind": TownProject.Kind.PAVILION,
		"pos": Vector2(8.0, 20.0), "modules": Vector2i(2, 3), "yaw": 0.0,
		"purpose": "Pavilhão coberto no meio da Feira. Vai abrigar as ordens de compra e venda entre jogadores (GDD-05).",
		"costs": [{&"pedra": 6, &"madeira": 4}, {&"madeira": 10, &"fibra": 4}, {&"folha": 10, &"fibra": 6, &"madeira": 4}],
	})
	_add_project({
		"id": &"forja", "start": 2, "name": "Forja Pública", "icon": "⚒️", "kind": TownProject.Kind.HOUSE,
		"pos": Vector2(-11.5, 0.5), "modules": Vector2i(2, 2), "brick": true, "chimney": true, "yaw": 0.0,
		"purpose": "Forja de tijolo com chaminé na Rua da Forja. Vai permitir forjar e reparar equipamento na cidade (GDD-06).",
		"costs": [{&"pedra": 10}, {&"pedra": 8, &"madeira": 6}, {&"ossos": 4, &"madeira": 6}],
	})
	_add_project({
		"id": &"taverna", "start": 1, "name": "Taverna", "icon": "🍺", "kind": TownProject.Kind.HOUSE,
		"pos": Vector2(-10.0, 20.0), "modules": Vector2i(3, 3), "chimney": true, "yaw": PI * 0.5,
		"purpose": "Casa grande de reboco e madeira com varanda para o beco. Vai ter a mesa do jogo de cartas (GDD-07) e descanso.",
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
		p.ring_radii = _VillageLayout.RADII
		p.gate_angles.assign(_VillageLayout.GATES)
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
			var target := Vector2(p.global_position.x, p.global_position.z) if p.kind != TownProject.Kind.PALISADE else _VillageLayout.ring_point(250.0)
			w.rotation.y = atan2(-(target.x - spot.x), -(target.y - spot.y))
			add_child(w)
			_workers[p.project_id] = w
		w.idle_anim = anims[clampi(p.stage, 0, 2)]
		if w.visual:
			w.visual.play(w.idle_anim)

func _worker_spot(p: TownProject) -> Vector2:
	match p.kind:
		TownProject.Kind.PALISADE:
			# Na cerca do sudoeste, 1,6 m para dentro
			var edge := _VillageLayout.ring_point(250.0)
			return edge + (CENTER - edge).normalized() * 1.6
		TownProject.Kind.WELL:
			return Vector2(p.position.x + 1.8, p.position.z - 0.8)
		_:
			var h := Vector2(p.modules) * TownProject.MODULE * 0.5
			var local := Vector3(h.x + 1.0, 0, h.y * 0.4).rotated(Vector3.UP, p.rotation.y)
			return Vector2(p.position.x + local.x, p.position.z + local.z)

# ---------------------------------------------------------------- portais

## Portal de madeira em cada portão: viga com a placa entalhada "VILA DA ESPERANÇA" virada para
## fora e o rumo da estrada virado para dentro; duas lanternas nos postes.
func _build_gates() -> void:
	var inner_text := {0.0: "↑ Covil da Besta · Serra · Cachoeira", 295.0: "← Arena de Teste", 180.0: "↓ Estrada de Porto Bruma"}
	for deg in _VillageLayout.GATES:
		var p := _VillageLayout.ring_point(deg)
		var tangent := (_VillageLayout.ring_point(deg + 1.0) - _VillageLayout.ring_point(deg - 1.0)).normalized()
		var gate := Node3D.new()
		gate.name = "Portal_%d" % int(deg)
		gate.position = Vector3(p.x, _get_ground_y(p.x, p.y), p.y)
		gate.rotation.y = atan2(-tangent.y, tangent.x)
		add_child(gate)
		var wood := _mat(Color(0.33, 0.22, 0.13), 0.9)
		for side in [-1.0, 1.0]:
			var post_x: float = side * 3.4
			var wp := p + tangent * post_x
			var dy := _get_ground_y(wp.x, wp.y) - gate.position.y
			_box(gate, Vector3(0.36, 4.6, 0.36), Vector3(post_x, dy + 2.0, 0), wood, true)
			_lantern(gate, Vector3(post_x - side * 0.45, dy + 3.3, 0.0))
		_box(gate, Vector3(7.8, 0.34, 0.4), Vector3(0, 4.2, 0), wood)
		_box(gate, Vector3(8.4, 0.18, 0.5), Vector3(0, 4.46, 0), _mat(Color(0.26, 0.17, 0.1), 0.9))
		# Placa pendurada sob a viga
		_box(gate, Vector3(3.9, 0.78, 0.12), Vector3(0, 3.48, 0), _mat(Color(0.52, 0.36, 0.2), 0.85))
		for rope_x in [-1.6, 1.6]:
			_box(gate, Vector3(0.04, 0.36, 0.04), Vector3(rope_x, 3.98, 0), _mat(Color(0.7, 0.6, 0.42), 0.9))
		# A face +z do portal aponta para fora quando concorda com o raio que sai do centro
		var out_dir := Vector2(sin(gate.rotation.y), cos(gate.rotation.y))
		var front_out := out_dir.dot(p - CENTER) > 0.0
		_carved_text(gate, "VILA DA ESPERANÇA", Vector3(0, 3.5, 0.065 if front_out else -0.065), 0.0 if front_out else PI, 46)
		_carved_text(gate, inner_text.get(deg, ""), Vector3(0, 3.5, -0.065 if front_out else 0.065), PI if front_out else 0.0, 30)

func _carved_text(parent: Node3D, text: String, pos: Vector3, yaw: float, size: int) -> void:
	var lbl := Label3D.new()
	lbl.text = text
	lbl.font_size = size
	lbl.pixel_size = 0.0055
	lbl.outline_size = 10
	lbl.modulate = Color(1.0, 0.9, 0.65)
	lbl.outline_modulate = Color(0.18, 0.1, 0.05)
	lbl.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	lbl.double_sided = false
	lbl.position = pos
	lbl.rotation.y = yaw
	parent.add_child(lbl)

# ---------------------------------------------------------------- praça

## Praça da Cepa-Mãe: calçamento procedural, a árvore velha no meio com canteiro de pedra, roda de
## bancos, varal de lâmpadas da copa até seis postes e as bandeiras da entrada norte.
func _build_plaza() -> void:
	var c := _VillageLayout.PLAZA
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2.ONE * (_VillageLayout.PLAZA_RADIUS * 2.0 + 0.4)
	var cobble := ShaderMaterial.new()
	cobble.shader = COBBLE_SHADER
	cobble.set_shader_parameter("center", c)
	cobble.set_shader_parameter("radius", _VillageLayout.PLAZA_RADIUS)
	var paving := MeshInstance3D.new()
	paving.name = "Calcamento"
	paving.mesh = floor_mesh
	paving.material_override = cobble
	paving.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	paving.position = Vector3(c.x, _VillageLayout.PLAZA_Y + 0.025, c.y)
	add_child(paving)

	# A Cepa-Mãe: árvore retorcida antiga que já estava aqui antes da vila
	var tree := _prop(NATURE + "TwistedTree_3", c, 20.0, 0.82)
	tree.name = "CepaMae"
	var stone := _mat(Color(0.47, 0.45, 0.42), 0.95)
	var ring := MeshInstance3D.new()
	var ring_mesh := CylinderMesh.new()
	ring_mesh.top_radius = 1.85
	ring_mesh.bottom_radius = 1.95
	ring_mesh.height = 0.45
	ring_mesh.radial_segments = 20
	ring.mesh = ring_mesh
	ring.material_override = stone
	ring.position = Vector3(c.x, 0.2, c.y)
	add_child(ring)
	var soil := MeshInstance3D.new()
	var soil_mesh := CylinderMesh.new()
	soil_mesh.top_radius = 1.7
	soil_mesh.bottom_radius = 1.7
	soil_mesh.height = 0.05
	soil.mesh = soil_mesh
	soil.material_override = _mat(Color(0.22, 0.16, 0.1), 1.0)
	soil.position = Vector3(c.x, 0.44, c.y)
	add_child(soil)
	_cylinder_body(Vector3(c.x, 0.0, c.y), 1.95, 4.0)
	for i in 7:
		var a := TAU * i / 7.0 + 0.3
		_prop(NATURE + ("Flower_3_Group" if i % 2 == 0 else "Flower_4_Group"), c + Vector2(sin(a), cos(a)) * 1.25, rad_to_deg(a), 0.3, 0.44)
	# Roda de bancos virados para fora (quem senta olha a praça)
	for i in 6:
		var a := TAU * i / 6.0
		var bp := c + Vector2(sin(a), cos(a)) * 3.4
		_prop(FANTASY + "Bench", bp, rad_to_deg(a), 0.9)

	# Varal de lâmpadas: da copa até seis postes na borda da praça
	var cord := SurfaceTool.new()
	cord.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hub := Vector3(c.x, 4.3, c.y)
	for i in 6:
		var a := TAU * (i + 0.5) / 6.0
		var pp := c + Vector2(sin(a), cos(a)) * (_VillageLayout.PLAZA_RADIUS - 0.5)
		var top := Vector3(pp.x, 3.3, pp.y)
		_post_with_cap(Vector3(pp.x, _VillageLayout.PLAZA_Y, pp.y), 3.4)
		var start := hub + Vector3(sin(a), 0, cos(a)) * 1.3
		var prev := start
		for k in range(1, 13):
			var t := k / 12.0
			var pt := start.lerp(top, t) - Vector3(0, sin(t * PI) * 0.75, 0)
			_tube(cord, prev, pt, 0.015)
			if k < 12:
				_glow_points.append(pt - Vector3(0, 0.09, 0))
				_glow_colors.append(BULB_COLORS[(i + k) % BULB_COLORS.size()])
			prev = pt
	var cord_mesh := MeshInstance3D.new()
	cord_mesh.name = "VaralDeLampadas"
	cord_mesh.mesh = cord.commit()
	cord_mesh.material_override = _mat(Color(0.12, 0.1, 0.08), 0.9)
	cord_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(cord_mesh)
	_night_light(Vector3(c.x, 3.6, c.y), Color(1.0, 0.8, 0.5), 11.0, 1.4)

	# Bandeiras na entrada norte da praça
	for b in [["Banner_1", Vector2(-2.3, -1.4), 1.24], ["Banner_2", Vector2(2.3, -1.4), 0.99]]:
		var banner := _prop(FANTASY + b[0], b[1], 0.0, 0.8, b[2])
		banner.name = "Banner_Praca_" + String(b[0])

# ---------------------------------------------------------------- bairros

func _build_districts() -> void:
	_build_forge_quarter()
	_build_training_yard()
	_build_alchemist_corner()
	_build_tavern_terrace()
	_build_fair()
	_build_river_quay()
	_build_mill()
	_build_south_hill()
	_build_homes()
	_build_street_lanterns()

## Rua da Forja: lenha empilhada, barril de água para têmpera e um carrinho de minério
func _build_forge_quarter() -> void:
	_woodpile(Vector2(-14.6, 3.4), 0.0)
	_prop(FANTASY + "Barrel", Vector2(-8.9, -1.0), 0.0, 1.0)
	_prop(FANTASY + "Bucket_Metal", Vector2(-8.4, -0.3), 30.0, 1.0)
	_prop(KIT + "Prop_Wagon", Vector2(-15.0, -0.2), 75.0, 0.7)
	_prop(FANTASY + "Crate_Metal", Vector2(-14.2, 1.6), 15.0, 0.9)
	_night_light(Vector3(-9.6, 2.4, 3.0), Color(1.0, 0.55, 0.25), 7.0, 1.6)

## Pátio de Armas: cercado com bonecos de treino, suporte de armas e a bandeira do Mestre
func _build_training_yard() -> void:
	var x0 := -15.0
	var x1 := -9.0
	var z0 := 7.5
	var z1 := 12.5
	var fence := KIT + "Prop_WoodenFence_Single"
	for x in [-14.0, -12.0, -10.0]:
		_prop(fence, Vector2(x, z0), 0.0, 1.0)
		_prop(fence, Vector2(x, z1), 0.0, 1.0)
	for z in [8.5, 10.5]:
		_prop(fence, Vector2(x0, z + 0.5), 90.0, 1.0)
	# Lado leste fica aberto para a praça; só um mourão em cada canto
	for z in [z0, z1]:
		_post_with_cap(Vector3(x1, _get_ground_y(x1, z), z), 1.3)
	for d in [Vector2(-13.6, 8.9), Vector2(-13.6, 11.2), Vector2(-11.7, 11.6)]:
		_prop(FANTASY + "Dummy", d, 90.0 + _decor.randf_range(-20.0, 20.0), 1.0)
	_prop(FANTASY + "WeaponStand", Vector2(-14.3, 10.1), 90.0, 1.0)
	_prop(FANTASY + "Shield_Wooden", Vector2(-11.0, 7.9), 0.0, 1.0, 0.0)
	var banner := _prop(FANTASY + "Banner_1", Vector2(-9.2, 12.9), 90.0, 0.7, 1.08)
	banner.name = "Banner_PatioDeArmas"

## Ateliê da Alquimista, ao pé do portão norte: bancada, caldeirão, poções e vasos de erva
func _build_alchemist_corner() -> void:
	_prop(FANTASY + "Workbench", Vector2(-5.4, -3.6), 180.0, 0.85)
	_prop(FANTASY + "Cauldron", Vector2(-7.2, -2.6), 0.0, 0.75)
	_prop(FANTASY + "Potion_1", Vector2(-5.6, -3.6), 0.0, 0.65, 0.78)
	_prop(FANTASY + "Potion_2", Vector2(-5.1, -3.5), 0.0, 0.65, 0.78)
	_prop(FANTASY + "Shelf_Small_Bottles", Vector2(-3.6, -4.2), 200.0, 0.9)
	for v in [[Vector2(-7.6, -4.0), "Pot_1"], [Vector2(-3.4, -2.6), "Vase_2"], [Vector2(-6.6, -4.6), "Vase_4"]]:
		_prop(FANTASY + v[1], v[0], _decor.randf() * 360.0, 0.9)
	for pl in [Vector2(-7.9, -3.2), Vector2(-3.1, -3.3), Vector2(-6.3, -1.4)]:
		_prop(NATURE + "Plant_1", pl, _decor.randf() * 360.0, 0.8)
	_rug(Vector2(-5.5, -2.2), 0.0, Vector2(2.6, 1.6), Color(0.27, 0.42, 0.3))

## Varanda da Taverna: mesa comprida, bancos, barris e a lanterna da porta
func _build_tavern_terrace() -> void:
	_prop(FANTASY + "Table_Large", Vector2(-3.4, 21.0), 90.0, 0.9)
	_prop(FANTASY + "Bench", Vector2(-4.4, 21.0), 90.0, 0.8)
	_prop(FANTASY + "Bench", Vector2(-2.4, 21.0), 90.0, 0.8)
	_prop(FANTASY + "Mug", Vector2(-3.4, 20.5), 0.0, 1.0, 0.73)
	_prop(FANTASY + "Mug", Vector2(-3.3, 21.6), 40.0, 1.0, 0.73)
	_prop(FANTASY + "Barrel_Holder", Vector2(-12.4, 16.2), 0.0, 1.0)
	_prop(FANTASY + "Barrel", Vector2(-13.6, 16.4), 0.0, 1.0)
	_prop(FANTASY + "Barrel", Vector2(-13.5, 23.8), 0.0, 1.0)
	_prop(FANTASY + "Barrel_Apples", Vector2(-12.4, 24.0), 0.0, 1.0)
	_woodpile(Vector2(-14.2, 20.0), 90.0)
	_night_light(Vector3(-4.0, 2.6, 19.8), Color(1.0, 0.72, 0.4), 8.0, 1.3)

## Feira: o pavilhão do Mercado no meio, bancas de fruta, carroça, varal de roupa e a boutique
## da Estilista Astral com a cadeira do Barbeiro
func _build_fair() -> void:
	_prop(FANTASY + "Stall_Empty", Vector2(12.2, 18.0), -90.0, 0.95)
	_prop(FANTASY + "FarmCrate_Apple", Vector2(11.9, 19.4), 10.0, 0.8)
	_prop(FANTASY + "FarmCrate_Carrot", Vector2(12.6, 16.6), -15.0, 0.8)
	_prop(FANTASY + "Barrel_Apples", Vector2(11.2, 16.4), 0.0, 1.0)
	_prop(FANTASY + "Stall_Cart_Empty", Vector2(12.0, 22.6), 200.0, 0.8)
	_prop(FANTASY + "Bag", Vector2(11.0, 23.4), 40.0, 1.0)
	_prop(FANTASY + "Pouch_Large", Vector2(12.9, 21.4), 0.0, 1.0)
	_prop(KIT + "Prop_Wagon", Vector2(14.6, 20.2), 8.0, 0.75)
	_prop(FANTASY + "Bench", Vector2(8.0, 24.4), 0.0, 0.9)
	var banner := _prop(FANTASY + "Banner_2", Vector2(10.6, 16.0), 0.0, 0.75, 0.93)
	banner.name = "Banner_Feira"
	_clothesline(Vector2(12.6, 24.6), Vector2(15.4, 24.0))
	_night_light(Vector3(8.0, 3.0, 17.2), Color(1.0, 0.8, 0.5), 9.0, 1.2)
	# Boutique da Estilista Astral e cadeira do Barbeiro
	_prop(FANTASY + "Stall_Empty", Vector2(10.2, 12.0), -90.0, 0.9)
	_rug(Vector2(9.0, 12.2), -90.0, Vector2(2.4, 1.8), Color(0.55, 0.2, 0.35))
	_prop(FANTASY + "Chest_Wood", Vector2(10.4, 13.6), -110.0, 0.65)
	_prop(FANTASY + "Chair_1", Vector2(12.0, 13.5), 180.0, 1.0)
	_prop(FANTASY + "Vase_2", Vector2(12.9, 14.6), 0.0, 1.0)

## Cais do Rio: píer de tábuas entrando na água, barris, cordas e a lanterna da ponta
func _build_river_quay() -> void:
	var z := 1.6
	var deck_y := maxf(_get_ground_y(7.6, z), RiverSystem.LOWER_WATER_Y + 0.55)
	var pier := Node3D.new()
	pier.name = "CaisDoRio"
	pier.position = Vector3(0, deck_y, 0)
	add_child(pier)
	for x in [8.6, 10.6, 12.6]:
		var tile := _scene(KIT + "Floor_WoodDark").instantiate() as Node3D
		tile.position = Vector3(x, 0.0, z)
		pier.add_child(tile)
	var wood := _mat(Color(0.3, 0.2, 0.12), 0.9)
	for x in [7.7, 9.6, 11.6, 13.5]:
		for side in [-0.95, 0.95]:
			_box(pier, Vector3(0.18, 3.0, 0.18), Vector3(x, -1.25, z + side), wood)
	# Borda e corda de segurar na ponta
	_box(pier, Vector3(0.16, 0.9, 0.16), Vector3(13.5, 0.45, z - 0.95), wood)
	_box(pier, Vector3(0.16, 0.9, 0.16), Vector3(13.5, 0.45, z + 0.95), wood)
	_box(pier, Vector3(0.05, 0.05, 1.9), Vector3(13.5, 0.8, z), _mat(Color(0.7, 0.6, 0.42), 0.9))
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(6.2, 0.3, 2.0)
	col.shape = shape
	col.position = Vector3(10.6, -0.14, z)
	body.add_child(col)
	pier.add_child(body)
	for p in [[Vector3(8.2, 0, z - 0.7), "Barrel"], [Vector3(8.9, 0, z - 0.75), "Bucket_Wooden_1"], [Vector3(12.8, 0, z + 0.7), "Rope_2"], [Vector3(9.6, 0, z + 0.7), "Crate_Wooden"]]:
		var n := _scene(FANTASY + p[1]).instantiate() as Node3D
		n.position = p[0]
		n.rotation.y = _decor.randf() * TAU
		pier.add_child(n)
	_lantern(pier, Vector3(13.25, 0.95, z - 0.95))
	_night_light(Vector3(12.0, deck_y + 1.8, z), Color(1.0, 0.78, 0.5), 7.0, 1.0)

## Moinho na beira do rio: casa de cenário com a roda d'água girando na correnteza
func _build_mill() -> void:
	_add_home(Vector2(3.5, -5.0), -PI * 0.5, Vector2i(2, 2), false, "Moinho")
	var wy := RiverSystem.LOWER_WATER_Y + 1.15
	var mount := Node3D.new()
	mount.name = "RodaDAgua"
	mount.position = Vector3(6.95, wy, -5.0)
	add_child(mount)
	var wood := _mat(Color(0.36, 0.24, 0.14), 0.9)
	var axle := MeshInstance3D.new()
	var axle_mesh := CylinderMesh.new()
	axle_mesh.top_radius = 0.09
	axle_mesh.bottom_radius = 0.09
	axle_mesh.height = 1.7
	axle.mesh = axle_mesh
	axle.material_override = _mat(Color(0.25, 0.2, 0.16), 0.7)
	axle.rotation.z = PI * 0.5
	axle.position.x = -0.75
	mount.add_child(axle)
	_wheel = Node3D.new()
	mount.add_child(_wheel)
	for k in 4:
		var spoke := MeshInstance3D.new()
		var sm := BoxMesh.new()
		sm.size = Vector3(0.1, 2.9, 0.1)
		spoke.mesh = sm
		spoke.material_override = wood
		spoke.rotation.x = PI * k / 4.0
		_wheel.add_child(spoke)
	for side in [-0.28, 0.28]:
		var rim := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 1.42
		tm.outer_radius = 1.54
		tm.rings = 24
		rim.mesh = tm
		rim.material_override = wood
		rim.rotation.z = PI * 0.5
		rim.position.x = side
		_wheel.add_child(rim)
	for k in 12:
		var a := TAU * k / 12.0
		var paddle := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(0.66, 0.5, 0.06)
		paddle.mesh = pm
		paddle.material_override = wood
		paddle.position = Vector3(0, cos(a) * 1.4, sin(a) * 1.4)
		paddle.rotation.x = a
		_wheel.add_child(paddle)
	_woodpile(Vector2(1.8, -7.4), 90.0)
	_prop(FANTASY + "Bag", Vector2(1.6, -3.4), 0.0, 1.0)
	_prop(FANTASY + "Bag", Vector2(1.9, -3.0), 50.0, 0.9)

## Colina da Capela (Capela e Berçário entram em _build_board), Horta cercada e o pomar
func _build_south_hill() -> void:
	var soil := _mat(Color(0.25, 0.18, 0.12), 0.97)
	for x in [-14.0, -12.0, -10.0]:
		var gy := _get_ground_y(x, 28.0)
		var bed := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(1.3, 0.3, 3.6)
		bed.mesh = bm
		bed.material_override = soil
		bed.position = Vector3(x, gy + 0.05, 28.0)
		add_child(bed)
		for k in 4:
			var crop := "Carrot" if x != -12.0 else "Plant_7"
			var path := (FANTASY if crop == "Carrot" else NATURE) + crop
			_prop(path, Vector2(x + _decor.randf_range(-0.25, 0.25), 26.7 + k * 0.85), _decor.randf() * 360.0, 0.9 if crop == "Carrot" else 0.6, 0.2)
	var fence := KIT + "Prop_WoodenFence_Single"
	for x in [-14.4, -12.4, -10.4]:
		_prop(fence, Vector2(x, 25.5), 0.0, 1.0)
		_prop(fence, Vector2(x, 30.5), 0.0, 1.0)
	for z in [26.5, 28.5]:
		_prop(fence, Vector2(-15.4, z + 0.5), 90.0, 1.0)
	_prop(FANTASY + "FarmCrate_Apple", Vector2(-8.6, 26.2), 20.0, 0.8)
	_prop(FANTASY + "FarmCrate_Empty", Vector2(-8.5, 30.0), -10.0, 0.8)
	_prop(TOOLS + "shovel", Vector2(-8.8, 29.2), 80.0, 1.0)
	_scarecrow(Vector2(-12.0, 31.6))
	# Pomar e árvores que quebram a paliçada
	for t in [[Vector2(-16.0, 22.8), "CommonTree_2", 0.75], [Vector2(-11.6, 33.0), "CommonTree_4", 0.7], [Vector2(8.8, 34.0), "CommonTree_1", 0.75], [Vector2(-17.0, 8.0), "Pine_2", 0.8], [Vector2(14.6, 9.0), "CommonTree_3", 0.7]]:
		_prop(NATURE + t[1], t[0], _decor.randf() * 360.0, t[2])
	for b in [Vector2(-1.8, 31.6), Vector2(-6.4, 32.6), Vector2(3.0, 28.8), Vector2(-14.6, 18.6), Vector2(14.2, 11.0), Vector2(-15.0, -1.6)]:
		_prop(NATURE + "Bush_Common_Flowers", b, _decor.randf() * 360.0, 0.8)

## Moradias de cenário: dão cara de vila de verdade (portas viradas para a rua mais perto)
func _build_homes() -> void:
	_add_home(Vector2(-16.0, 15.5), PI * 0.5, Vector2i(2, 2), false, "Casa_Oeste")
	_add_home(Vector2(11.0, 27.0), -PI * 0.5, Vector2i(2, 2), false, "Casa_Ribeira")
	_add_home(Vector2(5.0, 36.0), PI, Vector2i(2, 2), true, "Casa_Sul")
	_add_home(Vector2(-7.0, 35.5), PI, Vector2i(2, 2), false, "Casa_Colina")

func _add_home(pos: Vector2, yaw: float, modules: Vector2i, chimney: bool, home_name: String) -> void:
	var home := TownProject.new()
	home.name = home_name
	home.decorative = true
	home.kind = TownProject.Kind.HOUSE
	home.modules = modules
	home.chimney = chimney
	home.position = Vector3(pos.x, _get_ground_y(pos.x, pos.y), pos.y)
	home.rotation.y = yaw
	add_child(home)

## Lanternas em postes nas ruas: só a lâmpada brilha (sem luz), uma MultiMesh para todas
func _build_street_lanterns() -> void:
	for p in [Vector2(1.6, -8.0), Vector2(-2.4, -4.2), Vector2(-10.0, 6.4), Vector2(-15.6, 2.9), Vector2(2.9, 17.6),
			Vector2(-0.9, 23.6), Vector2(2.4, 30.8), Vector2(-2.9, 36.4), Vector2(-4.2, 15.0), Vector2(3.8, 14.6),
			Vector2(7.4, 4.6), Vector2(-7.0, 27.0), Vector2(6.8, 26.4)]:
		var base := Vector3(p.x, _get_ground_y(p.x, p.y), p.y)
		_post_with_cap(base, 2.6)
		_box(self, Vector3(0.55, 0.07, 0.07), base + Vector3(0.25, 2.45, 0), _mat(Color(0.3, 0.2, 0.12), 0.9))
		_lantern(self, base + Vector3(0.45, 1.95, 0))

# ---------------------------------------------------------------- estações

func _build_board() -> void:
	# Quadro de Obras: placa de madeira ao lado do Mestre Construtor, de frente para o spawn
	var board: StaticBody3D = preload("res://scripts/town/town_board_sign.gd").new()
	board.name = "QuadroDeObras"
	board.position = Vector3(4.4, _get_ground_y(4.4, 1.2), 1.2)
	board.rotation.y = deg_to_rad(-60.0)
	board.set("city", self)
	add_child(board)

	# Bigorna da Rua da Forja: a forja de verdade (GDD-06 §6)
	var anvil := ForgeStation.new()
	anvil.name = "Bigorna"
	anvil.city = self
	anvil.position = Vector3(-8.6, _get_ground_y(-8.6, 3.0), 3.0)
	add_child(anvil)

	# Fogueira pública da praça: descanso de 2%/s e buff Descansado para todos (GDD-10 §10.2)
	var fire := Campfire.new()
	fire.name = "FogueiraDoAcampamento"
	fire.position = Vector3(-4.6, _get_ground_y(-4.6, 9.4), 9.4)
	add_child(fire)
	for i in 3:
		var a := TAU * i / 3.0 + 0.6
		_log_seat(Vector2(-4.6, 9.4) + Vector2(sin(a), cos(a)) * 1.7, rad_to_deg(a) + 90.0)

	# Caldeirão Culinário público na varanda da Taverna (GDD-13 §4)
	var cauldron := _CookingStation.new()
	cauldron.name = "CaldeiraoPublico"
	cauldron.city = self
	cauldron.position = Vector3(-3.8, _get_ground_y(-3.8, 23.6), 23.6)
	add_child(cauldron)

	# Capela da Vila da Esperança no alto da colina (GDD-14 §4.1)
	var chapel := _VillageChapel.new()
	chapel.name = "CapelaDaEsperanca"
	chapel.city = self
	chapel.position = Vector3(-4.0, _get_ground_y(-4.0, 30.0), 30.0)
	add_child(chapel)

	# Berçário da Cidade e Casa da Parteira, do outro lado da avenida (GDD-14 §4.3)
	var nursery := _TownNursery.new()
	nursery.name = "BercarioDaCidade"
	nursery.city = self
	nursery.position = Vector3(6.0, _get_ground_y(6.0, 31.0), 31.0)
	add_child(nursery)

	_board_layer = CanvasLayer.new()
	_board_layer.layer = 12
	add_child(_board_layer)
	_board = TownBoard.new()
	_board.city = self
	_board_layer.add_child(_board)
	_market_screen = MarketScreen.new()
	_market_screen.city = self
	_board_layer.add_child(_market_screen)

	# Quadro de Missões & Contratos da Vila, logo na chegada da praça (GDD-05 §5, GDD-03, GDD-13)
	var mission_board := _MissionBoard.new()
	mission_board.name = "QuadroDeMissoes"
	mission_board.city = self
	mission_board.mission_system = mission_system
	mission_board.position = Vector3(-4.6, _get_ground_y(-4.6, 2.0), 2.0)
	mission_board.rotation.y = deg_to_rad(40.0)
	add_child(mission_board)

	# Modo Foto [P] e Câmera de Reconhecimento
	_photo_screen = _PhotoModeScreen.new()
	_photo_screen.mission_system = mission_system
	_board_layer.add_child(_photo_screen)

# ---------------------------------------------------------------- NPCs

func _spawn_city_npcs() -> void:
	# Ficha do NPC (GDD-17 §8): o [E] abre o NPC em 3D com papel e ações; a Vila atende 24 h
	var builder := _npc("MestreConstrutor", "Mestre Construtor", "🔨", &"Idle_FoldArms", Vector2(3.4, 0.3), Vector2(0.0, 0.0), BUILDER_DNA)
	builder.profile = _NpcProfile.make(&"mestre_construtor", "Mestre Construtor", "Obras da Vila", "🔨", "Praça da Cepa-Mãe") \
		.greet("sempre", "Cada tábua doada vira parede. Cada parede vira vila.") \
		.add(_NpcAction.make(&"obras", _NpcAction.Kind.SERVICE, "Quadro de Obras e Contratos", open_board, "📋")) \
		.topic("Como a vila cresce?", "Com doação. Você traz o material, a obra sobe por etapas e a vila te dá Reputação.") \
		.topic("O que são os Contratos?", "Pedidos de material que pagam em Dólares de Sucata. Entregou, chega outro no lugar.")

	var alchemist := _npc("Alquimista", "Alquimista Botânica", "⚗️", &"Idle_Talking", Vector2(-5.5, -1.5), Vector2(0.0, 2.0), ALCHEMIST_DNA)
	alchemist.profile = _NpcProfile.make(&"alquimista", "Alquimista Botânica", "Boticária", "⚗️", "Ateliê da Alquimista") \
		.greet("manha", "Ervas colhidas com orvalho curam melhor. Quer alguma coisa?") \
		.greet("tarde", "Poção fresca, saída do caldeirão agora mesmo.") \
		.greet("noite", "De noite as ervas dormem, mas as poções não.") \
		.add(_NpcAction.make(&"loja", _NpcAction.Kind.BUY, "Comprar poções e consumíveis", open_shop)) \
		.topic("Por que você não compra de volta?", "Se eu comprasse tudo, dinheiro nasceria do nada. Para vender, use o Mercado.") \
		.topic("Desconto?", "Quem ajuda a vila paga menos: 1% a cada 25 de Reputação, até 10%.")

	var merchant := _npc("Mercadora", "Mercadora", "💰", &"Idle_Talking", Vector2(6.9, 16.3), Vector2(5.0, 12.0), null)
	merchant.profile = _NpcProfile.make(&"mercadora", "Mercadora", "Mercado da Vila", "💰", "Feira") \
		.greet("sempre", "A caravana passa às 8h e às 17h. Deixe sua ordem que eu cuido do resto.") \
		.add(_NpcAction.make(&"mercado", _NpcAction.Kind.SELL, "Encomendas e vendas", open_market, "⚖️") \
			.with_check(func(_p): return "" if market_open() else "As bancas ainda estão em obras (Quadro de Obras)")) \
		.topic("Como funciona uma ordem?", "Você diz o material, a quantidade e o preço. Se a caravana aceitar, a ordem fecha e fica a receber aqui.") \
		.topic("Quais são as taxas?", "2% para listar, perdidos se cancelar, e 4% sobre cada venda.")

	# Mesa do Duelo de Cepas na varanda da Taverna (GDD-07 §7)
	var cards := TavernTable.new()
	cards.name = "MesaDeCartas"
	cards.city = self
	cards.position = Vector3(-3.6, _get_ground_y(-3.6, 18.2), 18.2)
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
	var couturier := _npc("EstilistaAstral", "Estilista Astral", "✨", &"Idle_Talking", Vector2(9.2, 13.4), Vector2(5.0, 12.0), couturier_dna)
	couturier.profile = _NpcProfile.make(&"estilista_astral", "Estilista Astral", "Cosméticos", "✨", "Feira") \
		.greet("sempre", "Coroa de flores, capa real, aura de estrela... o que combina com você hoje?") \
		.add(_NpcAction.make(&"cosmeticos", _NpcAction.Kind.BUY, "Loja de Cosméticos [F9]", open_cosmetics_shop)) \
		.topic("Cosmético muda alguma coisa na luta?", "Nada. É só estilo; a força vem do equipamento e do uso.")

	# Guardião do Mural: Feedback dos Jogadores & Guia de Exploração, sob a Cepa-Mãe
	var chronicler_dna := CharacterDNA.randomized(888)
	chronicler_dna.cosmetic_hat = "chapeu_cacador"
	chronicler_dna.cosmetic_cape = "manto_andarilho"
	var chronicler := _npc("CronistaDoMural", "Cronista do Mural", "📜", &"Idle_FoldArms", Vector2(-6.6, 6.4), Vector2(0.0, 6.0), chronicler_dna)
	chronicler.profile = _NpcProfile.make(&"cronista_mural", "Cronista do Mural", "Feedback e Guia", "📜", "Praça da Cepa-Mãe") \
		.greet("sempre", "Tudo o que acontece no vale acaba escrito neste mural.") \
		.add(_NpcAction.make(&"feedback", _NpcAction.Kind.SERVICE, "Deixar feedback [F8]", open_feedback_modal, "✍️")) \
		.add(_NpcAction.make(&"guia", _NpcAction.Kind.LEARN, "Guia do Explorador [J]", open_explorer_guide)) \
		.topic("Onde fica a Costelária?", "A oeste, depois da Arena da Paliçada. Siga a estrada do portão oeste até ver as costelas do Colosso no horizonte.")
	_prop(FANTASY + "BookStand", Vector2(-7.4, 5.6), 60.0, 1.0)

	# Moradores: não abrem tela, só contam alguma coisa da vila
	var folk := [
		["Pescador", "Seu Lambari", "🎣", &"Sitting_Idle", Vector2(13.0, 1.6), Vector2(20.0, 1.6), 101,
			"Rio bom é rio cheio. Quando chove, a água sobe até o píer — e os peixes grandes sobem junto."],
		["Moleira", "Dona Mó", "🌾", &"Interact", Vector2(1.9, -5.6), Vector2(3.5, -5.0), 202,
			"A roda não para nem de noite. Se um dia parar, alguém mexeu no rio lá em cima."],
		["Taverneiro", "Bento Caneca", "🍺", &"Idle_FoldArms", Vector2(-5.4, 20.4), Vector2(-3.4, 21.0), 303,
			"A Taverna ainda é só parede e promessa. Traga madeira e mel que eu sirvo a primeira rodada."],
		["Hortela", "Tia Rama", "🥕", &"Farm_Harvest", Vector2(-11.0, 27.0), Vector2(-12.0, 28.0), 404,
			"Cenoura aqui, erva ali. Quem planta perto da Capela diz que a colheita vem mais doce."],
		["Contadora", "Vó Brasa", "🔥", &"Sitting_Idle", Vector2(-6.2, 10.6), Vector2(-4.6, 9.4), 505,
			"Dizem que a Cepa-Mãe já era velha quando o rio ainda nem tinha nome. A vila nasceu à sombra dela."],
		["Sentinela", "Guarda Tião", "🛡️", &"Idle_FoldArms", Vector2(2.4, -8.6), Vector2(-1.0, -14.0), 606,
			"Do portão norte se ouve a Besta de Sucata rangendo no morro. Vá preparado — ou vá rápido."],
	]
	const FOLK_TITLES := {"Pescador": "Pescador", "Moleira": "Moleira", "Taverneiro": "Taverneiro", "Hortela": "Horteloa", "Contadora": "Contadora de Histórias", "Sentinela": "Guarda do Portão Norte"}
	for f in folk:
		var npc := _npc(f[0], f[1], f[2], f[3], f[4], f[5], CharacterDNA.randomized(f[6]), "", f[7], f[0] != "Pescador")
		npc.profile = _NpcProfile.make(StringName(f[0].to_lower()), f[1], FOLK_TITLES.get(f[0], "Morador"), f[2], "Vila da Esperança") \
			.topic("O que tem de novo?", f[7])
		if not npc.snap_to_ground:
			npc.position.y = get_node("CaisDoRio").position.y + 0.05

func open_explorer_guide(_player: Node) -> void:
	if not is_inside_tree() or get_tree().current_scene == null:
		return
	var guide := get_tree().current_scene.find_child("ExplorerGuide", true, false)
	if guide and guide.has_method("open_guide"):
		guide.open_guide()

## NPC da vila virado para `face` (ponto x, z); prompt e assentamento valem no _ready do TownNPC
func _npc(node_name: String, display: String, icon: String, anim: StringName, pos: Vector2, face: Vector2, dna: CharacterDNA = null, prompt: String = "", line: String = "", snap: bool = true) -> TownNPC:
	var npc := TownNPC.new()
	npc.name = node_name
	npc.dna = dna
	npc.display_name = display
	npc.icon = icon
	npc.idle_anim = anim
	npc.prompt = prompt
	npc.line = line
	npc.snap_to_ground = snap
	npc.position = Vector3(pos.x, _get_ground_y(pos.x, pos.y), pos.y)
	npc.rotation.y = atan2(-(face.x - pos.x), -(face.y - pos.y))
	add_child(npc)
	return npc

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

# ---------------------------------------------------------------- peças

## Instancia um modelo no chão (x, z) com giro em graus, escala e altura extra
func _prop(path: String, pos: Vector2, yaw_deg: float = 0.0, s: float = 1.0, y_off: float = 0.0) -> Node3D:
	var scene := _scene(path)
	var n: Node3D = scene.instantiate() if scene else Node3D.new()
	n.position = Vector3(pos.x, _get_ground_y(pos.x, pos.y) + y_off, pos.y)
	n.rotation.y = deg_to_rad(yaw_deg)
	n.scale = Vector3.ONE * s
	add_child(n)
	return n

func _scene(path: String) -> PackedScene:
	if not _scene_cache.has(path):
		var full := path + ".gltf"
		_scene_cache[path] = load(full) as PackedScene if ResourceLoader.exists(full) else null
	return _scene_cache[path]

func _mat(color: Color, roughness: float) -> StandardMaterial3D:
	var key := color.to_html() + str(roughness)
	if not _mat_cache.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = roughness
		_mat_cache[key] = m
	return _mat_cache[key]

func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, solid: bool = false) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	m.mesh = bm
	m.material_override = mat
	m.position = pos
	parent.add_child(m)
	if solid:
		var body := StaticBody3D.new()
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		col.shape = shape
		body.add_child(col)
		m.add_child(body)
	return m

func _cylinder_body(base: Vector3, radius: float, height: float) -> void:
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	col.shape = shape
	col.position = base + Vector3(0, height * 0.5, 0)
	body.add_child(col)
	add_child(body)

## Poste facetado de madeira com tampo (lanternas, varal, cantos de cerca)
func _post_with_cap(base: Vector3, height: float) -> void:
	var post := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.07
	cyl.bottom_radius = 0.1
	cyl.height = height
	cyl.radial_segments = 6
	cyl.rings = 1
	post.mesh = cyl
	post.material_override = _mat(Color(0.32, 0.21, 0.12), 0.9)
	post.position = base + Vector3(0, height * 0.5, 0)
	add_child(post)
	_box(self, Vector3(0.24, 0.08, 0.24), base + Vector3(0, height + 0.04, 0), _mat(Color(0.26, 0.17, 0.1), 0.9))

## Lanterna pequena com a chama na MultiMesh de lâmpadas
func _lantern(parent: Node3D, pos: Vector3) -> void:
	var scene := _scene(TOOLS + "lantern")
	if scene:
		var l := scene.instantiate() as Node3D
		l.scale = Vector3.ONE * 0.38
		l.position = pos
		parent.add_child(l)
	var world := pos if parent == self else (parent.position + pos.rotated(Vector3.UP, parent.rotation.y))
	_glow_points.append(world + Vector3(0, 0.15, 0))
	_glow_colors.append(Color(1.0, 0.7, 0.35))

func _night_light(pos: Vector3, color: Color, radius: float, energy: float) -> void:
	var light := OmniLight3D.new()
	light.light_color = color
	light.omni_range = radius
	light.shadow_enabled = false
	light.position = pos
	light.visible = false
	light.set_meta("energy", energy)
	add_child(light)
	_night_lights.append(light)

## Todas as lâmpadas numa MultiMesh com o shader que acende à noite
func _build_glow() -> void:
	if _glow_points.is_empty():
		return
	var sphere := SphereMesh.new()
	sphere.radius = 0.07
	sphere.height = 0.14
	sphere.radial_segments = 8
	sphere.rings = 4
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = sphere
	mm.instance_count = _glow_points.size()
	for i in _glow_points.size():
		mm.set_instance_transform(i, Transform3D(Basis(), _glow_points[i]))
		mm.set_instance_color(i, _glow_colors[i])
	var inst := MultiMeshInstance3D.new()
	inst.name = "Lampadas"
	inst.multimesh = mm
	inst.material_override = _glow_mat
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(inst)
	_glow_mat.set_shader_parameter("energy", 0.25)

## Prisma de 4 lados entre a e b (cordas do varal), somado num SurfaceTool
func _tube(st: SurfaceTool, a: Vector3, b: Vector3, r: float) -> void:
	var dir := (b - a).normalized()
	var side := dir.cross(Vector3.UP).normalized()
	if side.length_squared() < 0.01:
		side = Vector3.RIGHT
	var up := side.cross(dir).normalized()
	var ring := [side * r, up * r, -side * r, -up * r]
	for k in 4:
		var o1: Vector3 = ring[k]
		var o2: Vector3 = ring[(k + 1) % 4]
		st.add_vertex(a + o1)
		st.add_vertex(b + o1)
		st.add_vertex(b + o2)
		st.add_vertex(a + o1)
		st.add_vertex(b + o2)
		st.add_vertex(a + o2)

## Pilha de lenha: toras deitadas em pirâmide
func _woodpile(pos: Vector2, yaw_deg: float) -> void:
	var pile := Node3D.new()
	pile.position = Vector3(pos.x, _get_ground_y(pos.x, pos.y), pos.y)
	pile.rotation.y = deg_to_rad(yaw_deg)
	add_child(pile)
	var bark := _mat(Color(0.36, 0.24, 0.14), 0.95)
	var log_mesh := CylinderMesh.new()
	log_mesh.top_radius = 0.13
	log_mesh.bottom_radius = 0.14
	log_mesh.height = 1.4
	log_mesh.radial_segments = 7
	var rows := [4, 3, 2]
	for row in rows.size():
		for k in rows[row]:
			var m := MeshInstance3D.new()
			m.mesh = log_mesh
			m.material_override = bark
			m.rotation.z = PI * 0.5
			m.position = Vector3(0, 0.14 + row * 0.24, (k - (rows[row] - 1) * 0.5) * 0.28)
			pile.add_child(m)

## Toco deitado de sentar em volta da fogueira
func _log_seat(pos: Vector2, yaw_deg: float) -> void:
	var m := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.2
	cyl.bottom_radius = 0.22
	cyl.height = 1.3
	cyl.radial_segments = 8
	m.mesh = cyl
	m.material_override = _mat(Color(0.38, 0.26, 0.15), 0.95)
	m.rotation = Vector3(0, deg_to_rad(yaw_deg), PI * 0.5)
	m.position = Vector3(pos.x, _get_ground_y(pos.x, pos.y) + 0.18, pos.y)
	add_child(m)

func _rug(pos: Vector2, yaw_deg: float, size: Vector2, color: Color) -> void:
	var rug := MeshInstance3D.new()
	var rm := BoxMesh.new()
	rm.size = Vector3(size.x, 0.02, size.y)
	rug.mesh = rm
	rug.material_override = _mat(color, 0.85)
	rug.position = Vector3(pos.x, _get_ground_y(pos.x, pos.y) + 0.02, pos.y)
	rug.rotation.y = deg_to_rad(yaw_deg)
	add_child(rug)

## Varal de roupa entre dois postes, com panos coloridos
func _clothesline(a: Vector2, b: Vector2) -> void:
	var ya := _get_ground_y(a.x, a.y)
	var yb := _get_ground_y(b.x, b.y)
	_post_with_cap(Vector3(a.x, ya, a.y), 2.1)
	_post_with_cap(Vector3(b.x, yb, b.y), 2.1)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pa := Vector3(a.x, ya + 2.0, a.y)
	var pb := Vector3(b.x, yb + 2.0, b.y)
	_tube(st, pa, pb, 0.012)
	var line := MeshInstance3D.new()
	line.mesh = st.commit()
	line.material_override = _mat(Color(0.75, 0.7, 0.6), 0.9)
	add_child(line)
	var cloths := [Color(0.75, 0.3, 0.25), Color(0.9, 0.85, 0.7), Color(0.3, 0.45, 0.65), Color(0.8, 0.65, 0.3)]
	for k in cloths.size():
		var t := (k + 0.7) / (cloths.size() + 0.4)
		var p := pa.lerp(pb, t)
		var cloth := MeshInstance3D.new()
		var cm := BoxMesh.new()
		cm.size = Vector3(0.5, 0.7 - 0.1 * (k % 2), 0.02)
		cloth.mesh = cm
		cloth.material_override = _mat(cloths[k], 0.95)
		cloth.position = p - Vector3(0, cm.size.y * 0.5, 0)
		cloth.rotation.y = atan2(-(pb.z - pa.z), pb.x - pa.x)
		add_child(cloth)

## Espantalho da Horta: cruz de madeira, saco de palha e chapéu
func _scarecrow(pos: Vector2) -> void:
	var root := Node3D.new()
	root.name = "Espantalho"
	root.position = Vector3(pos.x, _get_ground_y(pos.x, pos.y), pos.y)
	root.rotation.y = deg_to_rad(20.0)
	add_child(root)
	var wood := _mat(Color(0.4, 0.27, 0.15), 0.9)
	_box(root, Vector3(0.1, 1.9, 0.1), Vector3(0, 0.95, 0), wood)
	_box(root, Vector3(1.3, 0.08, 0.08), Vector3(0, 1.45, 0), wood)
	_box(root, Vector3(0.5, 0.65, 0.3), Vector3(0, 1.3, 0), _mat(Color(0.55, 0.4, 0.25), 0.95))
	var head := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = 0.2
	hm.height = 0.4
	head.mesh = hm
	head.material_override = _mat(Color(0.82, 0.72, 0.45), 0.95)
	head.position.y = 1.85
	root.add_child(head)
	var hat := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.08
	cm.bottom_radius = 0.34
	cm.height = 0.3
	hat.mesh = cm
	hat.material_override = _mat(Color(0.7, 0.58, 0.3), 0.95)
	hat.position.y = 2.1
	root.add_child(hat)
