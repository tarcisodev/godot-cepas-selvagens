extends RefCounted
class_name RiverSystem

## Sistema Hidrográfico e Ecológico: Rio, Cachoeira e Lagoa
# Define a rota da água, a cachoeira no penhasco e a lagoa profunda.

const RIVER_WIDTH: float = 12.0
const WATERFALL_Z: float = -28.0
const UPPER_WATER_Y: float = 7.2
const LOWER_WATER_Y: float = -0.65
const LOWER_BED_Y: float = -2.4
const UPPER_BED_Y: float = 5.6

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
	else:
		return RIVER_WIDTH * 0.5 * 0.92

static func get_water_height(z: float) -> float:
	if z < (WATERFALL_Z - 1.5):
		return UPPER_WATER_Y
	elif z > (WATERFALL_Z + 1.5):
		return LOWER_WATER_Y
	else:
		# Transição na crista da queda
		var t: float = clamp((z - (WATERFALL_Z - 1.5)) / 3.0, 0.0, 1.0)
		return lerp(UPPER_WATER_Y, LOWER_WATER_Y, t)

static func get_distance_to_river(x: float, z: float) -> float:
	var river_center: float = get_river_center_x(z)
	return abs(x - river_center)

static func is_in_water(pos: Vector3) -> bool:
	var dist: float = get_distance_to_river(pos.x, pos.z)
	var max_w: float = get_water_half_width(pos.z)
	var surface_y: float = get_water_height(pos.z)
	return dist < max_w and pos.y <= (surface_y + 0.15)
