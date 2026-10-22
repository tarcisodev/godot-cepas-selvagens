class_name StatsComponent
extends Node

## Componente de atributos baseado puramente em pilha de modificadores (ADR-0001, ADR-0003 e GDD-01 §3).
## Sem atributos primários (FOR/AGI/INT). O poder vem do cálculo dos modificadores.

signal stat_changed(stat_name: StringName, new_value: float, old_value: float)

## Valores base padrão configuráveis pelo Inspector ou código
@export var default_base_stats: Dictionary = {
	&"max_health": 100.0,
	&"max_ether": 100.0,
	&"max_vigor": 100.0,
	&"max_poise": 50.0,
	&"health_regen": 0.0,
	&"ether_regen": 2.0,
	&"vigor_regen": 25.0,
	&"poise_regen": 10.0,
	&"move_speed": 4.5,
	&"dodge_cost": 25.0,
	&"cast_mobility": 1.0,
	&"load_capacity": 50.0,
	&"poise_resist": 0.0,
}

var _base_stats: Dictionary = {}
var _modifiers: Dictionary = {}        # StringName -> Array[ModifierData]
var _cached_values: Dictionary = {}    # StringName -> float
var _dirty: Dictionary = {}            # StringName -> bool

func _init() -> void:
	_init_defaults()

func _ready() -> void:
	_init_defaults()

func _init_defaults() -> void:
	for stat_name in default_base_stats.keys():
		if not _base_stats.has(stat_name):
			_base_stats[stat_name] = float(default_base_stats[stat_name])
			_dirty[stat_name] = true

## Define o valor base de um stat
func set_base_stat(stat_name: StringName, value: float) -> void:
	var old_val: float = get_stat(stat_name)
	_base_stats[stat_name] = value
	_dirty[stat_name] = true
	var new_val: float = get_stat(stat_name)
	if not is_equal_approx(old_val, new_val):
		stat_changed.emit(stat_name, new_val, old_val)

## Retorna o valor base sem modificadores
func get_base_stat(stat_name: StringName) -> float:
	return _base_stats.get(stat_name, 0.0)

## Adiciona um modificador à pilha
func add_modifier(modifier: ModifierData) -> void:
	if modifier == null or modifier.stat.is_empty():
		return
	
	if not _modifiers.has(modifier.stat):
		_modifiers[modifier.stat] = []
	
	var old_val: float = get_stat(modifier.stat)
	_modifiers[modifier.stat].append(modifier)
	_dirty[modifier.stat] = true
	
	var new_val: float = get_stat(modifier.stat)
	if not is_equal_approx(old_val, new_val):
		stat_changed.emit(modifier.stat, new_val, old_val)

## Remove um modificador específico
func remove_modifier(modifier: ModifierData) -> void:
	if modifier == null or not _modifiers.has(modifier.stat):
		return
	
	var list: Array = _modifiers[modifier.stat]
	var idx: int = list.find(modifier)
	if idx != -1:
		var old_val: float = get_stat(modifier.stat)
		list.remove_at(idx)
		_dirty[modifier.stat] = true
		var new_val: float = get_stat(modifier.stat)
		if not is_equal_approx(old_val, new_val):
			stat_changed.emit(modifier.stat, new_val, old_val)

## Remove todos os modificadores originados de uma mesma fonte (ex: desequipar item)
func remove_modifiers_from_source(source: Object) -> void:
	if source == null:
		return
	
	var stats_to_recalc: Array[StringName] = []
	
	for stat_name in _modifiers.keys():
		var list: Array = _modifiers[stat_name]
		var modified := false
		for i in range(list.size() - 1, -1, -1):
			var mod: ModifierData = list[i]
			if mod.source == source:
				list.remove_at(i)
				modified = true
		if modified:
			stats_to_recalc.append(stat_name)
	
	for stat_name in stats_to_recalc:
		var old_val: float = _cached_values.get(stat_name, _base_stats.get(stat_name, 0.0))
		_dirty[stat_name] = true
		var new_val: float = get_stat(stat_name)
		if not is_equal_approx(old_val, new_val):
			stat_changed.emit(stat_name, new_val, old_val)

## Retorna o valor final computado do stat, usando cache
func get_stat(stat_name: StringName) -> float:
	if not _dirty.get(stat_name, true):
		return _cached_values.get(stat_name, 0.0)
	
	var base: float = _base_stats.get(stat_name, 0.0)
	var sum_flat: float = 0.0
	var sum_pct_add: float = 0.0
	var prod_pct_mult: float = 1.0
	
	if _modifiers.has(stat_name):
		for mod in _modifiers[stat_name]:
			if mod is ModifierData:
				match mod.op:
					ModifierData.Op.FLAT:
						sum_flat += mod.value
					ModifierData.Op.PCT_ADD:
						sum_pct_add += mod.value
					ModifierData.Op.PCT_MULT:
						prod_pct_mult *= (1.0 + mod.value)
	
	# Fórmula oficial: (base + sum_flat) * (1 + sum_pct_add) * prod_pct_mult
	var final_val: float = (base + sum_flat) * (1.0 + sum_pct_add) * prod_pct_mult
	_cached_values[stat_name] = final_val
	_dirty[stat_name] = false
	return final_val
