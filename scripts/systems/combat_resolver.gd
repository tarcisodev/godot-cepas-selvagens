class_name CombatResolver
extends RefCounted

## Pipeline autoritativo de resolução de combate (ADR-0002 e ADR-0003).
## Resolve o dano mitigado, quebra de postura e dano a partes anatômicas.

## Bônus das Técnicas de quem bate (0 sem maestria ou sem Técnica)
static func _technique(attacker: Node, stat: StringName) -> float:
	if stat.is_empty() or attacker == null or not is_instance_valid(attacker):
		return 0.0
	var m = attacker.get("mastery")
	return m.technique_bonus(stat) if m != null and m.has_method("technique_bonus") else 0.0

static func _damage_stat(t: DamageType.Type) -> StringName:
	match t:
		DamageType.Type.SLASH:
			return &"dmg_slash"
		DamageType.Type.IMPACT:
			return &"dmg_impact"
		DamageType.Type.FIRE, DamageType.Type.EARTH, DamageType.Type.LIGHTNING:
			return &"dmg_magic"
	return &""

static func resolve_hit(hit: HitEvent) -> Dictionary:
	var result := {
		&"success": false,
		&"effective_damage": 0.0,
		&"mitigated_amount": 0.0,
		&"poise_broken": false,
		&"part_broken": false,
		&"target_defeated": false
	}
	
	if hit == null or hit.target == null:
		return result
	
	var target_stats: StatsComponent = hit.target.get_node_or_null("StatsComponent") as StatsComponent
	var target_pools: PoolsComponent = hit.target.get_node_or_null("PoolsComponent") as PoolsComponent
	
	if target_pools == null:
		return result

	# Bloqueio, i-frames da esquiva e afins: o alvo ajusta o golpe antes da mitigação
	if hit.target.has_method("filter_incoming_hit"):
		hit.target.filter_incoming_hit(hit)

	# 1. Cálculo de Resistência / Mitigação por tipo de dano
	# Técnicas do atacante (B38): bônus de dano pelo tipo, ensinados pelos mestres
	var raw_dmg: float = hit.raw_damage * (1.0 + _technique(hit.attacker, _damage_stat(hit.damage_type)))
	var resist_stat: StringName = StringName("resist_" + DamageType.to_string_name(hit.damage_type))
	var resistance: float = 0.0
	
	if target_stats != null:
		# Resistência é um percentual (ex: 0.25 = 25% de redução)
		resistance = clampf(target_stats.get_stat(resist_stat), -1.0, 0.90)
	
	var effective_damage: float = maxf(raw_dmg * (1.0 - resistance), 0.0)
	var mitigated: float = raw_dmg - effective_damage
	
	# 2. Aplicação do dano na vida
	var dealt_damage: float = target_pools.take_damage(effective_damage)
	
	# 3. Aplicação do dano de postura
	var poise_dmg: float = hit.poise_damage * (1.0 + _technique(hit.attacker, &"poise"))
	if target_stats != null:
		var poise_resist: float = clampf(target_stats.get_stat(&"poise_resist"), 0.0, 0.90)
		poise_dmg *= (1.0 - poise_resist)
	
	var broke_poise: bool = target_pools.damage_poise(poise_dmg)
	
	# 4. Quebra de parte anatômica (se a parte for especificada)
	var broke_part := false
	var part_dmg: float = (hit.part_break_damage if hit.part_break_damage > 0.0 else dealt_damage) * (1.0 + _technique(hit.attacker, &"part_break"))
	if not hit.part_id.is_empty():
		if hit.target.has_method("damage_part"):
			broke_part = hit.target.damage_part(hit.part_id, part_dmg)
		else:
			var anatomy: AnatomyComponent = hit.target.get_node_or_null("AnatomyComponent") as AnatomyComponent
			if anatomy != null:
				broke_part = anatomy.damage_part(hit.part_id, part_dmg)
	
	# 5. Preencher resultado
	result[&"success"] = true
	result[&"effective_damage"] = dealt_damage
	result[&"mitigated_amount"] = mitigated
	result[&"poise_broken"] = broke_poise
	result[&"part_broken"] = broke_part
	result[&"target_defeated"] = target_pools.current_health <= 0.0
	
	# 6. Notificar EventBus (se disponível na árvore)
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree != null and tree.root.has_node("EventBus"):
		var event_bus: EventBusAutoload = tree.root.get_node("EventBus") as EventBusAutoload
		if event_bus != null:
			event_bus.notify_hit_resolved(hit, dealt_damage, broke_part)
			if broke_poise:
				event_bus.notify_poise_broken(hit.target)
			if broke_part:
				event_bus.notify_part_broken(hit.target, hit.part_id)
			if result[&"target_defeated"]:
				event_bus.notify_entity_defeated(hit.target, hit.attacker)
	
	return result
