extends SceneTree

## B39 / GDD-18 fase 7: as Ilhotas (comuns) aparecem no pergaminho [M] como sombra pontilhada, no
## lugar e do tamanho delas. As outras ilhas não aparecem: são exploração.

const _WorldMapScreen = preload("res://scripts/ui/world_map_screen.gd")
const R := SkyIslandSchedule.Rarity
const SEED: int = 2026

var _started: bool = false

func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false

func _run() -> void:
	print("\n========================================================")
	print("🗺️ TESTANDO AS SOMBRAS DAS ILHOTAS NO MAPA (B39 fase 7)")
	print("========================================================")
	test_outlines()
	await test_map_draws()
	print("\n🎉 TODOS OS TESTES DAS ILHOTAS NO MAPA PASSARAM COM SUCESSO!")
	print("========================================================\n")
	quit(0)

func test_outlines() -> void:
	print("\n[1/2] Contorno de cada Ilhota, e só delas...")
	var commons := SkyIslandSchedule.commons(SEED)
	var lines := SkyIslandSchedule.common_outlines(SEED)
	assert(lines.size() == SkyIslandSchedule.SPECS[R.COMUM].count and lines.size() == commons.size(), "Uma sombra por Ilhota (%d)" % lines.size())
	for i in lines.size():
		var line: PackedVector2Array = lines[i]
		var c: Vector3 = commons[i].center
		var r: float = commons[i].radius
		assert(line[0].is_equal_approx(line[line.size() - 1]), "Contorno fechado")
		for p in line:
			var d := p.distance_to(Vector2(c.x, c.z))
			assert(d >= r * 0.79 and d <= r * 1.01, "Na borda da ilha (%.1f de %.1f)" % [d, r])
	# As Ilhotas são as mesmas do céu, em qualquer dia; as outras raridades ficam fora do mapa
	for day in [0.5, 7.3, 31.0]:
		var sky := SkyIslandSchedule.islands_at(SEED, day).filter(func(i): return i.rarity == R.COMUM)
		for i in sky.size():
			assert(sky[i].center.is_equal_approx(commons[i].center), "Ilhota fixa no dia %.1f" % day)
	assert(_WorldMapScreen.sky_shadows().size() == lines.size(), "O mapa usa as mesmas sombras")
	assert(SkyIslandSchedule.common_outlines(SEED + 1)[0] != lines[0], "Outra seed, outro céu")
	print("  ✓ %d sombras, cada uma na borda da sua Ilhota" % lines.size())

func test_map_draws() -> void:
	print("\n[2/2] O pergaminho abre e desenha com as sombras...")
	var field := SkyIslandField.new()
	field.fixed_day = 0.5
	root.add_child(field)
	var map: Node = _WorldMapScreen.new()
	root.add_child(map)
	await process_frame
	map.open_map(null)
	await process_frame
	await process_frame
	assert(map.is_open, "Mapa aberto")
	assert(_WorldMapScreen.sky_shadows().size() == SkyIslandSchedule.SPECS[R.COMUM].count, "Sombras do céu atual")
	map.close_map()
	map.queue_free()
	field.queue_free()
	await process_frame
	print("  ✓ Abriu e desenhou sem erro")
