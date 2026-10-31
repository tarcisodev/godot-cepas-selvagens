class_name LedgerVerbs
extends RefCounted

const _InventoryComponent = preload("res://scripts/components/inventory_component.gd")
const _WalletComponent = preload("res://scripts/components/wallet_component.gd")
const _ForgedItem = preload("res://scripts/data/forged_item.gd")
const _LedgerExchanges = preload("res://scripts/net/ledger_exchanges.gd")

## Verbos do livro-razão (ADR-0009, B41 fase 2). O servidor refaz cada pedido no livro do jogador
## com os dados dele; o cliente roda o mesmo código como previsão. Tudo que vem do cliente é
## conferido aqui: quantidade positiva e com teto, pilha e peça que existem, saldo que existe.
##
## Primitivas são gastos sem ganho (consumir, gastar, usar, equipar, desgaste): não criam valor.
## Trocas (gasta e ganha) têm verbo próprio e o servidor calcula o que sai (craft, compra...).
## Sistemas registram trocas com `register()` (o Callable recebe inv, wallet e args).

const MAX_AMOUNT: int = 9999

static var _exchanges: Dictionary = {}

## Registra uma troca: Callable(inv: InventoryComponent, wallet: WalletComponent, args: Dictionary) -> Variant
static func register(verb: StringName, handler: Callable) -> void:
	_exchanges[verb] = handler

static func is_known(verb: StringName) -> bool:
	return _exchanges.has(verb) or _LedgerExchanges.VERBS.has(verb) or verb in [&"consume_materials", &"consume_stack", &"swap_stacks", &"equip", &"unequip", &"remove_item", &"wear", &"spend", &"craft"]

## Sucesso de um resultado de verbo: true, dicionário não vazio, ou {"ok": true}
static func succeeded(result: Variant) -> bool:
	if result is bool:
		return result
	if result is Dictionary:
		return bool(result.get("ok", not result.is_empty()))
	return result != null

## Roda o verbo no inventário e carteira dados (o livro, no servidor)
static func execute(verb: StringName, inv: InventoryComponent, wallet: WalletComponent, args: Dictionary) -> Variant:
	if inv == null or wallet == null:
		return false
	match verb:
		&"consume_materials":
			var req := requirements(args.get("req", {}))
			return not req.is_empty() and inv.consume_materials(req)
		&"consume_stack":
			var n := amount(args.get("n", 0))
			return n > 0 and inv.consume_stack(args.get("stack", {}), n)
		&"swap_stacks":
			return inv.swap_stacks(args.get("a", {}), args.get("b", {}))
		&"equip":
			var it := item_at(inv, args.get("index", -1))
			if it == null:
				return false
			inv.equip(it)
			return true
		&"unequip":
			var slot := int(args.get("slot", -1))
			if slot < 0 or slot >= _ForgedItem.SLOT_KEYS.size():
				return false
			inv.unequip(slot)
			return true
		&"remove_item":
			var it := item_at(inv, args.get("index", -1))
			if it == null:
				return false
			inv.remove_item(it)
			return true
		&"wear":
			var a := clampf(float(args.get("amount", 0.0)), 0.0, 1000.0)
			var f := clampf(float(args.get("fraction", 0.0)), 0.0, 1.0)
			inv.wear_equipped(a, f)
			return true
		&"spend":
			var n := amount(args.get("amount", 0))
			return n > 0 and wallet.spend(n)
		&"craft":
			var recipe := StringName(str(args.get("recipe", "")))
			return _InventoryComponent.RECIPES.has(recipe) and inv.craft(recipe)
	if _LedgerExchanges.VERBS.has(verb):
		return _LedgerExchanges.execute(verb, inv, wallet, args)
	if _exchanges.has(verb):
		return _exchanges[verb].call(inv, wallet, args)
	return false

## Quantidade inteira positiva com teto (0 se vier algo inválido)
static func amount(v: Variant) -> int:
	if not (v is int or v is float):
		return 0
	var n := int(v)
	return n if n > 0 and n <= MAX_AMOUNT else 0

## {id: n} vindo da rede: ids viram StringName e toda quantidade precisa ser válida
static func requirements(raw: Variant) -> Dictionary:
	var out := {}
	if not (raw is Dictionary):
		return out
	for k in raw:
		var n := amount(raw[k])
		if n == 0:
			return {}
		out[StringName(str(k))] = n
	return out

static func item_at(inv: InventoryComponent, index: Variant) -> ForgedItem:
	var i := int(index) if (index is int or index is float) else -1
	return inv.items[i] if i >= 0 and i < inv.items.size() else null
