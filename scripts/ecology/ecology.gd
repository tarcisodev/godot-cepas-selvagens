class_name Ecology
extends Node3D

## Ciclo natural (GDD-10 §3–§5): grade de solo com Umidade e Nutrientes (células de CELL m),
## passo de vida das plantas (crescer, florir, frutificar, semear, morrer) e o nutriente que volta
## ao solo quando planta ou bicho morre. Roda devagar (a cada TICK s); o clima vem do WeatherSystem.

const CELL: float = 6.0
const TICK: float = 2.0
## Plantas por célula (árvores contam 3) e teto do vale inteiro
const CELL_CAPACITY: int = 3
const MAX_PLANTS: int = 420
## Mutação da semente: 3% base, até 12% em solo saturado de nutriente (GDD-10 §4)
const MUTATION_BASE: float = 0.03
const MUTATION_RICH: float = 0.12
## Pinheira-Lume (GDD-10 §9): teto no vale (cada adulta acende uma luz), raio do pólen,
## sementes na barriga dos bichos e o esterco onde elas saem
const MAX_PINHEIRAS: int = 36
const POLLEN_RADIUS: float = 30.0
const GUT_DAYS: float = 0.4
const DUNG_SEED_CHANCE: float = 0.7
const DUNG_NUTRIENT: float = 0.1
## Canteiro de Cultivo: solo regado e adubado
const GARDEN_SOIL: Dictionary = {"moisture": 0.7, "nutrients": 0.7}

@export var weather: WeatherSystem
@export var landscape: Node3D

var cells: int = 0
var moisture: PackedFloat32Array
var nutrients: PackedFloat32Array
var occupancy: PackedInt32Array
var _timer: float = 0.0
var _rng := RandomNumberGenerator.new()
var _sun: Node

func _ready() -> void:
	add_to_group("ecology")
	if weather == null:
		weather = get_parent().get_node_or_null("WeatherSystem") as WeatherSystem
	if landscape == null:
		landscape = get_parent().get_node_or_null("Landscape")
	_sun = get_parent().get_node_or_null("Sun")
	_rng.seed = 4242
	_init_grid()

func _init_grid() -> void:
	cells = int(ceil(WorldBounds.HALF * 2.0 / CELL))
	moisture.resize(cells * cells)
	nutrients.resize(cells * cells)
	occupancy.resize(cells * cells)
	var noise := FastNoiseLite.new()
	noise.seed = 77
	noise.frequency = 0.02
	for iz in cells:
		for ix in cells:
			var x := -WorldBounds.HALF + (ix + 0.5) * CELL
			var z := -WorldBounds.HALF + (iz + 0.5) * CELL
			var i := iz * cells + ix
			moisture[i] = clampf(0.45 + _river_bonus(x, z) + noise.get_noise_2d(x, z) * 0.15, 0.0, 1.0)
			nutrients[i] = clampf(0.45 + noise.get_noise_2d(x + 500.0, z) * 0.25, 0.05, 1.0)

## Solo para o save: umidade e nutriente de cada célula, compactados
func get_state() -> Dictionary:
	return {
		"cells": cells,
		"moisture": Marshalls.raw_to_base64(moisture.to_byte_array()),
		"nutrients": Marshalls.raw_to_base64(nutrients.to_byte_array()),
	}

func apply_state(d: Dictionary) -> void:
	if int(d.get("cells", 0)) != cells:
		return  # grade de outro tamanho de mapa: fica a do mundo novo
	var m := Marshalls.base64_to_raw(str(d.get("moisture", ""))).to_float32_array()
	var n := Marshalls.base64_to_raw(str(d.get("nutrients", ""))).to_float32_array()
	if m.size() == moisture.size():
		moisture = m
	if n.size() == nutrients.size():
		nutrients = n

## Índice da célula de solo em (x, z); -1 fora do mapa
func cell_index(x: float, z: float) -> int:
	var ix := int(floor((x + WorldBounds.HALF) / CELL))
	var iz := int(floor((z + WorldBounds.HALF) / CELL))
	if ix < 0 or iz < 0 or ix >= cells or iz >= cells:
		return -1
	return iz * cells + ix

func cell_at(pos: Vector3) -> Dictionary:
	var i := cell_index(pos.x, pos.z)
	if i < 0:
		return {"moisture": 0.0, "nutrients": 0.0}
	return {"moisture": moisture[i], "nutrients": nutrients[i]}

## Devolve nutriente ao solo (planta ou bicho que morreu e apodreceu ali)
func deposit(pos: Vector3, amount: float) -> void:
	var i := cell_index(pos.x, pos.z)
	if i >= 0:
		nutrients[i] = clampf(nutrients[i] + amount, 0.0, 1.0)

func is_day() -> bool:
	var h: float = _sun.get("current_time_hours") if _sun else 12.0
	return h >= 6.0 and h <= 18.0

func _process(delta: float) -> void:
	_update_lume()
	_timer -= delta
	if _timer <= 0.0:
		_timer = TICK
		step(TICK / _day_length())

func day_length() -> float:
	return _day_length()

## 0 de dia, 1 de noite; céu fechado também acende um pouco (a Pinheira-Lume brilha no escuro)
func night_factor() -> float:
	var h: float = _sun.get("current_time_hours") if _sun else 12.0
	var night := 1.0 - minf(smoothstep(5.0, 6.5, h), 1.0 - smoothstep(17.5, 19.0, h))
	var clouds: float = weather.clouds if weather else 0.0
	return clampf(maxf(night, clouds * 0.5), 0.0, 1.0)

func _update_lume() -> void:
	var night := night_factor()
	PinhaShape.set_night(night)
	for n in get_tree().get_nodes_in_group("lume_lights"):
		var light := n as OmniLight3D
		if light:
			light.light_energy = night * float(light.get_meta("strength", 1.0)) * 1.6
			light.visible = night > 0.05

func _day_length() -> float:
	return DayNightCycle.seconds_per_day()

## Um passo do ecossistema (`days` = dias de jogo desde o último). Público para os testes.
func step(days: float) -> void:
	var heat: float = weather.heat if weather else 0.5
	var rain: float = weather.rain if weather else 0.0
	for i in moisture.size():
		var m := moisture[i] + rain * days * 6.0 - heat * days * 0.45
		moisture[i] = clampf(m, 0.0, 1.0)
		nutrients[i] = clampf(nutrients[i] + days * 0.02, 0.0, 1.0) # intemperismo lento
	_river_moisture()
	_step_plants(days)
	_rot(days)

## Esterco e fruta caída somem depois de um dia de jogo, contado no mesmo relógio da natureza
## (se a duração do dia mudar, eles acompanham). A fruta que apodrece vira nutriente.
func _rot(days: float) -> void:
	for group in [&"dung", &"fallen_fruit"]:
		for n in get_tree().get_nodes_in_group(group):
			var node := n as Node3D
			if node == null or node.is_queued_for_deletion() or not node.has_meta("rot_days"):
				continue
			var left: float = node.get_meta("rot_days") - days
			node.set_meta("rot_days", left)
			if left > 0.0:
				continue
			if group == &"fallen_fruit":
				deposit(node.global_position, 0.05)
			node.queue_free()

## Perto do rio (e na várzea alagada) o solo nunca seca
func _river_moisture() -> void:
	var flood_w := 2.2 if RiverSystem.flood > 0.5 else 1.6
	for iz in cells:
		var z := -WorldBounds.HALF + (iz + 0.5) * CELL
		var cx := RiverSystem.get_river_center_x(z)
		var hw := RiverSystem.get_water_half_width(z)
		for ix in cells:
			var x := -WorldBounds.HALF + (ix + 0.5) * CELL
			if absf(x - cx) < hw * flood_w + CELL:
				var i := iz * cells + ix
				moisture[i] = maxf(moisture[i], 0.75)

func _river_bonus(x: float, z: float) -> float:
	var d := RiverSystem.get_distance_to_river(x, z) - RiverSystem.get_water_half_width(z)
	return clampf(1.0 - d / 25.0, 0.0, 1.0) * 0.35

# ---------------------------------------------------------------- plantas

func _step_plants(days: float) -> void:
	var light := is_day()
	# Lua cheia: o luar deixa as plantas crescerem também de noite, devagar (GDD-10 §2.1)
	if not light and _sun and _sun.has_method("moon_illumination") and _sun.moon_illumination() > 0.6:
		light = true
		days *= 0.3
	_count_plants()
	var plants := get_tree().get_nodes_in_group("plants")
	for n in plants:
		var p := n as PlantBody
		if p == null or not is_instance_valid(p) or p.is_queued_for_deletion():
			continue
		var i := cell_index(p.global_position.x, p.global_position.z)
		if i < 0:
			continue
		# No canteiro o solo é cuidado pelo dono: fixo e sem esgotar a célula
		var r := p.life_tick(days, GARDEN_SOIL if p.garden else {"moisture": moisture[i], "nutrients": nutrients[i]}, light)
		if not p.garden:
			moisture[i] = maxf(0.0, moisture[i] - r.water)
			nutrients[i] = maxf(0.0, nutrients[i] - r.food)
		match r.event:
			"seeds":
				_reproduce(p, plants.size())
			"died":
				deposit(p.global_position, 0.3 if p.dna.is_tree() else 0.1)
				p.remove_from_group("plants")
				p.queue_free()

var _pinheira_count: int = 0

## Lotação das células (árvores contam 3; canteiro não conta) e quantas Pinheiras há
func _count_plants() -> void:
	occupancy.fill(0)
	_pinheira_count = 0
	for n in get_tree().get_nodes_in_group("plants"):
		var p := n as PlantBody
		if p == null or p.is_queued_for_deletion():
			continue
		if p.dna.kind == PlantDNA.Kind.PINHEIRA:
			_pinheira_count += 1
		var i := cell_index(p.global_position.x, p.global_position.z)
		if i >= 0 and not p.garden:
			occupancy[i] += 3 if p.dna.is_tree() else 1

func _reproduce(p: PlantBody, total: int) -> void:
	# Pinheira: a semente vai dentro das pinhas que caem (GDD-10 §9)
	if p.dna.kind == PlantDNA.Kind.PINHEIRA:
		drop_pinhas(p, _rng.randi_range(2, 4))
		return
	# Árvore e arbusto: o fruto cai e vira frutinha coletável no chão
	if p.dna.kind == PlantDNA.Kind.ARVORE or p.dna.kind == PlantDNA.Kind.ARBUSTO:
		for k in _rng.randi_range(1, 2):
			_drop_fruit(p.global_position + Vector3(_rng.randf_range(-2.0, 2.0), 0, _rng.randf_range(-2.0, 2.0)))
	if total >= MAX_PLANTS:
		return
	var radius := 7.0 if p.dna.kind == PlantDNA.Kind.ARVORE else 3.5
	var seeds := 1 if p.dna.kind == PlantDNA.Kind.ARVORE else 2
	for k in seeds:
		var a := _rng.randf() * TAU
		var spot := p.global_position + Vector3(cos(a), 0, sin(a)) * _rng.randf_range(1.5, radius)
		sow(p.dna, spot)

## Planta uma semente em `spot` se der: terra firme, fora da vila, célula com lugar.
## A chance de mutação sobe com o nutriente do lugar onde ela cai.
## `is_seed`: `parent` já é o genoma da semente (pinhão) — só sorteia a mutação do lugar.
func sow(parent: PlantDNA, spot: Vector3, is_seed: bool = false) -> PlantBody:
	var r = _plant(parent, spot, is_seed)
	return r if r is PlantBody else null

## Planta e devolve a PlantBody, ou o motivo da recusa (String)
func _plant(parent: PlantDNA, spot: Vector3, is_seed: bool, garden: bool = false, by: String = ""):
	var i := cell_index(spot.x, spot.z)
	if i < 0 or not WorldBounds.inside(spot.x, spot.z, 4.0):
		return "Fora do vale"
	if CityHub.in_village(spot.x, spot.z, 1.0) and not garden:
		return "Na vila, só num Canteiro de Cultivo"
	if parent.kind == PlantDNA.Kind.PINHEIRA and _pinheira_count >= MAX_PINHEIRAS:
		return "O vale já tem Pinheiras demais"
	var weight := 3 if parent.is_tree() else 1
	if not garden and occupancy[i] + weight > CELL_CAPACITY + (0 if parent.is_tree() else 1):
		return "Sem espaço: outra planta já ocupa este chão"
	if not garden:
		spot.y = _ground(spot.x, spot.z)
	if RiverSystem.is_in_water(spot):
		return "Não brota dentro d'água"
	if not garden:
		occupancy[i] += weight
	if parent.kind == PlantDNA.Kind.PINHEIRA:
		_pinheira_count += 1
	var soil: float = GARDEN_SOIL.nutrients if garden else nutrients[i]
	var rich := clampf((soil - 0.6) / 0.4, 0.0, 1.0)
	var chance := lerpf(MUTATION_BASE, MUTATION_RICH, rich)
	var child := PlantBody.new()
	child.dna = PlantDNA.sprout(parent, _rng.randi(), chance) if is_seed else PlantDNA.seed_of(parent, _rng.randi(), chance)
	child.garden = garden
	child.planted_by = by
	child.stage = PlantBody.Stage.SEMENTE
	child.position = spot
	child.rotation.y = _rng.randf() * TAU
	add_child(child)
	return child

# ---------------------------------------------------------------- Pinheira-Lume (GDD-10 §9)

## Jogador planta um pinhão. Num canteiro (`garden`) o solo é fixo e a lotação não conta.
## Devolve a PlantBody ou o motivo da recusa (String).
func plant_seed(seed_dna: PlantDNA, spot: Vector3, garden: bool, by: String = ""):
	if garden:
		for n in get_tree().get_nodes_in_group("plants"):
			var p := n as PlantBody
			if p and p.garden and Vector2(p.global_position.x - spot.x, p.global_position.z - spot.z).length() < 0.6:
				return "Este canteiro já tem uma planta"
	return _plant(seed_dna, spot, true, garden, by)

## Roda rápida [G] com Pinhão-Lume: planta 1,5 m à frente do jogador. Usa a pilha escolhida
## na tela de inventário (meta `seed_traits`), senão a primeira. Devolve a mensagem para o HUD.
func plant_by_player(player: Node3D, material_id: StringName = &"pinhao_lume") -> String:
	var inv: InventoryComponent = player.get("inventory")
	if inv == null:
		return ""
	var stacks := inv.get_stacks(material_id)
	if stacks.is_empty():
		return "Nenhum Pinhão-Lume na mochila"
	var stack: Dictionary = stacks[0]
	var wanted: Array = player.get_meta("seed_traits", [])
	for s in stacks:
		if s.traits == wanted:
			stack = s
	var code := ""
	for t in stack.traits:
		if String(t).begins_with("gen_"):
			code = String(t)
	if code.is_empty():
		return "Pinhão sem genoma"
	var visual: Node3D = player.get("visual_mesh")
	var yaw: float = visual.global_rotation.y if visual else player.global_rotation.y
	var spot := player.global_position + Vector3(-sin(yaw), 0, -cos(yaw)) * 1.5
	var bed := _garden_bed_at(spot)
	if bed:
		spot = Vector3(bed.global_position.x, bed.global_position.y + 0.35, bed.global_position.z)
	_count_plants()
	var r = plant_seed(PlantDNA.from_genome_code(code), spot, bed != null, String(player.name))
	if r is String:
		return r
	inv.consume_stack(stack, 1)
	var mst: MasteryComponent = player.get("mastery")
	if mst:
		mst.add_xp(&"coleta", 5.0)
	return "Pinhão-Lume plantado — o broto aparece em 2 dias"

## Canteiro de Cultivo a menos de 1 m de `spot`
func _garden_bed_at(spot: Vector3) -> Node3D:
	for n in get_tree().get_nodes_in_group("built_structures"):
		var piece := n as Node3D
		if piece and piece.get("piece_type") == BuildablePiece.PieceType.CANTEIRO \
				and Vector2(piece.global_position.x - spot.x, piece.global_position.z - spot.z).length() < 1.0:
			return piece
	return null

## A safra cai: cada pinha é um cruzamento com o pólen da vizinha mais perto
func drop_pinhas(p: PlantBody, count: int) -> void:
	var father := pollen_father(p)
	for k in count:
		var a := _rng.randf() * TAU
		var pos := p.global_position + Vector3(cos(a), 0, sin(a)) * _rng.randf_range(2.0, 6.0)
		spawn_pinha(PlantDNA.cross(p.dna, father, _rng.randi()), pos)

## Pinheira adulta mais perto (pólen pelo vento, até POLLEN_RADIUS); sem nenhuma, ela mesma
func pollen_father(p: PlantBody) -> PlantDNA:
	var best: PlantBody = null
	var best_d := POLLEN_RADIUS
	for n in get_tree().get_nodes_in_group("pinheiras"):
		var o := n as PlantBody
		if o and o != p and o.stage >= PlantBody.Stage.ADULTA and not o.is_queued_for_deletion():
			var d := o.global_position.distance_to(p.global_position)
			if d < best_d:
				best = o
				best_d = d
	return best.dna if best else p.dna

func spawn_pinha(seed_dna: PlantDNA, pos: Vector3, age_days: float = 0.0) -> PinhaFruit:
	var pinha := PinhaFruit.new()
	pinha.dna = seed_dna
	pinha.age_days = age_days
	pinha.position = Vector3(pos.x, _ground(pos.x, pos.z), pos.z)
	if RiverSystem.is_in_water(pinha.position):
		pinha.free()
		return null
	add_child(pinha)
	return pinha

## O bicho solta a semente que comeu: esterco (aduba a célula) e, quase sempre, a semente brota ali
func drop_dung(pos: Vector3, seed_dna: PlantDNA) -> void:
	pos.y = _ground(pos.x, pos.z)
	if RiverSystem.is_in_water(pos):
		return
	deposit(pos, DUNG_NUTRIENT)
	var dung := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.12
	sm.height = 0.12
	sm.radial_segments = 6
	sm.rings = 3
	dung.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.25, 0.17, 0.1)
	mat.roughness = 1.0
	dung.material_override = mat
	dung.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dung.position = pos + Vector3(0, 0.03, 0)
	dung.add_to_group("dung")
	dung.set_meta("rot_days", 1.0)
	add_child(dung)
	if seed_dna and _rng.randf() < DUNG_SEED_CHANCE:
		sow(seed_dna, pos, true)

func _drop_fruit(pos: Vector3) -> void:
	var fruit := GatherableResource.new()
	fruit.type = GatherableResource.Type.FRUTINHA
	fruit.respawn_enabled = false
	fruit.position = Vector3(pos.x, _ground(pos.x, pos.z), pos.z)
	fruit.add_to_group("fallen_fruit")
	# Fruto que ninguém pega apodrece em um dia e vira nutriente (pode ter sido comido antes)
	fruit.set_meta("rot_days", 1.0)
	add_child(fruit)

func _ground(x: float, z: float) -> float:
	return landscape.get_height_at(x, z) if landscape and landscape.has_method("get_height_at") else 0.0
