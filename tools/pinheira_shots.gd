extends SceneTree

## Prints de revisão da Pinheira-Lume (B20): fileira de genomas diferentes de noite e de dia,
## e close das pinhas Fibonacci e mandala.
# Uso: godot --path . -s res://tools/pinheira_shots.gd -- <pasta_saida>

const WORLD_SCENE := "res://scenes/world.tscn"
const GENOMES: Array[String] = [
	"gen_TT-TT-BB-FF-58-8-34-5", "gen_Tt-CC-BB-ff-02-6-21-6", "gen_TT-HH-Bb-FF-33-9-55-5",
	"gen_T*-*T-BB-ff-78-11-34-4", "gen_Tt-TC-bb-FF-12-7-21-6",
]

var _out: String = "user://"
var _step: int = 0
var _wait: int = 200
var _cam: Camera3D
var _sun: Node
var _row_center: Vector3
var _pinha_spot: Vector3

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
			_set_hour(22.5)
			_next(300)
		1:
			_shot("1_fileira_noite")
			_set_hour(14.0)
			_next(120)
		2:
			_shot("2_fileira_dia")
			_cam.global_position = _pinha_spot + Vector3(0.0, 0.7, 1.0)
			_cam.look_at(_pinha_spot + Vector3(0, 0.15, 0))
			_next(30)
		3:
			_shot("3_pinhas_dia")
			_set_hour(22.5)
			_next(120)
		4:
			_shot("4_pinhas_noite")
			quit(0)
	return false

func _setup() -> void:
	_sun = current_scene.get_node_or_null("Sun")
	var land := current_scene.get_node_or_null("Landscape")
	var player := get_first_node_in_group("player") as Node3D
	var eco := get_first_node_in_group("ecology") as Ecology
	_row_center = Vector3(player.global_position.x + 30.0, 0, player.global_position.z - 45.0)
	for i in GENOMES.size():
		var p := PlantBody.new()
		p.dna = PlantDNA.from_genome_code(GENOMES[i])
		p.stage = PlantBody.Stage.FRUTO
		var x := _row_center.x + (i - 2) * 10.0
		var z := _row_center.z
		p.position = Vector3(x, land.get_height_at(x, z) if land else 0.0, z)
		eco.add_child(p)
		print(GENOMES[i], " → ", p.dna.describe())
	_row_center.y = land.get_height_at(_row_center.x, _row_center.z) if land else 0.0
	_cam = Camera3D.new()
	current_scene.add_child(_cam)
	_cam.fov = 60.0
	_cam.global_position = _row_center + Vector3(0, 7.0, 34.0)
	_cam.look_at(_row_center + Vector3(0, 7.0, 0))
	_cam.current = true
	# Duas pinhas no chão, lado a lado: Fibonacci e mandala
	_pinha_spot = _row_center + Vector3(0, 0, 14.0)
	_pinha_spot.y = land.get_height_at(_pinha_spot.x, _pinha_spot.z) if land else 0.0
	eco.spawn_pinha(PlantDNA.from_genome_code(GENOMES[0]), _pinha_spot + Vector3(-0.35, 0, 0))
	eco.spawn_pinha(PlantDNA.from_genome_code(GENOMES[1]), _pinha_spot + Vector3(0.35, 0, 0))
	for f in get_nodes_in_group("pinhas"):
		f.set_process(false) # não brotar durante os prints

func _set_hour(h: float) -> void:
	if _sun:
		_sun.day_count = 0 # lua nova: a noite mais escura
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
