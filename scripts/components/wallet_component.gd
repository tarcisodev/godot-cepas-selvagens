class_name WalletComponent
extends Node

## Carteira de Dólares de Sucata ($S) do personagem (GDD-05 §5). Inteiro, sem centavos.
## No online só o servidor altera o saldo (ADR-0002); aqui a regra é a mesma, local.

const SYMBOL: String = "$S"
const STARTING_MONEY: int = 50

signal money_changed(money: int)

var money: int = STARTING_MONEY

func add(amount: int) -> void:
	if amount <= 0:
		return
	if ledger != null and ledger.should_route():
		ledger.note_money(amount)
	money += amount
	money_changed.emit(money)

func can_afford(amount: int) -> bool:
	return amount >= 0 and money >= amount

## Livro-razão (ADR-0009): só a carteira do jogador local tem. No cliente online o gasto roda aqui
## como previsão e vai ao servidor como pedido. `add` só vale dentro de uma fonte (LedgerSources.gain).
var ledger: Node = null

## Gasta se houver saldo; devolve false sem mexer no saldo se não houver
func spend(amount: int) -> bool:
	if ledger != null and ledger.should_route():
		return ledger.run(&"spend", {"amount": amount}, func(): return _spend(amount))
	return _spend(amount)

func _spend(amount: int) -> bool:
	if not can_afford(amount):
		return false
	money -= amount
	money_changed.emit(money)
	return true

func set_money(value: int) -> void:
	money = maxi(0, value)
	money_changed.emit(money)

static func format(amount: int) -> String:
	return "%d %s" % [amount, SYMBOL]
