extends SceneTree

## B39 / GDD-18 fase 3: conteúdo das ilhas voadoras por raridade (flora, veios dos minérios novos,
## baú e ninho), que nasce com jogador perto, some quando todos saem guardando o que foi pego, e se
## renova inteiro numa época nova da ilha.

const R := SkyIslandSchedule.Rarity
const SEED: int = 2026

var _started: bool = false
var _field: SkyIslandField
var _visitor: Node3D

func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false

func _run() -> void:
	print("\n========================================================")
	print("🌿 TESTANDO O CONTEÚDO DAS ILHAS VOADORAS (B39 fase 3)")
	print("========================================================")
	_visitor = Node3D.new()
	_visitor.add_to_group("player")
	root.add_child(_visitor)
	_visitor.global_position = Vector3(0, -500, 0)
	_field = SkyIslandField.new()
	_field.fixed_day = 0.5
	root.add_child(_field)
	test_materials()
	await test_recipes()
	await test_state_kept()
	await test_renewal_and_drop()
	await test_nest()
	print("\n🎉 TODOS OS TESTES DO CONTEÚDO DAS ILHAS PASSARAM COM SUCESSO!")
	print("========================================================\n")
	quit(0)

func _island(rarity: int) -> SkyIsland:
	for isl in _field.list():
		if isl.rarity() == rarity:
			return isl
	return null

## Leva o visitante para cima da ilha (ou para longe) e deixa o céu se atualizar
func _visit(isl: SkyIsland) -> void:
	_visitor.global_position = isl.global_position + Vector3(0, 2, 0) if isl else Vector3(0, -500, 0)
	_field.refresh()
	await process_frame

func _first_day(rarity: int) -> float:
	var d := 0.0
	while d < 30.0:
		for isl in SkyIslandSchedule.islands_at(SEED, d):
			if isl.rarity == rarity and isl.phase == &"firme":
				return d
		d += 0.01
	return -1.0

func test_materials() -> void:
	print("\n[1/5] Minérios novos das ilhas...")
	for id in [&"cristal_vento", &"ferro_celeste", &"ambar_estelar"]:
		var m := MaterialData.of(id)
		assert(m.category == MaterialData.Category.MINERAL and m.base_value > 0 and not m.description.is_empty(), "%s cadastrado" % id)
	assert(MaterialData.of(&"ambar_estelar").base_value > MaterialData.of(&"ferro_celeste").base_value, "Âmbar vale mais que Ferro-Celeste")
	assert(MaterialData.of(&"ferro_celeste").base_value > MaterialData.of(&"cristal_vento").base_value, "Ferro-Celeste vale mais que Cristal")
	print("  ✓ Cristal-de-Vento, Ferro-Celeste e Âmbar-Estelar")

func test_recipes() -> void:
	print("\n[2/5] Cada raridade com a sua flora, veios e baú...")
	await _visit(null)
	for isl in _field.list():
		assert(isl.content == null, "Ninguém perto, nada nasce")
	for rarity in [R.COMUM, R.INCOMUM, R.RARA, R.LENDARIA, R.MITICA]:
		if rarity >= R.LENDARIA:
			_field.fixed_day = _first_day(rarity)
			assert(_field.fixed_day >= 0.0, "Achou a %s no céu" % SkyIslandSchedule.RARITY_NAMES[rarity])
			_field.refresh()
		var isl := _island(rarity)
		await _visit(isl)
		var c := isl.content
		assert(c != null, "Jogador perto: conteúdo da %s nasce" % SkyIslandSchedule.NAMES[rarity])
		var recipe: Dictionary = SkyIslandContent.RECIPES[rarity]
		var vein_n := 0
		for v in recipe.veins:
			vein_n += v[1]
		assert(c.veins.size() == vein_n, "%s: %d veios (%d)" % [SkyIslandSchedule.NAMES[rarity], vein_n, c.veins.size()])
		for v in c.veins:
			assert(v.type == recipe.veins[0][0] and not v.respawn_enabled, "Veio do minério da raridade, sem voltar sozinho")
		assert(c.flora.size() >= 6, "Flora de coleta")
		if recipe.chest.is_empty():
			assert(c.chest == null, "Comum não tem baú")
		else:
			assert(c.chest and c.chest.chest_title == recipe.chest.title and c.chest.reward_material == recipe.chest.material, "Baú certo: %s" % recipe.chest.title)
			assert(not c.chest.snap_to_ground, "Baú não desce para o vale")
		# Tudo em cima da ilha, no chão dela
		for g in c.veins + c.flora:
			var top := isl.top_at(g.global_position.x, g.global_position.z)
			assert(top > -INF and absf(g.global_position.y - top) < 0.05, "%s no chão da ilha" % g.display_name)
		print("  ✓ %s: %d veios, %d plantas, baú %s" % [SkyIslandSchedule.NAMES[rarity], c.veins.size(), c.flora.size(), c.chest.chest_title if c.chest else "—"])
	_field.fixed_day = 0.5
	await _visit(null)

func test_state_kept() -> void:
	print("\n[3/5] O que foi pego fica pego quando a ilha some e volta...")
	var isl := _island(R.INCOMUM)
	await _visit(isl)
	var c := isl.content
	var vein := c.veins[0]
	var drops := 0
	while vein.is_harvestable():
		assert(not vein.harvest_next(null).is_empty(), "Batida no veio")
		drops += 1
	assert(drops == vein.max_hits and vein.is_collected, "Veio acabou em %d batidas" % drops)
	c.chest.open_chest(null)
	assert(c.chest.is_opened, "Baú aberto")
	# Todo mundo vai embora: o conteúdo some e o estado fica guardado
	await _visit(null)
	await process_frame
	assert(isl.content == null, "Sem ninguém a 200 m, o conteúdo some")
	var st: Dictionary = _field.content_state.get(SkyIslandContent.key_for(isl.data), {})
	assert(st.get("v0", -1) == 0 and st.get("bau", false), "Guardou veio esgotado e baú aberto: %s" % st)
	# Volta: veio continua esgotado e baú continua aberto (não renasce de graça)
	await _visit(isl)
	assert(isl.content.veins[0].is_collected and not isl.content.veins[0].is_harvestable(), "Veio continua esgotado")
	assert(isl.content.chest.is_opened, "Baú continua aberto")
	# Veio pela metade também é lembrado
	var rare := _island(R.RARA)
	await _visit(rare)
	rare.content.veins[1].harvest_next(null)
	var left := rare.content.veins[1].hits_left
	await _visit(null)
	await _visit(rare)
	assert(rare.content.veins[1].hits_left == left and not rare.content.veins[1].is_collected, "Veio pela metade: %d batidas" % left)
	print("  ✓ Veio esgotado, veio pela metade e baú aberto continuam assim")

func test_renewal_and_drop() -> void:
	print("
[4/5] Ilha que sai do céu leva o que tinha; época nova renova a incomum...")
	# A rara troca de lugar: a velha some do céu e o estado dela vai junto
	var rare := _island(R.RARA)
	var rare_key := SkyIslandContent.key_for(rare.data)
	assert(_field.content_state.has(rare_key), "Rara tinha estado guardado")
	_field.fixed_day = 0.5 + SkyIslandSchedule.RARE_DAYS
	await _visit(null)
	assert(not _field.content_state.has(rare_key), "Rara que saiu do céu levou o estado")
	# Incomum, com todo mundo longe: na época nova o estado velho some e ela volta inteira
	_field.fixed_day = 0.5
	await _visit(null)
	var isl := _island(R.INCOMUM)
	var old_key := SkyIslandContent.key_for(isl.data)
	assert(_field.content_state.has(old_key), "Incomum tinha estado guardado")
	_field.fixed_day = 0.5 + SkyIslandSchedule.RENEW_DAYS
	await _visit(null)
	assert(not _field.content_state.has(old_key), "Estado da época velha jogado fora")
	await _visit(isl)
	assert(SkyIslandContent.key_for(isl.data) != old_key, "Época nova")
	assert(not isl.content.veins[0].is_collected and not isl.content.chest.is_opened, "Incomum renovada: veio inteiro e baú fechado")
	_field.fixed_day = 0.5
	await _visit(null)
	print("  ✓ Rara leva o que tinha; incomum renova a cada %d dias" % int(SkyIslandSchedule.RENEW_DAYS))

func test_nest() -> void:
	print("\n[5/5] Ninho de Planador numa Ilhota, no chão da ilha...")
	var with_nest: SkyIsland
	for isl in _field.list():
		if isl.rarity() != R.COMUM:
			continue
		await _visit(isl)
		if isl.content.nest:
			with_nest = isl
			break
	assert(with_nest != null, "Alguma Ilhota tem ninho")
	var nest := with_nest.content.nest
	var top := with_nest.top_at(nest.global_position.x, nest.global_position.z)
	assert(absf(nest.global_position.y - top) < 0.05, "Ninho no topo da ilha")
	assert(absf(nest._ground(nest.global_position.x, nest.global_position.z) - top) < 0.05, "O chão do ninho é a ilha, não o vale")
	# Prova em andamento: a ilha não some nem com todo mundo longe
	nest.state = PlanadorNest.State.WAITING
	await _visit(null)
	assert(with_nest.content != null and is_instance_valid(nest), "Ninho ocupado segura o conteúdo")
	nest.state = PlanadorNest.State.READY
	await _visit(null)
	await process_frame
	assert(with_nest.content == null, "Ninho livre: o conteúdo some")
	print("  ✓ Ninho em %s" % with_nest.name)
