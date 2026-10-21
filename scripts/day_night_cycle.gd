extends DirectionalLight3D
class_name DayNightCycle

## Ciclo de Luz Natural e Atmosfera (Dia e Noite)
# Simula a rotação do sol e modula cores e intensidade da iluminação
# para criar momentos contemplativos (alvorada, meio-dia, crepúsculo e luar).

@export var day_length_seconds: float = 300.0 # 5 minutos para um ciclo completo (360º)
@export var start_time_hour: float = 8.0     # Começar às 08:00 (manhã agradável)
@export var is_paused: bool = false

# Cores e intensidades nos diferentes momentos
@export var dawn_color: Color = Color(1.0, 0.72, 0.45)    # Dourado suave da alvorada
@export var noon_color: Color = Color(1.0, 0.96, 0.90)    # Luz clara do dia
@export var dusk_color: Color = Color(0.95, 0.48, 0.35)   # Alaranjado/rosado do entardecer
@export var night_color: Color = Color(0.25, 0.35, 0.65)  # Luar azulado/prateado

@export var day_energy: float = 1.3
@export var night_energy: float = 0.22

var current_time_hours: float = 8.0 # 0.0 a 24.0

func _ready() -> void:
	current_time_hours = start_time_hour
	_update_sun_position_and_lighting()

func _process(delta: float) -> void:
	if not is_paused:
		# Avança o tempo
		var hours_per_second: float = 24.0 / max(1.0, day_length_seconds)
		current_time_hours = fposmod(current_time_hours + hours_per_second * delta, 24.0)
		_update_sun_position_and_lighting()

func _update_sun_position_and_lighting() -> void:
	# 06:00 = 0º (nascer), 12:00 = 90º (zênite), 18:00 = 180º (pôr), 00:00 = 270º (meia-noite)
	var sun_angle_deg: float = ((current_time_hours - 6.0) / 24.0) * 360.0
	rotation_degrees.x = -sun_angle_deg
	rotation_degrees.y = -35.0 # Leve inclinação para sombras com volume e tridimensionalidade

	var is_day: bool = current_time_hours >= 5.5 and current_time_hours <= 18.5
	shadow_enabled = true

	# Transições de cores da luz solar
	if current_time_hours >= 5.5 and current_time_hours < 7.5:
		# Alvorada
		var t: float = (current_time_hours - 5.5) / 2.0
		light_color = dawn_color.lerp(noon_color, t)
		light_energy = lerp(0.3, day_energy, t)
	elif current_time_hours >= 7.5 and current_time_hours < 16.5:
		# Pleno dia
		light_color = noon_color
		light_energy = day_energy
	elif current_time_hours >= 16.5 and current_time_hours < 19.0:
		# Entardecer / Crepúsculo
		var t: float = (current_time_hours - 16.5) / 2.5
		light_color = noon_color.lerp(dusk_color, t)
		light_energy = lerp(day_energy, 0.4, t)
	else:
		# Noite / Luar
		light_color = night_color
		light_energy = night_energy

func get_formatted_time() -> String:
	var hours: int = int(current_time_hours)
	var minutes: int = int((current_time_hours - hours) * 60.0)
	return "%02d:%02d" % [hours, minutes]
