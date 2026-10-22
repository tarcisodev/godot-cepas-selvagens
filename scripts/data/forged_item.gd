class_name ForgedItem
extends Resource

## Peça de equipamento forjada (GDD-06 §6): receita, encaixe, qualidade (1–5★), traits herdados,
## durabilidade e os materiais que entraram (para o desmanche). Os efeitos saem da receita
## multiplicados pela qualidade, mais os bônus dos traits.

enum Slot { HEAD, BODY, HANDS }

const SLOT_NAMES: Array[String] = ["Cabeça", "Peito", "Mãos"]
const SLOT_KEYS: Array[StringName] = [&"head", &"body", &"hands"]
## Multiplicador dos efeitos por qualidade (GDD-06 §2)
const QUALITY_MULT: Array[float] = [1.0, 1.0, 1.1, 1.25, 1.4, 1.6]

@export var recipe_id: StringName
@export var display_name: String = ""
@export var slot: Slot = Slot.HEAD
@export var quality: int = 1
@export var traits: Array[StringName] = []
@export var durability: float = 100.0
@export var max_durability: float = 100.0
## Materiais usados {id: quantidade} — base do desmanche
@export var materials: Dictionary = {}

func is_broken() -> bool:
	return durability <= 0.0

func recipe() -> Dictionary:
	return Forge.RECIPES.get(recipe_id, {})

## Efeitos finais {stat: valor}: base da receita × qualidade + traits. Carga não escala.
func effects() -> Dictionary:
	var r := recipe()
	var out := {}
	var mult: float = QUALITY_MULT[clampi(quality, 1, 5)]
	for stat in r.get("mods", {}):
		var v: float = r.mods[stat]
		# Bônus (resistência, regeneração) crescem com a qualidade; reduções de custo também
		out[stat] = v * mult
	out[&"load"] = float(r.get("load", 0.0)) * (0.9 if traits.has(&"leve") else 1.0)
	for t in traits:
		var bonus: Dictionary = Forge.TRAIT_BONUS.get(t, {})
		for stat in bonus:
			out[stat] = out.get(stat, 0.0) + bonus[stat]
	return out

func trait_names() -> Array[String]:
	var out: Array[String] = []
	for t in traits:
		out.append(Forge.TRAIT_NAMES.get(t, String(t).capitalize()))
	return out

func to_dict() -> Dictionary:
	var mats := {}
	for id in materials:
		mats[String(id)] = materials[id]
	return {"recipe": String(recipe_id), "name": display_name, "slot": int(slot), "quality": quality,
		"traits": traits.map(func(t): return String(t)), "durability": durability, "max": max_durability, "materials": mats}

static func from_dict(d: Dictionary) -> ForgedItem:
	var it := ForgedItem.new()
	it.recipe_id = StringName(d.get("recipe", ""))
	it.display_name = str(d.get("name", ""))
	it.slot = int(d.get("slot", 0)) as Slot
	it.quality = int(d.get("quality", 1))
	for t in d.get("traits", []):
		it.traits.append(StringName(t))
	it.durability = float(d.get("durability", 100.0))
	it.max_durability = float(d.get("max", 100.0))
	for id in d.get("materials", {}):
		it.materials[StringName(id)] = int(d["materials"][id])
	return it
