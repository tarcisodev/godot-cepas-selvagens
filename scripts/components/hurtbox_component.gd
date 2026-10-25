class_name HurtboxComponent
extends Area3D

## Componente receptor de golpes (ADR-0003 e GDD-01 §1).
## Representa uma zona do corpo de uma entidade ou uma parte anatômica específica.

signal hit_received(hit_event: HitEvent, effective_damage: float)

@export var entity: Node                     ## Entidade dona desta hurtbox (Player, Monstro, Dummy)
@export var part_id: StringName = &"body"    ## Identificador da parte anatômica (ex: "horn", "body", "tail")
@export var damage_multiplier: float = 1.0   ## Multiplicador de vulnerabilidade desta zona

func _ready() -> void:
	if entity == null:
		entity = get_parent()
	
	# Hurtboxes ficam na camada 5 (bit 16) por padrão para colisão com Hitboxes
	collision_layer = 16
	collision_mask = 0

## Chamado pela Hitbox quando um golpe acerta esta hurtbox
func receive_hit(hit: HitEvent) -> Dictionary:
	if entity == null:
		return {}
	
	# Atribui o alvo e a parte anatômica atingida ao HitEvent
	hit.target = entity
	hit.part_id = part_id
	hit.raw_damage *= damage_multiplier
	
	# Resolve o dano no CombatResolver
	var result: Dictionary = CombatResolver.resolve_hit(hit)
	
	if result.get(&"success", false):
		hit_received.emit(hit, result.get(&"effective_damage", 0.0))
		
		# Feedback visual na entidade, se suportado
		if entity.has_method("on_hit_feedback"):
			entity.on_hit_feedback(hit, result)
		CombatFeel.on_hit(hit, result)
	
	return result
