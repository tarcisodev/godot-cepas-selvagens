class_name AbilityPhase
extends Resource

## Fases de execução de uma habilidade
enum Kind {
	WINDUP,    ## Preparação do golpe
	CHANNEL,   ## Canalização (se houver)
	RELEASE,   ## Momento do impacto/disparo da hitbox
	RECOVERY   ## Recuperação pós-golpe
}

@export var kind: Kind = Kind.WINDUP
@export var duration: float = 0.3
@export var mobility: MobilityProfile
@export var interruptible_by_poise: bool = true
@export var animation: StringName = &""
