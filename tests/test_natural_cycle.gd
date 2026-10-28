extends SceneTree

## B15 / GDD-10: ciclo da água, cheia, lua de 28 dias, solo, vida das plantas e necessidades dos bichos.

const _NatureProps = preload("res://scripts/nature_props.gd")
const _PlantBody = preload("res://scripts/systems/plant_body.gd")
const _PlantDNA = preload("res://scripts/data/plant_dna.gd")

var _started: bool = false

func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false

func _run() -> void:
	print("\n========================================================")
	print("🌦️ TESTANDO O CICLO NATURAL (B15 / GDD-10)")
	print("========================================================")
	test_weather_and_flood()
	test_moon()
	test_plant_life()
	test_soil_and_seeds()
	test_creature_needs()
	test_nature_props_procedural_trees()
	print("\n🎉 TODOS OS TESTES DO CICLO NATURAL PASSARAM COM SUCESSO!")
	print("========================================================\n")
	quit(0)

func test_weather_and_flood() -> void:
	print("\n[1/5] Sol → umidade → nuvem → chuva → cheia → vazão...")
	var w := WeatherSystem.new()
	var ticks_per_day := int(300.0 / WeatherSystem.TICK)
	var hour := 8.0
	var rained := false
	var max_flood := 0.0
	var peak_humidity := 0.0
	for i in ticks_per_day * 5:
		w.step(hour)
		peak_humidity = maxf(peak_humidity, w.humidity)
		rained = rained or w.rain > 0.2
		max_flood = maxf(max_flood, RiverSystem.flood)
		hour = fposmod(hour + 24.0 / ticks_per_day, 24.0)
	assert(peak_humidity > 0.55, "Sol evapora o rio e sobe a umidade")
	assert(rained, "Em 5 dias as nuvens carregam e chove")
	assert(max_flood > 0.3, "Chuva enche o rio (cheia máx. %.2f m)" % max_flood)
	# Sem chuva, a vazão esvazia a cheia
	w.rain = 0.0
	w.clouds = 0.0
	w.humidity = 0.3
	for i in 300:
		w.step(3.0)
	assert(RiverSystem.flood < 0.05, "Vazão esvazia a cheia")
	# Cheia sobe a água e alaga a várzea
	RiverSystem.flood = 1.0
	var z := 30.0
	var cx := RiverSystem.get_river_center_x(z)
	var hw := RiverSystem.get_water_half_width(z)
	assert(is_equal_approx(RiverSystem.get_water_height(z), RiverSystem.LOWER_WATER_Y + 1.0), "Nível sobe com a cheia")
	assert(RiverSystem.is_in_water(Vector3(cx + hw * 1.8, RiverSystem.LOWER_WATER_Y + 0.5, z)), "Várzea alagada conta como água")
	RiverSystem.flood = 0.0
	assert(not RiverSystem.is_in_water(Vector3(cx + hw * 1.8, RiverSystem.LOWER_WATER_Y + 0.5, z)), "Na vazante a várzea é terra")
	w.free()
	print("  ✓ Umidade %.2f, choveu, cheia %.2f m, vazão e várzea" % [peak_humidity, max_flood])

func test_moon() -> void:
	print("\n[2/5] Lua de 28 dias...")
	var sun: DirectionalLight3D = preload("res://scripts/day_night_cycle.gd").new()
	sun.day_count = 0
	sun.current_time_hours = 0.0
	assert(sun.moon_illumination() < 0.01 and sun.moon_phase_name().contains("nova"), "Dia 0: lua nova")
	sun.day_count = 14
	assert(sun.moon_illumination() > 0.99 and sun.moon_phase_name().contains("cheia"), "Dia 14: lua cheia")
	sun.day_count = 7
	assert(sun.moon_phase_name().contains("Quarto crescente"), "Dia 7: quarto crescente")
	sun.day_count = 28
	assert(sun.moon_illumination() < 0.01, "Dia 28: nova de novo (ciclo de 28 dias)")
	sun.day_count = 14
	sun.current_time_hours = 23.0
	sun._update_sun_position_and_lighting()
	var full_light := sun.light_energy
	sun.day_count = 0
	sun._update_sun_position_and_lighting()
	assert(full_light > sun.light_energy * 3.0, "Noite de lua cheia é bem mais clara que de lua nova")
	sun.free()
	print("  ✓ Nova → quarto → cheia → nova em 28 dias; luar segue a fase")

func test_plant_life() -> void:
	print("\n[3/5] Planta: nasce, cresce, flore, frutifica, semeia, morre...")
	var p := PlantBody.new()
	p.dna = PlantDNA.randomized(PlantDNA.Kind.CEPA, 5)
	p.stage = PlantBody.Stage.SEMENTE
	root.add_child(p)
	var good := {"moisture": 0.8, "nutrients": 0.8}
	var seen := {}
	var seeds := 0
	for i in 400:
		var r := p.life_tick(0.01, good, true)
		seen[p.stage] = true
		if r.event == "seeds":
			seeds += 1
		if r.event == "died":
			break
	assert(seen.size() == 6, "Passou por todos os estágios (viu %d)" % seen.size())
	assert(seeds >= 1, "Frutificou e soltou sementes")
	# Sem água: para de crescer e morre de penúria
	var dry := PlantBody.new()
	dry.dna = PlantDNA.randomized(PlantDNA.Kind.ARBUSTO, 6)
	dry.stage = PlantBody.Stage.JOVEM
	root.add_child(dry)
	var died := false
	for i in 300:
		var r := dry.life_tick(0.01, {"moisture": 0.05, "nutrients": 0.5}, true)
		assert(dry.stage == PlantBody.Stage.JOVEM, "Sem água não cresce")
		if r.event == "died":
			died = true
			break
	assert(died, "Sem água morre de penúria")
	# Noite: não cresce
	var night := PlantBody.new()
	night.dna = PlantDNA.randomized(PlantDNA.Kind.ARBUSTO, 7)
	night.stage = PlantBody.Stage.BROTO
	root.add_child(night)
	for i in 50:
		night.life_tick(0.05, good, false)
	assert(night.stage == PlantBody.Stage.BROTO, "No escuro não cresce")
	p.free()
	dry.free()
	night.free()
	print("  ✓ 6 estágios, sementes, penúria e noite")

func test_soil_and_seeds() -> void:
	print("\n[4/5] Solo, semeadura e mutação por nutriente...")
	var eco := Ecology.new()
	root.add_child(eco)
	var spot := Vector3(-60.0, 0.0, 120.0)
	var i := eco.cell_index(spot.x, spot.z)
	assert(i >= 0, "Célula dentro do mapa")
	var before := eco.nutrients[i]
	eco.deposit(spot, 0.3)
	assert(eco.nutrients[i] > before, "Bicho/planta morta devolve nutriente")
	# Mutação: solo pobre ~3%, solo saturado ~12%
	var parent := PlantDNA.randomized(PlantDNA.Kind.CEPA, 11)
	var poor := 0
	var rich := 0
	for k in 3000:
		if PlantDNA.seed_of(parent, k, Ecology.MUTATION_BASE).mutant:
			poor += 1
		if PlantDNA.seed_of(parent, k + 5000, Ecology.MUTATION_RICH).mutant:
			rich += 1
	assert(rich > poor * 2, "Solo rico gera bem mais mutantes (%d vs %d)" % [rich, poor])
	var child := eco.sow(parent, spot)
	assert(child != null and child.stage == PlantBody.Stage.SEMENTE, "Semente brota em terra livre")
	var village := eco.sow(parent, Vector3(1.5, 0, 4.5))
	assert(village == null, "Não brota dentro da vila")
	eco.free()
	print("  ✓ Nutriente volta ao solo; mutantes %d (pobre) vs %d (rico) em 3000" % [poor, rich])

func test_creature_needs() -> void:
	print("\n[5/5] Bicho: sede leva ao rio, fome leva à comida, envelhece e morre...")
	var c := WildCreature.new()
	c.dna = CreatureDNA.randomized(CreatureDNA.Species.TROTADOR, 3)
	c.position = Vector3(RiverSystem.get_river_center_x(40.0) + 25.0, 0, 40.0)
	root.add_child(c)
	c.thirst = 0.9
	c.hunger = 0.0
	c._live(0.016)
	assert(c._need == "drink", "Com sede vai beber")
	var bank_x := RiverSystem.get_river_center_x(40.0) + RiverSystem.get_water_half_width(40.0) + 0.9
	assert(absf(c._target.x - bank_x) < 0.5, "Alvo é a margem do rio")
	c.global_position = c._target
	for k in 300:
		c._live(0.016)
	assert(c.thirst < 0.1 and c.body.head_down == false, "Bebeu e levantou a cabeça")
	c.hunger = 0.9
	c._need = ""
	c._live(0.016)
	assert(c._need == "graze" or c._need == "eat", "Com fome procura comida")
	c.age_days = c.lifespan_days + 0.1
	c._live(0.016)
	assert(c.state == WildCreature.State.DEAD, "Velhice: morre e vira corpo")
	c.free()
	print("  ✓ Bebe na margem, come/pasta e morre de velhice")

func test_nature_props_procedural_trees() -> void:
	print("\n[6/6] NatureProps: árvores 100% procedurais (PlantBody)...")
	var np := _NatureProps.new()
	np.riparian_tree_count = 30
	np.hill_tree_count = 30
	np.bush_count = 0
	np.rock_count = 0
	np.mushroom_cluster_count = 0
	root.add_child(np)

	var plant_bodies: Array[_PlantBody] = []
	for child in np.get_children():
		if child is _PlantBody:
			plant_bodies.append(child)

	assert(plant_bodies.size() >= 10, "Árvores procedurais foram instanciadas no mundo (%d encontradas)" % plant_bodies.size())
	for plant in plant_bodies:
		assert(plant.dna != null, "Árvore possui PlantDNA válido")
		assert(plant.dna.kind == _PlantDNA.Kind.ARVORE or plant.dna.kind == _PlantDNA.Kind.PINHEIRA, "Tipo de planta é ARVORE ou PINHEIRA")
		assert(plant.is_in_group("plants"), "Registrada no grupo 'plants'")
		var has_static_body := false
		for subchild in plant.get_children():
			if subchild is StaticBody3D:
				has_static_body = true
				break
		assert(has_static_body, "Árvore procedural possui StaticBody3D para colisão no tronco")

	# Testar chamada legada de fallback _build_tree
	var test_tree_pos := Vector3(10.0, 0.0, 10.0)
	np._build_tree(test_tree_pos)
	var last_child = np.get_child(np.get_child_count() - 1)
	assert(last_child is _PlantBody, "_build_tree instancia PlantBody proceduralmente")
	assert(last_child.dna != null and last_child.dna.kind == _PlantDNA.Kind.ARVORE, "Fallback cria árvore procedural")

	np.free()
	print("  ✓ NatureProps gera 100% de árvores procedurais com PlantBody, PlantDNA e colisão")

