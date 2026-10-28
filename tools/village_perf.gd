extends SceneTree

## Mede FPS na Vila da Esperança nos mesmos ângulos dos prints (village_shots.gd), sem vsync.
# Uso: godot --path . -s res://tools/village_perf.gd -- <arquivo_saida.csv>

const Shots = preload("res://tools/village_shots.gd")
const WORLD_SCENE := "res://scenes/world.tscn"
const VIEWS := ["aerea", "entrada_sul", "praca_norte", "praca_leste"]
const TIMES := [["dia", 11.0], ["noite", 22.5]]
const WARMUP_FRAMES := 120
const SAMPLE_FRAMES := 300

var _out: String = "user://village_perf.csv"
var _wait: int = 300
var _cam: Camera3D
var _cases: Array = []
var _case_i: int = 0
var _sampling: bool = false
var _frames: int = 0
var _elapsed: float = 0.0
var _worst: float = 0.0
var _lines: PackedStringArray = ["horario,angulo,fps_medio,frame_pior_ms,draw_calls,primitivas"]

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	for t in TIMES:
		for v in VIEWS:
			_cases.append([t, v])
	change_scene_to_file(WORLD_SCENE)

func _process(delta: float) -> bool:
	if current_scene == null:
		return false
	if _cam == null:
		_wait -= 1
		if _wait > 0:
			return false
		_cam = Camera3D.new()
		_cam.fov = 70.0
		current_scene.add_child(_cam)
		_cam.make_current()
		Shots.hide_ui(current_scene)
		_start_case()
		return false
	if not _sampling:
		_wait -= 1
		if _wait <= 0:
			_sampling = true
			_frames = 0
			_elapsed = 0.0
			_worst = 0.0
		return false
	_frames += 1
	_elapsed += delta
	_worst = maxf(_worst, delta)
	if _frames < SAMPLE_FRAMES:
		return false
	var c: Array = _cases[_case_i]
	var fps := _frames / _elapsed
	var draws := int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
	var prims := int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
	var line := "%s,%s,%.1f,%.1f,%d,%d" % [c[0][0], c[1], fps, _worst * 1000.0, draws, prims]
	_lines.append(line)
	print("fps: ", line)
	_case_i += 1
	if _case_i >= _cases.size():
		var f := FileAccess.open(_out, FileAccess.WRITE)
		if f:
			f.store_string("\n".join(_lines) + "\n")
		var size := root.get_visible_rect().size
		print("resolucao: %dx%d" % [size.x, size.y])
		quit(0)
		return false
	_start_case()
	return false

func _start_case() -> void:
	var c: Array = _cases[_case_i]
	var sun = current_scene.get_node_or_null("Sun")
	if sun:
		sun.current_time_hours = c[0][1]
		sun.is_paused = true
		sun._update_sun_position_and_lighting()
	for view in Shots.VIEWS:
		if view[0] == c[1]:
			_place(view)
	Shots.hide_ui(current_scene)
	_sampling = false
	_wait = WARMUP_FRAMES

func _place(view: Array) -> void:
	var hub = current_scene.get_node_or_null("CityHub")
	var p: Vector3 = view[1]
	var t: Vector3 = view[2]
	var px := Shots.CENTER.x + p.x
	var pz := Shots.CENTER.y + p.z
	var tx := Shots.CENTER.x + t.x
	var tz := Shots.CENTER.y + t.z
	_cam.global_position = Vector3(px, hub._get_ground_y(px, pz) + p.y, pz)
	_cam.look_at(Vector3(tx, hub._get_ground_y(tx, tz) + t.y, tz), Vector3.UP)
