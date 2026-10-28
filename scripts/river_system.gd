extends RefCounted
class_name RiverSystem

## Sistema Hidrográfico e Ecológico: Rio, Cachoeira, Lagos e Mar Aberto
# Define a rota da água, a grande cachoeira, lagoas procedurais, afluentes
# e o estuário/delta que deságua no mar ao sul.

const RIVER_WIDTH: float = 12.0
const WATERFALL_Z: float = -28.0
const UPPER_WATER_Y: float = 7.2
const LOWER_WATER_Y: float = -0.65
const LOWER_BED_Y: float = -2.4
const UPPER_BED_Y: float = 5.6

## Mar e Oceano no limite Sul
const SEA_Z_START: float = 122.0
const SEA_WATER_Y: float = -1.1
const SEA_BED_Y: float = -4.5

## Centros e dimensões dos lagos procedurais
const VALLEY_LAKE_CENTER := Vector2(62.0, 18.0)
const VALLEY_LAKE_RADII := Vector2(22.0, 16.0)
const WATERFALL_LAKE_CENTER := Vector2(14.0, -20.0)
const WATERFALL_LAKE_RADII := Vector2(14.0, 12.0)

## Cheia máxima acima do nível normal (m)
const FLOOD_MAX: float = 1.4

## Cheia atual (0 a FLOOD_MAX m), escrita pelo WeatherSystem: a chuva enche, a vazão esvazia
static var flood: float = 0.0

# Linha da costa marítima procedural ao sul (com leves ondulações naturais)
static func get_coast_z(x: float) -> float:
	return SEA_Z_START + sin(x * 0.035) * 8.0 + cos(x * 0.08) * 3.0

# Verifica se o ponto está no mar aberto / oceano
static func is_in_sea(x: float, z: float) -> bool:
	return z >= get_coast_z(x)

# Razão de distância normalizada para o Lago do Vale (Lago Cristalino)
static func get_valley_lake_dist_ratio(x: float, z: float) -> float:
	var dx: float = (x - VALLEY_LAKE_CENTER.x) / VALLEY_LAKE_RADII.x
	var dz: float = (z - VALLEY_LAKE_CENTER.y) / VALLEY_LAKE_RADII.y
	var base_dist: float = sqrt(dx * dx + dz * dz)
	var angle: float = atan2(dz, dx)
	var perturb: float = sin(angle * 3.0) * 0.06 + cos(angle * 5.0) * 0.04
	return base_dist + perturb

# Verifica se o ponto está dentro de qualquer lago procedural
static func is_in_lake(x: float, z: float) -> bool:
	if get_valley_lake_dist_ratio(x, z) < 1.0:
		return true
	var dx_wf: float = (x - WATERFALL_LAKE_CENTER.x) / WATERFALL_LAKE_RADII.x
	var dz_wf: float = (z - WATERFALL_LAKE_CENTER.y) / WATERFALL_LAKE_RADII.y
	return (dx_wf * dx_wf + dz_wf * dz_wf) < 1.0

# Verifica se o ponto está dentro do riacho afluente que liga o Lago do Vale ao rio principal
static func is_in_tributary(x: float, z: float) -> bool:
	if x < 20.0 or x > 46.0:
		return false
	var stream_z: float = 18.0 + sin((x - 20.0) * 0.28) * 2.2
	return absf(z - stream_z) < 2.5

# Centro do rio ao longo do eixo Z
static func get_river_center_x(z: float) -> float:
	if z < WATERFALL_Z:
		# Rio superior no platô montanhoso
		return sin(z * 0.05) * 8.0 + 12.0
	elif z < (WATERFALL_Z + 12.0):
		# Lagoa da base da cachoeira (bacia ampla)
		return 12.0 + (z - WATERFALL_Z) * 0.3
	else:
		# Rio inferior serpentante pelo vale
		return sin(z * 0.038) * 16.0 + 15.0

static func get_water_half_width(z: float) -> float:
	if z < WATERFALL_Z:
		return 4.2 # Mais estreito no alto da serra
	elif z < (WATERFALL_Z + 14.0):
		# Bacia da cachoeira / lagoa ampla
		var t: float = (z - WATERFALL_Z) / 14.0
		return lerp(8.0, 5.5, t)
	elif z > 95.0:
		# Alargamento em estuário/delta no deságue marítimo ao sul
		var t_delta: float = clampf((z - 95.0) / 28.0, 0.0, 1.0)
		return lerpf(RIVER_WIDTH * 0.5 * 0.92, 28.0, t_delta * t_delta)
	else:
		return RIVER_WIDTH * 0.5 * 0.92

static func get_water_height(z: float) -> float:
	if z < (WATERFALL_Z - 1.5):
		return UPPER_WATER_Y + flood
	elif z > (WATERFALL_Z + 1.5):
		if z > 105.0:
			# Transição suave do nível do rio para o nível do mar aberto
			var t_sea: float = clampf((z - 105.0) / 20.0, 0.0, 1.0)
			return lerpf(LOWER_WATER_Y, SEA_WATER_Y, t_sea) + flood * (1.0 - t_sea * 0.5)
		return LOWER_WATER_Y + flood
	else:
		# Transição na crista da queda
		var t: float = clamp((z - (WATERFALL_Z - 1.5)) / 3.0, 0.0, 1.0)
		return lerp(UPPER_WATER_Y, LOWER_WATER_Y, t) + flood

static func get_distance_to_river(x: float, z: float) -> float:
	var river_center: float = get_river_center_x(z)
	return abs(x - river_center)

## Água no ponto: rio, cachoeira, várzea alagada, lagos, riachos ou mar aberto
static func is_in_water(pos: Vector3) -> bool:
	# 1. Mar Aberto
	if is_in_sea(pos.x, pos.z):
		return pos.y <= (SEA_WATER_Y + 0.2 + flood * 0.5)

	# 2. Lagos
	if is_in_lake(pos.x, pos.z):
		return pos.y <= (LOWER_WATER_Y + 0.2 + flood)

	# 3. Riacho Afluente
	if is_in_tributary(pos.x, pos.z):
		return pos.y <= (LOWER_WATER_Y + 0.2 + flood)

	# 4. Rio Principal e Várzea
	var dist: float = get_distance_to_river(pos.x, pos.z)
	var max_w: float = get_water_half_width(pos.z) * (2.2 if flood > 0.05 else 1.0)
	var surface_y: float = get_water_height(pos.z)
	return dist < max_w and pos.y <= (surface_y + 0.15)
