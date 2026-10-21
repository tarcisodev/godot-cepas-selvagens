class_name AbilityData
extends Resource

## Definição de habilidade/golpe com fases sequenciais
@export var id: StringName = &""
@export var display_name: String = ""
@export var phases: Array[AbilityPhase] = []
@export var vigor_cost: float = 0.0
@export var ether_cost: float = 0.0
@export var damage_type: DamageType.Type = DamageType.Type.SLASH
@export var base_damage: float = 10.0
@export var poise_damage: float = 15.0
@export var part_break_multiplier: float = 1.0
