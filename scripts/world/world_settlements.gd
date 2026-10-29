class_name WorldSettlements
extends Node3D

## Estrutura Geográfica do Vale: Cidades, Povoados, Estradas, Placas de Direção e Marcos de Viagem.
## Expande o mundo de 360x360m além da Vila da Esperança com 3 novos assentamentos vivos:
## - ⚓ Vila Ribeirinha de Porto Bruma (42, 48): doca de pesca, fogueira, baú e Mestre Pescador Cauã
## - 🏔️ Posto da Vigia do Norte (-32, -72): mirante da cachoeira, fogueira e Guarda-Florestal Iara
## - 🪐 Santuário Astral do Mirante (82, -38): círculo de menires, fogueira e Sábio Astral Celiano
## Também cria Marcos de Viagem Rápida ([E] abre o Mapa [M]) e placas nas encruzilhadas.

const _WorldLabel = preload("res://scripts/ui/world_label.gd")
const ROCK_SCENE = preload("res://assets/models/nature/Rock_Medium_2.gltf")
const PATH_SCENE = preload("res://assets/models/nature/RockPath_Square_Wide.gltf")
const CART_SCENE = preload("res://assets/models/props/fantasy/Stall_Cart_Empty.gltf")
const BANNER1_SCENE = preload("res://assets/models/props/fantasy/Banner_1.gltf")
const BANNER2_SCENE = preload("res://assets/models/props/fantasy/Banner_2.gltf")

@export var landscape: Node3D

## Catálogo oficial de Assentamentos / Vilas e Pontos Notáveis do Mapa
const SETTLEMENTS: Array[Dictionary] = [
	{
		"id": &"vila_esperanca",
		"name": "🏛️ Vila da Esperança",
		"subtitle": "Capital Central • Praça da Cepa-Mãe, Forja, Feira, Cais, Taverna & Capela",
		"pos": Vector3(-1.0, 0.0, 15.0),
		"spawn_offset": Vector3(1.0, 0.0, -14.5),
		"radius": 22.0,
		"can_fast_travel": true,
		"color": Color(0.96, 0.82, 0.42),
		"kind": "capital",
	},
	{
		"id": &"porto_bruma",
		"name": "⚓ Vila Ribeirinha de Porto Bruma",
		"subtitle": "Povoado Pesqueiro do Sul • Doca, Pesca, Nado & Suprimentos",
		"pos": Vector3(42.0, 0.0, 48.0),
		"spawn_offset": Vector3(-3.0, 0.0, -2.0),
		"radius": 13.0,
		"can_fast_travel": true,
		"color": Color(0.38, 0.78, 0.96),
		"kind": "settlement",
	},
	{
		"id": &"vigia_norte",
		"name": "🏔️ Posto da Vigia do Norte",
		"subtitle": "Forte de Caçadores da Serra • Domadores, Cachoeira & Pinheiras-Lume",
		"pos": Vector3(-32.0, 0.0, -72.0),
		"spawn_offset": Vector3(2.5, 0.0, 3.0),
		"radius": 13.0,
		"can_fast_travel": true,
		"color": Color(0.55, 0.90, 0.58),
		"kind": "settlement",
	},
	{
		"id": &"santuario_astral",
		"name": "🪐 Santuário Astral do Mirante",
		"subtitle": "Colinas do Leste • Observatório do Planeta Anelado & Sábio das Cepas",
		"pos": Vector3(82.0, 0.0, -38.0),
		"spawn_offset": Vector3(-3.0, 0.0, 2.0),
		"radius": 13.0,
		"can_fast_travel": true,
		"color": Color(0.78, 0.58, 0.98),
		"kind": "settlement",
	},
]

const LANDMARKS: Array[Dictionary] = [
	{
		"id": &"covil_besta",
		"name": "🦴 Morro da Besta de Sucata",
		"subtitle": "Caçada Inicial • Quebra de Chifre & Esfola",
		"pos": Vector3(-5.0, 0.0, -11.0),
		"color": Color(0.95, 0.55, 0.32),
		"kind": "danger",
	},
	{
		"id": &"arena_monstros",
		"name": "⚔️ Arena da Paliçada Oeste",
		"subtitle": "Combate de Grupo • Slimes, Esqueletos & Morcegos",
		"pos": Vector3(-27.0, 0.0, 3.0),
		"color": Color(0.92, 0.38, 0.38),
		"kind": "danger",
	},
	{
		"id": &"cachoeira_real",
		"name": "🌊 Grande Cachoeira & Lagoa",
		"subtitle": "Queda d'Água do Penhasco Norte • Pesca & Mergulho",
		"pos": Vector3(14.0, 0.0, -24.0),
		"color": Color(0.32, 0.72, 0.95),
		"kind": "nature",
	},
	{
		"id": &"bosque_lume",
		"name": "🌲 Bosque das Pinheiras-Lume",
		"subtitle": "Floresta Bioluminescente • Brilha à Noite",
		"pos": Vector3(26.0, 0.0, -18.0),
		"color": Color(0.38, 0.92, 0.68),
		"kind": "nature",
	},
	{
		"id": &"clareira_anciao",
		"name": "💀 Clareira do Ancião (Boss)",
		"subtitle": "Arena de Pedras • Rinolito Ancião",
		"pos": Vector3(-60.0, 0.0, 50.0),
		"color": Color(0.96, 0.28, 0.32),
		"kind": "boss",
	},
	{
		"id": &"lago_cristalino",
		"name": "💎 Lago Cristalino do Leste",
		"subtitle": "Bacia de Águas Calmas & Afluente das Colinas",
		"pos": Vector3(62.0, 0.0, 18.0),
		"color": Color(0.28, 0.68, 0.92),
		"kind": "nature",
	},
	{
		"id": &"estuario_mar",
		"name": "⚓ Estuário do Mar Aberto",
		"subtitle": "Deságue das Águas do Vale no Mar do Sul",
		"pos": Vector3(26.0, 0.0, 122.0),
		"color": Color(0.24, 0.58, 0.85),
		"kind": "nature",
	},
]

var _gifted_players: Dictionary = {}

func _ready() -> void:
	add_to_group("world_settlements")
	if landscape == null and get_parent():
		landscape = get_parent().get_node_or_null("Landscape")

	_build_crossroads_and_roads()
	_build_capital_waystone()
	_build_porto_bruma()
	_build_vigia_do_norte()
	_build_santuario_astral()

func _ground_y(x: float, z: float) -> float:
	if landscape and landscape.has_method("get_height_at"):
		return landscape.get_height_at(x, z)
	return 0.0

## Retorna o nome da região/assentamento se o jogador estiver dentro de um dos novos povoados ou marcos
static func get_settlement_or_region_at(pos: Vector3) -> String:
	var p2 := Vector2(pos.x, pos.z)
	for s in SETTLEMENTS:
		if s.id == &"vila_esperanca":
			continue
		var c := Vector2(s.pos.x, s.pos.z)
		if p2.distance_to(c) <= float(s.radius):
			return "%s (Zona de Pouso)" % s.name
	for lm in LANDMARKS:
		var c := Vector2(lm.pos.x, lm.pos.z)
		if p2.distance_to(c) <= 14.0:
			return str(lm.name)
	if pos.z < -45.0:
		return "🏔️ Terras Altas da Serra Norte"
	if pos.x > 55.0:
		return "🪐 Colinas Estelares do Leste"
	if pos.z > 40.0 and pos.x > 10.0:
		return "⚓ Várzea Sul de Porto Bruma"
	if pos.x < -40.0 and pos.z > 20.0:
		return "💀 Ermos Bravos do Sudoeste"
	return ""

static func in_any_settlement(x: float, z: float, margin: float = 1.0) -> bool:
	var p := Vector2(x, z)
	for s in SETTLEMENTS:
		var c := Vector2(s.pos.x, s.pos.z)
		if p.distance_to(c) < float(s.radius) + margin:
			return true
	return false

## Teleporta o jogador com segurança para um assentamento (Viagem Rápida)
func fast_travel_to(settlement_id: StringName, player: Node = null) -> bool:
	if player == null and is_inside_tree():
		player = get_tree().get_first_node_in_group("player") as Player
	if player == null:
		return false
	if player.has_meta("carrying_trade_pack") and player.get_meta("carrying_trade_pack") != null:
		if player.has_signal("posture_changed"):
			player.posture_changed.emit("🚫 Viagem Rápida bloqueada: Fardo Comercial nas costas! Viaje fisicamente pelas estradas.")
		return false
	for s in SETTLEMENTS:
		if s.id == settlement_id and s.get("can_fast_travel", false):
			var target: Vector3 = s.pos + s.get("spawn_offset", Vector3.ZERO)
			target.y = _ground_y(target.x, target.z) + 0.6
			player.global_position = target
			if "velocity" in player:
				player.velocity = Vector3.ZERO
			if player.has_signal("posture_changed"):
				player.posture_changed.emit("⚡ Viagem Rápida: chegou em %s!" % s.name)
			return true
	return false

# ---------------------------------------------------------------- Estradas & Placas

func _build_crossroads_and_roads() -> void:
	# Placa Central na Encruzilhada Norte, logo fora do portal da Vila da Esperança
	_create_signpost(
		Vector2(1.6, -12.4),
		"🪧 ENCRUZILHADA DO VALE\n⬆ Norte: Besta (-5,-11) & Vigia do Norte\n⬅ Oeste: Arena (-27,3)  •  ➡ Leste: Rio & Mirante\n⬇ Sul: Porto Bruma (42,48)   [M] Mapa Mundial"
	)
	# Placa na Saída Sul rumo a Porto Bruma, fora do portal sul
	_create_signpost(
		Vector2(2.8, 42.6),
		"🪧 ESTRADA RIBEIRINHA\n↘ Vila de Porto Bruma (42, 48)\n↖ Vila da Esperança"
	)
	# Placa na Subida da Cachoeira rumo à Vigia do Norte
	_create_signpost(
		Vector2(-8.0, -26.0),
		"🪧 SUBIDA DA SERRA\n↖ Posto da Vigia do Norte (-32, -72)\n➡ Grande Cachoeira"
	)
	# Placa rumo ao Santuário Astral no Leste
	_create_signpost(
		Vector2(34.0, -12.0),
		"🪧 TRILHA DAS ESTRELAS\n↗ Santuário Astral do Mirante (82, -38)\n⬅ Ponte & Vila da Esperança"
	)

	# Pedras de estrada guiando as saídas principais
	var road_chains: Array[Array] = [
		# Saída Oeste para Arena (do portal oeste)
		[Vector2(-21.0, 4.2), Vector2(-23.0, 3.8)],
		# Saída Sul para Porto Bruma (do portal sul, beirando o rio)
		[Vector2(0.0, 44.5), Vector2(6.0, 46.0), Vector2(13.0, 47.0), Vector2(20.0, 47.5), Vector2(37.0, 47.5)],
		# Saída Noroeste para Vigia do Norte
		[Vector2(-6.5, -18.0), Vector2(-12.0, -28.0), Vector2(-18.0, -40.0), Vector2(-24.0, -52.0), Vector2(-29.0, -64.0)],
		# Trilha Leste após o rio para o Santuário Astral
		[Vector2(32.0, -10.0), Vector2(44.0, -16.0), Vector2(56.0, -23.0), Vector2(68.0, -30.0)],
	]
	for chain in road_chains:
		for i in chain.size():
			var p: Vector2 = chain[i]
			if RiverSystem.get_distance_to_river(p.x, p.y) < RiverSystem.get_water_half_width(p.y) + 1.5:
				continue
			var tile := PATH_SCENE.instantiate() as Node3D
			tile.position = Vector3(p.x, _ground_y(p.x, p.y) + 0.03, p.y)
			tile.scale = Vector3.ONE * 0.9
			tile.rotation.y = float(i) * 0.4
			add_child(tile)

func _create_signpost(pos2d: Vector2, text: String) -> void:
	var root_post := Node3D.new()
	var y := _ground_y(pos2d.x, pos2d.y)
	root_post.position = Vector3(pos2d.x, y, pos2d.y)
	add_child(root_post)

	var wood_mat := StandardMaterial3D.new()
	wood_mat.albedo_color = Color(0.42, 0.27, 0.14)
	wood_mat.roughness = 0.88

	var pole := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.08
	cyl.bottom_radius = 0.10
	cyl.height = 2.2
	pole.mesh = cyl
	pole.material_override = wood_mat
	pole.position.y = 1.1
	root_post.add_child(pole)

	var board := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.5, 0.42, 0.08)
	board.mesh = box
	board.material_override = wood_mat
	board.position.y = 1.95
	root_post.add_child(board)

	# Placa de estrada: lida de perto, ícone de longe (WorldLabel)
	var lbl := _WorldLabel.make(_WorldLabel.Kind.NAME, text, "🪧")
	lbl.position.y = 2.55
	root_post.add_child(lbl)

# ---------------------------------------------------------------- Marcos de Viagem Rápida

func _build_capital_waystone() -> void:
	_create_waystone(Vector2(6.2, 3.2), &"vila_esperanca", "⚡ Marco de Viagem: Vila da Esperança")

func _create_waystone(pos2d: Vector2, settlement_id: StringName, title: String) -> void:
	var ws := WaystoneInteractable.new()
	ws.name = "Waystone_" + String(settlement_id)
	ws.settlement_id = settlement_id
	ws.title = title
	ws.position = Vector3(pos2d.x, _ground_y(pos2d.x, pos2d.y), pos2d.y)
	add_child(ws)

# ---------------------------------------------------------------- 1. Vila Ribeirinha de Porto Bruma

func _build_porto_bruma() -> void:
	var c := Vector2(42.0, 48.0)
	var hub := Node3D.new()
	hub.name = "VilaPortoBruma"
	add_child(hub)

	# Placa de entrada da vila
	var sign_lbl := _WorldLabel.make(_WorldLabel.Kind.SIGN, "")
	sign_lbl.full_text = "⚓ VILA RIBEIRINHA DE PORTO BRUMA\nDoca dos Pescadores • Comércio & Descanso"
	sign_lbl.modulate = Color(0.55, 0.88, 1.0)
	sign_lbl.sign_range = 45.0
	sign_lbl.position = Vector3(c.x, _ground_y(c.x, c.y) + 3.8, c.y)
	hub.add_child(sign_lbl)

	# Píer / Doca de madeira indo em direção à margem oeste (rio passa a oeste de x=42)
	var river_x := RiverSystem.get_river_center_x(c.y)
	var water_y := RiverSystem.get_water_height(c.y)
	var pier_x := river_x + RiverSystem.get_water_half_width(c.y) + 1.5
	_build_wooden_pier(hub, Vector3(pier_x, water_y + 0.45, c.y), 9.0)

	# Carroça / Tenda de peixes + estandartes
	var cart := CART_SCENE.instantiate() as Node3D
	cart.position = Vector3(c.x + 2.5, _ground_y(c.x + 2.5, c.y - 2.0), c.y - 2.0)
	cart.rotation.y = deg_to_rad(35.0)
	cart.scale = Vector3.ONE * 0.8
	hub.add_child(cart)

	var b1 := BANNER1_SCENE.instantiate() as Node3D
	b1.position = Vector3(c.x - 3.5, _ground_y(c.x - 3.5, c.y - 3.0), c.y - 3.0)
	hub.add_child(b1)

	# Fogueira e Baú de Suprimentos de Porto Bruma
	var fire := Campfire.new()
	fire.name = "FogueiraPortoBruma"
	fire.position = Vector3(c.x, _ground_y(c.x, c.y + 1.5), c.y + 1.5)
	hub.add_child(fire)

	var chest := SupplyChest.new()
	chest.name = "BauPortoBruma"
	chest.position = Vector3(c.x + 3.2, _ground_y(c.x + 3.2, c.y + 1.2), c.y + 1.2)
	hub.add_child(chest)

	_create_waystone(c + Vector2(-2.8, -3.2), &"porto_bruma", "⚡ Marco de Viagem: Porto Bruma")

	# NPC: Mestre Pescador Cauã
	var fisher_dna := CharacterDNA.randomized(4201)
	fisher_dna.cosmetic_hat = "chapeu_cacador"
	fisher_dna.shirt_color = Color("#2e6f95")
	var fisher := TownNPC.new()
	fisher.name = "MestrePescadorCaua"
	fisher.dna = fisher_dna
	fisher.display_name = "Mestre Pescador Cauã"
	fisher.icon = "🎣"
	fisher.idle_anim = &"Idle_Talking"
	fisher.prompt = "[E] Conversar sobre o Rio & Pesca"
	fisher.position = Vector3(c.x - 1.2, _ground_y(c.x - 1.2, c.y - 0.8), c.y - 0.8)
	fisher.talked.connect(func(player: Node) -> void:
		if player == null:
			return
		var inv: InventoryComponent = player.get("inventory")
		if inv and not _gifted_players.has("porto_bruma"):
			_gifted_players["porto_bruma"] = true
			inv.add_material(&"vara_pesca", 1)
			inv.add_material(&"carne_bem_passada", 3)
			if player.has_signal("posture_changed"):
				player.posture_changed.emit("🎣 Cauã: 'Bem-vindo a Porto Bruma! Tome 3 Peixes Assados e uma Vara nova. Use na beira d'água!'")
		elif player.has_signal("posture_changed"):
			player.posture_changed.emit("🎣 Cauã: 'Quando chove forte o rio enche a várzea! Nade até o fundo ou use a Vara de Pesca na margem.'")
	)
	hub.add_child(fisher)

func _build_wooden_pier(parent: Node3D, start: Vector3, length: float) -> void:
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.40, 0.26, 0.14)
	wood.roughness = 0.9

	var deck := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(length, 0.22, 2.8)
	deck.mesh = box
	deck.material_override = wood
	deck.position = start - Vector3(length * 0.35, 0.0, 0.0)
	parent.add_child(deck)

	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var bshape := BoxShape3D.new()
	bshape.size = box.size
	shape.shape = bshape
	body.add_child(shape)
	deck.add_child(body)

# ---------------------------------------------------------------- 2. Posto da Vigia do Norte

func _build_vigia_do_norte() -> void:
	var c := Vector2(-32.0, -72.0)
	var hub := Node3D.new()
	hub.name = "PostoVigiaDoNorte"
	add_child(hub)

	var sign_lbl := _WorldLabel.make(_WorldLabel.Kind.SIGN, "")
	sign_lbl.full_text = "🏔️ POSTO DA VIGIA DO NORTE\nGuardiões da Serra • Domadores & Caçadores"
	sign_lbl.modulate = Color(0.68, 0.96, 0.68)
	sign_lbl.sign_range = 45.0
	sign_lbl.position = Vector3(c.x, _ground_y(c.x, c.y) + 4.2, c.y)
	hub.add_child(sign_lbl)

	# Guarita / Plataforma de Vigia de madeira
	_build_watchtower_deck(hub, Vector3(c.x - 3.5, _ground_y(c.x - 3.5, c.y - 2.5), c.y - 2.5))

	var b2 := BANNER2_SCENE.instantiate() as Node3D
	b2.position = Vector3(c.x + 2.5, _ground_y(c.x + 2.5, c.y - 2.0), c.y - 2.0)
	hub.add_child(b2)

	var fire := Campfire.new()
	fire.name = "FogueiraVigiaNorte"
	fire.position = Vector3(c.x, _ground_y(c.x, c.y + 1.0), c.y + 1.0)
	hub.add_child(fire)

	_create_waystone(c + Vector2(3.5, 2.0), &"vigia_norte", "⚡ Marco de Viagem: Vigia do Norte")

	# NPC: Guarda-Florestal Iara
	var ranger_dna := CharacterDNA.randomized(7202)
	ranger_dna.femininity = 0.88
	ranger_dna.beard = CharacterDNA.Beard.NONE
	ranger_dna.hair_style = CharacterDNA.HairStyle.PONYTAIL
	ranger_dna.cosmetic_hat = "chapeu_cacador"
	ranger_dna.cosmetic_cape = "manto_andarilho"
	ranger_dna.shirt_color = Color("#2f5e3d")
	var ranger := TownNPC.new()
	ranger.name = "GuardaFlorestalIara"
	ranger.dna = ranger_dna
	ranger.display_name = "🦅 Guarda-Florestal Iara"
	ranger.idle_anim = &"Idle_FoldArms"
	ranger.prompt = "[E] Conversar sobre Montarias & Caça"
	ranger.position = Vector3(c.x + 1.2, _ground_y(c.x + 1.2, c.y - 0.8), c.y - 0.8)
	ranger.talked.connect(func(player: Node) -> void:
		if player == null:
			return
		var inv: InventoryComponent = player.get("inventory")
		if inv and not _gifted_players.has("vigia_norte"):
			_gifted_players["vigia_norte"] = true
			inv.add_material(&"laco_captura", 2)
			inv.add_material(&"sedativo_erva", 2)
			if player.has_signal("posture_changed"):
				player.posture_changed.emit("🦅 Iara: 'Subiu a Serra! Tome 2 Laços e 2 Sedativos: enfraqueça ou sedative um bicho, lance o Laço e monte com [E]!'")
		elif player.has_signal("posture_changed"):
			player.posture_changed.emit("🦅 Iara: 'À noite as Pinheiras-Lume brilham na serra! E cuidado com as tocas de Lobos-do-Ermo nos limites do vale.'")
	)
	hub.add_child(ranger)

func _build_watchtower_deck(parent: Node3D, pos: Vector3) -> void:
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.38, 0.25, 0.14)
	wood.roughness = 0.88
	var roof_mat := StandardMaterial3D.new()
	roof_mat.albedo_color = Color(0.22, 0.36, 0.22)

	for corner in [Vector2(-1.4, -1.4), Vector2(1.4, -1.4), Vector2(-1.4, 1.4), Vector2(1.4, 1.4)]:
		var pillar := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.12
		cyl.bottom_radius = 0.14
		cyl.height = 3.2
		pillar.mesh = cyl
		pillar.material_override = wood
		pillar.position = pos + Vector3(corner.x, 1.6, corner.y)
		parent.add_child(pillar)

	var roof := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.1
	cone.bottom_radius = 2.4
	cone.height = 1.4
	cone.radial_segments = 6
	roof.mesh = cone
	roof.material_override = roof_mat
	roof.position = pos + Vector3(0, 3.8, 0)
	parent.add_child(roof)

# ---------------------------------------------------------------- 3. Santuário Astral do Mirante

func _build_santuario_astral() -> void:
	var c := Vector2(82.0, -38.0)
	var hub := Node3D.new()
	hub.name = "SantuarioAstral"
	add_child(hub)

	var sign_lbl := _WorldLabel.make(_WorldLabel.Kind.SIGN, "")
	sign_lbl.full_text = "🪐 SANTUÁRIO ASTRAL DO MIRANTE\nObservatório do Planeta com Anéis & Sabedoria das Cepas"
	sign_lbl.modulate = Color(0.85, 0.68, 1.0)
	sign_lbl.sign_range = 45.0
	sign_lbl.position = Vector3(c.x, _ground_y(c.x, c.y) + 4.2, c.y)
	hub.add_child(sign_lbl)

	# Gerador Procedural do Santuário Astral (@tool):
	# Varre assets manuais, ergue o Altar Central + 8 Pilares Rúnicos com OmniLight3D + GPUParticles3D
	# e popula a flora/rochas densas via MultiMeshInstance3D + FastNoiseLite.
	var spawner := AstralSanctuarySpawner.new()
	spawner.name = "AstralSanctuarySpawner"
	spawner.terrain_provider = landscape
	spawner.sanctuary_center = Vector3(c.x, _ground_y(c.x, c.y), c.y)
	hub.add_child(spawner)

	var fire := Campfire.new()
	fire.name = "FogueiraSantuarioAstral"
	fire.position = Vector3(c.x + 2.8, _ground_y(c.x + 2.8, c.y + 2.2), c.y + 2.2)
	hub.add_child(fire)

	_create_waystone(c + Vector2(-3.5, 2.5), &"santuario_astral", "⚡ Marco de Viagem: Santuário Astral")

	# NPC: Sábio Astral Celiano
	var sage_dna := CharacterDNA.randomized(9303)
	sage_dna.cosmetic_hat = "coroa_solar"
	sage_dna.cosmetic_cape = "manto_estelar"
	sage_dna.cosmetic_aura = "aura_cosmica"
	var sage := TownNPC.new()
	sage.name = "SabioAstralCeliano"
	sage.dna = sage_dna
	sage.display_name = "🪐 Sábio Astral Celiano"
	sage.idle_anim = &"Idle_Talking"
	sage.prompt = "[E] Conversar sobre o Cosmos & Cartas"
	sage.position = Vector3(c.x + 1.8, _ground_y(c.x + 1.8, c.y - 1.2), c.y - 1.2)
	sage.talked.connect(func(player: Node) -> void:
		if player == null:
			return
		var inv: InventoryComponent = player.get("inventory")
		if inv and not _gifted_players.has("santuario_astral"):
			_gifted_players["santuario_astral"] = true
			inv.add_material(&"mega_pocao", 2)
			if player.has_signal("posture_changed"):
				player.posture_changed.emit("🪐 Celiano: 'Olhe para cima! O Gigante Anelado guarda segredos antigos. Receba 2 Mega Poções para sua jornada!'")
		elif player.has_signal("posture_changed"):
			player.posture_changed.emit("🪐 Celiano: 'Daqui das Colinas do Leste você vê as estrelas cadentes e o Planeta com Anéis com perfeição à noite!'")
	)
	hub.add_child(sage)


## Subclasse interna: Marco de Viagem Rápida interativo com [E] (abre o Mapa Mundial [M])
class WaystoneInteractable extends Node3D:
	var settlement_id: StringName = &"vila_esperanca"
	var title: String = "⚡ Marco de Viagem"
	var _prompt: _WorldLabel
	var _rune_mat: StandardMaterial3D
	var _rune_light: OmniLight3D
	var _time: float = 0.0

	## Traços da runa (x, y, comprimento, ângulo em graus) na face da pedra: um ᛉ com base
	const RUNE_STROKES := [
		[0.0, 1.0, 0.62, 0.0],
		[-0.09, 1.2, 0.26, 35.0],
		[0.09, 1.2, 0.26, -35.0],
		[0.0, 0.66, 0.2, 90.0],
	]

	func _ready() -> void:
		add_to_group("talkable")
		add_to_group("waystones")
		_build_mesh()

	## Pedra de pé (menir facetado) com runa entalhada que brilha e pulsa (B25: sai a esfera).
	func _build_mesh() -> void:
		var stone_mat := StandardMaterial3D.new()
		stone_mat.albedo_color = Color(0.36, 0.38, 0.4)
		stone_mat.roughness = 0.95

		var stone := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.24
		cyl.bottom_radius = 0.36
		cyl.height = 1.7
		cyl.radial_segments = 6
		cyl.rings = 1
		stone.mesh = cyl
		stone.material_override = stone_mat
		stone.position.y = 0.8
		stone.rotation.y = deg_to_rad(30.0)  # hexágono com uma face lisa virada para +z
		var holder := Node3D.new()  # leve inclinação de pedra fincada; a runa vai junto
		holder.rotation.z = deg_to_rad(-3.0)
		add_child(holder)
		var flat := Node3D.new()  # achata só a pedra, no eixo da face (z)
		flat.scale = Vector3(1.0, 1.0, 0.55)
		holder.add_child(flat)
		flat.add_child(stone)
		# Pedras soltas na base, para não parecer um poste
		for i in 3:
			var pebble := ROCK_SCENE.instantiate() as Node3D
			if pebble == null:
				continue
			var a := TAU * i / 3.0 + 0.6
			pebble.scale = Vector3.ONE * (0.22 - i * 0.03)
			pebble.position = Vector3(cos(a) * 0.42, 0.0, sin(a) * 0.32)
			pebble.rotation.y = a * 2.0
			add_child(pebble)

		_rune_mat = StandardMaterial3D.new()
		_rune_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_rune_mat.albedo_color = Color(0.45, 0.92, 1.0)
		var face_z := 0.36 * cos(PI / 6.0) * 0.55  # apótema da base × achatamento
		for s in RUNE_STROKES:
			var stroke := MeshInstance3D.new()
			var bar := BoxMesh.new()
			bar.size = Vector3(0.035, s[2], 0.01)
			stroke.mesh = bar
			stroke.material_override = _rune_mat
			stroke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			# a face afina para cima: acompanha o recuo da pedra na altura do traço
			var y: float = s[1]
			var inset := (0.36 - 0.12 * y / 1.7) * cos(PI / 6.0) * 0.55
			stroke.position = Vector3(s[0], y, inset + 0.004)
			stroke.rotation = Vector3(-atan2((face_z - inset), y), 0.0, deg_to_rad(s[3]))
			holder.add_child(stroke)
		var glow := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(0.75, 0.95)
		var glow_mat := StandardMaterial3D.new()
		glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		glow_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		glow_mat.albedo_texture = TutorialTrail.soft_dot()
		glow_mat.albedo_color = Color(0.3, 0.8, 1.0, 0.35)
		quad.material = glow_mat
		glow.mesh = quad
		glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		glow.position = Vector3(0, 1.0, face_z + 0.03)
		holder.add_child(glow)
		_rune_light = OmniLight3D.new()
		_rune_light.light_color = Color(0.4, 0.85, 1.0)
		_rune_light.omni_range = 2.6
		_rune_light.light_energy = 0.8
		_rune_light.shadow_enabled = false
		_rune_light.position = Vector3(0, 1.0, 0.45)
		add_child(_rune_light)

		var name_lbl := _WorldLabel.make(_WorldLabel.Kind.NAME, title.trim_prefix("⚡ "), "⚡", Color(0.55, 0.92, 1.0))
		name_lbl.position.y = 2.45
		add_child(name_lbl)
		_prompt = _WorldLabel.make(_WorldLabel.Kind.PROMPT, "[E] Abrir Mapa & Viajar [M]")
		_prompt.position.y = 2.2
		add_child(_prompt)

	func _process(delta: float) -> void:
		_time += delta
		# Runa respira devagar
		var k := 0.75 + sin(_time * 1.6) * 0.25
		if _rune_mat:
			_rune_mat.albedo_color = Color(0.45, 0.92, 1.0) * (0.8 + k * 0.6)
		if _rune_light:
			_rune_light.light_energy = 0.5 + k * 0.5

	func talk_to(player: Node) -> void:
		if not is_inside_tree() or get_tree().current_scene == null:
			return
		var map_screen := get_tree().current_scene.find_child("WorldMapScreen", true, false)
		if map_screen and map_screen.has_method("open_map"):
			map_screen.open_map(player as Player)
