extends SceneTree

## Prints de revisão visual da Vila da Esperança: vários ângulos em três horários.
# Uso: godot --path . -s res://tools/village_shots.gd -- <pasta_saida>

const WORLD_SCENE := "res://scenes/world.tscn"
const CENTER := Vector2(1.5, 4.5)

# [nome, posição da câmera relativa ao centro (x, altura acima do chão, z), alvo relativo (x, altura, z)]
const VIEWS := [
	["aerea", Vector3(0, 30, 26), Vector3(0, 0, 0)],
	["entrada_sul", Vector3(2, 1.7, 18), Vector3(0, 1.5, 0)],
	["praca_norte", Vector3(0, 1.7, 4), Vector3(0, 1.4, -10)],
	["praca_leste", Vector3(-4, 1.7, 0), Vector3(10, 1.4, 0)],
	["praca_oeste", Vector3(4, 1.7, 1), Vector3(-10, 1.4, 0)],
	["chao_rua", Vector3(1, 1.0, 6), Vector3(0, 0, -2)],
	["portao_norte", Vector3(0, 2.5, -4), Vector3(0, 1.5, -15)],
	["fogueira", Vector3(-0.4, 1.3, 3.4), Vector3(-2.1, 0.5, 1.1)],
]
const TIMES := [["dia", 11.0], ["tarde", 17.6], ["noite", 22.5]]

var _out: String = "user://"
var _wait: int = 300
var _time_i: int = 0
var _view_i: int = 0
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
		hide_ui(current_scene) # o painel de Objetivo nasce depois e volta a aparecer sozinho
	_wait -= 1
	if _wait > 0:
		return false
	if _cam == null:
		_cam = Camera3D.new()
		_cam.fov = 70.0
		current_scene.add_child(_cam)
		_cam.make_current()
		hide_ui(current_scene)
		_set_time(TIMES[0][1])
		_place(VIEWS[0])
		_wait = 120
		return false
	_shot("%s_%s" % [TIMES[_time_i][0], VIEWS[_view_i][0]])
	_view_i += 1
	if _view_i >= VIEWS.size():
		_view_i = 0
		_time_i += 1
		if _time_i >= TIMES.size():
			quit(0)
			return false
		_set_time(TIMES[_time_i][1])
	_place(VIEWS[_view_i])
	_wait = 60
	return false

## Esconde HUD, painel da Trilha e de Objetivo (cada um é um CanvasLayer próprio).
static func hide_ui(scene: Node) -> void:
	var objectives := scene.get_tree().root.get_node_or_null("Objectives")
	if objectives:
		objectives.set_process(false) # o autoload reexibe o painel a cada quadro
	for layer in scene.find_children("*", "CanvasLayer", true, false):
		layer.visible = false

func _set_time(hours: float) -> void:
	var sun = current_scene.get_node_or_null("Sun")
	if sun:
		sun.current_time_hours = hours
		sun.is_paused = true
		sun._update_sun_position_and_lighting()

func _ground(x: float, z: float) -> float:
	var hub = current_scene.get_node_or_null("CityHub")
	if hub and hub.has_method("_get_ground_y"):
		return hub._get_ground_y(x, z)
	return 0.0

func _place(view: Array) -> void:
	var p: Vector3 = view[1]
	var t: Vector3 = view[2]
	var px := CENTER.x + p.x
	var pz := CENTER.y + p.z
	var tx := CENTER.x + t.x
	var tz := CENTER.y + t.z
	_cam.global_position = Vector3(px, _ground(px, pz) + p.y, pz)
	_cam.look_at(Vector3(tx, _ground(tx, tz) + t.y, tz), Vector3.UP)

func _shot(name: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png(_out.path_join(name + ".png"))
	print("print: ", name)
