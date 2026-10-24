extends SceneTree

## Prints de revisão do crescimento contínuo da Pinheira-Lume: do pinhão à jovem de perto,
## da jovem à adulta de longe, e a troca broto → jovem no meio da transição.
# Uso: godot --path . -s res://tools/pinheira_growth_shots.gd -- <pasta_saida>

const WORLD_SCENE := "res://scenes/world.tscn"
const GENOME := "gen_TT-TT-BB-FF-58-8-34-5"
## [estágio, progresso] de cada planta da fileira de perto e da de longe
const CLOSE_ROW: Array = [[0, 0.5], [1, 0.0], [1, 0.5], [1, 1.0], [2, 0.0], [2, 0.05]]
const WIDE_ROW: Array = [[2, 0.0], [2, 0.25], [2, 0.5], [2, 0.75], [3, 0.0]]

var _out: String = "user://"
var _step: int = 0
var _wait: int = 200
var _cam: Camera3D
var _sun: Node
var _land: Node
var _eco: Ecology
var _base: Vector3
var _swap: PlantBody

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
			_next(120)
		1:
			_shot("1_pinhao_ao_broto_perto")
			_look(_base + Vector3(45.0, 0, 0), Vector3(0, 6.0, 40.0), 5.0)
			_next(60)
		2:
			_shot("2_jovem_a_adulta_longe")
			_look(_base + Vector3(0, 0, 14.0), Vector3(0, 0.5, 2.2), 0.3)
			_next(60)
		3:
			_shot("3_troca_antes")
			_swap.life_tick(0.05, {"moisture": 0.8, "nutrients": 0.8}, true)
			_next(18)
		4:
			_shot("4_troca_no_meio")
			_next(80)
		5:
			_shot("5_troca_depois")
			quit(0)
	return false

func _setup() -> void:
	_sun = current_scene.get_node_or_null("Sun")
	_land = current_scene.get_node_or_null("Landscape")
	_eco = get_first_node_in_group("ecology") as Ecology
	_eco.set_process(false) # a fileira não cresce sozinha durante os prints
	var player := get_first_node_in_group("player") as Node3D
	_base = Vector3(player.global_position.x + 30.0, 0, player.global_position.z - 45.0)
	for i in CLOSE_ROW.size():
		_plant(_base + Vector3((i - 2.5) * 1.1, 0, 0), CLOSE_ROW[i])
	for i in WIDE_ROW.size():
		_plant(_base + Vector3(45.0 + (i - 2) * 9.0, 0, 0), WIDE_ROW[i])
	_swap = _plant(_base + Vector3(0, 0, 14.0), [1, 0.99])
	_set_hour(14.0)
	for n in current_scene.find_children("*", "CanvasLayer", true, false):
		n.visible = false # sem HUD nos prints
	_cam = Camera3D.new()
	current_scene.add_child(_cam)
	_cam.fov = 50.0
	_cam.current = true
	_look(_base, Vector3(0, 1.8, 5.0), 0.3)

func _plant(at: Vector3, entry: Array) -> PlantBody:
	var p := PlantBody.new()
	p.dna = PlantDNA.from_genome_code(GENOME)
	p.stage = entry[0]
	p.progress = entry[1]
	at.y = _land.get_height_at(at.x, at.z) if _land else 0.0
	p.position = at
	_eco.add_child(p)
	return p

## Câmera em `target + offset`, olhando para `target` subido `look_y`
func _look(target: Vector3, offset: Vector3, look_y: float) -> void:
	target.y = _land.get_height_at(target.x, target.z) if _land else 0.0
	_cam.global_position = target + offset
	_cam.look_at(target + Vector3.UP * look_y)

func _set_hour(h: float) -> void:
	if _sun:
		_sun.current_time_hours = h
		_sun.is_paused = true
		_sun._update_sun_position_and_lighting()

func _next(frames: int) -> void:
	_step += 1
	_wait = frames

func _shot(name: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png(_out.path_join(name + ".png"))
	print("print: ", name)
