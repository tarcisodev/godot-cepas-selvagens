extends SceneTree

## B39 / GDD-18 fase 6: chefes e mítica. A Sentinela de Pedra dorme na Ilha-Ruína, acorda, expõe o
## núcleo depois do Martelo e puxa o raio; uma por surgimento, guardada no save. O Arquipélago do
## Eclipse tem a Matriarca que sela o Âmbar-Estelar e o Relicário, ilhotas com Planadores do
## Eclipse, Corrente lateral e Corrente turbulenta, e o anúncio escurece o céu.

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const R := SkyIslandSchedule.Rarity
const H = preload("res://scripts/world/sky_island_hazards.gd")
const SEED: int = 2026

var _started: bool = false
var _field: SkyIslandField

func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false

func _run() -> void:
	print("\n========================================================")
	print("🗿 TESTANDO CHEFES E MÍTICA DAS ILHAS (B39 fase 6)")
	print("========================================================")
	_field = SkyIslandField.new()
	_field.fixed_day = 0.5
	root.add_child(_field)
	test_bodies()
	await test_sentinel()
	await test_sentinel_save()
	await test_matriarch()
	await test_satellites_and_currents()
	await test_announcement()
	print("\n🎉 TODOS OS TESTES DOS CHEFES E DA MÍTICA PASSARAM COM SUCESSO!")
	print("========================================================\n")
	quit(0)

func _island(rarity: int, satellite: bool = false) -> SkyIsland:
	for isl in _field.list():
		if isl.rarity() == rarity and isl.is_link() == satellite:
			return isl
	return null

func _days(t: float) -> float:
	return SkyIslandSchedule.days(t)

func _at_event(rarity: int) -> Vector3:
	var w := SkyIslandSchedule.next_event(SEED, rarity, 0.0)
	_field.fixed_day = (w.y + w.z) * 0.5
	_field.refresh()
	return w

func _player(pos: Vector3) -> Player:
	var p: Player = PlayerScene.instantiate() as Player
	root.add_child(p)
	p._setup_components()
	p.set_physics_process(false)
	p.global_position = pos
	return p

func _top(isl: SkyIsland, dx: float, dz: float) -> Vector3:
	var c := isl.global_position + Vector3(dx, 0, dz)
	return Vector3(c.x, isl.top_at(c.x, c.z) + 0.3, c.z)

func _frames(n: int) -> void:
	for i in n:
		await physics_frame

func test_bodies() -> void:
	print("\n[1/6] Corpos novos: Sentinela de pedra e Planador do Eclipse...")
	var golem := CreatureBody.new()
	golem.dna = CreatureDNA.randomized(CreatureDNA.Species.SENTINELA, 5)
	golem.dna.alleles["porte"] = ["T", "T"]
	root.add_child(golem)
	assert(golem.dna.plan() == CreatureDNA.Plan.GOLEM and golem.core_node and golem.plates_node, "Sentinela: blocos, núcleo e couraça")
	assert(golem.back_height > 3.0, "Gigante (%.1f m até o alto do tronco)" % golem.back_height)
	golem.pose = &"sit"
	golem.pose_amount = 1.0
	for i in 60:
		golem.animate(1.0 / 30.0, 0.0)
	assert(golem.get_node("Torso").position.y < -0.5, "Sentada, o tronco desce")
	golem.queue_free()
	var e := CreatureDNA.eclipse(9)
	var plain := CreatureDNA.randomized(CreatureDNA.Species.PLANADOR, 9)
	plain.alleles["porte"] = ["T", "T"]
	assert(e.is_eclipse() and not plain.is_eclipse(), "Gene mítico só no Eclipse")
	assert(is_equal_approx(e.stage_scale(), 1.4) and is_equal_approx(CreatureDNA.eclipse(9, true).stage_scale(), 5.6), "Eclipse 1,4×; Matriarca 4× isso")
	assert(e.species_name() == "Planador do Eclipse", "Nome da espécie")
	var bird := CreatureBody.new()
	bird.dna = e
	root.add_child(bird)
	var glow := bird.find_children("*", "MeshInstance3D", true, false).filter(func(m): return m.material_override is StandardMaterial3D and m.material_override.emission_enabled)
	assert(glow.size() == 2, "Borda das duas asas brilha")
	bird.queue_free()
	var b := MountBond.create(e, &"eclipse", 0)
	assert(is_equal_approx(b.elo, 30.0) and b.marked, "Domado sai marcado com Elo 30")
	var f := BraveFlight.new(1)
	f.make_hard(25.0, 0.7, 0.8)
	assert(f.duration == 25.0 and f.window == 0.7, "Voo bravio do Eclipse mais duro")
	print("  ✓ Sentinela de %.1f m; Eclipse escuro com borda de luz; Elo 30 marcado" % golem.back_height)

func test_sentinel() -> void:
	print("\n[2/6] Sentinela dorme, acorda, expõe o núcleo e puxa o raio...")
	_at_event(R.LENDARIA)
	var legend := _island(R.LENDARIA)
	var p := _player(_top(legend, 0.0, 30.0))
	_field.refresh()
	await process_frame
	var g := legend.content.guardian
	assert(g != null and g.config.name == "Sentinela de Pedra", "Sentinela no meio da Ilha-Ruína")
	assert(absf(g.global_position.y - legend.top_at(g.global_position.x, g.global_position.z)) < 1.0, "No chão da ilha")
	await _frames(10)
	assert(g.state == BeastFighter.State.IDLE and g.body.pose == &"sit", "Dorme sentada com ninguém perto")
	assert(H.guardian_of(legend) == null, "Dormindo não puxa raio")
	var hb := g.get_node("Hurtbox_core") as HurtboxComponent
	assert(not hb.monitorable, "Núcleo escondido")
	p.global_position = _top(legend, 0.0, 9.0)
	await _frames(10)
	assert(g.state != BeastFighter.State.IDLE, "Acordou com alguém a menos de 14 m")
	# Martelo: o núcleo fica à mostra por um tempo
	g._start_attack(g.config.attacks[1])
	var saw := false
	for i in 120:
		await physics_frame
		if hb.monitorable:
			saw = true
			break
	assert(saw and g.is_part_exposed(&"core"), "Depois do Martelo, o núcleo aparece")
	var hid := false
	for i in 600:
		await physics_frame
		if not hb.monitorable:
			hid = true
			break
	assert(hid, "E se esconde de novo")
	# Para-raios: sem ninguém de ferro, o raio procura ela
	assert(H.guardian_of(legend) == g and _field.hazards._pick_target(legend, [p], 0) == g, "Acordada, puxa o raio")
	assert(g.take_lightning() and g.charged_time > 14.0, "O raio carrega o núcleo")
	g._start_attack(g.config.attacks[1])
	g._release_attack(null)
	assert((g._hit_shape.shape as SphereShape3D).radius > 7.0, "Carregada: o Martelo vira anel maior")
	# Núcleo quebrado: não carrega mais
	g.anatomy.damage_part(&"core", 9999.0)
	assert(not g.take_lightning() and g.charged_time == 0.0 and not g.body.core_node.visible, "Sem núcleo, sem raio")
	assert(g.harvest_queue.is_empty(), "Viva, nada para esfolar")
	p.queue_free()
	await process_frame
	print("  ✓ Dormiu, acordou, mostrou o núcleo e carregou com o raio")

func test_sentinel_save() -> void:
	print("\n[3/6] Uma por surgimento: derrotada, fica derrotada (e vai para o save)...")
	var legend := _island(R.LENDARIA)
	var p := _player(_top(legend, 0.0, 30.0))
	_field.refresh()
	await process_frame
	var g := legend.content.guardian
	var fell := [false]
	g.defeated.connect(func(): fell[0] = true)
	g.anatomy.damage_part(&"core", 9999.0)
	g.pools.take_damage(99999.0)
	await process_frame
	assert(fell[0] and g.state == BeastFighter.State.DEAD, "Derrotada")
	assert(g.harvest_queue.map(func(h): return h.label) == ["Ferro-Celeste", "Pedra Rúnica"], "Núcleo quebrado: sem Núcleo da Ruína na esfola (%s)" % [g.harvest_queue.map(func(h): return h.label)])
	var saved: Dictionary = JSON.parse_string(JSON.stringify(_field.get_state()))
	assert(saved.content[SkyIslandContent.key_for(legend.data)].get("chefe", false), "Save guarda a derrota")
	# Todo mundo sai e volta: ela não renasce
	p.global_position = Vector3(0, -900, 0)
	_field.refresh()
	await process_frame
	assert(legend.content == null, "Conteúdo some sem ninguém perto")
	p.global_position = _top(legend, 0.0, 30.0)
	_field.refresh()
	await process_frame
	assert(legend.content.guardian == null and legend.content.boss_dead(), "Voltou: sem Sentinela até a ilha afundar")
	p.queue_free()
	await process_frame
	print("  ✓ Derrotada fica derrotada; save leva 'chefe'")

func test_matriarch() -> void:
	print("\n[4/6] Matriarca sela o Âmbar e o Relicário; caída, libera e deixa o filhote...")
	_at_event(R.MITICA)
	var core := _island(R.MITICA)
	var p := _player(_top(core, 0.0, 35.0))
	var heard: Array[String] = []
	p.posture_changed.connect(func(m): heard.append(m))
	_field.refresh()
	await process_frame
	var c := core.content
	var m := c.guardian
	assert(m and m.config.name == "Matriarca do Eclipse" and m.dna.is_matriarch(), "Matriarca no núcleo")
	assert(not c.veins[0].is_harvestable() and c.veins[0].sealed != "", "Veio de Âmbar selado")
	assert(c.chest.open_chest(p).is_empty() and not c.chest.is_opened, "Relicário selado")
	assert(c.nest and c.nest.locked and c.nest.state == PlanadorNest.State.READY and c.nest.adult == null, "Ninho dela sem filhote ainda")
	# Asas quebradas: acabou a rajada
	m.anatomy.damage_part(&"wings", 99999.0)
	for i in 50:
		var pick := m._pick_attack(3.0, -m.global_basis.z)
		assert(pick.is_empty() or pick.id != &"rajada", "Sem asas, sem rajada")
	m.pools.take_damage(99999.0)
	await process_frame
	await process_frame
	assert(c.veins[0].is_harvestable() and c.chest.sealed == "", "Caída: veio e Relicário livres")
	assert(not c.chest.open_chest(p).is_empty(), "Relicário abre")
	assert(c.nest.state == PlanadorNest.State.WAITING and c.nest.adult and c.nest.adult.dna.is_eclipse(), "Filhote do Eclipse no ninho")
	assert(heard.any(func(h): return "Matriarca caiu" in h), "Aviso: %s" % [heard])
	assert(c.capture_state().get("chefe", false), "Derrota vai para o save")
	p.queue_free()
	await process_frame
	print("  ✓ Selados enquanto ela vive; livres e com filhote depois")

func test_satellites_and_currents() -> void:
	print("\n[5/6] Ilhotas, Corrente lateral e Corrente turbulenta da mítica...")
	var w := _at_event(R.MITICA)
	var list := SkyIslandSchedule.islands_at(SEED, (w.y + w.z) * 0.5)
	var core: Dictionary = list.filter(func(i): return i.rarity == R.MITICA and not i.get("satellite", false))[0]
	var sats := list.filter(func(i): return i.get("satellite", false))
	assert(sats.size() == SkyIslandSchedule.SATELLITES, "4 ilhotas")
	assert(sats.filter(func(i): return i.nest).size() == SkyIslandSchedule.SAT_NESTS, "2 com ninho do Eclipse")
	for s in sats:
		var d := Vector2(s.center.x - core.center.x, s.center.z - core.center.z).length()
		assert(d > core.radius + s.radius + 5.0, "Fora do núcleo (%.0f m)" % d)
		assert(s.center.y < core.center.y and s.phase == core.phase, "Mais baixa e com a mesma vida")
		assert(s.radius * 2.0 <= SkyIslandSchedule.SAT_DIAM.y + 0.01, "Pequena")
	for i in sats.size():
		for j in range(i + 1, sats.size()):
			var a: Dictionary = sats[i]
			var b: Dictionary = sats[j]
			assert(Vector2(a.center.x - b.center.x, a.center.z - b.center.z).length() > a.radius + b.radius, "Ilhotas não se encostam")
	assert(SkyIslandSchedule.islands_at(SEED, w.z + 0.01).all(func(i): return i.rarity != R.MITICA), "Afundam junto com o núcleo")
	# Ninho do Eclipse na ilhota: pousado, monta quem chegar
	var sat := _island(R.MITICA, true)
	for isl in _field.list():
		if isl.is_link() and isl.data.nest:
			sat = isl
	var p := _player(_top(sat, 0.0, 0.0))
	_field.refresh()
	await process_frame
	await process_frame
	var nest := sat.content.nest
	assert(nest and nest.eclipse and nest.state == PlanadorNest.State.WAITING and nest.adult.dna.is_eclipse(), "Planador do Eclipse pousado na ilhota")
	p.queue_free()
	# Corrente lateral: dentro do tubo, leva na direção em que se vai
	var ends := sat.link_ends()
	var mid := (ends[0] + ends[1]) * 0.5
	var along := (ends[1] - ends[0]).normalized()
	assert(sat.in_current(mid) and SkyIslandField.current_at(mid) == sat, "No meio do tubo lateral")
	assert(not sat.in_current(mid + Vector3(0, 8, 0)), "Fora do tubo, não")
	assert(H.current_push(mid, along).dot(along) > 6.0, "Indo para o núcleo, leva para o núcleo")
	assert(H.current_push(mid, -along).dot(-along) > 6.0, "Voltando, leva de volta")
	# Corrente do núcleo: tranco a cada 3–5 s; segurar o lado oposto anula
	var cisl := _island(R.MITICA)
	var t0 := (w.y + w.z) * 0.5 * DayNightCycle.seconds_per_day()
	var last := -INF
	var gaps: Array[float] = []
	var t := t0
	while gaps.size() < 20:
		var j := H.jolt(cisl.data, t)
		if not j.is_empty() and j.at != last:
			if last > -INF:
				gaps.append(j.at - last)
			last = j.at
		t += 0.1
	for gap in gaps:
		assert(gap >= 1.9 and gap <= 6.1, "Tranco a cada ~4 s (%.1f)" % gap)
	var jt := last + 0.2
	_field.fixed_day = jt / DayNightCycle.seconds_per_day()
	var j := H.jolt(cisl.data, jt)
	var col := cisl.global_position + cisl.current_offset() + Vector3(0, -30, 0)
	assert(cisl.in_current(col), "Dentro da Corrente do núcleo")
	assert(H.current_push(col).length() > 7.0, "Sem segurar: o tranco empurra")
	assert(H.current_push(col, -j.dir * 3.0) == Vector3.ZERO, "Segurando o lado oposto: anula")
	assert(H.jolt(_island(R.LENDARIA).data if _island(R.LENDARIA) else {"rarity": R.LENDARIA, "solid": true}, jt).is_empty(), "Só a mítica dá tranco")
	var dummy := Node3D.new()
	root.add_child(dummy)
	assert("segure ⬅ [A]" in H.jolt_text(dummy, Vector3.RIGHT), "Seta: empurra para a direita, segure A")
	dummy.queue_free()
	await process_frame
	print("  ✓ 4 ilhotas com tubo lateral; tranco a cada ~4 s, anulado segurando o outro lado")

func test_announcement() -> void:
	print("\n[6/6] Anúncio: o céu escurece e todo mundo fica sabendo...")
	var sun := DayNightCycle.new()
	root.add_child(sun)
	var w := SkyIslandSchedule.next_myth(SEED, 0.0)
	assert(SkyIslandField.eclipse_at(w, w.x - 0.01) == 0.0, "Antes do anúncio, sol normal")
	assert(absf(SkyIslandField.eclipse_at(w, (w.x + w.y) * 0.5) - 0.5) < 0.01, "No meio do anúncio, metade")
	assert(SkyIslandField.eclipse_at(w, (w.y + w.z) * 0.5) == 1.0, "No evento, eclipse inteiro")
	assert(SkyIslandField.eclipse_at(w, w.z + 0.001) == 0.0, "Afundou: sol de volta")
	var far := _player(Vector3(150, 2, 150))
	var heard: Array[String] = []
	far.posture_changed.connect(func(m): heard.append(m))
	_field.fixed_day = (w.x + w.y) * 0.5
	_field.refresh()
	_field.refresh()
	assert(absf(sun.eclipse - 0.5) < 0.01, "O relógio do sol recebe o eclipse (%.2f)" % sun.eclipse)
	var notices := heard.filter(func(m): return "Arquipélago do Eclipse sobe" in m)
	assert(notices.size() == 1, "Quem está longe também recebe, uma vez: %s" % [heard])
	_field.fixed_day = w.z + 0.01
	_field.refresh()
	assert(sun.eclipse == 0.0, "Acabou: sem eclipse")
	far.queue_free()
	sun.queue_free()
	await process_frame
	print("  ✓ %s" % notices[0])
