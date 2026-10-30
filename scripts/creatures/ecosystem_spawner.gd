class_name EcosystemSpawner
extends Node3D

## Povoa o vale com fauna e flora procedurais (GDD-09 §4): rebanhos de Trotador, Saltarelos,
## Planadores no céu, Raias e cardumes de Lambari no rio, e árvores, arbustos, Cepas Selvagens e
## cogumelos-lume. Nada nasce na vila, na água nem na arena. Também monta o Estábulo com as
## montarias de teste (Trotador e Planador) e põe a Raia montável no rio perto da vila.

const ARENA_CENTER: Vector2 = Vector2(-27.0, 3.0)
## Montarias próprias por personagem (decisão do Tarciso, GDD-03 §9.4)
const MAX_OWNED: int = 3
## Bicho morto, capturado ou solto volta a nascer no mesmo lugar depois disso (s)
const RESPAWN_DELAY: float = 90.0
## População mínima (repõe se cair abaixo) e máxima (para de reproduzir) por espécie
const POP_MIN: Dictionary = {CreatureDNA.Species.TROTADOR: 4, CreatureDNA.Species.SALTARELO: 4, CreatureDNA.Species.PLANADOR: 2,
	CreatureDNA.Species.LAMBARI: 16, CreatureDNA.Species.TRAIRA: 4, CreatureDNA.Species.DOURADO: 2}
const POP_MAX: Dictionary = {CreatureDNA.Species.TROTADOR: 24, CreatureDNA.Species.SALTARELO: 18, CreatureDNA.Species.PLANADOR: 6}
const MOUNTABLE: Dictionary = {CreatureDNA.Species.TROTADOR: Mount.Kind.LAND, CreatureDNA.Species.PLANADOR: Mount.Kind.AIR}
const STABLE_POS: Vector2 = Vector2(-15.0, -5.0)
## Cuidar (escovar e tratar) só vale com a montaria perto do estábulo (GDD-16 §2)
const CARE_RADIUS: float = 12.0
## Ninhos de Planador (Prova do Ninho, GDD-16 §4): nos morros mais altos, longe uns dos outros
const NEST_COUNT: int = 2
const NEST_GAP: float = 60.0

@export var landscape: Node3D
@export var world_seed: int = 2026

@export_group("Quantidades")
@export var trotador_herds: int = 6
@export var saltarelos: int = 12
@export var planadores: int = 4
@export var raias: int = 3
@export var lambari_schools: int = 6
@export var trairas: int = 5
@export var dourados: int = 2
@export var trees: int = 60
@export var bushes: int = 55
@export var cepas: int = 50
@export var mushrooms: int = 30
## Pinheiras-Lume (GDD-10 §9): bosques pequenos, para o pólen ir de uma para outra
@export var pinheira_groves: int = 2
@export var pinheiras_per_grove: int = 4

var _rng := RandomNumberGenerator.new()
## DNAs das montarias capturadas (save) e os nós delas no estábulo
var owned: Array[CreatureDNA] = []
## Elo de cada montaria própria, na mesma ordem de `owned` (GDD-16)
var bonds: Array[MountBond] = []
var _owned_nodes: Array[Mount] = []
var _stable_base: Vector3
var _dialog: CaptureDialog
var _pending_capture: WildCreature
var _pending_player: Node
var _care_dialog: MountCareDialog
var _care_mount: Mount
var _care_player: Player

func _ready() -> void:
	add_to_group("ecosystem")
	if landscape == null:
		landscape = get_parent().get_node_or_null("Landscape")
	_rng.seed = world_seed
	var layer := CanvasLayer.new()
	layer.layer = 12
	add_child(layer)
	_dialog = CaptureDialog.new()
	layer.add_child(_dialog)
	_dialog.chosen.connect(_on_capture_choice)
	_care_dialog = MountCareDialog.new()
	layer.add_child(_care_dialog)
	_care_dialog.chosen.connect(_on_care_choice)
	# Fome das montarias próprias: confere o dia de jogo de tempos em tempos
	var hunger := Timer.new()
	hunger.wait_time = 5.0
	hunger.autostart = true
	hunger.timeout.connect(tick_bonds)
	add_child(hunger)
	# Continuando um jogo com a natureza salva: ela volta pelo save, não precisa semear agora
	var save := get_node_or_null("/root/SaveGame")
	if not (save and save.load_on_enter and save.read_save().has("nature")):
		_spawn_plants()
		_spawn_fauna()
	_build_stable()
	_spawn_nests()

# ---------------------------------------------------------------- flora

func _spawn_plants() -> void:
	var plan := [[PlantDNA.Kind.ARVORE, trees, 16.0], [PlantDNA.Kind.ARBUSTO, bushes, 15.0], [PlantDNA.Kind.CEPA, cepas, 15.0], [PlantDNA.Kind.COGUMELO, mushrooms, 15.0]]
	for p in plan:
		for i in p[1]:
			var spot := _land_spot(p[2], WorldBounds.HALF * 0.92)
			if spot == Vector3.INF:
				continue
			var plant := PlantBody.new()
			plant.dna = PlantDNA.randomized(p[0], _rng.randi())
			# O vale já está vivo: idades e estágios variados (GDD-10 §4)
			var roll := _rng.randf()
			plant.stage = PlantBody.Stage.JOVEM if roll < 0.15 else (PlantBody.Stage.FLORIDA if roll < 0.35 else (PlantBody.Stage.FRUTO if roll < 0.5 else PlantBody.Stage.ADULTA))
			plant.age = _rng.randf() * plant.lifespan() * 0.6
			plant.progress = _rng.randf() * 0.8
			plant.position = spot
			plant.rotation.y = _rng.randf() * TAU
			add_child(plant)
	_spawn_pinheiras()

## Bosques de Pinheira-Lume com idades variadas; o primeiro fica perto da vila, para ser visto
func _spawn_pinheiras() -> void:
	var stages := [PlantBody.Stage.FRUTO, PlantBody.Stage.ADULTA, PlantBody.Stage.FRUTO, PlantBody.Stage.FLORIDA, PlantBody.Stage.JOVEM]
	for g in pinheira_groves:
		var center := _land_spot(24.0 if g == 0 else 55.0, 40.0 if g == 0 else WorldBounds.HALF * 0.8)
		if center == Vector3.INF:
			continue
		for i in pinheiras_per_grove:
			var a := TAU * i / pinheiras_per_grove + _rng.randf() * 0.5
			var x := center.x + cos(a) * _rng.randf_range(7.0, 12.0)
			var z := center.z + sin(a) * _rng.randf_range(7.0, 12.0)
			if CityHub.in_village(x, z, 3.0) or RiverSystem.get_distance_to_river(x, z) < RiverSystem.get_water_half_width(z) + 3.0 or not WorldBounds.inside(x, z, 6.0):
				continue
			var plant := PlantBody.new()
			plant.dna = PlantDNA.randomized(PlantDNA.Kind.PINHEIRA, _rng.randi())
			plant.stage = stages[(i + g) % stages.size()]
			plant.age = _rng.randf_range(8.0, 20.0)
			plant.progress = _rng.randf() * 0.6
			plant.position = Vector3(x, _ground(x, z), z)
			plant.rotation.y = _rng.randf() * TAU
			add_child(plant)

# ---------------------------------------------------------------- fauna

func _spawn_fauna() -> void:
	for h in trotador_herds:
		var center := _land_spot(25.0, WorldBounds.HALF * 0.85)
		if center == Vector3.INF:
			continue
		for i in _rng.randi_range(3, 4):
			_add_wild(CreatureDNA.Species.TROTADOR, center + Vector3(_rng.randf_range(-3, 3), 0, _rng.randf_range(-3, 3)), 14.0)
	for i in saltarelos:
		var spot := _land_spot(16.0, WorldBounds.HALF * 0.85)
		if spot != Vector3.INF:
			_add_wild(CreatureDNA.Species.SALTARELO, spot, 8.0)
	for i in planadores:
		var spot := _land_spot(20.0, WorldBounds.HALF * 0.7)
		if spot != Vector3.INF:
			_add_wild(CreatureDNA.Species.PLANADOR, spot + Vector3(0, 15, 0), 16.0)
	for i in raias:
		_add_wild(CreatureDNA.Species.RAIA, _river_spot(_rng.randf_range(15.0, WorldBounds.HALF * 0.8)), 18.0)
	_spawn_fish(false)

## Peixes do rio (GDD-10 §8). Com `only_missing`, só repõe espécie que está abaixo do mínimo —
## save antigo, de antes da Traíra e do Dourado, ganha os peixes novos ao carregar
func _spawn_fish(only_missing: bool) -> void:
	if not only_missing or population(CreatureDNA.Species.LAMBARI) < POP_MIN[CreatureDNA.Species.LAMBARI]:
		for s in lambari_schools:
			var z := _rng.randf_range(-12.0, WorldBounds.HALF * 0.8)
			for i in 4:
				_add_wild(CreatureDNA.Species.LAMBARI, _river_spot(z + i * 0.6), 10.0)
	# Traíras nos remansos do rio de baixo e no rio da serra; Dourados no poço da cachoeira
	if not only_missing or population(CreatureDNA.Species.TRAIRA) < POP_MIN[CreatureDNA.Species.TRAIRA]:
		for i in trairas:
			var z := _rng.randf_range(-80.0, -34.0) if i == 0 else _rng.randf_range(-8.0, WorldBounds.HALF * 0.8)
			_add_wild(CreatureDNA.Species.TRAIRA, _river_spot(z), 8.0)
	if not only_missing or population(CreatureDNA.Species.DOURADO) < POP_MIN[CreatureDNA.Species.DOURADO]:
		for i in dourados:
			_add_wild(CreatureDNA.Species.DOURADO, _river_spot(RiverSystem.WATERFALL_Z + _rng.randf_range(4.0, 10.0)), 5.0)

func _add_wild(species: CreatureDNA.Species, pos: Vector3, roam: float, p_dna: CreatureDNA = null) -> WildCreature:
	var c := WildCreature.new()
	c.dna = p_dna if p_dna else CreatureDNA.randomized(species, _rng.randi())
	c.roam_radius = roam
	c.position = pos
	c.captured.connect(_on_captured)
	c.removed.connect(_on_removed.bind(species, pos, roam))
	add_child(c)
	return c

# ---------------------------------------------------------------- captura (GDD-03 §9.3)

func _on_captured(c: WildCreature, player: Node) -> void:
	EventBusAutoload.report(player, &"captura", {"species": c.dna.species_name()})
	_pending_capture = c
	_pending_player = player
	var can := MOUNTABLE.has(c.dna.species) and owned.size() < MAX_OWNED
	var reason := "só Trotador e Planador viram montaria" if not MOUNTABLE.has(c.dna.species) else "estábulo cheio: %d/%d" % [owned.size(), MAX_OWNED]
	_dialog.ask(c.dna, can, reason)

func _on_capture_choice(choice: StringName) -> void:
	var c := _pending_capture
	_pending_capture = null
	if c == null or not is_instance_valid(c):
		return
	match choice:
		&"abate":
			c.careful_slaughter()
			_say("🔪 Abate cuidadoso: segure [E] no corpo para esfolar as partes Íntegras")
		&"estabulo":
			if add_owned_mount(c.dna):
				_say("🐎 %s levado ao estábulo! (%d/%d)" % [c.dna.species_name(), owned.size(), MAX_OWNED])
			c.take_away()
		&"rancho":
			if _pending_player != null and _pending_player.has_method("add_livestock"):
				_pending_player.add_livestock(c.dna)
			else:
				_say("🏡 %s enviado ao Rancho como matriz reprodutiva!" % c.dna.species_name())
			c.take_away()
		_:
			_say("🌿 Você soltou o %s" % c.dna.species_name())
			c.take_away()

## Bicho que sumiu só é reposto se a espécie ficou rara (o resto vem da reprodução)
func _on_removed(_c: WildCreature, species: CreatureDNA.Species, pos: Vector3, roam: float) -> void:
	if not is_inside_tree():
		return
	await get_tree().create_timer(RESPAWN_DELAY).timeout
	if is_inside_tree() and population(species) < POP_MIN.get(species, 2):
		_add_wild(species, pos, roam)

func population(species: CreatureDNA.Species) -> int:
	var n := 0
	for c in get_tree().get_nodes_in_group("wild_creatures"):
		if c is WildCreature and c.dna.species == species and c.is_alive():
			n += 1
	return n

## Filhote de dois adultos (GDD-10 §5): DNA cruzado com mutação de 3%, nasce pequeno
func spawn_offspring(a: WildCreature, b: WildCreature) -> bool:
	if population(a.dna.species) >= POP_MAX.get(a.dna.species, 10):
		return false
	var c := _add_wild(a.dna.species, (a.global_position + b.global_position) * 0.5, a.roam_radius)
	c.dna = CreatureDNA.cross(a.dna, b.dna, _rng.randi())
	c.body.dna = c.dna
	c.body.build()
	c.age_days = 0.0
	c.hunger = 0.3
	c.thirst = 0.3
	c.breed_cooldown = WildCreature.BREED_COOLDOWN
	return true

## Filhote nascido de gestação por DNA de pai e mãe (GDD-14)
func spawn_from_dna(mother_dna: CreatureDNA, father_dna: CreatureDNA, pos: Vector3, roam: float) -> WildCreature:
	if population(mother_dna.species) >= POP_MAX.get(mother_dna.species, 10):
		return null
	var c := _add_wild(mother_dna.species, pos, roam)
	c.dna = CreatureDNA.cross(mother_dna, father_dna, _rng.randi())
	c.body.dna = c.dna
	c.body.build()
	c.age_days = 0.0
	c.hunger = 0.3
	c.thirst = 0.3
	c.breed_cooldown = WildCreature.BREED_COOLDOWN
	return c

# ---------------------------------------------------------------- save da natureza (GDD-10)

## Plantas e bichos vivos como estão agora (posição, DNA, idade, fome, sede)
func nature_state() -> Dictionary:
	var plants := []
	for n in get_tree().get_nodes_in_group("plants"):
		var p := n as PlantBody
		if p == null or p.is_queued_for_deletion():
			continue
		var pos := p.global_position
		plants.append({
			"dna": p.dna.to_dict(), "stage": p.stage, "age": snappedf(p.age, 0.01), "progress": snappedf(p.progress, 0.01),
			"stress": snappedf(p.stress, 0.01), "pos": [snappedf(pos.x, 0.01), snappedf(pos.y, 0.01), snappedf(pos.z, 0.01)],
			"rot": snappedf(p.rotation.y, 0.01), "garden": p.garden, "by": p.planted_by,
		})
	# Pinhas no chão: são sementes esperando brotar (GDD-10 §9)
	var pinhas := []
	for n in get_tree().get_nodes_in_group("pinhas"):
		var f := n as PinhaFruit
		if f and not f.is_collected and not f.is_queued_for_deletion():
			var pos := f.global_position
			pinhas.append({"gen": f.dna.genome_code(), "age": snappedf(f.age_days, 0.01), "pos": [snappedf(pos.x, 0.01), snappedf(pos.y, 0.01), snappedf(pos.z, 0.01)]})
	var wild := []
	for n in get_tree().get_nodes_in_group("wild_creatures"):
		var c := n as WildCreature
		if c == null or c.is_queued_for_deletion() or not c.is_alive() or c.state == WildCreature.State.CAPTURED:
			continue
		var pos := c.global_position
		wild.append({
			"dna": c.dna.to_dict(), "pos": [snappedf(pos.x, 0.01), snappedf(pos.y, 0.01), snappedf(pos.z, 0.01)],
			"home": [snappedf(c.home.x, 0.01), snappedf(c.home.y, 0.01), snappedf(c.home.z, 0.01)], "roam": c.roam_radius,
			"age": snappedf(c.age_days, 0.01), "life": snappedf(c.lifespan_days, 0.01), "hunger": snappedf(c.hunger, 0.01),
			"thirst": snappedf(c.thirst, 0.01), "breed": snappedf(c.breed_cooldown, 0.01),
			"gut": c.gut.map(func(g): return {"gen": g.dna.genome_code(), "t": snappedf(g.t, 0.01)}),
		})
	return {"plants": plants, "wild": wild, "pinhas": pinhas}

## Troca a natureza do mundo pela do save
func restore_nature(d: Dictionary) -> void:
	for n in get_tree().get_nodes_in_group("plants"):
		n.remove_from_group("plants")
		n.queue_free()
	for n in get_tree().get_nodes_in_group("wild_creatures"):
		var c := n as WildCreature
		if c and c.state != WildCreature.State.CAPTURED:
			c.remove_from_group("wild_creatures")
			c.queue_free()
	for e in d.get("plants", []):
		var plant := PlantBody.new()
		plant.dna = PlantDNA.from_dict(e.get("dna", {}))
		plant.stage = int(e.get("stage", PlantBody.Stage.ADULTA)) as PlantBody.Stage
		plant.age = float(e.get("age", 0.0))
		plant.progress = float(e.get("progress", 0.0))
		plant.stress = float(e.get("stress", 0.0))
		plant.position = _vec(e.get("pos", [0, 0, 0]))
		plant.rotation.y = float(e.get("rot", 0.0))
		plant.garden = bool(e.get("garden", false))
		plant.planted_by = str(e.get("by", ""))
		add_child(plant)
	for n in get_tree().get_nodes_in_group("pinhas"):
		n.remove_from_group("pinhas")
		n.remove_from_group("fallen_fruit")
		n.queue_free()
	var eco := get_tree().get_first_node_in_group("ecology") as Ecology
	if eco:
		for e in d.get("pinhas", []):
			eco.spawn_pinha(PlantDNA.from_genome_code(str(e.get("gen", ""))), _vec(e.get("pos", [0, 0, 0])), float(e.get("age", 0.0)))
	# Save de antes da Pinheira-Lume: o vale ganha os bosques
	if not d.get("plants", []).any(func(e): return e.get("dna", {}).has("gen")):
		_spawn_pinheiras()
	for e in d.get("wild", []):
		var dna := CreatureDNA.from_dict(e.get("dna", {}))
		var c := _add_wild(dna.species, _vec(e.get("pos", [0, 0, 0])), float(e.get("roam", 14.0)), dna)
		c.home = _vec(e.get("home", e.get("pos", [0, 0, 0])))
		c.age_days = float(e.get("age", 4.0))
		c.lifespan_days = float(e.get("life", 15.0))
		c.hunger = float(e.get("hunger", 0.2))
		c.thirst = float(e.get("thirst", 0.2))
		c.breed_cooldown = float(e.get("breed", 0.0))
		for g in e.get("gut", []):
			c.gut.append({"dna": PlantDNA.from_genome_code(str(g.get("gen", ""))), "t": float(g.get("t", 0.2))})
	_spawn_fish.call_deferred(true) # depois do queue_free dos bichos antigos

static func _vec(a: Array) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))

func _say(msg: String) -> void:
	if _pending_player and is_instance_valid(_pending_player) and _pending_player.has_signal("posture_changed"):
		_pending_player.posture_changed.emit(msg)

## Põe um bicho no estábulo como montaria própria; false se cheio ou não montável.
## Sem Elo dado, é a captura no laço (Elo 10, não marcada).
func add_owned_mount(d: CreatureDNA, bond: MountBond = null) -> bool:
	if owned.size() >= MAX_OWNED or not MOUNTABLE.has(d.species):
		return false
	owned.append(d)
	bonds.append(bond if bond else MountBond.create(d, &"laco", today()))
	_spawn_owned(d, owned.size() - 1)
	return true

func _spawn_owned(d: CreatureDNA, slot: int) -> void:
	var m := _add_mount(d, MOUNTABLE[d.species], "Seu " + d.species_name().get_slice("-", 0), _stable_base + Vector3(-3.0 + slot * 3.0, 0, 4.0))
	m.owned = true
	m.set_bond(bonds[slot])
	m.care_requested.connect(_on_care_requested)
	m.died.connect(_on_owned_died)
	_owned_nodes.append(m)

## Morte permanente (GDD-16 §7): sai do estábulo e do save; no corpo fica a Lembrança (3★, Saudade)
func _on_owned_died(m: Mount) -> void:
	var i := _owned_nodes.find(m)
	if i < 0:
		return
	_owned_nodes.remove_at(i)
	owned.remove_at(i)
	bonds.remove_at(i)
	if _care_mount == m:
		_care_dialog.close()
		_care_mount = null
	var spot := m.global_position
	spot.y = _ground(spot.x, spot.z) + 0.2
	# A Lembrança guarda quem ela foi (nome, espécie, Elo e o dia em que morreu)
	var memory := {"kind": "lembranca", "name": m.display_name, "species": m.dna.species_name(), "elo": floori(m.bond.elo), "day": today()}
	DroppedLoot.spawn_for_stack(self, m.global_position + Vector3.UP, spot, {"id": &"lembranca", "quality": 3, "traits": [&"saudade"], "amount": 1, "memory": memory})
	EventBusAutoload.report(get_tree().get_first_node_in_group("player"), &"companheira_perdida", memory)
	_tell(get_tree().get_first_node_in_group("player"), "💔 %s morreu. Ficou a Lembrança dela no chão." % m.display_name)
	m.queue_free()

static func today() -> int:
	return MountBond.today()

func owned_state() -> Array:
	var out: Array = []
	for i in owned.size():
		var e := owned[i].to_dict()
		e["bond"] = bonds[i].to_dict()
		out.append(e)
	return out

func restore_owned(list: Array) -> void:
	for m in _owned_nodes:
		if is_instance_valid(m):
			if m.rider:
				m.dismount()
			m.queue_free()
	_owned_nodes.clear()
	owned.clear()
	bonds.clear()
	for e in list:
		if e is Dictionary and owned.size() < MAX_OWNED:
			var d := CreatureDNA.from_dict(e)
			# Save de antes do GDD-16: entra como capturada no laço
			var bond: MountBond = MountBond.from_dict(e["bond"], d) if e.get("bond") is Dictionary else null
			add_owned_mount(d, bond)

## Ninhos no alto: os pontos mais altos do relevo, fora da vila, do rio e do estábulo
func _spawn_nests() -> void:
	if landscape == null or not landscape.has_method("get_height_at"):
		return
	var spots: Array = []
	var half := WorldBounds.HALF * 0.9
	var x := -half
	while x <= half:
		var z := -half
		while z <= half:
			if not CityHub.in_village(x, z, 20.0) and Vector2(x, z).distance_to(STABLE_POS) > 30.0 					and RiverSystem.get_distance_to_river(x, z) > RiverSystem.get_water_half_width(z) + 6.0:
				spots.append(Vector3(x, _ground(x, z), z))
			z += 8.0
		x += 8.0
	spots.sort_custom(func(a, b): return a.y > b.y)
	var placed: Array[Vector3] = []
	for spot in spots:
		if placed.size() >= NEST_COUNT:
			break
		if placed.any(func(q): return Vector2(q.x, q.z).distance_to(Vector2(spot.x, spot.z)) < NEST_GAP):
			continue
		var nest := PlanadorNest.new()
		nest.name = "NinhoPlanador%d" % placed.size()
		nest.position = spot
		add_child(nest)
		placed.append(spot)

# ---------------------------------------------------------------- Elo e Companheira (GDD-16)

## Passa a fome dos dias de jogo que correram
func tick_bonds() -> void:
	var day := today()
	for b in bonds:
		b.tick_hunger(day)

## A Companheira atual (ou null)
func companion_mount() -> Mount:
	for m in _owned_nodes:
		if is_instance_valid(m) and m.bond and m.bond.companion:
			return m
	return null

## Só uma Companheira por personagem: a anterior volta a Arisca (ciúme). false se a faixa não deixa.
func set_companion(m: Mount) -> bool:
	if m == null or m.bond == null or not m.bond.can_be_companion():
		return false
	for b in bonds:
		if b != m.bond and b.companion:
			b.jealous()
	m.bond.companion = true
	return true

## Apito de Osso ([H], GDD-16 §5): a Companheira ouve dentro do alcance da faixa e vem pelo mundo.
## Caindo, é a pegada no ar (só a Companheira plena voadora; ver catch_check).
## Devolve o motivo: &"ok", &"sem_apito", &"montado", &"sem_companheira", &"longe", &"a_caminho",
## &"pegando" ou o motivo de catch_check
func whistle(player: Player) -> StringName:
	if player == null or player.inventory == null or player.inventory.get_material_count(&"apito_osso") <= 0:
		_tell(player, "Você precisa de um Apito de Osso (faça no [Tab]: 3 Restos Ósseos + 1 Fibra)")
		return &"sem_apito"
	if player.mounted_on != null:
		_tell(player, "🎶 Você já está montado")
		return &"montado"
	var m := companion_mount()
	if m == null or m.kind == Mount.Kind.WATER:
		_tell(player, "🎶 Nenhuma Companheira atende o apito (escolha uma no estábulo)")
		return &"sem_companheira"
	if player.is_skydiving or (not player.is_on_floor() and player.velocity.y < -3.0):
		var why := catch_check(m, player)
		if why == &"ok":
			m.catch_falling(player)
			_tell(player, "🪶 %s mergulhou atrás de você!" % m.display_name)
		return why
	if m.is_catching():
		return &"pegando"
	if m.is_coming():
		_tell(player, "🎶 %s já está a caminho" % m.display_name)
		return &"a_caminho"
	var dist := Vector2(m.global_position.x, m.global_position.z).distance_to(Vector2(player.global_position.x, player.global_position.z))
	if dist > m.bond.whistle_range():
		_tell(player, "🎶 %s está longe demais para ouvir (%d m; alcance %d m)" % [m.display_name, roundi(dist), roundi(m.bond.whistle_range())])
		return &"longe"
	m.call_to(player)
	_tell(player, "🎶 %s ouviu o apito e está vindo (%d m)" % [m.display_name, roundi(dist)])
	return &"ok"

## Pode pegar o dono em queda? Companheira plena (Elo 75), voadora, a até 60 m e com fôlego
func catch_check(m: Mount, player: Player) -> StringName:
	if m.is_catching():
		return &"pegando"
	if m.kind != Mount.Kind.AIR:
		_tell(player, "🎶 %s não voa: não te pega no ar" % m.display_name)
		return &"nao_voa"
	if m.bond.band() < MountBond.BAND_MIN.size() - 1:
		_tell(player, "🎶 Só a Companheira plena (Elo 75) te pega no ar")
		return &"elo_baixo"
	var dist := m.global_position.distance_to(player.global_position)
	if dist > Mount.CATCH_RANGE:
		_tell(player, "🎶 %s está longe demais para te pegar (%d m; máx. %d m)" % [m.display_name, roundi(dist), roundi(Mount.CATCH_RANGE)])
		return &"longe"
	if m.stamina < Mount.CATCH_STAMINA:
		_tell(player, "🎶 %s está cansada demais para mergulhar" % m.display_name)
		return &"cansada"
	return &"ok"

func _on_care_requested(m: Mount, player: Player) -> void:
	_care_mount = m
	_care_player = player
	tick_bonds()
	_care_dialog.ask(care_state(m, player))

## O que a tela de cuidado mostra e quais botões ficam ativos
func care_state(m: Mount, player: Player) -> Dictionary:
	var b := m.bond
	var food := _food_for(b, player)
	var near_stable := Vector2(m.global_position.x, m.global_position.z).distance_to(STABLE_POS) <= CARE_RADIUS
	var top := MountBond.BAND_MIN.size() - 1
	var next := "Elo máximo." if b.band() == top else "Próxima faixa: %s com Elo %d (%s)" % [
		MountBond.BAND_NAMES[b.band() + 1], roundi(MountBond.BAND_MIN[b.band() + 1]), MountBond.UNLOCKS[b.band() + 1]]
	var info: Array[String] = [m.dna.species_name(), "Índole %s" % String(b.temperament).capitalize(), "%s (Elo %d)" % [b.band_name(), floori(b.elo)]]
	if not b.accepts(false):
		info.append("só aceita você")
	if b.is_hungry(today()):
		info.append("⚠ com fome")
	var companion_text := "⭐  Já é a sua Companheira"
	if not b.companion:
		if not b.can_be_companion():
			companion_text = "⭐  Companheira só a partir de Mansa (Elo 25)"
		elif companion_mount():
			companion_text = "⭐  Tornar Companheira (a atual fica com ciúme)"
		else:
			companion_text = "⭐  Tornar Companheira"
	var feed_text := "🍎  Alimentar com %s" % MaterialData.of(food).display_name if food != &"" else "🍎  Alimentar (precisa de: %s)" % _diet_names(b)
	var order_text := ""
	if b.companion:
		order_text = "🧭  Ordem: Seguir (toque para Ficar)" if b.order == MountBond.Order.FOLLOW else "🧭  Ordem: Ficar (toque para Seguir)"
	return {
		"title": "🐾 " + m.display_name,
		"name": b.mount_name,
		"info": " · ".join(info),
		"elo": b.elo,
		"next": next,
		"feed": [feed_text, food != &""],
		"care": ["🪮  Escovar e tratar" + ("" if near_stable else " (só no estábulo)"), near_stable],
		"companion": [companion_text, not b.companion and b.can_be_companion()],
		"order": [order_text, b.companion],
	}

func _on_care_choice(choice: StringName, text: String) -> void:
	var m := _care_mount
	var player := _care_player
	if m == null or not is_instance_valid(m) or player == null:
		return
	var b := m.bond
	var reopen := true
	match choice:
		&"montar":
			reopen = false
			m.begin_mount(player)
		&"alimentar":
			var food := _food_for(b, player)
			if food != &"" and player.inventory.consume_material(food, 1):
				var gain := b.feed(food, today())
				_tell(player, "🍎 %s comeu %s%s" % [m.display_name, MaterialData.of(food).display_name, " · Elo +%d" % roundi(gain) if gain > 0.0 else " · já comeu hoje (sem Elo)"])
		&"cuidar":
			var gain := b.care(today())
			_tell(player, "🪮 Você escovou %s%s" % [m.display_name, " · Elo +%d" % roundi(gain) if gain > 0.0 else " · já foi cuidada hoje"])
		&"companheira":
			if set_companion(m):
				_tell(player, "⭐ %s agora é a sua Companheira" % m.display_name)
		&"ordem":
			b.order = MountBond.Order.STAY if b.order == MountBond.Order.FOLLOW else MountBond.Order.FOLLOW
			_tell(player, "🧭 %s: %s" % [m.display_name, "vou te seguir" if b.order == MountBond.Order.FOLLOW else "fico aqui"])
		&"batizar":
			if b.rename(text):
				m.set_bond(b)
				_tell(player, "✏️ Agora ela se chama %s" % m.display_name)
		_:
			reopen = false
	if reopen:
		_care_dialog.ask(care_state(m, player))
	else:
		_care_dialog.close()
		_care_mount = null
		_care_player = null

## Primeira comida da dieta da espécie que o jogador tem na mochila
func _food_for(b: MountBond, player: Player) -> StringName:
	if player == null or player.inventory == null:
		return &""
	for food in MountBond.DIET.get(b.species, []):
		if player.inventory.get_material_count(food) > 0:
			return food
	return &""

func _diet_names(b: MountBond) -> String:
	return ", ".join(MountBond.DIET.get(b.species, []).map(func(f): return MaterialData.of(f).display_name))

func _tell(player: Node, msg: String) -> void:
	if player and player.has_signal("posture_changed"):
		player.posture_changed.emit(msg)

# ---------------------------------------------------------------- estábulo e montarias

func _build_stable() -> void:
	var stable := Node3D.new()
	stable.name = "Estabulo"
	var base := Vector3(STABLE_POS.x, _ground(STABLE_POS.x, STABLE_POS.y), STABLE_POS.y)
	_stable_base = base
	stable.position = base
	add_child(stable)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.4, 0.27, 0.15)
	# Telheiro: 4 postes e cobertura de tábuas
	for x in [-3.0, 3.0]:
		for z in [-2.0, 2.0]:
			_box(stable, Vector3(0.18, 2.8, 0.18), Vector3(x, 1.4, z), wood)
	_box(stable, Vector3(6.8, 0.15, 4.8), Vector3(0, 2.85, 0), wood).rotation.x = 0.12
	_box(stable, Vector3(6.4, 0.12, 0.12), Vector3(0, 1.0, -2.0), wood)
	var sign_label := Label3D.new()
	sign_label.text = "🐎 Estábulo"
	sign_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign_label.font_size = 22
	sign_label.outline_size = 6
	sign_label.modulate = Color(1.0, 0.9, 0.6)
	sign_label.position = Vector3(0, 3.6, 0)
	sign_label.visibility_range_end = 28.0
	stable.add_child(sign_label)

	var trot := CreatureDNA.randomized(CreatureDNA.Species.TROTADOR, 101)
	trot.alleles["porte"] = ["T", "T"]
	trot.alleles["chifre"] = ["C", "c"]
	_add_mount(trot, Mount.Kind.LAND, "Trotador", base + Vector3(-1.5, 0, 0.3))
	var bird := CreatureDNA.randomized(CreatureDNA.Species.PLANADOR, 202)
	bird.alleles["porte"] = ["T", "T"]
	bird.alleles["chifre"] = ["C", "C"]
	_add_mount(bird, Mount.Kind.AIR, "Planador", base + Vector3(1.7, 0, 0.3))
	# Raia montável no rio, na altura da vila, encostada na margem do lado da vila (dá para montar
	# da beira ou nadando até ela)
	var raia := CreatureDNA.randomized(CreatureDNA.Species.RAIA, 303)
	raia.alleles["porte"] = ["T", "T"]
	var raia_spot := _river_spot(10.0)
	raia_spot.x -= RiverSystem.get_water_half_width(10.0) * 0.7
	_add_mount(raia, Mount.Kind.WATER, "Raia-do-Rio", raia_spot)

func _add_mount(d: CreatureDNA, kind: Mount.Kind, mount_name: String, pos: Vector3) -> Mount:
	var m := Mount.new()
	m.name = "Montaria_" + mount_name
	m.dna = d
	m.kind = kind
	m.display_name = mount_name
	m.position = pos
	m.rotation.y = PI * 0.5
	add_child(m)
	return m

# ---------------------------------------------------------------- lugares

## Ponto em terra firme a uma distância [min, max] da origem; Vector3.INF se não achar
func _land_spot(min_dist: float, max_dist: float) -> Vector3:
	for attempt in 12:
		var a := _rng.randf() * TAU
		var d := _rng.randf_range(min_dist, max_dist)
		var x := cos(a) * d
		var z := sin(a) * d
		if CityHub.in_village(x, z, 2.0) or Vector2(x, z).distance_to(ARENA_CENTER) < 11.0 or Vector2(x, z).distance_to(STABLE_POS) < 5.0:
			continue
		if RiverSystem.get_distance_to_river(x, z) < RiverSystem.get_water_half_width(z) + 2.0:
			continue
		if not WorldBounds.inside(x, z, 6.0):
			continue
		return Vector3(x, _ground(x, z), z)
	return Vector3.INF

func _river_spot(z: float) -> Vector3:
	return Vector3(RiverSystem.get_river_center_x(z), RiverSystem.get_water_height(z) - 0.3, z)

func _ground(x: float, z: float) -> float:
	return landscape.get_height_at(x, z) if landscape and landscape.has_method("get_height_at") else 0.0

func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = mat
	parent.add_child(mi)
	return mi
