class_name Forge
extends RefCounted

## Forja modular (GDD-06 §2–§4 e §6): receitas com Núcleo, Revestimento e Tempero (opcional,
## forja ≥ 10). Qualidade = média ponderada das ★ dos obrigatórios (núcleo pesa 2) + crítico;
## traits: slot 1 do núcleo, slot 2 do tempero. Reparo e desmanche gastam e devolvem material.

const TEMPER_LEVEL: int = 10
const CRIT_PER_LEVEL: float = 0.004
const PUBLIC_FORGE_CRIT: float = 0.10
const REPAIR_COST: int = 5
const REPAIR_MAX_LOSS: float = 0.04
const SALVAGE_FRACTION: float = 0.4

## Cada slot: lista de opções {id, n}; tempero dá um trait
const RECIPES: Dictionary = {
	&"elmo_chifre_de_pedra": {
		"name": "Elmo Chifre-de-Pedra", "slot": ForgedItem.Slot.HEAD, "class": "pesada", "icon": "⛑️",
		"core": [{"id": &"chifre_rinolito", "n": 1}],
		"coat": [{"id": &"placa_carapaca", "n": 2}],
		"temper": [{"id": &"fibra", "n": 1, "trait": &"leve"}],
		"mods": {&"resist_slash": 0.10, &"resist_impact": 0.12, &"poise_resist": 0.15},
		"load": 14.0,
	},
	&"gibao_andarilho": {
		"name": "Gibão do Andarilho", "slot": ForgedItem.Slot.BODY, "class": "leve", "icon": "🦺",
		"core": [{"id": &"couro_trotador", "n": 3}],
		"coat": [{"id": &"tendao_elastico", "n": 1}, {"id": &"fibra", "n": 4}],
		"temper": [{"id": &"erva", "n": 2, "trait": &"calma_fria"}],
		"mods": {&"resist_slash": 0.08, &"dodge_cost": -3.0},
		"load": 5.0,
	},
	&"capuz_penacho": {
		"name": "Capuz de Penacho", "slot": ForgedItem.Slot.HEAD, "class": "leve", "icon": "🧢",
		"core": [{"id": &"pena_penacho", "n": 3}],
		"coat": [{"id": &"pele_saltarelo", "n": 1}],
		"temper": [{"id": &"mel", "n": 1, "trait": &"doce_foco"}],
		"mods": {&"ether_regen": 1.5, &"dodge_cost": -1.0},
		"load": 2.0,
	},
	&"bracadeiras_galhada": {
		"name": "Braçadeiras de Galhada", "slot": ForgedItem.Slot.HANDS, "class": "média", "icon": "🧤",
		"core": [{"id": &"chifre_galhado", "n": 1}],
		"coat": [{"id": &"couro_trotador", "n": 1}],
		"temper": [{"id": &"ossos", "n": 2, "trait": &"ossudo"}],
		"mods": {&"resist_impact": 0.06, &"poise_resist": 0.06},
		"load": 4.0,
	},
}

const TRAIT_NAMES: Dictionary = {
	&"integro": "Íntegro", &"cicatrizado": "Cicatrizado", &"iridescente": "Iridescente",
	&"leve": "Leve (−10% peso)", &"calma_fria": "Calma Fria", &"doce_foco": "Doce Foco", &"ossudo": "Ossudo",
}
## Bônus de efeito por trait (somados depois da qualidade)
const TRAIT_BONUS: Dictionary = {
	&"cicatrizado": {&"poise_resist": 0.15},
	&"calma_fria": {&"vigor_regen": 2.0},
	&"doce_foco": {&"ether_regen": 1.0},
	&"ossudo": {&"resist_impact": 0.05},
}
## Traits do núcleo que passam para o item (slot 1)
const CORE_TRAITS: Array[StringName] = [&"cicatrizado", &"integro", &"iridescente"]

## Prévia sem gastar nada. `core`/`coat`/`temper` = pilhas do inventário ({} = vazio).
## Devolve {"ok", "reason", "quality", "traits", "crit"}.
static func preview(recipe_id: StringName, core: Dictionary, coat: Dictionary, temper: Dictionary, forge_level: int, public_forge: bool) -> Dictionary:
	var r: Dictionary = RECIPES.get(recipe_id, {})
	if r.is_empty():
		return {"ok": false, "reason": "Receita desconhecida"}
	var core_opt := _option(r.core, core)
	var coat_opt := _option(r.coat, coat)
	if core_opt.is_empty():
		return {"ok": false, "reason": "Falta o núcleo"}
	if coat_opt.is_empty():
		return {"ok": false, "reason": "Falta o revestimento"}
	var temper_opt := _option(r.temper, temper)
	if not temper.is_empty() and forge_level < TEMPER_LEVEL:
		return {"ok": false, "reason": "Tempero só com forja %d" % TEMPER_LEVEL}
	var q := roundi((core.quality * 2.0 + coat.quality) / 3.0)
	var traits: Array[StringName] = []
	for t in CORE_TRAITS:
		if core.traits.has(t):
			traits.append(t)
			break
	if not temper_opt.is_empty():
		traits.append(temper_opt.trait)
	var crit := forge_level * CRIT_PER_LEVEL + (PUBLIC_FORGE_CRIT if public_forge else 0.0)
	return {"ok": true, "reason": "", "quality": clampi(q, 1, 5), "traits": traits, "crit": clampf(crit, 0.0, 0.9)}

## Forja de verdade: gasta as pilhas escolhidas, rola o crítico e devolve o item (ou null)
static func forge(inv: InventoryComponent, recipe_id: StringName, core: Dictionary, coat: Dictionary, temper: Dictionary, forge_level: int, public_forge: bool, rng: RandomNumberGenerator) -> ForgedItem:
	var p := preview(recipe_id, core, coat, temper, forge_level, public_forge)
	if not p.ok:
		return null
	var r: Dictionary = RECIPES[recipe_id]
	var uses: Array = [[core, _option(r.core, core)], [coat, _option(r.coat, coat)]]
	if not temper.is_empty():
		uses.append([temper, _option(r.temper, temper)])
	for u in uses:
		if u[0].amount < u[1].n:
			return null
	var item := ForgedItem.new()
	item.recipe_id = recipe_id
	item.slot = r.slot
	item.quality = mini(5, p.quality + (1 if rng.randf() < p.crit else 0))
	item.traits.assign(p.traits)
	item.display_name = r.name + (" (Íntegro)" if item.traits.has(&"integro") else "")
	var dur := 100.0 * (1.15 if item.traits.has(&"integro") or item.traits.has(&"cicatrizado") else 1.0)
	item.max_durability = dur
	item.durability = dur
	for u in uses:
		item.materials[u[0].id] = item.materials.get(u[0].id, 0) + u[1].n
		inv.consume_stack(u[0], u[1].n)
	return item

## Reparo: 5 $S + 1 do revestimento; durabilidade cheia, mas o máximo cai 4%
static func repair(item: ForgedItem, inv: InventoryComponent, wallet: WalletComponent) -> String:
	if item.durability >= item.max_durability - 0.01:
		return "Já está inteiro"
	var coat_id := _coat_material(item)
	if inv.get_material_count(coat_id) < 1:
		return "Falta 1 %s" % MaterialData.of(coat_id).display_name
	if wallet == null or not wallet.spend(REPAIR_COST):
		return "Faltam %s" % WalletComponent.format(REPAIR_COST)
	inv.consume_materials({coat_id: 1})
	item.max_durability *= 1.0 - REPAIR_MAX_LOSS
	item.durability = item.max_durability
	return ""

## Desmanche: devolve 40% dos materiais com −1★
static func salvage(item: ForgedItem, inv: InventoryComponent) -> Dictionary:
	var back := {}
	var q := maxi(1, item.quality - 1)
	for id in item.materials:
		var n := int(floor(item.materials[id] * SALVAGE_FRACTION))
		if n > 0:
			inv.add_material(id, n, q)
			back[id] = n
	return back

## Opção do slot que a pilha atende ({} se nenhuma)
static func _option(options: Array, stack: Dictionary) -> Dictionary:
	if stack.is_empty():
		return {}
	for o in options:
		if o.id == stack.id:
			return o
	return {}

static func _coat_material(item: ForgedItem) -> StringName:
	for o in RECIPES[item.recipe_id].coat:
		if item.materials.has(o.id):
			return o.id
	return RECIPES[item.recipe_id].coat[0].id
