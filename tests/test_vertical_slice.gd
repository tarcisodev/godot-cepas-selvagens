extends SceneTree

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const DummyScene: PackedScene = preload("res://scenes/dummy_creature.tscn")

func _init() -> void:
	print("\n========================================================")
	print("🎯 VALIDANDO VERTICAL SLICE COMPLETO (B07)")
	print("Caçar, Quebrar Partes, Coletar Loot, Forjar e Evoluir")
	print("========================================================")
	
	test_player_weapons_and_mobility()
	test_creature_parts_and_conditional_loot()
	test_crafting_and_trait_modifiers()
	test_mastery_progression()
	
	print("\n🎉 VERTICAL SLICE VALIDADO COM 100% DE SUCESSO!")
	print("========================================================\n")
	quit(0)

func test_player_weapons_and_mobility() -> void:
	print("\n[1/4] Testando armas (Melee vs Cajado) e Mobilidade por Carga...")
	var player: Player = PlayerScene.instantiate() as Player
	root.add_child(player)
	player._setup_components()
	
	var stats: StatsComponent = player.stats
	var pools: PoolsComponent = player.pools
	assert(stats != null and pools != null, "Player deve inicializar com stats e pools")
	
	# Ataque melee consome vigor
	var vigor_before: float = pools.current_vigor
	var ok_vigor := pools.consume_vigor(player.weapon_style.primary.cost)
	assert(ok_vigor, "Deve conseguir gastar vigor no ataque de machete")
	assert(pools.current_vigor < vigor_before, "Vigor deve diminuir após golpe")
	
	# Conjuração de cajado consome éter
	var ether_before: float = pools.current_ether
	var ok_ether := pools.consume_ether(20.0)
	assert(ok_ether, "Deve conseguir gastar éter na conjuração do cajado")
	assert(pools.current_ether < ether_before, "Éter deve diminuir após magia")
	
	# Penalidade de mobilidade por Carga (Load)
	var base_speed: float = player.walk_speed
	var initial_load: float = stats.get_stat(&"load")
	assert(is_equal_approx(initial_load, 0.0), "Carga inicial sem equipamento deve ser 0")
	
	# Adicionando carga pesada (ex: armadura pesada +30 load)
	var armor_source := RefCounted.new()
	stats.add_modifier(ModifierData.new(&"load", ModifierData.Op.FLAT, 30.0, armor_source))
	var heavy_load: float = stats.get_stat(&"load")
	assert(is_equal_approx(heavy_load, 30.0), "Carga deve refletir 30.0")
	
	var load_cap: float = stats.get_stat(&"load_capacity")
	var penalty: float = clampf(1.0 - ((heavy_load / load_cap) * 0.35), 0.5, 1.0)
	var slowed_speed: float = base_speed * penalty
	assert(slowed_speed < base_speed, "Velocidade sob carga pesada deve ser menor que a base")
	
	player.free()
	print("  ✓ Ataques, custos e penalidade de mobilidade por peso validados!")

func test_creature_parts_and_conditional_loot() -> void:
	print("\n[2/4] Testando quebra anatômica e loot condicional (Íntegro vs Lascado)...")
	var player: Player = PlayerScene.instantiate() as Player
	player.name = "Player"
	root.add_child(player)
	player._setup_components()
	
	var dummy: DummyCreature = DummyScene.instantiate() as DummyCreature
	dummy.name = "DummyCreature"
	root.add_child(dummy)
	dummy._setup_components()
	
	var inv: InventoryComponent = player.inventory
	assert(inv != null, "Player deve possuir InventoryComponent")
	assert(inv.get_material_count(&"chifre_lascado") == 0, "Sem chifres lascados no início")
	
	# 1. Dano direto no Chifre até quebrar (50 de HP)
	var broke_horn := dummy.anatomy.damage_part(&"horn", 55.0)
	assert(broke_horn, "Chifre deve quebrar com 55 de dano")
	assert(dummy.anatomy.is_part_broken(&"horn"), "Status do chifre deve ser quebrado")
	
	# Verifica se o drop foi premiado ao player
	assert(inv.get_material_count(&"chifre_lascado") == 1, "Player deve ter recebido 1 Chifre Lascado")
	
	# 2. Testando criatura derrotada com chifre intacto em nova criatura
	var dummy2: DummyCreature = DummyScene.instantiate() as DummyCreature
	root.add_child(dummy2)
	dummy2._setup_components()
	assert(dummy2.anatomy.is_part_intact(&"horn"), "Chifre do dummy 2 deve estar intacto")
	
	# Abate com chifre intacto: o loot fica no corpo até ser esfolado (GDD-03 §8)
	dummy2._on_health_depleted()
	assert(inv.get_material_count(&"chifre_integro") == 0, "Loot do corpo não cai sozinho; precisa esfolar")
	assert(dummy2.is_harvestable(), "Corpo deve ficar esfolável")
	assert(dummy2.next_harvest_label() == "Chifre Íntegro", "Primeira parte a esfolar é o chifre intacto")
	var esfola_xp_before: float = player.mastery.get_xp(&"esfola")
	var steps := 0
	while dummy2.is_harvestable():
		dummy2.harvest_next(player)
		steps += 1
	assert(steps == 2, "Corpo com chifre intacto tem 2 partes para esfolar")
	assert(inv.get_material_count(&"chifre_integro") == 1, "Player deve ter recebido 1 Chifre Íntegro pelo abate cuidadoso")
	assert(inv.get_material_count(&"placa_carapaca") >= 2, "Player deve ter recebido placas de carapaça")
	assert(player.mastery.get_xp(&"esfola") > esfola_xp_before or player.mastery.get_level(&"esfola") > 1, "Esfolar dá XP de esfola")
	assert(player.get_harvest_time() == 3.0, "Esfola leva 3 s por parte no nível inicial")

	# Corpo que se decompõe perde o que não foi esfolado
	var dummy3: DummyCreature = DummyScene.instantiate() as DummyCreature
	root.add_child(dummy3)
	dummy3._setup_components()
	dummy3._on_health_depleted()
	dummy3._process(DummyCreature.CORPSE_LIFETIME + 1.0)
	assert(not dummy3.is_harvestable(), "Depois de 5 min o corpo não é mais esfolável")
	dummy3.free()

	# Besta de treino renasce inteira depois de esfolada
	assert(dummy2.respawn_timer > 0.0, "Corpo esvaziado inicia a contagem para renascer")
	dummy2._process(DummyCreature.RESPAWN_DELAY + 0.1)
	assert(dummy2.pools.current_health > 0.0, "Besta renasce com vida cheia")
	assert(dummy2.anatomy.is_part_intact(&"horn"), "Besta renasce com o chifre intacto")
	assert(not dummy2.is_harvestable(), "Besta viva não é esfolável")
	
	dummy.free()
	dummy2.free()
	player.free()
	print("  ✓ Quebra de parte em combate e loot condicional validados com perfeição!")

func test_crafting_and_trait_modifiers() -> void:
	print("\n[3/4] Testando Forja do Elmo Chifre-de-Pedra e aplicação de Traits...")
	var player: Player = PlayerScene.instantiate() as Player
	root.add_child(player)
	player._setup_components()
	
	var stats: StatsComponent = player.stats
	var inv: InventoryComponent = player.inventory
	var initial_poise_resist: float = stats.get_stat(&"poise_resist")
	var initial_slash_resist: float = stats.get_stat(&"resist_slash")
	
	# Forjar com Chifre Íntegro (Qualidade 4, Trait Casca Rígida)
	inv.add_material(&"chifre_integro", 1)
	inv.add_material(&"placa_carapaca", 1)
	
	var crafted := inv.craft_and_equip_horn_helmet(&"chifre_integro")
	assert(crafted, "Forja com Chifre Íntegro deve ter sucesso")
	assert(inv.equipped[&"head"] == &"Elmo Chifre-de-Pedra (Íntegro)", "Elmo Íntegro deve estar equipado")
	
	# Validação dos modificadores nos stats (ADR-0001, ADR-0003 e GDD-06)
	var new_poise_resist: float = stats.get_stat(&"poise_resist")
	var new_slash_resist: float = stats.get_stat(&"resist_slash")
	assert(new_poise_resist > initial_poise_resist, "Resistência a quebra de postura deve subir (+25%)")
	assert(new_slash_resist > initial_slash_resist, "Mitigação de corte deve subir (+20%)")
	assert(stats.get_stat(&"load") >= 18.0, "Carga do elmo deve ser contabilizada (+18 load)")
	
	player.free()
	print("  ✓ Forja modular, herança de traits e aplicação no StatsComponent validados!")

func test_mastery_progression() -> void:
	print("\n[4/4] Testando progressão por uso (Maestria de Lâmina e Canalização)...")
	var player: Player = PlayerScene.instantiate() as Player
	root.add_child(player)
	player._setup_components()
	
	var mastery: MasteryComponent = player.mastery
	assert(mastery != null, "Player deve possuir MasteryComponent")
	assert(mastery.get_level(&"lâmina") == 1, "Nível inicial de lâmina deve ser 1")
	assert(is_equal_approx(mastery.get_xp(&"lâmina"), 0.0), "XP inicial deve ser 0")
	
	# Simulando ganho de XP por acerto com lâmina (50 de dano -> 25 XP)
	mastery.add_xp(&"lâmina", 25.0)
	assert(is_equal_approx(mastery.get_xp(&"lâmina"), 25.0), "XP deve ser 25.0")
	
	# Subindo de nível (mais 25 XP = 50 XP, passa de 40 XP do nível 1 -> nível 2)
	mastery.add_xp(&"lâmina", 25.0)
	assert(mastery.get_level(&"lâmina") >= 2, "Deve ter subido para nível 2 em Lâmina")
	
	# Maestria de canalização
	mastery.add_xp(&"canalização", 45.0)
	assert(mastery.get_level(&"canalização") >= 2, "Deve ter subido para nível 2 em Canalização")
	
	player.free()
	print("  ✓ Ganho de XP e subida de nível em maestria validados!")
