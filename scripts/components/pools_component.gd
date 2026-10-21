class_name PoolsComponent
extends Node

## Gerencia os 4 recursos dinâmicos (Vida, Éter, Vigor, Postura) conforme GDD-01 §2 e §3.
## Lê os tetos e regenerações a partir do StatsComponent.

signal health_changed(current: float, max_val: float)
signal ether_changed(current: float, max_val: float)
signal vigor_changed(current: float, max_val: float)
signal poise_changed(current: float, max_val: float)

signal health_depleted()
signal poise_broken()
signal poise_recovered()

@export var stats: StatsComponent

var current_health: float = 100.0
var current_ether: float = 100.0
var current_vigor: float = 100.0
var current_poise: float = 50.0

var is_poise_broken: bool = false
var _poise_break_timer: float = 0.0
var _vigor_regen_delay_timer: float = 0.0

const VIGOR_REGEN_DELAY: float = 0.8       ## Tempo após gastar vigor antes de começar a regenerar
const POISE_BREAK_DURATION: float = 3.0   ## Tempo atordoado após quebra de postura

func _ready() -> void:
	if stats == null:
		stats = get_node_or_null("../StatsComponent") as StatsComponent
	
	if stats != null:
		stats.stat_changed.connect(_on_stat_changed)
		reset_all()

func reset_all() -> void:
	if stats == null:
		return
	current_health = stats.get_stat(&"max_health")
	current_ether = stats.get_stat(&"max_ether")
	current_vigor = stats.get_stat(&"max_vigor")
	current_poise = stats.get_stat(&"max_poise")
	is_poise_broken = false
	
	health_changed.emit(current_health, stats.get_stat(&"max_health"))
	ether_changed.emit(current_ether, stats.get_stat(&"max_ether"))
	vigor_changed.emit(current_vigor, stats.get_stat(&"max_vigor"))
	poise_changed.emit(current_poise, stats.get_stat(&"max_poise"))

func _process(delta: float) -> void:
	if stats == null:
		return
	
	# 1. Regeneração de Vigor
	if _vigor_regen_delay_timer > 0.0:
		_vigor_regen_delay_timer -= delta
	else:
		var max_v: float = stats.get_stat(&"max_vigor")
		if current_vigor < max_v:
			var regen: float = stats.get_stat(&"vigor_regen") * delta
			current_vigor = minf(current_vigor + regen, max_v)
			vigor_changed.emit(current_vigor, max_v)
	
	# 2. Regeneração de Éter contínua
	var max_e: float = stats.get_stat(&"max_ether")
	if current_ether < max_e:
		var regen_e: float = stats.get_stat(&"ether_regen") * delta
		current_ether = minf(current_ether + regen_e, max_e)
		ether_changed.emit(current_ether, max_e)
	
	# 3. Postura quebrada ou regenerando
	var max_p: float = stats.get_stat(&"max_poise")
	if is_poise_broken:
		_poise_break_timer -= delta
		if _poise_break_timer <= 0.0:
			is_poise_broken = false
			current_poise = max_p
			poise_recovered.emit()
			poise_changed.emit(current_poise, max_p)
	else:
		if current_poise < max_p:
			var regen_p: float = stats.get_stat(&"poise_regen") * delta
			current_poise = minf(current_poise + regen_p, max_p)
			poise_changed.emit(current_poise, max_p)

## Consome vigor se houver saldo suficiente
func consume_vigor(amount: float) -> bool:
	if current_vigor < amount:
		return false
	current_vigor -= amount
	_vigor_regen_delay_timer = VIGOR_REGEN_DELAY
	vigor_changed.emit(current_vigor, stats.get_stat(&"max_vigor"))
	return true

## Consome éter se houver saldo suficiente
func consume_ether(amount: float) -> bool:
	if current_ether < amount:
		return false
	current_ether -= amount
	ether_changed.emit(current_ether, stats.get_stat(&"max_ether"))
	return true

## Aplica dano à vida
func take_damage(amount: float) -> float:
	if amount <= 0.0 or current_health <= 0.0:
		return 0.0
	
	var effective_damage: float = minf(amount, current_health)
	current_health -= effective_damage
	health_changed.emit(current_health, stats.get_stat(&"max_health"))
	
	if current_health <= 0.0:
		health_depleted.emit()
	
	return effective_damage

## Aplica dano à postura
func damage_poise(amount: float) -> bool:
	if is_poise_broken or amount <= 0.0:
		return false
	
	current_poise = maxf(current_poise - amount, 0.0)
	poise_changed.emit(current_poise, stats.get_stat(&"max_poise"))
	
	if current_poise <= 0.0:
		is_poise_broken = true
		_poise_break_timer = POISE_BREAK_DURATION
		poise_broken.emit()
		return true
	
	return false

## Cura vida
func heal(amount: float) -> float:
	if amount <= 0.0 or current_health <= 0.0:
		return 0.0
	var max_h: float = stats.get_stat(&"max_health")
	var healed: float = minf(amount, max_h - current_health)
	current_health += healed
	health_changed.emit(current_health, max_h)
	return healed

func _on_stat_changed(stat_name: StringName, new_val: float, _old_val: float) -> void:
	match stat_name:
		&"max_health":
			current_health = minf(current_health, new_val)
			health_changed.emit(current_health, new_val)
		&"max_ether":
			current_ether = minf(current_ether, new_val)
			ether_changed.emit(current_ether, new_val)
		&"max_vigor":
			current_vigor = minf(current_vigor, new_val)
			vigor_changed.emit(current_vigor, new_val)
		&"max_poise":
			current_poise = minf(current_poise, new_val)
			poise_changed.emit(current_poise, new_val)
