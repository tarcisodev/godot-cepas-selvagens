extends SceneTree

## B12 / ADR-0005: estoque em pilhas por (id, qualidade, traits), coleta 1★/2★ e organizador da tela.

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const GatherableClass = preload("res://scripts/gatherable_resource.gd")

var _started: bool = false

func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false

func _run() -> void:
	print("\n========================================================")
	print("🎒 TESTANDO ESTOQUE COM QUALIDADE (B12 / ADR-0005)")
	print("========================================================")
	test_material_data()
	test_stacks()
	test_gather_quality()
	test_sorting()
	print("\n🎉 TODOS OS TESTES DE ESTOQUE PASSARAM COM SUCESSO!")
	print("========================================================\n")
	quit(0)

func test_material_data() -> void:
	print("\n[1/4] MaterialData dos materiais do slice...")
	for id in [&"madeira", &"galho", &"folha", &"fibra", &"pedra", &"frutinha", &"besouro", &"ossos", &"erva", &"mel", &"chifre_rinolito", &"placa_carapaca", &"tendao_elastico"]:
		var d := MaterialData.of(id)
		assert(d.id == id, "Dados de %s vêm do .tres" % id)
		assert(not d.display_name.is_empty() and d.unit_weight > 0.0, "%s tem nome e peso" % id)
	var unknown := MaterialData.of(&"material_inexistente")
	assert(unknown != null and unknown.display_name == "Material Inexistente", "Id sem .tres devolve dados genéricos")
	print("  ✓ .tres carregados; id desconhecido não quebra")

func test_stacks() -> void:
	print("\n[2/4] Pilhas: juntar, separar, gastar da pior para a melhor...")
	var player: Player = PlayerScene.instantiate() as Player
	root.add_child(player)
	player._setup_components()
	var inv := player.inventory
	inv.add_material(&"madeira", 3)
	inv.add_material(&"madeira", 2)
	inv.add_material(&"madeira", 4, 2)
	inv.add_material(&"chifre_rinolito", 1, 3, [&"integro"])
	inv.add_material(&"chifre_rinolito", 1, 3, [&"integro"])
	assert(inv.get_stacks(&"madeira").size() == 2, "1★ juntam; 2★ fica em outra pilha")
	assert(inv.get_material_count(&"madeira") == 9, "Contagem soma as pilhas")
	assert(inv.get_stacks(&"chifre_rinolito").size() == 1 and inv.get_material_count(&"chifre_rinolito") == 2, "Mesma qualidade e traits juntam")

	assert(inv.consume_materials({&"madeira": 6}), "Construção gasta 6 madeiras")
	var left := inv.get_stacks(&"madeira")
	assert(left.size() == 1 and left[0].quality == 2 and left[0].amount == 3, "Gastou as 5 de 1★ e 1 de 2★ (pior primeiro)")

	var w_before := inv.get_total_weight()
	inv.add_material(&"pedra", 2)
	assert(is_equal_approx(inv.get_total_weight() - w_before, 2.0 * MaterialData.of(&"pedra").unit_weight), "Peso total soma peso unitário × quantidade")

	var saved: Array = JSON.parse_string(JSON.stringify(inv.stacks_to_save()))
	inv.load_from_save(saved)
	assert(inv.get_material_count(&"madeira") == 3 and inv.best_stack(&"chifre_rinolito").traits.has(&"integro"), "Pilhas sobrevivem ao JSON com qualidade e traits")
	player.free()
	print("  ✓ Pilhas por (id, ★, traits), gasto da pior qualidade e save validados")

func test_gather_quality() -> void:
	print("\n[3/4] Coleta 1★/2★ pela maestria (GDD-08 §8)...")
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in 200:
		assert(GatherableClass.roll_quality(24, 2, rng) == 1, "Abaixo do nível 25 sempre 1★")
	var twos := 0
	for i in 2000:
		var q: int = GatherableClass.roll_quality(100, 2, rng)
		assert(q <= 2, "Coleta comum nunca passa de 2★")
		if q == 2:
			twos += 1
	# nível 100: 10% + 0,4% × 75 = 40%
	assert(twos > 700 and twos < 900, "No nível 100 ~40%% vira 2★ (saiu %d/2000)" % twos)
	assert(GatherableClass.roll_quality(100, 1, rng) == 1, "Material com teto 1★ não sobe")
	print("  ✓ Curva 1★/2★: %d/2000 no nível 100" % twos)

func test_sorting() -> void:
	print("\n[4/4] Organizador automático da tela de inventário...")
	var list: Array = [
		{"id": &"galho", "quality": 1, "traits": [], "amount": 20},
		{"id": &"pedra", "quality": 2, "traits": [], "amount": 3},
		{"id": &"mel", "quality": 1, "traits": [], "amount": 1},
		{"id": &"madeira", "quality": 4, "traits": [], "amount": 2},
	]
	var ids := func(arr: Array) -> Array: return arr.map(func(s): return s.id)
	assert(ids.call(InventoryScreen.sort_stacks(list, InventoryScreen.SortMode.RARIDADE, true))[0] == &"madeira", "Raridade: 4★ primeiro")
	assert(ids.call(InventoryScreen.sort_stacks(list, InventoryScreen.SortMode.QUANTIDADE, true))[0] == &"galho", "Quantidade: 20 primeiro")
	assert(ids.call(InventoryScreen.sort_stacks(list, InventoryScreen.SortMode.QUANTIDADE, false))[0] == &"mel", "Quantidade invertida: 1 primeiro")
	# Peso: galho 20×0,4 = 8 · pedra 3×1,5 = 4,5 · madeira 2×2 = 4 · mel 0,5
	assert(ids.call(InventoryScreen.sort_stacks(list, InventoryScreen.SortMode.PESO, true)) == [&"galho", &"pedra", &"madeira", &"mel"], "Peso total da pilha, maior primeiro")
	var by_name: Array = ids.call(InventoryScreen.sort_stacks(list, InventoryScreen.SortMode.NOME, true))
	assert(by_name == [&"mel", &"galho", &"pedra", &"madeira"], "Nome A→Z pelo nome de exibição (saiu %s)" % [by_name])
	var by_color: Array = ids.call(InventoryScreen.sort_stacks(list, InventoryScreen.SortMode.COR, true))
	assert(by_color[by_color.size() - 1] == &"pedra", "Cor: cinza (pedra) vai para o fim")
	print("  ✓ Raridade, quantidade, peso, nome e cor ordenam como esperado")
