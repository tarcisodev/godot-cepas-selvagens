extends SceneTree

## B13 / GDD-09: DNA de criaturas e plantas, corpos procedurais, montarias e roda rápida de itens.

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")

var _started: bool = false

func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false

func _run() -> void:
	print("\n========================================================")
	print("🦌 TESTANDO FAUNA, FLORA E MONTARIAS PROCEDURAIS (B13)")
	print("========================================================")
	test_creature_dna()
	test_bodies()
	await test_mount()
	test_quick_wheel()
	print("\n🎉 TODOS OS TESTES DE FAUNA, FLORA E MONTARIAS PASSARAM COM SUCESSO!")
	print("========================================================\n")
	quit(0)

func test_creature_dna() -> void:
	print("\n[1/4] DNA de criatura: determinismo, porte, chifre e cruzamento...")
	var a := CreatureDNA.randomized(CreatureDNA.Species.TROTADOR, 42)
	var b := CreatureDNA.randomized(CreatureDNA.Species.TROTADOR, 42)
	assert(a.alleles == b.alleles and a.base_color == b.base_color, "Mesma seed = mesmo bicho")
	a.alleles["porte"] = ["T", "T"]
	assert(is_equal_approx(a.size_factor(), 1.0), "TT = 100%")
	a.alleles["porte"] = ["T", "t"]
	assert(is_equal_approx(a.size_factor(), 0.75), "Tt = 75%")
	a.alleles["porte"] = ["t", "t"]
	assert(is_equal_approx(a.size_factor(), 0.5), "tt = 50%")
	a.alleles["chifre"] = ["C", "c"]
	assert(a.has_horns(), "Chifre é dominante")
	a.alleles["chifre"] = ["c", "c"]
	assert(not a.has_horns(), "cc não tem chifre")
	assert(not a.is_mutant(), "Sem * não é mutante")
	a.alleles["padrao"] = ["*", "p"]
	assert(a.is_mutant() and a.coat_color() != a.base_color, "Mutante ganha cor iridescente")
	var mutants := 0
	var p1 := CreatureDNA.randomized(CreatureDNA.Species.TROTADOR, 1)
	var p2 := CreatureDNA.randomized(CreatureDNA.Species.TROTADOR, 2)
	for i in 400:
		if CreatureDNA.cross(p1, p2, i).is_mutant():
			mutants += 1
	# 6 alelos × 3% ≈ 17% de filhos com pelo menos uma mutação
	assert(mutants > 35 and mutants < 110, "Taxa de mutação perto de 3%% por alelo (%d/400 filhos)" % mutants)
	var pd := PlantDNA.randomized(PlantDNA.Kind.CEPA, 9)
	assert(pd.leaf_color == PlantDNA.randomized(PlantDNA.Kind.CEPA, 9).leaf_color, "Planta também é determinística")
	print("  ✓ Determinismo, porte incompleto, chifre dominante, mutação (%d/400)" % mutants)

func test_bodies() -> void:
	print("\n[2/4] Corpos procedurais de todas as espécies e plantas...")
	for sp in CreatureDNA.Species.values():
		var body := CreatureBody.new()
		body.dna = CreatureDNA.randomized(sp, 7)
		root.add_child(body)
		assert(body.get_child_count() > 0 and body.saddle != null, "%s monta corpo e sela" % body.dna.species_name())
		body.animate(0.016, 3.0, 1.0, true)
		body.free()
	for k in PlantDNA.Kind.values():
		var plant := PlantBody.new()
		plant.dna = PlantDNA.randomized(k, 3)
		root.add_child(plant)
		var mesh_inst := plant.find_children("*", "MeshInstance3D", false, false)[0] as MeshInstance3D
		assert(mesh_inst and mesh_inst.mesh and mesh_inst.mesh.get_surface_count() == 1, "%s vira uma malha só" % plant.dna.display_name())
		plant.free()
	print("  ✓ 5 espécies e 4 tipos de planta montados")

func test_mount() -> void:
	print("\n[3/4] Montaria: 1,5 s parado, dano cancela, montar e desmontar...")
	var player: Player = PlayerScene.instantiate() as Player
	root.add_child(player)
	player._setup_components()
	player.set_physics_process(false) # sem chão no teste: não deixa o player cair
	var m := Mount.new()
	m.dna = CreatureDNA.randomized(CreatureDNA.Species.TROTADOR, 5)
	m.kind = Mount.Kind.LAND
	root.add_child(m)
	player.global_position = m.global_position + Vector3(1.0, 0, 0)

	m.talk_to(player)
	player.pools.current_health -= 5.0
	await create_timer(0.3).timeout
	assert(player.mounted_on == null, "Dano durante a montaria cancela")

	m.talk_to(player)
	await create_timer(Mount.MOUNT_TIME + 0.4).timeout
	assert(player.mounted_on == m and m.rider == player, "Parado por 1,5 s: montado")
	m.dismount()
	assert(player.mounted_on == null and m.rider == null, "[E] desmonta")
	m.mount(player)
	player.pools.poise_broken.emit()
	assert(player.mounted_on == null, "Postura quebrada derruba da montaria")
	m.free()
	player.free()
	print("  ✓ Canal de montar, cancelamento por dano, desmontar e derrubada")

func test_quick_wheel() -> void:
	print("\n[4/4] Roda rápida: trocar e usar consumível...")
	var player: Player = PlayerScene.instantiate() as Player
	root.add_child(player)
	player._setup_components()
	var wheel := QuickItemWheel.new()
	wheel.player = player
	root.add_child(wheel)
	assert(wheel.consumable_ids().is_empty(), "Sem consumíveis, roda vazia")
	player.inventory.add_material(&"pocao", 2)
	player.inventory.add_material(&"carne_bem_passada", 1)
	player.inventory.add_material(&"madeira", 5)
	var ids := wheel.consumable_ids()
	assert(ids == [&"pocao", &"carne_bem_passada"], "Só consumíveis, cura antes de vigor (saiu %s)" % [ids])
	wheel.cycle(1)
	assert(wheel.selected_id == &"pocao", "Primeira troca escolhe o primeiro")
	wheel.cycle(1)
	assert(wheel.selected_id == &"carne_bem_passada", "Próximo")
	wheel.cycle(-1)
	assert(wheel.selected_id == &"pocao", "Anterior")
	assert(not wheel.use_selected(), "Vida cheia: não gasta a poção")
	player.pools.current_health = 10.0
	assert(wheel.use_selected() and player.inventory.get_material_count(&"pocao") == 1, "Usa uma poção")
	assert(Engine.time_scale == 1.0, "A roda não mexe no tempo")
	wheel.free()
	player.free()
	print("  ✓ Lista, anterior/próximo, uso e tempo normal")
