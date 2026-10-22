extends SceneTree

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const ChestScript = preload("res://scripts/supply_chest.gd")

var _started: bool = false

func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false

func _run() -> void:
	print("\n========================================================")
	print("🧪 TESTANDO CONSUMÍVEIS E BAÚ DE SUPRIMENTOS")
	print("========================================================")

	test_consumable_data()
	test_use_item_restores_pools()
	test_quick_use_picks_weakest_that_covers()
	test_chest_refills_kit()

	print("\n🎉 TODOS OS TESTES DE CONSUMÍVEIS PASSARAM COM SUCESSO!")
	print("========================================================\n")
	quit(0)

func _spawn_player() -> Player:
	var player: Player = PlayerScene.instantiate() as Player
	root.add_child(player)
	return player

func test_consumable_data() -> void:
	print("\n[1/4] Dados dos consumíveis...")
	assert(MaterialData.of(&"pocao").restore_health > 0.0, "Poção cura")
	assert(MaterialData.of(&"mega_pocao").restore_health > MaterialData.of(&"pocao").restore_health, "Mega Poção cura mais")
	assert(MaterialData.of(&"erva").restore_health > 0.0, "Erva cura um pouco")
	for id in [&"carne_mal_passada", &"carne_bem_passada", &"carne_torrada"]:
		assert(MaterialData.of(id).restore_vigor > 0.0, "Carne repõe Vigor: %s" % id)
	assert(MaterialData.of(&"carne_bem_passada").restore_vigor > MaterialData.of(&"carne_mal_passada").restore_vigor, "Bem passada rende mais")
	for id in [&"cannabis_sativa", &"cannabis_indica"]:
		assert(MaterialData.of(id).restore_ether > 0.0, "Cannabis repõe Éter: %s" % id)
	assert(not MaterialData.of(&"madeira").is_consumable(), "Madeira não se come")
	print("  ✓ Erva/poções → Vida, carnes → Vigor, cannabis → Éter")

func test_use_item_restores_pools() -> void:
	print("\n[2/4] Usar item gasta uma unidade e repõe o pool...")
	var player := _spawn_player()
	var inv := player.inventory
	var pools := player.pools
	inv.add_material(&"pocao", 2)
	var stack := inv.get_stacks(&"pocao")[0]
	assert(not inv.use_item(stack, pools), "Vida cheia: não desperdiça a poção")
	assert(inv.get_material_count(&"pocao") == 2, "Poção não foi gasta")

	pools.take_damage(50.0)
	assert(inv.use_item(stack, pools), "Com Vida faltando, usa")
	assert(is_equal_approx(pools.current_health, 50.0 + MaterialData.of(&"pocao").restore_health), "Poção cura o valor dela")
	assert(inv.get_material_count(&"pocao") == 1, "Gastou uma poção")

	inv.add_material(&"carne_bem_passada", 1)
	pools.consume_vigor(70.0)
	var before := pools.current_vigor
	assert(inv.use_item(inv.get_stacks(&"carne_bem_passada")[0], pools), "Come a carne")
	assert(pools.current_vigor > before, "Carne repõe Vigor")
	assert(inv.get_material_count(&"carne_bem_passada") == 0, "Pilha vazia some")

	inv.add_material(&"madeira", 1)
	assert(not inv.use_item(inv.get_stacks(&"madeira")[0], pools), "Madeira não é usável")
	player.free()
	print("  ✓ Uso validado")

func test_quick_use_picks_weakest_that_covers() -> void:
	print("\n[3/4] Atalho escolhe o menor item que cobre o que falta...")
	var player := _spawn_player()
	var inv := player.inventory
	var pools := player.pools
	inv.add_material(&"erva", 3)
	inv.add_material(&"pocao", 3)
	inv.add_material(&"mega_pocao", 3)

	pools.take_damage(10.0)
	assert(inv.use_best_for(&"health", pools), "Cura com o atalho")
	assert(inv.get_material_count(&"erva") == 2, "Ferimento leve gasta erva")

	pools.take_damage(35.0)
	assert(inv.use_best_for(&"health", pools))
	assert(inv.get_material_count(&"pocao") == 2, "Ferimento médio gasta poção")

	pools.take_damage(90.0)
	assert(inv.use_best_for(&"health", pools))
	assert(inv.get_material_count(&"mega_pocao") == 2, "Ferimento grave gasta mega poção")

	assert(not inv.use_best_for(&"ether", pools), "Sem cannabis e Éter cheio: nada a usar")
	pools.consume_ether(60.0)
	assert(not inv.use_best_for(&"ether", pools), "Sem cannabis: nada a usar")
	inv.add_material(&"cannabis_sativa", 1)
	assert(inv.use_best_for(&"ether", pools), "Com cannabis repõe Éter")
	player.free()
	print("  ✓ Atalho validado")

func test_chest_refills_kit() -> void:
	print("\n[4/4] Baú completa a mochila até o kit...")
	var player := _spawn_player()
	var chest: SupplyChest = ChestScript.new()
	root.add_child(chest)
	var inv := player.inventory
	inv.add_material(&"pocao", 2)
	chest.talk_to(player)
	for id in chest.kit.keys():
		assert(inv.get_material_count(id) == int(chest.kit[id]), "Kit completo: %s" % id)
	assert(chest.refill(inv).is_empty(), "Mochila cheia: o baú não dá mais")
	inv.consume_materials({&"pocao": 3})
	var given := chest.refill(inv)
	assert(given.size() == 1 and inv.get_material_count(&"pocao") == int(chest.kit[&"pocao"]), "Repõe só o que foi gasto")
	chest.free()
	player.free()
	print("  ✓ Baú validado")
