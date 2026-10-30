extends SceneTree

## B37 / GDD-16 fase 3: dano de queda (para todo mundo), salto da montaria voadora no ar e
## pegada no ar pela Companheira plena com o Apito de Osso ([H]). Nada de câmera lenta.

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")

var _started: bool = false
var _player: Player
var _eco: EcosystemSpawner
## Pista seca longe do rio (x inicial e sentido)
var _x0: float = 0.0
var _side: float = 1.0
const Z: float = 30.0

func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false

func _run() -> void:
	print("\n========================================================")
	print("🪶 TESTANDO QUEDA, SALTO E PEGADA NO AR (B37)")
	print("========================================================")
	var cx := RiverSystem.get_river_center_x(Z)
	_side = -1.0 if cx > 0.0 else 1.0
	_x0 = cx + _side * (RiverSystem.get_water_half_width(Z) + 15.0)
	# Chão de verdade em y = 0 para o CharacterBody3D pousar
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(400, 1, 400)
	shape.shape = box
	floor_body.add_child(shape)
	floor_body.position = Vector3(_x0 + _side * 100.0, -0.5, Z)
	root.add_child(floor_body)
	_player = PlayerScene.instantiate() as Player
	root.add_child(_player)
	_player._setup_components()
	_eco = EcosystemSpawner.new()
	for prop in ["trotador_herds", "saltarelos", "planadores", "raias", "lambari_schools", "trees", "bushes", "cepas", "mushrooms", "pinheira_groves"]:
		_eco.set(prop, 0)
	root.add_child(_eco)
	_player.inventory.add_material(&"apito_osso", 1)
	await test_fall_damage()
	await test_air_jump_and_glide()
	await test_air_catch()
	await test_catch_failures()
	print("\n🎉 TODOS OS TESTES DA PEGADA NO AR PASSARAM COM SUCESSO!")
	print("========================================================\n")
	quit(0)

func _at(dist: float, height: float) -> Vector3:
	return Vector3(_x0 + _side * dist, height, Z)

func _heal() -> void:
	_player.pools.heal(9999.0)

## Solta o jogador da altura dada e espera pousar; devolve a Vida perdida
func _drop(height: float) -> float:
	_heal()
	_player.velocity = Vector3.ZERO
	_player.global_position = _at(40.0, height)
	var hp := _player.pools.current_health
	for i in 600:
		await physics_frame
		if _player.is_on_floor() and _player.fall_speed == 0.0 and i > 2:
			break
	return hp - _player.pools.current_health

func test_fall_damage() -> void:
	print("\n[1/4] Dano de queda...")
	await _drop(1.0) # assenta no chão
	assert(await _drop(3.0) == 0.0, "3 m não machuca")
	var mid := await _drop(15.0)
	assert(mid > 30.0 and mid < 90.0, "15 m machuca bastante (%.0f)" % mid)
	var high := await _drop(21.0)
	assert(high > mid + 10.0 and high < _player.stats.get_stat(&"max_health"), "21 m machuca mais, quase tudo (%.0f)" % high)
	var t := clampf((sqrt(2.0 * _player.gravity * 30.0) - Player.FALL_SAFE_SPEED) / (Player.FALL_LETHAL_SPEED - Player.FALL_SAFE_SPEED), 0.0, 1.0)
	assert(t == 1.0, "Pela conta, 30 m tira a Vida inteira")
	# A esquiva não anula a queda (mas anula golpes)
	_player.is_dodging = true
	_player.dodge_timer = Player.DODGE_DURATION
	var fall := HitEvent.new(null, _player, 10.0, DamageType.Type.IMPACT, 0.0, &"queda")
	_player.filter_incoming_hit(fall)
	var blow := HitEvent.new(null, _player, 10.0, DamageType.Type.IMPACT, 0.0, &"body")
	_player.filter_incoming_hit(blow)
	assert(fall.raw_damage == 10.0 and blow.raw_damage == 0.0, "Esquiva não salva da queda")
	_player.is_dodging = false
	print("  ✓ 3 m: 0 · 15 m: −%.0f · 21 m: −%.0f · 30 m: Vida inteira" % [mid, high])

func _companion(elo: float) -> Mount:
	var dna := CreatureDNA.randomized(CreatureDNA.Species.PLANADOR, 31)
	var bond := MountBond.create(dna, &"ninho", 0)
	bond.elo = elo
	_eco.restore_owned([])
	assert(_eco.add_owned_mount(dna, bond), "Planador no estábulo")
	var m: Mount = _eco._owned_nodes[0]
	assert(_eco.set_companion(m), "Companheira")
	await process_frame # o _settle adiado do _ready assenta ela no chão antes de voar
	return m

## Voa com o jogador até a altura e salta (desmonta no ar)
func _jump_from(m: Mount, height: float) -> void:
	_heal()
	m.global_position = _at(40.0, height)
	m.mount(_player)
	m.airborne = true
	m._speed = 12.0
	m.dismount()

func test_air_jump_and_glide() -> void:
	print("\n[2/4] Salto no ar e planeio da montaria...")
	var m := await _companion(80.0)
	_jump_from(m, 18.0)
	assert(_player.mounted_on == null and _player.is_skydiving, "Saltou: queda livre")
	assert(_player.global_position.y > 14.0, "Saiu do dorso no alto, não no chão")
	assert(m.airborne and m.global_position.y > 17.0, "A montaria ficou no ar")
	assert(_player.velocity.length() > 5.0, "Leva o embalo do voo")
	await physics_frame
	await physics_frame
	assert(_player.character_visual == null or _player.character_visual.current() == &"A_TPose", "Braços abertos na queda")
	var hp := _player.pools.current_health
	for i in 400:
		await physics_frame
		if _player.is_on_floor() and _player.fall_speed == 0.0:
			break
	assert(_player.pools.current_health < hp - 40.0, "Sem pegada, a queda de 18 m machuca de verdade")
	assert(not _player.is_skydiving, "Pousou: fim da queda livre")
	var y0 := m.global_position.y
	for i in 30:
		await physics_frame
	assert(m.global_position.y < y0 - 0.5 and m.global_position.y > 0.0, "Sem cavaleiro ela desce planando devagar")
	m.global_position.y = 0.05
	await physics_frame
	await physics_frame
	assert(not m.airborne, "E pousa no chão")
	# Perto do chão, descer da voadora é descer normal
	m.global_position = _at(40.0, 2.0)
	m.mount(_player)
	m.airborne = true
	m.dismount()
	assert(not _player.is_skydiving and absf(_player.global_position.y - 0.1) < 0.2, "A 2 m do chão desce em pé, sem saltar")
	print("  ✓ Saltou de 18 m com embalo; ela ficou no ar e desceu planando")

func test_air_catch() -> void:
	print("\n[3/4] Pegada no ar...")
	var m := await _companion(80.0)
	_jump_from(m, 35.0)
	# Ela fica para trás: 20 m atrás e acima
	m.global_position = _player.global_position + Vector3(-_side * 20.0, 5.0, 0)
	m.stamina = Mount.STAMINA_MAX
	var hp := _player.pools.current_health
	assert(_eco.whistle(_player) == &"ok" and m.is_catching(), "[H] caindo: ela mergulha")
	assert(_eco.whistle(_player) == &"pegando", "Apitar de novo não reinicia")
	var t := 0.0
	while _player.mounted_on == null and t < 5.0:
		await physics_frame
		t += 1.0 / 60.0
	assert(_player.mounted_on == m, "Ela pegou o dono no ar")
	assert(_player.global_position.y > 3.0, "Pegou antes do chão (%.1f m)" % _player.global_position.y)
	assert(_player.pools.current_health >= hp and _player.fall_speed == 0.0, "Pegada: nada de dano de queda")
	assert(m.stamina < Mount.STAMINA_MAX - Mount.CATCH_STAMINA + 1.0, "O mergulho gasta fôlego")
	print("  ✓ Mergulhou 20 m e pegou em %.2f s, a %.1f m do chão" % [t, _player.global_position.y])

func test_catch_failures() -> void:
	print("\n[4/4] Quando a pegada falha...")
	var m := await _companion(60.0)
	_jump_from(m, 18.0)
	assert(_eco.whistle(_player) == &"elo_baixo" and not m.is_catching(), "Parceira (Elo 60) não pega no ar")
	m = await _companion(80.0)
	_jump_from(m, 18.0)
	m.global_position = _player.global_position + Vector3(-_side * 70.0, 0, 0)
	assert(_eco.whistle(_player) == &"longe", "A 70 m não alcança")
	m.global_position = _player.global_position + Vector3(-_side * 10.0, 0, 0)
	m.stamina = 5.0
	assert(_eco.whistle(_player) == &"cansada", "Sem fôlego não mergulha")
	m.stamina = Mount.STAMINA_MAX
	assert(_eco.whistle(_player) == &"ok", "Mergulhou")
	_player.pools.take_damage(5.0)
	await physics_frame
	await physics_frame
	assert(not m.is_catching() and _player.mounted_on == null, "Levou dano na queda: a pegada falha")
	await _land()
	# Longe e baixo: o chão chega antes dela
	m = await _companion(80.0)
	_jump_from(m, 8.0)
	m.global_position = _player.global_position + Vector3(-_side * 55.0, 20.0, 0)
	m.stamina = Mount.STAMINA_MAX
	var hp := _player.pools.current_health
	assert(_eco.whistle(_player) == &"ok", "Mergulhou de longe")
	await _land()
	assert(_player.mounted_on == null and not m.is_catching(), "Não chegou a tempo")
	assert(_player.pools.current_health < hp, "E a queda machucou")
	print("  ✓ Elo baixo, longe, cansada, dano na queda e chão antes dela: sem pegada")

func _land() -> void:
	for i in 400:
		await physics_frame
		if i > 2 and _player.is_on_floor() and _player.fall_speed == 0.0 and not _player.is_skydiving:
			return
