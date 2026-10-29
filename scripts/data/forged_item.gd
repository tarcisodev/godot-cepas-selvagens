class_name ForgedItem
extends Resource

## Peça de equipamento forjada (GDD-06 §6 e GDD-12): receita, encaixe, família (pano, couro, ferro,
## vinda do revestimento), qualidade (1–5★), traits herdados, durabilidade e os materiais que
## entraram (para o desmanche). Os efeitos saem da receita × qualidade × fator da família + traits.

## Encaixes do estilo Albion (GDD-12 §1). A ordem dos 3 primeiros é a dos saves antigos.
enum Slot { HEAD, BODY, FEET, MAIN_HAND, OFF_HAND, CAPE, BAG }

const SLOT_NAMES: Array[String] = ["Cabeça", "Peito", "Botas", "Arma primária", "Arma secundária", "Capa", "Mochila"]
const SLOT_KEYS: Array[StringName] = [&"head", &"body", &"feet", &"main_hand", &"off_hand", &"cape", &"bag"]
## Encaixes que dão habilidade de armadura (teclas 4 / 5 / R)
const ARMOR_SLOTS: Array[Slot] = [Slot.HEAD, Slot.BODY, Slot.FEET]
## Multiplicador dos efeitos por qualidade (GDD-06 §2)
const QUALITY_MULT: Array[float] = [1.0, 1.0, 1.1, 1.25, 1.4, 1.6]

## Fator da família (GDD-12 §2.1): Carga, mitigação (resistências e Postura) e um extra pequeno.
## A receita traz os números da família de origem; outra família muda pela razão entre os fatores.
const FAMILY: Dictionary = {
	&"pano": {"name": "Pano", "load": 0.5, "mitigation": 0.6, "extra": {&"ether_regen": 0.5}, "mastery": &"armadura_leve"},
	&"couro": {"name": "Couro", "load": 1.0, "mitigation": 1.0, "extra": {&"dodge_cost": -1.0}, "mastery": &"armadura_media"},
	&"ferro": {"name": "Ferro", "load": 1.6, "mitigation": 1.4, "extra": {&"poise_resist": 0.05}, "mastery": &"armadura_pesada"},
}
## Receitas que mudaram de nome (saves antigos)
const RENAMED: Dictionary = {&"bracadeiras_galhada": &"couraca_galhada"}

@export var recipe_id: StringName
@export var display_name: String = ""
@export var slot: Slot = Slot.HEAD
## &"pano", &"couro", &"ferro" (vazio nas armas)
@export var family: StringName = &""
@export var quality: int = 1
@export var traits: Array[StringName] = []
@export var durability: float = 100.0
@export var max_durability: float = 100.0
## Materiais usados {id: quantidade} — base do desmanche
@export var materials: Dictionary = {}
## História que a peça herdou do tempero (ex.: a Lembrança de uma montaria; GDD-16 §7)
@export var memory: Dictionary = {}

func is_broken() -> bool:
	return durability <= 0.0

func recipe() -> Dictionary:
	return Forge.RECIPES.get(recipe_id, {})

func is_weapon() -> bool:
	return slot == Slot.MAIN_HAND or slot == Slot.OFF_HAND

func is_two_handed() -> bool:
	return bool(recipe().get("two_hand", false))

func family_name() -> String:
	return FAMILY[family]["name"] if FAMILY.has(family) else ""

## Efeitos finais {stat: valor}: base da receita × qualidade × família + traits. Carga não escala
## com a qualidade, só com a família.
func effects() -> Dictionary:
	var r := recipe()
	var out := {}
	var mult: float = QUALITY_MULT[clampi(quality, 1, 5)]
	var base_family: StringName = r.get("family", family)
	var f_now: Dictionary = FAMILY.get(family, {})
	var f_base: Dictionary = FAMILY.get(base_family, f_now)
	var mitig: float = (float(f_now.mitigation) / float(f_base.mitigation)) if not f_now.is_empty() and not f_base.is_empty() else 1.0
	var load_f: float = (float(f_now.load) / float(f_base.load)) if not f_now.is_empty() and not f_base.is_empty() else 1.0
	var mods: Dictionary = r.get("mods", {})
	if r.has("by_family"):
		# Números já escritos por família (mochila): sem fator de mitigação
		mods = r.by_family.get(family, mods)
		mitig = 1.0
	for stat in mods:
		var v: float = mods[stat]
		# Bônus (resistência, regeneração, capacidade) crescem com a qualidade; reduções de custo também
		var is_mitigation: bool = String(stat).begins_with("resist_") or stat == &"poise_resist"
		out[stat] = v * mult * (mitig if is_mitigation else 1.0)
	out[&"load"] = float(r.get("load", 0.0)) * load_f * (0.9 if traits.has(&"leve") else 1.0)
	if not is_weapon() and slot in ARMOR_SLOTS:
		for stat in f_now.get("extra", {}):
			out[stat] = out.get(stat, 0.0) + f_now.extra[stat]
	for t in traits:
		var bonus: Dictionary = Forge.TRAIT_BONUS.get(t, {})
		for stat in bonus:
			out[stat] = out.get(stat, 0.0) + bonus[stat]
	return out

## Força da arma: qualidade × fator do núcleo usado (pedra no mangual bate menos que ferro)
func weapon_power() -> float:
	var power := 1.0
	for o in recipe().get("core", []):
		if materials.has(o.id):
			power = float(o.get("power", 1.0))
			break
	for t in traits:
		power *= float(Forge.WEAPON_TRAIT_POWER.get(t, 1.0))
	return QUALITY_MULT[clampi(quality, 1, 5)] * power

## Habilidade de armadura desta peça (GDD-12 §6.3): a da receita (parte de criatura) ou a da família
func ability_id() -> StringName:
	if not slot in ARMOR_SLOTS:
		return &""
	var r := recipe()
	if r.has("ability"):
		return r.ability
	return ArmorAbilities.for_slot(slot, family)

func trait_names() -> Array[String]:
	var out: Array[String] = []
	for t in traits:
		out.append(Forge.TRAIT_NAMES.get(t, String(t).capitalize()))
	return out

func to_dict() -> Dictionary:
	var mats := {}
	for id in materials:
		mats[String(id)] = materials[id]
	return {"recipe": String(recipe_id), "name": display_name, "slot": int(slot), "family": String(family), "quality": quality,
		"traits": traits.map(func(t): return String(t)), "durability": durability, "max": max_durability, "materials": mats,
		"memory": memory.duplicate(true)}

static func from_dict(d: Dictionary) -> ForgedItem:
	var it := ForgedItem.new()
	it.recipe_id = StringName(d.get("recipe", ""))
	it.display_name = str(d.get("name", ""))
	if RENAMED.has(it.recipe_id):
		it.recipe_id = RENAMED[it.recipe_id]
		it.display_name = str(Forge.RECIPES[it.recipe_id].name)
	it.slot = int(d.get("slot", 0)) as Slot
	var r: Dictionary = Forge.RECIPES.get(it.recipe_id, {})
	if r.has("slot"):
		it.slot = r.slot
	it.family = StringName(d.get("family", r.get("family", "")))
	it.quality = int(d.get("quality", 1))
	for t in d.get("traits", []):
		it.traits.append(StringName(t))
	it.durability = float(d.get("durability", 100.0))
	it.memory = d.get("memory", {}) if d.get("memory", {}) is Dictionary else {}
	it.max_durability = float(d.get("max", 100.0))
	for id in d.get("materials", {}):
		it.materials[StringName(id)] = int(d["materials"][id])
	return it
