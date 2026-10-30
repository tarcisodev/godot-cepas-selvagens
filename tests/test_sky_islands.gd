extends SceneTree

## B39 / GDD-18 fases 1 e 2: agenda do céu (seed + relógio único, igual para todos), forma
## procedural por raridade, ilhas no mundo e a Corrente de vento que leva a voadora acima do teto
## de 40 m; em cima da ilha ela é o chão, embaixo a base não se atravessa.

const DT: float = 1.0 / 30.0
const SEED: int = 2026
const R := SkyIslandSchedule.Rarity

var _started: bool = false

func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false

func _run() -> void:
	print("\n========================================================")
	print("☁️ TESTANDO AS ILHAS VOADORAS (B39)")
	print("========================================================")
	test_schedule()
	test_events()
	var field: SkyIslandField = await test_shape_and_field()
	await test_current_and_ceiling(field)
	print("\n🎉 TODOS OS TESTES DAS ILHAS VOADORAS PASSARAM COM SUCESSO!")
	print("========================================================\n")
	quit(0)

func _by_rarity(list: Array[Dictionary], rarity: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in list:
		if i.rarity == rarity:
			out.append(i)
	return out

func test_schedule() -> void:
	print("\n[1/4] Agenda: mesma seed e hora = mesmo céu; comuns fixas, incomuns giram, raras trocam...")
	var a := SkyIslandSchedule.islands_at(SEED, 1.3)
	var b := SkyIslandSchedule.islands_at(SEED, 1.3)
	assert(a.size() == b.size(), "Mesma agenda")
	for i in a.size():
		assert(a[i].id == b[i].id and a[i].center.is_equal_approx(b[i].center), "Mesma ilha no mesmo lugar: %s" % a[i].id)
	var other := SkyIslandSchedule.islands_at(SEED + 1, 1.3)
	assert(not other[0].center.is_equal_approx(a[0].center), "Outra seed, outro céu")
	assert(_by_rarity(a, R.COMUM).filter(func(i): return i.nest).size() == SkyIslandSchedule.NEST_COMMONS, "Ilhotas com ninho")
	assert(_by_rarity(a, R.COMUM).size() == 6 and _by_rarity(a, R.INCOMUM).size() == 3 and _by_rarity(a, R.RARA).size() == 2, "6 comuns, 3 incomuns, 2 raras")
	# Alturas e tamanhos pela raridade; nada dentro da vila
	for isl in a:
		var spec: Dictionary = SkyIslandSchedule.SPECS[isl.rarity]
		if isl.phase == &"firme":
			assert(isl.center.y >= spec.height.x and isl.center.y <= spec.height.y, "%s na faixa de altura (%.1f)" % [isl.id, isl.center.y])
		assert(isl.radius * 2.0 >= spec.diam.x - 0.01 and isl.radius * 2.0 <= spec.diam.y + 0.01, "%s no tamanho" % isl.id)
		assert(not CityHub.in_village(isl.center.x, isl.center.z, 0.0), "%s fora da vila" % isl.id)
	# Comuns fixas e sem se encostar
	var later := SkyIslandSchedule.islands_at(SEED, 23.7)
	var commons := _by_rarity(a, R.COMUM)
	for i in commons.size():
		assert(commons[i].center.is_equal_approx(_by_rarity(later, R.COMUM)[i].center), "Comum fixa")
		for j in range(i + 1, commons.size()):
			var d := Vector2(commons[i].center.x, commons[i].center.z).distance_to(Vector2(commons[j].center.x, commons[j].center.z))
			assert(d >= commons[i].radius + commons[j].radius, "Comuns não se encostam")
	# Incomum: mesma ilha (id), outro ponto da órbita, sempre perto do ponto fixo
	var u0 := _by_rarity(a, R.INCOMUM)[0]
	var u1 := _by_rarity(SkyIslandSchedule.islands_at(SEED, 2.3), R.INCOMUM)[0]
	assert(u0.id == u1.id and not u0.center.is_equal_approx(u1.center), "Incomum gira")
	assert(Vector2(u0.center.x, u0.center.z).distance_to(Vector2(u1.center.x, u1.center.z)) <= SkyIslandSchedule.ORBIT_RADIUS * 2.0 + 0.01, "Órbita curta")
	# Rara: troca de lugar e de forma a cada 2 dias; as duas vagas ficam em metades opostas
	var r0 := _by_rarity(SkyIslandSchedule.islands_at(SEED, 0.5), R.RARA)
	var r1 := _by_rarity(SkyIslandSchedule.islands_at(SEED, 2.5), R.RARA)
	assert(r0[0].id != r1[0].id, "Rara troca de lugar")
	assert(r0[0].center.x <= 0.0 and r0[1].center.x >= 0.0, "Raras em metades opostas")
	# Volumes de raridades diferentes nunca se cruzam (faixas de altura com folga)
	for x in SkyIslandSchedule.SPECS:
		if x == R.MITICA:
			continue
		var lo: Dictionary = SkyIslandSchedule.SPECS[x]
		var hi: Dictionary = SkyIslandSchedule.SPECS[x + 1]
		assert(lo.height.y + lo.relief < hi.height.x - SkyIslandShape.max_drop(), "Faixa %d abaixo da %d" % [x, x + 1])
	print("  ✓ %d ilhas no dia 1,3; comuns fixas; incomum gira; rara troca de lugar" % a.size())

func test_events() -> void:
	print("\n[2/4] Lendária e mítica surgem, duram e afundam pelo relógio...")
	var legend_time := 0.0
	var myth_windows := 0
	var was_myth := false
	var saw_announce_before_rise := false
	var saw_sink := false
	var step := 0.002
	var d := 0.0
	var last_phase := &""
	while d < 42.0:
		var list := SkyIslandSchedule.islands_at(SEED, d)
		var legends := _by_rarity(list, R.LENDARIA)
		var myths := _by_rarity(list, R.MITICA)
		assert(legends.size() <= 1 and myths.size() <= 1, "No máximo uma de cada")
		if not legends.is_empty():
			legend_time += step
		if not myths.is_empty():
			var m: Dictionary = myths[0]
			if not was_myth:
				myth_windows += 1
				assert(m.phase == &"anunciada" and not m.solid, "Mítica começa só anunciada (coluna de luz)")
			if last_phase == &"anunciada" and m.phase == &"surgindo":
				saw_announce_before_rise = true
			if m.phase == &"afundando":
				saw_sink = true
				assert(m.center.y < SkyIslandSchedule.SPECS[R.MITICA].height.y, "Afundando desce")
			last_phase = m.phase
		was_myth = not myths.is_empty()
		d += step
	assert(myth_windows == 6, "Uma mítica a cada 7 dias: %d em 42" % myth_windows)
	assert(saw_announce_before_rise and saw_sink, "Anúncio → subida → afundamento")
	var expected := 42.0 / SkyIslandSchedule.LEGEND_CYCLE * SkyIslandSchedule.LEGEND_DAYS
	assert(absf(legend_time - expected) < 0.1, "Lendária fica 6 h de jogo por ciclo (%.2f de %.2f dias)" % [legend_time, expected])
	var next := SkyIslandSchedule.next_myth(SEED, 0.0)
	assert(next.y - next.x > SkyIslandSchedule.ANNOUNCE_DAYS - 0.001 and next.z > next.y, "Próxima mítica: anúncio, subida, fim")
	print("  ✓ %d míticas em 42 dias; lendária %.2f dias no céu" % [myth_windows, legend_time])

func test_shape_and_field() -> SkyIslandField:
	print("\n[3/4] Forma procedural e ilhas no mundo...")
	for rarity in SkyIslandSchedule.SPECS:
		var isl := {"radius": 20.0, "depth": 7.0, "relief": 2.0, "rarity": rarity, "shape_seed": 77}
		var s := SkyIslandShape.new(isl)
		assert(s.contains(0, 0) and not s.contains(21.0, 0.0), "Dentro e fora")
		var t := s.top_at(0, 0)
		assert(t >= -0.01 and t <= 2.01, "Topo no relevo")
		assert(s.top_at(25.0, 0.0) == -INF and s.bottom_at(25.0, 0.0) == INF, "Fora não tem chão nem base")
		assert(s.bottom_at(0, 0) < t - 7.0, "Base funda no meio")
		assert(s.build_mesh().get_faces().size() > 1000, "Malha com topo, base e borda")
	# Quem está na origem (a vila) não é levado ao céu quando as ilhas nascem
	var walker := CharacterBody3D.new()
	var gravity := GDScript.new()
	gravity.source_code = "extends CharacterBody3D
func _physics_process(delta):
	velocity.y -= 18.0 * delta
	move_and_slide()
"
	gravity.reload()
	walker.set_script(gravity)
	var ground := StaticBody3D.new()
	var box := CollisionShape3D.new()
	box.shape = BoxShape3D.new()
	box.shape.size = Vector3(20, 1, 20)
	ground.add_child(box)
	root.add_child(ground)
	ground.global_position = Vector3(0, -0.5, 0)
	var cap := CollisionShape3D.new()
	cap.shape = CapsuleShape3D.new()
	walker.add_child(cap)
	root.add_child(walker)
	walker.global_position = Vector3(0, 1.2, 0)
	var field := SkyIslandField.new()
	field.fixed_day = 0.5
	root.add_child(field)
	for i in 20:
		await physics_frame
	assert(walker.global_position.distance_to(Vector3(0, 1.2, 0)) < 0.5, "Ilha nova não carrega o jogador da vila (%s)" % walker.global_position)
	walker.queue_free()
	ground.queue_free()
	assert(SkyIslandField.instance == field, "Campo registrado")
	var count := SkyIslandSchedule.islands_at(SEED, 0.5).size()
	assert(field.islands.size() == count, "Uma ilha no mundo para cada da agenda")
	for isl in field.list():
		var col: CollisionShape3D
		for c in isl.body.get_children():
			if c is CollisionShape3D:
				col = c
		assert(col and not col.disabled and (col.shape as ConcavePolygonShape3D).get_faces().size() > 0, "Ilha com colisão")
	# Rara troca de lugar: a velha sai, a nova entra
	var old_ids := field.islands.keys()
	field.refresh(2.5)
	var new_ids := field.islands.keys()
	assert(old_ids.any(func(id): return not new_ids.has(id)), "Rara velha saiu")
	field.refresh(0.5)
	print("  ✓ %d ilhas no mundo, com malha e colisão" % field.islands.size())
	return field

func _air_mount() -> Mount:
	var m := Mount.new()
	m.kind = Mount.Kind.AIR
	m.dna = CreatureDNA.randomized(CreatureDNA.Species.PLANADOR, 3)
	m.skip_settle = true
	root.add_child(m)
	return m

func test_current_and_ceiling(field: SkyIslandField) -> void:
	print("\n[4/4] Corrente de vento, teto de 40 m, chão da ilha e base de rocha...")
	var isl: SkyIsland
	for n in field.list():
		if n.rarity() == R.COMUM:
			isl = n
			break
	var m := _air_mount()
	# Longe das ilhas, o teto continua 40 m acima do chão
	var far := Vector3(-170.0, 30.0, -170.0)
	for n in field.list():
		assert(Vector2(n.global_position.x, n.global_position.z).distance_to(Vector2(far.x, far.z)) > n.shape.radius + 12.0, "Ponto livre longe das ilhas")
	m.global_position = far
	for i in 120:
		m._vertical = 6.0
		m._move_air(Vector3.ZERO, DT, false)
	assert(absf(m.global_position.y - Mount.AIR_CEILING) < 0.01, "Sem Corrente, para no teto (%.1f)" % m.global_position.y)
	# Acima do teto e fora da Corrente: desce planando, não despenca
	m.global_position = far + Vector3(0, 40.0, 0)
	m._vertical = 0.0
	m._move_air(Vector3.ZERO, 1.0, false)
	assert(absf(m.global_position.y - (70.0 - Mount.GLIDE_DOWN_SPEED)) < 0.01, "Desce planando a %.1f m/s" % Mount.GLIDE_DOWN_SPEED)
	# Dentro da Corrente: sobe sozinha acima do teto até passar do topo da ilha
	var col := isl.global_position + isl.current_offset()
	m.global_position = Vector3(col.x, 20.0, col.z)
	m._vertical = 0.0
	var t := 0.0
	while m.global_position.y < isl.top_y() + 5.0 and t < 30.0:
		m._move_air(Vector3.ZERO, DT, false)
		t += DT
	assert(m.global_position.y >= isl.top_y() + 5.0, "A Corrente leva acima de 40 m até a ilha (%.1f, topo %.1f)" % [m.global_position.y, isl.top_y()])
	assert(t < (isl.top_y() - 20.0) / SkyIslandField.CURRENT_LIFT + 5.0, "Sobe a ~8 m/s (%.1f s)" % t)
	assert(m.global_position.y <= isl.top_y() + SkyIslandField.CURRENT_OVERSHOOT + 0.01, "Não passa muito do topo")
	# Voa para cima da ilha: lá a ilha é o chão (teto 40 m acima dela), e pousa nela
	var center := isl.global_position
	var top := isl.top_at(center.x, center.z)
	m.global_position = Vector3(center.x, top + 6.0, center.z)
	assert(absf(m._ground(center.x, center.z) - top) < 0.01, "Em cima, o chão é a ilha")
	m.global_position = Vector3(center.x, top + 0.2, center.z)
	m._vertical = 0.0
	m._move_air(Vector3.ZERO, DT, false)
	assert(absf(m.global_position.y - top) < 0.01 and not m.airborne, "Pousa na ilha")
	# Embaixo da ilha: a base de rocha não se atravessa
	var bottom := isl.bottom_at(center.x, center.z)
	m.global_position = Vector3(center.x, bottom - 4.0, center.z)
	for i in 90:
		m._vertical = 6.0
		m._move_air(Vector3.ZERO, DT, false)
	assert(m.global_position.y <= bottom - 0.99, "Não atravessa a base (%.2f, base %.2f)" % [m.global_position.y, bottom])
	var top_y := isl.top_y()
	# Sem céu de ilhas, tudo como antes
	field.queue_free()
	await process_frame
	assert(SkyIslandField.ground_at(0, 0, 999.0, 3.0) == 3.0 and SkyIslandField.current_at(Vector3.ZERO) == null, "Sem campo, chão é o terreno")
	m.queue_free()
	print("  ✓ Corrente em %.1f s até %.1f m; pousa no topo; base sólida" % [t, top_y])
