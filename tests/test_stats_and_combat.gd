extends SceneTree

func _init() -> void:
	print("\n==========================================")
	print("🧪 INICIANDO TESTES DO SISTEMA DE STATS E COMBATE")
	print("==========================================")
	
	test_stats_modifiers_formula()
	test_pools_behavior()
	test_combat_resolution()
	
	print("\n🎉 TODOS OS TESTES PASSARAM COM SUCESSO!")
	print("==========================================\n")
	quit(0)

func test_stats_modifiers_formula() -> void:
	print("\n[1/3] Testando fórmula de Stats e Modificadores...")
	var stats := StatsComponent.new()
	stats.set_base_stat(&"max_health", 100.0)
	
	# Valor base sem modificadores
	assert(is_equal_approx(stats.get_stat(&"max_health"), 100.0), "Base deve ser 100")
	
	# Adicionando FLAT (+20) -> 120
	var item_source := RefCounted.new()
	var mod_flat := ModifierData.new(&"max_health", ModifierData.Op.FLAT, 20.0, item_source)
	stats.add_modifier(mod_flat)
	assert(is_equal_approx(stats.get_stat(&"max_health"), 120.0), "Base 100 + Flat 20 deve dar 120")
	
	# Adicionando PCT_ADD (+10% e +15% = +25%) -> 120 * 1.25 = 150
	var mod_pct1 := ModifierData.new(&"max_health", ModifierData.Op.PCT_ADD, 0.10, item_source)
	var buff_source := RefCounted.new()
	var mod_pct2 := ModifierData.new(&"max_health", ModifierData.Op.PCT_ADD, 0.15, buff_source)
	stats.add_modifier(mod_pct1)
	stats.add_modifier(mod_pct2)
	assert(is_equal_approx(stats.get_stat(&"max_health"), 150.0), "(100 + 20) * (1 + 0.25) deve dar 150")
	
	# Adicionando PCT_MULT (+20% multiplicativo) -> 150 * 1.20 = 180
	var mod_mult := ModifierData.new(&"max_health", ModifierData.Op.PCT_MULT, 0.20, buff_source)
	stats.add_modifier(mod_mult)
	assert(is_equal_approx(stats.get_stat(&"max_health"), 180.0), "150 * 1.20 deve dar 180")
	
	# Removendo modificadores da fonte 'item_source' (Flat 20 e PCT1 10%)
	# Resta: base 100, PCT_ADD 15%, PCT_MULT 20% -> 100 * 1.15 * 1.20 = 138.0
	stats.remove_modifiers_from_source(item_source)
	assert(is_equal_approx(stats.get_stat(&"max_health"), 138.0), "Após remover item, deve ser 138")
	
	stats.free()
	print("  ✓ Cálculo da pilha de modificadores verificado com precisão!")

func test_pools_behavior() -> void:
	print("\n[2/3] Testando comportamento dos Pools (Vida, Vigor, Postura)...")
	var root := Node.new()
	var stats := StatsComponent.new()
	stats.name = "StatsComponent"
	root.add_child(stats)
	
	var pools := PoolsComponent.new()
	pools.name = "PoolsComponent"
	pools.stats = stats
	root.add_child(pools)
	
	# Inicialização
	pools.reset_all()
	assert(is_equal_approx(pools.current_health, 100.0), "Vida inicial deve ser 100")
	assert(is_equal_approx(pools.current_vigor, 100.0), "Vigor inicial deve ser 100")
	assert(is_equal_approx(pools.current_poise, 50.0), "Postura inicial deve ser 50")
	
	# Consumo de Vigor
	var ok_vigor := pools.consume_vigor(30.0)
	assert(ok_vigor, "Deve conseguir gastar 30 de vigor")
	assert(is_equal_approx(pools.current_vigor, 70.0), "Vigor deve ser 70")
	
	var fail_vigor := pools.consume_vigor(80.0)
	assert(not fail_vigor, "Não deve conseguir gastar mais vigor do que possui")
	assert(is_equal_approx(pools.current_vigor, 70.0), "Vigor continua 70")
	
	# Dano à Postura
	var broke := pools.damage_poise(30.0)
	assert(not broke, "30 de dano em 50 de postura não quebra")
	assert(is_equal_approx(pools.current_poise, 20.0), "Postura restante deve ser 20")
	
	broke = pools.damage_poise(25.0)
	assert(broke, "Mais 25 de dano zera a postura e quebra")
	assert(pools.is_poise_broken, "Estado de postura quebrada deve ser verdadeiro")
	
	root.free()
	print("  ✓ Pools e transições de estado validados com sucesso!")

func test_combat_resolution() -> void:
	print("\n[3/3] Testando CombatResolver com mitigação e resistências...")
	var target := Node.new()
	var stats := StatsComponent.new()
	stats.name = "StatsComponent"
	target.add_child(stats)
	
	var pools := PoolsComponent.new()
	pools.name = "PoolsComponent"
	pools.stats = stats
	target.add_child(pools)
	pools.reset_all()
	
	# Adicionando 25% de resistência a Cortante (resist_slash = 0.25)
	var armor := RefCounted.new()
	stats.add_modifier(ModifierData.new(&"resist_slash", ModifierData.Op.FLAT, 0.25, armor))
	
	# Ataque de 40 de dano cortante e 20 de dano de postura
	var hit := HitEvent.new(null, target, 40.0, DamageType.Type.SLASH, 20.0)
	var res: Dictionary = CombatResolver.resolve_hit(hit)
	
	# 40 * (1 - 0.25) = 30 de dano efetivo, 10 mitigado
	assert(res[&"success"], "Hit deve ser resolvido")
	assert(is_equal_approx(res[&"effective_damage"], 30.0), "Dano efetivo deve ser 30 (40 - 25%)")
	assert(is_equal_approx(res[&"mitigated_amount"], 10.0), "Mitigação deve ser 10")
	assert(is_equal_approx(pools.current_health, 70.0), "Vida do alvo deve cair de 100 para 70")
	assert(is_equal_approx(pools.current_poise, 30.0), "Postura do alvo deve cair de 50 para 30")
	
	target.free()
	print("  ✓ CombatResolver e cálculo de resistência validados!")
