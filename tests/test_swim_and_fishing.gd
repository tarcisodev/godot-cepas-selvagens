extends SceneTree

## B19 / GDD-10 §2 e §6: nado, mergulho e fôlego; peixes procedurais; pesca com vara.

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const STEP: float = 1.0 / 60.0

var _started: bool = false

func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false

func _run() -> void:
	print("\n========================================================")
	print("🌊 TESTANDO NADO, MERGULHO, PEIXES E PESCA (B19)")
	print("========================================================")
	RiverSystem.flood = 0.0
	var player: Player = PlayerScene.instantiate() as Player
	root.add_child(player)
	player._setup_components()
	player.set_physics_process(false)
	player.fishing.set_process(false) # o teste dá os passos da pesca na mão
	var eco := EcosystemSpawner.new()
	for prop in ["trotador_herds", "saltarelos", "planadores", "raias", "lambari_schools", "trairas", "dourados", "trees", "bushes", "cepas", "mushrooms"]:
		eco.set(prop, 0)
	root.add_child(eco)

	await test_swim(player)
	test_oxygen(player)
	test_fish_bodies(eco)
	test_fishing_catch(player, eco)
	test_line_breaks(player, eco)
	print("\n🎉 TODOS OS TESTES DE NADO E PESCA PASSARAM COM SUCESSO!")
	print("========================================================\n")
	quit(0)

## Terreno falso: leito fundo no rio e chão alto fora dele
func _fake_landscape(bed: float) -> Node:
	var script := GDScript.new()
	script.source_code = "extends Node\nvar bed: float = %f\nfunc get_height_at(x: float, z: float) -> float:\n\treturn bed if RiverSystem.get_distance_to_river(x, z) < RiverSystem.get_water_half_width(z) else 2.0\n" % bed
	script.reload()
	var n := Node.new()
	n.set_script(script)
	root.add_child(n)
	return n

func _river_point(z: float) -> Vector3:
	return Vector3(RiverSystem.get_river_center_x(z), RiverSystem.get_water_height(z), z)

func test_swim(player: Player) -> void:
	print("\n[1/5] Boia no fundo, anda no raso...")
	player._landscape = _fake_landscape(RiverSystem.LOWER_BED_Y)
	var p := _river_point(40.0)
	player.global_position = Vector3(p.x, RiverSystem.LOWER_BED_Y, p.z)
	assert(player._update_swim_state(), "Água funda: nada")
	player.set_physics_process(true) # move_and_slide precisa do passo de física de verdade
	for i in 180:
		await physics_frame
	player.set_physics_process(false)
	var float_y := RiverSystem.get_water_height(player.global_position.z) - Player.SWIM_FLOAT
	assert(absf(player.global_position.y - float_y) < 0.15, "Boiou com a cabeça para fora (y=%.2f, alvo %.2f)" % [player.global_position.y, float_y])
	assert(player.global_position.z > p.z + 0.5, "A correnteza levou rio abaixo")
	player._landscape.set("bed", RiverSystem.LOWER_WATER_Y - 0.5)
	assert(not player._update_swim_state(), "Raso (50 cm): sai do nado")
	player._landscape.set("bed", RiverSystem.LOWER_BED_Y)
	print("  ✓ Boia na superfície, correnteza empurra, raso volta a andar")

func test_oxygen(player: Player) -> void:
	print("\n[2/5] Mergulho e fôlego...")
	var p := _river_point(40.0)
	player.global_position = Vector3(p.x, RiverSystem.LOWER_BED_Y + 0.1, p.z)
	player.is_swimming = true
	player.oxygen = Player.OXYGEN_MAX
	var hp := player.pools.current_health
	for i in 10:
		player._update_oxygen(1.0)
	assert(player.is_underwater and is_equal_approx(player.oxygen, Player.OXYGEN_MAX - 10.0), "Embaixo d'água gasta 1 s de fôlego por s")
	assert(player.pools.current_health == hp, "Com fôlego não perde Vida")
	for i in 25:
		player._update_oxygen(1.0)
	assert(player.oxygen == 0.0 and player.pools.current_health < hp, "Sem fôlego afoga (Vida caiu)")
	player.global_position.y = RiverSystem.get_water_height(p.z) - Player.SWIM_FLOAT
	player._update_oxygen(1.0)
	assert(not player.is_underwater and player.oxygen > 0.0, "Cabeça fora: respira")
	player.pools.heal(999.0)
	player.oxygen = Player.OXYGEN_MAX
	player.is_swimming = false
	print("  ✓ Fôlego de %d s, afogamento tira Vida, superfície recupera" % roundi(Player.OXYGEN_MAX))

func test_fish_bodies(eco: EcosystemSpawner) -> void:
	print("\n[3/5] Peixes procedurais...")
	var sizes := {}
	for sp in [CreatureDNA.Species.LAMBARI, CreatureDNA.Species.TRAIRA, CreatureDNA.Species.DOURADO]:
		var d := CreatureDNA.randomized(sp, 11)
		d.alleles["porte"] = ["T", "T"]
		var c := eco._add_wild(sp, _river_point(30.0) - Vector3(0, 0.5, 0), 4.0, d)
		assert(c.is_in_group("fish"), "%s está no grupo de peixes" % d.species_name())
		var aabb := AABB()
		for mi in c.body.find_children("*", "MeshInstance3D", true, false):
			aabb = aabb.merge((mi as MeshInstance3D).get_aabb()) if aabb.size != Vector3.ZERO else (mi as MeshInstance3D).get_aabb()
		sizes[sp] = aabb.size.z
		c.take_away()
	assert(sizes[CreatureDNA.Species.LAMBARI] < 0.6, "Lambari é peixinho (%.2f m)" % sizes[CreatureDNA.Species.LAMBARI])
	assert(sizes[CreatureDNA.Species.LAMBARI] < sizes[CreatureDNA.Species.TRAIRA] and sizes[CreatureDNA.Species.TRAIRA] < sizes[CreatureDNA.Species.DOURADO], "Lambari < Traíra < Dourado")
	print("  ✓ Três espécies com tamanhos próprios (%.2f / %.2f / %.2f m)" % [sizes[CreatureDNA.Species.LAMBARI], sizes[CreatureDNA.Species.TRAIRA], sizes[CreatureDNA.Species.DOURADO]])

func _hooked_fish(player: Player, eco: EcosystemSpawner, sp: CreatureDNA.Species) -> WildCreature:
	var fishing := player.fishing
	var spot := _river_point(50.0)
	player.global_position = spot + Vector3(-7.0, 1.0, 0)
	var d := CreatureDNA.randomized(sp, 21)
	d.alleles["porte"] = ["T", "t"]
	var fish := eco._add_wild(sp, spot + Vector3(1.5, -0.6, 0), 4.0, d)
	fish.set_process(false)
	assert(fishing.cast_at(spot), "Lança na água")
	fishing.tick(STEP, false, false)
	fishing._timer = 0.0
	fishing.tick(STEP, false, false) # CASTING → WAITING
	assert(fishing.state == FishingComponent.State.WAITING, "Boia na água esperando")
	fishing.tick(STEP, false, false)
	assert(fishing.fish == fish and fish.lure != Vector3.INF, "A boia atraiu o peixe de verdade")
	fishing._timer = 0.0
	fishing.tick(STEP, false, false)
	assert(fishing.state == FishingComponent.State.BITE, "Mordeu: boia afundou")
	fishing.tick(STEP, false, true)
	assert(fishing.state == FishingComponent.State.REELING and fish.hooked, "Fisgou com o clique")
	return fish

func test_fishing_catch(player: Player, eco: EcosystemSpawner) -> void:
	print("\n[4/5] Vara, isca, fisgar e recolher...")
	var inv := player.inventory
	inv.add_material(&"galho", 3)
	inv.add_material(&"fibra", 4)
	assert(inv.craft(&"vara_pesca") and MaterialData.of(&"vara_pesca").tool_action == &"pesca", "Faz a vara (ferramenta de pesca)")
	inv.add_material(&"besouro", 1)
	_hooked_fish(player, eco, CreatureDNA.Species.LAMBARI)
	assert(player.fishing.used_bait and inv.get_material_count(&"besouro") == 0, "Besouro virou isca")
	assert(player.fishing.is_busy(), "Pescando: o clique é da vara")
	# Recolhe com cuidado: segura enquanto a tensão está abaixo de 70%, solta acima
	var t := 0.0
	while player.fishing.state == FishingComponent.State.REELING and t < 60.0:
		player.fishing.tick(STEP, player.fishing.tension < 0.7, false)
		t += STEP
	assert(inv.get_material_count(&"peixe_lambari") == 1, "Pescou o lambari (%.1f s)" % t)
	assert(inv.best_stack(&"peixe_lambari").quality == 2, "Porte Tt = 2★")
	assert(MaterialData.of(&"peixe_lambari").restore_vigor > 0.0, "Peixe é comida (Vigor)")
	assert(inv.get_material_count(&"vara_pesca") == 1, "A vara não gasta")
	print("  ✓ Lambari 2★ pescado em %.1f s; vara fica, isca gasta" % t)

func test_line_breaks(player: Player, eco: EcosystemSpawner) -> void:
	print("\n[5/5] Linha arrebenta e peixe escapa...")
	var fish := _hooked_fish(player, eco, CreatureDNA.Species.DOURADO)
	var t := 0.0
	while player.fishing.state == FishingComponent.State.REELING and t < 30.0:
		player.fishing.tick(STEP, true, false) # puxa sem parar
		t += STEP
	assert(player.fishing.state == FishingComponent.State.IDLE and player.inventory.get_material_count(&"peixe_dourado") == 0, "Puxar sem parar arrebenta a linha")
	assert(is_instance_valid(fish) and not fish.hooked, "O dourado continua no rio")
	fish.take_away()
	var fish2 := _hooked_fish(player, eco, CreatureDNA.Species.TRAIRA)
	t = 0.0
	while player.fishing.state == FishingComponent.State.REELING and t < 30.0:
		player.fishing.tick(STEP, false, false) # linha frouxa
		t += STEP
	assert(player.fishing.state == FishingComponent.State.IDLE and player.inventory.get_material_count(&"peixe_traira") == 0, "Linha frouxa: escapa")
	fish2.take_away()
	print("  ✓ Esticar demais arrebenta; afrouxar demais solta o peixe")
