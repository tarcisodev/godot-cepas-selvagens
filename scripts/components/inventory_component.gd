class_name InventoryComponent
extends Node

const _ForgedItem = preload("res://scripts/data/forged_item.gd")
const _StatsComponent = preload("res://scripts/components/stats_component.gd")

## Gerencia inventário de materiais de caça e forja de equipamentos (GDD-03, GDD-05 e GDD-06).
## Peças forjadas (GDD-06 §6) ficam em `items`; uma por encaixe em `equipped_items`, com os
## efeitos aplicados ao StatsComponent. `equipped` guarda só os nomes (HUD, objetivos).

## Materiais ficam em pilhas (ADR-0005): { "id", "quality" (1–5), "traits" (ordenados), "amount" }.
## Unidades só se juntam com id, qualidade e traits iguais. A API por id (add/get/consume)
## continua valendo: conta a soma das pilhas e gasta da pior qualidade para a melhor.

signal material_collected(material_id: StringName, amount: int)
signal item_crafted(item_name: StringName, quality: int, traits: Array[StringName])
signal equipment_changed(slot: StringName, item_name: StringName)
## Qualquer mudança nas pilhas (para a tela de inventário se redesenhar)
signal stacks_changed()
## Consumível usado (poção, carne, erva...): `effect` é o resumo do que repôs
signal item_used(material_id: StringName, effect: String)
## Pilha de material jogada no chão
signal stack_dropped(stack: Dictionary)
## Peça forjada jogada no chão
signal forged_item_dropped(item: ForgedItem)

@export var stats: StatsComponent

var stacks: Array[Dictionary] = []

## Total por id (somente leitura; útil para HUD e depuração)
var materials: Dictionary:
	get:
		var totals := {}
		for s in stacks:
			totals[s.id] = totals.get(s.id, 0) + s.amount
		return totals

## Nomes do que está equipado por encaixe (GDD-12 §1)
var equipped: Dictionary = {
	&"head": &"",
	&"body": &"",
	&"feet": &"",
	&"main_hand": &"",
	&"off_hand": &"",
	&"cape": &"",
	&"bag": &"",
}
## Peso que o estoque carrega sem lentidão, sem mochila (GDD-12 §6.4)
const BASE_CARRY: float = 20.0
## Peças forjadas guardadas e as equipadas (encaixe -> ForgedItem)
var items: Array[ForgedItem] = []
var equipped_items: Dictionary = {}
## Se verdadeiro, esconde o capacete/capuz no personagem mantendo a defesa e a habilidade
var hide_helmet: bool = false
## Fonte dos modificadores de cada encaixe (para tirar só os daquela peça)
var _slot_sources: Dictionary = {}

signal items_changed()

func set_hide_helmet(hide: bool) -> void:
	if hide_helmet == hide:
		return
	hide_helmet = hide
	equipment_changed.emit(&"head", equipped[&"head"])
	items_changed.emit()

func _init() -> void:
	_add_to_stack(&"placa_carapaca", 2, 1, []) # Já inicia com 2 placas de carapaça para o slice

func _ready() -> void:
	if stats == null:
		stats = get_parent().get_node_or_null("StatsComponent") as StatsComponent

## Adiciona material na pilha de mesma qualidade e traits (cria a pilha se não houver)
func add_material(material_id: StringName, amount: int = 1, quality: int = 1, traits: Array = []) -> void:
	if amount <= 0:
		return
	_add_to_stack(material_id, amount, quality, traits)
	material_collected.emit(material_id, amount)
	stacks_changed.emit()

## Quantidade de um material (soma das pilhas)
func get_material_count(material_id: StringName) -> int:
	var total := 0
	for s in _stacks_matching(material_id):
		total += s.amount
	return total

## Verifica se possui os materiais requeridos
func has_materials(requirements: Dictionary) -> bool:
	for mat_id in requirements.keys():
		if get_material_count(mat_id) < requirements[mat_id]:
			return false
	return true

## Consome materiais, da pior qualidade para a melhor (ADR-0005)
func consume_materials(requirements: Dictionary) -> bool:
	if not has_materials(requirements):
		return false
	for mat_id in requirements.keys():
		var left: int = requirements[mat_id]
		for s in _stacks_matching(mat_id):
			var take := mini(left, s.amount)
			s.amount -= take
			left -= take
			if left == 0:
				break
	_drop_empty()
	stacks_changed.emit()
	return true

## Pilhas de um material (ou todas, com id vazio), da pior qualidade para a melhor.
func get_stacks(material_id: StringName = &"") -> Array[Dictionary]:
	if material_id.is_empty():
		return stacks.duplicate()
	return _stacks_matching(material_id)

## Consome `amount` de uma pilha específica (a forja escolhe a pilha).
func consume_stack(stack: Dictionary, amount: int = 1) -> bool:
	var target := _resolve_stack(stack)
	if target.is_empty() or target.amount < amount:
		return false
	target.amount -= amount
	_drop_empty()
	stacks_changed.emit()
	return true

## Remove `amount` (ou tudo se `amount <= 0`) de uma pilha para jogar no chão.
## Devolve o dicionário da pilha descartada ({id, quality, traits, amount}) ou {} se falhar.
func drop_stack(stack: Dictionary, amount: int = -1) -> Dictionary:
	var target := _resolve_stack(stack)
	if target.is_empty() or int(target.amount) <= 0:
		return {}
	var take: int = int(target.amount) if amount <= 0 else mini(amount, int(target.amount))
	if take <= 0:
		return {}
	var dropped := {
		"id": StringName(target.id),
		"quality": int(target.quality),
		"traits": target.traits.duplicate(),
		"amount": take,
	}
	target.amount -= take
	_drop_empty()
	stack_dropped.emit(dropped)
	stacks_changed.emit()
	return dropped

## Troca a posição de duas pilhas no array do inventário (usado no arrastar e soltar manual)
func swap_stacks(stack_a: Dictionary, stack_b: Dictionary) -> bool:
	var a := _resolve_stack(stack_a)
	var b := _resolve_stack(stack_b)
	if a.is_empty() or b.is_empty() or a == b:
		return false
	var idx_a: int = stacks.find(a)
	var idx_b: int = stacks.find(b)
	if idx_a < 0 or idx_b < 0:
		return false
	stacks[idx_a] = b
	stacks[idx_b] = a
	stacks_changed.emit()
	return true

func _resolve_stack(stack: Dictionary) -> Dictionary:
	if stack.is_empty():
		return {}
	if stacks.has(stack):
		return stack
	var want_id := StringName(stack.get("id", &""))
	var want_q: int = int(stack.get("quality", 1))
	var want_traits: Array = stack.get("traits", [])
	for s in stacks:
		if s.id == want_id and int(s.quality) == want_q and s.traits == want_traits:
			return s
	return {}

## Usa uma unidade de um consumível da pilha dada: gasta e repõe Vida/Vigor/Éter nos pools.
## Recusa se o item não é consumível ou se não repõe nada (tudo cheio), para não desperdiçar.
func use_item(stack: Dictionary, pools: PoolsComponent) -> bool:
	if pools == null or not stacks.has(stack) or stack.amount < 1:
		return false
	var data := MaterialData.of(stack.id)
	if not data.is_consumable():
		return false
	var hp_room: bool = data.restore_health > 0.0 and pools.current_health < pools.stats.get_stat(&"max_health")
	var vigor_room: bool = data.restore_vigor > 0.0 and pools.current_vigor < pools.stats.get_stat(&"max_vigor")
	var ether_room: bool = data.restore_ether > 0.0 and pools.current_ether < pools.stats.get_stat(&"max_ether")
	var has_buff: bool = not data.food_buff_id.is_empty()
	if not (hp_room or vigor_room or ether_room or has_buff):
		return false
	if data.restore_health > 0.0:
		pools.heal(data.restore_health)
	if data.restore_vigor > 0.0:
		pools.restore_vigor(data.restore_vigor)
	if data.restore_ether > 0.0:
		pools.restore_ether(data.restore_ether)
	if has_buff:
		var target_node: Node = pools.get_parent() if pools else null
		var food_comp: Node = target_node.get("food_buff") if target_node else null
		if food_comp and food_comp.has_method("apply_food_buff"):
			food_comp.apply_food_buff(data.food_buff_id, data.food_buff_duration, int(stack.get("quality", 1)), stack.get("traits", []))
	consume_stack(stack, 1)
	item_used.emit(stack.id, data.effect_text())
	return true

## Usa o consumível mais fraco que ainda repõe `pool` (&"health", &"vigor" ou &"ether"):
## atalho de combate, guarda as poções fortes para quando a Vida está baixa de verdade.
func use_best_for(pool: StringName, pools: PoolsComponent) -> bool:
	if pools == null:
		return false
	var missing: float = 0.0
	match pool:
		&"health": missing = pools.stats.get_stat(&"max_health") - pools.current_health
		&"vigor": missing = pools.stats.get_stat(&"max_vigor") - pools.current_vigor
		&"ether": missing = pools.stats.get_stat(&"max_ether") - pools.current_ether
	if missing <= 0.0:
		return false
	var options: Array[Dictionary] = []
	for s in stacks:
		if _restore_of(s.id, pool) > 0.0:
			options.append(s)
	if options.is_empty():
		return false
	# Prefere o menor item que cobre o que falta; se nenhum cobre, o maior que houver
	options.sort_custom(func(a, b): return _restore_of(a.id, pool) < _restore_of(b.id, pool))
	var pick: Dictionary = options[options.size() - 1]
	for s in options:
		if _restore_of(s.id, pool) >= missing:
			pick = s
			break
	return use_item(pick, pools)

static func _restore_of(material_id: StringName, pool: StringName) -> float:
	var data := MaterialData.of(material_id)
	match pool:
		&"health": return data.restore_health
		&"vigor": return data.restore_vigor
		&"ether": return data.restore_ether
	return 0.0

## Peso total carregado em materiais (kg)
func get_total_weight() -> float:
	var w := 0.0
	for s in stacks:
		w += MaterialData.of(s.id).unit_weight * s.amount
	return w

## Pilhas em formato JSON (save/rede)
func stacks_to_save() -> Array:
	var out: Array = []
	for s in stacks:
		out.append({"id": String(s.id), "quality": s.quality, "traits": s.traits.map(func(t): return String(t)), "amount": s.amount})
	return out

## Recarrega as pilhas a partir de `stacks_to_save()`
func load_from_save(data: Array) -> void:
	stacks.clear()
	for e in data:
		if e is Dictionary:
			var traits: Array = e.get("traits", []).map(func(t): return StringName(t))
			_add_to_stack(StringName(e.get("id", "")), int(e.get("amount", 0)), int(e.get("quality", 1)), traits)
	stacks_changed.emit()

## Pilha de maior qualidade de um material ({} se não houver)
func best_stack(material_id: StringName) -> Dictionary:
	var list := _stacks_matching(material_id)
	return list[list.size() - 1] if not list.is_empty() else {}

func _add_to_stack(material_id: StringName, amount: int, quality: int, traits: Array) -> void:
	if material_id.is_empty() or amount <= 0:
		return
	var key_traits: Array[StringName] = []
	for t in traits:
		key_traits.append(StringName(t))
	key_traits.sort()
	quality = clampi(quality, 1, 5)
	for s in stacks:
		if s.id == material_id and s.quality == quality and s.traits == key_traits:
			s.amount += amount
			return
	stacks.append({"id": material_id, "quality": quality, "traits": key_traits, "amount": amount})

## Receitas de ofício simples (GDD-03 §9): resultado -> {materiais}
const RECIPES: Dictionary = {
	&"tocha": {&"galho": 2, &"fibra": 1},
	&"laco_fibra": {&"fibra": 4, &"galho": 2},
	&"sedativo_erva": {&"erva": 3, &"mel": 1},
	&"vara_pesca": {&"galho": 3, &"fibra": 4},
}

## Faz 1 unidade da receita (gasta a pior qualidade primeiro). false se faltar material.
func craft(result_id: StringName) -> bool:
	var recipe: Dictionary = RECIPES.get(result_id, {})
	if recipe.is_empty() or not consume_materials(recipe):
		return false
	add_material(result_id, 1)
	return true

## Pilhas de um material, da pior qualidade para a melhor
func _stacks_matching(material_id: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for s in stacks:
		if s.id == material_id:
			out.append(s)
	out.sort_custom(func(a, b): return a.quality < b.quality)
	return out

func _drop_empty() -> void:
	for i in range(stacks.size() - 1, -1, -1):
		if stacks[i].amount <= 0:
			stacks.remove_at(i)

# ---------------------------------------------------------------- peças forjadas (GDD-06 §6)

func add_item(item: ForgedItem) -> void:
	items.append(item)
	item_crafted.emit(StringName(item.display_name), item.quality, item.traits)
	items_changed.emit()

## Equipa no encaixe da peça (troca a que estava). A peça precisa estar em `items`.
## Arma de duas mãos tira a secundária; secundária tira a arma de duas mãos (GDD-12 §3).
func equip(item: ForgedItem) -> void:
	if not items.has(item):
		return
	if item.slot == ForgedItem.Slot.MAIN_HAND and item.is_two_handed() and equipped_items.has(ForgedItem.Slot.OFF_HAND):
		unequip(ForgedItem.Slot.OFF_HAND)
	elif item.slot == ForgedItem.Slot.OFF_HAND:
		var main: ForgedItem = equipped_items.get(ForgedItem.Slot.MAIN_HAND)
		if main and main.is_two_handed():
			unequip(ForgedItem.Slot.MAIN_HAND)
	equipped_items[item.slot] = item
	_refresh_slot(item.slot)

## Família de cada peça de armadura equipada (cabeça, peito, botas): XP de armadura por família
func armor_families() -> Array[StringName]:
	var out: Array[StringName] = []
	for slot in ForgedItem.ARMOR_SLOTS:
		var it: ForgedItem = equipped_items.get(slot)
		if it and not it.is_broken() and ForgedItem.FAMILY.has(it.family):
			out.append(it.family)
	return out

## Limite de peso do estoque: base + mochila (kg)
func carry_capacity() -> float:
	return BASE_CARRY + (stats.get_stat(&"carry_capacity") if stats else 0.0)

## Peso carregado / limite (1 = no limite; acima disso fica lento, GDD-12 §6.4)
func carry_ratio() -> float:
	return get_total_weight() / maxf(carry_capacity(), 1.0)

func unequip(slot: int) -> void:
	equipped_items.erase(slot)
	_refresh_slot(slot)

## Tira uma peça da mochila (desmanche); desequipa se estiver em uso
func remove_item(item: ForgedItem) -> void:
	if equipped_items.get(item.slot) == item:
		unequip(item.slot)
	items.erase(item)
	items_changed.emit()

## Joga uma peça forjada no chão (desequipa se estiver equipada e emite sinal)
func drop_forged_item(item: ForgedItem) -> bool:
	if item == null or not items.has(item):
		return false
	remove_item(item)
	forged_item_dropped.emit(item)
	return true

func equipped_in(slot: int) -> ForgedItem:
	return equipped_items.get(slot)

## Reaplica os efeitos do encaixe (peça quebrada não protege, mas ainda pesa)
func _refresh_slot(slot: int) -> void:
	if not _slot_sources.has(slot):
		_slot_sources[slot] = RefCounted.new()
	var src: RefCounted = _slot_sources[slot]
	var item: ForgedItem = equipped_items.get(slot)
	var key: StringName = ForgedItem.SLOT_KEYS[slot]
	if stats:
		stats.remove_modifiers_from_source(src)
		if item:
			var fx := item.effects()
			for stat in fx:
				if item.is_broken() and stat != &"load":
					continue
				stats.add_modifier(ModifierData.new(stat, ModifierData.Op.FLAT, fx[stat], src))
	equipped[key] = StringName(item.display_name) if item else &""
	equipment_changed.emit(key, equipped[key])
	items_changed.emit()

## Desgaste: golpe recebido (−1) ou queda (−10% do máximo, GDD-06 §4)
func wear_equipped(amount: float, fraction_of_max: float = 0.0) -> void:
	for slot in equipped_items:
		var item: ForgedItem = equipped_items[slot]
		var was_broken := item.is_broken()
		if fraction_of_max > 0.0:
			item.max_durability = maxf(1.0, item.max_durability * (1.0 - fraction_of_max))
			item.durability = minf(item.durability, item.max_durability)
		item.durability = maxf(0.0, item.durability - amount)
		if item.is_broken() != was_broken:
			_refresh_slot(slot)
	items_changed.emit()

func items_to_save() -> Dictionary:
	var eq := {}
	for slot in equipped_items:
		eq[str(slot)] = items.find(equipped_items[slot])
	return {"items": items.map(func(it): return it.to_dict()), "equipped": eq, "hide_helmet": hide_helmet}

func load_items(data: Dictionary) -> void:
	for slot in equipped_items.keys():
		unequip(slot)
	items.clear()
	hide_helmet = bool(data.get("hide_helmet", false))
	for d in data.get("items", []):
		items.append(ForgedItem.from_dict(d))
	var eq: Dictionary = data.get("equipped", {})
	for slot in eq:
		var idx := int(eq[slot])
		if idx >= 0 and idx < items.size():
			equip(items[idx])
	equipment_changed.emit(&"head", equipped[&"head"])
	items_changed.emit()

## Atalho do slice: forja o Elmo Chifre-de-Pedra com o chifre dado (ou o melhor) e as placas,
## e já equipa. Usado pelo menu e pelos testes antigos.
func craft_and_equip_horn_helmet(horn: Dictionary = {}) -> bool:
	if horn.is_empty():
		horn = best_stack(&"chifre_rinolito")
	var plates := _stacks_matching(&"placa_carapaca").filter(func(s): return s.amount >= 2)
	if horn.is_empty() or plates.is_empty():
		return false
	var mastery: MasteryComponent = get_parent().get_node_or_null("MasteryComponent") as MasteryComponent if get_parent() else null
	var level: int = mastery.get_level(&"forja") if mastery else 1
	var item := Forge.forge(self, &"elmo_chifre_de_pedra", horn, plates[plates.size() - 1], {}, level, false, RandomNumberGenerator.new())
	if item == null:
		return false
	add_item(item)
	equip(item)
	if mastery:
		mastery.add_xp(&"forja", 45.0 if item.traits.has(&"integro") else 25.0)
	return true
