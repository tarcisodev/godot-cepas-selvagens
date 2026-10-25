extends SceneTree

## GDD-12 §12: Lobo-do-Ermo (bando noturno, cerca pelos flancos, acorda a toca) e Tatu-Espinho
## (territorial, carapaça que quebra com impacto), esfola e os materiais novos na forja.

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")

var _started: bool = false

func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false

func _run() -> void:
	print("\n========================================================")
	print("🐺 TESTANDO LOBO-DO-ERMO E TATU-ESPINHO (GDD-12 §12)")
	print("========================================================")
	test_bodies()
	test_wolf_pack()
	test_armadillo()
	test_new_materials_in_forge()
	print("\n🎉 TODOS OS TESTES DOS BICHOS DO ERMO PASSARAM COM SUCESSO!")
	print("========================================================\n")
	quit(0)

func _player() -> Player:
	var p: Player = PlayerScene.instantiate() as Player
	root.add_child(p)
	p._setup_components()
	p.set_physics_process(false)
	return p

func _beast(cfg: Dictionary) -> BeastFighter:
	var b := BeastFighter.new()
	b.config = cfg
	root.add_child(b)
	b.set_physics_process(false)
	return b

func _sun(hour: float) -> DayNightCycle:
	var sun := DayNightCycle.new()
	sun.start_time_hour = hour
	sun.is_paused = true
	root.add_child(sun)
	sun.current_time_hours = hour
	return sun

func test_bodies() -> void:
	print("\n[1/4] Corpos procedurais...")
	var wolf := _beast(BeastFighter.lobo_do_ermo())
	var tatu := _beast(BeastFighter.tatu_espinho())
	assert(wolf.dna.species == CreatureDNA.Species.LOBO and tatu.dna.species == CreatureDNA.Species.TATU, "Espécies novas")
	assert(tatu.body.plates_node != null and wolf.body.plates_node == null and wolf.body.horn_node == null, "Tatu tem placas; lobo não tem placa nem chifre")
	assert(wolf._leg > tatu._leg, "Lobo de perna longa, tatu rente ao chão")
	assert(not wolf.is_in_group("boss") and not tatu.is_in_group("boss"), "Não são boss (sem barra no topo)")
	wolf.free()
	tatu.free()
	print("  ✓ Lobo esguio e tatu encouraçado, sem barra de boss")

func test_wolf_pack() -> void:
	print("\n[2/4] Bando de lobos...")
	var p := _player()
	var sun := _sun(12.0)
	var wolves: Array[BeastFighter] = []
	for j in 3:
		var w := _beast(BeastFighter.lobo_do_ermo())
		w.pack_id = "toca_teste"
		w.pack_slot = j
		w.global_position = Vector3(j * 2.0, 0, 0)
		w.home = w.global_position
		wolves.append(w)
	p.global_position = Vector3(0, 0, 8.0)
	wolves[0]._physics_process(0.016)
	assert(wolves[0].state == BeastFighter.State.IDLE and wolves[0].body.pose == &"head_low", "De dia o lobo dorme e não vê você a 8 m")
	sun.current_time_hours = 21.0
	wolves[0]._physics_process(0.016)
	assert(wolves[0].state == BeastFighter.State.CHASE, "À noite o lobo caça")
	# Apanhar acorda a toca inteira, mesmo de dia
	sun.current_time_hours = 12.0
	for w in wolves:
		w._set_state(BeastFighter.State.IDLE)
	var hit := HitEvent.new(p, wolves[1], 5.0, DamageType.Type.SLASH, 0.0)
	wolves[1].on_hit_feedback(hit, {&"effective_damage": 5.0})
	assert(wolves.all(func(w): return w.state == BeastFighter.State.CHASE), "Um lobo apanha, a toca toda acorda")
	# Bote longe; mordida perto
	wolves[0].rotation.y = 0.0
	assert(wolves[0]._pick_attack(6.0, Vector3(0, 0, -6.0)).get("id", &"") == &"bote", "A 6 m de frente: bote")
	assert(wolves[0]._pick_attack(1.5, Vector3(0, 0, -1.5)).get("id", &"") == &"mordida", "Perto: mordida")
	# Leve: o empurrão do golpe joga longe (o boss quase não sai do lugar)
	wolves[0].apply_knockback(Vector3(5, 0, 0))
	assert(wolves[0]._knockback.length() > 4.0, "Lobo voa com o golpe")
	# Esfola
	wolves[2].pools.take_damage(999.0)
	assert(wolves[2].is_harvestable(), "Lobo abatido pode ser esfolado")
	while wolves[2].is_harvestable():
		wolves[2].harvest_next(p)
	assert(p.inventory.get_material_count(&"couro_lobo") == 2 and p.inventory.get_material_count(&"presa_lobo") == 1, "2 couros e 1 presa")
	assert(wolves[2].respawn_timer > 0.0 and wolves[2].respawn_timer <= 180.0, "Volta em 3 min")
	for w in wolves:
		w.free()
	sun.free()
	p.free()
	print("  ✓ Dorme de dia, caça à noite, toca acorda junta, bote e mordida, esfola")

func test_armadillo() -> void:
	print("\n[3/4] Tatu-Espinho...")
	var p := _player()
	var tatu := _beast(BeastFighter.tatu_espinho())
	p.global_position = tatu.global_position + Vector3(0, 0, 10.0)
	tatu._physics_process(0.016)
	assert(tatu.state == BeastFighter.State.IDLE, "A 10 m o tatu não liga")
	p.global_position = tatu.global_position + Vector3(0, 0, 5.0)
	tatu._physics_process(0.016)
	assert(tatu.state != BeastFighter.State.IDLE, "A 5 m ele defende o canto")
	p.global_position = tatu.global_position + Vector3(0, 0, 20.0)
	tatu._set_state(BeastFighter.State.CHASE)
	tatu._physics_process(0.016)
	assert(tatu.state == BeastFighter.State.RETURN, "Fora do território ele volta")
	var slash := CombatResolver.resolve_hit(HitEvent.new(p, tatu, 100.0, DamageType.Type.SLASH, 0.0))
	assert(slash[&"effective_damage"] < 70.0, "Carapaça segura o corte")
	var plates0 := p.inventory.get_material_count(&"placa_carapaca")
	tatu.filter_incoming_hit(HitEvent.new(p, tatu, 1.0, DamageType.Type.IMPACT, 0.0))
	assert(tatu.damage_part(&"carapace", 45.0) and tatu.carapace_broken and not tatu.body.plates_node.visible, "Impacto quebra a carapaça")
	assert(p.inventory.get_material_count(&"placa_carapaca") == plates0 + 1, "Cai uma placa na hora")
	assert(tatu.stats.get_stat(&"resist_slash") < 0.01, "Sem carapaça o corte entra")
	tatu.free()
	p.free()
	print("  ✓ Território, carapaça contra corte, quebra com impacto e solta placa")

func test_new_materials_in_forge() -> void:
	print("\n[4/4] Couro, presa e garra na forja...")
	var p := _player()
	var inv := p.inventory
	var rng := RandomNumberGenerator.new()
	inv.add_material(&"couro_lobo", 3, 2)
	inv.add_material(&"tendao_elastico", 1, 2)
	var gibao := Forge.forge(inv, &"gibao_andarilho", inv.get_stacks(&"couro_lobo")[0], inv.get_stacks(&"tendao_elastico")[0], {}, 1, false, rng)
	assert(gibao != null and is_equal_approx(gibao.max_durability, 110.0), "Gibão de couro de lobo dura 10% mais")
	inv.add_material(&"barra_ferro", 2, 2)
	inv.add_material(&"couro_trotador", 1, 2)
	inv.add_material(&"presa_lobo", 1, 2)
	var espada := Forge.forge(inv, &"espada_ferro", inv.get_stacks(&"barra_ferro")[0], inv.get_stacks(&"couro_trotador")[0], inv.get_stacks(&"presa_lobo")[0], 10, false, rng)
	assert(espada != null and espada.traits.has(&"serrilhado"), "Presa de lobo serrilha a espada")
	assert(is_equal_approx(espada.weapon_power(), ForgedItem.QUALITY_MULT[espada.quality] * 1.06), "Serrilhado: +6% de dano")
	inv.add_material(&"pele_saltarelo", 2, 2)
	inv.add_material(&"fibra", 3, 2)
	inv.add_material(&"garra_tatu", 1, 2)
	var botas := Forge.forge(inv, &"botas_saltarelo", inv.get_stacks(&"pele_saltarelo")[0], inv.get_stacks(&"fibra")[0], inv.get_stacks(&"garra_tatu")[0], 10, false, rng)
	assert(botas != null and botas.traits.has(&"cravado") and botas.effects().get(&"poise_resist", 0.0) >= 0.06, "Garra de tatu crava as botas (+Postura)")
	p.free()
	print("  ✓ Couro de lobo, presa serrilhada e garra cravada")
