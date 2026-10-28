class_name TownProject
extends Node3D

const _WorldLabel = preload("res://scripts/ui/world_label.gd")

## Obra da vila (GDD-08 §6.1): 3 etapas (Fundação → Estrutura → Acabamento), cada uma pedindo
## materiais comuns que os jogadores doam. Etapa completa muda o visual na hora:
## canteiro (estacas e caixotes) → piso de pedra → paredes com andaime → prédio pronto.
## As peças vêm do Medieval Village MegaKit (grade de 2 m).

signal stage_completed(project: TownProject, stage: int)
signal progress_changed(project: TownProject)

enum Kind { HOUSE, PAVILION, WELL, PALISADE }

const STAGE_NAMES: Array[String] = ["Fundação", "Estrutura", "Acabamento"]
const KIT := "res://assets/models/village/"
const FANTASY := "res://assets/models/props/fantasy/"
const MODULE: float = 2.0
const WALL_TOP: float = 3.1

@export var project_id: StringName
@export var display_name: String = ""
@export var icon: String = "🏗️"
## Para que o prédio serve quando ficar pronto
@export var purpose: String = ""
@export var kind: Kind = Kind.HOUSE
## Custos de cada etapa: [{material_id: quantidade}, ...] (3 etapas)
@export var stage_costs: Array[Dictionary] = []
## Tamanho em módulos de 2 m (x = largura, y = profundidade) para casas e pavilhões
@export var modules: Vector2i = Vector2i(2, 2)
@export var brick_walls: bool = false
@export var chimney: bool = false
## Paliçada: centro e raio do anel, e direções (graus, 0 = norte) onde ficam os portões
@export var ring_center: Vector2 = Vector2.ZERO
@export var ring_radius: float = 13.5
@export var gate_angles: Array[float] = []

## Etapas concluídas (0 a 3)
var stage: int = 0
## Doado na etapa atual: {material_id: quantidade}
var deposited: Dictionary = {}

var _visual: Node3D
var _sign: _WorldLabel
var _scene_cache: Dictionary = {}

func _ready() -> void:
	add_to_group("town_projects")
	_sign = _WorldLabel.make(_WorldLabel.Kind.NAME, "", "🏗️")
	add_child(_sign)
	_snap_to_ground()
	rebuild()

func is_complete() -> bool:
	return stage >= stage_costs.size()

func stage_name() -> String:
	return "Pronto" if is_complete() else STAGE_NAMES[stage]

## Custo da etapa atual ({} se pronta)
func current_costs() -> Dictionary:
	return {} if is_complete() else stage_costs[stage]

## O que ainda falta na etapa atual
func missing() -> Dictionary:
	var out := {}
	var costs := current_costs()
	for id in costs:
		var left: int = costs[id] - int(deposited.get(id, 0))
		if left > 0:
			out[id] = left
	return out

## Fração doada da etapa atual (0..1)
func stage_progress() -> float:
	var total := 0
	var done := 0
	var costs := current_costs()
	for id in costs:
		total += costs[id]
		done += mini(int(deposited.get(id, 0)), costs[id])
	return 1.0 if total == 0 else float(done) / float(total)

## Doa até `amount` de um material do inventário (limitado ao que falta e ao que há).
## Devolve quantas unidades entraram. Gasta a pior qualidade primeiro (ADR-0005).
func donate(inventory: InventoryComponent, material_id: StringName, amount: int) -> int:
	var need: int = missing().get(material_id, 0)
	var n := mini(mini(amount, need), inventory.get_material_count(material_id) if inventory else 0)
	if n <= 0:
		return 0
	inventory.consume_materials({material_id: n})
	deposited[material_id] = int(deposited.get(material_id, 0)) + n
	if missing().is_empty():
		stage += 1
		deposited = {}
		rebuild()
		stage_completed.emit(self, stage)
	else:
		_update_sign()
	progress_changed.emit(self)
	return n

func get_state() -> Dictionary:
	var dep := {}
	for id in deposited:
		dep[String(id)] = deposited[id]
	return {"stage": stage, "deposited": dep}

func apply_state(state: Dictionary) -> void:
	stage = clampi(int(state.get("stage", 0)), 0, stage_costs.size())
	deposited = {}
	for id in state.get("deposited", {}):
		deposited[StringName(id)] = int(state["deposited"][id])
	rebuild()
	progress_changed.emit(self)

# ---------------------------------------------------------------- visual

func rebuild() -> void:
	if _visual:
		_visual.free()
	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)
	match kind:
		Kind.HOUSE:
			_build_house()
		Kind.PAVILION:
			_build_pavilion()
		Kind.WELL:
			_build_well()
		Kind.PALISADE:
			_build_palisade()
	_update_sign()

func _update_sign() -> void:
	if _sign == null:
		return
	if kind == Kind.PALISADE:
		_sign.position = Vector3(ring_center.x - global_position.x, 3.4, ring_center.y - ring_radius - global_position.z + 1.0)
	else:
		_sign.position = Vector3(0, (WALL_TOP + 3.2) if stage >= 2 and kind == Kind.HOUSE else 3.0, 0)
	if is_complete():
		_sign.set_full_text("%s %s" % [icon, display_name])
		_sign.icon = icon
	else:
		_sign.icon = "🏗️"
		_sign.full_text = "🏗️ %s\n%s %d/3 · %d%%" % [display_name, STAGE_NAMES[stage], stage + 1, roundi(stage_progress() * 100.0)]

func _half() -> Vector2:
	return Vector2(modules.x, modules.y) * MODULE * 0.5

func _build_house() -> void:
	var h := _half()
	if stage == 0:
		_build_site_markers(h)
		return
	_build_plinth(h, "Floor_UnevenBrick" if brick_walls else "Floor_WoodDark")
	if stage == 1:
		_build_scaffold(h, 1.6)
		_build_material_piles(h, true)
		return
	var wall := "Wall_UnevenBrick" if brick_walls else "Wall_Plaster"
	_build_walls(h, wall)
	if stage == 2:
		_build_scaffold(h, WALL_TOP + 0.6)
		_build_material_piles(h, false)
		return
	_build_roof(h)
	if chimney:
		_place(KIT + "Prop_Chimney", Vector3(h.x - 0.9, WALL_TOP - 0.6, -h.y + 0.9))
	_place(FANTASY + "Barrel", Vector3(h.x + 0.6, 0, h.y - 0.4))
	_place(FANTASY + "Lantern_Wall", Vector3(1.0, 2.3, h.y + 0.12))

func _build_pavilion() -> void:
	var h := _half()
	if stage == 0:
		_build_site_markers(h)
		return
	_build_plinth(h, "Floor_Brick")
	if stage == 1:
		_build_material_piles(h, true)
		return
	for x in [-h.x + 0.25, 0.0, h.x - 0.25]:
		for z in [-h.y + 0.25, h.y - 0.25]:
			_post(Vector3(x, 0, z), 2.9, 0.13)
	if stage == 2:
		_build_scaffold(h, 2.6)
		return
	var roof := _place(KIT + "Roof_RoundTiles_4x6", Vector3(0, 2.85, 0))
	roof.scale = Vector3(h.x * 2.0 / 4.0, 0.8, h.y * 2.0 / 6.0)
	_place(FANTASY + "Stall_Empty", Vector3(-h.x * 0.45, 0, -h.y * 0.3), PI * 0.5).scale = Vector3.ONE * 0.75
	_place(FANTASY + "Stall_Cart_Empty", Vector3(h.x * 0.4, 0, h.y * 0.35), -PI * 0.5).scale = Vector3.ONE * 0.7
	_place(FANTASY + "FarmCrate_Apple", Vector3(h.x * 0.45, 0, -h.y * 0.5))
	_place(FANTASY + "Barrel_Apples", Vector3(-h.x * 0.4, 0, h.y * 0.55))

func _build_well() -> void:
	if stage == 0:
		for i in 6:
			var a := TAU * i / 6.0
			_post(Vector3(cos(a) * 1.1, 0, sin(a) * 1.1), 0.7, 0.05)
		_place(KIT + "Prop_Brick1", Vector3(1.6, 0.1, 0.3))
		_place(KIT + "Prop_Brick2", Vector3(1.7, 0.1, -0.2))
		return
	var ring_h := 0.35 if stage == 1 else 0.85
	var ring := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.0
	cyl.bottom_radius = 1.08
	cyl.height = ring_h + 0.6
	ring.mesh = cyl
	ring.position.y = (ring_h - 0.6) * 0.5
	ring.material_override = _flat_mat(Color(0.5, 0.49, 0.47), 0.95)
	_visual.add_child(ring)
	var water := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.82
	disc.bottom_radius = 0.82
	disc.height = 0.02
	water.mesh = disc
	water.position.y = ring_h - 0.25
	water.material_override = _flat_mat(Color(0.1, 0.22, 0.3), 0.1)
	_visual.add_child(water)
	_add_box_collision(Vector3(2.0, ring_h + 0.6, 2.0), Vector3(0, (ring_h - 0.6) * 0.5, 0))
	if stage == 1:
		_place(KIT + "Prop_Brick1", Vector3(1.6, 0.1, 0.3))
		return
	_post(Vector3(-0.95, 0, 0), 2.2, 0.08)
	_post(Vector3(0.95, 0, 0), 2.2, 0.08)
	if stage == 2:
		return
	var beam := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(2.1, 0.12, 0.12)
	beam.mesh = bm
	beam.position.y = 1.9
	beam.material_override = _flat_mat(Color(0.38, 0.25, 0.14), 0.85)
	_visual.add_child(beam)
	_place(KIT + "Roof_Wooden_2x1", Vector3(0, 2.1, -0.75)).scale = Vector3(1.0, 0.8, 1.0)
	_place(KIT + "Roof_Wooden_2x1", Vector3(0, 2.1, 0.75), PI).scale = Vector3(1.0, 0.8, 1.0)
	_place(FANTASY + "Bucket_Wooden_1", Vector3(0.7, ring_h, 0.5))

func _build_palisade() -> void:
	# Anel em segmentos de 2 m; pula água, encostas fortes e os portões
	var center := Vector3(ring_center.x, 0, ring_center.y)
	var seg_count := int(TAU * ring_radius / MODULE)
	for i in seg_count:
		var a := TAU * (i + 0.5) / seg_count
		var compass := fposmod(rad_to_deg(a) + 90.0, 360.0)
		if _near_gate(compass):
			continue
		var world := center + Vector3(cos(a), 0, sin(a)) * ring_radius
		var y := _ground(world.x, world.z)
		if RiverSystem.is_in_water(Vector3(world.x, y, world.z)):
			continue
		var local := world - global_position
		local.y = y - global_position.y
		var yaw := -a + PI * 0.5
		if stage == 0:
			if i % 4 == 0:
				_post(local, 1.0, 0.06)
		elif stage == 1:
			_post(local, 1.6, 0.09)
		elif stage == 2:
			_post(local, 1.6, 0.09)
			if i % 2 == 0:
				_place(KIT + "Prop_WoodenFence_Single", local, yaw)
		else:
			_place(KIT + "Prop_WoodenFence_Single", local, yaw)
	if stage >= 3:
		for g in gate_angles:
			for side in [-1.0, 1.0]:
				var ga: float = deg_to_rad(g - 90.0) + side * deg_to_rad(9.0)
				var p := center + Vector3(cos(ga), 0, sin(ga)) * ring_radius
				var local := p - global_position
				local.y = _ground(p.x, p.z) - global_position.y
				_post(local, 3.4, 0.22)
				var light := OmniLight3D.new()
				light.light_color = Color(1.0, 0.78, 0.45)
				light.omni_range = 6.0
				light.position = local + Vector3(0, 3.5, 0)
				_visual.add_child(light)

func _near_gate(compass_deg: float) -> bool:
	for g in gate_angles:
		if absf(angle_difference(deg_to_rad(compass_deg), deg_to_rad(g))) < deg_to_rad(9.0):
			return true
	return false

# ---------------------------------------------------------------- peças

func _build_site_markers(h: Vector2) -> void:
	for c in [Vector2(-h.x, -h.y), Vector2(h.x, -h.y), Vector2(h.x, h.y), Vector2(-h.x, h.y)]:
		_post(Vector3(c.x, 0, c.y), 0.9, 0.05)
	# Cordão entre as estacas
	var rope := _flat_mat(Color(0.75, 0.65, 0.45), 0.9)
	for edge in [[Vector2(-h.x, -h.y), Vector2(h.x, -h.y)], [Vector2(h.x, -h.y), Vector2(h.x, h.y)], [Vector2(h.x, h.y), Vector2(-h.x, h.y)], [Vector2(-h.x, h.y), Vector2(-h.x, -h.y)]]:
		var a: Vector2 = edge[0]
		var b: Vector2 = edge[1]
		var m := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3((b - a).length(), 0.02, 0.02)
		m.mesh = bm
		m.material_override = rope
		m.position = Vector3((a.x + b.x) * 0.5, 0.75, (a.y + b.y) * 0.5)
		m.rotation.y = -atan2(b.y - a.y, b.x - a.x)
		_visual.add_child(m)
	_place(KIT + "Prop_Crate", Vector3(h.x * 0.4, 0, h.y * 0.2))
	_place(KIT + "Prop_Brick1", Vector3(-h.x * 0.3, 0.1, -h.y * 0.2))
	_place(KIT + "Prop_Brick2", Vector3(-h.x * 0.2, 0.1, -h.y * 0.35))

func _build_plinth(h: Vector2, floor_piece: String) -> void:
	# Base de pedra que desce até o terreno (o chão do vale não é plano)
	var base := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(h.x * 2.0 + 0.3, 1.2, h.y * 2.0 + 0.3)
	base.mesh = bm
	base.position.y = -0.58
	base.material_override = _flat_mat(Color(0.45, 0.43, 0.4), 0.95)
	_visual.add_child(base)
	_add_box_collision(bm.size, base.position)
	for ix in modules.x:
		for iz in modules.y:
			_place(KIT + floor_piece, Vector3(-h.x + MODULE * (ix + 0.5), 0.03, -h.y + MODULE * (iz + 0.5)))

func _build_walls(h: Vector2, wall: String) -> void:
	var door_index := modules.x / 2
	for ix in modules.x:
		var x := -h.x + MODULE * (ix + 0.5)
		_wall(wall + ("_Window_Wide_Round" if ix != door_index else "_Straight"), Vector3(x, 0, -h.y), 0.0)
		_wall(wall + ("_Door_Round" if ix == door_index else "_Window_Wide_Round"), Vector3(x, 0, h.y), PI)
	for iz in modules.y:
		var z := -h.y + MODULE * (iz + 0.5)
		_wall(wall + "_Straight", Vector3(-h.x, 0, z), PI * 0.5)
		_wall(wall + ("_Window_Wide_Round" if iz % 2 == 0 else "_Straight"), Vector3(h.x, 0, z), -PI * 0.5)
	for c in [Vector2(-h.x, -h.y), Vector2(h.x, -h.y), Vector2(h.x, h.y), Vector2(-h.x, h.y)]:
		_place(KIT + ("Corner_Exterior_Brick" if brick_walls else "Corner_Exterior_Wood"), Vector3(c.x, 0, c.y))
	# Porta (só no acabamento) e colisão das paredes
	if stage >= 3:
		_place(KIT + "Door_1_Round", Vector3(-h.x + MODULE * (door_index + 0.5) + 0.55, 0, h.y - 0.05), PI)
	for side in [[Vector3(h.x * 2.0, WALL_TOP, 0.3), Vector3(0, WALL_TOP * 0.5, -h.y)], [Vector3(0.3, WALL_TOP, h.y * 2.0), Vector3(-h.x, WALL_TOP * 0.5, 0)], [Vector3(0.3, WALL_TOP, h.y * 2.0), Vector3(h.x, WALL_TOP * 0.5, 0)]]:
		_add_box_collision(side[0], side[1])

func _wall(piece: String, pos: Vector3, yaw: float) -> void:
	_place(KIT + piece, pos, yaw)

func _build_roof(h: Vector2) -> void:
	var key := "%dx%d" % [modules.x * 2, modules.y * 2]
	var roof_scene: String = {"4x4": "Roof_RoundTiles_4x4", "4x6": "Roof_RoundTiles_4x6", "6x6": "Roof_RoundTiles_6x6", "6x8": "Roof_RoundTiles_6x8"}.get(key, "Roof_RoundTiles_4x4")
	_place(KIT + roof_scene, Vector3(0, WALL_TOP, 0))

func _build_scaffold(h: Vector2, height: float) -> void:
	# Andaime: postes finos fora das paredes, tábuas a meia altura e no topo
	var wood := _flat_mat(Color(0.55, 0.4, 0.24), 0.9)
	var off := 0.55
	var xs := [-h.x - off, h.x + off]
	var zs := [-h.y - off, h.y + off]
	for x in xs:
		for z in [-h.y - off, 0.0, h.y + off]:
			_post(Vector3(x, 0, z), height, 0.05)
	for z in zs:
		_post(Vector3(0, 0, z), height, 0.05)
	for level in [height * 0.5, height]:
		for z in zs:
			_plank(Vector3(0, level, z), Vector3(h.x * 2.0 + off * 2.0, 0.06, 0.35), wood)
		for x in xs:
			_plank(Vector3(x, level, 0), Vector3(0.35, 0.06, h.y * 2.0 + off * 2.0), wood)

func _build_material_piles(h: Vector2, stones: bool) -> void:
	_place(KIT + "Prop_Crate", Vector3(h.x + 1.4, 0, -h.y + 0.6))
	if stones:
		_place(KIT + "Prop_Brick1", Vector3(h.x + 1.3, 0.1, 0.4))
		_place(KIT + "Prop_Brick2", Vector3(h.x + 1.6, 0.1, 0.1))
	else:
		# Toras empilhadas
		for i in 3:
			var trunk := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.14
			cyl.bottom_radius = 0.14
			cyl.height = 2.2
			trunk.mesh = cyl
			trunk.rotation.z = PI * 0.5
			trunk.position = Vector3(h.x + 1.5, 0.15 + 0.26 * (i % 2), 0.6 + 0.3 * i)
			trunk.material_override = _flat_mat(Color(0.45, 0.3, 0.18), 0.9)
			_visual.add_child(trunk)

func _post(pos: Vector3, height: float, radius: float) -> void:
	var m := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius * 1.15
	cyl.height = height
	cyl.radial_segments = 8
	m.mesh = cyl
	m.position = pos + Vector3(0, height * 0.5, 0)
	m.material_override = _flat_mat(Color(0.38, 0.25, 0.14), 0.9)
	_visual.add_child(m)

func _plank(pos: Vector3, size: Vector3, mat: Material) -> void:
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	m.mesh = bm
	m.position = pos
	m.material_override = mat
	_visual.add_child(m)

func _place(path: String, pos: Vector3, yaw: float = 0.0) -> Node3D:
	var scene := _scene(path)
	var n: Node3D = scene.instantiate() if scene else Node3D.new()
	n.position = pos
	n.rotation.y = yaw
	_visual.add_child(n)
	return n

func _scene(path: String) -> PackedScene:
	if not _scene_cache.has(path):
		var full := path + ".gltf"
		_scene_cache[path] = load(full) as PackedScene if ResourceLoader.exists(full) else null
	return _scene_cache[path]

func _add_box_collision(size: Vector3, pos: Vector3) -> void:
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	col.position = pos
	body.add_child(col)
	_visual.add_child(body)

func _flat_mat(color: Color, roughness: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	return m

func _ground(x: float, z: float) -> float:
	var landscape := _landscape()
	return landscape.get_height_at(x, z) if landscape else global_position.y

func _landscape() -> Node:
	var scene := get_tree().current_scene if is_inside_tree() else null
	return scene.get_node_or_null("Landscape") if scene else null

## Casas e pavilhões assentam na parte mais alta do terreno sob a base (a base desce até o chão)
func _snap_to_ground() -> void:
	var landscape := _landscape()
	if landscape == null or kind == Kind.PALISADE:
		return
	var h := _half() if kind != Kind.WELL else Vector2(1.0, 1.0)
	var top := -INF
	for c in [Vector2(-h.x, -h.y), Vector2(h.x, -h.y), Vector2(h.x, h.y), Vector2(-h.x, h.y), Vector2.ZERO]:
		top = maxf(top, landscape.get_height_at(global_position.x + c.x, global_position.z + c.y))
	global_position.y = top
