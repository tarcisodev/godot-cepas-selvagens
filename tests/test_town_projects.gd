extends SceneTree

## GDD-08 §6.1: obras da vila com doação de materiais, etapas, Reputação, save e zonas.

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const ZoneManagerClass = preload("res://scripts/core/zone_manager.gd")

var _started: bool = false

func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false

func _run() -> void:
	print("\n========================================================")
	print("🏗️ TESTANDO OBRAS DA VILA (GDD-08 §6.1)")
	print("========================================================")
	test_project_donation()
	test_city_state_and_reputation()
	test_zones_and_village_area()
	print("\n🎉 TODOS OS TESTES DAS OBRAS DA VILA PASSARAM COM SUCESSO!")
	print("========================================================\n")
	quit(0)

func _make_player() -> Player:
	var player: Player = PlayerScene.instantiate() as Player
	root.add_child(player)
	player._setup_components()
	return player

func test_project_donation() -> void:
	print("\n[1/3] Doação, etapas e visual de uma obra...")
	var p := TownProject.new()
	p.project_id = &"teste"
	p.display_name = "Casa de Teste"
	p.kind = TownProject.Kind.HOUSE
	var costs: Array[Dictionary] = [{&"pedra": 4}, {&"madeira": 3, &"fibra": 2}, {&"folha": 2}]
	p.stage_costs = costs
	root.add_child(p)
	var player := _make_player()
	var inv := player.inventory

	assert(p.stage == 0 and p.stage_name() == "Fundação", "Obra começa na Fundação")
	assert(p.donate(inv, &"pedra", 2) == 0, "Sem pedra no inventário não doa nada")
	inv.add_material(&"pedra", 3)
	inv.add_material(&"pedra", 3, 2)
	assert(p.donate(inv, &"pedra", 2) == 2 and p.missing() == {&"pedra": 2}, "Doação parcial fica registrada")
	assert(inv.get_stacks(&"pedra")[0].quality == 1 and inv.get_material_count(&"pedra") == 4, "Gasta a pior qualidade primeiro")
	assert(is_equal_approx(p.stage_progress(), 0.5), "Progresso da etapa em 50%")
	assert(p.donate(inv, &"pedra", 99) == 2, "Doação é limitada ao que falta")
	assert(inv.get_material_count(&"pedra") == 2, "O excesso fica no inventário")
	assert(p.stage == 1 and p.deposited.is_empty(), "Fundação concluída: passa para a Estrutura")
	assert(p.get_node("Visual").get_child_count() > 0, "Visual reconstruído para a nova etapa")

	inv.add_material(&"madeira", 3)
	inv.add_material(&"fibra", 2)
	p.donate(inv, &"madeira", 3)
	p.donate(inv, &"fibra", 2)
	inv.add_material(&"folha", 2)
	p.donate(inv, &"folha", 2)
	assert(p.is_complete() and p.stage_name() == "Pronto", "Três etapas completas = obra pronta")
	assert(p.donate(inv, &"pedra", 1) == 0 and p.missing().is_empty(), "Obra pronta não aceita mais doação")

	var saved: Dictionary = JSON.parse_string(JSON.stringify({"stage": 1, "deposited": {"madeira": 2}}))
	p.apply_state(saved)
	assert(p.stage == 1 and p.deposited.get(&"madeira") == 2 and p.missing() == {&"madeira": 1, &"fibra": 2}, "Estado da obra volta do JSON")
	p.free()
	player.free()
	print("  ✓ Doação parcial, limite pelo que falta, pior ★ primeiro, troca de etapa e estado")

func test_city_state_and_reputation() -> void:
	print("\n[2/3] Vila: obras iniciais, Reputação e save...")
	var city := CityHub.new()
	root.add_child(city)
	var player := _make_player()
	var ids := city.get_projects().map(func(p): return p.project_id)
	assert(ids == [&"poco", &"palicada", &"mercado", &"forja", &"taverna"], "Cinco obras na vila (saiu %s)" % [ids])
	assert(city.get_project(&"forja").stage == 2 and city.get_project(&"poco").stage == 0, "Jogo novo: a vila já começou (forja com paredes, poço no lote)")

	var poco := city.get_project(&"poco")
	player.inventory.add_material(&"pedra", 5)
	assert(city.donate(poco, player, &"pedra", 5) == 5 and city.reputation == 5, "Doar dá 1 de Reputação por unidade")

	var state: Dictionary = JSON.parse_string(JSON.stringify(city.get_state()))
	city.free()
	var city2 := CityHub.new()
	root.add_child(city2)
	city2.apply_state(state)
	assert(city2.reputation == 5, "Reputação volta do save")
	assert(city2.get_project(&"poco").deposited.get(&"pedra") == 5, "Doação parcial do poço volta do save")
	assert(city2.get_project(&"forja").stage == 2, "Etapa das obras volta do save")
	city2.free()
	player.free()
	print("  ✓ 5 obras, etapas iniciais, Reputação e ida e volta do estado")

func test_zones_and_village_area() -> void:
	print("\n[3/3] Zonas: covil da besta fora da cidade, perigo antes da cidade...")
	var zm := ZoneManagerClass.new()
	root.add_child(zm)
	assert(zm.get_zone_at(Vector3(-5.0, 0.0, -11.0)) == ZoneManagerClass.ZoneType.DANGER, "Besta fica no covil (dá para lutar)")
	assert(zm.can_combat_at(Vector3(-5.0, 0.0, -11.0)), "Combate liberado no covil")
	assert(zm.get_zone_at(Vector3(0.0, 0.0, 0.0)) == ZoneManagerClass.ZoneType.CITY, "Spawn fica na vila")
	assert(zm.get_zone_at(Vector3(-7.5, 0.0, 5.0)) == ZoneManagerClass.ZoneType.CITY, "Taverna fica na vila, longe da arena")
	assert(CityHub.in_village(-7.5, 5.0) and not CityHub.in_village(-27.0, 3.0), "Arena fora da área da vila")
	zm.free()
	print("  ✓ Covil, vila e arena sem sobreposição")
