extends DirectionalLight3D
class_name DayNightCycle

## Ciclo de Luz Natural e Atmosfera (Dia e Noite)
# Simula a rotação do sol e modula cores e intensidade da iluminação
# para criar momentos contemplativos (alvorada, meio-dia, crepúsculo e luar).

@export var day_length_seconds: float = 300.0 # 5 minutos para um ciclo completo (360º)
@export var start_time_hour: float = 8.0     # Começar às 08:00 (manhã agradável)
@export var is_paused: bool = false

## Modo otimizado para servidores dedicados: usa Timer ao invés de rodar _process a cada frame
@export var use_timer_update: bool = false
@export var timer_tick_interval: float = 0.5

# Cores e intensidades nos diferentes momentos
@export var dawn_color: Color = Color(1.0, 0.72, 0.45)    # Dourado suave da alvorada
@export var noon_color: Color = Color(1.0, 0.96, 0.90)    # Luz clara do dia
@export var dusk_color: Color = Color(0.95, 0.48, 0.35)   # Alaranjado/rosado do entardecer
@export var night_color: Color = Color(0.25, 0.35, 0.65)  # Luar azulado/prateado

@export var day_energy: float = 1.3
@export var night_energy: float = 0.22

var current_time_hours: float = 8.0 # 0.0 a 24.0
## Dias corridos desde o começo do jogo (vira a cada meia-noite)
var day_count: int = 0
## Ciclo da lua (GDD-10 §2.1): 28 dias de jogo; 0 = nova, 0,5 = cheia
const MOON_CYCLE_DAYS: float = 28.0
const MOON_PHASE_NAMES: Array[String] = ["Lua nova", "Lua crescente", "Quarto crescente", "Crescente gibosa", "Lua cheia", "Minguante gibosa", "Quarto minguante", "Lua minguante"]
const MOON_PHASE_ICONS: Array[String] = ["🌑", "🌒", "🌓", "🌔", "🌕", "🌖", "🌗", "🌘"]

## Céu fechado (0–1), escrito pelo WeatherSystem: nuvens tiram luz e sombra do sol (GDD-10 §2)
var overcast: float = 0.0
## Eclipse (0–1) do Arquipélago do Eclipse (GDD-18 §7.4), escrito pelo SkyIslandField: o planeta
## com anéis passa na frente do sol e a luz cai até ECLIPSE_DIM
var eclipse: float = 0.0
const ECLIPSE_DIM: float = 0.3

## Relógio único do mundo (ADR-0006): todo sistema de natureza lê a duração do dia daqui.
## Nenhuma ação de jogador escreve na hora; só este relógio anda e o load do save restaura.
const DEFAULT_DAY_SECONDS: float = 300.0
static var instance: DayNightCycle

## Segundos reais de um dia de jogo; sem sol no mundo (testes), o padrão de 5 min
static func seconds_per_day() -> float:
	return maxf(1.0, instance.day_length_seconds) if is_instance_valid(instance) else DEFAULT_DAY_SECONDS

func _enter_tree() -> void:
	instance = self

func _exit_tree() -> void:
	if instance == self:
		instance = null

func _ready() -> void:
	current_time_hours = start_time_hour
	_update_sun_position_and_lighting()
	if use_timer_update:
		set_process(false)
		var timer := Timer.new()
		timer.name = "SunUpdateTimer"
		timer.wait_time = timer_tick_interval
		timer.autostart = true
		timer.timeout.connect(func():
			if not is_paused:
				advance_time(timer_tick_interval)
		)
		add_child(timer)

## Avança o relógio do mundo e atualiza iluminação
func advance_time(delta: float) -> void:
	var hours_per_second: float = 24.0 / max(1.0, day_length_seconds)
	var next_hours: float = current_time_hours + hours_per_second * delta
	if next_hours >= 24.0:
		day_count += 1
	current_time_hours = fposmod(next_hours, 24.0)
	if not is_inside_tree() or DisplayServer.get_name() != "headless":
		_update_sun_position_and_lighting()

func _process(delta: float) -> void:
	if not is_paused:
		advance_time(delta)

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
		# Noite / Luar: a fase da lua decide a claridade (cheia ilumina, nova quase escuro)
		var illum := moon_illumination()
		light_color = night_color.lerp(Color(0.62, 0.68, 0.85), illum * 0.5)
		light_energy = night_energy * (0.2 + 0.8 * illum)

	# Nuvens: luz mais fraca e acinzentada, sombras mais suaves
	if eclipse > 0.0:
		light_energy *= 1.0 - eclipse * ECLIPSE_DIM
	if overcast > 0.0:
		light_energy *= 1.0 - overcast * 0.6
		light_color = light_color.lerp(Color(0.72, 0.76, 0.82), overcast * 0.6)
		shadow_opacity = 1.0 - overcast * 0.7

## Fase da lua de 0 a 1 (0 = nova, 0,5 = cheia)
func moon_phase() -> float:
	return fposmod((day_count + current_time_hours / 24.0) / MOON_CYCLE_DAYS, 1.0)

## Fração iluminada do disco (0 na nova, 1 na cheia)
func moon_illumination() -> float:
	return (1.0 - cos(moon_phase() * TAU)) * 0.5

func moon_phase_index() -> int:
	return int(round(moon_phase() * 8.0)) % 8

func moon_phase_name() -> String:
	return MOON_PHASE_ICONS[moon_phase_index()] + " " + MOON_PHASE_NAMES[moon_phase_index()]

## Ângulo do sol no céu (graus): 0 = nascente, 90 = zênite
func sun_angle_deg() -> float:
	return ((current_time_hours - 6.0) / 24.0) * 360.0

func get_formatted_time() -> String:
	var hours: int = int(current_time_hours)
	var minutes: int = int((current_time_hours - hours) * 60.0)
	return "%02d:%02d" % [hours, minutes]
