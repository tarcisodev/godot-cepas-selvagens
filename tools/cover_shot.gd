extends SceneTree

## Capa do jogo (fundo da tela de título): o andarilho com equipamento forjado encara o Rinolito
## Ancião empinado na Clareira do Ancião, no fim da tarde. Sem HUD; o lado esquerdo fica livre
## para o título (o menu escurece essa faixa).
# Uso: godot --path . -s res://tools/cover_shot.gd -- <arquivo.png> [hora] [yaw_desvio_graus] [lado_graus]
# A capa atual (assets/ui/menu_background.png, 2560x1080) saiu com: 16.8 8 80

const WORLD_SCENE := "res://scenes/world.tscn"

var _out: String = "user://cover.png"
var _hour: float = 17.6
var _yaw_shift: float = 14.0
## Direção (graus) de onde o herói vem, em volta do boss
var _side_deg: float = 0.0
var _step: int = 0
var _wait: int = 220
var _player: Player
var _boss: BeastFighter
var _cam: Camera3D

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	if args.size() > 1:
		_hour = float(args[1])
	if args.size() > 2:
		_yaw_shift = float(args[2])
	if args.size() > 3:
		_side_deg = float(args[3])
	change_scene_to_file(WORLD_SCENE)

func _process(delta: float) -> bool:
	if current_scene == null:
		return false
	if _boss and _boss.body:
		_boss.body.animate(delta, 0.0)
	if _step > 0:
		# O painel de objetivos se reacende a cada quadro: apaga todas as camadas de interface
		for n in root.find_children("*", "CanvasLayer", true, false):
			(n as CanvasLayer).visible = false
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
			_step = 1
			_wait = 120
		1:
			var img := root.get_texture().get_image()
			img.save_png(_out)
			print("capa: ", _out, " ", img.get_size())
			quit(0)
	return false

func _setup() -> void:
	var sun := current_scene.get_node_or_null("Sun")
	if sun:
		sun.current_time_hours = _hour
		sun.is_paused = true
		sun._update_sun_position_and_lighting()
	# Tela limpa: sem HUD, sem placas e nomes
	for n in root.find_children("*", "CanvasLayer", true, false):
		(n as CanvasLayer).visible = false
	# Painéis de autoload (objetivos) ficam como Control direto na raiz
	for n in root.get_children():
		if n != current_scene and n is CanvasItem:
			(n as CanvasItem).visible = false
	_player = get_first_node_in_group("player") as Player
	_boss = get_first_node_in_group("boss") as BeastFighter
	_boss.set_physics_process(false)
	for l in current_scene.find_children("*", "Label3D", true, false):
		(l as Label3D).visible = false
	_dress_player()
	# O painel de objetivos some sozinho quando há um menu aberto
	var hush := Node.new()
	hush.add_to_group("open_menus")
	current_scene.add_child(hush)

	var land := current_scene.get_node_or_null("Landscape")
	var bpos := _boss.global_position
	if land:
		bpos.y = land.get_height_at(bpos.x, bpos.z) - 0.15
		_boss.global_position = bpos
	# O herói fica a ~8 m do boss, no lado de onde vem a luz da tarde (oeste)
	var dir := Vector3(sin(deg_to_rad(_side_deg)), 0, cos(deg_to_rad(_side_deg)))
	var hero := bpos + dir * 8.0
	hero.y = land.get_height_at(hero.x, hero.z) if land else bpos.y
	_player.global_position = hero
	var to_boss := bpos - hero
	to_boss.y = 0.0
	_player.visual_mesh.rotation.y = atan2(-to_boss.x, -to_boss.z)
	_player.is_blocking = true
	if _player.character_visual:
		_player.character_visual.play(&"Idle_Shield_Loop")
	_boss.look_at(Vector3(hero.x, _boss.global_position.y, hero.z), Vector3.UP)
	_boss.body.pose = &"head_low"
	_boss.body.pose_amount = 1.0

	# Câmera baixa atrás do ombro esquerdo do herói, olhando o boss
	var fwd := to_boss.normalized()
	var right := fwd.cross(Vector3.UP).normalized()
	_cam = Camera3D.new()
	current_scene.add_child(_cam)
	_cam.fov = 40.0
	# De lado (3/4): o boss aparece de perfil, com o chifre e as placas recortados no céu
	_cam.global_position = hero - fwd * 3.2 - right * 7.5 + Vector3.UP * 1.3
	_cam.look_at(hero.lerp(bpos, 0.5) + Vector3.UP * 1.8)
	# Gira um pouco para a esquerda: os dois vão para a direita, o título fica com o céu e o vale
	_cam.rotate_y(deg_to_rad(_yaw_shift))

func _dress_player() -> void:
	var inv := _player.inventory
	var rng := RandomNumberGenerator.new()
	for spec in [[&"cota_ferro", &"barra_ferro", 3, &"placa_carapaca", 2], [&"elmo_chifre_de_pedra", &"chifre_rinolito", 1, &"barra_ferro", 2],
			[&"botas_saltarelo", &"pele_saltarelo", 2, &"couro_trotador", 1], [&"espada_ferro", &"barra_ferro", 2, &"couro_trotador", 1], [&"escudo", &"barra_ferro", 2, &"placa_carapaca", 1]]:
		inv.add_material(spec[1], spec[2], 4)
		inv.add_material(spec[3], spec[4], 4)
		var item := Forge.forge(inv, spec[0], inv.get_stacks(spec[1])[0], inv.get_stacks(spec[3])[0], {}, 1, false, rng)
		inv.add_item(item)
		inv.equip(item)
	_player.set_physics_process(false)
