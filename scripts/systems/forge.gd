class_name Forge
extends RefCounted

## Forja modular (GDD-06 §2–§4 e §6, GDD-12): receitas com Núcleo, Revestimento e Tempero (opcional,
## forja ≥ 10). Qualidade = média ponderada das ★ dos obrigatórios (núcleo pesa 2) + crítico;
## traits: slot 1 do núcleo, slot 2 do tempero; família: a do revestimento escolhido.
## Reparo, desmanche e fundição gastam e devolvem material.

const TEMPER_LEVEL: int = 10
const CRIT_PER_LEVEL: float = 0.004
const PUBLIC_FORGE_CRIT: float = 0.10
const REPAIR_COST: int = 5
const REPAIR_MAX_LOSS: float = 0.04
const SALVAGE_FRACTION: float = 0.4

## Cada slot: lista de opções {id, n}. No revestimento, `family` decide a família da peça
## (GDD-12 §2); no núcleo das armas, `power` multiplica o dano. Tempero dá um trait.
## `family` da receita = família de origem dos números de `mods`.
const RECIPES: Dictionary = {
	# --- Cabeça
	&"elmo_chifre_de_pedra": {
		"name": "Elmo Chifre-de-Pedra", "slot": ForgedItem.Slot.HEAD, "family": &"ferro", "icon": "⛑️",
		"core": [{"id": &"chifre_rinolito", "n": 1}],
		"coat": [{"id": &"placa_carapaca", "n": 2, "family": &"ferro"}, {"id": &"barra_ferro", "n": 2, "family": &"ferro"}, {"id": &"couro_trotador", "n": 2, "family": &"couro"}],
		"temper": [{"id": &"fibra", "n": 1, "trait": &"leve"}, {"id": &"lembranca", "n": 1, "trait": &"saudade"}],
		"mods": {&"resist_slash": 0.10, &"resist_impact": 0.12, &"poise_resist": 0.15},
		"load": 14.0,
		# Parte de criatura no núcleo: o chifre de Rinolito dá a Investida no lugar do Brado
		"ability": &"investida",
	},
	&"capuz_penacho": {
		"name": "Capuz de Penacho", "slot": ForgedItem.Slot.HEAD, "family": &"pano", "icon": "🧢",
		"core": [{"id": &"pena_penacho", "n": 3}],
		"coat": [{"id": &"fibra", "n": 4, "family": &"pano"}, {"id": &"pele_saltarelo", "n": 1, "family": &"couro"}],
		"temper": [{"id": &"mel", "n": 1, "trait": &"doce_foco"}, {"id": &"lembranca", "n": 1, "trait": &"saudade"}],
		"mods": {&"ether_regen": 1.5, &"dodge_cost": -1.0},
		"load": 2.0,
	},
	# --- Peito
	&"gibao_andarilho": {
		"name": "Gibão do Andarilho", "slot": ForgedItem.Slot.BODY, "family": &"couro", "icon": "🦺",
		"core": [{"id": &"couro_trotador", "n": 3}, {"id": &"couro_lobo", "n": 3, "durability": 1.1}],
		"coat": [{"id": &"tendao_elastico", "n": 1, "family": &"couro"}, {"id": &"fibra", "n": 4, "family": &"pano"}],
		"temper": [{"id": &"erva", "n": 2, "trait": &"calma_fria"}, {"id": &"lembranca", "n": 1, "trait": &"saudade"}],
		"mods": {&"resist_slash": 0.08, &"dodge_cost": -3.0},
		"load": 5.0,
	},
	&"couraca_galhada": {
		"name": "Couraça de Galhada", "slot": ForgedItem.Slot.BODY, "family": &"couro", "icon": "🧥",
		"core": [{"id": &"chifre_galhado", "n": 1}],
		"coat": [{"id": &"couro_trotador", "n": 1, "family": &"couro"}, {"id": &"barra_ferro", "n": 2, "family": &"ferro"}],
		"temper": [{"id": &"ossos", "n": 2, "trait": &"ossudo"}, {"id": &"lembranca", "n": 1, "trait": &"saudade"}],
		"mods": {&"resist_impact": 0.10, &"poise_resist": 0.08},
		"load": 7.0,
	},
	&"cota_ferro": {
		"name": "Cota de Ferro", "slot": ForgedItem.Slot.BODY, "family": &"ferro", "icon": "🛡️",
		"core": [{"id": &"barra_ferro", "n": 3}],
		"coat": [{"id": &"placa_carapaca", "n": 2, "family": &"ferro"}, {"id": &"couro_trotador", "n": 2, "family": &"couro"}],
		"temper": [{"id": &"ossos", "n": 2, "trait": &"ossudo"}, {"id": &"lembranca", "n": 1, "trait": &"saudade"}],
		"mods": {&"resist_slash": 0.14, &"resist_impact": 0.08, &"resist_pierce": 0.06, &"poise_resist": 0.08},
		"load": 18.0,
	},
	# --- Botas
	&"botas_saltarelo": {
		"name": "Botas de Saltarelo", "slot": ForgedItem.Slot.FEET, "family": &"couro", "icon": "🥾",
		"core": [{"id": &"pele_saltarelo", "n": 2}],
		"coat": [{"id": &"fibra", "n": 3, "family": &"pano"}, {"id": &"couro_trotador", "n": 1, "family": &"couro"}, {"id": &"placa_carapaca", "n": 1, "family": &"ferro"}, {"id": &"barra_ferro", "n": 1, "family": &"ferro"}],
		"temper": [{"id": &"fibra", "n": 1, "trait": &"leve"}, {"id": &"garra_tatu", "n": 1, "trait": &"cravado"}, {"id": &"lembranca", "n": 1, "trait": &"saudade"}],
		"mods": {&"resist_slash": 0.03, &"dodge_cost": -2.0},
		"load": 3.0,
	},
	# --- Capa: passiva do material (GDD-12 §6.6), sem mitigação
	&"capa_penas": {
		"name": "Capa de Penas", "slot": ForgedItem.Slot.CAPE, "family": &"pano", "icon": "🪶",
		"core": [{"id": &"pena_penacho", "n": 4}],
		"coat": [{"id": &"fibra", "n": 2, "family": &"pano"}, {"id": &"tendao_elastico", "n": 1, "family": &"couro"}],
		"temper": [{"id": &"lembranca", "n": 1, "trait": &"saudade"}],
		"mods": {},
		"load": 1.0,
		"passive": &"queda_lenta",
	},
	&"capa_couro": {
		"name": "Capa de Couro", "slot": ForgedItem.Slot.CAPE, "family": &"couro", "icon": "🧣",
		"core": [{"id": &"couro_trotador", "n": 2}, {"id": &"couro_lobo", "n": 2}],
		"coat": [{"id": &"fibra", "n": 2, "family": &"pano"}, {"id": &"tendao_elastico", "n": 1, "family": &"couro"}],
		"temper": [{"id": &"lembranca", "n": 1, "trait": &"saudade"}],
		"mods": {},
		"load": 1.5,
		"passive": &"abrigo",
	},
	# --- Mochila: limite de peso do estoque (GDD-12 §6.4); não entra na Carga de combate
	&"mochila": {
		"name": "Mochila", "slot": ForgedItem.Slot.BAG, "family": &"couro", "icon": "🎒",
		"core": [{"id": &"couro_trotador", "n": 2}, {"id": &"couro_lobo", "n": 2}, {"id": &"fibra", "n": 6}],
		"coat": [{"id": &"tendao_elastico", "n": 1, "family": &"couro"}, {"id": &"fibra", "n": 3, "family": &"pano"}],
		"temper": [{"id": &"lembranca", "n": 1, "trait": &"saudade"}],
		"by_family": {&"couro": {&"carry_capacity": 40.0}, &"pano": {&"carry_capacity": 20.0}},
		"load": 0.0,
	},
	# --- Armas (GDD-12 §7): o estilo vem da primária; duas mãos trava a secundária
	&"espada_ferro": {
		"name": "Espada de Ferro", "slot": ForgedItem.Slot.MAIN_HAND, "icon": "🗡️",
		"core": [{"id": &"barra_ferro", "n": 2, "power": 1.0}],
		"coat": [{"id": &"couro_trotador", "n": 1}, {"id": &"couro_lobo", "n": 1}, {"id": &"fibra", "n": 2}],
		"temper": [{"id": &"ossos", "n": 2, "trait": &"ossudo"}, {"id": &"presa_lobo", "n": 1, "trait": &"serrilhado"}],
		"mods": {}, "load": 0.0, "style": &"sword",
	},
	&"mangual": {
		"name": "Mangual", "slot": ForgedItem.Slot.MAIN_HAND, "icon": "🔨", "two_hand": true,
		"core": [{"id": &"barra_ferro", "n": 3, "power": 1.0}, {"id": &"pedra", "n": 6, "power": 0.85}],
		"coat": [{"id": &"madeira", "n": 2}],
		"temper": [{"id": &"ossos", "n": 2, "trait": &"ossudo"}, {"id": &"presa_lobo", "n": 1, "trait": &"serrilhado"}],
		"mods": {}, "load": 0.0, "style": &"heavy",
	},
	&"cajado_arcano": {
		"name": "Cajado Arcano", "slot": ForgedItem.Slot.MAIN_HAND, "icon": "🪄", "two_hand": true,
		"core": [{"id": &"quartzo_lume", "n": 2, "power": 1.0}, {"id": &"pinhao_lume", "n": 2, "power": 0.9}],
		"coat": [{"id": &"madeira", "n": 2}],
		"temper": [{"id": &"mel", "n": 1, "trait": &"doce_foco"}],
		"mods": {}, "load": 0.0, "style": &"staff",
	},
	&"berrante_caca": {
		"name": "Berrante de Caça", "slot": ForgedItem.Slot.MAIN_HAND, "icon": "📯", "two_hand": true,
		"core": [{"id": &"chifre_rinolito", "n": 1, "power": 1.1}, {"id": &"chifre_galhado", "n": 2, "power": 1.0}, {"id": &"ossos", "n": 4, "power": 0.9}],
		"coat": [{"id": &"madeira", "n": 2}, {"id": &"quartzo_lume", "n": 1}, {"id": &"couro_trotador", "n": 2}],
		"temper": [{"id": &"mel", "n": 1, "trait": &"doce_foco"}, {"id": &"ossos", "n": 2, "trait": &"ossudo"}, {"id": &"presa_lobo", "n": 1, "trait": &"serrilhado"}],
		"mods": {}, "load": 0.0, "style": &"hunting_horn",
	},
	&"escudo": {
		"name": "Escudo", "slot": ForgedItem.Slot.OFF_HAND, "icon": "🛡",
		"core": [{"id": &"barra_ferro", "n": 2, "power": 1.0}, {"id": &"madeira", "n": 3, "power": 0.85}],
		"coat": [{"id": &"couro_trotador", "n": 1}, {"id": &"placa_carapaca", "n": 1}],
		"temper": [{"id": &"garra_tatu", "n": 1, "trait": &"cravado"}],
		# O peso do escudo já está no estilo espada e escudo
		"mods": {&"resist_impact": 0.03}, "load": 0.0, "shield": true,
	},
}

## Fundição na bigorna (GDD-12 §8): minério + combustível → 1 barra com a qualidade do minério
const SMELT: Dictionary = {
	&"barra_ferro": {"ore": &"minerio_ferro", "ore_n": 2, "fuel": &"madeira", "fuel_n": 1},
}

## Armas de treino que o Mestre de Armas dá (Q1, sem material para desmanchar)
const TRAINING: Array[StringName] = [&"espada_ferro", &"escudo", &"mangual", &"cajado_arcano", &"berrante_caca"]

const TRAIT_NAMES: Dictionary = {
	&"integro": "Íntegro", &"cicatrizado": "Cicatrizado", &"iridescente": "Iridescente",
	&"leve": "Leve (−10% peso)", &"calma_fria": "Calma Fria", &"doce_foco": "Doce Foco", &"ossudo": "Ossudo",
	&"treino": "Treino", &"serrilhado": "Serrilhado (+6% dano)", &"cravado": "Cravado",
	&"saudade": "Saudade (+5% resistências)",
}
const PASSIVE_NAMES: Dictionary = {
	&"queda_lenta": "Queda lenta", &"abrigo": "Abrigo (+2 regen. de Vigor à noite ou na chuva)",
}
## Bônus de efeito por trait (somados depois da qualidade)
const TRAIT_BONUS: Dictionary = {
	&"cicatrizado": {&"poise_resist": 0.15},
	&"calma_fria": {&"vigor_regen": 2.0},
	&"doce_foco": {&"ether_regen": 1.0},
	&"ossudo": {&"resist_impact": 0.05},
	&"cravado": {&"poise_resist": 0.06},
	# Lembrança de uma montaria que morreu (GDD-16 §7): só sai daí
	&"saudade": {&"resist_slash": 0.05, &"resist_impact": 0.05, &"resist_pierce": 0.05},
}
## Arma com este trait bate mais (multiplica a força da arma)
const WEAPON_TRAIT_POWER: Dictionary = {&"serrilhado": 1.06}
## Traits do núcleo que passam para o item (slot 1)
const CORE_TRAITS: Array[StringName] = [&"cicatrizado", &"integro", &"iridescente"]

## Prévia sem gastar nada. `core`/`coat`/`temper` = pilhas do inventário ({} = vazio).
## Devolve {"ok", "reason", "quality", "traits", "crit", "family"}.
## `temper_ok` = Técnica "Mão de Tempero" aprendida; `crit_bonus` = Técnicas de crítico (B38).
static func preview(recipe_id: StringName, core: Dictionary, coat: Dictionary, temper: Dictionary, forge_level: int, public_forge: bool, temper_ok: bool = true, crit_bonus: float = 0.0) -> Dictionary:
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
	if not temper.is_empty() and not temper_ok:
		return {"ok": false, "reason": "Tempero só com a Técnica Mão de Tempero (Mestra Bigorna Velha, Costelária)"}
	var q := roundi((core.quality * 2.0 + coat.quality) / 3.0)
	var traits: Array[StringName] = []
	for t in CORE_TRAITS:
		if core.traits.has(t):
			traits.append(t)
			break
	if not temper_opt.is_empty():
		traits.append(temper_opt.trait)
	var crit := forge_level * CRIT_PER_LEVEL + (PUBLIC_FORGE_CRIT if public_forge else 0.0) + crit_bonus
	var family: StringName = coat_opt.get("family", r.get("family", &""))
	return {"ok": true, "reason": "", "quality": clampi(q, 1, 5), "traits": traits, "crit": clampf(crit, 0.0, 0.9), "family": family}

## Forja de verdade: gasta as pilhas escolhidas, rola o crítico e devolve o item (ou null)
static func forge(inv: InventoryComponent, recipe_id: StringName, core: Dictionary, coat: Dictionary, temper: Dictionary, forge_level: int, public_forge: bool, rng: RandomNumberGenerator, temper_ok: bool = true, crit_bonus: float = 0.0) -> ForgedItem:
	var p := preview(recipe_id, core, coat, temper, forge_level, public_forge, temper_ok, crit_bonus)
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
	item.family = p.family
	item.quality = mini(5, p.quality + (1 if rng.randf() < p.crit else 0))
	item.traits.assign(p.traits)
	var other_family: bool = item.family != r.get("family", item.family)
	item.display_name = r.name + (" de %s" % item.family_name() if other_family else "") + (" (Íntegro)" if item.traits.has(&"integro") else "")
	# A Lembrança no tempero leva o nome da montaria para a peça
	if not temper.is_empty() and temper.get("memory", {}) is Dictionary and not temper.get("memory", {}).is_empty():
		item.memory = temper.memory.duplicate(true)
		if item.memory.has("name"):
			item.display_name += " · Saudade de %s" % item.memory.name
	var dur := 100.0 * (1.15 if item.traits.has(&"integro") or item.traits.has(&"cicatrizado") else 1.0)
	dur *= float(_option(r.core, core).get("durability", 1.0)) # couro de lobo dura mais
	item.max_durability = dur
	item.durability = dur
	for u in uses:
		item.materials[u[0].id] = item.materials.get(u[0].id, 0) + u[1].n
		inv.consume_stack(u[0], u[1].n)
	return item

## Peça de treino Q1 (Mestre de Armas): sem material, então o desmanche não devolve nada
static func make_training(recipe_id: StringName) -> ForgedItem:
	var r: Dictionary = RECIPES[recipe_id]
	var item := ForgedItem.new()
	item.recipe_id = recipe_id
	item.slot = r.slot
	item.family = r.get("family", &"")
	item.display_name = "%s de Treino" % r.name
	item.traits.append(&"treino")
	return item

## Famílias (pano, couro, ferro) em que a receita pode ser forjada pelos revestimentos disponíveis
static func recipe_families(recipe_id: StringName) -> Array[StringName]:
	var r: Dictionary = RECIPES.get(recipe_id, {})
	var out: Array[StringName] = []
	if r.is_empty():
		return out
	var base: StringName = r.get("family", &"")
	for o in r.get("coat", []):
		var fam: StringName = o.get("family", base)
		if fam != &"" and not out.has(fam):
			out.append(fam)
	if out.is_empty() and base != &"":
		out.append(base)
	return out

## Monta uma peça de demonstração para qualquer derivação (mesmo sem ter os materiais na mochila)
static func make_preview_item(recipe_id: StringName, core_id: StringName = &"", coat_id: StringName = &"", temper_id: StringName = &"", quality: int = 1, core_traits: Array = []) -> ForgedItem:
	var r: Dictionary = RECIPES.get(recipe_id, {})
	if r.is_empty():
		return null
	var core_opt: Dictionary = r.core[0] if not r.core.is_empty() else {}
	for o in r.core:
		if o.id == core_id:
			core_opt = o
			break
	var coat_opt: Dictionary = r.coat[0] if not r.coat.is_empty() else {}
	for o in r.coat:
		if o.id == coat_id:
			coat_opt = o
			break
	var temper_opt: Dictionary = {}
	if temper_id != &"":
		for o in r.temper:
			if o.id == temper_id:
				temper_opt = o
				break
	var item := ForgedItem.new()
	item.recipe_id = recipe_id
	item.slot = r.slot
	item.family = coat_opt.get("family", r.get("family", &""))
	item.quality = clampi(quality, 1, 5)
	for t in CORE_TRAITS:
		if core_traits.has(t):
			item.traits.append(t)
			break
	if not temper_opt.is_empty() and temper_opt.has("trait"):
		item.traits.append(temper_opt.trait)
	if not core_opt.is_empty():
		item.materials[core_opt.id] = int(core_opt.get("n", 1))
	if not coat_opt.is_empty():
		item.materials[coat_opt.id] = item.materials.get(coat_opt.id, 0) + int(coat_opt.get("n", 1))
	if not temper_opt.is_empty():
		item.materials[temper_opt.id] = item.materials.get(temper_opt.id, 0) + int(temper_opt.get("n", 1))
	var other_family: bool = item.family != r.get("family", item.family)
	item.display_name = r.name + (" de %s" % item.family_name() if other_family else "") + (" (Íntegro)" if item.traits.has(&"integro") else "")
	return item

## Funde 1 barra: gasta o minério da melhor pilha que tenha o bastante e o combustível.
## Devolve "" se fundiu, ou o motivo.
static func smelt(inv: InventoryComponent, out_id: StringName) -> String:
	var rec: Dictionary = SMELT.get(out_id, {})
	if rec.is_empty():
		return "Não se funde isso"
	var ores: Array = inv.get_stacks(rec.ore).filter(func(st): return st.amount >= rec.ore_n)
	if ores.is_empty():
		return "Faltam %d %s" % [rec.ore_n, MaterialData.of(rec.ore).display_name]
	if inv.get_material_count(rec.fuel) < rec.fuel_n:
		return "Falta %d %s" % [rec.fuel_n, MaterialData.of(rec.fuel).display_name]
	ores.sort_custom(func(a, b): return a.quality > b.quality)
	var q: int = ores[0].quality
	inv.consume_stack(ores[0], rec.ore_n)
	inv.consume_materials({rec.fuel: rec.fuel_n})
	inv.add_material(out_id, 1, q)
	EventBusAutoload.report(inv.get_parent(), &"fundicao", {"material": String(out_id), "quality": q})
	return ""

## Reparo: 5 $S + 1 do revestimento; durabilidade cheia, mas o máximo cai 4%
static func repair(item: ForgedItem, inv: InventoryComponent, wallet: WalletComponent) -> String:
	if item.durability >= item.max_durability - 0.01:
		return "Já está inteiro"
	if item.traits.has(&"treino"):
		# Peça de treino: o Mestre de Armas troca de graça; na bigorna sai só pelo dinheiro
		if wallet == null or not wallet.spend(REPAIR_COST):
			return "Faltam %s" % WalletComponent.format(REPAIR_COST)
		item.durability = item.max_durability
		return ""
	var coat_id := _coat_material(item)
	if inv.get_material_count(coat_id) < 1:
		return "Falta 1 %s" % MaterialData.of(coat_id).display_name
	if wallet == null or not wallet.spend(REPAIR_COST):
		return "Faltam %s" % WalletComponent.format(REPAIR_COST)
	inv.consume_materials({coat_id: 1})
	item.max_durability *= 1.0 - REPAIR_MAX_LOSS
	item.durability = item.max_durability
	return ""

## Desmanche: devolve 40% dos materiais com −1★ (peça de treino não devolve nada)
static func salvage(item: ForgedItem, inv: InventoryComponent) -> Dictionary:
	var back := {}
	if item.traits.has(&"treino"):
		return back
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
