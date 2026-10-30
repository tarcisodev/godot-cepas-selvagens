extends SceneTree

## Prints de revisão do B39 (GDD-18): o céu de ilhas visto do vale, uma Ilhota com a Corrente de
## vento, cada raridade de perto com o seu conteúdo (fase 3) e a coluna de luz da mítica anunciada.
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
			_close_up(_nest_island(), 1.1, 9.0)
		3:
			_shot("3_ilhota_com_ninho")
			_close_up(_first(SkyIslandSchedule.Rarity.INCOMUM), 1.0, 12.0)
		4:
			_shot("4_ilha_de_musgo")
			_close_up(_first(SkyIslandSchedule.Rarity.RARA), 0.9, 14.0)
		5:
			_shot("5_ilha_da_ventania")
			_close_up(_first(SkyIslandSchedule.Rarity.LENDARIA), 0.8, 16.0)
		6:
			_shot("6_ilha_ruina")
			_boss_close_up(_first(SkyIslandSchedule.Rarity.LENDARIA))
		7:
			_shot("6b_sentinela_de_pedra")
			_set_day(_find_day(SkyIslandSchedule.Rarity.MITICA, &"firme"))
			_close_up(_first(SkyIslandSchedule.Rarity.MITICA), 0.7, 18.0)
		8:
			_shot("7_arquipelago_do_eclipse")
			_boss_close_up(_first(SkyIslandSchedule.Rarity.MITICA))
		9:
			_shot("7b_matriarca_do_eclipse")
			var sat: SkyIsland
			for isl in _field.list():
				if isl.is_link() and isl.data.nest:
					sat = isl
			_close_up(sat, 1.4, 6.0)
		10:
			_shot("7c_ilhota_do_eclipse")
			_set_day(_find_day(SkyIslandSchedule.Rarity.MITICA, &"anunciada"))
			_put_player(null)
			_cam.global_position = Vector3(0, 15, 100)
			var myth := _first(SkyIslandSchedule.Rarity.MITICA)
			if myth:
				_cam.look_at(Vector3(myth.global_position.x, 60, myth.global_position.z))
			_next(60)
		11:
			_shot("8_mitica_anunciada")
			quit(0)
	return false

## Jogador em cima da ilha (para o conteúdo nascer) e câmera olhando o topo de lado e do alto
func _close_up(isl: SkyIsland, dist: float, height: float) -> void:
	if isl == null:
		_next(1)
		return
	_put_player(isl)
	var r := isl.shape.radius
	_cam.global_position = isl.global_position + Vector3(r * dist, height, r * dist * 0.5)
	_cam.look_at(isl.global_position + Vector3(0, 0.5, 0))
	_next(90)

## Câmera de perto no chefe da ilha (o conteúdo já nasceu com o jogador em cima)
func _boss_close_up(isl: SkyIsland) -> void:
	var g: BeastFighter = isl.content.guardian if isl and isl.content else null
	if g == null:
		_next(1)
		return
	var size := 9.0 if isl.rarity() == SkyIslandSchedule.Rarity.LENDARIA else 22.0
	_cam.global_position = g.global_position + Vector3(size * 0.7, size * 0.45, -size)
	_cam.look_at(g.global_position + Vector3(0, size * 0.18, 0))
	_next(40)

func _put_player(isl: SkyIsland) -> void:
	if _player == null:
		return
	_player.global_position = isl.global_position + Vector3(isl.shape.radius * 0.5, 1.0, 0) if isl else Vector3(0, 2, 0)
	_player.velocity = Vector3.ZERO
	_field.refresh()

func _nest_island() -> SkyIsland:
	for isl in _field.list():
		if isl.data.get("nest", false):
			return isl
	return _first(SkyIslandSchedule.Rarity.COMUM)

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

## Primeiro dia em que há uma ilha da raridade naquela fase (lendária e mítica: pela agenda)
func _find_day(rarity: int, phase: StringName) -> float:
	if rarity >= SkyIslandSchedule.Rarity.LENDARIA:
		var w := SkyIslandSchedule.next_event(_field.world_seed, rarity, 0.0)
		return (w.x + w.y) * 0.5 if phase == &"anunciada" else (w.y + w.z) * 0.5
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
