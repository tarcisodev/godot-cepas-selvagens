extends SceneTree

## B17 / GDD-10: a natureza vai para o save — plantas (DNA, estágio, idade), bichos (DNA, idade,
## fome, sede), solo e clima voltam como estavam.

var _frame: int = 0

func _initialize() -> void:
	change_scene_to_file("res://scenes/world.tscn")

func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == 10:
		_run()
	return false

func _run() -> void:
	print("\n========================================================")
	print("🌱 TESTANDO O SAVE DA NATUREZA (B17 / GDD-10)")
	print("========================================================")
	var player := get_first_node_in_group("player")
	var save := root.get_node("SaveGame")
	var eco := get_first_node_in_group("ecosystem")
	var ecology := get_first_node_in_group("ecology")
	var weather := get_first_node_in_group("weather")
	assert(player and eco and ecology and weather, "Mundo com player, ecossistema, solo e clima")

	print("\n[1/2] Coletar o estado...")
	var plant := _first_mutable_plant()
	plant.stage = PlantBody.Stage.FLORIDA
	plant.age = 3.25
	var plant_pos := plant.global_position
	var plant_seed := plant.dna.dna_seed
	var wild := get_nodes_in_group("wild_creatures")[0] as WildCreature
	wild.hunger = 0.77
	wild.age_days = 9.5
	var wild_seed := wild.dna.dna_seed
	ecology.nutrients[100] = 0.91
	weather.humidity = 0.66
	RiverSystem.flood = 0.8
	var data: Dictionary = JSON.parse_string(JSON.stringify(save.collect(player)))
	assert(data.has("nature"), "Save tem a natureza")
	var n_plants: int = data.nature.plants.size()
	var n_wild: int = data.nature.wild.size()
	assert(n_plants > 50 and n_wild > 10, "Plantas (%d) e bichos (%d) no save" % [n_plants, n_wild])
	print("  ✓ %d plantas, %d bichos, solo e clima no save" % [n_plants, n_wild])

	print("\n[2/2] Mexer no mundo e restaurar...")
	for i in 5:
		var p := get_nodes_in_group("plants")[i] as Node
		p.remove_from_group("plants")
		p.queue_free()
	ecology.nutrients[100] = 0.1
	weather.humidity = 0.2
	RiverSystem.flood = 0.0
	save.apply_save(player, data)
	assert(get_nodes_in_group("plants").size() == n_plants, "Mesmo número de plantas")
	var wild_now := get_nodes_in_group("wild_creatures").filter(func(c): return c.is_alive())
	assert(wild_now.size() == n_wild, "Mesmo número de bichos")
	var back: PlantBody = null
	for p in get_nodes_in_group("plants"):
		if (p as PlantBody).dna.dna_seed == plant_seed and (p as PlantBody).position.distance_to(plant_pos) < 0.05:
			back = p
	assert(back != null and back.stage == PlantBody.Stage.FLORIDA and is_equal_approx(back.age, 3.25), "Planta volta com estágio e idade")
	var wback: WildCreature = null
	for c in wild_now:
		if c.dna.dna_seed == wild_seed:
			wback = c
	assert(wback != null and is_equal_approx(wback.hunger, 0.77) and is_equal_approx(wback.age_days, 9.5), "Bicho volta com fome e idade")
	assert(is_equal_approx(ecology.nutrients[100], 0.91), "Solo volta")
	assert(is_equal_approx(weather.humidity, 0.66) and is_equal_approx(RiverSystem.flood, 0.8), "Clima e cheia voltam")
	print("  ✓ Plantas, bichos, solo e clima restaurados")
	print("\n🎉 TODOS OS TESTES DO SAVE DA NATUREZA PASSARAM COM SUCESSO!")
	print("========================================================\n")
	quit(0)

func _first_mutable_plant() -> PlantBody:
	for p in get_nodes_in_group("plants"):
		if (p as PlantBody).stage != PlantBody.Stage.SEMENTE:
			return p
	return get_nodes_in_group("plants")[0]

