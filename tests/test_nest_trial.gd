extends SceneTree

## B37 / GDD-16 fase 6: Prova do Ninho. Oferenda de carne Íntegra, adulto que chega voando e só
## aceita quem ofereceu, roubo da oferenda, voo bravio (trancos e barra de queda), domado vira
## montaria própria marcada com Elo 50 e você segue voando nela; caiu, a queda é de verdade.

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const DT: float = 1.0 / 30.0

var _started: bool = false

func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false

func _run() -> void:
	print("\n========================================================")
	print("🪶 TESTANDO A PROVA DO NINHO (B37)")
	print("========================================================")
	test_brave_flight()
	var player := _player()
	var thief := _player()
	var eco := EcosystemSpawner.new()
	for prop in ["trotador_herds", "saltarelos", "planadores", "raias", "lambari_schools", "trees", "bushes", "cepas", "mushrooms", "pinheira_groves"]:
		eco.set(prop, 0)
	root.add_child(eco)
	var nest := PlanadorNest.new()
	nest.position = Vector3(10, 6, 10)
	eco.add_child(nest)
	test_offering(player, thief, eco, nest)
	test_trial_tamed(player, eco, nest)
	test_trial_thrown(player, eco)
	print("\n🎉 TODOS OS TESTES DA PROVA DO NINHO PASSARAM COM SUCESSO!")
	print("========================================================\n")
	quit(0)

func _player() -> Player:
	var p: Player = PlayerScene.instantiate() as Player
	root.add_child(p)
	p._setup_components()
	p.set_physics_process(false)
	p.remove_from_group("player")
	return p

## Avança o adulto (piloto automático) até `cond` ou o tempo acabar; devolve os segundos
func _run_adult(nest: PlanadorNest, cond: Callable, max_s: float) -> float:
	var t := 0.0
	while not cond.call() and t < max_s:
		var a := nest.adult
		if a and is_instance_valid(a):
			a._physics_process(DT)
		t += DT
	return t

func test_brave_flight() -> void:
	print("\n[1/4] Voo bravio (trancos e barra de queda)...")
	# Quem responde certo a todo tranco aguenta os 20 s
	var good := BraveFlight.new(7)
	var r := &"voando"
	while r == &"voando":
		r = good.step(DT, -good.jolt)
	assert(r == &"domado" and good.fall < 0.3 and good.jolts >= 8, "Respondendo certo: domado (%d trancos, queda %.2f)" % [good.jolts, good.fall])
	# Quem não faz nada cai antes do fim
	var idle := BraveFlight.new(7)
	r = &"voando"
	while r == &"voando":
		r = idle.step(DT, Vector2.ZERO)
	assert(r == &"caiu" and idle.time < BraveFlight.DURATION, "Parado: cai em %.1f s" % idle.time)
	# Empurrar junto com o tranco derruba mais rápido
	var wrong := BraveFlight.new(7)
	r = &"voando"
	while r == &"voando":
		r = wrong.step(DT, wrong.jolt)
	assert(r == &"caiu" and wrong.time < idle.time, "Empurrando junto: cai antes (%.1f s)" % wrong.time)
	var hurt := BraveFlight.new(1)
	hurt.hurt()
	hurt.hurt()
	hurt.hurt()
	assert(hurt.step(DT, Vector2.ZERO) == &"caiu", "Três golpes no voo: cai")
	assert(good.hud_text().contains("Queda"), "HUD mostra a barra")
	var shown := BraveFlight.new(3)
	while shown.jolt == Vector2.ZERO:
		shown.step(DT, Vector2.ZERO)
	assert(shown.hud_text().contains(BraveFlight.ARROWS[shown.jolt]) and shown.hud_text().contains(BraveFlight.KEYS[-shown.jolt]), "HUD mostra o tranco e a tecla oposta: %s" % shown.hud_text())
	print("  ✓ Certo: domado (queda %.2f) · parado: cai em %.1f s · junto: %.1f s" % [good.fall, idle.time, wrong.time])

func test_offering(player: Player, thief: Player, eco: EcosystemSpawner, nest: PlanadorNest) -> void:
	print("\n[2/4] Oferenda, chegada e roubo...")
	player.inventory.add_material(&"carne_crua", 2, 2)
	assert(nest.offer(player) == &"sem_carne" and nest.state == PlanadorNest.State.READY, "Carne comum não serve")
	player.inventory.add_material(&"carne_crua", 2, 3, [&"integro"])
	for i in EcosystemSpawner.MAX_OWNED:
		eco.add_owned_mount(CreatureDNA.randomized(CreatureDNA.Species.TROTADOR, 60 + i))
	assert(nest.offer(player) == &"estabulo_cheio", "Estábulo cheio: nem oferece")
	eco.restore_owned([])
	assert(nest.offer(player) == &"ok" and nest.state == PlanadorNest.State.OFFERED, "Ofereceu")
	assert(player.inventory.get_stacks(&"carne_crua").filter(func(s): return s.traits.has(&"integro"))[0].amount == 1, "Gastou uma carne Íntegra")
	var a := nest.adult
	assert(a != null and a.global_position.distance_to(nest.global_position) > 30.0 and a.global_position.y > nest.global_position.y + 15.0, "O adulto vem de longe e do alto")
	# Outro jogador rouba a oferenda antes de ele chegar
	nest.talk_to(thief)
	assert(nest.state == PlanadorNest.State.READY and nest.adult == null, "Roubaram: ele deu meia-volta")
	assert(thief.inventory.get_stacks(&"carne_crua").any(func(s): return s.traits.has(&"integro")), "O ladrão levou a carne")
	for i in 400:
		if is_instance_valid(a):
			a._physics_process(DT)
	assert(not is_instance_valid(a) or a.is_queued_for_deletion(), "E sumiu no céu")
	# Oferece de novo e espera ele pousar
	assert(nest.offer(player) == &"ok", "Ofereceu de novo")
	var t := _run_adult(nest, func(): return nest.state == PlanadorNest.State.WAITING, 15.0)
	assert(nest.state == PlanadorNest.State.WAITING and not nest.adult.airborne, "Chegou voando e pousou (%.1f s)" % t)
	assert(t > 2.0, "Levou tempo para chegar: nada de teleporte")
	nest.adult.begin_mount(thief)
	assert(nest.adult._channel_player == null, "Só aceita quem ofereceu")
	print("  ✓ Só carne Íntegra, com lugar no estábulo; roubo faz ele ir embora; chegou em %.1f s" % t)

func test_trial_tamed(player: Player, eco: EcosystemSpawner, nest: PlanadorNest) -> void:
	print("\n[3/4] Voo bravio até domar...")
	var a := nest.adult
	nest.talk_to(player)
	assert(a._channel_player == player, "Montar leva os 1,5 s de sempre")
	a._channel_player = null
	a.mount(player)
	assert(nest.state == PlanadorNest.State.TRIAL and nest.flight != null, "Montou: começou o voo bravio")
	nest.input_source = func() -> Vector2: return -nest.flight.jolt if nest.flight else Vector2.ZERO
	var peak := 0.0
	var t := 0.0
	while nest.state == PlanadorNest.State.TRIAL and t < 30.0:
		a._physics_process(DT)
		if is_instance_valid(a):
			peak = maxf(peak, a.global_position.y)
		t += DT
	assert(nest.state == PlanadorNest.State.EMPTY, "Aguentou: domado e o ninho ficou vazio")
	assert(peak > nest.global_position.y + 10.0, "Voou alto (pico %.1f m)" % peak)
	assert(eco.owned.size() == 1 and eco.owned[0].species == CreatureDNA.Species.PLANADOR, "Virou montaria própria")
	var b: MountBond = eco.bonds[0]
	assert(b.elo == 50.0 and b.marked and not b.accepts(false), "Elo 50 e marcada (só aceita você)")
	var m: Mount = eco._owned_nodes[0]
	assert(player.mounted_on == m and m.airborne and m.global_position.y > nest.global_position.y + 5.0, "Você segue voando nele")
	assert(nest.offer(player) == &"ocupado" and nest.regrow_day == MountBond.today() + PlanadorNest.REGROW_DAYS, "Vazio até o próximo filhote crescer")
	nest.input_source = Callable()
	m.dismount()
	player.end_fall()
	print("  ✓ Domado em %.1f s, pico %.1f m; Elo 50, marcado; ninho vazio por %d dias" % [t, peak, PlanadorNest.REGROW_DAYS])

func test_trial_thrown(player: Player, eco: EcosystemSpawner) -> void:
	print("\n[4/4] Voo bravio: derrubado...")
	var nest := PlanadorNest.new()
	nest.position = Vector3(-30, 6, -30)
	eco.add_child(nest)
	player.inventory.add_material(&"carne_crua", 1, 3, [&"integro"])
	assert(nest.offer(player) == &"ok", "Ofereceu em outro ninho")
	_run_adult(nest, func(): return nest.state == PlanadorNest.State.WAITING, 15.0)
	var a := nest.adult
	a.mount(player)
	nest.input_source = func() -> Vector2: return Vector2.ZERO
	var t := 0.0
	while nest.state == PlanadorNest.State.TRIAL and t < 30.0:
		a._physics_process(DT)
		t += DT
	assert(player.mounted_on == null and player.is_skydiving, "Caiu de verdade (queda livre)")
	assert(player.global_position.y > nest.global_position.y + 3.0, "Do alto")
	assert(nest.state == PlanadorNest.State.READY and nest.adult == null, "Ele vai embora; o ninho aceita nova oferenda")
	assert(eco.owned.size() == 1, "Não ganhou montaria")
	player.end_fall()
	print("  ✓ Sem segurar os trancos: derrubado em %.1f s, do alto" % t)
