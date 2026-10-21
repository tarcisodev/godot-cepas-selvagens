extends CanvasLayer
class_name WorldHUD

@export var day_night: Node3D
@export var player: CharacterBody3D

@onready var time_label: Label = $MarginContainer/VBoxContainer/TimeLabel
@onready var mode_label: Label = $MarginContainer/VBoxContainer/ModeLabel
@onready var tips_container: VBoxContainer = $BottomMargin/TipsContainer

var tips_visible: bool = true
var current_posture: String = "Em Pé"
var current_view: String = "🌄 3ª Pessoa"

func _ready() -> void:
	if player and player.camera_rig:
		player.camera_rig.camera_mode_changed.connect(_on_camera_mode_changed)
	if player and player.has_signal("posture_changed"):
		player.posture_changed.connect(_on_posture_changed)

	# Dicas visíveis seguem a opção "Mostrar Dicas de Controle"
	_set_tips_visible(GameSettings.get_value("video", "show_tips"))
	GameSettings.setting_changed.connect(_on_setting_changed)

func _process(_delta: float) -> void:
	if day_night and time_label:
		var time_str: String = day_night.get_formatted_time()
		var period_desc: String = _get_period_description(day_night.current_time_hours)
		time_label.text = "⏰ %s · %s" % [time_str, period_desc]

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_H:
		GameSettings.set_value("video", "show_tips", not tips_visible)
		GameSettings.save()

func _on_setting_changed(section: String, key: String, value: Variant) -> void:
	if section == "video" and key == "show_tips":
		_set_tips_visible(value)

func _set_tips_visible(show: bool) -> void:
	tips_visible = show
	tips_container.visible = show

func _on_camera_mode_changed(is_first_person: bool) -> void:
	current_view = "👁 1ª Pessoa" if is_first_person else "🌄 3ª Pessoa"
	_update_hud_status()

func _on_posture_changed(posture: String) -> void:
	current_posture = posture
	_update_hud_status()

func _update_hud_status() -> void:
	if mode_label:
		mode_label.text = "%s  |  %s" % [current_view, current_posture]

func _get_period_description(hour: float) -> String:
	if hour >= 5.0 and hour < 7.0:
		return "Alvorada Dourada"
	elif hour >= 7.0 and hour < 12.0:
		return "Manhã Clara"
	elif hour >= 12.0 and hour < 16.0:
		return "Sol a Pino"
	elif hour >= 16.0 and hour < 18.5:
		return "Entardecer Suave"
	elif hour >= 18.5 and hour < 21.0:
		return "Crepúsculo"
	else:
		return "Noite Estrelada"
