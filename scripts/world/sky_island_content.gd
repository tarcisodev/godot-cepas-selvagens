class_name SkyIslandContent
extends Node3D

## O que cresce e o que se acha numa ilha voadora (GDD-18 §3 e §9): flora de coleta, veios do
## minério da raridade, baú e, às vezes, um ninho de Planador, mais os enfeites do bioma.
## Nasce quando um jogador chega perto e some quando todos vão embora; o que já foi pego fica
## guardado no `SkyIslandField` pela chave ilha + época, e a ilha só se renova numa época nova.

const R := SkyIslandSchedule.Rarity
const G := GatherableResource.Type

const GRASS: PackedScene = preload("res://assets/models/nature/Grass_Common_Tall.gltf")
const WISPY: PackedScene = preload("res://assets/models/nature/Grass_Wispy_Tall.gltf")
const FERN: PackedScene = preload("res://assets/models/nature/Fern_1.gltf")
const MUSHROOM: PackedScene = preload("res://assets/models/nature/Mushroom_Common.gltf")
const TWISTED: PackedScene = preload("res://assets/models/nature/TwistedTree_2.gltf")
const ROCK: PackedScene = preload("res://assets/models/nature/Rock_Medium_2.gltf")
const PINE: PackedScene = preload("res://assets/models/nature/Pine_3.gltf")

## Por raridade: flora de coleta [tipo, quantos], veios [tipo, quantos], baú e enfeites [cena ou
## forma, quantos, escala]. O ninho vem da agenda (SkyIslandSchedule.NEST_COMMONS Ilhotas).
const RECIPES: Dictionary = {
	R.COMUM: {
		"flora": [[G.FIBRA, 3], [G.ERVA, 2], [G.PEDRA, 2], [G.GALHO, 2]],
		"veins": [],
		"chest": {},
		"decor": [[&"grass", 14, 1.0], [&"pine", 2, 0.6], [&"rock", 2, 0.8]],
	},
	R.INCOMUM: {
		"flora": [[G.ERVA, 3], [G.FOLHA, 3], [G.FIBRA, 2], [G.FRUTINHA, 1]],
		"veins": [[G.VEIO_QUARTZO, 1]],
		"chest": {"title": "Baú de Musgo", "money": 20, "material": &"quartzo_lume", "qty": 2, "quality": 2},
		"decor": [[&"fern", 16, 1.1], [&"mushroom", 6, 1.2], [&"pine", 3, 1.2]],
	},
	R.RARA: {
		"flora": [[G.FIBRA, 4], [G.PEDRA, 3]],
		"veins": [[G.VEIO_CRISTAL_VENTO, 3]],
		"chest": {"title": "Baú da Ventania", "money": 45, "material": &"cristal_vento", "qty": 2, "quality": 3},
		"decor": [[&"wispy", 16, 1.0], [&"twisted", 3, 0.8], [&"rock", 5, 1.2]],
	},
	R.LENDARIA: {
		"flora": [[G.ERVA, 3], [G.PEDRA, 3]],
		"veins": [[G.VEIO_FERRO_CELESTE, 3]],
		"chest": {"title": "Baú da Ruína", "money": 120, "material": &"ferro_celeste", "qty": 3, "quality": 3},
		"decor": [[&"pillar", 8, 1.0], [&"rock", 5, 1.3], [&"wispy", 8, 0.9]],
	},
	R.MITICA: {
		"flora": [[G.ERVA, 4], [G.FOLHA, 2], [G.FRUTINHA, 2]],
		"veins": [[G.VEIO_AMBAR_ESTELAR, 1]],
		"chest": {"title": "Relicário", "money": 300, "material": &"ambar_estelar", "qty": 1, "quality": 3},
		"decor": [[&"crystal", 18, 1.0], [&"wispy", 10, 0.9]],
	},
}
## Ilhotas do Arquipélago do Eclipse (GDD-18 §7.4): flora de cristal e pouso dos Planadores do Eclipse
const SATELLITE: Dictionary = {
	"flora": [[G.ERVA, 2], [G.FOLHA, 2]],
	"veins": [],
	"chest": {},
	"decor": [[&"crystal", 8, 0.9], [&"wispy", 4, 0.8]],
}
## Enquanto a Matriarca vive, o veio e o Relicário ficam selados
const SEAL_TEXT: String = "Selado pela Matriarca do Eclipse"

## Coisas de coleta ficam até esta fração do raio da borda, e longe uma da outra (m)
const SPREAD: float = 0.72
const SPACING: float = 2.6
## Enfeites da receita valem para uma ilha de DECOR_RADIUS m de raio; as maiores ganham mais,
## na proporção da área, até DECOR_MAX vezes
const DECOR_RADIUS: float = 12.0
const DECOR_MAX: float = 6.0
## Enfeites altos (árvore, pilar) ficam mais longe do resto, para não cobrir ninho nem baú
const TALL: Array[StringName] = [&"pine", &"twisted", &"pillar"]

## Ilha + época: o conteúdo de uma época nova é outro
var key: String
var island: SkyIsland
var veins: Array[GatherableResource] = []
var flora: Array[GatherableResource] = []
var chest: WildChest
var nest: PlanadorNest
## Chefe da ilha: a Sentinela de Pedra (lendária) ou a Matriarca do Eclipse (núcleo da mítica)
var guardian: BeastFighter
var _boss_dead: bool = false
var _spots: Array[Vector2] = []
var _rng := RandomNumberGenerator.new()

static func key_for(island_data: Dictionary) -> String:
	return "%s@%d" % [island_data.id, int(island_data.epoch)]

## Monta tudo de acordo com a raridade, aplicando o que já foi pego (`state`)
func setup(p_island: SkyIsland, state: Dictionary) -> void:
	island = p_island
	key = key_for(island.data)
	name = "Conteudo"
	_rng.seed = hash([int(island.data.shape_seed), int(island.data.epoch), "conteudo"])
	var satellite := island.is_link()
	var recipe: Dictionary = SATELLITE if satellite else RECIPES[island.rarity()]
	# Chefe, ninho e baú primeiro: precisam do miolo da ilha, que fica sem lugar depois da flora
	_boss_dead = bool(state.get("chefe", false))
	if has_boss():
		_spots.append(Vector2.ZERO)
		if not _boss_dead:
			_build_guardian()
	if island.data.get("nest", false):
		_build_nest()
		nest.eclipse = satellite
	elif has_boss() and island.rarity() == R.MITICA:
		# Ninho da Matriarca: o filhote dela só aparece depois que ela cai
		_build_nest()
		nest.eclipse = true
		nest.locked = not _boss_dead
		nest.eclipse_name = "Filhote da Matriarca"
	if not recipe.chest.is_empty():
		_build_chest(recipe.chest)
	for v in recipe.veins:
		for i in v[1]:
			var vein := _gatherable(v[0], false)
			if vein:
				veins.append(vein)
	for f in recipe.flora:
		for i in f[1]:
			var g := _gatherable(f[0], true)
			if g:
				flora.append(g)
	var area := clampf(pow(island.shape.radius / DECOR_RADIUS, 2.0), 1.0, DECOR_MAX)
	for d in recipe.decor:
		for i in roundi(d[1] * area):
			_decor(d[0], d[2])
	apply_state(state)
	_set_sealed(island.rarity() == R.MITICA and not _boss_dead)

## Lendária e núcleo da mítica têm chefe
func has_boss() -> bool:
	return island != null and not island.is_link() and island.rarity() >= R.LENDARIA

## O chefe desta época já caiu
func boss_dead() -> bool:
	return _boss_dead

## O que mudou desde que a ilha nasceu: batidas que faltam em cada veio, baú aberto, ninho vazio
func capture_state() -> Dictionary:
	var out := {}
	for i in veins.size():
		var v := veins[i]
		if is_instance_valid(v) and (v.is_collected or v.hits_left < v.max_hits):
			out["v%d" % i] = 0 if v.is_collected else v.hits_left
	if chest and is_instance_valid(chest) and chest.is_opened:
		out["bau"] = true
	if nest and is_instance_valid(nest) and nest.state == PlanadorNest.State.EMPTY:
		out["ninho"] = nest.regrow_day
	if _boss_dead:
		out["chefe"] = true
	return out

func apply_state(state: Dictionary) -> void:
	for i in veins.size():
		var k := "v%d" % i
		if not state.has(k):
			continue
		var left := int(state[k])
		if left <= 0:
			veins[i].hits_left = 0
			veins[i].is_collected = true
			veins[i]._set_visual_visible(false)
		else:
			veins[i].hits_left = left
	if chest and state.get("bau", false):
		chest.from_dict({"id": String(chest.chest_id), "opened": true, "money": chest.reward_money})
	if nest and state.has("ninho"):
		nest.state = PlanadorNest.State.EMPTY
		nest.regrow_day = int(state["ninho"])

## Ninho com prova em andamento ou chefe lutando: a ilha não pode sumir agora. O ninho do Eclipse
## esperando montaria não segura (o bicho só fica pousado nele).
func busy() -> bool:
	if guardian and is_instance_valid(guardian) and not guardian.state in [BeastFighter.State.IDLE, BeastFighter.State.DEAD]:
		return true
	if nest == null or not is_instance_valid(nest):
		return false
	if nest.eclipse:
		return nest.state == PlanadorNest.State.TRIAL
	return nest.state in [PlanadorNest.State.OFFERED, PlanadorNest.State.WAITING, PlanadorNest.State.TRIAL]

## Sentinela de Pedra na lendária, Matriarca do Eclipse no núcleo da mítica, no meio da ilha. A
## arena é a ilha: o chefe não passa da borda.
func _build_guardian() -> void:
	var cfg := BeastFighter.sentinela_da_ruina() if island.rarity() == R.LENDARIA else BeastFighter.matriarca_do_eclipse()
	cfg.arena_radius = island.shape.radius - 4.0
	guardian = BeastFighter.new()
	guardian.name = "Sentinela" if island.rarity() == R.LENDARIA else "Matriarca"
	guardian.config = cfg
	guardian.position = Vector3(0.0, island.shape.top_at(0.0, 0.0) + 0.3, 0.0)
	add_child(guardian)
	guardian.home = guardian.global_position
	guardian.defeated.connect(_on_guardian_defeated)

func _on_guardian_defeated() -> void:
	_boss_dead = true
	_set_sealed(false)
	if nest and island.rarity() == R.MITICA and not island.is_link():
		nest.unlock_eclipse()
	for p in get_tree().get_nodes_in_group("player"):
		if p.has_signal("posture_changed") and SkyIslandField.on_island(island, (p as Node3D).global_position):
			if island.rarity() == R.MITICA:
				p.posture_changed.emit("🌑 A Matriarca caiu: o Âmbar-Estelar e o Relicário estão livres, e o filhote dela espera no ninho")

## Veio de Âmbar-Estelar e Relicário selados enquanto a Matriarca vive
func _set_sealed(on: bool) -> void:
	var why := SEAL_TEXT if on else ""
	for v in veins:
		if is_instance_valid(v):
			v.sealed = why
	if chest and is_instance_valid(chest):
		chest.sealed = why

# ---------------------------------------------------------------- partes

## Lugar livre no topo (local), longe dos outros; Vector3.INF se não achar
func _spot(spread: float = SPREAD, spacing: float = SPACING) -> Vector3:
	var shape := island.shape
	for attempt in 30:
		var a := _rng.randf() * TAU
		var r := sqrt(_rng.randf()) * shape.edge_radius(a) * spread
		var p := Vector2(cos(a), sin(a)) * r
		if _spots.any(func(q): return q.distance_to(p) < spacing):
			continue
		_spots.append(p)
		return Vector3(p.x, shape.top_at(p.x, p.y), p.y)
	return Vector3.INF

func _gatherable(type: int, respawns: bool) -> GatherableResource:
	var at := _spot()
	if at == Vector3.INF:
		return null
	var g := GatherableResource.new()
	g.type = type
	# Veios da ilha não voltam sozinhos: a ilha se renova inteira na época seguinte
	g.respawn_enabled = respawns
	g.position = at
	g.rotation.y = _rng.randf() * TAU
	add_child(g)
	return g

func _build_chest(cfg: Dictionary) -> void:
	var at := _spot(0.4, 4.0)
	if at == Vector3.INF:
		return
	chest = WildChest.new()
	chest.snap_to_ground = false
	chest.chest_id = StringName("ilha_%s" % key)
	chest.chest_title = cfg.title
	chest.reward_money = cfg.money
	chest.reward_material = cfg.material
	chest.reward_material_qty = cfg.qty
	chest.reward_material_quality = cfg.quality
	chest.guaranteed_card_id = &""
	chest.position = at
	chest.rotation.y = _rng.randf() * TAU
	add_child(chest)

func _build_nest() -> void:
	var at := _spot(0.3, 5.0)
	if at == Vector3.INF:
		return
	nest = PlanadorNest.new()
	nest.name = "NinhoDaIlha"
	nest.nest_seed = _rng.randi()
	nest.position = at
	add_child(nest)

func _decor(kind: StringName, size: float) -> void:
	var at := _spot(0.9, 3.0 if kind in TALL else 1.2)
	if at == Vector3.INF:
		return
	var node: Node3D
	match kind:
		&"grass": node = GRASS.instantiate()
		&"wispy": node = WISPY.instantiate()
		&"fern": node = FERN.instantiate()
		&"mushroom": node = MUSHROOM.instantiate()
		&"twisted": node = TWISTED.instantiate()
		&"rock": node = ROCK.instantiate()
		&"pine": node = PINE.instantiate()
		&"pillar": node = _pillar()
		&"crystal": node = _crystal()
	if node == null:
		return
	node.position = at
	node.rotation.y = _rng.randf() * TAU
	node.scale = Vector3.ONE * size * _rng.randf_range(0.8, 1.25)
	# Árvore torta da Ventania: dobrada pelo vento, sempre para o mesmo lado
	if kind == &"twisted" or kind == &"wispy":
		node.rotation.z = 0.12
	add_child(node)

## Pilar de ruína: inteiro ou quebrado, com o capitel caído do lado
func _pillar() -> Node3D:
	var root := Node3D.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.62, 0.6, 0.55)
	mat.roughness = 1.0
	var h := _rng.randf_range(1.2, 4.5)
	var col := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.38
	cyl.bottom_radius = 0.45
	cyl.height = h
	cyl.radial_segments = 8
	col.mesh = cyl
	col.position.y = h * 0.5
	col.material_override = mat
	root.add_child(col)
	var cap := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.1, 0.35, 1.1)
	cap.mesh = box
	cap.material_override = mat
	if h > 3.0:
		cap.position.y = h + 0.17
	else:
		cap.position = Vector3(1.2, 0.17, 0.3)
		cap.rotation = Vector3(0.0, 0.5, 0.25)
	root.add_child(cap)
	return root

## Cristal que brota do chão da mítica
func _crystal() -> Node3D:
	var m := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(0.6, _rng.randf_range(1.2, 3.6), 0.6)
	m.mesh = prism
	var mat := StandardMaterial3D.new()
	var hue := _rng.randf_range(0.6, 0.8)
	mat.albedo_color = Color.from_hsv(hue, 0.55, 1.0, 0.85)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.05
	mat.emission_enabled = true
	mat.emission = Color.from_hsv(hue, 0.7, 1.0)
	mat.emission_energy_multiplier = 1.4
	m.material_override = mat
	m.position.y = prism.size.y * 0.5
	m.rotation = Vector3(_rng.randf_range(-0.3, 0.3), 0.0, _rng.randf_range(-0.3, 0.3))
	var root := Node3D.new()
	root.add_child(m)
	return root
