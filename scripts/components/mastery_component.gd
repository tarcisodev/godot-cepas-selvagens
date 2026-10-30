class_name MasteryComponent
extends Node

const _MasterTechniques = preload("res://scripts/costelaria/master_techniques.gd")

## Componente de Maestria e Progressão por Uso (GDD-02 e B03).
## Escuta sinais de combate e atribui XP a tags específicas sem nível global de personagem.

signal xp_gained(tag: StringName, amount: float, current_level: int, current_xp: float, needed_xp: float)
signal level_up(tag: StringName, new_level: int)

@export var initial_tags: Array[StringName] = [&"lâmina", &"canalização", &"armadura_leve", &"armadura_media", &"armadura_pesada", &"forja", &"esfola", &"coleta", &"mineracao"]

# Estrutura: tag -> { "level": int, "xp": float }
var _masteries: Dictionary = {}
## Técnicas de marco ensinadas pelos mestres (B38): tag -> [marcos]. Sem o mestre, o marco
## alcançado não libera nada (GDD-17 §5).
var techniques: Dictionary = {}
## Lições do Pátio já feitas (bônus de primeira vez): tag -> [faixas]
var lessons_done: Dictionary = {}

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

func has_technique(tag: StringName, milestone: int) -> bool:
	return techniques.get(tag, []).has(milestone)

func learn_technique(tag: StringName, milestone: int) -> void:
	if not techniques.has(tag):
		techniques[tag] = []
	if not techniques[tag].has(milestone):
		techniques[tag].append(milestone)

## Soma dos bônus das Técnicas aprendidas num stat (ver MasterTechniques)
func technique_bonus(stat: StringName) -> float:
	return _MasterTechniques.bonus(techniques, stat)

func has_lesson(tag: StringName, band: int) -> bool:
	return lessons_done.get(tag, []).has(band)

func mark_lesson(tag: StringName, band: int) -> void:
	if not lessons_done.has(tag):
		lessons_done[tag] = []
	if not lessons_done[tag].has(band):
		lessons_done[tag].append(band)

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
		
		match hit_event.damage_type:
			DamageType.Type.SLASH:
				add_xp(&"lâmina", xp_amount)
			DamageType.Type.IMPACT:
				add_xp(&"concussão", xp_amount)
			DamageType.Type.FIRE, DamageType.Type.EARTH, DamageType.Type.LIGHTNING:
				add_xp(&"canalização", xp_amount)
	
	# XP defensivo: se fomos o alvo e mitigamos dano
	elif hit_event.target == parent:
		var mitigated: float = hit_event.raw_damage - effective_damage
		if mitigated > 0.0:
			# Cada peça de armadura leva a parte dela para a maestria da sua família (GDD-12 §2);
			# sem armadura nenhuma, o XP vai para a média, como antes
			var inv: InventoryComponent = parent.get_node_or_null("InventoryComponent") as InventoryComponent
			var families: Array[StringName] = inv.armor_families() if inv else []
			if families.is_empty():
				add_xp(&"armadura_media", mitigated * 0.6)
			for f in families:
				add_xp(ForgedItem.FAMILY[f].mastery, mitigated * 0.6 / families.size())
