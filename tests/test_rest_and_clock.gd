extends SceneTree

## B22 / GDD-10 §10 / ADR-0006: relógio único que ninguém pula, Descansar (Vida por lugar),
## interrupção e bloqueio de combate, buff Descansado, Fogueira/Banco/Cama e cama como renascer.

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")

var _started: bool = false

func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false

func _run() -> void:
	print("\n========================================================")
	print("🔥 TESTANDO O RELÓGIO ÚNICO E O DESCANSAR (B22 / GDD-10 §10)")
	print("========================================================")
	test_single_clock()
	test_rest_rates()
	test_interruptions()
	test_rested_buff()
	test_bed_respawn()
	test_save()
	print("\n🎉 TODOS OS TESTES DO DESCANSAR PASSARAM COM SUCESSO!")
	print("========================================================\n")
	quit(0)

func _spawn_player() -> Player:
	var player: Player = PlayerScene.instantiate() as Player
	root.add_child(player)
	player.set_physics_process(false)
	player.global_position = Vector3(60.0, 0.0, 60.0)
	player.rest.since_combat = RestComponent.COMBAT_LOCK
	return player

func test_single_clock() -> void:
	print("\n[1/6] Relógio único: bicho, fruta e esterco seguem a duração do dia...")
	assert(DayNightCycle.seconds_per_day() == DayNightCycle.DEFAULT_DAY_SECONDS, "Sem sol: dia padrão de 5 min")
	var sun := DayNightCycle.new()
	root.add_child(sun)
	sun.day_length_seconds = 600.0
	assert(DayNightCycle.seconds_per_day() == 600.0, "O sol é o relógio")
	var c := WildCreature.new()
	c.dna = CreatureDNA.randomized(CreatureDNA.Species.TROTADOR, 5)
	c.position = Vector3(RiverSystem.get_river_center_x(40.0) + 25.0, 0, 40.0)
	root.add_child(c)
	var age0 := c.age_days
	c._live(6.0)
	assert(is_equal_approx(c.age_days - age0, 6.0 / 600.0), "Bicho envelhece no ritmo do dia do sol (%.4f)" % (c.age_days - age0))
	var eco := Ecology.new()
	root.add_child(eco)
	eco._drop_fruit(Vector3(70, 0, 70))
	eco.drop_dung(Vector3(72, 0, 70), null)
	var fruit: Node = get_nodes_in_group("fallen_fruit").filter(func(n): return n.has_meta("rot_days"))[0]
	eco.step(0.5)
	assert(is_instance_valid(fruit) and not fruit.is_queued_for_deletion(), "Meio dia: a fruta ainda está no chão")
	eco.step(0.6)
	assert(fruit.is_queued_for_deletion(), "Um dia de jogo: a fruta apodreceu")
	assert(get_nodes_in_group("dung").all(func(n): return n.is_queued_for_deletion()), "Esterco some no mesmo relógio")
	# Ninguém pula o tempo: só o relógio e o load do save escrevem a hora
	var writers := _clock_writers("res://scripts")
	assert(writers == ["res://scripts/core/save_game.gd"], "Só o save escreve a hora fora do relógio: %s" % [writers])
	var world_scene := FileAccess.get_file_as_string("res://scenes/world.tscn")
	assert(not world_scene.contains("WaitButton") and not world_scene.contains("Avançar 4h"), "O Esperar saiu do menu")
	eco.free()
	c.free()
	sun.free()
	print("  ✓ Dia de 600 s vale para bicho, fruta e esterco; ninguém pula a hora")

## Arquivos que escrevem `current_time_hours` (fora o próprio relógio)
func _clock_writers(dir_path: String) -> Array:
	var out: Array = []
	var dir := DirAccess.open(dir_path)
	for f in dir.get_files():
		if not f.ends_with(".gd") or f == "day_night_cycle.gd":
			continue
		var path := dir_path.path_join(f)
		var re := RegEx.create_from_string("current_time_hours\\s*[-+*/]?=[^=]")
		if re.search(FileAccess.get_file_as_string(path)):
			out.append(path)
	for d in dir.get_directories():
		out.append_array(_clock_writers(dir_path.path_join(d)))
	return out

func test_rest_rates() -> void:
	print("\n[2/6] Vida volta com a taxa do lugar...")
	var player := _spawn_player()
	var pools := player.pools
	var max_h := player.stats.get_stat(&"max_health")
	pools.current_health = max_h * 0.2
	player.rest._last_health = pools.current_health
	player.rest._process(1.0)
	assert(is_equal_approx(pools.current_health, max_h * 0.2), "Em pé a Vida não volta")
	player.toggle_sit(true)
	assert(player.is_sitting and player.rest.current_spot() == RestComponent.Spot.GROUND, "Sentou no chão")
	var before := pools.current_health
	player.rest._process(1.0)
	assert(is_equal_approx(pools.current_health - before, max_h * RestComponent.RATE_GROUND), "Chão: 0,5%/s")
	var fire := Campfire.new()
	root.add_child(fire)
	fire.global_position = player.global_position + Vector3(3.0, 0, 0)
	assert(player.rest.current_spot() == RestComponent.Spot.CAMP, "A 3 m da fogueira")
	before = pools.current_health
	player.rest._process(1.0)
	assert(is_equal_approx(pools.current_health - before, max_h * RestComponent.RATE_CAMP), "Fogueira: 2%/s")
	fire.global_position = player.global_position + Vector3(5.0, 0, 0)
	assert(player.rest.current_spot() == RestComponent.Spot.GROUND, "A 5 m a fogueira não alcança")
	fire.free()
	player.toggle_sit(false)
	var bench := _piece(BuildablePiece.PieceType.BANCO, player.global_position + Vector3(8, 0, 0), "")
	bench.talk_to(player)
	assert(player.is_sitting and player.rest.current_spot() == RestComponent.Spot.CAMP, "[E] no banco senta e vale como acampamento")
	player.toggle_sit(false)
	var bed := _piece(BuildablePiece.PieceType.CAMA, player.global_position + Vector3(-8, 0, 0), BuildingSystem.owner_name_of(player))
	bed.talk_to(player)
	assert(player.is_sitting and player.rest.current_spot() == RestComponent.Spot.BED, "Deitou na cama")
	before = pools.current_health
	player.rest._process(1.0)
	assert(is_equal_approx(pools.current_health - before, max_h * RestComponent.RATE_BED), "Cama: 3%/s")
	player.toggle_sit(false)
	assert(player.global_position.distance_to(bed.global_position) > 0.8, "Levanta para o lado da cama")
	# Cama dos outros não
	var other := _piece(BuildablePiece.PieceType.CAMA, player.global_position + Vector3(0, 0, 8), "Outro")
	other.talk_to(player)
	assert(not player.is_sitting, "Cama de outro jogador não deita")
	for n in [bench, bed, other]:
		n.free()
	player.free()
	print("  ✓ Chão 0,5%/s, fogueira e banco 2%/s, cama 3%/s; cama alheia recusa")

func test_interruptions() -> void:
	print("\n[3/6] Interrupção e bloqueio de 10 s pelo combate...")
	var player := _spawn_player()
	player.rest.mark_combat()
	player.toggle_sit(true)
	assert(not player.is_sitting, "Combate há menos de 10 s: não senta")
	assert(player.rest.block_reason().begins_with("Em combate"), "HUD diz o motivo")
	player.rest._process(RestComponent.COMBAT_LOCK + 0.1)
	player.toggle_sit(true)
	assert(player.is_sitting, "Passados 10 s, descansa")
	player.pools.take_damage(5.0)
	assert(not player.is_sitting and player.rest.since_combat < 1.0, "Levar dano tira do descanso e trava de novo")
	player.rest.since_combat = RestComponent.COMBAT_LOCK
	player.toggle_sit(true)
	var horse := Node3D.new()
	root.add_child(horse)
	player.mounted_on = horse
	player.rest._process(0.1)
	assert(not player.is_sitting, "Montar tira do descanso")
	player.mounted_on = null
	horse.free()
	player.free()
	print("  ✓ Bloqueio de 10 s, dano e montaria interrompem")

func test_rested_buff() -> void:
	print("\n[4/6] Descansado: 60 s na fogueira, +25%, renova sem acumular, some no Caído...")
	var player := _spawn_player()
	var base_vigor := player.stats.get_stat(&"vigor_regen")
	var base_ether := player.stats.get_stat(&"ether_regen")
	player.toggle_sit(true)
	for i in 70:
		player.rest._process(1.0)
	assert(not player.rest.has_rested(), "No chão não ganha Descansado")
	var fire := Campfire.new()
	root.add_child(fire)
	fire.global_position = player.global_position + Vector3(1.5, 0, 0)
	for i in 59:
		player.rest._process(1.0)
	assert(not player.rest.has_rested(), "Antes de 60 s ainda não")
	player.rest._process(1.5)
	assert(player.rest.has_rested(), "60 s na fogueira: Descansado")
	assert(is_equal_approx(player.stats.get_stat(&"vigor_regen"), base_vigor * 1.25), "Vigor volta 25% mais rápido")
	assert(is_equal_approx(player.stats.get_stat(&"ether_regen"), base_ether * 1.25), "Éter volta 25% mais rápido")
	assert(player.rest.status_text().contains("Descansado"), "HUD mostra o buff")
	player.rest.rested_left = 100.0
	for i in 61:
		player.rest._process(1.0)
	assert(player.rest.rested_left > RestComponent.RESTED_DURATION - 5.0, "Descansar de novo renova o tempo")
	assert(is_equal_approx(player.stats.get_stat(&"vigor_regen"), base_vigor * 1.25), "Não acumula")
	player.toggle_sit(false)
	player.pools.take_damage(1000.0)
	assert(player.is_downed and not player.rest.has_rested(), "Caído perde o Descansado")
	assert(is_equal_approx(player.stats.get_stat(&"vigor_regen"), base_vigor), "Modificador saiu da pilha")
	# Acaba sozinho depois de 15 min reais
	player.rest.apply_rested(2.0)
	player.rest._process(2.5)
	assert(not player.rest.has_rested() and is_equal_approx(player.stats.get_stat(&"vigor_regen"), base_vigor), "Buff expira")
	fire.free()
	player.free()
	print("  ✓ Descansado aplicado, renovado, expirado e removido no Caído")

func test_bed_respawn() -> void:
	print("\n[5/6] Cama marca o renascer; sem cama, acampamento...")
	var player := _spawn_player()
	player.spawn_point = Vector3(0, 1.2, 0)
	var me := BuildingSystem.owner_name_of(player)
	var bed := _piece(BuildablePiece.PieceType.CAMA, Vector3(50, 0, 50), me)
	assert(BuildingSystem.has_bed(self, me) and not BuildingSystem.has_bed(self, "Outro"), "Uma cama por personagem")
	assert(player.lie_in_bed(bed) and player.marked_bed == bed, "Deitar marca a cama")
	player.toggle_sit(false)
	assert(player.respawn_point().distance_to(bed.global_position) < 2.0, "Renasce ao lado da cama")
	player.pools.take_damage(1000.0)
	player.downed_timer = 0.0
	player._process_downed(0.1)
	assert(player.global_position.distance_to(bed.global_position) < 2.0, "Caído volta para a cama")
	bed.free()
	assert(player.respawn_point() == player.spawn_point and player.marked_bed == null, "Cama desmontada: volta ao acampamento")
	player.free()
	print("  ✓ Cama vira renascer e some com a peça")

func test_save() -> void:
	print("\n[6/6] Save: buff Descansado e cama marcada...")
	var save_game: Node = root.get_node("SaveGame")
	var p1 := _spawn_player()
	var bed := _piece(BuildablePiece.PieceType.CAMA, Vector3(-40, 0, 55), BuildingSystem.owner_name_of(p1))
	p1.lie_in_bed(bed)
	p1.toggle_sit(false)
	p1.rest.apply_rested(321.0)
	var data: Dictionary = JSON.parse_string(JSON.stringify(save_game.collect(p1)))
	assert(data.has("bed") and absf(float(data["rest"]["rested_left"]) - 321.0) < 0.2, "Save guarda cama e buff")
	p1.free()
	bed.free()
	var p2: Player = PlayerScene.instantiate() as Player
	root.add_child(p2)
	p2.set_physics_process(false)
	save_game.apply_save(p2, data)
	assert(p2.rest.has_rested() and absf(p2.rest.rested_left - 321.0) < 0.2, "Buff volta com o tempo que faltava")
	assert(p2.marked_bed != null and p2.marked_bed.global_position.distance_to(Vector3(-40, 0, 55)) < 0.5, "Cama marcada volta")
	for n in get_nodes_in_group("built_structures"):
		n.free()
	p2.free()
	print("  ✓ Buff e cama sobrevivem ao save")

func _piece(type: BuildablePiece.PieceType, at: Vector3, owner: String) -> BuildablePiece:
	var p := BuildablePiece.new()
	p.piece_type = type
	p.owner_name = owner
	p.position = at
	root.add_child(p)
	return p
