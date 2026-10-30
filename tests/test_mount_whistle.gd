extends SceneTree

## B37 / GDD-16 fase 2: Apito de Osso ([H]). A Companheira ouve dentro do alcance da faixa e vem
## pelo mundo (correndo, contornando paredão, ou voando alto), sem teleporte; para ao lado do dono.

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const DT: float = 1.0 / 30.0

## Chão plano com um paredão opcional (faixa em X de wall_x a wall_x + 2 m, de z0 - 4 a z0 + 4)
class FakeLand extends Node:
	var wall_x: float = INF
	var z0: float = 0.0
	func get_height_at(x: float, z: float) -> float:
		return 6.0 if x >= wall_x and x <= wall_x + 2.0 and absf(z - z0) <= 4.0 else 0.0

var _started: bool = false

func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false

func _run() -> void:
	print("\n========================================================")
	print("🎶 TESTANDO O APITO DE OSSO (B37)")
	print("========================================================")
	var player: Player = PlayerScene.instantiate() as Player
	root.add_child(player)
	player._setup_components()
	player.set_physics_process(false) # sem chão no teste
	var eco := EcosystemSpawner.new()
	for prop in ["trotador_herds", "saltarelos", "planadores", "raias", "lambari_schools", "trees", "bushes", "cepas", "mushrooms", "pinheira_groves"]:
		eco.set(prop, 0)
	root.add_child(eco)
	test_recipe_and_refusals(player, eco)
	test_land_call(player, eco)
	test_air_call(player, eco)
	test_cancel(player, eco)
	test_key(player, eco)
	print("\n🎉 TODOS OS TESTES DO APITO PASSARAM COM SUCESSO!")
	print("========================================================\n")
	quit(0)

## Pista seca ao lado do rio: começo e sentido (sem atravessar água)
func _lane(z: float) -> Array:
	var cx := RiverSystem.get_river_center_x(z)
	var side := -1.0 if cx > 0.0 else 1.0
	return [cx + side * (RiverSystem.get_water_half_width(z) + 10.0), side]

func _run_until(m: Mount, max_seconds: float) -> float:
	var t := 0.0
	while m.is_coming() and t < max_seconds:
		m._physics_process(DT)
		t += DT
	return t

func test_recipe_and_refusals(player: Player, eco: EcosystemSpawner) -> void:
	print("\n[1/5] Receita e quando o apito não chama...")
	assert(eco.whistle(player) == &"sem_apito", "Sem apito na mochila")
	var inv := player.inventory
	assert(not inv.craft(&"apito_osso"), "Sem material não faz")
	inv.add_material(&"ossos", 3)
	inv.add_material(&"fibra", 1)
	assert(inv.craft(&"apito_osso") and inv.get_material_count(&"apito_osso") == 1 and inv.get_material_count(&"ossos") == 0, "3 ossos + 1 fibra = Apito de Osso")
	assert(not MaterialData.of(&"apito_osso").is_tool() and not MaterialData.of(&"apito_osso").is_consumable(), "Não vai para a roda rápida: é o [H]")
	assert(eco.whistle(player) == &"sem_companheira", "Sem Companheira ninguém atende")
	print("  ✓ Receita no [Tab]; sem apito ou sem Companheira, nada acontece")

func test_land_call(player: Player, eco: EcosystemSpawner) -> void:
	print("\n[2/5] Trotador vem correndo e contorna o paredão...")
	var dna := CreatureDNA.randomized(CreatureDNA.Species.TROTADOR, 21)
	dna.alleles["porte"] = ["T", "T"]
	assert(eco.add_owned_mount(dna, MountBond.create(dna, &"cria", 0)), "Companheira Mansa (Elo 40, apito a 60 m)")
	var m: Mount = eco._owned_nodes[0]
	assert(eco.set_companion(m), "Vira Companheira")
	var land := FakeLand.new()
	root.add_child(land)
	m._landscape = land
	var z := 30.0
	var lane := _lane(z)
	var x0: float = lane[0]
	var side: float = lane[1]
	m.global_position = Vector3(x0, 0, z)
	player.global_position = Vector3(x0 + side * 80.0, 0, z)
	assert(eco.whistle(player) == &"longe" and not m.is_coming(), "A 80 m a Mansa não ouve")
	player.global_position = Vector3(x0 + side * 50.0, 0, z)
	# Paredão de 6 m no meio do caminho
	land.wall_x = x0 + side * 25.0 - (2.0 if side < 0.0 else 0.0)
	land.z0 = z
	var start := m.global_position
	assert(eco.whistle(player) == &"ok" and m.is_coming(), "A 50 m ouve e vem")
	assert(eco.whistle(player) == &"a_caminho", "Apitar de novo não reinicia")
	m._physics_process(DT)
	assert(m.global_position != start and m.global_position.distance_to(start) < 1.0, "Anda pelo mundo: nada de teleporte")
	var t := _run_until(m, Mount.CALL_TIMEOUT)
	var dist := Vector2(m.global_position.x, m.global_position.z).distance_to(Vector2(player.global_position.x, z))
	assert(not m.is_coming() and dist <= Mount.CALL_ARRIVE + 0.5, "Chegou ao lado do dono (%.1f m, %.1f s)" % [dist, t])
	assert(t > 50.0 / Mount.SPEEDS[Mount.Kind.LAND].y, "Levou o tempo de correr até lá (%.1f s)" % t)
	assert(m.global_position.y < 0.5, "Contornou o paredão em vez de subir nele")
	print("  ✓ Correu %.0f m em %.1f s, desviou do paredão e parou ao lado" % [50.0, t])

func test_air_call(player: Player, eco: EcosystemSpawner) -> void:
	print("\n[3/5] Planador vem voando alto e pousa...")
	var dna := CreatureDNA.randomized(CreatureDNA.Species.PLANADOR, 22)
	var bond := MountBond.create(dna, &"ninho", 0)
	bond.elo = 80.0
	assert(eco.add_owned_mount(dna, bond), "Planador Companheira plena (apito a 300 m)")
	var m: Mount = eco._owned_nodes[1]
	assert(eco.set_companion(m) and eco.companion_mount() == m, "Troca de Companheira")
	var flat := FakeLand.new()
	root.add_child(flat)
	m._landscape = flat
	m.global_position = Vector3(0, 0, -60)
	player.global_position = Vector3(0, 0, 140)
	assert(eco.whistle(player) == &"ok", "A 200 m a plena ouve")
	var peak := 0.0
	var t := 0.0
	while m.is_coming() and t < Mount.CALL_TIMEOUT:
		m._physics_process(DT)
		peak = maxf(peak, m.global_position.y)
		t += DT
	var dist := Vector2(m.global_position.x, m.global_position.z).distance_to(Vector2(0, 140))
	assert(not m.is_coming() and dist <= Mount.CALL_ARRIVE + 0.5, "Chegou (%.1f m)" % dist)
	assert(peak > Mount.CALL_FLY_HEIGHT * 0.7, "Voou alto no caminho (pico %.1f m)" % peak)
	assert(is_equal_approx(m.global_position.y, 0.0) and not m.airborne, "Pousou ao lado do dono")
	print("  ✓ Voou 200 m em %.1f s (pico %.1f m) e pousou" % [t, peak])

func test_cancel(player: Player, eco: EcosystemSpawner) -> void:
	print("\n[4/5] Chamado cancelado...")
	var m: Mount = eco.companion_mount()
	m.global_position = Vector3(0, 0, -20)
	player.global_position = Vector3(0, 0, 40)
	assert(eco.whistle(player) == &"ok", "Chamou")
	var other := Mount.new()
	other.dna = CreatureDNA.randomized(CreatureDNA.Species.TROTADOR, 23)
	root.add_child(other)
	other.mount(player)
	m._physics_process(DT)
	assert(not m.is_coming(), "Dono montou outra: ela para")
	assert(eco.whistle(player) == &"montado", "Montado não apita")
	other.dismount()
	other.queue_free()
	assert(eco.whistle(player) == &"ok", "Chamou de novo")
	m._call_time = 0.01
	m._physics_process(DT)
	m._physics_process(DT)
	assert(not m.is_coming() and not m.airborne, "Sem chegar a tempo, desiste e pousa")
	print("  ✓ Para se o dono montar outra ou se não chegar a tempo")

func test_key(player: Player, eco: EcosystemSpawner) -> void:
	print("\n[5/5] Tecla [H]...")
	var m: Mount = eco.companion_mount()
	m.global_position = Vector3(0, 0, -20)
	player.global_position = Vector3(0, 0, 40)
	var ev := InputEventKey.new()
	ev.keycode = KEY_H
	ev.pressed = true
	player._unhandled_input(ev)
	assert(m.is_coming(), "[H] apita")
	m._called_by = null
	var hud_src := FileAccess.get_file_as_string("res://scripts/hud.gd")
	assert(hud_src.contains("KEY_F2") and not hud_src.contains("keycode == KEY_H"), "As dicas da tela passaram para o [F2]")
	print("  ✓ [H] chama a Companheira; dicas no [F2]")
