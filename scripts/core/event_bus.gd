class_name EventBusAutoload
extends Node

## Barramento global de eventos do jogo (ADR-0003 e GDD-01 §1).
## Permite desacoplar combate, maestria, áudio, HUD e IA.

signal hit_resolved(hit_event: HitEvent, final_damage: float, is_part_broken: bool)
signal poise_broken(target: Node)
signal poise_recovered(target: Node)
signal part_broken(target: Node, part_id: StringName)
signal entity_defeated(entity: Node, killer: Node)

## Notifica resolução de acerto
func notify_hit_resolved(hit_event: HitEvent, final_damage: float, is_part_broken: bool = false) -> void:
	hit_resolved.emit(hit_event, final_damage, is_part_broken)

## Notifica quebra de postura
func notify_poise_broken(target: Node) -> void:
	poise_broken.emit(target)

## Notifica quebra de parte anatômica
func notify_part_broken(target: Node, part_id: StringName) -> void:
	part_broken.emit(target, part_id)

## Notifica derrota de entidade
func notify_entity_defeated(entity: Node, killer: Node) -> void:
	entity_defeated.emit(entity, killer)
