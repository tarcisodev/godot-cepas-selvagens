extends SceneTree

## Prints de revisão visual da Costelária (B38): ângulos de dia e de noite e, no fim, a Ficha
## do NPC aberta numa mestra. Câmeras no referencial do Colosso (CostelariaLayout).
# Uso: godot --path . -s res://tools/costelaria_shots.gd -- <pasta_saida>

const _Layout = preload("res://scripts/costelaria/costelaria_layout.gd")
const _NpcDialog = preload("res://scripts/ui/npc_dialog.gd")
const _VillageShots = preload("res://tools/village_shots.gd")
const WORLD_SCENE := "res://scenes/world.tscn"

# [nome, câmera local (lx, altura acima do chão, lz), alvo local (lx, altura, lz)]
const VIEWS := [
	["aerea", Vector3(45, 55, 55), Vector3(0, 0, -5)],
	["silhueta", Vector3(70, 12, 5), Vector3(0, 7, 0)],
	["estrada", Vector3(0, 2.0, 80), Vector3(0, 5, 40)],
	["portao", Vector3(0, 1.7, 66), Vector3(0, 4, 45)],
	["espinha", Vector3(1, 1.7, 30), Vector3(0, 7, -10)],
	["coracao", Vector3(7, 1.7, 6), Vector3(0, 3, -6)],
	["costelas_oeste", Vector3(-7, 1.7, -2), Vector3(-15, 2.2, -14)],
	["costelas_leste", Vector3(7, 1.7, -2), Vector3(15, 2.2, -14)],
	["cranio", Vector3(2, 3, -24), Vector3(0, 6, -46)],
	["patio", Vector3(9, 2.2, 24), Vector3(19, 1.2, 34)],
	["ventre", Vector3(1, 1.7, 2), Vector3(0, 2, 12)],
	["forjas", Vector3(-17, 1.8, -4), Vector3(-25, 1.5, -8)],
]
const TIMES := [["dia", 11.0], ["noite", 22.5]]

var _out: String = "user://"
var _wait: int = 300
var _time_i: int = 0
var _view_i: int = 0
var _cam: Camera3D
var _ficha_step: int = 0

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	change_scene_to_file(WORLD_SCENE)

func _process(_delta: float) -> bool:
	if current_scene == null:
		return false
	if _cam and _ficha_step == 0:
		_VillageShots.hide_ui(current_scene)
	_wait -= 1
	if _wait > 0:
		return false
	if _cam == null:
		_cam = Camera3D.new()
		_cam.fov = 70.0
		current_scene.add_child(_cam)
		_cam.make_current()
		_VillageShots.hide_ui(current_scene)
		_set_time(TIMES[0][1])
		_place(VIEWS[0])
		_wait = 120
		return false
	if _ficha_step > 0:
		return _ficha()
	_shot("%s_%s" % [TIMES[_time_i][0], VIEWS[_view_i][0]])
	_view_i += 1
	if _view_i >= VIEWS.size():
		_view_i = 0
		_time_i += 1
		if _time_i >= TIMES.size():
			_ficha_step = 1
			_wait = 1
			return false
		_set_time(TIMES[_time_i][1])
	_place(VIEWS[_view_i])
	_wait = 60
	return false

## Abre a Ficha da Mestra Corisca e da Boticária com a UI visível
func _ficha() -> bool:
	var hub = current_scene.find_child("Costelaria", true, false)
	var ids := [&"corisca", &"nha_salvia"]
	if _ficha_step <= ids.size() * 2:
		var i := (_ficha_step - 1) / 2
		if _ficha_step % 2 == 1:
			_set_time(11.0)
			hub.settle_routines()
			var npc: Node3D = hub.npcs[ids[i]]
			var player := get_first_node_in_group_safe()
			player.global_position = npc.global_position + npc.global_transform.basis.z * -1.5
			npc.talk_to(player)
			_NpcDialog.instance.get_parent().visible = true
			if i == 1:
				_NpcDialog.instance.choose(0)
			_wait = 90
		else:
			_shot("ficha_" + String(ids[i]))
			_NpcDialog.instance.close()
			_wait = 1
		_ficha_step += 1
		return false
	quit(0)
	return false

func get_first_node_in_group_safe() -> Node3D:
	return current_scene.get_tree().get_first_node_in_group("player") as Node3D

func _set_time(hours: float) -> void:
	var sun = current_scene.get_node_or_null("Sun")
	if sun:
		sun.current_time_hours = hours
		sun.is_paused = true
		sun._update_sun_position_and_lighting()

func _ground_world(x: float, z: float) -> float:
	var land = current_scene.get_node_or_null("Landscape")
	return land.get_height_at(x, z) if land and land.has_method("get_height_at") else 0.0

func _place(view: Array) -> void:
	var p: Vector3 = view[1]
	var t: Vector3 = view[2]
	var pw := _Layout.to_world(Vector2(p.x, p.z))
	var tw := _Layout.to_world(Vector2(t.x, t.z))
	_cam.global_position = Vector3(pw.x, _ground_world(pw.x, pw.y) + p.y, pw.y)
	_cam.look_at(Vector3(tw.x, _ground_world(tw.x, tw.y) + t.y, tw.y), Vector3.UP)
	_VillageShots.stand_player_at(current_scene, Vector3(pw.x, _ground_world(pw.x, pw.y), pw.y))

func _shot(name: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png(_out.path_join(name + ".png"))
	print("print: ", name)
