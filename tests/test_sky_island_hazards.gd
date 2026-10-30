extends SceneTree

## B39 / GDD-18 fase 5: perigos das ilhas voadoras. Rajadas na rara (no topo e na Corrente), a
## Corrente da lendária que liga e desliga, raios que procuram quem veste ferro na Ilha-Ruína e a
## Zona Selvagem (PvP e full loot) da rara para cima, com aviso no HUD.

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const _ForgedItem = preload("res://scripts/data/forged_item.gd")
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
	print("⚡ TESTANDO OS PERIGOS DAS ILHAS VOADORAS (B39 fase 5)")
	print("========================================================")
	_field = SkyIslandField.new()
	_field.fixed_day = 0.5
	root.add_child(_field)
	var zm := ZoneManager.new()
	root.add_child(zm)
	test_timing()
	await test_gust_on_top()
	test_gust_in_current()
	await test_lightning()
	await test_wild_zone(zm)
	print("\n🎉 TODOS OS TESTES DOS PERIGOS DAS ILHAS PASSARAM COM SUCESSO!")
	print("========================================================\n")
	quit(0)

func _island(rarity: int) -> SkyIsland:
	for isl in _field.list():
		if isl.rarity() == rarity:
			return isl
	return null

## Põe o relógio do céu no segundo real `t`
func _set_time(t: float) -> void:
	_field.fixed_day = t / DayNightCycle.seconds_per_day()
	_field.refresh()

func _now() -> float:
	return _field.day() * DayNightCycle.seconds_per_day()

func _player(pos: Vector3) -> Player:
	var p: Player = PlayerScene.instantiate() as Player
	root.add_child(p)
	p._setup_components()
	p.global_position = pos
	return p

func _on_top(isl: SkyIsland, dx: float = 0.0, dz: float = 0.0) -> Vector3:
	var c := isl.global_position + Vector3(dx, 0, dz)
	return Vector3(c.x, isl.top_at(c.x, c.z) + 0.3, c.z)

func _settle(n: int = 20) -> void:
	for i in n:
		await physics_frame

func test_timing() -> void:
	print("\n[1/5] Quando cada coisa acontece sai do relógio...")
	var rare := _island(R.RARA).data
	var last := -INF
	var gaps: Array[float] = []
	var t := 0.0
	while gaps.size() < 30:
		var g := H.gust(rare, t)
		if not g.is_empty() and g.at != last:
			if last > -INF:
				gaps.append(g.at - last)
			last = g.at
		t += 0.25
	for gap in gaps:
		assert(gap >= 29.9 and gap <= 60.1, "Rajada a cada 30–60 s (%.1f)" % gap)
	var g := H.gust(rare, last - 0.5)
	assert(not g.is_empty() and not g.blowing, "Avisa 1 s antes")
	assert(H.gust(rare, last + 0.2).blowing, "Depois sopra")
	assert(H.gust(rare, 12345.6) == H.gust(rare.duplicate(), 12345.6), "Mesma conta em todo cliente")
	for r in [R.COMUM, R.INCOMUM]:
		var other := _island(r).data
		for s in 200:
			assert(H.gust(other, float(s)).is_empty(), "Comum e incomum sem rajada")
	# Corrente da lendária: 40 s ligada, 20 s desligada
	var legend := {"rarity": R.LENDARIA, "shape_seed": 4242}
	var on := 0
	for s in 600:
		on += 1 if H.current_on(legend, float(s) + 0.5) else 0
	assert(on == 400, "Lendária: Corrente ligada 2/3 do tempo (%d de 600 s)" % on)
	assert(H.current_on(rare, 33.0) and H.current_on(_island(R.COMUM).data, 33.0), "As outras sempre ligadas")
	for k in 20:
		var gap := H.strike_mark_at(legend, k + 1) - H.strike_mark_at(legend, k)
		assert(gap >= 14.9 and gap <= 35.1, "Raio a cada ~25 s (%.1f)" % gap)
	print("  ✓ %d rajadas entre 30 e 60 s; Corrente da lendária 40/20 s; raio a cada ~25 s" % gaps.size())

## Próxima rajada da rara a partir de `t`
func _next_gust(isl: SkyIsland, t: float) -> Dictionary:
	while true:
		var g := H.gust(isl.data, t)
		if not g.is_empty():
			return g
		t += 0.25
	return {}

func test_gust_on_top() -> void:
	print("\n[2/5] Rajada no topo da rara: em pé voa ~4 m, agachado fica...")
	var isl := _island(R.RARA)
	var g := _next_gust(isl, _now())
	_set_time(g.at - 0.5)
	isl = _island(R.RARA)
	var p := _player(_on_top(isl))
	var heard: Array[String] = []
	p.posture_changed.connect(func(msg): heard.append(msg))
	await _settle()
	assert(p.is_on_floor(), "De pé na Ilha da Ventania")
	assert(isl._gust_leaves != null and isl._gust_leaves.emitting, "Folhas e som avisam antes")
	var start := p.global_position
	_set_time(g.at + 0.1)
	await _settle(60)
	var moved := Vector2(p.global_position.x - start.x, p.global_position.z - start.z)
	var flew := moved.length()
	assert(moved.length() > 3.0 and moved.length() < 5.5, "Em pé, a rajada joga ~4 m (%.1f)" % moved.length())
	assert(moved.normalized().dot(Vector2(g.dir.x, g.dir.z)) > 0.9, "Na direção do vento")
	assert(heard.any(func(m): return "Rajada" in m), "Aviso no HUD: %s" % [heard])
	# Agachado: a próxima não leva
	var g2 := _next_gust(isl, g.at + H.GUST_BLOW + 0.1)
	_set_time(g2.at - 0.5)
	p.global_position = _on_top(isl)
	Input.action_press("crouch")
	await _settle()
	assert(p.is_crouching, "Agachado")
	start = p.global_position
	_set_time(g2.at + 0.1)
	await _settle(60)
	Input.action_release("crouch")
	moved = Vector2(p.global_position.x - start.x, p.global_position.z - start.z)
	assert(moved.length() < 0.3, "Agachado não voa (%.2f)" % moved.length())
	p.queue_free()
	await process_frame
	print("  ✓ Em pé voou %.1f m; agachado ficou" % flew)

func test_gust_in_current() -> void:
	print("\n[3/5] Na Corrente da rara, a rajada empurra de lado; a da lendária liga e desliga...")
	var isl := _island(R.RARA)
	var g := _next_gust(isl, _now())
	var inside := isl.global_position + isl.current_offset() + Vector3(0, -20, 0)
	_set_time(g.at - 0.5)
	assert(isl.in_current(inside) and H.current_push(inside) == Vector3.ZERO, "Avisando: ainda não empurra")
	_set_time(g.at + 0.1)
	var push := H.current_push(inside)
	assert(is_equal_approx(push.length(), H.CURRENT_GUST_SPEED) and push.y == 0.0, "Soprando: de lado a %.0f m/s" % H.CURRENT_GUST_SPEED)
	assert(H.current_push(inside + Vector3(0, 0, 40)) == Vector3.ZERO, "Fora da Corrente, nada")
	# Lendária no céu: a Corrente some nos 20 s desligada (não sobe, e não se vê)
	var w := SkyIslandSchedule.next_event(SEED, R.LENDARIA, 0.0)
	var mid := (w.y + w.z) * 0.5 * DayNightCycle.seconds_per_day()
	_set_time(mid)
	var legend := _island(R.LENDARIA)
	var p := legend.global_position + legend.current_offset() + Vector3(0, -20, 0)
	var t := mid
	while not H.current_on(legend.data, t):
		t += 1.0
	_set_time(t + 0.5)
	assert(legend.in_current(p) and legend._current.visible, "Ligada: sobe")
	while H.current_on(legend.data, t):
		t += 1.0
	_set_time(t + 0.5)
	assert(not legend.in_current(p) and not legend._current.visible, "Desligada: não sobe e some")
	assert(SkyIslandField.current_at(p) == null, "A montaria não acha Corrente")
	print("  ✓ Rajada tira da coluna; Corrente da Ilha-Ruína liga 40 s e desliga 20 s")

func _iron_armor(p: Player, celeste: bool = false) -> void:
	var it := _ForgedItem.new()
	it.recipe_id = &"cota_ferro"
	it.display_name = "Cota de Ferro"
	it.slot = _ForgedItem.Slot.BODY
	it.family = &"ferro"
	if celeste:
		it.materials = {&"ferro_celeste": 2}
	p.inventory.add_item(it)
	p.inventory.equip(it)

## Leva o relógio até a próxima marca de raio da lendária e devolve [k, quando marca]
func _next_strike(legend: SkyIsland) -> Vector2:
	var t := _now()
	var k := floori(t / H.STRIKE_SLOT)
	while H.strike_mark_at(legend.data, k) < t + 0.1:
		k += 1
	return Vector2(k, H.strike_mark_at(legend.data, k))

func test_lightning() -> void:
	print("\n[4/5] Raio na Ilha-Ruína procura quem veste ferro em céu aberto...")
	var w := SkyIslandSchedule.next_event(SEED, R.LENDARIA, 0.0)
	_set_time((w.y + w.z) * 0.5 * DayNightCycle.seconds_per_day())
	var legend := _island(R.LENDARIA)
	var cloth := _player(_on_top(legend, -12.0, 0.0))
	var iron := _player(_on_top(legend, 12.0, 0.0))
	_iron_armor(iron)
	await _settle()
	assert(H.attracts_lightning(iron) and not H.attracts_lightning(cloth), "Ferro atrai, pano não")
	var s := _next_strike(legend)
	_set_time(s.y + 0.05)
	await physics_frame
	var key := "%s|%d" % [legend.data.id, int(s.x)]
	var strike: Dictionary = _field.hazards.strikes.get(key, {})
	assert(not strike.is_empty() and strike.pos.distance_to(iron.global_position) < 1.0, "Marca no chão embaixo de quem veste ferro")
	assert(is_instance_valid(strike.mark), "Marca visível 1,5 s antes")
	var hp := iron.pools.current_health
	var cloth_hp := cloth.pools.current_health
	_set_time(s.y + H.STRIKE_MARK + 0.05)
	await physics_frame
	assert(strike.done and not is_instance_valid(strike.mark), "O raio caiu")
	assert(iron.pools.current_health < hp, "Quem ficou na marca levou dano (%.0f → %.0f)" % [hp, iron.pools.current_health])
	assert(iron.pools.is_poise_broken, "Postura quebrada")
	assert(cloth.pools.current_health == cloth_hp, "Quem veste pano não levou nada")
	# Quem sai da marca a tempo escapa
	iron.pools.reset_all()
	await _settle(5)
	s = _next_strike(legend)
	_set_time(s.y + 0.05)
	await physics_frame
	iron.global_position = _on_top(legend, 0.0, 12.0)
	await _settle(3)
	hp = iron.pools.current_health
	_set_time(s.y + H.STRIKE_MARK + 0.05)
	await physics_frame
	assert(iron.pools.current_health == hp, "Saiu da marca: escapou")
	# Ferro-Celeste não atrai; debaixo de pedra também não
	var celeste := _player(_on_top(legend, 0.0, -12.0))
	_iron_armor(celeste, true)
	assert(not H.attracts_lightning(celeste), "Ferro-Celeste não atrai raio")
	var roof := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4, 1, 4)
	shape.shape = box
	roof.add_child(shape)
	root.add_child(roof)
	roof.global_position = iron.global_position + Vector3(0, 6, 0)
	await _settle(3)
	assert(not _field.hazards.is_open_sky(iron), "Debaixo da pedra não é céu aberto")
	s = _next_strike(legend)
	_set_time(s.y + 0.05)
	await physics_frame
	strike = _field.hazards.strikes.get("%s|%d" % [legend.data.id, int(s.x)], {})
	assert(strike.pos == Vector3.INF, "Ninguém exposto vestindo ferro: o raio não procura ninguém")
	for n in [cloth, iron, celeste, roof]:
		n.queue_free()
	await process_frame
	print("  ✓ Marca em quem veste ferro, raio de %.0f com Postura quebrada; pano, Ferro-Celeste e abrigo escapam" % H.STRIKE_DAMAGE)

func test_wild_zone(zm: ZoneManager) -> void:
	print("\n[5/5] Rara para cima é Zona Selvagem, com aviso ao pisar e ao sair...")
	_set_time(0.5 * DayNightCycle.seconds_per_day())
	var rare := _island(R.RARA)
	var common := _island(R.COMUM)
	assert(zm.get_zone_at(_on_top(rare)) == ZoneManager.ZoneType.WILD_PVP, "Topo da rara: Zona Selvagem")
	assert(zm.get_zone_at(_on_top(common)) != ZoneManager.ZoneType.WILD_PVP, "Comum: neutra")
	assert(zm.get_zone_at(_on_top(_island(R.INCOMUM))) != ZoneManager.ZoneType.WILD_PVP, "Incomum: neutra")
	var below := rare.global_position + Vector3(0, -80, 0)
	assert(zm.get_zone_at(below) != ZoneManager.ZoneType.WILD_PVP, "Embaixo da rara, no chão: não")
	assert("Zona Selvagem · PvP e full loot" in zm.get_zone_name_at(_on_top(rare)), "Nome no HUD: %s" % zm.get_zone_name_at(_on_top(rare)))
	assert(not zm.can_build_at(_on_top(rare)).allowed, "Não se constrói na ilha")
	var p := _player(_on_top(common))
	p.set_physics_process(false)
	var heard: Array[String] = []
	p.posture_changed.connect(func(msg): heard.append(msg))
	await _settle(2)
	assert(heard.is_empty(), "Na comum, nada")
	p.global_position = _on_top(rare)
	await _settle(2)
	p.global_position = _on_top(rare, 2.0, 0.0)
	await _settle(2)
	assert(heard == ["☠️ Zona Selvagem · PvP e full loot"], "Aviso ao pisar, uma vez: %s" % [heard])
	p.global_position = below
	await _settle(2)
	assert(heard.back() == "Saiu da Zona Selvagem", "Aviso ao sair")
	p.queue_free()
	await process_frame
	print("  ✓ %s" % zm.get_zone_name_at(_on_top(rare)))
