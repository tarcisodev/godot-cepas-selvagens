class_name HitboxComponent
extends Area3D

## Componente emissor de golpes físicos ou mágicos (ADR-0003 e GDD-01 §1).
## Ativado durante a fase RELEASE do ataque.

signal hit_landed(hurtbox: HurtboxComponent, result: Dictionary)

@export var attacker: Node
@export var damage: float = 25.0
@export var poise_damage: float = 20.0
@export var damage_type: DamageType.Type = DamageType.Type.SLASH
@export var part_break_multiplier: float = 1.2
## Entidades deste grupo não são acertadas (ex.: monstros não se ferem entre si).
@export var ignore_group: StringName = &""
## Multiplica o empurrão do golpe no alvo (CombatFeel, GDD-12 §10)
@export var knockback_mult: float = 1.0

var _hit_entities: Array[Node] = []
var _is_active: bool = false
var _active_timer: float = 0.0

func _ready() -> void:
	if attacker == null:
		attacker = get_parent()
	
	collision_layer = 0
	collision_mask = 16 # Detecta Hurtboxes (camada 5 / bit 16)
	monitoring = false
	monitorable = false
	area_entered.connect(_on_area_entered)

func _process(delta: float) -> void:
	if _is_active:
		_active_timer -= delta
		if _active_timer <= 0.0:
			deactivate()

## Ativa a hitbox por uma duração fixa (fase de impacto)
func activate(duration: float = 0.25) -> void:
	_hit_entities.clear()
	_is_active = true
	_active_timer = duration
	monitoring = true

## Ativa a hitbox com parâmetros customizados de golpe ou magia (GDD-01)
func activate_with_params(duration: float = 0.25, custom_damage: float = 25.0, custom_type: DamageType.Type = DamageType.Type.SLASH, custom_poise: float = 20.0, custom_break_mult: float = 1.2) -> void:
	damage = custom_damage
	damage_type = custom_type
	poise_damage = custom_poise
	part_break_multiplier = custom_break_mult
	activate(duration)

## Desativa a detecção de impacto
func deactivate() -> void:
	_is_active = false
	monitoring = false
	_hit_entities.clear()

func _on_area_entered(area: Area3D) -> void:
	if not _is_active or not (area is HurtboxComponent):
		return
	
	var hurtbox: HurtboxComponent = area as HurtboxComponent
	if hurtbox.entity == attacker:
		return # Evita auto-dano
	if not ignore_group.is_empty() and hurtbox.entity.is_in_group(ignore_group):
		return

	# Evita acertar a mesma entidade duas vezes no mesmo golpe
	if _hit_entities.has(hurtbox.entity):
		return
	
	_hit_entities.append(hurtbox.entity)
	
	# Constrói o evento de golpe
	var hit := HitEvent.new(
		attacker,
		hurtbox.entity,
		damage,
		damage_type,
		poise_damage,
		hurtbox.part_id
	)
	hit.part_break_damage = damage * part_break_multiplier
	hit.hit_position = global_position
	hit.knockback_mult = knockback_mult
	
	# Executa o acerto na hurtbox
	var res: Dictionary = hurtbox.receive_hit(hit)
	hit_landed.emit(hurtbox, res)
