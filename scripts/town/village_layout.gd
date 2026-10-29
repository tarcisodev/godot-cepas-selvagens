class_name VillageLayout
extends RefCounted

## Planta da Vila da Esperança (B36): elipse de 38 × 50 m ao sul do spawn, com o rio fazendo a
## muralha do leste. Só dados e funções estáticas — o terreno (relevo e cor), a grama, as zonas e
## o CityHub leem daqui, então mexer na planta é mexer só neste arquivo.
##
## Bairros: Praça da Cepa-Mãe no meio; Forja e Pátio de Armas a oeste; Taverna a sudoeste;
## Feira a sudeste; Cais e Moinho na beira do rio; Colina da Capela, Horta e casas ao sul.

## Centro e raios (x, z) da elipse da paliçada
const CENTER := Vector2(-1.0, 15.0)
const RADII := Vector2(19.0, 25.0)

## Praça: disco calçado, plano em PLAZA_Y; a Cepa-Mãe fica no meio
const PLAZA := Vector2(0.0, 6.0)
const PLAZA_RADIUS: float = 8.0
const PLAZA_Y: float = 0.0

## Colina da Capela: elevação suave no sul (centro, raio, altura)
const HILL := Vector3(-3.0, 30.0, 9.0)
const HILL_HEIGHT: float = 1.4

## Portões em graus no contorno da elipse (0 = norte, 90 = leste): norte (covil e serra),
## oeste (arena) e sul (estrada de Porto Bruma)
const GATES: Array[float] = [0.0, 295.0, 180.0]

## Ruas de terra batida: pontos (x, z) e largura em metros
const ROADS: Array[Dictionary] = [
	{"name": "Avenida Norte", "w": 3.2, "pts": [Vector2(-1.0, -12.0), Vector2(-0.5, -5.0), Vector2(0.0, -1.0)]},
	{"name": "Rua da Forja", "w": 2.8, "pts": [Vector2(-7.5, 5.0), Vector2(-12.5, 4.6), Vector2(-20.0, 4.3)]},
	{"name": "Avenida Sul", "w": 3.2, "pts": [Vector2(0.0, 13.0), Vector2(1.0, 20.0), Vector2(1.0, 26.0), Vector2(0.0, 33.0), Vector2(-1.0, 42.0)]},
	{"name": "Beco da Taverna", "w": 2.4, "pts": [Vector2(-5.0, 11.5), Vector2(-6.0, 17.0), Vector2(-6.0, 23.0)]},
	{"name": "Rua da Feira", "w": 2.4, "pts": [Vector2(5.0, 11.5), Vector2(5.6, 16.0), Vector2(5.0, 24.0), Vector2(1.5, 27.0)]},
	{"name": "Descida do Cais", "w": 2.2, "pts": [Vector2(7.0, 3.4), Vector2(9.0, 2.2)]},
	{"name": "Trilha da Horta", "w": 1.8, "pts": [Vector2(0.8, 27.5), Vector2(-6.0, 28.2), Vector2(-9.5, 28.0)]},
	{"name": "Trilha do Berçário", "w": 1.6, "pts": [Vector2(1.0, 24.5), Vector2(5.5, 28.4)]},
	{"name": "Trilha do Moinho", "w": 1.6, "pts": [Vector2(-0.5, -4.0), Vector2(1.3, -5.0)]},
]

## Lotes ocupados (x, z, raio): sem grama nem tufos por cima
const LOTS: Array[Vector3] = [
	Vector3(-11.5, 0.5, 3.0), Vector3(-10.0, 20.0, 4.3), Vector3(8.0, 20.0, 3.8), Vector3(-4.0, 30.0, 3.6),
	Vector3(6.0, 31.0, 3.3), Vector3(3.5, -5.0, 3.0), Vector3(-16.0, 15.5, 3.0), Vector3(11.0, 27.0, 3.0),
	Vector3(5.0, 36.0, 3.0), Vector3(-7.0, 35.5, 3.0), Vector3(-12.0, 10.0, 3.4), Vector3(-5.5, -3.0, 2.4),
]

## Raio normalizado da elipse: < 1 dentro da paliçada, 1 na paliçada
static func ellipse_k(x: float, z: float, margin: float = 0.0) -> float:
	var dx := (x - CENTER.x) / (RADII.x + margin)
	var dz := (z - CENTER.y) / (RADII.y + margin)
	return sqrt(dx * dx + dz * dz)

## true dentro da paliçada (+ margem)
static func in_village(x: float, z: float, margin: float = 1.0) -> bool:
	return ellipse_k(x, z, margin) < 1.0

## Distância aproximada até a paliçada (negativa dentro), medida no raio que sai do centro
static func edge_distance(x: float, z: float) -> float:
	var d := Vector2(x, z) - CENTER
	var k := ellipse_k(x, z)
	if k < 0.0001:
		return -minf(RADII.x, RADII.y)
	return d.length() * (1.0 - 1.0 / k)

## Ponto da paliçada no ângulo `deg` (0 = norte, 90 = leste)
static func ring_point(deg: float) -> Vector2:
	var a := deg_to_rad(deg)
	return Vector2(CENTER.x + sin(a) * RADII.x, CENTER.y - cos(a) * RADII.y)

## Ângulo (0 = norte) do ponto visto do centro, na mesma medida de `ring_point`
static func ring_angle(x: float, z: float) -> float:
	return fposmod(rad_to_deg(atan2((x - CENTER.x) / RADII.x, -(z - CENTER.y) / RADII.y)), 360.0)

## Distância até o eixo da rua mais próxima e a meia-largura dela (x = distância, y = meia-largura)
static func nearest_road(x: float, z: float) -> Vector2:
	var p := Vector2(x, z)
	var best := Vector2(INF, 0.0)
	for road in ROADS:
		var pts: Array = road["pts"]
		for i in pts.size() - 1:
			var d := _segment_distance(p, pts[i], pts[i + 1])
			if d - road["w"] * 0.5 < best.x - best.y:
				best = Vector2(d, road["w"] * 0.5)
	return best

## Chão de rua, praça ou lote de construção: grama e tufos não nascem aqui
static func is_paved(x: float, z: float) -> bool:
	if ellipse_k(x, z) > 1.25:
		return false
	if Vector2(x, z).distance_to(PLAZA) < PLAZA_RADIUS + 0.6:
		return true
	var r := nearest_road(x, z)
	if r.x < r.y + 0.4:
		return true
	for lot in LOTS:
		if Vector2(x - lot.x, z - lot.y).length() < lot.z:
			return true
	return false

## Relevo da vila: amansa o ruído do vale dentro da paliçada, aplaina a praça e ergue a Colina
## da Capela. Fora (k > 1,35) devolve `h` intacto; entre 1 e 1,35 faz a transição.
static func shape_height(x: float, z: float, h: float) -> float:
	var k := ellipse_k(x, z)
	if k >= 1.35:
		return h
	var floor_h := h * 0.15
	var dh := Vector2(x - HILL.x, z - HILL.y).length()
	if dh < HILL.z:
		var t := 1.0 - dh / HILL.z
		floor_h += HILL_HEIGHT * t * t * (3.0 - 2.0 * t)
	var dp := Vector2(x, z).distance_to(PLAZA)
	if dp < PLAZA_RADIUS + 3.0:
		floor_h = lerpf(PLAZA_Y, floor_h, smoothstep(PLAZA_RADIUS + 0.5, PLAZA_RADIUS + 3.0, dp))
	return lerpf(floor_h, h, smoothstep(1.0, 1.35, k))

## Cor do chão da vila: terra batida nas ruas (borda suave) e grama mais quente e variada
static func ground_tint(x: float, z: float, base: Color) -> Color:
	var k := ellipse_k(x, z)
	if k > 1.3:
		return base
	var inside := 1.0 - smoothstep(1.0, 1.3, k)
	var col := base.lerp(Color(0.36, 0.47, 0.25), 0.35 * inside)
	col = col.lerp(Color(0.30, 0.42, 0.24), (sin(x * 0.61 + z * 0.23) * sin(z * 0.47 - x * 0.19) * 0.5 + 0.5) * 0.4 * inside)
	var dirt := Color(0.43, 0.34, 0.23)
	var r := nearest_road(x, z)
	var t := 1.0 - smoothstep(r.y - 0.4, r.y + 1.1, r.x)
	var dp := Vector2(x, z).distance_to(PLAZA)
	t = maxf(t, 1.0 - smoothstep(PLAZA_RADIUS, PLAZA_RADIUS + 1.6, dp))
	for lot in LOTS:
		var dl := Vector2(x - lot.x, z - lot.y).length()
		t = maxf(t, (1.0 - smoothstep(lot.z - 0.8, lot.z + 0.6, dl)) * 0.75)
	return col.lerp(dirt, t)

static func _segment_distance(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return p.distance_to(a + ab * t)
