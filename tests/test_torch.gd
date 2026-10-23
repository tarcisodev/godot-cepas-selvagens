extends SceneTree

## Tocha (GDD-03 §9): receita, [T] faz e acende, queima e troca sozinha, água apaga, abelhas.

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")

var _started: bool = false

func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false

func _run() -> void:
	print("\n========================================================")
	print("🔥 TESTANDO A TOCHA")
	print("========================================================")
	test_recipe_and_quick_craft()
	test_burn_and_next_torch()
	test_water_and_bees()
	print("\n🎉 TODOS OS TESTES DA TOCHA PASSARAM COM SUCESSO!")
	print("========================================================\n")
	quit(0)

func _spawn_player() -> Player:
	var player: Player = PlayerScene.instantiate() as Player
	root.add_child(player)
	player.set_physics_process(false)
	return player

func test_recipe_and_quick_craft() -> void:
	print("\n[1/3] Receita e [T] sem tocha na mochila...")
	var player := _spawn_player()
	var inv := player.inventory
	var torch := player.torch
	assert(torch != null, "Player ganha o componente da tocha")
	assert(InventoryComponent.RECIPES.has(&"tocha"), "Tocha tem receita")
	assert(MaterialData.of(&"tocha").tool_action == &"tocha", "Tocha é ferramenta da roda")
	assert(not torch.toggle(), "Sem tocha e sem material não acende")
	assert(not torch.is_lit, "Continua apagada")
	for mat in InventoryComponent.RECIPES[&"tocha"]:
		inv.add_material(mat, InventoryComponent.RECIPES[&"tocha"][mat])
	assert(torch.toggle(), "Com material, [T] faz e acende")
	assert(torch.is_lit and inv.get_material_count(&"tocha") == 1, "Fez uma tocha e está acesa")
	assert(not inv.has_materials(InventoryComponent.RECIPES[&"tocha"]), "Gastou o material")
	assert(torch._light != null and torch._light.visible, "Luz ligada")
	assert(torch.toggle() and not torch.is_lit, "[T] de novo apaga")
	assert(not torch._light.visible, "Luz desligada")
	player.free()
	print("  ✓ Receita e atalho validados")

func test_burn_and_next_torch() -> void:
	print("\n[2/3] Queima, guarda o resto e pega a próxima...")
	var player := _spawn_player()
	var inv := player.inventory
	var torch := player.torch
	inv.add_material(&"tocha", 2)
	assert(torch.toggle(), "Acende")
	torch._process(40.0)
	assert(is_equal_approx(torch.burn_left, TorchComponent.BURN_TIME - 40.0), "Queimou 40 s")
	torch.toggle()
	torch._process(40.0)
	assert(is_equal_approx(torch.burn_left, TorchComponent.BURN_TIME - 40.0), "Apagada não queima")
	torch.toggle()
	torch._process(TorchComponent.BURN_TIME)
	assert(torch.is_lit and inv.get_material_count(&"tocha") == 1, "Acabou uma, a outra pegou")
	assert(is_equal_approx(torch.burn_left, TorchComponent.BURN_TIME), "Tocha nova cheia")
	torch._process(TorchComponent.BURN_TIME + 1.0)
	assert(not torch.is_lit and inv.get_material_count(&"tocha") == 0, "Sem mais tochas, apaga")
	player.free()
	print("  ✓ Queima validada")

func test_water_and_bees() -> void:
	print("\n[3/3] Água apaga; fumaça acalma abelhas...")
	var player := _spawn_player()
	var inv := player.inventory
	var torch := player.torch
	inv.add_material(&"tocha", 1)
	torch.toggle()
	var hive := GatherableResource.new()
	hive.type = GatherableResource.Type.MEL
	root.add_child(hive)
	var hp := player.pools.current_health
	hive._handle_bee_hazard(player)
	assert(is_equal_approx(player.pools.current_health, hp), "Com tocha acesa as abelhas não picam")
	player.is_swimming = true
	torch._process(0.1)
	assert(not torch.is_lit, "Água apaga a tocha")
	assert(not torch.toggle(), "Não acende nadando")
	player.is_swimming = false
	hive._handle_bee_hazard(player)
	assert(player.pools.current_health < hp, "Sem tocha as abelhas picam")
	hive.free()
	player.free()
	print("  ✓ Água e abelhas validadas")
