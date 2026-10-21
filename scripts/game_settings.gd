extends Node

## Configurações do Jogo (Autoload "GameSettings")
# Guarda volumes, controles e vídeo em user://settings.cfg
# e aplica tudo nos buses de áudio, janela e câmera.

const SAVE_PATH: String = "user://settings.cfg"

const DEFAULTS: Dictionary = {
	"audio": {
		"master": 80.0,
		"ambient": 80.0,
		"music": 70.0,
		"effects": 80.0,
	},
	"controls": {
		"mouse_sensitivity": 1.0, # Multiplicador sobre a sensibilidade base da câmera
		"invert_y": false,
	},
	"video": {
		"fullscreen": false,
		"vsync": true,
		"show_tips": true,
	},
}

# Nome do bus de áudio de cada chave de volume
const AUDIO_BUSES: Dictionary = {
	"master": &"Master",
	"ambient": &"Ambiente",
	"music": &"Musica",
	"effects": &"Efeitos",
}

signal setting_changed(section: String, key: String, value: Variant)

var _values: Dictionary = {}

func _ready() -> void:
	_values = DEFAULTS.duplicate(true)
	_load()
	_apply_all()

func get_value(section: String, key: String) -> Variant:
	return _values[section][key]

func set_value(section: String, key: String, value: Variant) -> void:
	_values[section][key] = value
	_apply(section, key)
	setting_changed.emit(section, key, value)

func save() -> void:
	var cfg := ConfigFile.new()
	for section in _values:
		for key in _values[section]:
			cfg.set_value(section, key, _values[section][key])
	cfg.save(SAVE_PATH)

func reset_to_defaults() -> void:
	for section in DEFAULTS:
		for key in DEFAULTS[section]:
			set_value(section, key, DEFAULTS[section][key])

func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	for section in _values:
		for key in _values[section]:
			_values[section][key] = cfg.get_value(section, key, _values[section][key])

func _apply_all() -> void:
	for section in _values:
		for key in _values[section]:
			_apply(section, key)

func _apply(section: String, key: String) -> void:
	var value: Variant = _values[section][key]
	match section:
		"audio":
			var bus_index: int = AudioServer.get_bus_index(AUDIO_BUSES[key])
			if bus_index >= 0:
				var linear: float = clampf(value / 100.0, 0.0, 1.0)
				AudioServer.set_bus_mute(bus_index, linear <= 0.0)
				AudioServer.set_bus_volume_db(bus_index, linear_to_db(maxf(linear, 0.0001)))
		"video":
			if key == "fullscreen":
				var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if value else DisplayServer.WINDOW_MODE_WINDOWED
				DisplayServer.window_set_mode(mode)
			elif key == "vsync":
				var vsync := DisplayServer.VSYNC_ENABLED if value else DisplayServer.VSYNC_DISABLED
				DisplayServer.window_set_vsync_mode(vsync)
