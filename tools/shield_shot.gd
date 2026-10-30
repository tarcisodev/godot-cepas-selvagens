extends SceneTree

## Prints de revisão da pose do escudo: jogador de espada e escudo de frente, de lado e de costas.
# Uso: godot --path . -s res://tools/shield_shot.gd -- <pasta_saida>

const WORLD_SCENE := "res://scenes/world.tscn"

var _out: String = "user://"
var _step: int = 0
var _wait: int = 200
var _player: Player
var _cam: Camera3D

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	change_scene_to_file(WORLD_SCENE)

func _process(_delta: float) -> bool:
	if current_scene == null:
		return false
	if _cam:
		_cam.make_current()
	_wait -= 1
	if _wait > 0:
		return false
	match _step:
		0:
			_setup()
			_frame(Vector3(0, 1.3, 2.4))
			_next(60)
		1:
			_shot("escudo_frente")
			_dump_hand("idle")
			_frame(Vector3(2.4, 1.3, 0.3))
			_next(20)
		2:
			_shot("escudo_lado")
			_frame(Vector3(0.3, 1.3, -2.4))
			_next(20)
		3:
			_shot("escudo_costas")
			_player.character_visual.play(&"Sword_Block")
			_frame(Vector3(0, 1.3, 2.4))
			_next(40)
		4:
			_shot("escudo_bloqueio_costas")
			_dump_hand("block")
			_frame(Vector3(-0.6, 1.3, -2.4))
			_next(20)
		5:
			_shot("escudo_bloqueio_frente")
			quit(0)
	return false

func _setup() -> void:
	var sun := current_scene.get_node_or_null("Sun")
	if sun:
		sun.current_time_hours = 10.0
		sun.is_paused = true
		sun._update_sun_position_and_lighting()
	_player = get_first_node_in_group("player") as Player
	_player.set_physics_process(false)
	var spot := Vector3(40.0, 0.0, -30.0)
	var land := current_scene.get_node_or_null("Landscape")
	spot.y = land.get_height_at(spot.x, spot.z) if land else 0.0
	_player.global_position = spot
	_player.visual_mesh.rotation.y = 0.0
	_cam = Camera3D.new()
	current_scene.add_child(_cam)
	_cam.fov = 45.0

func _frame(offset: Vector3) -> void:
	var c := _player.global_position
	_cam.global_position = c + offset
	_cam.look_at(c + Vector3.UP * 1.0)

## Rotação do hand_l em relação à pose de descanso, nos eixos do modelo
func _dump_hand(label: String) -> void:
	var sk: Skeleton3D = _player.character_visual.skeleton
	var b := sk.find_bone("hand_l")
	var rest := sk.get_bone_global_rest(b).basis.orthonormalized()
	var pose := sk.get_bone_global_pose(b).basis.orthonormalized()
	var r := pose * rest.inverse()
	print("hand ", label, " R.x=", r.x, " R.y=", r.y, " R.z=", r.z, " origin=", sk.get_bone_global_pose(b).origin)
	for socket: BoneAttachment3D in _player.character_visual._equipment_sockets:
		if socket.bone_name != &"hand_l":
			continue
		var s := (sk.global_basis.inverse() * socket.global_basis).orthonormalized()
		var node := socket.get_child(0) as Node3D
		print("shield in skel X=", (sk.global_basis.inverse() * node.global_basis).x, " Y=", (sk.global_basis.inverse() * node.global_basis).y, " Z=", (sk.global_basis.inverse() * node.global_basis).z)
		# Peça desejada: em pé, face (-Z local) para frente e um pouco para fora (+X = esquerda do modelo)
		var face := Vector3(0.4, 0.0, 1.0).normalized()
		var want := Basis(Vector3.UP.cross(-face), Vector3.UP, -face)
		var node_n := (sk.global_basis.inverse() * node.global_basis).orthonormalized()
		var piece: Basis = _player.weapon_style.pieces[1].transform.basis
		print("P sugerido ", piece * (node_n.inverse() * want), " s=", s, " rest=", rest)

func _next(frames: int) -> void:
	_step += 1
	_wait = frames

func _shot(shot_name: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png(_out.path_join(shot_name + ".png"))
	print("print: ", shot_name)
