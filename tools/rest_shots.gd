extends SceneTree

## Prints de revisão do B22: jogador descansando na fogueira do acampamento de noite (com a
## linha de descanso no HUD), e Fogueira, Banco e Cama construídos lado a lado.
# Uso: godot --path . -s res://tools/rest_shots.gd -- <pasta_saida>

const WORLD_SCENE := "res://scenes/world.tscn"

var _out: String = "user://"
var _step: int = 0
var _wait: int = 200
var _player: Player
var _sun: Node
var _cam: Camera3D

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
	match _step:
		0:
			_setup()
			_next(240)
		1:
			_shot("1_descansando_na_fogueira_noite")
			_player.rest.apply_rested()
			_next(30)
		2:
			_shot("2_descansado_no_hud")
			_show_pieces()
			_next(60)
		3:
			_shot("3_fogueira_banco_cama")
			quit(0)
	return false

func _setup() -> void:
	_sun = current_scene.get_node_or_null("Sun")
	if _sun:
		_sun.current_time_hours = 21.5
		_sun.is_paused = true
		_sun._update_sun_position_and_lighting()
	_player = get_first_node_in_group("player") as Player
	var fire := current_scene.find_child("FogueiraDoAcampamento", true, false) as Node3D
	var spot := fire.global_position + Vector3(1.6, 0.4, 1.2)
	_player.global_position = spot
	_player.look_at(Vector3(fire.global_position.x, spot.y, fire.global_position.z))
	_player.pools.current_health = _player.stats.get_stat(&"max_health") * 0.35
	_player.rest._last_health = _player.pools.current_health
	_player.toggle_sit(true)

## Fogueira, Banco e Cama construídos lado a lado, longe da vila, vistos por uma câmera própria
func _show_pieces() -> void:
	if _sun:
		_sun.current_time_hours = 17.0 # luz de fim de tarde para ver os modelos
		_sun._update_sun_position_and_lighting()
	var land := current_scene.get_node_or_null("Landscape")
	var base := Vector3(40.0, 0, -30.0)
	var types := [BuildablePiece.PieceType.FOGUEIRA, BuildablePiece.PieceType.BANCO, BuildablePiece.PieceType.CAMA]
	for i in types.size():
		var p := BuildablePiece.new()
		p.piece_type = types[i]
		var x := base.x + (i - 1) * 2.4
		p.position = Vector3(x, land.get_height_at(x, base.z) if land else 0.0, base.z)
		current_scene.add_child(p)
	base.y = land.get_height_at(base.x, base.z) if land else 0.0
	_cam = Camera3D.new()
	current_scene.add_child(_cam)
	_cam.fov = 50.0
	_cam.global_position = base + Vector3(0, 2.2, 5.0)
	_cam.look_at(base + Vector3(0, 0.3, 0))
	_cam.current = true

func _next(frames: int) -> void:
	_step += 1
	_wait = frames

func _shot(name: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png(_out.path_join(name + ".png"))
	print("print: ", name)
