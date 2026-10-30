class_name MilestoneDef
extends Resource

## Marco do Diário do Caçador (GDD-19 §6): feito com jeito que dá título, carta, adorno ou
## acesso no Quadro — nunca atributo (ADR-0001).

enum Tier { RASTRO, TRILHA, LENDA }
## counter: contador >= n · distinct: chaves diferentes com o prefixo >= n · record: recorde >= n
enum Kind { COUNTER, DISTINCT, RECORD }

const TIER_NAMES: Array[String] = ["Rastro", "Trilha", "Lenda"]

@export var id: StringName
@export var chapter: StringName
@export var tier: Tier = Tier.RASTRO
@export var description: String = ""
@export var kind: Kind = Kind.COUNTER
## Chave do contador ou do recorde; prefixo para DISTINCT
@export var key: String = ""
@export var threshold: float = 1.0
## Recompensas (todas opcionais)
@export var title: String = ""
@export var card_id: StringName = &""
@export var adorno: StringName = &""
## Libera os Contratos de Mestre do Quadro (B28) deste capítulo
@export var board_access: bool = false
## Fica fora da conta até o sistema que alimenta o contador existir
@export var pending: bool = false

## Quanto falta, de 0 a 1 (para a tela do Diário)
func progress(ledger) -> float:
	return clampf(current(ledger) / threshold, 0.0, 1.0) if threshold > 0.0 else 0.0

func current(ledger) -> float:
	match kind:
		Kind.COUNTER:
			return float(ledger.count(chapter, key))
		Kind.DISTINCT:
			return float(ledger.distinct(chapter, key))
		Kind.RECORD:
			return float(ledger.record(chapter, key).get("value", 0.0))
	return 0.0

func reached(ledger) -> bool:
	return not pending and current(ledger) >= threshold
