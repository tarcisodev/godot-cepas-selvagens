extends Node3D
class_name NatureAudio

## Paisagem Sonora da Natureza (Soundscape 3D)
# Vento ambiente, estrondo relaxante da cachoeira, estalos da fogueira,
# cantos de pássaros, coaxar de sapos e grilos na noite.

const RiverClass = preload("res://scripts/river_system.gd")

@export var day_night: Node3D

var wind_player: AudioStreamPlayer
var crickets_player: AudioStreamPlayer
var waterfall_player: AudioStreamPlayer3D
var campfire_player: AudioStreamPlayer3D
var bird_player: AudioStreamPlayer3D
var frog_player: AudioStreamPlayer3D

var bird_timer: float = 3.5
var frog_timer: float = 2.0

func _ready() -> void:
	_setup_ambient_wind()
	_setup_crickets()
	_setup_waterfall()
	_setup_campfire()
	_setup_bird_and_frog()

func _setup_ambient_wind() -> void:
	wind_player = AudioStreamPlayer.new()
	wind_player.name = "WindPlayer"
	wind_player.bus = &"Ambiente"
	var stream: AudioStreamWAV = load("res://assets/audio/wind_ambient.wav")
	if stream:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wind_player.stream = stream
		wind_player.volume_db = -10.0
		add_child(wind_player)
		wind_player.play()

func _setup_crickets() -> void:
	crickets_player = AudioStreamPlayer.new()
	crickets_player.name = "CricketsPlayer"
	crickets_player.bus = &"Ambiente"
	var stream: AudioStreamWAV = load("res://assets/audio/crickets_night.wav")
	if stream:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		crickets_player.stream = stream
		crickets_player.volume_db = -80.0 # Começa mudo, aumenta ao anoitecer
		add_child(crickets_player)
		crickets_player.play()

func _setup_waterfall() -> void:
	waterfall_player = AudioStreamPlayer3D.new()
	waterfall_player.name = "WaterfallAudio"
	waterfall_player.bus = &"Ambiente"
	var stream: AudioStreamWAV = load("res://assets/audio/waterfall.wav")
	if stream:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		waterfall_player.stream = stream
		waterfall_player.volume_db = 4.0
		waterfall_player.unit_size = 18.0
		waterfall_player.max_distance = 95.0
		waterfall_player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		var wf_z: float = RiverClass.WATERFALL_Z
		var wf_x: float = RiverClass.get_river_center_x(wf_z)
		waterfall_player.position = Vector3(wf_x, 2.5, wf_z)
		add_child(waterfall_player)
		waterfall_player.play()

func _setup_campfire() -> void:
	campfire_player = AudioStreamPlayer3D.new()
	campfire_player.name = "CampfireAudio"
	campfire_player.bus = &"Ambiente"
	var stream: AudioStreamWAV = load("res://assets/audio/campfire.wav")
	if stream:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		campfire_player.stream = stream
		campfire_player.volume_db = 2.0
		campfire_player.unit_size = 6.0
		campfire_player.max_distance = 32.0
		campfire_player.position = Vector3(4.0, 0.5, -4.0)
		add_child(campfire_player)
		campfire_player.play()

func _setup_bird_and_frog() -> void:
	# Pássaros cantando lá de cima
	bird_player = AudioStreamPlayer3D.new()
	bird_player.name = "BirdAudio"
	bird_player.bus = &"Ambiente"
	bird_player.stream = load("res://assets/audio/bird_chirp.wav")
	bird_player.volume_db = -4.0
	bird_player.unit_size = 22.0
	bird_player.max_distance = 80.0
	add_child(bird_player)

	# Sapos coaxando na beira d'água
	frog_player = AudioStreamPlayer3D.new()
	frog_player.name = "FrogAudio"
	frog_player.bus = &"Ambiente"
	frog_player.stream = load("res://assets/audio/frog_croak.wav")
	frog_player.volume_db = -2.0
	frog_player.unit_size = 12.0
	frog_player.max_distance = 45.0
	add_child(frog_player)

func _process(delta: float) -> void:
	# Ajusta volume dos grilos conforme o ciclo dia/noite
	if day_night and crickets_player:
		var hour: float = day_night.current_time_hours
		var is_night: bool = hour < 5.5 or hour > 18.0
		var target_db: float = -14.0 if is_night else -80.0
		crickets_player.volume_db = lerp(crickets_player.volume_db, target_db, 1.5 * delta)

	# Cantos de pássaro aleatórios durante o dia
	bird_timer -= delta
	if bird_timer <= 0.0:
		bird_timer = randf_range(5.0, 13.0)
		var is_day: bool = true
		if day_night:
			is_day = day_night.current_time_hours >= 6.0 and day_night.current_time_hours <= 18.0
		if is_day and bird_player and not bird_player.playing:
			# Posiciona o pio em uma árvore ou no céu
			bird_player.position = Vector3(randf_range(-30, 30), randf_range(12, 22), randf_range(-40, 20))
			bird_player.play()

	# Coaxar de sapo na margem da água
	frog_timer -= delta
	if frog_timer <= 0.0:
		frog_timer = randf_range(4.0, 9.0)
		if frog_player and not frog_player.playing:
			var z: float = randf_range(-25.0, 40.0)
			var rx: float = RiverClass.get_river_center_x(z)
			var hw: float = RiverClass.get_water_half_width(z)
			var side: float = 1.0 if randf() > 0.5 else -1.0
			frog_player.position = Vector3(rx + side * (hw + 0.8), -0.5, z)
			frog_player.play()
