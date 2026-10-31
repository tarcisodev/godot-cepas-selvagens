class_name LedgerExchanges
extends RefCounted

const _InventoryComponent = preload("res://scripts/components/inventory_component.gd")
const _WalletComponent = preload("res://scripts/components/wallet_component.gd")
const _ForgedItem = preload("res://scripts/data/forged_item.gd")
const _Forge = preload("res://scripts/systems/forge.gd")
const _CookingSystem = preload("res://scripts/systems/cooking_system.gd")

## Trocas determinísticas do livro-razão (B41 fase 2): forja, fundição, reparo, desmanche,
## cozinha e espeto. O cliente chama o atalho daqui (roda a função de sempre como previsão e manda
## o pedido); o servidor refaz a mesma função estática no livro, com as pilhas dele e o sorteio dele.
## Pilhas vão pela rede como chave (InventoryComponent.stack_key) e peças pelo índice em `items`.

const VERBS: Array[StringName] = [&"forge", &"smelt", &"repair", &"salvage", &"cook", &"roast"]
## Limites do que o cliente informa sobre si (maestria ainda é do cliente)
const MAX_FORGE_LEVEL: int = 100
const MAX_CRIT_BONUS: float = 0.25
## Espeto: o que pode sair da carne crua, e a qualidade máxima de cada ponto
const ROAST_RESULTS: Dictionary = {&"carne_mal_passada": 0, &"carne_bem_passada": 3, &"carne_torrada": 1}

# ---------------------------------------------------------------- atalhos do cliente

## Forja e guarda a peça. Devolve a peça (ou null), como Forge.forge.
static func forge(player: Node, recipe_id: StringName, core: Dictionary, coat: Dictionary, temper: Dictionary, forge_level: int, public_forge: bool, rng: RandomNumberGenerator, temper_ok: bool, crit_bonus: float) -> ForgedItem:
	var inv: InventoryComponent = player.inventory
	var args := {"recipe": String(recipe_id), "core": _key(core), "coat": _key(coat), "temper": _key(temper), "level": forge_level, "public": public_forge, "temper_ok": temper_ok, "crit": crit_bonus}
	return _run(inv, &"forge", args, func():
		var item := _Forge.forge(inv, recipe_id, core, coat, temper, forge_level, public_forge, rng, temper_ok, crit_bonus)
		if item:
			inv.add_item(item)
		return item)

static func smelt(player: Node, out_id: StringName) -> String:
	var inv: InventoryComponent = player.inventory
	var res: Variant = _run(inv, &"smelt", {"out": String(out_id)}, func(): return _smelt_result(inv, out_id))
	return String(res.get("err", "")) if res is Dictionary else ""

static func repair(player: Node, item: ForgedItem) -> String:
	var inv: InventoryComponent = player.inventory
	var wallet: WalletComponent = player.wallet
	var res: Variant = _run(inv, &"repair", {"index": inv.items.find(item)}, func():
		var err := _Forge.repair(item, inv, wallet)
		return {"ok": err.is_empty(), "err": err})
	return String(res.get("err", "")) if res is Dictionary else ""

## Desmancha: devolve os materiais e tira a peça da mochila
static func salvage(player: Node, item: ForgedItem) -> Dictionary:
	var inv: InventoryComponent = player.inventory
	var res: Variant = _run(inv, &"salvage", {"index": inv.items.find(item)}, func():
		if not inv.items.has(item):
			return {"ok": false}
		var back := _Forge.salvage(item, inv)
		inv.remove_item(item)
		return {"ok": true, "back": back})
	return res.get("back", {}) if res is Dictionary else {}

static func cook(player: Node, base_stack: Dictionary, side_stacks: Array) -> Dictionary:
	var inv: InventoryComponent = player.inventory
	var sides: Array = side_stacks.map(func(s): return _key(s))
	var res: Variant = _run(inv, &"cook", {"base": _key(base_stack), "sides": sides}, func():
		var r := _CookingSystem.cook(inv, base_stack, side_stacks)
		r["ok"] = bool(r.get("success", false))
		return r)
	return res if res is Dictionary else {"success": false}

## Espeto: troca 1 carne crua pelo resultado do ponto (o tempo é do cliente; o servidor limita a qualidade)
static func roast(inv: InventoryComponent, meat_stack: Dictionary, result_id: StringName, out_q: int) -> bool:
	var traits: Array = meat_stack.get("traits", []).duplicate()
	return bool(_run(inv, &"roast", {"meat": _key(meat_stack), "result": String(result_id), "q": out_q}, func():
		if not inv.consume_stack(meat_stack, 1):
			return false
		inv.add_material(result_id, 1, out_q, traits)
		return true))

static func _smelt_result(inv: InventoryComponent, out_id: StringName) -> Dictionary:
	var err := _Forge.smelt(inv, out_id)
	return {"ok": err.is_empty(), "err": err}

## Previsão local + pedido ao servidor quando o inventário é do jogador online; senão, só local
static func _run(inv: InventoryComponent, verb: StringName, args: Dictionary, local: Callable) -> Variant:
	if inv != null and inv.ledger != null:
		return inv.ledger.run(verb, args, local)
	return local.call()

static func _key(stack: Dictionary) -> Dictionary:
	return _InventoryComponent.stack_key(stack) if not stack.is_empty() else {}

# ---------------------------------------------------------------- servidor

## O servidor refaz a troca no livro. Devolve o mesmo formato do atalho (sucesso via LedgerVerbs.succeeded).
static func execute(verb: StringName, inv: InventoryComponent, wallet: WalletComponent, args: Dictionary) -> Variant:
	match verb:
		&"forge":
			var recipe := StringName(str(args.get("recipe", "")))
			if not _Forge.RECIPES.has(recipe):
				return false
			var core := _stack(inv, args.get("core", {}))
			var coat := _stack(inv, args.get("coat", {}))
			var temper := _stack(inv, args.get("temper", {}))
			if core.is_empty() or coat.is_empty() or (not (args.get("temper", {}) as Dictionary).is_empty() and temper.is_empty()):
				return false
			var level := clampi(int(args.get("level", 1)), 1, MAX_FORGE_LEVEL)
			var crit := clampf(float(args.get("crit", 0.0)), 0.0, MAX_CRIT_BONUS)
			var rng := RandomNumberGenerator.new()
			rng.randomize()
			var item := _Forge.forge(inv, recipe, core, coat, temper, level, bool(args.get("public", false)), rng, bool(args.get("temper_ok", false)), crit)
			if item == null:
				return false
			inv.add_item(item)
			return true
		&"smelt":
			return _smelt_result(inv, StringName(str(args.get("out", ""))))
		&"repair":
			var it := _item(inv, args.get("index", -1))
			if it == null:
				return false
			var err := _Forge.repair(it, inv, wallet)
			return {"ok": err.is_empty(), "err": err}
		&"salvage":
			var it := _item(inv, args.get("index", -1))
			if it == null:
				return false
			_Forge.salvage(it, inv)
			inv.remove_item(it)
			return true
		&"cook":
			var base := _stack(inv, args.get("base", {}))
			var sides: Array = []
			for k in args.get("sides", []):
				var s := _stack(inv, k)
				if s.is_empty():
					return false
				sides.append(s)
			if base.is_empty() or sides.is_empty():
				return false
			return bool(_CookingSystem.cook(inv, base, sides).get("success", false))
		&"roast":
			var meat := _stack(inv, args.get("meat", {}))
			var result := StringName(str(args.get("result", "")))
			if meat.is_empty() or not ROAST_RESULTS.has(result):
				return false
			var base_q := int(meat.quality)
			var cap: int = maxi(base_q, int(ROAST_RESULTS[result])) if result != &"carne_torrada" else 1
			var q := clampi(int(args.get("q", 1)), 1, cap)
			var traits: Array = meat.traits.duplicate()
			if not inv.consume_stack(meat, 1):
				return false
			inv.add_material(result, 1, q, traits)
			return true
	return false

## Pilha do livro que bate com a chave ({} se não houver)
static func _stack(inv: InventoryComponent, key: Variant) -> Dictionary:
	if not (key is Dictionary) or (key as Dictionary).is_empty():
		return {}
	return inv._resolve_stack(key)

static func _item(inv: InventoryComponent, index: Variant) -> ForgedItem:
	var i := int(index) if (index is int or index is float) else -1
	return inv.items[i] if i >= 0 and i < inv.items.size() else null
