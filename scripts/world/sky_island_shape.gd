class_name SkyIslandShape
extends RefCounted

## Forma de uma ilha voadora (GDD-18 §6), em coordenadas locais (centro no meio do topo, y = 0
## é a altura do chão da ilha). Topo em disco recortado com relevo baixo; base em cone invertido.
## A malha, a colisão e o chão que a montaria enxerga saem destas mesmas funções.

## Anéis e fatias da malha polar
const RINGS: int = 10
const SEGMENTS: int = 40
## Saliências da rocha por baixo, em fração da fundura
const JAG: float = 0.2
## Cores do topo e da rocha por raridade
const TOP_COLORS: Array[Color] = [Color(0.36, 0.5, 0.3), Color(0.24, 0.42, 0.26), Color(0.45, 0.44, 0.36), Color(0.46, 0.43, 0.38), Color(0.5, 0.66, 0.8)]
const ROCK_COLORS: Array[Color] = [Color(0.4, 0.34, 0.27), Color(0.3, 0.3, 0.26), Color(0.38, 0.37, 0.36), Color(0.42, 0.4, 0.37), Color(0.3, 0.28, 0.42)]

var radius: float
var depth: float
var relief: float
var rarity: int
var _noise := FastNoiseLite.new()

func _init(island: Dictionary) -> void:
	radius = island.radius
	depth = island.depth
	relief = island.relief
	rarity = island.rarity
	_noise.seed = int(island.shape_seed)
	_noise.frequency = 0.07
	_noise.fractal_octaves = 3

## Raio da borda no ângulo dado (borda recortada, 80–100% do raio)
func edge_radius(angle: float) -> float:
	var n := _noise.get_noise_2d(cos(angle) * 40.0, sin(angle) * 40.0)
	return radius * (0.8 + 0.2 * (n * 0.5 + 0.5))

func contains(lx: float, lz: float) -> bool:
	return Vector2(lx, lz).length() <= edge_radius(atan2(lz, lx))

## Altura do topo (local) ou -INF fora da ilha
func top_at(lx: float, lz: float) -> float:
	var r := Vector2(lx, lz).length()
	var e := edge_radius(atan2(lz, lx))
	if r > e:
		return -INF
	var t := r / e
	var bump := (_noise.get_noise_2d(lx * 1.3, lz * 1.3) * 0.5 + 0.5) * relief * (1.0 - t * t)
	return bump - 0.6 * pow(t, 6.0)

## Altura da base (local) ou INF fora da ilha
func bottom_at(lx: float, lz: float) -> float:
	var r := Vector2(lx, lz).length()
	var e := edge_radius(atan2(lz, lx))
	if r > e:
		return INF
	var t := r / e
	# Rocha irregular por baixo (pontas e saliências), mais funda no meio
	var jag := (_noise.get_noise_2d(lx * 0.9 + 300.0, lz * 0.9) * 0.5 + 0.5) * depth * JAG * (1.0 - t)
	return top_at(lx, lz) - 0.8 - depth * pow(1.0 - pow(t, 1.6), 0.8) - jag

## Quanto a base mais funda pode descer abaixo do chão da ilha
static func max_drop() -> float:
	return 0.8 + SkyIslandSchedule.MAX_DEPTH * (1.0 + JAG)

## Malha do topo e da base, com cor por vértice
func build_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var top := TOP_COLORS[rarity]
	var rock := ROCK_COLORS[rarity]
	var grid: Array = []
	var under: Array = []
	for i in RINGS + 1:
		var row: Array[Vector3] = []
		var urow: Array[Vector3] = []
		for j in SEGMENTS:
			var a := float(j) / SEGMENTS * TAU
			var r := edge_radius(a) * float(i) / RINGS * 0.999
			var x := cos(a) * r
			var z := sin(a) * r
			row.append(Vector3(x, top_at(x, z), z))
			urow.append(Vector3(x, bottom_at(x, z), z))
		grid.append(row)
		under.append(urow)
	for i in RINGS:
		for j in SEGMENTS:
			var j2 := (j + 1) % SEGMENTS
			var c := top.lerp(rock, 0.5 if i == RINGS - 1 else 0.0)
			_quad(st, grid[i][j], grid[i][j2], grid[i + 1][j2], grid[i + 1][j], c)
			_quad(st, under[i][j2], under[i][j], under[i + 1][j], under[i + 1][j2], rock.darkened(0.15 * float(RINGS - i) / RINGS))
	# Faixa de rocha na borda, entre o topo e a base
	for j in SEGMENTS:
		var j2 := (j + 1) % SEGMENTS
		_quad(st, grid[RINGS][j], grid[RINGS][j2], under[RINGS][j2], under[RINGS][j], rock)
	st.generate_normals()
	return st.commit()

func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color) -> void:
	st.set_color(color)
	for v in [a, c, b, a, d, c]:
		st.add_vertex(v)
