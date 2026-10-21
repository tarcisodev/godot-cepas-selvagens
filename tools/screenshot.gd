extends SceneTree

## Captura de tela automática para revisão visual.
# Uso: godot --path . -s res://tools/screenshot.gd -- <saida.png> [frames] [yaw_graus] [distancia] [hora] [limpo]
# [limpo] = 1 esconde toda a interface (CanvasLayers), para capas e fundos.
# Carrega o mundo, espera alguns frames, gira a câmera do player e salva o PNG.

const WORLD_SCENE := "res://scenes/world.tscn"

var _out_path: String = "user://screenshot.png"
var _frames_left: int = 120
var _yaw_deg: float = 0.0
var _distance: float = -1.0
var _hour: float = -1.0
var _clean: bool = false
var _configured: bool = false

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out_path = args[0]
	if args.size() > 1:
		_frames_left = int(args[1])
	if args.size() > 2:
		_yaw_deg = float(args[2])
	if args.size() > 3:
		_distance = float(args[3])
	if args.size() > 4:
		_hour = float(args[4])
	if args.size() > 5:
		_clean = args[5] == "1"
	change_scene_to_file(WORLD_SCENE)

func _process(_delta: float) -> bool:
	if not _configured and current_scene != null:
		_configure_camera()
	_frames_left -= 1
	# Esconde a interface alguns frames antes, para o frame capturado já sair limpo
	if _clean and _frames_left == 3:
		for layer in current_scene.find_children("*", "CanvasLayer", true, false):
			layer.visible = false
	if _frames_left > 0:
		return false
	var image := root.get_texture().get_image()
	image.save_png(_out_path)
	print("Screenshot salvo em: ", _out_path)
	return true

func _configure_camera() -> void:
	var player := current_scene.get_tree().get_first_node_in_group("player")
	if player == null:
		return
	_configured = true
	var sun = current_scene.get_node_or_null("Sun")
	if sun and _hour >= 0.0:
		sun.current_time_hours = _hour
		sun.is_paused = true
		sun._update_sun_position_and_lighting()
	var rig = player.get_node_or_null("CameraRig")
	if rig == null:
		return
	rig.yaw = deg_to_rad(_yaw_deg)
	rig.pitch = deg_to_rad(-12.0)
	rig.rotation.y = rig.yaw
	rig.get_node("SpringArm3D").rotation.x = rig.pitch
	if _distance >= 0.0:
		rig.target_distance = _distance
