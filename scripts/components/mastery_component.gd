class_name MasteryComponent
extends Node

## Componente de Maestria e Progressão por Uso (GDD-02 e B03).
## Escuta sinais de combate e atribui XP a tags específicas sem nível global de personagem.

signal xp_gained(tag: StringName, amount: float, current_level: int, current_xp: float, needed_xp: float)
signal level_up(tag: StringName, new_level: int)

@export var initial_tags: Array[StringName] = [&"lâmina", &"canalização", &"armadura_media", &"forja", &"esfola"]

# Estrutura: tag -> { "level": int, "xp": float }
var _masteries: Dictionary = {}

func _ready() -> void:
	for tag in initial_tags:
		if not _masteries.has(tag):
			_masteries[tag] = { "level": 1, "xp": 0.0 }
	
	if is_inside_tree():
		var eb: Node = get_node_or_null("/root/EventBus")
		if eb != null and eb.has_signal("hit_resolved"):
			eb.hit_resolved.connect(_on_hit_resolved)

## Retorna o XP necessário para alcançar o próximo nível
static func get_xp_for_next_level(level: int) -> float:
	# Curva suave no início e exponencial depois (GDD-02 §4)
	return 40.0 * pow(1.12, level - 1)

## Adiciona XP a uma tag de maestria
func add_xp(tag: StringName, amount: float) -> void:
	if amount <= 0.0:
		return
	
	if not _masteries.has(tag):
		_masteries[tag] = { "level": 1, "xp": 0.0 }
	
	var data: Dictionary = _masteries[tag]
	var current_level: int = data["level"]
	var current_xp: float = data["xp"] + amount
	var needed_xp: float = get_xp_for_next_level(current_level)
	
	var leveled: bool = false
	while current_xp >= needed_xp and current_level < 100:
		current_xp -= needed_xp
		current_level += 1
		leveled = true
		needed_xp = get_xp_for_next_level(current_level)
		level_up.emit(tag, current_level)
	
	data["level"] = current_level
	data["xp"] = current_xp
	xp_gained.emit(tag, amount, current_level, current_xp, needed_xp)

## Retorna o nível atual de uma tag
func get_level(tag: StringName) -> int:
	if _masteries.has(tag):
		return _masteries[tag]["level"]
	return 1

## Retorna o XP atual de uma tag
func get_xp(tag: StringName) -> float:
	if _masteries.has(tag):
		return _masteries[tag]["xp"]
	return 0.0

## Listener do EventBus de combate
func _on_hit_resolved(hit_event: HitEvent, effective_damage: float, is_part_broken: bool) -> void:
	var parent: Node = get_parent()
	if hit_event == null or parent == null:
		return
	
	# XP ofensivo: se fomos o atacante
	if hit_event.attacker == parent and effective_damage > 0.0:
		var bonus_broken: float = 1.5 if is_part_broken else 1.0
		var xp_amount: float = (effective_damage * 0.5) * bonus_broken
		
		if hit_event.damage_type == DamageType.Type.SLASH:
			add_xp(&"lâmina", xp_amount)
		elif hit_event.damage_type == DamageType.Type.FIRE or hit_event.damage_type == DamageType.Type.EARTH:
			add_xp(&"canalização", xp_amount)
	
	# XP defensivo: se fomos o alvo e mitigamos dano
	elif hit_event.target == parent:
		var mitigated: float = hit_event.raw_damage - effective_damage
		if mitigated > 0.0:
			add_xp(&"armadura_media", mitigated * 0.6)
