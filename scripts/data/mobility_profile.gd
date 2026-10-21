class_name MobilityProfile
extends Resource

## Define como o personagem pode se mover durante uma fase de habilidade (GDD-01 §4)
@export_range(0.0, 1.0) var move_mult: float = 1.0       ## 0 = enraizado, 1 = velocidade total
@export var can_rotate: bool = true
@export var can_dodge_cancel: bool = false
@export var can_jump: bool = false
@export_range(0.0, 1.0) var load_sensitivity: float = 1.0
