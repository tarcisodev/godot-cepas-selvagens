class_name HitEvent
extends RefCounted

## Evento atômico de golpe conforme ADR-0003
## Contém todos os dados brutos antes de passar pelo CombatResolver.

var attacker: Node = null
var target: Node = null
var damage_type: DamageType.Type = DamageType.Type.IMPACT
var raw_damage: float = 0.0
var poise_damage: float = 0.0
var part_break_damage: float = 0.0
var part_id: StringName = &""           ## Zona ou parte anatômica atingida (ex: "horn", "tail", "body")
var is_critical: bool = false
var hit_position: Vector3 = Vector3.ZERO
var hit_normal: Vector3 = Vector3.UP

func _init(
	p_attacker: Node = null,
	p_target: Node = null,
	p_damage: float = 0.0,
	p_type: DamageType.Type = DamageType.Type.IMPACT,
	p_poise: float = 0.0,
	p_part_id: StringName = &""
) -> void:
	attacker = p_attacker
	target = p_target
	raw_damage = p_damage
	damage_type = p_type
	poise_damage = p_poise
	part_id = p_part_id
