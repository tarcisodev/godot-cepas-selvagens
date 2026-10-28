class_name FoodBuffComponent
extends Node

const _StatsComponent = preload("res://scripts/components/stats_component.gd")
const _ModifierData = preload("res://scripts/data/modifier_data.gd")
const _MaterialData = preload("res://scripts/data/material_data.gd")

## Componente de Buffs de Refeição e Gastronomia (GDD-13 §4 e §5).
## Gerencia o buff de comida ativo no personagem. Conforme GDD-13 §5:
## "Uma refeição completa substitui a anterior (não acumula 10 buffs de comida ao mesmo tempo,
## mantendo o equilíbrio estilo Monster Hunter)."
## Respeita rigorosamente ADR-0001 e ADR-0003: todos os efeitos entram como ModifierData
## no StatsComponent associado com `source = self`.

signal food_buff_applied(buff_id: StringName, buff_name: String, duration: float, icon: String)
signal food_buff_expired()
signal food_buff_cleared()

@export var stats: _StatsComponent
var player: Node3D

## Estado atual do buff de comida
var active_buff_id: StringName = &""
var active_buff_name: String = ""
var active_buff_icon: String = "🍲"
var time_left: float = 0.0
var total_duration: float = 0.0
var current_quality: int = 1
var current_traits: Array = []

## Lista de modificadores ativos no StatsComponent originados deste componente
var _active_modifiers: Array[_ModifierData] = []

func _ready() -> void:
	if stats == null and player:
		stats = player.get("stats") as _StatsComponent

func _process(delta: float) -> void:
	if time_left > 0.0:
		time_left -= delta
		if time_left <= 0.0:
			_on_buff_timeout()

func has_buff() -> bool:
	return not active_buff_id.is_empty() and time_left > 0.0

func get_time_left() -> float:
	return maxf(time_left, 0.0)

func get_formatted_time_left() -> String:
	var total_secs: int = maxi(int(time_left), 0)
	var mins: int = total_secs / 60
	var secs: int = total_secs % 60
	return "%02d:%02d" % [mins, secs]

## Aplica um novo buff gastronômico. Substitui qualquer buff anterior.
func apply_food_buff(buff_id: StringName, duration: float, quality: int = 1, traits: Array = []) -> void:
	if buff_id.is_empty() or duration <= 0.0:
		return
	
	# Remove buff pré-existente
	clear_buff(false)
	
	active_buff_id = buff_id
	time_left = duration
	total_duration = duration
	current_quality = clampi(quality, 1, 5)
	current_traits = traits.duplicate()
	
	var buff_info := _get_buff_definitions(buff_id)
	active_buff_name = buff_info.get("name", String(buff_id).capitalize())
	active_buff_icon = buff_info.get("icon", "🍲")
	
	# Multiplicador por qualidade (1★: 1.0x, 2★: 1.1x, 3★: 1.2x, 4★: 1.35x, 5★: 1.5x)
	var q_mult: float = 1.0 + (current_quality - 1) * 0.10
	if current_quality >= 4:
		q_mult += 0.05
	if current_traits.has(&"mutante") or current_traits.has(&"iridescente"):
		q_mult += 0.10
		
	# Adiciona modificadores matemáticos no StatsComponent
	if stats:
		var raw_mods: Array = buff_info.get("modifiers", [])
		for m in raw_mods:
			var stat_name: StringName = m.get("stat", &"")
			var op: _ModifierData.Op = m.get("op", _ModifierData.Op.FLAT)
			var base_val: float = float(m.get("value", 0.0))
			var final_val: float = base_val * q_mult
			
			var mod := _ModifierData.new(stat_name, op, final_val, self)
			_active_modifiers.append(mod)
			stats.add_modifier(mod)
			
	food_buff_applied.emit(active_buff_id, active_buff_name, time_left, active_buff_icon)

## Limpa o buff atual
func clear_buff(emit_signal: bool = true) -> void:
	if stats and not _active_modifiers.is_empty():
		stats.remove_modifiers_from_source(self)
	_active_modifiers.clear()
	
	active_buff_id = &""
	active_buff_name = ""
	active_buff_icon = "🍲"
	time_left = 0.0
	total_duration = 0.0
	current_quality = 1
	current_traits.clear()
	
	if emit_signal:
		food_buff_cleared.emit()

func _on_buff_timeout() -> void:
	clear_buff(false)
	food_buff_expired.emit()

## Definições canônicas de buffs gastronômicos (GDD-13 §4)
static func _get_buff_definitions(id: StringName) -> Dictionary:
	match id:
		&"vigor_inabalavel":
			return {
				"name": "Vigor Inabalável",
				"icon": "🍲",
				"desc": "+20 Vigor máximo e -15% no custo da esquiva",
				"modifiers": [
					{"stat": &"max_vigor", "op": _ModifierData.Op.FLAT, "value": 20.0},
					{"stat": &"dodge_cost", "op": _ModifierData.Op.PCT_ADD, "value": -0.15}
				]
			}
		&"foco_mistico":
			return {
				"name": "Foco Místico",
				"icon": "🐟",
				"desc": "+30 Éter máximo e +25% de regeneração de Éter",
				"modifiers": [
					{"stat": &"max_ether", "op": _ModifierData.Op.FLAT, "value": 30.0},
					{"stat": &"ether_regen", "op": _ModifierData.Op.PCT_ADD, "value": 0.25}
				]
			}
		&"garras_afiadas":
			return {
				"name": "Garras Afiadas",
				"icon": "🥩",
				"desc": "+10% de dano e +5% de velocidade de movimento",
				"modifiers": [
					{"stat": &"damage_bonus", "op": _ModifierData.Op.PCT_ADD, "value": 0.10},
					{"stat": &"move_speed_bonus", "op": _ModifierData.Op.PCT_ADD, "value": 0.05}
				]
			}
		&"postura_de_pedra":
			return {
				"name": "Postura de Pedra",
				"icon": "🥣",
				"desc": "+25 de Postura máxima e +15% de recuperação de postura",
				"modifiers": [
					{"stat": &"max_poise", "op": _ModifierData.Op.FLAT, "value": 25.0},
					{"stat": &"poise_regen", "op": _ModifierData.Op.PCT_ADD, "value": 0.15}
				]
			}
		&"passo_leve":
			return {
				"name": "Passo Leve",
				"icon": "🥪",
				"desc": "+15 kg de capacidade de carga e +10% de velocidade de corrida",
				"modifiers": [
					{"stat": &"load_capacity", "op": _ModifierData.Op.FLAT, "value": 15.0},
					{"stat": &"move_speed_bonus", "op": _ModifierData.Op.PCT_ADD, "value": 0.10}
				]
			}
		&"bem_alimentado":
			return {
				"name": "Bem Alimentado",
				"icon": "🍖",
				"desc": "+15% de regeneração de Vigor",
				"modifiers": [
					{"stat": &"vigor_regen", "op": _ModifierData.Op.PCT_ADD, "value": 0.15}
				]
			}
		&"nutricao_basica":
			return {
				"name": "Nutrição Básica",
				"icon": "🍲",
				"desc": "+10 Vigor máximo e +10% de regeneração de Vigor",
				"modifiers": [
					{"stat": &"max_vigor", "op": _ModifierData.Op.FLAT, "value": 10.0},
					{"stat": &"vigor_regen", "op": _ModifierData.Op.PCT_ADD, "value": 0.10}
				]
			}
		_:
			return {
				"name": String(id).capitalize(),
				"icon": "🍲",
				"desc": "Alimentado pelo vale",
				"modifiers": []
			}
