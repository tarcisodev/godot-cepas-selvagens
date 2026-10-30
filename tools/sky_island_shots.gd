extends SceneTree

## Prints de revisão do B39 (GDD-18): o céu de ilhas visto do vale, uma Ilhota com a Corrente de
## vento, a Ilha-Ruína de perto e a coluna de luz da mítica anunciada.
# Uso: godot --path . -s res://tools/sky_island_shots.gd -- <pasta_saida>

const WORLD_SCENE := "res://scenes/world.tscn"

var _out: String = "user://"
var _step: int = 0
var _wait: int = 200
var _player: Player
var _field: SkyIslandField
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
			_set_day(_find_day(SkyIslandSchedule.Rarity.LENDARIA, &"firme"))
			_cam.global_position = Vector3(0, 12, 60)
			_cam.look_at(Vector3(0, 80, -40))
			_next(60)
		1:
			_shot("1_ceu_de_ilhas")
			var isl := _first(SkyIslandSchedule.Rarity.COMUM)
			var c := isl.global_position + isl.current_offset()
			_cam.global_position = c + (c - isl.global_position).normalized() * 45.0 + Vector3(0, -15, 0)
			_cam.look_at(isl.global_position + Vector3(0, -12, 0))
			_next(60)
		2:
			_shot("2_ilhota_e_corrente")
			var isl := _first(SkyIslandSchedule.Rarity.LENDARIA)
			if isl:
				_cam.global_position = isl.global_position + Vector3(isl.shape.radius * 1.4, 18, isl.shape.radius * 0.6)
				_cam.look_at(isl.global_position)
			_next(60)
		3:
			_shot("3_ilha_ruina")
			_set_day(_find_day(SkyIslandSchedule.Rarity.MITICA, &"anunciada"))
			_cam.global_position = Vector3(0, 15, 100)
			var myth := _first(SkyIslandSchedule.Rarity.MITICA)
			if myth:
				_cam.look_at(Vector3(myth.global_position.x, 60, myth.global_position.z))
			_next(60)
		4:
			_shot("4_mitica_anunciada")
			quit(0)
	return false

func _setup() -> void:
	var sun := current_scene.get_node_or_null("Sun")
	if sun:
		sun.current_time_hours = 10.0
		sun.is_paused = true
		sun._update_sun_position_and_lighting()
	_player = get_first_node_in_group("player") as Player
	_field = SkyIslandField.instance
	_cam = Camera3D.new()
	current_scene.add_child(_cam)
	_cam.fov = 60.0
	_cam.far = 800.0
	_cam.current = true

## Primeiro dia (a cada 0,01) em que há uma ilha da raridade naquela fase
func _find_day(rarity: int, phase: StringName) -> float:
	var d := 0.0
	while d < 30.0:
		for isl in SkyIslandSchedule.islands_at(_field.world_seed, d):
			if isl.rarity == rarity and isl.phase == phase:
				return d
		d += 0.01
	return 0.5

func _set_day(d: float) -> void:
	_field.fixed_day = d
	_field.refresh()
	print("dia ", d, " jogador ", _player.global_position if _player else Vector3.ZERO)

func _first(rarity: int) -> SkyIsland:
	for isl in _field.list():
		if isl.rarity() == rarity:
			return isl
	return null

func _next(frames: int) -> void:
	_step += 1
	_wait = frames

func _shot(name: String) -> void:
	if _player:
		print("  jogador ", _player.global_position, " vida ", _player.pools.current_health if _player.pools else -1.0)
	var img := root.get_texture().get_image()
	img.save_png(_out.path_join(name + ".png"))
	print("print: ", name)
