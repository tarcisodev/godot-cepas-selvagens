class_name ModifierData
extends Resource

## Operação matemática do modificador
enum Op {
	FLAT,      ## Soma direta: (base + flat)
	PCT_ADD,   ## Porcentagem aditiva: (1 + sum(pct_add))
	PCT_MULT   ## Porcentagem multiplicativa: product(1 + pct_mult)
}

@export var stat: StringName = &""
@export var op: Op = Op.FLAT
@export var value: float = 0.0

## Referência opcional à fonte (Item, Buff, Habilidade, etc.) para remoção em lote
var source: Object = null

func _init(p_stat: StringName = &"", p_op: Op = Op.FLAT, p_value: float = 0.0, p_source: Object = null) -> void:
	stat = p_stat
	op = p_op
	value = p_value
	source = p_source
