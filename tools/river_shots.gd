extends SceneTree

## Prints de revisão do B19: nadar até a Raia, mergulhar, montar e pescar.
# Uso: godot --path . -s res://tools/river_shots.gd -- <pasta_saida>

const WORLD_SCENE := "res://scenes/world.tscn"

var _out: String = "user://"
var _frame: int = 0
var _player: Player
var _raia: Mount
var _step: int = 0
var _wait: int = 150

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	change_scene_to_file(WORLD_SCENE)

func _process(_delta: float) -> bool:
	if current_scene == null:
		return false
	_wait -= 1
	if _wait > 0:
		return false
	_player = get_first_node_in_group("player") as Player
	match _step:
		0:
			var sun = current_scene.get_node_or_null("Sun")
			if sun:
				sun.current_time_hours = 10.0
				sun.is_paused = true
			for m in get_nodes_in_group("mounts"):
				if m.kind == Mount.Kind.WATER:
					_raia = m
			var rz := _raia.global_position.z + 3.0
			_player.global_position = Vector3(RiverSystem.get_river_center_x(rz), RiverSystem.get_water_height(rz) - 0.6, rz)
			_face(_raia.global_position, 4.5)
			_next(90)
		1:
			_shot("1_nadando_perto_da_raia")
			Input.action_press("crouch")
			_next(70)
		2:
			Input.action_release("crouch")
			_shot("2_mergulhando")
			_next(120)
		3:
			_player.global_position = Vector3(_raia.global_position.x + 1.2, RiverSystem.get_water_height(_raia.global_position.z) - 1.3, _raia.global_position.z + 0.5)
			_raia.talk_to(_player)
			_next(130)
		4:
			_face(_raia.global_position + Vector3(0, 0, -6), 5.0)
			_next(20)
		5:
			_shot("3_montado_na_raia")
			_raia.dismount()
			var z := 46.0
			var cx := RiverSystem.get_river_center_x(z)
			var bank := cx - RiverSystem.get_water_half_width(z) - 1.2
			var land: Node = current_scene.get_node("Landscape")
			_player.global_position = Vector3(bank, land.get_height_at(bank, z) + 0.2, z)
			_player.inventory.add_material(&"vara_pesca", 1)
			var eco := get_first_node_in_group("ecosystem") as EcosystemSpawner
			var d := CreatureDNA.randomized(CreatureDNA.Species.DOURADO, 5)
			d.alleles["porte"] = ["T", "T"]
			var fish := eco._add_wild(CreatureDNA.Species.DOURADO, Vector3(cx - 1.5, RiverSystem.get_water_height(z) - 0.5, z + 1.0), 3.0, d)
			fish.add_to_group("shot_fish")
			_face(Vector3(cx, _player.global_position.y, z), 3.2, -14.0)
			_next(40)
		6:
			print("cast: ", _player.fishing.cast())
			_next(25)
		7:
			_shot("4_lancando")
			_next(60)
		8:
			_shot("5_boia_na_agua")
			var f := _player.fishing
			f.fish = get_first_node_in_group("shot_fish") as WildCreature
			f.fish.lure = f.bobber_pos
			f._timer = 0.0
			_next(3)
		9:
			_player.fishing._hook()
			Input.action_press("attack")
			_next(40)
		10:
			_shot("6_recolhendo")
			Input.action_release("attack")
			_next(5)
		_:
			quit()
	return false

func _next(frames: int) -> void:
	_step += 1
	_wait = frames

func _face(target: Vector3, dist: float, pitch_deg: float = -10.0) -> void:
	var rig = _player.get_node_or_null("CameraRig")
	var to := target - _player.global_position
	rig.yaw = atan2(-to.x, -to.z)
	rig.pitch = deg_to_rad(pitch_deg)
	rig.rotation.y = rig.yaw
	rig.get_node("SpringArm3D").rotation.x = rig.pitch
	rig.target_distance = dist

func _shot(name: String) -> void:
	var image := root.get_texture().get_image()
	var path := _out.path_join(name + ".png")
	image.save_png(path)
	var cv := _player.character_visual
	var head_y := -99.0
	if cv and cv.skeleton and cv.skeleton.find_bone(&"Head") >= 0:
		head_y = (cv.skeleton.global_transform * cv.skeleton.get_bone_global_pose(cv.skeleton.find_bone(&"Head")).origin).y
	print("  cabeça-superfície=", snappedf(head_y - RiverSystem.get_water_height(_player.global_position.z), 0.01), " pés-superfície=", snappedf(_player.global_position.y - RiverSystem.get_water_height(_player.global_position.z), 0.01), " anim=", cv.current() if cv else "")
	print("print: ", path, " | nadando=", _player.is_swimming, " fôlego=", snappedf(_player.oxygen, 0.1), " montado=", _player.mounted_on != null, " pesca=", _player.fishing.state)
