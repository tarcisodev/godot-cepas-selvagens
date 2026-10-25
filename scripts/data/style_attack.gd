class_name StyleAttack
extends Resource

const _DamageType = preload("res://scripts/data/damage_type.gd")

## Um dos 2 básicos de um estilo de batalha (clique esq./dir., GDD-01 §8).
## Preparação (hit_delay) → golpe ativo (active_time) → recuperação até `duration`.

enum Kind {
	MELEE,       ## Hitbox na frente do corpo
	LUNGE,       ## Hitbox na frente + avanço durante o golpe
	PROJECTILE,  ## Dispara um projétil na direção em que o corpo olha
	AREA,        ## Explosão em volta do ponto à frente
	BLOCK,       ## Segurar o botão: bloqueio frontal que gasta Vigor
	AIM          ## Segurar o botão: entra em modo de mira com retícula over-the-shoulder
}

@export var kind: Kind = Kind.MELEE
@export var display_name: String = ""
## Animações em sequência; golpes seguidos dentro da janela de combo avançam a lista.
@export var anims: Array[StringName] = []
@export var duration: float = 0.35
@export var hit_delay: float = 0.0
@export var active_time: float = 0.2

@export_group("Dano")
@export var damage: float = 20.0
@export var damage_type: DamageType.Type = DamageType.Type.SLASH
@export var poise_damage: float = 10.0
@export var break_mult: float = 1.0
## Alcance do projétil (m/s) ou raio da área (m).
@export var reach: float = 2.5

@export_group("Custo e mobilidade")
## &"vigor" ou &"ether"
@export var cost_pool: StringName = &"vigor"
@export var cost: float = 10.0
## Multiplicador da velocidade de andar durante o golpe (0 = enraizado).
@export_range(0.0, 1.0) var move_mult: float = 0.4
## Velocidade do avanço (só LUNGE).
@export var lunge_speed: float = 0.0
