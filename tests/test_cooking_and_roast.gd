extends SceneTree

const _Player = preload("res://scripts/player.gd")
const _CookingSystem = preload("res://scripts/systems/cooking_system.gd")
const _FoodBuffComponent = preload("res://scripts/components/food_buff_component.gd")
const _RoastSpitMinigame = preload("res://scripts/ui/roast_spit_minigame.gd")
const _CookingScreen = preload("res://scripts/ui/cooking_screen.gd")
const _CookingStation = preload("res://scripts/town/cooking_station.gd")
const _Campfire = preload("res://scripts/town/campfire.gd")
const _VultureFlock3D = preload("res://scripts/creatures/vulture_flock_3d.gd")
const _WildCreature = preload("res://scripts/creatures/wild_creature.gd")
const _CreatureDNA = preload("res://scripts/data/creature_dna.gd")
const _MaterialData = preload("res://scripts/data/material_data.gd")

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")

var _started: bool = false

func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false

func _run() -> void:
	print("\n========================================================")
	print("🍲 TESTANDO CULINÁRIA, ESPETO NA FOGUEIRA & URUBUS (GDD-13 e GDD-10 §11)")
	print("========================================================")

	test_food_material_data()
	test_cooking_system_recipes()
	test_food_buff_and_stats()
	test_inventory_use_dish()
	test_roast_spit_minigame()
	test_stations_and_campfire()
	test_vultures_and_decomposition()

	print("\n🎉 TODOS OS TESTES DE CULINÁRIA E URUBUS PASSARAM COM SUCESSO!")
	print("========================================================\n")
	quit(0)

func _spawn_player() -> _Player:
	var player: _Player = PlayerScene.instantiate() as _Player
	root.add_child(player)
	player._setup_components()
	player.set_physics_process(false)
	return player

func test_food_material_data() -> void:
	print("\n[1/7] Recursos e definições de pratos culinários...")
	var dishes: Array[StringName] = [
		&"gisado_cacador", &"peixe_ao_mel", &"assado_ermo",
		&"caldo_revigorante", &"banquete_viagem", &"ensopado_campeiro"
	]
	for d_id in dishes:
		var mat := _MaterialData.of(d_id)
		assert(mat != null, "Recurso existe: %s" % d_id)
		assert(mat.is_consumable(), "É consumível: %s" % d_id)
		assert(not mat.food_buff_id.is_empty(), "Possui food_buff_id: %s" % d_id)
		assert(mat.food_buff_duration > 0.0, "Possui duração válida: %s" % d_id)
		assert("min" in mat.effect_text(), "effect_text descreve o buff: %s" % mat.effect_text())

	var meat_well := _MaterialData.of(&"carne_bem_passada")
	assert(meat_well.food_buff_id == &"bem_alimentado", "Carne bem passada concede buff Bem Alimentado")
	print("  ✓ Todos os pratos culinários e carnes assadas configurados")

func test_cooking_system_recipes() -> void:
	print("\n[2/7] Sistema de receitas culinárias e cálculo de qualidade...")
	# 1. Gisado do Caçador
	var r1 := _CookingSystem.evaluate_recipe(&"carne_crua", [&"erva", &"frutinha"])
	assert(r1.get("result_id") == &"gisado_cacador", "Gisado identificado corretamente")

	# 2. Peixe Dourado ao Mel
	var r2 := _CookingSystem.evaluate_recipe(&"peixe_dourado", [&"mel", &"erva"])
	assert(r2.get("result_id") == &"peixe_ao_mel", "Peixe ao Mel identificado")

	# 3. Assado do Ermo
	var r3 := _CookingSystem.evaluate_recipe(&"carne_crua", [&"pinhao_lume", &"folha"])
	assert(r3.get("result_id") == &"assado_ermo", "Assado do Ermo identificado")

	# 4. Improvisação: base comestível + qualquer acompanhamento
	var r_imp := _CookingSystem.evaluate_recipe(&"carne_crua", [&"erva"])
	assert(r_imp.get("result_id") == &"ensopado_campeiro", "Improvisação gera Ensopado Campeiro")

	# Cálculo de qualidade ponderada
	var base_stack := {"id": &"carne_crua", "amount": 2, "quality": 4, "traits": [&"integro"]}
	var ingr_stacks := [
		{"id": &"erva", "amount": 1, "quality": 2, "traits": []},
		{"id": &"frutinha", "amount": 1, "quality": 2, "traits": [&"mutante"]}
	]
	var q: int = _CookingSystem.calculate_quality(base_stack, ingr_stacks)
	assert(q >= 2 and q <= 4, "Qualidade calculada de forma ponderada (obteve %d)" % q)

	var traits := _CookingSystem.combine_traits(base_stack, ingr_stacks)
	assert(traits.has(&"integro") and traits.has(&"mutante"), "Herda traits únicos dos ingredientes")
	print("  ✓ Receitas, combinações, qualidade e traits validados")

func test_food_buff_and_stats() -> void:
	print("\n[3/7] Componente de buffs de comida e modificadores de atributos (ADR-0001)...")
	var player := _spawn_player()
	var fb: _FoodBuffComponent = player.food_buff
	var stats := player.stats
	assert(fb != null, "Player possui FoodBuffComponent")

	var initial_vigor: float = stats.get_stat(&"max_vigor")
	var initial_dodge: float = stats.get_stat(&"dodge_cost")

	# Aplica Gisado do Caçador (+20 Vigor máx, -15% custo esquiva)
	fb.apply_food_buff(&"vigor_inabalavel", 1200.0, 1)
	assert(fb.has_buff(), "Buff ativo")
	assert(stats.get_stat(&"max_vigor") > initial_vigor, "Vigor aumentou com a refeição")
	assert(stats.get_stat(&"dodge_cost") < initial_dodge, "Custo da esquiva diminuiu")

	# Regra GDD-13 §5: uma refeição substitui a anterior (estilo MH)
	var initial_ether: float = stats.get_stat(&"max_ether")
	fb.apply_food_buff(&"foco_mistico", 1200.0, 1)
	assert(stats.get_stat(&"max_ether") > initial_ether, "Éter aumentou com o novo prato")
	assert(is_equal_approx(stats.get_stat(&"max_vigor"), initial_vigor), "Buff anterior de vigor foi limpo")

	# Limpeza e expiração
	fb.clear_buff()
	assert(not fb.has_buff(), "Buff limpo")
	assert(is_equal_approx(stats.get_stat(&"max_ether"), initial_ether), "Status de éter voltou ao padrão")

	player.free()
	print("  ✓ Buffs, regras de substituição de refeição e stats validados")

func test_inventory_use_dish() -> void:
	print("\n[4/7] Consumo de prato pronto pelo inventário e disparo de buff...")
	var player := _spawn_player()
	var inv := player.inventory
	var pools := player.pools

	inv.add_material(&"gisado_cacador", 1, 3, [])
	var stack := inv.get_stacks(&"gisado_cacador")[0]

	# Mesmo com pools cheios, prato gastronômico é consumido para aplicar o buff!
	assert(inv.use_item(stack, pools), "Consome o prato preparado")
	assert(inv.get_material_count(&"gisado_cacador") == 0, "Prato consumido da mochila")
	assert(player.food_buff.has_buff(), "Buff ativado no jogador")
	assert(player.food_buff.active_buff_id == &"vigor_inabalavel", "Buff correto aplicado")

	player.free()
	print("  ✓ Consumo de pratos e ativação automática validados")

func test_roast_spit_minigame() -> void:
	print("\n[5/7] Minigame do espeto na fogueira (estágios de timing)...")
	var player := _spawn_player()
	var minigame := _RoastSpitMinigame.new()
	player.add_child(minigame)

	# 1. Puxar antes da hora (t = 2.0s) -> Malpassada
	player.inventory.add_material(&"carne_crua", 1)
	minigame.open(player)
	minigame.elapsed = 2.0
	var res1 := minigame.pull_spit()
	assert(res1.get("result_id") == &"carne_mal_passada", "Puxado antes -> Carne Malpassada")

	# 2. Puxar no ponto perfeito (t = 4.0s) -> Bem Passada (3★) + buff Bem Alimentado
	player.inventory.add_material(&"carne_crua", 1)
	minigame.open(player)
	minigame.elapsed = 4.0
	var res2 := minigame.pull_spit()
	assert(res2.get("result_id") == &"carne_bem_passada", "Puxado na janela verde -> Carne Bem Passada")
	assert(int(res2.get("quality")) >= 3, "Qualidade aprimorada pela maestria")
	assert(player.food_buff.has_buff() and player.food_buff.active_buff_id == &"bem_alimentado", "Concedeu buff Bem Alimentado")

	# 3. Puxar tarde (t = 5.2s) -> Queimada
	player.inventory.add_material(&"carne_crua", 1)
	minigame.open(player)
	minigame.elapsed = 5.2
	var res3 := minigame.pull_spit()
	assert(res3.get("result_id") == &"carne_torrada", "Puxado tarde -> Queimada")

	player.free()
	print("  ✓ Janelas de timing do espeto validadas")

func test_stations_and_campfire() -> void:
	print("\n[6/7] Estação do Caldeirão e Fogueira com minigame...")
	var fire := _Campfire.new()
	root.add_child(fire)
	assert(fire.is_in_group("talkable"), "Campfire pertence ao grupo talkable")
	assert(fire.is_in_group("rest_fires"), "Campfire pertence a rest_fires")

	var cauldron := _CookingStation.new()
	root.add_child(cauldron)
	assert(cauldron.is_in_group("talkable"), "CookingStation pertence a talkable")
	assert(cauldron.is_in_group("cooking_station"), "CookingStation pertence a cooking_station")

	fire.free()
	cauldron.free()
	print("  ✓ Estações 3D no mundo validadas")

func test_vultures_and_decomposition() -> void:
	print("\n[7/7] Urubus procedurais e enriquecimento de nutrientes no solo...")
	var flock := _VultureFlock3D.new()
	root.add_child(flock)
	assert(flock.state == _VultureFlock3D.State.CIRCLING, "Urubus iniciam circulando sobre a carcaça")

	flock.disperse()
	assert(flock.state == _VultureFlock3D.State.DISPERSING, "Dispersam ao esfolar ou apodrecer")
	flock.free()

	# Testa criação na morte de criatura selvagem
	var c := _WildCreature.new()
	c.dna = _CreatureDNA.new()
	c.dna.species = _CreatureDNA.Species.TROTADOR
	root.add_child(c)
	c.call("_die", false)
	assert(c.state == _WildCreature.State.DEAD, "Criatura morre")
	assert(c._vultures != null, "Urubus gerados acima da carcaça como farol visual")

	c.call("_remove")
	print("  ✓ Urubus e ciclo da carcaça validados")
