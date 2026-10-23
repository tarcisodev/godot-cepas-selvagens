extends SceneTree

## Prints de revisão da tocha: noite de lua nova, apagada e acesa.
# Uso: godot --path . -s res://tools/torch_shots.gd -- <pasta_saida>

const WORLD_SCENE := "res://scenes/world.tscn"

var _out: String = "user://"
var _step: int = 0
var _wait: int = 200

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
	var player := get_first_node_in_group("player") as Player
	match _step:
		0:
			var sun = current_scene.get_node_or_null("Sun")
			if sun:
				sun.day_count = 0 # lua nova: a noite mais escura
				sun.current_time_hours = 23.0
				sun.is_paused = true
				sun._update_sun_position_and_lighting() # pausado, o sol não se recalcula sozinho
			_next(400)
		1:
			_shot("1_noite_sem_tocha")
			player.inventory.add_material(&"tocha", 1)
			player.torch.toggle()
			_next(40)
		2:
			_shot("2_noite_com_tocha")
			player.inventory.add_material(&"galho", 3)
			player.inventory.add_material(&"fibra", 2)
			var menu = current_scene.find_child("ActionsMenu", true, false)
			if menu:
				menu.open_menu()
			_next(10)
		3:
			_shot("3_menu_fabricar")
			quit(0)
	return false

func _next(frames: int) -> void:
	_step += 1
	_wait = frames

func _shot(name: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png(_out.path_join(name + ".png"))
	print("print: ", name)
