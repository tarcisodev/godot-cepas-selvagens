class_name CostelariaLayout
extends RefCounted

## Planta da Costelária (B38, GDD-17 §3): a cidade dentro do esqueleto de um Colosso, a oeste
## do vale. Só dados e funções estáticas — terreno, grama, zonas, o hub e os NPCs leem daqui.
##
## Tudo é medido no **referencial do Colosso** (lx, lz): lz negativo vai para o crânio (oeste,
## longe da Vila) e lz positivo para a cauda, que é o portão virado para a Vila da Esperança
## (leste). `to_world` gira 90°: local +Z vira mundo +X.

## Centro da elipse no mundo (x, z) e raios locais (lx = largura, lz = comprimento)
const CENTER := Vector2(-110.0, -10.0)
const RADII := Vector2(32.0, 58.0)
## Chão aplainado da cidade e quanto do relevo original sobra lá dentro
const PLATEAU_Y: float = 1.0
const RELIEF_KEEP: float = 0.12

## Altura da espinha (m) ao longo do corpo: pares (lz, altura), do crânio até a ponta da cauda
const SPINE: Array[Vector2] = [
	Vector2(-50.0, 5.5), Vector2(-38.0, 8.5), Vector2(-28.0, 11.5), Vector2(-10.0, 13.0),
	Vector2(8.0, 12.5), Vector2(22.0, 10.0), Vector2(32.0, 7.0), Vector2(44.0, 4.0), Vector2(56.0, 1.6),
]
## Costelas: 12 pares entre o pescoço e a bacia; o pé de cada costela fica em lx = ±RIB_FOOT_X
const RIB_COUNT: int = 12
const RIB_FIRST_Z: float = -24.0
const RIB_STEP: float = 3.6
const RIB_FOOT_X: float = 16.5
## Patas (garras-torre): dianteiras e traseiras (lx, lz)
const LEGS: Array[Vector2] = [Vector2(-17.0, -28.0), Vector2(17.0, -28.0), Vector2(-16.0, 28.0), Vector2(16.0, 28.0)]
const SKULL := Vector2(0.0, -44.0)
const PELVIS_Z: float = 24.0

## Praça do Coração (cristal de âmbar = Marco de Viagem)
const HEART := Vector2(0.0, -4.0)
const HEART_RADIUS: float = 8.0

## Bairros (GDD-17 §3): nome, ponto local (lx, lz) e raio — o Guarda aponta para eles
const DISTRICTS: Dictionary = {
	&"cauda": {"name": "Cauda (Portão e Estábulo)", "at": Vector2(0.0, 50.0), "r": 9.0},
	&"espinha": {"name": "Espinha (Avenida)", "at": Vector2(0.0, 22.0), "r": 6.0},
	&"costelas": {"name": "Costelas (Lojas)", "at": Vector2(-13.0, -4.0), "r": 14.0},
	&"coracao": {"name": "Coração (Praça do Âmbar)", "at": HEART, "r": HEART_RADIUS},
	&"pulmao_oeste": {"name": "Pulmão Oeste (Salão das Forjas)", "at": Vector2(-25.0, -8.0), "r": 6.0},
	&"pulmao_leste": {"name": "Pulmão Leste (Estalagem)", "at": Vector2(25.0, -8.0), "r": 6.0},
	&"pelvis": {"name": "Pélvis (Pátio dos Mestres)", "at": Vector2(18.0, 33.0), "r": 8.0},
	&"cranio": {"name": "Crânio (Arquivo e Câmara dos Mestres)", "at": Vector2(0.0, -40.0), "r": 10.0},
	&"ventre": {"name": "Ventre (Feira da Noite)", "at": Vector2(0.0, 10.0), "r": 6.0},
}

## Ruas locais: largura e pontos (lx, lz)
const ROADS: Array[Dictionary] = [
	{"name": "Avenida da Espinha", "w": 5.0, "pts": [Vector2(0.0, 60.0), Vector2(0.0, 20.0), Vector2(0.0, -36.0)]},
	{"name": "Travessa dos Pulmões", "w": 3.6, "pts": [Vector2(-29.0, -8.0), Vector2(0.0, -6.0), Vector2(29.0, -8.0)]},
	{"name": "Rua das Costelas Oeste", "w": 3.0, "pts": [Vector2(-12.5, -26.0), Vector2(-12.5, 18.0)]},
	{"name": "Rua das Costelas Leste", "w": 3.0, "pts": [Vector2(12.5, -26.0), Vector2(12.5, 18.0)]},
	{"name": "Trilha do Estábulo", "w": 2.6, "pts": [Vector2(0.0, 44.0), Vector2(-11.0, 44.0)]},
	{"name": "Trilha do Pátio", "w": 2.6, "pts": [Vector2(0.0, 30.0), Vector2(16.0, 32.0)]},
	{"name": "Subida do Crânio", "w": 3.0, "pts": [Vector2(0.0, -36.0), Vector2(-10.0, -39.0), Vector2(10.0, -39.0)]},
]

## Ponto local (lx, lz) → mundo (x, z)
static func to_world(local: Vector2) -> Vector2:
	return CENTER + Vector2(local.y, -local.x)

## Mundo (x, z) → ponto local (lx, lz)
static func to_local(x: float, z: float) -> Vector2:
	return Vector2(-(z - CENTER.y), x - CENTER.x)

## Direção local (lx, lz) virada para o mundo, como ângulo Y de um Node3D (o nó olha para -Z)
static func yaw_facing(local_dir: Vector2) -> float:
	var w := Vector2(local_dir.y, -local_dir.x)
	return atan2(-w.x, -w.y)

## Giro que leva o referencial do Colosso para o mundo (local +Z → mundo +X)
const YAW: float = PI * 0.5

static func ellipse_k(x: float, z: float, margin: float = 0.0) -> float:
	var l := to_local(x, z)
	var dx := l.x / (RADII.x + margin)
	var dz := l.y / (RADII.y + margin)
	return sqrt(dx * dx + dz * dz)

static func in_city(x: float, z: float, margin: float = 1.0) -> bool:
	return ellipse_k(x, z, margin) < 1.0

## Distância aproximada até a borda (negativa dentro), medida no raio que sai do centro
static func edge_distance(x: float, z: float) -> float:
	var k := ellipse_k(x, z)
	var d := Vector2(x, z).distance_to(CENTER)
	if k < 0.0001:
		return -RADII.x
	return d * (1.0 - 1.0 / k)

## Altura da espinha no ponto lz (interpolada entre os pares de SPINE)
static func spine_height(lz: float) -> float:
	if lz <= SPINE[0].x:
		return SPINE[0].y
	for i in SPINE.size() - 1:
		var a: Vector2 = SPINE[i]
		var b: Vector2 = SPINE[i + 1]
		if lz <= b.x:
			return lerpf(a.y, b.y, smoothstep(a.x, b.x, lz))
	return SPINE[SPINE.size() - 1].y

## lz de cada par de costelas
static func rib_z(i: int) -> float:
	return RIB_FIRST_Z + RIB_STEP * float(i)

## Ponto do bairro no mundo (x, z)
static func district_world(id: StringName) -> Vector2:
	return to_world(DISTRICTS[id]["at"]) if DISTRICTS.has(id) else to_world(HEART)

## Bairro em que o ponto do mundo está; &"" fora de todos
static func district_at(x: float, z: float) -> StringName:
	var l := to_local(x, z)
	var best := &""
	var best_d := INF
	for id in DISTRICTS:
		var d := l.distance_to(DISTRICTS[id]["at"])
		if d < float(DISTRICTS[id]["r"]) and d < best_d:
			best = id
			best_d = d
	return best

## (distância ao eixo da rua mais próxima, meia-largura) no referencial local
static func nearest_road(l: Vector2) -> Vector2:
	var best := Vector2(INF, 0.0)
	for road in ROADS:
		var pts: Array = road["pts"]
		for i in pts.size() - 1:
			var d := _segment_distance(l, pts[i], pts[i + 1])
			if d - road["w"] * 0.5 < best.x - best.y:
				best = Vector2(d, road["w"] * 0.5)
	return best

## Pátio dos Mestres: o único canto da cidade onde se luta (bonecos de treino)
const YARD_RADIUS: float = 8.0

static func in_training_yard(x: float, z: float) -> bool:
	return to_local(x, z).distance_to(DISTRICTS[&"pelvis"]["at"]) < YARD_RADIUS

## Rua, praça ou pátio: sem grama nem tufos
static func is_paved(x: float, z: float) -> bool:
	if ellipse_k(x, z) > 1.1:
		return false
	var l := to_local(x, z)
	if l.distance_to(HEART) < HEART_RADIUS + 0.6:
		return true
	var r := nearest_road(l)
	if r.x < r.y + 0.4:
		return true
	return l.distance_to(DISTRICTS[&"pelvis"]["at"]) < 8.5

## Relevo: aplaina dentro da elipse no PLATEAU_Y com um pouco do ruído; a praça fica lisa.
## Fora (k > 1,3) devolve `h` intacto; entre 1 e 1,3 faz a transição.
static func shape_height(x: float, z: float, h: float) -> float:
	var k := ellipse_k(x, z)
	if k >= 1.3:
		return h
	var floor_h := PLATEAU_Y + (h - PLATEAU_Y) * RELIEF_KEEP
	var l := to_local(x, z)
	var dp := l.distance_to(HEART)
	if dp < HEART_RADIUS + 3.0:
		floor_h = lerpf(PLATEAU_Y, floor_h, smoothstep(HEART_RADIUS + 0.5, HEART_RADIUS + 3.0, dp))
	return lerpf(floor_h, h, smoothstep(1.0, 1.3, k))

## Chão: pó de osso nas ruas e na praça, terra seca e avermelhada no resto
static func ground_tint(x: float, z: float, base: Color) -> Color:
	var k := ellipse_k(x, z)
	if k > 1.25:
		return base
	var inside := 1.0 - smoothstep(1.0, 1.25, k)
	var col := base.lerp(Color(0.46, 0.40, 0.28), 0.45 * inside)
	var l := to_local(x, z)
	var r := nearest_road(l)
	var t := 1.0 - smoothstep(r.y - 0.4, r.y + 1.0, r.x)
	t = maxf(t, 1.0 - smoothstep(HEART_RADIUS, HEART_RADIUS + 1.4, l.distance_to(HEART)))
	t = maxf(t, (1.0 - smoothstep(7.5, 9.0, l.distance_to(DISTRICTS[&"pelvis"]["at"]))) * 0.8)
	var bone_dust := Color(0.72, 0.66, 0.52).lerp(Color(0.62, 0.55, 0.42), (sin(x * 0.9 + z * 0.4) * sin(z * 0.7 - x * 0.3)) * 0.5 + 0.5)
	return col.lerp(bone_dust, t * inside)

static func _segment_distance(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return p.distance_to(a + ab * t)
