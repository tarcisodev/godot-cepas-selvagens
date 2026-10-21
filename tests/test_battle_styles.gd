extends SceneTree

## B10: estilos de batalha, bloqueio, Caído, Mestre de Armas e monstros de teste.

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const TrainerScene: PackedScene = preload("res://scenes/weapon_trainer.tscn")
const SlimeScene: PackedScene = preload("res://scenes/monsters/slime.tscn")
const SWORD: WeaponStyle = preload("res://resources/weapons/sword_shield.tres")
const HAMMER: WeaponStyle = preload("res://resources/weapons/heavy_hammer.tres")
const STAFF: WeaponStyle = preload("res://resources/weapons/arcane_staff.tres")

# Roda no primeiro frame: só aí a raiz está na árvore e add_child chama o _ready dos nós
var _started: bool = false

func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false

func _run() -> void:
	print("\n========================================================")
	print("⚔ VALIDANDO ESTILOS DE BATALHA E ARENA DE TESTE (B10)")
	print("========================================================")

	test_styles_change_bar_load_and_visual()
	test_attack_phases()
	test_block_and_downed()
	test_trainer_swaps_style()
	test_monster_ai_cycle()

	print("\n🎉 B10 VALIDADO: TODOS OS TESTES PASSARAM!")
	print("========================================================\n")
	quit(0)

func _spawn_player() -> Player:
	var player: Player = PlayerScene.instantiate() as Player
	root.add_child(player)
	return player

func test_styles_change_bar_load_and_visual() -> void:
	print("\n[1/5] Troca de estilo: básicos, Carga e peças visíveis...")
	var player := _spawn_player()
	assert(player.weapon_style == SWORD, "Começa com espada e escudo")
	var base_load: float = player.stats.get_stat(&"load") - SWORD.weight
	for style in [SWORD, HAMMER, STAFF]:
		player.equip_style(style)
		assert(player.weapon_style == style, "Estilo equipado")
		assert(is_equal_approx(player.stats.get_stat(&"load"), base_load + style.weight), "Peso do estilo na Carga (sem acumular)")
		assert(player.character_visual._equipment_sockets.size() == style.pieces.size(), "Uma peça visível por item do estilo")
		assert(player.character_visual.weapon != null, "Arma presa na mão")
	player.free()
	print("  ✓ Estilos trocam barra, peso e visual")

func test_attack_phases() -> void:
	print("\n[2/5] Golpe em fases: custo, preparação, golpe ativo e fim...")
	var player := _spawn_player()
	player.equip_style(HAMMER)
	var vigor_before: float = player.pools.current_vigor
	assert(player.try_attack(HAMMER.primary), "Golpe pesado começa")
	assert(is_equal_approx(player.pools.current_vigor, vigor_before - HAMMER.primary.cost), "Golpe pesado gasta Vigor")
	assert(not player.try_attack(HAMMER.primary), "Não começa outro golpe no meio do primeiro")
	player._process_attack(HAMMER.primary.hit_delay * 0.5)
	assert(not player.attack_hitbox._is_active, "Hitbox ainda desligada na preparação")
	player._process_attack(HAMMER.primary.hit_delay * 0.6)
	assert(player.attack_hitbox._is_active, "Hitbox liga depois da preparação")
	assert(is_equal_approx(player.attack_hitbox.damage, HAMMER.primary.damage), "Dano do golpe vem do estilo")
	assert(player.attack_hitbox.damage_type == DamageType.Type.IMPACT, "Martelo bate com impacto")
	player._process_attack(HAMMER.primary.duration)
	assert(player.current_attack == null and not player.is_attacking, "Golpe termina")

	player.equip_style(STAFF)
	var ether_before: float = player.pools.current_ether
	assert(player.try_attack(STAFF.primary), "Dardo arcano começa")
	assert(player.pools.current_ether < ether_before, "Cajado gasta Éter")
	var children_before: int = root.get_child_count()
	player._process_attack(STAFF.primary.hit_delay + 0.01)
	assert(root.get_child_count() == children_before + 1, "Dardo arcano é disparado no mundo")
	var bolt: Node = root.get_child(root.get_child_count() - 1)
	assert(bolt is ArcaneBolt, "O projétil é um ArcaneBolt")
	bolt.free()
	player.free()
	print("  ✓ Fases, custos e projétil funcionando")

func test_block_and_downed() -> void:
	print("\n[3/5] Bloqueio frontal, guarda pelas costas e Caído...")
	var player := _spawn_player()
	player.equip_style(SWORD)
	var attacker := Node3D.new()
	root.add_child(attacker)
	var facing: Vector3 = -player.visual_mesh.global_basis.z
	attacker.global_position = player.global_position + facing * 1.5

	player.is_blocking = true
	var hit := HitEvent.new(attacker, player, 30.0, DamageType.Type.SLASH, 20.0)
	var health_before: float = player.pools.current_health
	CombatResolver.resolve_hit(hit)
	var blocked_loss: float = health_before - player.pools.current_health
	assert(is_equal_approx(blocked_loss, 30.0 * Player.BLOCK_DAMAGE_MULT), "Bloqueio de frente segura 80% do dano")
	assert(player.pools.current_vigor < player.stats.get_stat(&"max_vigor"), "Vigor paga o golpe bloqueado")

	attacker.global_position = player.global_position - facing * 1.5
	health_before = player.pools.current_health
	CombatResolver.resolve_hit(HitEvent.new(attacker, player, 30.0, DamageType.Type.SLASH, 0.0))
	assert(is_equal_approx(health_before - player.pools.current_health, 30.0), "Golpe pelas costas passa pelo escudo")

	player.is_blocking = false
	CombatResolver.resolve_hit(HitEvent.new(attacker, player, 999.0, DamageType.Type.SLASH, 0.0))
	assert(player.is_downed, "Vida zerada = Caído")
	assert(not player.try_attack(SWORD.primary), "Caído não ataca")
	player._process_downed(Player.DOWNED_DURATION + 0.1)
	assert(not player.is_downed, "Levanta depois do tempo de Caído")
	assert(is_equal_approx(player.pools.current_health, player.stats.get_stat(&"max_health")), "Volta com Vida cheia")
	attacker.free()
	player.free()
	print("  ✓ Bloqueio direcional e ciclo de Caído validados")

func test_trainer_swaps_style() -> void:
	print("\n[4/5] Mestre de Armas troca o estilo...")
	var player := _spawn_player()
	var trainer: WeaponTrainer = TrainerScene.instantiate() as WeaponTrainer
	root.add_child(trainer)
	assert(trainer.is_in_group("talkable"), "Armeiro atende com [E]")
	player.pools.take_damage(40.0)
	trainer.talk_to(player)
	assert(trainer.is_open and trainer.is_in_group("open_menus"), "Menu abre e trava o combate")
	assert(is_equal_approx(player.pools.current_health, player.stats.get_stat(&"max_health")), "Conversar cura")
	assert(trainer._list.get_child_count() == 3, "Três estilos no menu")
	trainer.choose(STAFF)
	assert(player.weapon_style == STAFF, "Estilo escolhido é equipado")
	assert(not trainer.is_open and not trainer.is_in_group("open_menus"), "Menu fecha depois da escolha")
	trainer.free()
	player.free()
	print("  ✓ Troca no armeiro validada")

func test_monster_ai_cycle() -> void:
	print("\n[5/5] Monstro: persegue, avisa, ataca, morre e renasce...")
	var player := _spawn_player()
	var slime: TestMonster = SlimeScene.instantiate() as TestMonster
	root.add_child(slime)
	player.global_position = slime.global_position + Vector3(0, 0, -5.0)
	assert(slime.state == TestMonster.State.WANDER, "Nasce patrulhando")

	slime._physics_process(0.016)
	assert(slime.state == TestMonster.State.CHASE, "Vê o jogador e persegue")
	player.global_position = slime.global_position + Vector3(0, 0, -1.0)
	slime._physics_process(0.016)
	assert(slime.state == TestMonster.State.WINDUP, "Perto: prepara o golpe")
	assert(slime.warn_label.visible, "Aviso visível na preparação")
	slime._physics_process(slime.windup_time + 0.01)
	assert(slime.state == TestMonster.State.ATTACK and slime.hitbox._is_active, "Golpe ativo depois do aviso")
	assert(slime.hitbox.ignore_group == &"monsters", "Monstros não se acertam")

	var resisted := CombatResolver.resolve_hit(HitEvent.new(player, slime, 50.0, DamageType.Type.SLASH, 0.0))
	assert(resisted[&"effective_damage"] < 50.0, "Slime resiste a corte")
	slime.pools.take_damage(9999.0)
	assert(slime.state == TestMonster.State.DEAD, "Morre com Vida zerada")
	slime._physics_process(slime.respawn_delay + 0.1)
	assert(slime.state == TestMonster.State.WANDER, "Renasce")
	assert(is_equal_approx(slime.pools.current_health, slime.max_health), "Renasce com Vida cheia")

	player.global_position = slime.global_position + Vector3(0, 0, -1.0)
	player.is_downed = true
	slime._physics_process(0.016)
	assert(slime.state == TestMonster.State.WANDER, "Ignora o jogador Caído")
	slime.free()
	player.free()
	print("  ✓ Ciclo da IA validado")
