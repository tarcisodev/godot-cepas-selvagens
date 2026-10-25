extends SceneTree

## Prints de revisão do B23 (GDD-12): Rinolito Ancião na clareira (parado e empinando no Pisão),
## jogador com o equipamento novo de frente e de costas, grupo de veios de ferro, a bigorna com as
## receitas novas e o HUD da luta (barra do boss e das habilidades).
# Uso: godot --path . -s res://tools/b23_shots.gd -- <pasta_saida>

const WORLD_SCENE := "res://scenes/world.tscn"

var _out: String = "user://"
var _step: int = 0
var _wait: int = 200
var _player: Player
var _boss: BeastFighter
var _cam: Camera3D

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	change_scene_to_file(WORLD_SCENE)

var _use_own_cam: bool = true

func _process(delta: float) -> bool:
	if current_scene == null:
		return false
	# A pose do bicho só anda no animate(); a câmera do jogador tenta voltar a ser a atual
	if _boss and _boss.body:
		_boss.body.animate(delta, 0.0)
	if _cam and _use_own_cam:
		var rig_cam: Camera3D = _player.camera_rig.get_node_or_null("SpringArm3D/Camera3D") if _player and _player.camera_rig else null
		if rig_cam:
			rig_cam.current = false
		_cam.make_current()
	_wait -= 1
	if _wait > 0:
		return false
	match _step:
		0:
			_setup()
			_frame_boss(Vector3(9.0, 4.0, 9.0))
			_next(90)
		1:
			_shot("1_rinolito_anciao")
			_boss.body.pose = &"rear"
			_boss.body.pose_amount = 1.0
			_next(40)
		2:
			_shot("2_anciao_empina_pisao")
			_boss.body.pose = &"head_low"
			_next(40)
		3:
			_shot("3_anciao_chifrada")
			_boss.body.pose = &""
			_dress_player()
			_frame_player(Vector3(0, 1.4, -3.2))
			_next(60)
		4:
			_shot("4_equipamento_frente")
			_frame_player(Vector3(0, 1.6, 3.2))
			_next(30)
		5:
			_shot("5_equipamento_costas")
			_frame_vein()
			_next(60)
		6:
			_shot("6_veio_de_ferro")
			_fight_hud()
			_next(60)
		7:
			_shot("7_hud_luta_boss")
			_open_forge()
			_next(30)
		8:
			_shot("8_bigorna")
			quit(0)
	return false

func _setup() -> void:
	var sun := current_scene.get_node_or_null("Sun")
	if sun:
		sun.current_time_hours = 10.0
		sun.is_paused = true
		sun._update_sun_position_and_lighting()
	_player = get_first_node_in_group("player") as Player
	_boss = get_first_node_in_group("boss") as BeastFighter
	_boss.set_physics_process(false)
	_cam = Camera3D.new()
	current_scene.add_child(_cam)
	_cam.fov = 55.0
	_cam.current = true

func _frame_boss(offset: Vector3) -> void:
	var c := _boss.global_position
	_cam.global_position = c + offset
	_cam.look_at(c + Vector3.UP * 1.6)

func _dress_player() -> void:
	var inv := _player.inventory
	var rng := RandomNumberGenerator.new()
	for spec in [[&"cota_ferro", &"barra_ferro", 3, &"placa_carapaca", 2], [&"elmo_chifre_de_pedra", &"chifre_rinolito", 1, &"barra_ferro", 2],
			[&"botas_saltarelo", &"pele_saltarelo", 2, &"couro_trotador", 1], [&"capa_penas", &"pena_penacho", 4, &"fibra", 2],
			[&"mochila", &"couro_trotador", 2, &"tendao_elastico", 1], [&"espada_ferro", &"barra_ferro", 2, &"couro_trotador", 1],
			[&"escudo", &"barra_ferro", 2, &"placa_carapaca", 1]]:
		inv.add_material(spec[1], spec[2], 3)
		inv.add_material(spec[3], spec[4], 3)
		var item := Forge.forge(inv, spec[0], inv.get_stacks(spec[1])[0], inv.get_stacks(spec[3])[0], {}, 1, false, rng)
		inv.add_item(item)
		inv.equip(item)
	_player.set_physics_process(false)
	var spot := Vector3(40.0, 0.0, -30.0)
	var land := current_scene.get_node_or_null("Landscape")
	spot.y = land.get_height_at(spot.x, spot.z) if land else 0.0
	_player.global_position = spot
	_player.visual_mesh.rotation.y = 0.0

func _frame_player(offset: Vector3) -> void:
	var c := _player.global_position
	_cam.global_position = c + offset
	_cam.look_at(c + Vector3.UP * 1.0)

func _frame_vein() -> void:
	var veins := get_nodes_in_group("ore_veins")
	if veins.is_empty():
		return
	var v := veins[0] as Node3D
	_cam.global_position = v.global_position + Vector3(4.0, 3.0, 4.0)
	_cam.look_at(v.global_position + Vector3.UP * 0.4)

## Jogador na clareira, boss bravo e com a barra no topo; câmera do próprio jogador
func _fight_hud() -> void:
	_player.set_physics_process(true)
	_player.global_position = _boss.global_position + Vector3(0, 0.5, 9.0)
	_boss.look_at(_player.global_position, Vector3.UP)
	_boss._set_state(BeastFighter.State.CHASE)
	_boss.pools.take_damage(380.0)
	_boss.pools.damage_poise(90.0)
	_use_own_cam = false
	_cam.current = false
	if _player.camera_rig:
		var rig_cam: Camera3D = _player.camera_rig.get_node_or_null("SpringArm3D/Camera3D")
		if rig_cam:
			rig_cam.current = true
		_player.camera_rig.global_rotation.y = 0.0
	_player.armor_abilities.cooldowns[&"investida"] = 7.0

func _open_forge() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	current_scene.add_child(layer)
	var screen := ForgeScreen.new()
	layer.add_child(screen)
	screen.open(_player, true)
	_use_own_cam = false
	screen._recipe = &"cota_ferro"
	screen.refresh()

func _next(frames: int) -> void:
	_step += 1
	_wait = frames

func _shot(name: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png(_out.path_join(name + ".png"))
	print("print: ", name)
