extends Node3D

## Laboratório do gerador procedural de personagens (B09): uma grade de humanoides sorteados.
# R sorteia de novo, 1–6 trocam a animação de todos e T liga/desliga o giro.
# Pela linha de comando: `-- --shot=print.png [--anim=Walk] [--seed=10]` salva um print e fecha.

const COLUMNS := 6
const ROWS := 2
const SPACING := 1.25
const ANIMATIONS: Array[StringName] = [&"Idle", &"Walk", &"Jog_Fwd", &"Sword_Regular_A", &"Dance", &"Spell_Simple_Idle"]

var _characters: Array[CharacterVisual] = []
var _labels: Array[Label3D] = []
var _anim := 0
var _first_seed := 1
var _spin := false
var _shot_path := ""
var _frames := 0

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			_shot_path = arg.trim_prefix("--shot=")
		elif arg.begins_with("--anim="):
			_anim = maxi(ANIMATIONS.find(StringName(arg.trim_prefix("--anim="))), 0)
		elif arg.begins_with("--seed="):
			_first_seed = arg.trim_prefix("--seed=").to_int()
	_build_stage()
	var focus := -1
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--focus="):
			focus = arg.trim_prefix("--focus=").to_int()
	for i in COLUMNS * ROWS:
		var row := i / COLUMNS
		var character := CharacterVisual.new()
		character.weapon_scene = null
		character.dna = CharacterDNA.randomized(_first_seed + i)
		character.position = Vector3((i % COLUMNS - (COLUMNS - 1) * 0.5) * SPACING + row * SPACING * 0.5, 0.0, -row * SPACING * 1.4)
		# O CharacterVisual olha para -Z; a câmera está em +Z.
		character.rotation.y = PI
		add_child(character)
		_characters.append(character)
		var label := Label3D.new()
		label.position = character.position + Vector3(0.0, 0.05, 0.45)
		label.rotation.x = -PI * 0.5
		label.font_size = 28
		label.pixel_size = 0.002
		add_child(label)
		_labels.append(label)
	if focus >= 0 and focus < _characters.size():
		# Close de um personagem (para conferir rosto e mãos).
		var target := _characters[focus].position
		var camera := get_viewport().get_camera_3d()
		camera.position = target + Vector3(0.35, 1.45, 1.5)
		camera.look_at(target + Vector3(0.0, 1.15, 0.0))
	_refresh()

func _process(delta: float) -> void:
	if _spin:
		for character in _characters:
			character.rotation.y += delta * 0.8
	if _shot_path != "":
		_frames += 1
		if _frames == 45:
			get_viewport().get_texture().get_image().save_png(_shot_path)
			get_tree().quit()

func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_R:
		_first_seed += _characters.size()
		for i in _characters.size():
			_characters[i].rebuild(CharacterDNA.randomized(_first_seed + i))
		_refresh()
	elif key.keycode == KEY_T:
		_spin = not _spin
		if not _spin:
			for character in _characters:
				character.rotation.y = PI
	elif key.keycode >= KEY_1 and key.keycode < KEY_1 + ANIMATIONS.size():
		_anim = key.keycode - KEY_1
		_refresh()

func _refresh() -> void:
	for i in _characters.size():
		_characters[i].play(ANIMATIONS[_anim])
		_labels[i].text = "#%d" % _characters[i].dna.dna_seed

func _build_stage() -> void:
	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 1.55, 5.2)
	camera.fov = 50.0
	add_child(camera)
	camera.look_at(Vector3(0.0, 0.95, -0.9))

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, 30.0, 0.0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	add_child(sun)

	var sky := ProceduralSkyMaterial.new()
	sky.sky_top_color = Color("#6f93b8")
	sky.ground_bottom_color = Color("#3d3a30")
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = Sky.new()
	environment.sky.sky_material = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)

	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(30.0, 30.0)
	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_color = Color("#5d6b3f")
	plane.material = ground_material
	ground.mesh = plane
	add_child(ground)

	var hud := CanvasLayer.new()
	var help := Label.new()
	help.text = "R: sortear de novo   1-6: animação   T: girar"
	help.position = Vector2(16.0, 12.0)
	hud.add_child(help)
	add_child(hud)
