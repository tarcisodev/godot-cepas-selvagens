extends CharacterBody3D
class_name Player

## Controlador do Personagem: Andarilho Contemplativo
# Suporte a agachar (Ctrl), andar lento (Alt), correr (Shift),
# sentar/descansar e animação procedural suave.

@export_group("Velocidades")
@export var slow_walk_speed: float = 2.0
@export var walk_speed: float = 3.8
@export var sprint_speed: float = 7.0
@export var crouch_speed: float = 1.7
@export var acceleration: float = 8.0
@export var friction: float = 10.0
@export var jump_velocity: float = 4.2
@export var rotation_speed: float = 10.0

const CameraRigScript = preload("res://scripts/camera_rig.gd")

## Estilo de batalha atual (B10): define os 2 básicos, o peso e o que aparece no corpo.
@export var weapon_style: WeaponStyle = preload("res://resources/weapons/sword_shield.tres")

@export_group("Referências")
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var camera_rig: Node3D = $CameraRig
@onready var visual_mesh: Node3D = $VisualMesh
@onready var character_visual: CharacterVisual = get_node_or_null("VisualMesh/CharacterVisual")
@onready var stats: StatsComponent = $StatsComponent
@onready var pools: PoolsComponent = $PoolsComponent
@onready var attack_hitbox: HitboxComponent = $VisualMesh/AttackHitbox
@onready var mastery: MasteryComponent = get_node_or_null("MasteryComponent")
@onready var inventory: InventoryComponent = get_node_or_null("InventoryComponent")
@onready var card_collection: CardCollectionComponent = get_node_or_null("CardCollectionComponent")

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var is_first_person: bool = false
var is_crouching: bool = false
var is_sitting: bool = false
var is_dodging: bool = false
var is_attacking: bool = false
var is_casting: bool = false
var is_aiming: bool = false
var dodge_timer: float = 0.0
var dodge_dir: Vector3 = Vector3.FORWARD
const DODGE_DURATION: float = 0.36
const DODGE_SPEED: float = 8.5
## Início da esquiva sem dano (GDD-01 §8, carga leve)
const DODGE_IFRAMES: float = 0.2
# Golpes seguidos dentro da janela avançam as animações do básico (combo A → B → C)
const COMBO_WINDOW_MS: int = 700
var combo_step: int = 0
var last_attack_ms: int = -100000

# Golpe em andamento: preparação (hit_delay) → golpe ativo → recuperação
var current_attack: StyleAttack = null
var _last_attack: StyleAttack = null
var _attack_elapsed: float = 0.0
var _attack_hit_pending: bool = false
var _attack_dir: Vector3 = Vector3.FORWARD
var _style_source: RefCounted = RefCounted.new()

# Bloqueio frontal do escudo: segura parte do golpe e o Vigor paga o resto
var is_blocking: bool = false
const BLOCK_DAMAGE_MULT: float = 0.2
const BLOCK_POISE_MULT: float = 0.3
const BLOCK_VIGOR_PER_DAMAGE: float = 0.6
const BLOCK_ARC_DOT: float = 0.2

# Reação a golpe e Caído (Vida zerada; 5 s é valor de teste, o GDD-05 fala em 30 s)
const FLINCH_TIME: float = 0.3
var flinch_timer: float = 0.0
const DOWNED_DURATION: float = 5.0
var is_downed: bool = false
var downed_timer: float = 0.0
## Em duelo consensual aceito (GDD-05): libera o ataque dentro da cidade. Ainda sem convite no jogo.
var in_duel: bool = false
var spawn_point: Vector3 = Vector3.ZERO
var last_safe_position: Vector3 = Vector3(0.0, 1.2, 0.0)

# Armeiro e outros NPCs com [E]
const TALK_RANGE: float = 2.6
const QUICK_USE_KEYS: Dictionary = {KEY_1: &"health", KEY_2: &"vigor", KEY_3: &"ether"}
const QUICK_USE_NAMES: Dictionary = {&"health": "Vida", &"vigor": "Vigor", &"ether": "Éter"}

# Esfola manual (GDD-03 §8): segurar [E] perto do corpo; mover, soltar ou levar dano interrompe
const HARVEST_RANGE: float = 2.6
var is_harvesting: bool = false
var harvest_timer: float = 0.0
var harvest_target: Node3D = null
var harvest_start_health: float = 0.0

var footstep_player: AudioStreamPlayer3D
var dodge_player: AudioStreamPlayer3D
var attack_whoosh_player: AudioStreamPlayer3D
var footstep_sounds: Array[AudioStream] = []
var footstep_timer: float = 0.4

# Alturas da câmera
const STAND_CAM_Y: float = 1.5
const CROUCH_CAM_Y: float = 0.85
const SIT_CAM_Y: float = 0.65

signal posture_changed(state_name: String)
signal style_changed(style: WeaponStyle)
signal aim_changed(is_aiming: bool)

func _ready() -> void:
	add_to_group("player")
	_setup_components()

	if camera_rig and camera_rig.has_signal("camera_mode_changed"):
		camera_rig.camera_mode_changed.connect(_on_camera_mode_changed)

	_setup_footsteps()
	_setup_combat_audio()
	floor_snap_length = 0.35
	floor_max_angle = deg_to_rad(55.0)
	spawn_point = global_position if global_position.y > -5.0 else Vector3(0.0, 1.2, 0.0)
	last_safe_position = spawn_point
	if pools and not pools.health_depleted.is_connected(_on_health_depleted):
		pools.health_depleted.connect(_on_health_depleted)
	equip_style(weapon_style)

func _setup_components() -> void:
	if not is_in_group("player"):
		add_to_group("player")
	if stats == null:
		stats = get_node_or_null("StatsComponent") as StatsComponent
	if pools == null:
		pools = get_node_or_null("PoolsComponent") as PoolsComponent
	if pools and stats:
		pools.stats = stats
	if mastery == null:
		mastery = get_node_or_null("MasteryComponent") as MasteryComponent
		if mastery == null:
			mastery = MasteryComponent.new()
			mastery.name = "MasteryComponent"
			add_child(mastery)
	if inventory == null:
		inventory = get_node_or_null("InventoryComponent") as InventoryComponent
		if inventory == null:
			inventory = InventoryComponent.new()
			inventory.name = "InventoryComponent"
			add_child(inventory)
	if inventory and stats:
		inventory.stats = stats
	if inventory and not inventory.item_used.is_connected(_on_item_used):
		inventory.item_used.connect(_on_item_used)
	if card_collection == null:
		card_collection = get_node_or_null("CardCollectionComponent") as CardCollectionComponent
		if card_collection == null:
			card_collection = CardCollectionComponent.new()
			card_collection.name = "CardCollectionComponent"
			add_child(card_collection)

func _setup_footsteps() -> void:
	if footstep_player != null:
		return
	footstep_player = AudioStreamPlayer3D.new()
	footstep_player.name = "FootstepAudio"
	footstep_player.bus = &"Efeitos"
	footstep_player.volume_db = -8.0
	footstep_player.max_distance = 18.0
	add_child(footstep_player)
	
	# Carrega 4 passos naturais na grama do kit
	for i in range(1, 5):
		var p: String = "res://assets/audio/Small_Sound_Kit/Small Sound Kit/Footsteps/S_Grass_Mono_Without_Hitting_Boot_%d.wav" % i
		var s = load(p)
		if s:
			footstep_sounds.append(s)

func _setup_combat_audio() -> void:
	if attack_whoosh_player != null:
		return
	# Áudio de corte / swing de ataque
	attack_whoosh_player = AudioStreamPlayer3D.new()
	attack_whoosh_player.name = "AttackWhooshAudio"
	attack_whoosh_player.bus = &"Efeitos"
	var whoosh_stream = load("res://assets/audio/Small_Sound_Kit/Small Sound Kit/Magic/Mgc_Ice_Arrow_Cast_01.wav")
	if whoosh_stream:
		attack_whoosh_player.stream = whoosh_stream
		attack_whoosh_player.volume_db = -6.0
		attack_whoosh_player.max_distance = 25.0
		add_child(attack_whoosh_player)
	
	# Áudio de esquiva / foley de movimento rápido
	dodge_player = AudioStreamPlayer3D.new()
	dodge_player.name = "DodgeAudio"
	dodge_player.bus = &"Efeitos"
	var dodge_stream = load("res://assets/audio/Small_Sound_Kit/Small Sound Kit/Clothes/Army_RUN_01.wav")
	if dodge_stream:
		dodge_player.stream = dodge_stream
		dodge_player.volume_db = -5.0
		dodge_player.max_distance = 20.0
		add_child(dodge_player)

func _physics_process(delta: float) -> void:
	# Aplicar gravidade
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Obter input de movimentação
	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")

	# Se estava sentado e pressionou mover, levanta automaticamente
	if is_sitting and input_dir != Vector2.ZERO:
		toggle_sit(false)

	# Agachar com Ctrl
	var wants_crouch: bool = Input.is_action_pressed("crouch") and not is_sitting
	if wants_crouch != is_crouching:
		is_crouching = wants_crouch
		_update_collision_for_crouch()
		posture_changed.emit("Agachado" if is_crouching else "Em Pé")

	# Direção no espaço 3D relativa à câmera
	var cam_yaw: float = camera_rig.global_rotation.y if camera_rig else 0.0
	var move_direction: Vector3 = (Transform3D.IDENTITY.rotated(Vector3.UP, cam_yaw) * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	if is_downed:
		_process_downed(delta)
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		_update_animation(0.0)
		return

	if flinch_timer > 0.0:
		flinch_timer -= delta

	# Básicos do estilo (clique esq./dir.); menu aberto ou Postura quebrada travam o combate
	_process_attack(delta)
	var tree := get_tree()
	var can_fight: bool = (tree == null or tree.get_nodes_in_group("open_menus").is_empty()) and not is_stunned() and not is_downed
	if can_fight and tree != null:
		var zm := tree.get_first_node_in_group("zone_manager")
		if zm and zm.has_method("can_combat_at") and not zm.can_combat_at(global_position, in_duel):
			can_fight = false
	var secondary: StyleAttack = weapon_style.secondary if weapon_style else null

	# Modo de Bloqueio (armas com secondary.kind == BLOCK)
	is_blocking = can_fight and secondary != null and secondary.kind == StyleAttack.Kind.BLOCK \
		and Input.is_action_pressed("cast") and current_attack == null and not is_dodging \
		and not is_sitting and pools != null and pools.current_vigor > 0.0

	# Modo de Mira (armas com secondary.kind == AIM)
	var wants_aim: bool = can_fight and secondary != null and secondary.kind == StyleAttack.Kind.AIM \
		and Input.is_action_pressed("cast") and not is_dodging and not is_sitting
	_set_aiming(wants_aim)

	if can_fight and weapon_style:
		if is_aiming:
			# Mirando: clique esquerdo dispara o tiro arcano mirado
			if Input.is_action_just_pressed("attack"):
				if weapon_style.aim_attack:
					try_attack(weapon_style.aim_attack)
				else:
					try_attack(weapon_style.primary)
		elif is_blocking:
			# Bloqueando: clique esquerdo desfere contra-ataque / shield bash
			if Input.is_action_just_pressed("attack"):
				if weapon_style.block_counter:
					try_attack(weapon_style.block_counter)
				else:
					try_attack(weapon_style.primary)
		else:
			# Neutro: clique esquerdo = golpe primário
			if Input.is_action_just_pressed("attack"):
				try_attack(weapon_style.primary)
			# Neutro: clique direito = secundário se não for BLOCK nem AIM
			elif secondary and secondary.kind != StyleAttack.Kind.BLOCK and secondary.kind != StyleAttack.Kind.AIM and Input.is_action_just_pressed("cast"):
				try_attack(secondary)

	# Processar Esquiva / Rolamento (tecla C ou Esquiva)
	if is_dodging:
		dodge_timer -= delta
		if dodge_timer <= 0.0:
			is_dodging = false
			posture_changed.emit("Em Pé")
	elif Input.is_action_just_pressed("dodge") and is_on_floor() and not is_sitting and not is_attacking and not is_stunned():
		var dodge_cost: float = stats.get_stat(&"dodge_cost") if stats else 25.0
		if pools and pools.consume_vigor(dodge_cost):
			is_dodging = true
			dodge_timer = DODGE_DURATION
			dodge_dir = move_direction if move_direction != Vector3.ZERO else -Transform3D.IDENTITY.rotated(Vector3.UP, cam_yaw).basis.z
			if dodge_player and is_inside_tree() and dodge_player.is_inside_tree():
				dodge_player.pitch_scale = randf_range(1.05, 1.25)
				dodge_player.play()
			posture_changed.emit("Esquiva")

	# Pulo suave (consome 12 de vigor)
	if Input.is_action_just_pressed("jump") and is_on_floor() and not is_crouching and not is_sitting and not is_dodging and not is_attacking:
		if pools == null or pools.consume_vigor(12.0):
			velocity.y = jump_velocity

	_handle_harvest(delta, input_dir)

	# Definir velocidade alvo
	var target_speed: float = walk_speed
	if is_harvesting or is_stunned():
		target_speed = 0.0
	elif is_dodging:
		target_speed = DODGE_SPEED
		move_direction = dodge_dir
	elif _is_lunging():
		target_speed = current_attack.lunge_speed
		move_direction = _attack_dir
	elif current_attack:
		target_speed = walk_speed * current_attack.move_mult # Mobilidade do golpe/conjuro (GDD-01 §4)
	elif is_aiming:
		target_speed = walk_speed * (weapon_style.secondary.move_mult if weapon_style and weapon_style.secondary else 0.6)
	elif is_blocking:
		target_speed = walk_speed * weapon_style.secondary.move_mult
	elif is_sitting:
		target_speed = 0.0
	elif is_crouching:
		target_speed = crouch_speed
	elif Input.is_action_pressed("slow_walk"):
		target_speed = slow_walk_speed
	elif Input.is_action_pressed("sprint") and input_dir != Vector2.ZERO:
		var sprint_vigor_cost: float = 16.0 * delta
		if pools != null and pools.consume_vigor(sprint_vigor_cost):
			target_speed = sprint_speed
		else:
			target_speed = walk_speed

	# Penalidade de peso do equipamento na velocidade (Carga - GDD-01 §4 e B07)
	if not is_dodging and not _is_lunging() and stats != null:
		var current_load: float = stats.get_stat(&"load")
		var load_cap: float = maxf(stats.get_stat(&"load_capacity"), 1.0)
		var load_penalty: float = clampf(1.0 - ((current_load / load_cap) * 0.35), 0.5, 1.0)
		target_speed *= load_penalty

	var target_velocity_xz: Vector3 = move_direction * target_speed
	var current_velocity_xz: Vector3 = Vector3(velocity.x, 0, velocity.z)
	var rate: float = acceleration if move_direction != Vector3.ZERO else friction
	if is_dodging or _is_lunging():
		rate = 20.0
	var new_velocity_xz: Vector3 = current_velocity_xz.lerp(target_velocity_xz, rate * delta)

	velocity.x = new_velocity_xz.x
	velocity.z = new_velocity_xz.z

	move_and_slide()

	# Atualiza última posição segura sobre o chão dentro do mapa
	if is_on_floor() and global_position.y > -6.0 and absf(global_position.x) < 88.0 and absf(global_position.z) < 88.0:
		last_safe_position = global_position

	# Resgate automático caso caia no limbo ou atravesse o chão
	if global_position.y < -20.0 or absf(global_position.x) > 130.0 or absf(global_position.z) > 130.0:
		_recover_from_void()

	# Altura da câmera e colisão suaves
	_update_camera_height(delta)

	# Animação e passos
	_update_animation(Vector3(velocity.x, 0, velocity.z).length())
	_handle_footsteps(delta, input_dir)
	_handle_rotation(delta, move_direction)

## Atalhos de consumível: [1] cura, [2] comida (Vigor), [3] erva de Éter.
## Usa o item mais fraco que cobre o que falta (InventoryComponent.use_best_for).
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var pool: StringName = QUICK_USE_KEYS.get(event.keycode, &"")
	if pool.is_empty() or inventory == null or pools == null or is_downed:
		return
	if get_tree() and not get_tree().get_nodes_in_group("open_menus").is_empty():
		return
	get_viewport().set_input_as_handled()
	if not inventory.use_best_for(pool, pools):
		posture_changed.emit("Nada para repor %s" % QUICK_USE_NAMES[pool])

func _on_item_used(material_id: StringName, effect: String) -> void:
	var data := MaterialData.of(material_id)
	posture_changed.emit("%s %s: %s" % [data.icon, data.display_name, effect])

func _update_collision_for_crouch() -> void:
	var shape = collision_shape.shape as CapsuleShape3D
	if shape:
		shape.height = 1.15 if is_crouching else 1.75
		collision_shape.position.y = 0.58 if is_crouching else 0.875

func _update_camera_height(delta: float) -> void:
	if camera_rig == null:
		return
	var target_cam_y: float = STAND_CAM_Y
	if is_sitting:
		target_cam_y = SIT_CAM_Y
	elif is_crouching:
		target_cam_y = CROUCH_CAM_Y

	camera_rig.position.y = lerp(camera_rig.position.y, target_cam_y, 8.0 * delta)

## Escolhe a animação do UAL1 pelo estado atual (prioridade: ações > postura > locomoção).
func _update_animation(speed: float) -> void:
	if character_visual == null:
		return
	var moving: bool = speed > 0.15

	if is_downed:
		character_visual.play(&"Death01")
	elif is_stunned():
		character_visual.play(&"Idle_Shield_Break")
	elif is_harvesting:
		character_visual.play_timed(&"Farm_Harvest", get_harvest_time())
	elif is_dodging:
		character_visual.play_timed(&"Roll", DODGE_DURATION)
	elif current_attack:
		if not current_attack.anims.is_empty():
			character_visual.play_timed(current_attack.anims[combo_step % current_attack.anims.size()], current_attack.duration)
	elif is_blocking:
		var block_anims: Array[StringName] = weapon_style.secondary.anims
		character_visual.play(block_anims[0] if not block_anims.is_empty() else &"Sword_Block")
	elif is_aiming:
		if moving:
			character_visual.play(&"Walk", speed / walk_speed)
		else:
			var aim_anims: Array[StringName] = weapon_style.secondary.anims if weapon_style and weapon_style.secondary else []
			character_visual.play(aim_anims[0] if not aim_anims.is_empty() else &"Spell_Simple_Idle")
	elif flinch_timer > 0.0:
		pass # deixa a reação ao golpe terminar
	elif is_sitting:
		character_visual.play(&"Sitting_Idle")
	elif not is_on_floor():
		character_visual.play(&"Jump")
	elif is_crouching:
		character_visual.play(&"Crouch_Fwd" if moving else &"Crouch_Idle")
	elif not moving:
		character_visual.play(&"Idle")
	elif speed > walk_speed + 0.5:
		character_visual.play(&"Sprint", speed / sprint_speed)
	elif speed > slow_walk_speed + 0.3:
		character_visual.play(&"Jog_Fwd", speed / walk_speed)
	else:
		character_visual.play(&"Walk", maxf(speed / slow_walk_speed, 0.4))

## Tempo de esfola/coleta por recurso, encurtado pela maestria correspondente.
func get_harvest_time() -> float:
	if harvest_target and harvest_target.has_method("get_gather_time"):
		return harvest_target.get_gather_time(mastery)
	var level: int = mastery.get_level(&"esfola") if mastery else 1
	if level >= 100:
		return 0.5
	elif level >= 50:
		return 1.5
	elif level >= 10:
		return 2.5
	return 3.0

func _find_harvest_target() -> Node3D:
	if get_tree() == null:
		return null
	var best: Node3D = null
	var best_dist: float = HARVEST_RANGE
	for node in get_tree().get_nodes_in_group("harvestable"):
		if node is Node3D and node.has_method("is_harvestable") and node.is_harvestable():
			var d: float = global_position.distance_to((node as Node3D).global_position)
			if d < best_dist:
				best = node
				best_dist = d
	return best

func _cancel_harvest(reason: String) -> void:
	is_harvesting = false
	harvest_target = null
	harvest_timer = 0.0
	posture_changed.emit(reason)

func _handle_harvest(delta: float, input_dir: Vector2) -> void:
	if not is_harvesting:
		var tree := get_tree()
		if Input.is_action_just_pressed("interact") and (tree == null or tree.get_nodes_in_group("open_menus").is_empty()):
			var npc: Node3D = _find_nearest_in_group(&"talkable", TALK_RANGE)
			if npc and _find_harvest_target() == null:
				npc.talk_to(self)
				return
		if Input.is_action_pressed("interact") and is_on_floor() and not (is_attacking or is_casting or is_dodging or is_sitting):
			harvest_target = _find_harvest_target()
			if harvest_target:
				is_harvesting = true
				harvest_timer = 0.0
				harvest_start_health = pools.current_health if pools else 0.0
				var verb: String = harvest_target.get_harvest_verb() if harvest_target.has_method("get_harvest_verb") else "Esfolando"
				posture_changed.emit("%s: %s" % [verb, harvest_target.next_harvest_label()])
		return

	# Interrupções: soltar a tecla, andar, levar dano ou o corpo esvaziar/sumir
	if not Input.is_action_pressed("interact") or input_dir != Vector2.ZERO or is_attacking or is_casting or is_dodging:
		_cancel_harvest("Esfola interrompida")
		return
	if pools and pools.current_health < harvest_start_health:
		_cancel_harvest("Esfola interrompida pelo dano!")
		return
	if not is_instance_valid(harvest_target) or not harvest_target.is_harvestable():
		_cancel_harvest("Em Pé")
		return

	# Vira para o corpo enquanto trabalha
	var to_target: Vector3 = harvest_target.global_position - global_position
	if to_target.length_squared() > 0.01:
		visual_mesh.rotation.y = lerp_angle(visual_mesh.rotation.y, atan2(-to_target.x, -to_target.z), 8.0 * delta)

	harvest_timer += delta
	if harvest_timer >= get_harvest_time():
		var got: String = harvest_target.harvest_next(self)
		harvest_timer = 0.0
		if harvest_target.is_harvestable():
			var verb: String = harvest_target.get_harvest_verb() if harvest_target.has_method("get_harvest_verb") else "Esfolando"
			posture_changed.emit("Coletado: %s • %s: %s" % [got, verb, harvest_target.next_harvest_label()])
			if character_visual:
				character_visual.play_timed(&"Farm_Harvest", get_harvest_time(), true)
		else:
			is_harvesting = false
			harvest_target = null
			posture_changed.emit("Coletado: %s" % got)

func _handle_footsteps(delta: float, input_dir: Vector2) -> void:
	if is_on_floor() and input_dir != Vector2.ZERO and not is_sitting:
		var speed_mult: float = 1.0
		if Input.is_action_pressed("sprint"):
			speed_mult = 1.6
		elif is_crouching or Input.is_action_pressed("slow_walk"):
			speed_mult = 0.55

		footstep_timer -= delta * speed_mult
		if footstep_timer <= 0.0:
			footstep_timer = 0.44
			if footstep_player:
				if not footstep_sounds.is_empty():
					footstep_player.stream = footstep_sounds.pick_random()
				footstep_player.pitch_scale = randf_range(0.95, 1.05)
				footstep_player.volume_db = -12.0 if is_crouching else -7.0
				footstep_player.play()
	else:
		footstep_timer = 0.15

func _handle_rotation(delta: float, move_dir: Vector3) -> void:
	if is_first_person or is_aiming or is_blocking:
		if camera_rig:
			visual_mesh.rotation.y = lerp_angle(visual_mesh.rotation.y, camera_rig.global_rotation.y, rotation_speed * delta)
	elif current_attack:
		pass # o golpe sai para onde a câmera mirava quando começou
	else:
		if move_dir.length_squared() > 0.001 and not is_sitting:
			var target_angle: float = atan2(-move_dir.x, -move_dir.z)
			visual_mesh.rotation.y = lerp_angle(visual_mesh.rotation.y, target_angle, rotation_speed * delta)

func _set_aiming(aiming: bool) -> void:
	if is_aiming != aiming:
		is_aiming = aiming
		if camera_rig and camera_rig.has_method("set_aiming"):
			camera_rig.set_aiming(is_aiming)
		aim_changed.emit(is_aiming)
		if is_aiming:
			posture_changed.emit("Mirando")
		elif current_attack == null and not is_blocking:
			posture_changed.emit("Em Pé")

func _on_camera_mode_changed(first_person: bool) -> void:
	is_first_person = first_person
	visual_mesh.visible = !first_person

## Alterna entre sentar e levantar
func toggle_sit(force_state = null) -> void:
	if force_state != null:
		is_sitting = force_state
	else:
		is_sitting = !is_sitting
	posture_changed.emit("Sentado / Meditando" if is_sitting else "Em Pé")

func _find_nearest_in_group(group: StringName, max_dist: float) -> Node3D:
	if get_tree() == null:
		return null
	var best: Node3D = null
	var best_dist: float = max_dist
	for node in get_tree().get_nodes_in_group(group):
		if node is Node3D:
			var d: float = global_position.distance_to((node as Node3D).global_position)
			if d < best_dist:
				best = node
				best_dist = d
	return best

# --- Estilos de batalha (B10) ---

## Troca o estilo: barra de básicos, peso na Carga e peças visíveis.
func equip_style(style: WeaponStyle) -> void:
	if style == null:
		return
	if is_aiming:
		_set_aiming(false)
	weapon_style = style
	_end_attack()
	is_blocking = false
	if stats:
		stats.remove_modifiers_from_source(_style_source)
		stats.add_modifier(ModifierData.new(&"load", ModifierData.Op.FLAT, style.weight, _style_source))
	if character_visual:
		character_visual.set_equipment(style.pieces)
	style_changed.emit(style)
	posture_changed.emit("Estilo: %s" % style.display_name)

## Começa um básico se o estado permitir e o recurso pagar; retorna se começou.
func try_attack(attack: StyleAttack) -> bool:
	if attack == null or attack.kind == StyleAttack.Kind.BLOCK or attack.kind == StyleAttack.Kind.AIM:
		return false
	if current_attack or is_sitting or is_dodging or is_harvesting or is_downed or is_stunned():
		return false
	if pools:
		var paid: bool = pools.consume_ether(attack.cost) if attack.cost_pool == &"ether" else pools.consume_vigor(attack.cost)
		if not paid:
			return false
	var now_ms: int = Time.get_ticks_msec()
	if attack == _last_attack and now_ms - last_attack_ms < COMBO_WINDOW_MS + int(attack.duration * 1000.0):
		combo_step += 1
	else:
		combo_step = 0
	last_attack_ms = now_ms
	_last_attack = attack
	current_attack = attack
	_attack_elapsed = 0.0
	_attack_hit_pending = true
	is_attacking = true
	is_casting = attack.cost_pool == &"ether"
	# Sem lock (GDD-01 §5): o golpe sai para onde a câmera olha
	if camera_rig and not is_first_person:
		visual_mesh.rotation.y = camera_rig.global_rotation.y
	_attack_dir = -visual_mesh.global_basis.z
	_attack_dir.y = 0.0
	_attack_dir = _attack_dir.normalized()
	if attack_whoosh_player and is_inside_tree() and attack_whoosh_player.is_inside_tree():
		attack_whoosh_player.pitch_scale = 0.75 if is_casting else randf_range(0.96, 1.12)
		attack_whoosh_player.play()
	posture_changed.emit(attack.display_name)
	return true

func _process_attack(delta: float) -> void:
	if current_attack == null:
		return
	_attack_elapsed += delta
	if _attack_hit_pending and _attack_elapsed >= current_attack.hit_delay:
		_attack_hit_pending = false
		_release_attack(current_attack)
	if _attack_elapsed >= current_attack.duration:
		_end_attack()
		posture_changed.emit("Em Pé")

func _release_attack(attack: StyleAttack) -> void:
	match attack.kind:
		StyleAttack.Kind.MELEE, StyleAttack.Kind.LUNGE:
			if attack_hitbox:
				attack_hitbox.activate_with_params(attack.active_time, attack.damage, attack.damage_type, attack.poise_damage, attack.break_mult)
		StyleAttack.Kind.PROJECTILE:
			var aim: Vector3 = _attack_dir
			var spawn_pos: Vector3 = global_position + Vector3.UP * 1.3 + _attack_dir * 0.6
			if character_visual and character_visual.weapon and is_instance_valid(character_visual.weapon):
				spawn_pos = character_visual.weapon.global_position + character_visual.weapon.global_basis.y.normalized() * 0.9
			if is_aiming and camera_rig and camera_rig.has_method("get_aim_target"):
				var target_pt: Vector3 = camera_rig.get_aim_target(attack.reach)
				aim = (target_pt - spawn_pos).normalized()
			elif camera_rig and not is_first_person:
				aim = -camera_rig.global_basis.z
			ArcaneBolt.spawn(get_parent(), self, spawn_pos, aim, attack)
		StyleAttack.Kind.AREA:
			EarthBurst.spawn(get_parent(), self, global_position + _attack_dir * (attack.reach * 0.6), attack)

func _end_attack() -> void:
	current_attack = null
	_attack_hit_pending = false
	is_attacking = false
	is_casting = false

func _is_lunging() -> bool:
	return current_attack != null and current_attack.kind == StyleAttack.Kind.LUNGE \
		and _attack_elapsed < current_attack.hit_delay + current_attack.active_time

func is_stunned() -> bool:
	return pools != null and pools.is_poise_broken

## Chamado pelo CombatResolver antes da mitigação: i-frames da esquiva e bloqueio frontal.
func filter_incoming_hit(hit: HitEvent) -> void:
	if is_downed or (is_dodging and dodge_timer > DODGE_DURATION - DODGE_IFRAMES):
		hit.raw_damage = 0.0
		hit.poise_damage = 0.0
		return
	if not is_blocking or not (hit.attacker is Node3D):
		return
	var to_attacker: Vector3 = (hit.attacker as Node3D).global_position - global_position
	to_attacker.y = 0.0
	var facing: Vector3 = -visual_mesh.global_basis.z
	facing.y = 0.0
	if to_attacker.length_squared() < 0.0001 or facing.normalized().dot(to_attacker.normalized()) < BLOCK_ARC_DOT:
		return
	var held: float = hit.raw_damage * (1.0 - BLOCK_DAMAGE_MULT)
	if pools.consume_vigor(held * BLOCK_VIGOR_PER_DAMAGE):
		hit.raw_damage *= BLOCK_DAMAGE_MULT
		hit.poise_damage *= BLOCK_POISE_MULT
		posture_changed.emit("Bloqueou!")
	else:
		# Guarda quebrada: sem Vigor o escudo cede e a Postura leva o golpe inteiro
		pools.consume_vigor(pools.current_vigor)
		is_blocking = false
		hit.poise_damage *= 1.5
		posture_changed.emit("Guarda quebrada!")

## Reação visual ao golpe recebido (chamado pela Hurtbox).
func on_hit_feedback(_hit: HitEvent, result: Dictionary) -> void:
	if is_downed or result.get(&"effective_damage", 0.0) <= 0.0:
		return
	if result.get(&"poise_broken", false):
		_end_attack()
		is_blocking = false
		if is_aiming:
			_set_aiming(false)
		if is_harvesting:
			_cancel_harvest("Postura quebrada!")
	elif current_attack == null and not is_blocking and not is_dodging and character_visual:
		flinch_timer = FLINCH_TIME
		character_visual.play_timed(&"Hit_Chest", FLINCH_TIME, true)

func _on_health_depleted() -> void:
	is_downed = true
	downed_timer = DOWNED_DURATION
	_end_attack()
	is_blocking = false
	if is_aiming:
		_set_aiming(false)
	if is_harvesting:
		_cancel_harvest("Caído")
	posture_changed.emit("Caído! Voltando ao acampamento em %.0f s" % DOWNED_DURATION)

func _process_downed(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	downed_timer -= delta
	if downed_timer <= 0.0:
		is_downed = false
		global_position = spawn_point
		velocity = Vector3.ZERO
		if pools:
			pools.reset_all()
		posture_changed.emit("De volta ao acampamento")

## Resgata o jogador se cair no vazio (limbo) ou atravessar a malha
func _recover_from_void() -> void:
	velocity = Vector3.ZERO
	var target_pos: Vector3 = last_safe_position if (last_safe_position != Vector3.ZERO and last_safe_position.y > -5.0) else spawn_point
	if target_pos.y < -5.0:
		target_pos = Vector3(0.0, 1.2, 0.0)
	target_pos.y += 1.0
	global_position = target_pos
	is_dodging = false
	is_attacking = false
	current_attack = null
	_attack_hit_pending = false
	is_blocking = false
	if is_aiming:
		_set_aiming(false)
	if is_harvesting:
		_cancel_harvest("Resgatado do abismo")
	posture_changed.emit("Em Pé")
	if character_visual:
		character_visual.play(&"Idle")
