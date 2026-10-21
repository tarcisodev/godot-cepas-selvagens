extends Node3D
class_name NatureAudio

## Paisagem Sonora da Natureza (Soundscape 3D)
# Vento ambiente, estrondo relaxante da cachoeira, estalos da fogueira,
# cantos de pássaros, coaxar de sapos e grilos na noite.

const RiverClass = preload("res://scripts/river_system.gd")

@export var day_night: Node3D

var wind_player: AudioStreamPlayer
var forest_player: AudioStreamPlayer
var waterfall_player: AudioStreamPlayer3D

func _ready() -> void:
	_setup_ambient_wind()
	_setup_forest_ambience()
	_setup_waterfall()

func _setup_ambient_wind() -> void:
	wind_player = AudioStreamPlayer.new()
	wind_player.name = "WindPlayer"
	wind_player.bus = &"Ambiente"
	var stream: AudioStreamWAV = load("res://assets/audio/Small_Sound_Kit/Small Sound Kit/Ambience/Amb_Wind.wav")
	if stream:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wind_player.stream = stream
		wind_player.volume_db = -12.0
		add_child(wind_player)
		wind_player.play()

func _setup_forest_ambience() -> void:
	forest_player = AudioStreamPlayer.new()
	forest_player.name = "ForestPlayer"
	forest_player.bus = &"Ambiente"
	var stream: AudioStreamWAV = load("res://assets/audio/Small_Sound_Kit/Small Sound Kit/Ambience/Amb_Forest_River_Bird_1.wav")
	if stream:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		forest_player.stream = stream
		forest_player.volume_db = -14.0
		add_child(forest_player)
		forest_player.play()

func _setup_waterfall() -> void:
	waterfall_player = AudioStreamPlayer3D.new()
	waterfall_player.name = "WaterfallAudio"
	waterfall_player.bus = &"Ambiente"
	var stream: AudioStreamWAV = load("res://assets/audio/Small_Sound_Kit/Small Sound Kit/Ambience/Amb_Mountain_River_1.wav")
	if stream:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		waterfall_player.stream = stream
		waterfall_player.volume_db = -10.0
		waterfall_player.unit_size = 12.0
		waterfall_player.max_distance = 65.0
		waterfall_player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		var wf_z: float = RiverClass.WATERFALL_Z
		var wf_x: float = RiverClass.get_river_center_x(wf_z)
		waterfall_player.position = Vector3(wf_x, 2.5, wf_z)
		add_child(waterfall_player)
		waterfall_player.play()

func _process(_delta: float) -> void:
	pass
