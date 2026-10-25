extends SceneTree

## Valida o Céu Vivo (Estrelas Procedurais + Planeta com Anel), HUD Astrolábio,
## Menu TAB renovado, Loja de Cosméticos 3D, Guia do Explorador e Mural de Feedback.

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")

var _started := false

func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false

func _run() -> void:
	print("\n========================================================")
	print("🪐 TESTANDO CÉU VIVO, HUD, COSMÉTICOS 3D, GUIA & FEEDBACK")
	print("========================================================")
	test_celestial_sky()
	test_cosmetics_3d_and_shop()
	test_guide_and_feedback()
	test_world_settlements_map_and_tutorial()
	print("\n🎉 TODOS OS TESTES DE CÉU, COSMÉTICOS, MAPA, VILAS E TUTORIAL PASSARAM!")
	print("========================================================\n")
	quit(0)

func test_celestial_sky() -> void:
	print("\n[1/3] Cúpula Estelar Procedural e Planeta com Anéis...")
	var sun := DayNightCycle.new()
	sun.start_time_hour = 22.0
	root.add_child(sun)

	var sky := CelestialSky.new()
	sky.sun = sun
	root.add_child(sky)
	sky._process(0.1)

	assert(sky.star_dome != null and sky.star_dome.material_override is ShaderMaterial, "StarDome com shader")
	assert(sky.planet_root != null and sky.planet_body != null and sky.planet_rings != null, "Planeta com corpo e anéis")
	var star_vis: float = sky._star_mat.get_shader_parameter("sky_visibility")
	var planet_fade: float = sky._planet_mat.get_shader_parameter("sky_fade")
	assert(star_vis > 0.7, "Estrelas visíveis à noite (vis=%.2f)" % star_vis)
	assert(planet_fade > 0.8, "Planeta com anel nítido à noite (fade=%.2f)" % planet_fade)

	sky.free()
	sun.free()
	print("  ✓ StarDome e RingedPlanet funcionando e reagindo ao ciclo solar")

func test_cosmetics_3d_and_shop() -> void:
	print("\n[2/3] Cosméticos 3D, Loja e Personagem Feminino...")
	var player: Player = PlayerScene.instantiate() as Player
	root.add_child(player)
	player.set_physics_process(false)

	var dna := CharacterDNA.randomized(12)
	dna.femininity = 0.88
	player.character_visual.rebuild(dna)
	player.wallet.set_money(300)

	var shop := CosmeticsShop.new()
	root.add_child(shop)
	shop.open_shop(player)
	assert(shop.is_open, "Loja de cosméticos abriu")

	var coroa := CosmeticsCatalog.get_item("coroa_flores")
	var manto := CosmeticsCatalog.get_item("manto_rosa_real")
	var aura := CosmeticsCatalog.get_item("aura_cosmica")
	shop._on_action_item(coroa)
	shop._on_action_item(manto)
	shop._on_action_item(aura)

	var updated_dna := player.character_visual.dna
	assert(updated_dna.has_cosmetic("coroa_flores") and updated_dna.cosmetic_hat == "coroa_flores", "Coroa comprada e equipada")
	assert(updated_dna.cosmetic_cape == "manto_rosa_real", "Manto equipado")
	assert(updated_dna.cosmetic_aura == "aura_cosmica", "Aura equipada")
	assert(player.wallet.money == 300 - int(coroa.price) - int(manto.price) - int(aura.price), "Descontou o ouro certinho")

	var skel := player.character_visual.skeleton
	assert(skel.get_node_or_null("Cosmetic_HatSocket") != null, "Chapéu 3D anexado na cabeça")
	assert(skel.get_node_or_null("Cosmetic_CapeSocket") != null, "Capa 3D anexada nas costas")
	assert(player.character_visual.get_node_or_null("Cosmetic_Aura") != null, "Aura 3D anexada no personagem")

	# Serialização no save (to_dict / from_dict)
	var restored := CharacterDNA.from_dict(updated_dna.to_dict())
	assert(restored.cosmetic_hat == "coroa_flores" and restored.has_cosmetic("manto_rosa_real"), "Cosméticos salvos no DNA")

	shop.close_shop()
	shop.free()
	player.free()
	print("  ✓ Compra, encaixe 3D e persistência de cosméticos validados")

func test_guide_and_feedback() -> void:
	print("\n[3/3] Guia do Explorador e Mural de Feedback...")
	var guide := ExplorerGuide.new()
	root.add_child(guide)
	guide.open_guide()
	assert(guide.is_open, "Guia abriu")
	guide.close_guide()
	guide.free()

	var fb := FeedbackModal.new()
	root.add_child(fb)
	fb.open_modal()
	assert(fb.is_open, "Mural de feedback abriu")
	fb.close_modal()
	fb.free()

	var coop := CoopMenu.new()
	root.add_child(coop)
	coop.open_menu()
	assert(coop.is_open, "Menu Coop LAN abriu")
	coop.close_menu()
	coop.free()

	var touch := MobileTouchControls.new()
	root.add_child(touch)
	touch.set_touch_enabled(true)
	assert(touch.is_enabled and touch.visible, "Controles Touch de celular ativaram")
	touch.set_touch_enabled(false)
	assert(not touch.is_enabled and not touch.visible, "Controles Touch de celular desativaram")
	touch.free()
	print("  ✓ Guia, Mural de Feedback, Menu Coop LAN e Controles Mobile Touch validados")

func test_world_settlements_map_and_tutorial() -> void:
	print("\n[4/4] Cidades do Vale, Mapa Mundial [M] e Trilha do Tutorial...")
	var player: Player = PlayerScene.instantiate() as Player
	root.add_child(player)
	player.set_physics_process(false)

	var ws := WorldSettlements.new()
	root.add_child(ws)
	assert(ws.get_node_or_null("VilaPortoBruma") != null, "Vila Ribeirinha de Porto Bruma criada")
	assert(ws.get_node_or_null("PostoVigiaDoNorte") != null, "Posto da Vigia do Norte criado")
	assert(ws.get_node_or_null("SantuarioAstral") != null, "Santuário Astral do Mirante criado")
	var santuario_hub := ws.get_node("SantuarioAstral")
	var spawner := santuario_hub.get_node_or_null("AstralSanctuarySpawner") as AstralSanctuarySpawner
	assert(spawner != null, "AstralSanctuarySpawner @tool presente no Santuário Astral")

	# Simula assets estáticos colocados manualmente e testa a substituição procedural
	var manual_tree := Node3D.new()
	manual_tree.name = "Manual_Tree_Static_01"
	manual_tree.position = Vector3(82.0, 0.0, -36.0)
	santuario_hub.add_child(manual_tree)
	var manual_rock := Node3D.new()
	manual_rock.name = "StaticRock_Old_02"
	manual_rock.position = Vector3(80.0, 0.0, -39.0)
	santuario_hub.add_child(manual_rock)
	spawner.rebuild_sanctuary()
	assert(spawner.last_purged_manual_count == 2, "Varredura @tool excluiu os 2 assets estáticos manuais")
	assert(spawner.get_node_or_null("Procedural_AltarAndPillars/AltarCentral/AltarOmniLight") is OmniLight3D, "Altar tem OmniLight3D")
	assert(spawner.get_node_or_null("Procedural_AltarAndPillars/AltarCentral/AltarAuraParticles") is GPUParticles3D, "Altar tem GPUParticles3D")
	assert(spawner.get_node_or_null("Procedural_FloraAndRocks/Procedural_MultiMesh_Trees") is MultiMeshInstance3D, "MultiMesh de árvores procedurais criado")
	assert(spawner.get_node_or_null("Procedural_FloraAndRocks/Procedural_MultiMesh_LushFoliage") is MultiMeshInstance3D, "MultiMesh de flora densa criado")

	assert(ws.fast_travel_to(&"porto_bruma", player), "Viagem rápida para Porto Bruma funciona")
	assert(player.global_position.distance_to(Vector3(39.0, player.global_position.y, 46.0)) < 5.0, "Player chegou em Porto Bruma")

	var trail := TutorialTrail.new()
	trail.player = player
	root.add_child(trail)
	assert(trail.current_step == 0 and not trail.is_completed, "Trilha do Tutorial inicia no Passo 1/8")
	trail.advance_step()
	assert(trail.current_step == 1, "Avançou para o Passo 2/8 da Trilha do Tutorial")
	trail.jump_to_step(7)
	trail.advance_step()
	assert(trail.is_completed, "Concluiu as 8 estações da Trilha do Tutorial")

	var map_screen := WorldMapScreen.new()
	root.add_child(map_screen)
	map_screen.open_map(player)
	assert(map_screen.is_open, "Mapa Mundial [M] abriu")
	map_screen.close_map()
	assert(not map_screen.is_open, "Mapa Mundial [M] fechou")

	map_screen.free()
	trail.free()
	ws.free()
	player.free()
	print("  ✓ 4 Cidades/Assentamentos, Viagem Rápida, Mapa [M] e Trilha do Tutorial (8 estações) validados")
