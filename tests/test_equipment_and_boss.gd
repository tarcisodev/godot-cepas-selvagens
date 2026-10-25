extends SceneTree

## B23 / GDD-12: encaixes do estilo Albion, famílias pelo revestimento, armas forjadas e duas mãos,
## estilo pela arma, habilidades de armadura, mochila e capa, veios e fundição, save antigo,
## peso do golpe (hitstop e empurrão sem mexer no tempo do mundo) e o Rinolito Ancião.

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const SlimeScene: PackedScene = preload("res://scenes/monsters/slime.tscn")
const SWORD_SHIELD: WeaponStyle = preload("res://resources/weapons/sword_shield.tres")
const SWORD: WeaponStyle = preload("res://resources/weapons/sword.tres")
const HAMMER: WeaponStyle = preload("res://resources/weapons/heavy_hammer.tres")
const UNARMED: WeaponStyle = preload("res://resources/weapons/unarmed.tres")

var _started: bool = false

func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false

func _run() -> void:
	print("\n========================================================")
	print("🛡️ TESTANDO EQUIPAMENTO, MINÉRIO, PESO DO GOLPE E BOSS (B23 / GDD-12)")
	print("========================================================")
	test_families_and_slots()
	test_weapons_and_two_hands()
	test_armor_abilities()
	test_bag_and_cape()
	test_ore_and_smelt()
	test_old_save_migration()
	test_combat_feel()
	test_boss()
	print("\n🎉 TODOS OS TESTES DO B23 PASSARAM COM SUCESSO!")
	print("========================================================\n")
	quit(0)

func _player() -> Player:
	var p: Player = PlayerScene.instantiate() as Player
	root.add_child(p)
	p._setup_components()
	p.set_physics_process(false)
	return p

func _forge(p: Player, recipe: StringName, core_id: StringName, core_n: int, coat_id: StringName, coat_n: int, q: int = 1) -> ForgedItem:
	p.inventory.add_material(core_id, core_n, q)
	if coat_id != core_id:
		p.inventory.add_material(coat_id, coat_n, q)
	else:
		p.inventory.add_material(coat_id, coat_n, q)
	var core: Dictionary = p.inventory.get_stacks(core_id)[0]
	var coat: Dictionary = p.inventory.get_stacks(coat_id)[0]
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var item := Forge.forge(p.inventory, recipe, core, coat, {}, 1, false, rng)
	assert(item != null, "Forjou %s" % recipe)
	p.inventory.add_item(item)
	return item

func test_families_and_slots() -> void:
	print("\n[1/8] Encaixes e família pelo revestimento...")
	assert(ForgedItem.SLOT_KEYS.size() == 7 and not ForgedItem.SLOT_KEYS.has(&"hands"), "7 encaixes, sem mãos")
	var p := _player()
	var load0 := p.stats.get_stat(&"load")
	var cota := _forge(p, &"cota_ferro", &"barra_ferro", 3, &"placa_carapaca", 2)
	assert(cota.family == &"ferro" and cota.slot == ForgedItem.Slot.BODY, "Cota com placa é de ferro, no peito")
	p.inventory.equip(cota)
	assert(is_equal_approx(p.stats.get_stat(&"load") - load0, 18.0), "Cota de ferro pesa 18")
	var cota_couro := _forge(p, &"cota_ferro", &"barra_ferro", 3, &"couro_trotador", 2)
	assert(cota_couro.family == &"couro" and cota_couro.display_name.contains("de Couro"), "Mesma receita com couro vira couro")
	var fx_ferro := cota.effects()
	var fx_couro := cota_couro.effects()
	assert(is_equal_approx(fx_couro[&"load"], 18.0 / 1.6), "Carga do couro = ferro ÷ 1,6")
	assert(is_equal_approx(fx_couro[&"resist_slash"], fx_ferro[&"resist_slash"] / 1.4), "Mitigação do couro = ferro ÷ 1,4")
	assert(fx_couro.has(&"dodge_cost") and fx_ferro.has(&"poise_resist"), "Cada família tem o seu extra")
	# Maestria da família: XP de dano mitigado vai para armadura_pesada com a cota
	var heavy0 := p.mastery.get_xp(&"armadura_pesada")
	var hit := HitEvent.new(null, p, 20.0, DamageType.Type.SLASH, 0.0)
	p.mastery._on_hit_resolved(hit, 10.0, false)
	assert(p.mastery.get_xp(&"armadura_pesada") > heavy0, "Peça de ferro dá XP de armadura pesada")
	p.free()
	print("  ✓ 7 encaixes, família pelo revestimento, fator de Carga e mitigação, XP por família")

func test_weapons_and_two_hands() -> void:
	print("\n[2/8] Armas forjadas, duas mãos e estilo pela arma...")
	var p := _player()
	p.ensure_starter_weapons()
	assert(p.inventory.equipped_in(ForgedItem.Slot.MAIN_HAND) != null and p.inventory.equipped_in(ForgedItem.Slot.OFF_HAND) != null, "Kit inicial: espada e escudo de treino")
	assert(p.weapon_style == SWORD_SHIELD, "Espada + escudo = espada e escudo")
	p.inventory.unequip(ForgedItem.Slot.OFF_HAND)
	assert(p.weapon_style == SWORD, "Sem escudo = espada sozinha (corte pesado no direito)")
	var mangual := _forge(p, &"mangual", &"pedra", 6, &"madeira", 2, 3)
	p.inventory.equip(p.inventory.items.filter(func(it): return it.recipe_id == &"escudo")[0])
	p.inventory.equip(mangual)
	assert(p.weapon_style == HAMMER and p.inventory.equipped_in(ForgedItem.Slot.OFF_HAND) == null, "Mangual é de duas mãos: tira o escudo")
	assert(is_equal_approx(p.weapon_power, ForgedItem.QUALITY_MULT[mangual.quality] * 0.85), "Força = qualidade × núcleo de pedra (0,85)")
	var scaled := p._scaled_attack(p.weapon_style.primary)
	assert(is_equal_approx(scaled.damage, HAMMER.primary.damage * p.weapon_power) and HAMMER.primary.damage == 26.0, "Golpe sai com a força da arma; o recurso não muda")
	p.inventory.equip(p.inventory.items.filter(func(it): return it.recipe_id == &"escudo")[0])
	assert(p.inventory.equipped_in(ForgedItem.Slot.MAIN_HAND) == null and p.weapon_style == UNARMED, "Escudo tira a arma de duas mãos: punhos")
	assert(Forge.salvage(p.inventory.items[0], p.inventory).is_empty(), "Peça de treino não devolve material")
	p.free()
	print("  ✓ Kit de treino, espada/escudo, duas mãos, força da arma e punhos")

func test_armor_abilities() -> void:
	print("\n[3/8] Habilidades de armadura [4] [5] [R]...")
	var p := _player()
	var ab := p.armor_abilities
	assert(ab.use_slot(ForgedItem.Slot.HEAD) != "", "Sem peça, sem habilidade")
	var capuz := _forge(p, &"capuz_penacho", &"pena_penacho", 3, &"fibra", 4)
	p.inventory.equip(capuz)
	assert(capuz.family == &"pano" and ab.ability_in(ForgedItem.Slot.HEAD) == &"foco", "Capuz de pano dá Foco")
	var regen0 := p.stats.get_stat(&"ether_regen")
	assert(ab.use_slot(ForgedItem.Slot.HEAD) == "", "Foco usado")
	assert(p.stats.get_stat(&"ether_regen") > regen0 * 1.9 and ab.cooldown_left(&"foco") > 19.0, "Éter em dobro e recarga de 20 s")
	assert(ab.use_slot(ForgedItem.Slot.HEAD) != "", "Em recarga não usa de novo")
	ab._process(5.1)
	assert(is_equal_approx(p.stats.get_stat(&"ether_regen"), regen0), "Foco acaba em 5 s")
	# Peito de couro: Esquivo
	var gibao := _forge(p, &"gibao_andarilho", &"couro_trotador", 3, &"tendao_elastico", 1)
	p.inventory.equip(gibao)
	assert(ab.use_slot(ForgedItem.Slot.BODY) == "" and is_equal_approx(ab.take_free_dodge(), ArmorAbilityComponent.FREE_DODGE_IFRAMES), "Esquivo: próxima esquiva grátis e longa")
	assert(ab.take_free_dodge() == 0.0, "Só uma esquiva grátis")
	# Peito de pano: Véu absorve
	var gibao_pano := _forge(p, &"gibao_andarilho", &"couro_trotador", 3, &"fibra", 4)
	p.inventory.equip(gibao_pano)
	p.pools.current_ether = 100.0
	assert(ab.use_slot(ForgedItem.Slot.BODY) == "", "Véu usado")
	var hit := HitEvent.new(null, p, 30.0, DamageType.Type.SLASH, 10.0)
	ab.filter_hit(hit)
	assert(hit.raw_damage == 0.0 and is_equal_approx(ab.veil_hp, 10.0), "Véu absorve 30 dos 40")
	# Elmo com chifre de Rinolito: Investida no lugar do Brado
	var elmo := _forge(p, &"elmo_chifre_de_pedra", &"chifre_rinolito", 1, &"placa_carapaca", 2)
	p.inventory.equip(elmo)
	assert(ab.ability_in(ForgedItem.Slot.HEAD) == &"investida", "Chifre de Rinolito dá Investida")
	p.pools.current_vigor = 100.0
	assert(ab.use_slot(ForgedItem.Slot.HEAD) == "" and p.current_attack != null and p.current_attack.kind == StyleAttack.Kind.LUNGE, "Investida sai como avanço")
	p._end_attack()
	# Botas de ferro: Pisão
	var botas := _forge(p, &"botas_saltarelo", &"pele_saltarelo", 2, &"barra_ferro", 1)
	p.inventory.equip(botas)
	assert(botas.family == &"ferro" and ab.ability_in(ForgedItem.Slot.FEET) == &"pisao", "Botas com ferro dão Pisão")
	assert(ab.use_slot(ForgedItem.Slot.FEET) == "" and p.current_attack.kind == StyleAttack.Kind.AREA, "Pisão sai como golpe em área")
	p.free()
	print("  ✓ Foco, Esquivo, Véu, Investida do chifre e Pisão; recarga e custo")

func test_bag_and_cape() -> void:
	print("\n[4/8] Mochila e capa...")
	var p := _player()
	assert(is_equal_approx(p.inventory.carry_capacity(), 20.0), "Sem mochila: 20 kg")
	var bag := _forge(p, &"mochila", &"couro_trotador", 2, &"tendao_elastico", 1)
	p.inventory.equip(bag)
	assert(bag.family == &"couro" and is_equal_approx(p.inventory.carry_capacity(), 60.0), "Mochila de couro: 60 kg")
	assert(is_zero_approx(bag.effects()[&"load"]), "Mochila não pesa na Carga de combate")
	p.inventory.add_material(&"pedra", 200)
	assert(p.is_overloaded() and p.carry_speed_factor() < 1.0, "Muito peso: lento e sem esquiva")
	var cape := _forge(p, &"capa_penas", &"pena_penacho", 4, &"fibra", 2)
	p.inventory.equip(cape)
	assert(p.armor_abilities.cape_passive() == &"queda_lenta", "Capa de Penas: queda lenta")
	p.free()
	print("  ✓ Limite da mochila, lentidão acima dele e passiva da capa")

func test_ore_and_smelt() -> void:
	print("\n[5/8] Veio de ferro e fundição...")
	var p := _player()
	var vein := GatherableResource.new()
	vein.type = GatherableResource.Type.VEIO_FERRO
	root.add_child(vein)
	assert(vein.max_hits == 4 and vein.mastery_tag == &"mineracao", "Veio aguenta 4 batidas, maestria mineração")
	for i in 3:
		vein.harvest_next(p)
		assert(vein.is_harvestable(), "Ainda tem minério depois da batida %d" % (i + 1))
	vein.harvest_next(p)
	assert(not vein.is_harvestable(), "Some na quarta batida")
	var ore := p.inventory.get_material_count(&"minerio_ferro")
	assert(ore >= 4 and ore <= 8, "4 batidas rendem 4–8 minérios (%d)" % ore)
	vein.respawn()
	assert(vein.hits_left == 4, "Volta inteiro")
	p.inventory.add_material(&"madeira", 1)
	var bars0 := p.inventory.get_material_count(&"barra_ferro")
	assert(Forge.smelt(p.inventory, &"barra_ferro") == "", "Fundiu")
	assert(p.inventory.get_material_count(&"barra_ferro") == bars0 + 1 and p.inventory.get_material_count(&"minerio_ferro") == ore - 2, "2 minérios + 1 madeira = 1 barra")
	assert(Forge.smelt(p.inventory, &"barra_ferro") != "", "Sem madeira não funde")
	vein.free()
	p.free()
	print("  ✓ Batidas do veio, volta e fundição da barra")

func test_old_save_migration() -> void:
	print("\n[6/8] Save antigo: braçadeiras viram couraça...")
	var old := {"recipe": "bracadeiras_galhada", "name": "Braçadeiras de Galhada", "slot": 2, "quality": 3,
		"traits": ["ossudo"], "durability": 80.0, "max": 100.0, "materials": {"chifre_galhado": 1, "couro_trotador": 1}}
	var it := ForgedItem.from_dict(old)
	assert(it.recipe_id == &"couraca_galhada" and it.slot == ForgedItem.Slot.BODY and it.quality == 3, "Virou Couraça de Galhada no peito, mesmas ★")
	assert(it.family == &"couro" and it.display_name == "Couraça de Galhada", "Família couro e nome novo")
	var elmo := ForgedItem.from_dict({"recipe": "elmo_chifre_de_pedra", "name": "Elmo", "slot": 0, "quality": 2})
	assert(elmo.family == &"ferro" and elmo.slot == ForgedItem.Slot.HEAD, "Peça antiga sem família ganha a da receita")
	print("  ✓ Migração de saves de antes do GDD-12")

func test_combat_feel() -> void:
	print("\n[7/8] Peso do golpe: hitstop e empurrão locais...")
	var p := _player()
	var slime: TestMonster = SlimeScene.instantiate() as TestMonster
	root.add_child(slime)
	slime.set_physics_process(false)
	p.global_position = slime.global_position + Vector3(0, 0, 2.0)
	var scale_before := Engine.time_scale
	var hit := HitEvent.new(p, slime, 30.0, DamageType.Type.IMPACT, 40.0)
	hit.hit_position = slime.global_position + Vector3.UP
	var res := slime.hurtbox.receive_hit(hit)
	assert(res.get(&"success", false), "Golpe resolvido")
	assert(slime._hitstop > 0.1 and p._hitstop > 0.1, "Hitstop nos dois (golpe pesado)")
	assert(slime._knockback.length() > 1.0 and slime._knockback.z < 0.0, "Empurrão para longe de quem bateu")
	assert(Engine.time_scale == scale_before, "O tempo do mundo não mudou")
	assert(p.camera_rig == null or p.camera_rig.trauma > 0.0, "Tranco na câmera de quem bateu")
	assert(CombatFeel.hitstop_of(CombatFeel.weight_of(HitEvent.new(p, slime, 10.0, DamageType.Type.SLASH, 8.0))) < CombatFeel.hitstop_of(1.0), "Golpe leve para menos que o pesado")
	slime.free()
	p.free()
	print("  ✓ Hitstop, empurrão e tranco sem mexer no Engine.time_scale")

func test_boss() -> void:
	print("\n[8/8] Rinolito Ancião...")
	var p := _player()
	var boss := BeastFighter.new()
	boss.config = BeastFighter.rinolito_anciao()
	root.add_child(boss)
	boss.set_physics_process(false)
	assert(boss.is_in_group("boss") and boss.is_in_group("monsters"), "Boss nos grupos")
	assert(is_equal_approx(boss.pools.current_health, 900.0) and is_equal_approx(boss.pools.current_poise, 220.0), "Vida 900, Postura 220")
	assert(boss.body.horn_node != null and boss.body.plates_node != null, "Corpo com chifre e placas")
	assert(boss.find_children("*", "Label3D", false, false).all(func(l): return l.text != "!"), "Sem aviso na tela")
	# Persegue quem entra na clareira
	p.global_position = boss.global_position + Vector3(0, 0, -3.0)
	boss._physics_process(0.016)
	assert(boss.state == BeastFighter.State.CHASE or boss.state == BeastFighter.State.WINDUP, "Vê o jogador e vai")
	# De frente e perto: chifrada ou pisão, com pose
	boss.rotation.y = 0.0
	var pick := boss._pick_attack(3.0, Vector3(0, 0, -3.0))
	assert(pick.id in [&"chifrada", &"pisao"], "Perto e de frente: chifrada ou pisão")
	boss._start_attack(pick)
	assert(boss.state == BeastFighter.State.WINDUP and boss.body.pose != &"", "Prepara com pose (o único aviso)")
	boss._physics_process(float(pick.windup) + 0.01)
	assert(boss.state == BeastFighter.State.ACTIVE and boss.hitbox._is_active, "Golpe ativo depois da pose")
	# Longe e de frente: investida
	assert(boss._pick_attack(12.0, Vector3(0, 0, -12.0)).get("id", &"") == &"investida", "Longe: investida")
	# Errou a investida: tonto
	boss._set_state(BeastFighter.State.CHASE)
	boss._start_attack(boss.config.attacks[2])
	boss._release_attack(p)
	boss._charge_left = 0.0
	boss._physics_process(0.016)
	assert(boss.state == BeastFighter.State.DAZED, "Investida que não acerta deixa tonto")
	# Chifre quebra com impacto e cai como material 4★ Cicatrizado
	var horns0 := p.inventory.get_material_count(&"chifre_rinolito")
	var impact := HitEvent.new(p, boss, 10.0, DamageType.Type.IMPACT, 0.0)
	boss.filter_incoming_hit(impact)
	assert(boss.damage_part(&"horn", 130.0), "130 de impacto × 1,5 quebra o chifre (180)")
	assert(boss.horn_broken and not boss.body.horn_node.visible, "Chifre some do corpo")
	var horn_stack: Dictionary = p.inventory.get_stacks(&"chifre_rinolito").filter(func(s): return s.quality == 4)[0]
	assert(p.inventory.get_material_count(&"chifre_rinolito") == horns0 + 1 and horn_stack.traits.has(&"cicatrizado"), "Chifre 4★ Cicatrizado na mochila")
	# Postura zerada: atordoado e leva mais dano
	var slash0 := boss.stats.get_stat(&"resist_slash")
	boss.pools.damage_poise(999.0)
	assert(boss.state == BeastFighter.State.STAGGER and boss.stats.get_stat(&"resist_slash") < slash0, "Atordoado com a defesa baixa")
	# Fúria abaixo de 50%
	boss.pools.take_damage(500.0)
	assert(boss.enraged, "Furioso abaixo de 50%")
	assert(boss.boss_bar_info().has("max_health"), "Barra do boss tem os números")
	# Morte e esfola: sem o chifre inteiro, o corpo não rende chifre
	boss.pools.take_damage(9999.0)
	assert(boss.state == BeastFighter.State.DEAD and boss.is_harvestable(), "Morre e pode ser esfolado")
	assert(boss.harvest_queue.all(func(h): return h.label != "Chifre do Ancião"), "Chifre quebrado na luta não sai de novo do corpo")
	var plates0 := p.inventory.get_material_count(&"placa_carapaca")
	while boss.is_harvestable():
		boss.harvest_next(p)
	assert(p.inventory.get_material_count(&"placa_carapaca") >= plates0 + 6, "Esfola rende as 6 placas")
	assert(boss.respawn_timer > 0.0, "Corpo vazio: volta em 10 min")
	boss.respawn()
	assert(boss.state == BeastFighter.State.IDLE and not boss.horn_broken and boss.body.horn_node.visible and is_equal_approx(boss.pools.current_health, 900.0), "Volta inteiro")
	boss.free()
	p.free()
	print("  ✓ Poses, golpes, investida errada, chifre, atordoado, fúria, esfola e volta")
