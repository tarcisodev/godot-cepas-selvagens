extends SceneTree

## Mede o custo dos bichos que lutam (GDD-12 §9 e §12): FPS e tempo de física/processo no
## acampamento e na Clareira do Ancião, com os BeastFighter ligados e desligados.
# Uso: godot --path . -s res://tools/perf_beasts.gd

const WORLD_SCENE := "res://scenes/world.tscn"
const SAMPLE_FRAMES: int = 240

var _step: int = 0
var _wait: int = 300
var _frames: int = 0
var _acc := {"fps": 0.0, "process": 0.0, "physics": 0.0}
var _player: Player
var _results: Array[String] = []

func _initialize() -> void:
	change_scene_to_file(WORLD_SCENE)

func _process(_delta: float) -> bool:
	if current_scene == null:
		return false
	if _wait > 0:
		_wait -= 1
		return false
	if _frames < SAMPLE_FRAMES:
		_acc.fps += Engine.get_frames_per_second()
		_acc.process += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		_acc.physics += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		_frames += 1
		return false
	_report()
	match _step:
		0:
			_set_beasts(false)
		1:
			_player = get_first_node_in_group("player") as Player
			var boss := get_first_node_in_group("boss") as Node3D
			_set_beasts(true)
			_player.global_position = boss.global_position + Vector3(0, 2.0, 30.0)
		2:
			_set_beasts(false)
		3:
			for r in _results:
				print(r)
			quit(0)
			return false
	_step += 1
	_wait = 120
	return false

func _report() -> void:
	var names := ["acampamento, bichos ligados", "acampamento, bichos desligados", "clareira do boss, ligados", "clareira do boss, desligados"]
	var n: int = get_nodes_in_group("monsters").filter(func(b): return b is BeastFighter).size()
	_results.append("%s: %.0f FPS · processo %.2f ms · física %.2f ms (%d BeastFighter)" % [
		names[_step], _acc.fps / _frames, _acc.process / _frames, _acc.physics / _frames, n])
	_acc = {"fps": 0.0, "process": 0.0, "physics": 0.0}
	_frames = 0

func _set_beasts(on: bool) -> void:
	for b in get_nodes_in_group("monsters"):
		if b is BeastFighter:
			b.set_physics_process(on)
			b.visible = on
