extends SceneTree

## B39 / GDD-18 fase 4: ciclo das ilhas e save. A ilha que vai afundar treme e avisa quem está em
## cima com tempo de sair; o que foi pego (veio, baú) vai para o save e volta igual; e quando a
## ilha some, quem ficou cai de verdade.

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const R := SkyIslandSchedule.Rarity
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
	print("⏳ TESTANDO CICLO, AVISO E SAVE DAS ILHAS (B39 fase 4)")
	print("========================================================")
	_field = SkyIslandField.new()
	_field.fixed_day = 0.5
	root.add_child(_field)
	var legend := _legend_window()
	test_schedule_warning(legend)
	await test_save_roundtrip()
	await test_warning_to_players(legend)
	await test_real_fall(legend)
	print("\n🎉 TODOS OS TESTES DO CICLO DAS ILHAS PASSARAM COM SUCESSO!")
	print("========================================================\n")
	quit(0)

## Primeira lendária: [subida, começa a afundar, some]
func _legend_window() -> Vector3:
	var w := SkyIslandSchedule.next_event(SEED, R.LENDARIA, 0.0)
	var rise := SkyIslandSchedule.days(SkyIslandSchedule.RISE_S)
	return Vector3(w.y + rise * 1.5, w.z - rise, w.z)

func _legend_at(day: float) -> Dictionary:
	for isl in SkyIslandSchedule.islands_at(SEED, day):
		if isl.rarity == R.LENDARIA:
			return isl
	return {}

func _island(rarity: int) -> SkyIsland:
	for isl in _field.list():
		if isl.rarity() == rarity:
			return isl
	return null

func test_schedule_warning(w: Vector3) -> void:
	print("\n[1/4] Antes de afundar, 1 h de jogo de tremor...")
	assert(w != Vector3.INF, "Achou uma lendária")
	var warn_from := w.y - SkyIslandSchedule.days(SkyIslandSchedule.WARN_S)
	assert(not _legend_at(warn_from - 0.002).warning, "Firme e quieta antes do aviso")
	var shaking := _legend_at(warn_from + 0.002)
	assert(shaking.warning and shaking.phase == &"firme", "Treme antes de descer")
	assert(_legend_at(w.y + 0.001).phase == &"afundando", "Depois desce")
	assert(_legend_at(w.z + 0.001).is_empty(), "E some")
	for isl in SkyIslandSchedule.islands_at(SEED, 3.99):
		if isl.rarity <= R.INCOMUM:
			assert(not isl.warning, "Comum e incomum nunca afundam")
	print("  ✓ Treme %.0f s reais e desce em %.0f s" % [SkyIslandSchedule.WARN_S, SkyIslandSchedule.RISE_S])

func test_save_roundtrip() -> void:
	print("\n[2/4] O que foi pego vai para o save e volta...")
	var visitor := Node3D.new()
	visitor.add_to_group("player")
	root.add_child(visitor)
	var isl := _island(R.INCOMUM)
	visitor.global_position = isl.global_position + Vector3(0, 2, 0)
	_field.refresh()
	var c := isl.content
	while c.veins[0].is_harvestable():
		c.veins[0].harvest_next(null)
	c.chest.open_chest(null)
	# O save passa por JSON (números viram float, chaves viram texto)
	var st := _field.get_state()
	st["content"]["rara_0_99@99"] = {"bau": true}
	var text := JSON.stringify({"sky_islands": st})
	var saved: Dictionary = JSON.parse_string(text)
	# Mundo novo, como ao abrir o jogo de novo
	_field.queue_free()
	await process_frame
	_field = SkyIslandField.new()
	_field.fixed_day = 0.5
	root.add_child(_field)
	assert(not _island(R.INCOMUM).content.veins[0].is_collected, "Sem o save, a ilha nasce inteira")
	_field.apply_state(saved["sky_islands"])
	await process_frame
	isl = _island(R.INCOMUM)
	assert(isl.content and isl.content.veins[0].is_collected and isl.content.chest.is_opened, "Com o save: veio esgotado e baú aberto")
	assert(not _field.content_state.has("rara_0_99@99"), "Estado de ilha que já saiu do céu é jogado fora")
	visitor.queue_free()
	await process_frame
	print("  ✓ Veio e baú voltam do save; ilha que não existe mais é esquecida")

## Jogador de verdade, com o aviso no posture_changed
func _player() -> Player:
	var p: Player = PlayerScene.instantiate() as Player
	root.add_child(p)
	p._setup_components()
	return p

func test_warning_to_players(w: Vector3) -> void:
	print("\n[3/4] Quem está em cima recebe o aviso, uma vez por etapa...")
	var p := _player()
	p.set_physics_process(false)
	var heard: Array[String] = []
	p.posture_changed.connect(func(msg): heard.append(msg))
	_field.fixed_day = w.x + 0.01
	_field.refresh()
	var isl := _island(R.LENDARIA)
	p.global_position = isl.global_position + Vector3(0, 1.0, 0)
	_field.refresh()
	assert(heard.is_empty(), "Firme: nada a avisar")
	_field.fixed_day = w.y - SkyIslandSchedule.days(SkyIslandSchedule.WARN_S) + 0.002
	_field.refresh()
	p.global_position = Vector3(isl.global_position.x, isl.top_at(isl.global_position.x, isl.global_position.z) + 1.0, isl.global_position.z)
	_field.refresh()
	_field.refresh()
	var shakes := heard.filter(func(m): return "tremendo" in m)
	assert(shakes.size() == 1 and "afunda em ~" in shakes[0], "Aviso de tremor uma vez, com o tempo: %s" % [heard])
	assert(isl._stage == &"tremendo" and isl._debris.emitting, "Malha treme e solta pedras")
	# Começou a descer: novo aviso (o jogador desce junto com a ilha)
	_field.fixed_day = w.y + 0.0005
	_field.refresh()
	p.global_position = Vector3(isl.global_position.x, isl.top_at(isl.global_position.x, isl.global_position.z) + 1.0, isl.global_position.z)
	_field.refresh()
	assert(heard.filter(func(m): return "afundando" in m).size() == 1, "Aviso de afundando: %s" % [heard])
	assert(isl._stage == &"afundando", "Treme mais forte")
	# Quem está longe não ouve nada
	var far := _player()
	far.set_physics_process(false)
	var far_heard: Array = []
	far.posture_changed.connect(func(msg): far_heard.append(msg))
	far.global_position = Vector3(0, 2, 0)
	_field.refresh()
	assert(far_heard.is_empty(), "Longe da ilha, sem aviso")
	far.queue_free()
	p.queue_free()
	await process_frame
	print("  ✓ %s" % shakes[0])

func test_real_fall(w: Vector3) -> void:
	print("\n[4/4] Ficou em cima até o fim: cai de verdade...")
	_field.fixed_day = w.y - 0.02
	_field.refresh()
	var isl := _island(R.LENDARIA)
	var c := isl.global_position
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(200, 1, 200)
	shape.shape = box
	floor_body.add_child(shape)
	root.add_child(floor_body)
	floor_body.global_position = Vector3(c.x, -0.5, c.z)
	var p := _player()
	p.global_position = Vector3(c.x, isl.top_at(c.x, c.z) + 0.5, c.z)
	for i in 30:
		await physics_frame
	assert(p.is_on_floor() and p.global_position.y > 100.0, "De pé na Ilha-Ruína (%.1f m)" % p.global_position.y)
	var hp := p.pools.current_health
	# A ilha acaba (afundou e se desfez): o chão some
	_field.fixed_day = w.z + 0.001
	_field.refresh()
	assert(_island(R.LENDARIA) == null, "A Ilha-Ruína saiu do céu")
	for i in 900:
		await physics_frame
		if p.is_on_floor() and p.global_position.y < 2.0:
			break
	assert(p.global_position.y < 2.0, "Caiu até o chão (%.1f m)" % p.global_position.y)
	assert(p.pools.current_health < hp * 0.05 or p.is_downed, "Queda de verdade: Vida %.0f de %.0f" % [p.pools.current_health, hp])
	p.queue_free()
	floor_body.queue_free()
	print("  ✓ Caiu de %.0f m e ficou com %.0f de Vida" % [c.y, p.pools.current_health])
