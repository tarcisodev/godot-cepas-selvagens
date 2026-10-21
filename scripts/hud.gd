extends CanvasLayer
class_name WorldHUD

@export var day_night: Node3D
@export var player: CharacterBody3D

@onready var time_label: Label = $MarginContainer/VBoxContainer/TimeLabel
@onready var mode_label: Label = $MarginContainer/VBoxContainer/ModeLabel
@onready var tips_container: VBoxContainer = $BottomMargin/TipsContainer
@onready var health_bar: ProgressBar = get_node_or_null("MarginContainer/VBoxContainer/StatusBars/HealthBar")
@onready var ether_bar: ProgressBar = get_node_or_null("MarginContainer/VBoxContainer/StatusBars/EtherBar")
@onready var vigor_bar: ProgressBar = get_node_or_null("MarginContainer/VBoxContainer/StatusBars/VigorBar")
@onready var poise_bar: ProgressBar = get_node_or_null("MarginContainer/VBoxContainer/StatusBars/PoiseBar")
@onready var reticle: Control = get_node_or_null("Reticle")

var tips_visible: bool = true
var current_posture: String = "Em Pé"
var current_view: String = "🌄 3ª Pessoa"

func _ready() -> void:
	if player and player.camera_rig:
		player.camera_rig.camera_mode_changed.connect(_on_camera_mode_changed)
	if player and player.has_signal("posture_changed"):
		player.posture_changed.connect(_on_posture_changed)
	if player and player.has_signal("aim_changed"):
		player.aim_changed.connect(_on_aim_changed)

	if player and "pools" in player and player.pools != null:
		player.pools.health_changed.connect(_on_health_changed)
		player.pools.ether_changed.connect(_on_ether_changed)
		player.pools.vigor_changed.connect(_on_vigor_changed)
		player.pools.poise_changed.connect(_on_poise_changed)
		if player.stats != null:
			_on_health_changed(player.pools.current_health, player.stats.get_stat(&"max_health"))
			_on_ether_changed(player.pools.current_ether, player.stats.get_stat(&"max_ether"))
			_on_vigor_changed(player.pools.current_vigor, player.stats.get_stat(&"max_vigor"))
			_on_poise_changed(player.pools.current_poise, player.stats.get_stat(&"max_poise"))

	# Dicas visíveis seguem a opção "Mostrar Dicas de Controle"
	var gs = get_node_or_null("/root/GameSettings")
	if gs:
		_set_tips_visible(gs.get_value("video", "show_tips"))
		gs.setting_changed.connect(_on_setting_changed)
	else:
		_set_tips_visible(true)

func _process(_delta: float) -> void:
	if day_night and time_label:
		var time_str: String = day_night.get_formatted_time()
		var period_desc: String = _get_period_description(day_night.current_time_hours)
		time_label.text = "⏰ %s · %s" % [time_str, period_desc]

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_H:
		var gs = get_node_or_null("/root/GameSettings")
		if gs:
			gs.set_value("video", "show_tips", not tips_visible)
			gs.save()
		else:
			_set_tips_visible(not tips_visible)

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

func _on_aim_changed(is_aiming: bool) -> void:
	if reticle:
		reticle.visible = is_aiming

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

func _on_health_changed(current: float, max_val: float) -> void:
	if health_bar:
		health_bar.max_value = max_val
		health_bar.value = current

func _on_ether_changed(current: float, max_val: float) -> void:
	if ether_bar:
		ether_bar.max_value = max_val
		ether_bar.value = current

func _on_vigor_changed(current: float, max_val: float) -> void:
	if vigor_bar:
		vigor_bar.max_value = max_val
		vigor_bar.value = current

func _on_poise_changed(current: float, max_val: float) -> void:
	if poise_bar:
		poise_bar.max_value = max_val
		poise_bar.value = current
