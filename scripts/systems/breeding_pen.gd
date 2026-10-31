class_name BreedingPen
extends Node
const _LedgerSources = preload("res://scripts/net/ledger_sources.gd")

## Sistema de Criadouro, Rancho e Cercado de Reprodução (GDD-04 §2, GDD-08 §4-§5, GDD-09 §5).
## Gerencia 1 reprodutor (Macho/Sire) e 1 matriz (Fêmea/Dam) da mesma espécie, alimentação no cocho,
## gestação temporizada, cruzamento mendeliano com mutações e os 3 destinos do filhote:
## 1. Abate cuidadoso: 100% partes Íntegras (+1 qualidade) e traits cultivados.
## 2. Promover a montaria própria.
## 3. Manter no cercado como nova matriz/reprodutor para as próximas gerações.

const _CreatureDNA = preload("res://scripts/data/creature_dna.gd")
const _InventoryComponent = preload("res://scripts/components/inventory_component.gd")
const _MasteryComponent = preload("res://scripts/components/mastery_component.gd")
const _MaterialData = preload("res://scripts/data/material_data.gd")

signal sire_changed(dna: _CreatureDNA)
signal dam_changed(dna: _CreatureDNA)
signal breeding_started()
signal gestation_progress(progress_ratio: float, time_left: float)
signal offspring_born(dna: _CreatureDNA)
signal offspring_harvested(yields: Array[Dictionary])
signal feed_changed(current: float, max_val: float)
signal status_message(msg: String)

const FEED_VALUES: Dictionary = {
	&"folha": 15.0,
	&"erva": 20.0,
	&"frutinha": 25.0,
	&"carne_pequena": 30.0,
	&"carne_crua": 30.0,
	&"adubo_organico": 40.0
}

const DEFAULT_GESTATION_DURATION: float = 60.0
const FEED_BURN_RATE: float = 0.5 # unidades de alimento por segundo de gestação ativa
const MAX_FEED: float = 100.0

@export var pen_name: String = "Cercado de Reprodução"
@export var gestation_duration: float = DEFAULT_GESTATION_DURATION
@export var max_feed: float = MAX_FEED

var sire: _CreatureDNA = null
var dam: _CreatureDNA = null
var offspring: _CreatureDNA = null

var feed_level: float = 0.0
var gestation_time: float = 0.0
var is_pregnant: bool = false
var mutation_boost: bool = false
var generation: int = 1

func _ready() -> void:
	add_to_group("breeding_pens")

func _process(delta: float) -> void:
	if is_pregnant:
		advance_time(delta)

## Valida se o DNA pode ser alocado como Reprodutor (Macho)
func can_set_sire(dna: _CreatureDNA) -> bool:
	if dna == null or not dna.is_male() or not dna.is_fertile():
		return false
	if dna.species == _CreatureDNA.Species.RINOLITO:
		return false
	if dam != null and dna.species != dam.species:
		return false
	return true

## Aloca o Reprodutor Macho
func set_sire(dna: _CreatureDNA) -> bool:
	if not can_set_sire(dna):
		status_message.emit("❌ Macho incompatível ou infértil")
		return false
	if is_pregnant:
		status_message.emit("❌ Não é possível trocar o reprodutor durante a gestação")
		return false
	sire = dna
	sire_changed.emit(sire)
	status_message.emit("♂ Reprodutor definido: %s" % sire.species_name())
	return true

## Remove o Reprodutor Macho
func remove_sire() -> _CreatureDNA:
	if is_pregnant:
		status_message.emit("❌ Gestação em andamento; não remova os pais agora")
		return null
	var old := sire
	sire = null
	sire_changed.emit(null)
	return old

## Valida se o DNA pode ser alocado como Matriz (Fêmea)
func can_set_dam(dna: _CreatureDNA) -> bool:
	if dna == null or not dna.is_female() or not dna.is_fertile():
		return false
	if dna.species == _CreatureDNA.Species.RINOLITO:
		return false
	if sire != null and dna.species != sire.species:
		return false
	return true

## Aloca a Matriz Fêmea
func set_dam(dna: _CreatureDNA) -> bool:
	if not can_set_dam(dna):
		status_message.emit("❌ Fêmea incompatível ou infértil")
		return false
	if is_pregnant:
		status_message.emit("❌ Não é possível trocar a matriz durante a gestação")
		return false
	dam = dna
	dam_changed.emit(dam)
	status_message.emit("♀ Matriz definida: %s" % dam.species_name())
	return true

## Remove a Matriz Fêmea
func remove_dam() -> _CreatureDNA:
	if is_pregnant:
		status_message.emit("❌ Gestação em andamento; não remova os pais agora")
		return null
	var old := dam
	dam = null
	dam_changed.emit(null)
	return old

## Verifica se o cercado está apto para iniciar a gestação
func can_start_breeding() -> bool:
	if sire == null or dam == null:
		return false
	if sire.species != dam.species:
		return false
	if offspring != null:
		return false
	if is_pregnant:
		return false
	if feed_level <= 0.0:
		return false
	return true

## Inicia o ciclo de gestação
func start_breeding() -> bool:
	if not can_start_breeding():
		if feed_level <= 0.0:
			status_message.emit("❌ O cocho está vazio! Abasteça com alimento vegetal ou adubo")
		elif offspring != null:
			status_message.emit("❌ Já existe um filhote no cercado. Cuide do filhote primeiro")
		elif sire == null or dam == null:
			status_message.emit("❌ É necessário 1 Reprodutor (♂) e 1 Matriz (♀) da mesma espécie")
		return false
	is_pregnant = true
	gestation_time = 0.0
	breeding_started.emit()
	status_message.emit("❤️ Ciclo reprodutivo iniciado no cercado!")
	return true

## Alimenta o cocho a partir do inventário do jogador
func feed(player: Node, item_id: StringName = &"") -> bool:
	var inv: _InventoryComponent = _get_inventory(player)
	if inv == null:
		return false
	
	var chosen_item: StringName = item_id
	if chosen_item.is_empty():
		for k in FEED_VALUES.keys():
			if inv.has_materials({k: 1}):
				chosen_item = k
				break
	
	if chosen_item.is_empty() or not inv.has_materials({chosen_item: 1}):
		status_message.emit("❌ Sem alimento vegetal ou adubo adequado no inventário")
		return false
	
	inv.consume_materials({chosen_item: 1})
	var feed_gain: float = float(FEED_VALUES.get(chosen_item, 20.0))
	feed_level = minf(max_feed, feed_level + feed_gain)
	
	if chosen_item == &"adubo_organico":
		mutation_boost = true
		status_message.emit("🧪 Adubo de monstro mineralizado adicionado! (+40 comida, chance de mutação +10%%)")
	else:
		var d := _MaterialData.of(chosen_item)
		status_message.emit("🌾 Cocho abastecido com %s (+%.0f comida)" % [d.display_name, feed_gain])
	
	feed_changed.emit(feed_level, max_feed)
	return true

## Avança o tempo de gestação com base no alimento disponível
func advance_time(delta: float) -> void:
	if not is_pregnant:
		return
	
	if feed_level <= 0.0:
		# Paralisa o ciclo sem matar as matrizes (GDD-04 §2)
		return
	
	var consumed: float = delta * FEED_BURN_RATE
	feed_level = maxf(0.0, feed_level - consumed)
	gestation_time += delta
	
	var progress := clampf(gestation_time / gestation_duration, 0.0, 1.0)
	var time_left := maxf(0.0, gestation_duration - gestation_time)
	gestation_progress.emit(progress, time_left)
	
	if gestation_time >= gestation_duration:
		_finish_birth()

## Conclui a gestação instantaneamente (para testes ou término acelerado)
func finish_gestation() -> void:
	if not is_pregnant and can_start_breeding():
		start_breeding()
	if is_pregnant:
		gestation_time = gestation_duration
		_finish_birth()

func _finish_birth() -> void:
	is_pregnant = false
	gestation_time = 0.0
	var mut_chance: float = 0.10 if mutation_boost else 0.03
	offspring = _CreatureDNA.cross(sire, dam, randi(), mut_chance)
	offspring.stage = _CreatureDNA.LifeStage.BABY
	mutation_boost = false
	offspring_born.emit(offspring)
	status_message.emit("🎉 Nasceu um filhote de %s (Geração %d)!" % [offspring.species_name(), generation + 1])

## Calcula as probabilidades genéticas do cruzamento via quadro de Punnett
func punnett_square() -> Dictionary:
	if sire == null or dam == null:
		return {}
	var result: Dictionary = {
		"porte": {},
		"chifre": {"com_chifre": 0.0, "sem_chifre": 0.0},
		"padrao": {"listrado": 0.0, "liso": 0.0},
		"mutation_chance": 0.10 if mutation_boost else 0.03
	}
	
	# Porte (dominância incompleta: TT, Tt, tt)
	var s_porte: Array = sire.alleles.get("porte", ["T", "t"])
	var d_porte: Array = dam.alleles.get("porte", ["T", "t"])
	for s in s_porte:
		for d in d_porte:
			var combo := [s, d]
			combo.sort()
			var key := "%s%s" % [combo[0], combo[1]] # TT, Tt, tt
			result["porte"][key] = result["porte"].get(key, 0) + 0.25
	
	# Chifre (dominância completa: C dominante, cc recessivo)
	var s_horn: Array = sire.alleles.get("chifre", ["c", "c"])
	var d_horn: Array = dam.alleles.get("chifre", ["c", "c"])
	for s in s_horn:
		for d in d_horn:
			if s == "C" or d == "C" or s == "*" or d == "*":
				result["chifre"]["com_chifre"] += 0.25
			else:
				result["chifre"]["sem_chifre"] += 0.25
				
	# Padrão de pelagem (dominância completa: P dominante, pp recessivo)
	var s_pat: Array = sire.alleles.get("padrao", ["p", "p"])
	var d_pat: Array = dam.alleles.get("padrao", ["p", "p"])
	for s in s_pat:
		for d in d_pat:
			if s == "P" or d == "P" or s == "*" or d == "*":
				result["padrao"]["listrado"] += 0.25
			else:
				result["padrao"]["liso"] += 0.25
				
	return result

## 1. Abate Cuidadoso do Filhote (GDD-04 §2):
## 100% de partes Íntegras (+1 qualidade sobre o normal, qualidade 3★)
## Preserva e extrai traits biológicos cultivados
func harvest_offspring(player: Node) -> Array[Dictionary]:
	if offspring == null:
		status_message.emit("❌ Nenhum filhote no cercado para abate")
		return []
	EventBusAutoload.report(player, &"cria", {"species": offspring.species_name(), "generation": generation + 1})
	
	var inv: _InventoryComponent = _get_inventory(player)
	var traits: Array = [&"integro"]
	if offspring.is_mutant():
		traits.append(&"iridescente")
	if offspring.size_factor() >= 1.0:
		traits.append(&"denso")
	if offspring.mount_speed_factor() >= 1.0:
		traits.append(&"veloz")
	if offspring.has_horns():
		traits.append(&"chifre_macico")
	if offspring.is_striped():
		traits.append(&"camuflado")
	
	var items: Array = []
	match offspring.species:
		_CreatureDNA.Species.TROTADOR:
			if offspring.has_horns():
				items.append([&"chifre_galhado", 1])
			items.append([&"couro_trotador", 2])
			items.append([&"carne_crua", 2])
		_CreatureDNA.Species.PLANADOR:
			items.append([&"pena_penacho", 3])
			items.append([&"carne_crua", 1])
		_CreatureDNA.Species.SALTARELO:
			items.append([&"pele_saltarelo", 2])
			items.append([&"carne_crua", 1])
		_CreatureDNA.Species.LOBO:
			items.append([&"couro_trotador", 2])
			items.append([&"ossos", 2])
			items.append([&"carne_crua", 2])
		_CreatureDNA.Species.TATU:
			items.append([&"ossos", 3])
			items.append([&"carne_crua", 2])
		_:
			items.append([&"carne_crua", 2])
	
	var yields: Array[Dictionary] = []
	for it in items:
		var mat_id: StringName = it[0]
		var count: int = it[1]
		var q: int = 3 # Garantido 3★ pelo abate cuidadoso no rancho
		if inv:
			_LedgerSources.gain(&"breeding", name, func(): inv.add_material(mat_id, count, q, traits))
		var mat_info := _MaterialData.of(mat_id)
		yields.append({
			"id": mat_id,
			"amount": count,
			"quality": q,
			"traits": traits,
			"name": mat_info.display_name
		})
	
	var mastery := _get_mastery(player)
	if mastery:
		mastery.add_xp(&"esfola", 35.0)
	
	var old_offspring := offspring
	offspring = null
	offspring_harvested.emit(yields)
	status_message.emit("🔪 Abate cuidadoso de %s concluído! Partes 100%% Íntegras (+1★)" % old_offspring.species_name())
	return yields

## 2. Promover Filhote a Montaria Própria
func promote_offspring_to_mount(player: Node) -> bool:
	if offspring == null:
		status_message.emit("❌ Nenhum filhote para promover a montaria")
		return false
	
	offspring.stage = _CreatureDNA.LifeStage.ADULT
	var eco := get_tree().get_first_node_in_group("ecosystem") if is_inside_tree() else null
	var added := false
	if eco and eco.has_method("add_owned_mount"):
		added = eco.add_owned_mount(offspring)
	elif player and player.has_method("add_livestock"):
		added = player.add_livestock(offspring)
	else:
		added = true
	
	if added:
		EventBusAutoload.report(player, &"cria", {"species": offspring.species_name(), "generation": generation + 1})
		var name_str := offspring.species_name()
		offspring = null
		status_message.emit("🐎 %s promovido a montaria própria!" % name_str)
		return true
	else:
		status_message.emit("❌ Estábulo de montarias cheio ou espécie não montável")
		return false

## 3. Promover Filhote a Nova Matriz / Reprodutor do Cercado
func promote_offspring_to_breeder() -> bool:
	if offspring == null:
		status_message.emit("❌ Nenhum filhote no cercado para assumir como matriz")
		return false
	
	offspring.stage = _CreatureDNA.LifeStage.ADULT
	generation += 1
	if offspring.is_male():
		sire = offspring
		sire_changed.emit(sire)
		status_message.emit("👑 Filhote tornou-se o novo Reprodutor (♂) da Geração %d!" % generation)
	else:
		dam = offspring
		dam_changed.emit(dam)
		status_message.emit("👑 Filhote tornou-se a nova Matriz (♀) da Geração %d!" % generation)
	offspring = null
	return true

## Serialização para SaveGame
func to_dict() -> Dictionary:
	return {
		"name": pen_name,
		"generation": generation,
		"feed_level": feed_level,
		"gestation_time": gestation_time,
		"is_pregnant": is_pregnant,
		"mutation_boost": mutation_boost,
		"sire": sire.to_dict() if sire else null,
		"dam": dam.to_dict() if dam else null,
		"offspring": offspring.to_dict() if offspring else null,
	}

## Desserialização
func from_dict(d: Dictionary) -> void:
	pen_name = str(d.get("name", pen_name))
	generation = int(d.get("generation", 1))
	feed_level = float(d.get("feed_level", 0.0))
	gestation_time = float(d.get("gestation_time", 0.0))
	is_pregnant = bool(d.get("is_pregnant", false))
	mutation_boost = bool(d.get("mutation_boost", false))
	
	var s_data = d.get("sire")
	sire = _CreatureDNA.from_dict(s_data) if s_data is Dictionary else null
	
	var dam_data = d.get("dam")
	dam = _CreatureDNA.from_dict(dam_data) if dam_data is Dictionary else null
	
	var off_data = d.get("offspring")
	offspring = _CreatureDNA.from_dict(off_data) if off_data is Dictionary else null

func _get_inventory(target: Node) -> _InventoryComponent:
	if target == null:
		return null
	if target.get("inventory") is _InventoryComponent:
		return target.get("inventory") as _InventoryComponent
	var comp = target.get_node_or_null("InventoryComponent") as _InventoryComponent
	if comp:
		return comp
	for c in target.get_children():
		if c is _InventoryComponent:
			return c as _InventoryComponent
	return null

func _get_mastery(target: Node) -> _MasteryComponent:
	if target == null:
		return null
	if target.get("mastery") is _MasteryComponent:
		return target.get("mastery") as _MasteryComponent
	var comp = target.get_node_or_null("MasteryComponent") as _MasteryComponent
	if comp:
		return comp
	for c in target.get_children():
		if c is _MasteryComponent:
			return c as _MasteryComponent
	return null
