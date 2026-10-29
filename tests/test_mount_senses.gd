extends SceneTree

## B37 / GDD-16 fase 5: sentidos da Companheira. [Q] montado: Faro (Parceira) deixa rastros dos
## bichos no raio por 20 s; Olho de caça (plena) marca as partes que quebram e a Vida (%) das presas
## perto por 8 s. Recarga de 45 s; não dá dano.

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")

var _started: bool = false

func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false

func _run() -> void:
	print("\n========================================================")
	print("👃 TESTANDO FARO E OLHO DE CAÇA (B37)")
	print("========================================================")
	var player: Player = PlayerScene.instantiate() as Player
	root.add_child(player)
	player._setup_components()
	player.set_physics_process(false)
	var eco := EcosystemSpawner.new()
	for prop in ["trotador_herds", "saltarelos", "planadores", "raias", "lambari_schools", "trees", "bushes", "cepas", "mushrooms", "pinheira_groves"]:
		eco.set(prop, 0)
	root.add_child(eco)
	var dna := CreatureDNA.randomized(CreatureDNA.Species.TROTADOR, 51)
	var bond := MountBond.create(dna, &"cria", 0)
	assert(eco.add_owned_mount(dna, bond), "Montaria própria")
	var m: Mount = eco._owned_nodes[0]
	await process_frame
	m.global_position = Vector3(0, 0, 0)
	assert(m.senses != null, "Montaria própria tem sentidos")
	# Bichos: um perto (20 m), um no raio do faro (50 m), um longe (80 m) e uma fera com chifre perto
	var near := eco._add_wild(CreatureDNA.Species.TROTADOR, Vector3(20, 0, 0), 2.0)
	var mid := eco._add_wild(CreatureDNA.Species.SALTARELO, Vector3(0, 0, 50), 2.0)
	var far := eco._add_wild(CreatureDNA.Species.TROTADOR, Vector3(-80, 0, 0), 2.0)
	var boss := BeastFighter.new()
	boss.config = BeastFighter.rinolito_anciao()
	boss.position = Vector3(0, 0, -15)
	root.add_child(boss)
	boss.set_physics_process(false)
	for c in [near, mid, far]:
		c.set_physics_process(false)
		c.set_process(false)
	near.pools.take_damage(near.stats.get_stat(&"max_health") * 0.85)
	m.mount(player)

	print("\n[1/3] Quem pode farejar...")
	assert(m.senses.use() == &"sem_elo" and get_nodes_in_group("scent_marks").is_empty(), "Mansa (Elo 40) não fareja")
	m.bond.elo = 60.0
	assert(m.senses.use() == &"sem_elo", "Parceira que não é Companheira também não")
	assert(eco.set_companion(m), "Vira Companheira")
	print("  ✓ Só a Companheira Parceira+ empresta o faro")

	print("\n[2/3] Faro (Parceira)...")
	var found := m.senses.sniff()
	assert(found.has(near) and found.has(mid) and found.has(boss) and not found.has(far), "Raio de 60 m: acha 3, não o de 80 m")
	assert(m.senses.use() == &"ok", "Farejou")
	var trails := get_nodes_in_group("scent_trails")
	assert(trails.size() == 3, "Três rastros no chão (%d)" % trails.size())
	var prints: int = trails[0].find_children("*", "MeshInstance3D", false, false).size()
	assert(prints == MountSenses.PRINTS, "Cada rastro tem %d pegadas" % MountSenses.PRINTS)
	assert(trails.any(func(t): return (t.find_children("*", "Label3D", false, false)[0] as Label3D).text.contains("Saltarelo")), "O rastro diz de quem é")
	assert(get_nodes_in_group("scent_eyes").is_empty(), "Parceira não tem Olho de caça")
	assert(m.senses.use() == &"recarga", "Recarga de 45 s")
	print("  ✓ Rastros de 3 bichos no raio; recarga")

	print("\n[3/3] Olho de caça (plena)...")
	m.bond.elo = 80.0
	m.senses.cooldown = 0.0
	for t in get_nodes_in_group("scent_marks"):
		t.free()
	assert(m.senses.use() == &"ok", "Farejou de novo")
	var eyes := get_nodes_in_group("scent_eyes")
	assert(eyes.size() == 2, "Marca as presas a até 25 m: o Trotador ferido e o Rinolito (%d)" % eyes.size())
	var near_eye: Node = eyes.filter(func(e): return e.get_parent() == near)[0]
	var hp_label: Label3D = near_eye.find_children("*", "Label3D", false, false)[0]
	assert(hp_label.text == "❤ 15%", "Mostra a Vida do ferido: %s" % hp_label.text)
	var boss_eye: Node = eyes.filter(func(e): return e.get_parent() == boss)[0]
	var labels: Array = boss_eye.find_children("*", "Label3D", false, false).map(func(l): return l.text)
	assert(labels.has("◎ Chifre") and labels.has("◎ Carapaça"), "Marca chifre e carapaça do Rinolito: %s" % [labels])
	assert(near.pools.current_health > 0.0 and is_equal_approx(near.pools.current_health / near.stats.get_stat(&"max_health"), 0.15), "Farejar não dá dano")
	# Somem sozinhas: o Olho em 8 s (aqui, pelo timer)
	var timer: Timer = boss_eye.find_children("*", "Timer", false, false)[0]
	assert(is_equal_approx(timer.wait_time, MountSenses.EYE_TIME), "Olho dura 8 s")
	print("  ✓ Vida %s e partes (%s) marcadas; sem dano" % [hp_label.text, ", ".join(labels.filter(func(l): return l.begins_with("◎")))])
	print("\n🎉 TODOS OS TESTES DO FARO PASSARAM COM SUCESSO!")
	print("========================================================\n")
	quit(0)
