class_name AnatomyComponent
extends Node

## Componente de anatomia para criaturas com partes quebráveis (GDD-03).
## Gerencia partes individuais (chifre, cauda, carapaça) com HP e estados de quebra próprios.

enum PartState {
	INTACT,     ## Intacto: condição perfeita (rende partes Íntegras se capturado)
	CRACKED,    ## Rachado: HP da parte abaixo de 50%
	BROKEN,     ## Quebrado: HP da parte zerado (dropa fragmento na luta)
	SEVERED,    ## Decepado: parte decepada cai no chão como coletável
	SCARRED     ## Cicatrizado: regenerou em caçadas anteriores (trait especial)
}

signal part_damaged(part_id: StringName, current_hp: float, max_hp: float)
signal part_state_changed(part_id: StringName, new_state: PartState, old_state: PartState)
signal part_broken(part_id: StringName)

## Configuração inicial de partes (id -> { max_hp, severable }) ou Array de dicionários
@export var initial_parts: Dictionary = {
	&"horn": { "max_hp": 80.0, "severable": false },
	&"carapace": { "max_hp": 150.0, "severable": false },
	&"tail": { "max_hp": 100.0, "severable": true }
}
@export var parts_config: Variant = []

var _parts: Dictionary = {}

func _ready() -> void:
	if parts_config is Array and not parts_config.is_empty():
		for item in parts_config:
			if item is Dictionary:
				var pid: StringName = item.get(&"id", item.get("id", &""))
				var hp: float = float(item.get(&"max_integrity", item.get("max_integrity", item.get("max_hp", 100.0))))
				var sev: bool = bool(item.get(&"severable", item.get("severable", false)))
				register_part(pid, hp, sev)
	else:
		for part_id in initial_parts.keys():
			var cfg: Dictionary = initial_parts[part_id]
			register_part(part_id, float(cfg.get("max_hp", 100.0)), bool(cfg.get("severable", false)))

## Registra uma parte anatômica
func register_part(part_id: StringName, max_hp: float, severable: bool = false) -> void:
	_parts[part_id] = {
		&"max_hp": max_hp,
		&"current_hp": max_hp,
		&"state": PartState.INTACT,
		&"severable": severable
	}

## Retorna a integridade / HP atual da parte
func get_part_integrity(part_id: StringName) -> float:
	if _parts.has(part_id):
		return _parts[part_id][&"current_hp"]
	return 0.0

## Aplica dano a uma parte específica. Retorna true se a parte quebrou neste golpe.
func damage_part(part_id: StringName, amount: float) -> bool:
	if not _parts.has(part_id):
		return false
	
	var part: Dictionary = _parts[part_id]
	var current_state: PartState = part[&"state"]
	
	# Se já está quebrada ou decepada, não quebra novamente
	if current_state == PartState.BROKEN or current_state == PartState.SEVERED:
		return false
	
	var old_hp: float = part[&"current_hp"]
	var new_hp: float = maxf(old_hp - amount, 0.0)
	part[&"current_hp"] = new_hp
	part_damaged.emit(part_id, new_hp, part[&"max_hp"])
	
	# Transição para rachado se cair abaixo de 50%
	if new_hp > 0.0 and new_hp <= (part[&"max_hp"] * 0.5) and current_state == PartState.INTACT:
		part[&"state"] = PartState.CRACKED
		part_state_changed.emit(part_id, PartState.CRACKED, current_state)
	
	# Quebra ou decepamento se zerar o HP
	if new_hp <= 0.0:
		var target_state: PartState = PartState.SEVERED if part[&"severable"] else PartState.BROKEN
		part[&"state"] = target_state
		part_state_changed.emit(part_id, target_state, current_state)
		part_broken.emit(part_id)
		
		if is_inside_tree():
			var eb: Node = get_node_or_null("/root/EventBus")
			if eb != null and eb.has_method("notify_part_broken"):
				eb.notify_part_broken(get_parent(), part_id)
		
		return true
	
	return false

## Retorna o estado atual de uma parte
func get_part_state(part_id: StringName) -> PartState:
	if _parts.has(part_id):
		return _parts[part_id][&"state"]
	return PartState.INTACT

## Verifica se uma parte está intacta
func is_part_intact(part_id: StringName) -> bool:
	return get_part_state(part_id) == PartState.INTACT

## Retorna o HP atual de uma parte
func get_part_hp(part_id: StringName) -> float:
	if _parts.has(part_id):
		return _parts[part_id][&"current_hp"]
	return 0.0

## Verifica se uma parte está quebrada ou decepada
func is_part_broken(part_id: StringName) -> bool:
	var state: PartState = get_part_state(part_id)
	return state == PartState.BROKEN or state == PartState.SEVERED
