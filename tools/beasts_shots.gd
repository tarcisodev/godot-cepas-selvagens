extends SceneTree

## Prints dos bichos do ermo (GDD-12 §12): bando de lobos no fim de tarde (um em bote, um mordendo)
## e um Tatu-Espinho guardando um grupo de veios de ferro.
# Uso: godot --path . -s res://tools/beasts_shots.gd -- <pasta_saida>

const WORLD_SCENE := "res://scenes/world.tscn"

var _out: String = "user://"
var _step: int = 0
var _wait: int = 220
var _cam: Camera3D
var _player: Player
var _posed: Array[BeastFighter] = []

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	change_scene_to_file(WORLD_SCENE)

func _process(delta: float) -> bool:
	if current_scene == null:
		return false
	for b in _posed:
		b.body.animate(delta, 0.0)
	if _cam:
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
			_frame_wolves()
			_next(60)
		1:
			_shot("1_bando_de_lobos")
			_frame_tatu()
			_next(60)
		2:
			_shot("2_tatu_nos_veios")
			quit(0)
	return false

func _setup() -> void:
	_player = get_first_node_in_group("player") as Player
	_player.set_physics_process(false)
	var hush := Node.new()
	hush.add_to_group("open_menus")
	current_scene.add_child(hush)
	for n in root.find_children("*", "CanvasLayer", true, false):
		(n as CanvasLayer).visible = false
	for b in get_nodes_in_group("monsters"):
		if b is BeastFighter:
			b.set_physics_process(false)
	_cam = Camera3D.new()
	current_scene.add_child(_cam)
	_cam.fov = 50.0

func _sun(hour: float) -> void:
	var sun := current_scene.get_node_or_null("Sun")
	if sun:
		sun.current_time_hours = hour
		sun.is_paused = true
		sun._update_sun_position_and_lighting()

func _frame_wolves() -> void:
	_sun(17.3)
	var pack: Array = get_nodes_in_group("monsters").filter(func(b): return b is BeastFighter and b.pack_id == "toca_0")
	var c: Vector3 = pack[0].home
	# O jogador no meio do bando; cada lobo de um lado, olhando para ele
	var land := current_scene.get_node_or_null("Landscape")
	_player.global_position = Vector3(c.x, land.get_height_at(c.x, c.z), c.z + 5.0)
	var poses := [&"paw", &"head_low", &""]
	for i in pack.size():
		var w: BeastFighter = pack[i]
		var a := deg_to_rad(-60.0 + 60.0 * i)
		var pos := _player.global_position + Vector3(sin(a), 0, -cos(a)) * (3.0 + i)
		pos.y = land.get_height_at(pos.x, pos.z)
		w.global_position = pos
		w.look_at(Vector3(_player.global_position.x, pos.y, _player.global_position.z), Vector3.UP)
		w.body.pose = poses[i % poses.size()]
		w.body.pose_amount = 1.0
		_posed.append(w)
	_cam.global_position = _player.global_position + Vector3(6.5, 2.2, 6.0)
	_cam.look_at(_player.global_position + Vector3(0, 0.8, -2.5))

func _frame_tatu() -> void:
	_sun(10.5)
	var tatu: BeastFighter = null
	for b in get_nodes_in_group("monsters"):
		if b is BeastFighter and b.dna.species == CreatureDNA.Species.TATU:
			tatu = b
			break
	if tatu == null:
		return
	tatu.body.pose = &"head_low"
	tatu.body.pose_amount = 0.6
	_posed.append(tatu)
	var p := tatu.global_position
	_cam.global_position = p + Vector3(3.5, 1.6, 3.5)
	_cam.look_at(p + Vector3(-1.0, 0.4, -1.0))

func _next(frames: int) -> void:
	_step += 1
	_wait = frames

func _shot(name: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png(_out.path_join(name + ".png"))
	print("print: ", name)
