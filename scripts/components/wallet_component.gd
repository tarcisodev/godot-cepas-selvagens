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
	money += amount
	money_changed.emit(money)

func can_afford(amount: int) -> bool:
	return amount >= 0 and money >= amount

## Gasta se houver saldo; devolve false sem mexer no saldo se não houver
func spend(amount: int) -> bool:
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
