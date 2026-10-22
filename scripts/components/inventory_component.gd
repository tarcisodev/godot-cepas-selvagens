class_name InventoryComponent
extends Node

## Gerencia inventário de materiais de caça e forja de equipamentos (GDD-03, GDD-05 e GDD-06).
## Permite forjar o Elmo Chifre-de-Pedra aplicando modificadores ao StatsComponent do portador.

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

@export var stats: StatsComponent

var stacks: Array[Dictionary] = []

## Total por id (somente leitura; útil para HUD e depuração)
var materials: Dictionary:
	get:
		var totals := {}
		for s in stacks:
			totals[s.id] = totals.get(s.id, 0) + s.amount
		return totals

# Slots equipados
var equipped: Dictionary = {
	&"head": &"",
	&"body": &""
}

var _craft_source: RefCounted = RefCounted.new()

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
	if not stacks.has(stack) or stack.amount < amount:
		return false
	stack.amount -= amount
	_drop_empty()
	stacks_changed.emit()
	return true

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
	if not (hp_room or vigor_room or ether_room):
		return false
	pools.heal(data.restore_health)
	pools.restore_vigor(data.restore_vigor)
	pools.restore_ether(data.restore_ether)
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
	&"laco_fibra": {&"fibra": 4, &"galho": 2},
	&"sedativo_erva": {&"erva": 3, &"mel": 1},
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

## Forja e equipa o Elmo Chifre-de-Pedra (GDD-06 §5) com a pilha de chifre dada
## (vazia = o melhor chifre que houver). Qualidade e trait do elmo vêm do chifre.
func craft_and_equip_horn_helmet(horn: Dictionary = {}) -> bool:
	if horn.is_empty():
		horn = best_stack(&"chifre_rinolito")
	if horn.is_empty() or get_material_count(&"placa_carapaca") < 1:
		return false
	consume_stack(horn, 1)
	consume_materials({&"placa_carapaca": 1})

	var is_integro: bool = horn.traits.has(&"integro")
	var quality: int = horn.quality + 1 if is_integro else horn.quality
	var traits: Array[StringName] = []
	if is_integro:
		traits.append(&"Casca Rígida")
	else:
		traits.append(&"Reforçado")
	
	# Remove modificadores de capacete anteriores deste componente
	if stats != null:
		stats.remove_modifiers_from_source(_craft_source)
		
		# Modificadores de armadura e poise
		var poise_bonus: float = 0.25 if is_integro else 0.12
		var armor_bonus: float = 0.20 if is_integro else 0.10
		var load_weight: float = 18.0 if is_integro else 12.0
		
		stats.add_modifier(ModifierData.new(&"poise_resist", ModifierData.Op.FLAT, poise_bonus, _craft_source))
		stats.add_modifier(ModifierData.new(&"resist_slash", ModifierData.Op.FLAT, armor_bonus, _craft_source))
		stats.add_modifier(ModifierData.new(&"resist_impact", ModifierData.Op.FLAT, armor_bonus, _craft_source))
		stats.add_modifier(ModifierData.new(&"load", ModifierData.Op.FLAT, load_weight, _craft_source))
		
		# Aumento de peso reduz velocidade de cast e aumenta custo de esquiva
		var dodge_cost_inc: float = 8.0 if is_integro else 4.0
		stats.add_modifier(ModifierData.new(&"dodge_cost", ModifierData.Op.FLAT, dodge_cost_inc, _craft_source))
	
	var helmet_name: StringName = &"Elmo Chifre-de-Pedra (Íntegro)" if is_integro else &"Elmo Chifre-de-Pedra (Fragmentado)"
	equipped[&"head"] = helmet_name
	
	item_crafted.emit(helmet_name, quality, traits)
	equipment_changed.emit(&"head", helmet_name)
	
	# Concede XP de maestria de forja
	var parent: Node = get_parent()
	if parent != null:
		var mastery: MasteryComponent = parent.get_node_or_null("MasteryComponent") as MasteryComponent
		if mastery != null:
			mastery.add_xp(&"forja", 45.0 if is_integro else 25.0)
	
	return true
