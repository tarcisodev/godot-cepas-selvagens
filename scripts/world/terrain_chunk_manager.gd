class_name TerrainChunkManager
extends Node3D

## Gerenciador de Chunks de Terreno e Vegetação em MultiMesh (B24).
## Permite a expansão do mundo de Cepas Selvagens de 360m para escala de quilômetros,
## gerando terreno contínuo e vegetação otimizada por GPU instancing ao redor dos jogadores.

const RiverClass = preload("res://scripts/river_system.gd")

const GRASS_SCENES: Array[PackedScene] = [
	preload("res://assets/models/nature/Grass_Common_Short.gltf"),
	preload("res://assets/models/nature/Grass_Wispy_Short.gltf"),
]

const FLOWER_SCENES: Array[PackedScene] = [
	preload("res://assets/models/nature/Flower_3_Group.gltf"),
	preload("res://assets/models/nature/Clover_1.gltf"),
]

@export var enabled: bool = true
@export var chunk_size: float = 64.0
@export var subdivisions: int = 16
@export var view_distance_chunks: int = 3
@export var grass_per_chunk: int = 350
@export var flowers_per_chunk: int = 30
@export var landscape: MeshInstance3D

## Dicionário de chunks ativos: Vector2i(coord_x, coord_z) -> Node3D (chunk)
var active_chunks: Dictionary = {}

var _grass_meshes: Array[Mesh] = []
var _flower_meshes: Array[Mesh] = []
var _material: StandardMaterial3D
var _check_timer: float = 0.0

func _ready() -> void:
	if not enabled:
		return
	WorldBounds.open_world_enabled = true
	if landscape == null:
		landscape = get_parent().get_node_or_null("Landscape") as LandscapeGenerator
	_init_materials_and_meshes()

func _init_materials_and_meshes() -> void:
	_material = StandardMaterial3D.new()
	_material.vertex_color_use_as_albedo = true
	_material.vertex_color_is_srgb = true
	_material.roughness = 0.95
	_material.metallic_specular = 0.1

	for sc in GRASS_SCENES:
		var m := _extract_mesh_from_scene(sc)
		if m:
			_grass_meshes.append(m)
	for sc in FLOWER_SCENES:
		var m := _extract_mesh_from_scene(sc)
		if m:
			_flower_meshes.append(m)

func _process(delta: float) -> void:
	if not enabled or landscape == null:
		return
	_check_timer -= delta
	if _check_timer > 0.0:
		return
	_check_timer = 0.35 # Atualiza chunks a ~3 Hz
	update_chunks_around_players()

func get_tracked_positions() -> Array[Vector3]:
	var positions: Array[Vector3] = []
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player != null and is_instance_valid(player):
		positions.append(player.global_position)

	var net: Node = get_node_or_null("/root/NetworkManager")
	if net != null and "remote_avatars" in net:
		var remotes: Dictionary = net.remote_avatars
		for id in remotes:
			var av: Node3D = remotes[id]
			if is_instance_valid(av):
				positions.append(av.global_position)
	return positions

func update_chunks_around_players() -> void:
	var positions := get_tracked_positions()
	if positions.is_empty():
		return

	var needed_coords: Dictionary = {}
	for pos in positions:
		var center_cx: int = int(floor(pos.x / chunk_size))
		var center_cz: int = int(floor(pos.z / chunk_size))
		for dz in range(-view_distance_chunks, view_distance_chunks + 1):
			for dx in range(-view_distance_chunks, view_distance_chunks + 1):
				var coord := Vector2i(center_cx + dx, center_cz + dz)
				# Se o chunk estiver totalmente dentro do vale central (já renderizado pelo Landscape), pula
				if _is_inside_central_valley(coord):
					continue
				needed_coords[coord] = true

	# Carrega novos chunks necessários
	for coord in needed_coords.keys():
		if not active_chunks.has(coord):
			_load_chunk(coord)

	# Descarrega chunks distantes de todos os jogadores
	var to_remove: Array[Vector2i] = []
	for coord in active_chunks.keys():
		if not needed_coords.has(coord):
			to_remove.append(coord)

	for coord in to_remove:
		_unload_chunk(coord)

func _is_inside_central_valley(coord: Vector2i) -> bool:
	var min_x: float = float(coord.x) * chunk_size
	var max_x: float = min_x + chunk_size
	var min_z: float = float(coord.y) * chunk_size
	var max_z: float = min_z + chunk_size
	var valley_limit: float = WorldBounds.VALLEY_HALF - 4.0
	return absf(min_x) < valley_limit and absf(max_x) < valley_limit and absf(min_z) < valley_limit and absf(max_z) < valley_limit

func _load_chunk(coord: Vector2i) -> void:
	var chunk := Node3D.new()
	chunk.name = "Chunk_%d_%d" % [coord.x, coord.y]
	add_child(chunk)
	active_chunks[coord] = chunk

	var origin_x: float = float(coord.x) * chunk_size
	var origin_z: float = float(coord.y) * chunk_size
	var step: float = chunk_size / float(subdivisions)
	var row: int = subdivisions + 1
	var total_verts: int = row * row

	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var heights := PackedFloat32Array()
	verts.resize(total_verts)
	normals.resize(total_verts)
	colors.resize(total_verts)
	uvs.resize(total_verts)
	heights.resize(total_verts)

	for zi in range(row):
		for xi in range(row):
			var idx: int = zi * row + xi
			var gx: float = origin_x + float(xi) * step
			var gz: float = origin_z + float(zi) * step
			var gy: float = landscape.get_height_at(gx, gz)
			heights[idx] = gy
			var v := Vector3(gx, gy, gz)
			verts[idx] = v
			colors[idx] = landscape.get_vertex_color_at(v)
			uvs[idx] = Vector2(gx * 0.1, gz * 0.1)

	# Normais suaves derivadas do relevo contínuo
	for zi in range(row):
		for xi in range(row):
			var idx: int = zi * row + xi
			var hl: float = heights[zi * row + maxi(xi - 1, 0)]
			var hr: float = heights[zi * row + mini(xi + 1, subdivisions)]
			var hd: float = heights[maxi(zi - 1, 0) * row + xi]
			var hu: float = heights[mini(zi + 1, subdivisions) * row + xi]
			normals[idx] = Vector3((hl - hr) / (2.0 * step), 1.0, (hd - hu) / (2.0 * step)).normalized()

	var indices := PackedInt32Array()
	indices.resize(subdivisions * subdivisions * 6)
	var k: int = 0
	for zi in range(subdivisions):
		for xi in range(subdivisions):
			var a: int = zi * row + xi
			indices[k] = a
			indices[k + 1] = a + 1
			indices[k + 2] = a + row
			indices[k + 3] = a + 1
			indices[k + 4] = a + row + 1
			indices[k + 5] = a + row
			k += 6

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var mesh_inst := MeshInstance3D.new()
	mesh_inst.mesh = am
	mesh_inst.material_override = _material
	chunk.add_child(mesh_inst)

	# Colisão trimesh física otimizada
	var static_body := StaticBody3D.new()
	static_body.collision_layer = 1
	var col_shape := CollisionShape3D.new()
	col_shape.shape = am.create_trimesh_shape()
	static_body.add_child(col_shape)
	chunk.add_child(static_body)

	# Vegetação em MultiMesh por chunk
	_build_multimesh_vegetation(chunk, origin_x, origin_z)

func _build_multimesh_vegetation(chunk: Node3D, origin_x: float, origin_z: float) -> void:
	if _grass_meshes.is_empty() and _flower_meshes.is_empty():
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = int(origin_x * 73856093.0) ^ int(origin_z * 19349663.0)

	# Grama
	if not _grass_meshes.is_empty() and grass_per_chunk > 0:
		var grass_transforms: Array[Transform3D] = []
		for i in grass_per_chunk:
			var rx: float = origin_x + rng.randf_range(1.0, chunk_size - 1.0)
			var rz: float = origin_z + rng.randf_range(1.0, chunk_size - 1.0)
			var dist_river: float = RiverClass.get_distance_to_river(rx, rz)
			var water_hw: float = RiverClass.get_water_half_width(rz)
			if dist_river < (water_hw * 0.9):
				continue
			var ry: float = landscape.get_height_at(rx, rz)
			if ry > 18.0:
				continue
			var s: float = rng.randf_range(0.35, 0.55)
			var basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3.ONE * s)
			grass_transforms.append(Transform3D(basis, Vector3(rx, ry - 0.03, rz)))

		if not grass_transforms.is_empty():
			var g_mm := MultiMesh.new()
			g_mm.transform_format = MultiMesh.TRANSFORM_3D
			g_mm.mesh = _grass_meshes[rng.randi() % _grass_meshes.size()]
			g_mm.instance_count = grass_transforms.size()
			for i in grass_transforms.size():
				g_mm.set_instance_transform(i, grass_transforms[i])

			var g_mmi := MultiMeshInstance3D.new()
			g_mmi.multimesh = g_mm
			g_mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			chunk.add_child(g_mmi)

	# Flores
	if not _flower_meshes.is_empty() and flowers_per_chunk > 0:
		var flower_transforms: Array[Transform3D] = []
		for i in flowers_per_chunk:
			var rx: float = origin_x + rng.randf_range(1.0, chunk_size - 1.0)
			var rz: float = origin_z + rng.randf_range(1.0, chunk_size - 1.0)
			var dist_river: float = RiverClass.get_distance_to_river(rx, rz)
			var water_hw: float = RiverClass.get_water_half_width(rz)
			if dist_river < (water_hw * 0.9):
				continue
			var ry: float = landscape.get_height_at(rx, rz)
			if ry > 15.0:
				continue
			var s: float = rng.randf_range(0.25, 0.38)
			var basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3.ONE * s)
			flower_transforms.append(Transform3D(basis, Vector3(rx, ry - 0.03, rz)))

		if not flower_transforms.is_empty():
			var f_mm := MultiMesh.new()
			f_mm.transform_format = MultiMesh.TRANSFORM_3D
			f_mm.mesh = _flower_meshes[rng.randi() % _flower_meshes.size()]
			f_mm.instance_count = flower_transforms.size()
			for i in flower_transforms.size():
				f_mm.set_instance_transform(i, flower_transforms[i])

			var f_mmi := MultiMeshInstance3D.new()
			f_mmi.multimesh = f_mm
			f_mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			chunk.add_child(f_mmi)

func _unload_chunk(coord: Vector2i) -> void:
	var chunk: Node3D = active_chunks.get(coord)
	if chunk != null and is_instance_valid(chunk):
		chunk.queue_free()
	active_chunks.erase(coord)

func _extract_mesh_from_scene(scene: PackedScene) -> Mesh:
	if scene == null:
		return null
	var inst := scene.instantiate()
	var mesh: Mesh = null
	if inst is MeshInstance3D:
		mesh = (inst as MeshInstance3D).mesh
	else:
		var found := inst.find_children("*", "MeshInstance3D", true, false)
		if not found.is_empty():
			mesh = (found[0] as MeshInstance3D).mesh
	inst.free()
	return mesh
