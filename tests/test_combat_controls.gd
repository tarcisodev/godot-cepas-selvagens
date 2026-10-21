extends SceneTree

## Validação dos Controles de Combate, Mira e Novos Estilos de Armas:
## 1. Cajado Arcano: Mira pelo ombro (Right Click) + Disparo Arcano (Left Click mirando)
##    e Ataque Melee físico (Left Click sem mirar).
## 2. Martelo Pesado: Balanço rápido primário + Investida demolidora secundária.
## 3. Espada e Escudo: Bloqueio secundário + Pancada com escudo (contra-ataque).
## 4. Retícula no HUD sincronizada com modo de mira.

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const SWORD: WeaponStyle = preload("res://resources/weapons/sword_shield.tres")
const HAMMER: WeaponStyle = preload("res://resources/weapons/heavy_hammer.tres")
const STAFF: WeaponStyle = preload("res://resources/weapons/arcane_staff.tres")

var _started: bool = false

func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false

func _run() -> void:
	print("\n========================================================")
	print("🎯 VALIDANDO CONTROLES DE COMBATE E MIRA (GODOT 4.7)")
	print("========================================================")

	test_staff_aim_and_attacks()
	test_hammer_swing_and_lunge()
	test_sword_shield_block_and_counter()
	test_hud_reticle_integration()

	print("\n🎉 CONTROLES DE COMBATE E MIRA PASSARAM COM SUCESSO!")
	print("========================================================\n")
	quit(0)

func _spawn_player() -> Player:
	var player: Player = PlayerScene.instantiate() as Player
	root.add_child(player)
	return player

func test_staff_aim_and_attacks() -> void:
	print("\n[1/4] Cajado Arcano: ataque melee, modo de mira e dardo arcano...")
	var player := _spawn_player()
	player.equip_style(STAFF)

	# 1. Ataque corpo a corpo sem mirar (Left Click padrão)
	assert(player.weapon_style.primary != null, "Cajado tem ataque primário")
	assert(player.weapon_style.primary.kind == StyleAttack.Kind.MELEE, "Primário do cajado é corpo a corpo")
	var vigor_before: float = player.pools.current_vigor
	assert(player.try_attack(player.weapon_style.primary), "Golpe melee de cajado inicia com sucesso")
	assert(is_equal_approx(player.pools.current_vigor, vigor_before - player.weapon_style.primary.cost), "Golpe físico gasta Vigor")
	player._process_attack(player.weapon_style.primary.hit_delay + 0.05)
	assert(player.attack_hitbox._is_active, "Hitbox corpo a corpo ativa")
	assert(is_equal_approx(player.attack_hitbox.damage, 18.0), "Dano do golpe físico é 18")
	player._process_attack(player.weapon_style.primary.duration)
	assert(player.current_attack == null, "Golpe físico finalizado")

	# 2. Modo de Mira (Right Click)
	assert(player.weapon_style.secondary != null, "Cajado tem secundário")
	assert(player.weapon_style.secondary.kind == StyleAttack.Kind.AIM, "Secundário do cajado é AIM")
	assert(not player.try_attack(player.weapon_style.secondary), "AIM não é disparado via try_attack")

	# Ativa mira
	player._set_aiming(true)
	assert(player.is_aiming, "Jogador entrou em modo de mira")
	assert(player.camera_rig.is_aiming, "CameraRig sincronizado em modo de mira")

	# Simula processo da câmera para interpolar zoom, offset e fov
	player.camera_rig._process(0.1)
	assert(player.camera_rig.spring_arm.spring_length < player.camera_rig.default_distance, "Câmera aproxima no ombro")
	assert(player.camera_rig.camera.fov < player.camera_rig.normal_fov, "FOV diminui durante mira (zoom tático)")

	# Raycast de mira retorna um ponto 3D válido
	var aim_target: Vector3 = player.camera_rig.get_aim_target(30.0)
	assert(aim_target.is_finite(), "Ponto de mira calculado no mundo")

	# 3. Disparo Arcano durante a mira (Left Click mirando)
	assert(player.weapon_style.aim_attack != null, "Cajado possui aim_attack configurado")
	assert(player.weapon_style.aim_attack.kind == StyleAttack.Kind.PROJECTILE, "aim_attack é projétil")
	var ether_before: float = player.pools.current_ether
	assert(player.try_attack(player.weapon_style.aim_attack), "Disparo arcano inicia durante a mira")
	assert(is_equal_approx(player.pools.current_ether, ether_before - player.weapon_style.aim_attack.cost), "Disparo arcano consome Éter")

	var child_count_before: int = root.get_child_count()
	player._process_attack(player.weapon_style.aim_attack.hit_delay + 0.02)
	assert(root.get_child_count() == child_count_before + 1, "ArcaneBolt instanciado no mundo")
	var bolt: Node = root.get_child(root.get_child_count() - 1)
	assert(bolt is ArcaneBolt, "Projétil é da classe ArcaneBolt")
	bolt.free()
	player._process_attack(player.weapon_style.aim_attack.duration)

	# Desativa mira
	player._set_aiming(false)
	assert(not player.is_aiming, "Mira desativada")
	assert(not player.camera_rig.is_aiming, "CameraRig voltou ao modo normal")

	player.free()
	print("  ✓ Cajado arcano validado com perfeição!")

func test_hammer_swing_and_lunge() -> void:
	print("\n[2/4] Martelo Pesado: balanço rápido primário e investida secundária...")
	var player := _spawn_player()
	player.equip_style(HAMMER)

	# 1. Balanço rápido no botão esquerdo (primary)
	assert(player.weapon_style.primary.kind == StyleAttack.Kind.MELEE, "Primário do martelo é golpe rápido MELEE")
	assert(player.weapon_style.primary.damage == 26.0, "Dano do balanço rápido é 26")
	assert(player.weapon_style.primary.duration <= 0.5, "Duração ágil de balanço rápido")
	var vigor_before: float = player.pools.current_vigor
	assert(player.try_attack(player.weapon_style.primary), "Balanço rápido inicia")
	assert(is_equal_approx(player.pools.current_vigor, vigor_before - player.weapon_style.primary.cost), "Balanço gasta Vigor")
	player._process_attack(player.weapon_style.primary.duration)

	# 2. Investida demolidora no botão direito (secondary)
	assert(player.weapon_style.secondary.kind == StyleAttack.Kind.LUNGE, "Secundário do martelo é LUNGE")
	assert(player.weapon_style.secondary.damage == 48.0, "Investida tem alto dano de 48")
	assert(player.weapon_style.secondary.poise_damage >= 40.0, "Investida quebra postura")
	vigor_before = player.pools.current_vigor
	assert(player.try_attack(player.weapon_style.secondary), "Investida pesada inicia")
	assert(is_equal_approx(player.pools.current_vigor, vigor_before - player.weapon_style.secondary.cost), "Investida consome Vigor")
	player._process_attack(player.weapon_style.secondary.hit_delay + 0.05)
	assert(player._is_lunging(), "Jogador está em movimento de avanço / lunge")
	player._process_attack(player.weapon_style.secondary.duration)
	assert(not player._is_lunging(), "Avanço termina após duração do golpe")

	player.free()
	print("  ✓ Martelo pesado validado com sucesso!")

func test_sword_shield_block_and_counter() -> void:
	print("\n[3/4] Espada e Escudo: bloqueio e pancada com escudo (counter)...")
	var player := _spawn_player()
	player.equip_style(SWORD)

	# 1. Primário: combo de espada
	assert(player.weapon_style.primary.kind == StyleAttack.Kind.MELEE, "Primário é corte de espada")
	assert(player.weapon_style.primary.damage == 22.0, "Dano de espada 22")

	# 2. Secundário: Bloqueio
	assert(player.weapon_style.secondary.kind == StyleAttack.Kind.BLOCK, "Secundário é Bloqueio")

	# 3. Counter: Pancada com escudo
	assert(player.weapon_style.block_counter != null, "Possui golpe de contra-ataque configurado")
	assert(player.weapon_style.block_counter.kind == StyleAttack.Kind.MELEE, "Pancada é dano de impacto MELEE")
	assert(player.weapon_style.block_counter.poise_damage == 28.0, "Pancada causa 28 de dano na postura")

	var vigor_before: float = player.pools.current_vigor
	assert(player.try_attack(player.weapon_style.block_counter), "Pancada com escudo inicia")
	assert(is_equal_approx(player.pools.current_vigor, vigor_before - player.weapon_style.block_counter.cost), "Pancada gasta Vigor")
	player._process_attack(player.weapon_style.block_counter.hit_delay + 0.05)
	assert(player.attack_hitbox._is_active, "Hitbox da pancada de escudo ativada")
	assert(is_equal_approx(player.attack_hitbox.damage, 16.0), "Dano da pancada é 16")
	player._process_attack(player.weapon_style.block_counter.duration)

	player.free()
	print("  ✓ Espada, escudo e contra-ataque validados!")

func test_hud_reticle_integration() -> void:
	print("\n[4/4] Sinais de mira e sincronização do HUD...")
	var player := _spawn_player()
	var aim_signals: Array[bool] = []
	player.aim_changed.connect(func(aiming: bool): aim_signals.append(aiming))

	player._set_aiming(true)
	assert(aim_signals.size() == 1 and aim_signals[0] == true, "Sinal aim_changed(true) emitido ao entrar em mira")

	player._set_aiming(false)
	assert(aim_signals.size() == 2 and aim_signals[1] == false, "Sinal aim_changed(false) emitido ao sair de mira")

	# Valida chamada direta do método _on_aim_changed do HUD
	var hud := WorldHUD.new()
	var reticle := Control.new()
	reticle.visible = false
	hud.reticle = reticle
	hud._on_aim_changed(true)
	assert(reticle.visible, "HUD ativa retícula no evento de mira")
	hud._on_aim_changed(false)
	assert(not reticle.visible, "HUD desativa retícula ao cessar mira")

	reticle.free()
	hud.free()
	player.free()
	print("  ✓ Sinais de mira e integração HUD validados!")
