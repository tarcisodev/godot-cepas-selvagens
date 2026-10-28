class_name GatherableSpawner
extends Node3D

## Distribuidor Ecológico dos 10 Recursos Coletáveis no Mapa
## Espalha Madeira, Galho, Folha, Fibra, Pedra, Frutinha, Besouro,
## Ossos, Erva e Mel em biomas/zonas coerentes do relevo.

const GatherableResourceClass = preload("res://scripts/gatherable_resource.gd")
const RiverClass = preload("res://scripts/river_system.gd")

@export var landscape: MeshInstance3D

@export_group("Quantidades de Recursos")
@export var count_madeira: int = 28
@export var count_galho: int = 48
@export var count_folha: int = 40
@export var count_fibra: int = 44
@export var count_pedra: int = 50
@export var count_frutinha: int = 30
@export var count_besouro: int = 24
@export var count_ossos: int = 20
@export var count_erva: int = 40
@export var count_mel: int = 16
## Veios de minério (GDD-12 §8): número de grupos; cada grupo tem 3–5 nós
@export var count_veios_ferro: int = 14
@export var count_veios_quartzo: int = 5

var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	if landscape == null:
		landscape = get_parent().get_node_or_null("Landscape")
	
	_rng.seed = 20261021
	spawn_all_resources()

func spawn_all_resources() -> void:
	# 1. Galhos e Folhas (espalhados pela vegetação e clareiras)
	_spawn_scattered(GatherableResourceClass.Type.GALHO, count_galho, 10.0, WorldBounds.HALF * 0.85)
	_spawn_scattered(GatherableResourceClass.Type.FOLHA, count_folha, 8.0, WorldBounds.HALF * 0.8)
	
	# 2. Madeira (troncos caídos em clareiras e bordas de mata)
	_spawn_scattered(GatherableResourceClass.Type.MADEIRA, count_madeira, 12.0, WorldBounds.HALF * 0.8)
	
	# 3. Fibras e Ervas (concentradas perto da margem do rio e mata ciliar)
	_spawn_riparian(GatherableResourceClass.Type.FIBRA, count_fibra, 2.5, 9.0)
	_spawn_riparian(GatherableResourceClass.Type.ERVA, count_erva, 3.0, 14.0)
	
	# 4. Frutinhas (arbustos nas transições do vale)
	_spawn_scattered(GatherableResourceClass.Type.FRUTINHA, count_frutinha, 14.0, WorldBounds.HALF * 0.75)
	
	# 5. Pedras (colinas, encostas rochosas e cascalho)
	_spawn_slopes(GatherableResourceClass.Type.PEDRA, count_pedra)
	
	# 6. Besouros (perto de troncos úmidos e margens)
	_spawn_riparian(GatherableResourceClass.Type.BESOURO, count_besouro, 4.0, 16.0)
	
	# 7. Ossos (próximos à arena e morro da Besta de Sucata)
	_spawn_hazardous(GatherableResourceClass.Type.OSSOS, count_ossos)
	
	# 8. Mel (em árvores e clareiras ensolaradas)
	_spawn_scattered(GatherableResourceClass.Type.MEL, count_mel, 15.0, WorldBounds.HALF * 0.8)

	# 9. Veios de minério: grupos nas encostas altas; o quartzo só nas mais altas
	_spawn_veins(GatherableResourceClass.Type.VEIO_FERRO, count_veios_ferro, 0.45)
	_spawn_veins(GatherableResourceClass.Type.VEIO_QUARTZO, count_veios_quartzo, 0.75)

func _get_ground_y(x: float, z: float) -> float:
	if landscape and landscape.has_method("get_height_at"):
		return landscape.get_height_at(x, z)
	return 0.0

## Espalha recursos em raios gerais longe do spawn central imediato
func _spawn_scattered(type: GatherableResourceClass.Type, count: int, min_dist: float, max_dist: float) -> void:
	var spawned: int = 0
	var attempts: int = 0
	while spawned < count and attempts < count * 8:
		attempts += 1
		var angle := _rng.randf_range(0.0, TAU)
		var dist := _rng.randf_range(min_dist, max_dist)
		var x: float = cos(angle) * dist
		var z: float = sin(angle) * dist
		
		# Não nasce no meio do rio profundo
		var dist_river := RiverClass.get_distance_to_river(x, z)
		var river_hw := RiverClass.get_water_half_width(z)
		if dist_river < (river_hw + 1.2):
			continue
		
		if _create_node(type, x, z):
			spawned += 1

## Concentra recursos ao longo da margem fértil do rio
func _spawn_riparian(type: GatherableResourceClass.Type, count: int, min_river_dist: float, max_river_dist: float) -> void:
	var spawned: int = 0
	var attempts: int = 0
	while spawned < count and attempts < count * 8:
		attempts += 1
		var z := _rng.randf_range(-WorldBounds.HALF * 0.85, WorldBounds.HALF * 0.85)
		# Pula o penhasco vertical da cachoeira
		if z >= (RiverClass.WATERFALL_Z - 3.0) and z <= (RiverClass.WATERFALL_Z + 4.0):
			continue
		
		var rx: float = RiverClass.get_river_center_x(z)
		var hw: float = RiverClass.get_water_half_width(z)
		var side: float = 1.0 if _rng.randf() > 0.5 else -1.0
		var offset: float = _rng.randf_range(min_river_dist, max_river_dist)
		var x: float = rx + (side * (hw + offset))
		
		if Vector2(x, z).length() < 7.0:
			continue
		
		if _create_node(type, x, z):
			spawned += 1

## Gera pedras em encostas mais altas e penhascos
func _spawn_slopes(type: GatherableResourceClass.Type, count: int) -> void:
	var spawned: int = 0
	var attempts: int = 0
	while spawned < count and attempts < count * 8:
		attempts += 1
		var x := _rng.randf_range(-WorldBounds.HALF * 0.85, WorldBounds.HALF * 0.85)
		var z := _rng.randf_range(-WorldBounds.HALF * 0.85, WorldBounds.HALF * 0.85)
		var y := _get_ground_y(x, z)
		
		if landscape != null and y < 1.0 and _rng.randf() > 0.35:
			continue
		
		var dist_river := RiverClass.get_distance_to_river(x, z)
		var river_hw := RiverClass.get_water_half_width(z)
		if dist_river < (river_hw + 1.0):
			continue
		
		if _create_node(type, x, z):
			spawned += 1

## Grupos de 3–5 nós de minério nas encostas: `height_frac` = fração da altura máxima
## amostrada a partir da qual o grupo pode nascer (0,75 = só no alto dos morros)
func _spawn_veins(type: GatherableResourceClass.Type, groups: int, height_frac: float) -> void:
	var max_y := 1.0
	for i in 200:
		max_y = maxf(max_y, _get_ground_y(_rng.randf_range(-WorldBounds.HALF, WorldBounds.HALF) * 0.85, _rng.randf_range(-WorldBounds.HALF, WorldBounds.HALF) * 0.85))
	var min_y := max_y * height_frac
	var spawned := 0
	var attempts := 0
	while spawned < groups and attempts < groups * 60:
		attempts += 1
		var cx := _rng.randf_range(-WorldBounds.HALF * 0.85, WorldBounds.HALF * 0.85)
		var cz := _rng.randf_range(-WorldBounds.HALF * 0.85, WorldBounds.HALF * 0.85)
		if landscape != null and _get_ground_y(cx, cz) < min_y:
			continue
		if RiverClass.get_distance_to_river(cx, cz) < RiverClass.get_water_half_width(cz) + 6.0:
			continue
		if CityHub.in_village(cx, cz, 12.0):
			continue
		var n := _rng.randi_range(3, 5)
		for k in n:
			var a := _rng.randf() * TAU
			var r := _rng.randf_range(0.8, 3.2) if k > 0 else 0.0
			var node := _create_node(type, cx + cos(a) * r, cz + sin(a) * r)
			if node:
				node.add_to_group("ore_veins")
		spawned += 1

## Gera ossos perto das zonas de perigo (Arena em -27, 3 e Morro da Besta em -5, -11)
func _spawn_hazardous(type: GatherableResourceClass.Type, count: int) -> void:
	var centers: Array[Vector2] = [
		Vector2(-27.0, 3.0),  # Arena
		Vector2(-6.0, -10.0), # Proximidades do morro da Besta
		Vector2(-25.0, -35.0) # Penhasco
	]
	
	var spawned: int = 0
	var attempts: int = 0
	while spawned < count and attempts < count * 8:
		attempts += 1
		var center: Vector2 = centers[_rng.randi() % centers.size()]
		var offset_r := _rng.randf_range(3.0, 14.0)
		var offset_a := _rng.randf_range(0.0, TAU)
		var x: float = center.x + cos(offset_a) * offset_r
		var z: float = center.y + sin(offset_a) * offset_r
		if _create_node(type, x, z):
			spawned += 1

func _create_node(type: GatherableResourceClass.Type, x: float, z: float) -> GatherableResource:
	# Nada nasce dentro da paliçada, no meio das obras da vila
	if CityHub.in_village(x, z):
		return null
	var y: float = _get_ground_y(x, z)
	if RiverClass.is_in_water(Vector3(x, y, z)) or RiverClass.is_in_sea(x, z) or RiverClass.is_in_lake(x, z):
		return null
	var res := GatherableResourceClass.new()
	res.type = type
	res.position = Vector3(x, y, z)
	res.rotation.y = _rng.randf_range(0.0, TAU)
	add_child(res)
	return res
