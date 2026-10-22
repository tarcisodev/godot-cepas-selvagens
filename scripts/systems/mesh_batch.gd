class_name MeshBatch
extends RefCounted

## Junta várias primitivas (esfera, cilindro, cápsula) numa malha só, com cor por vértice.
## Os vértices e normais de cada peça são transformados de uma vez (operação em C++ sobre o
## array inteiro), em vez de um a um pelo SurfaceTool — bem mais rápido para plantas e bichos.

## Arrays das primitivas de forma fixa já geradas, por chave
static var _cache: Dictionary = {}

var _verts := PackedVector3Array()
var _normals := PackedVector3Array()
var _colors := PackedColorArray()
var _indices := PackedInt32Array()

func is_empty() -> bool:
	return _verts.is_empty()

## Arrays de uma primitiva, guardados por `key` (use "" para formas que mudam a cada chamada)
static func arrays_of(mesh: PrimitiveMesh, key: String = "") -> Array:
	if key != "" and _cache.has(key):
		return _cache[key]
	var arrays := mesh.get_mesh_arrays()
	if key != "":
		_cache[key] = arrays
	return arrays

func append(arrays: Array, xform: Transform3D, color: Color) -> void:
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var base: int = _verts.size()
	_verts.append_array(xform * verts)
	# Normal com escala não uniforme: inversa transposta (o shader normaliza)
	_normals.append_array(Transform3D(xform.basis.inverse().transposed(), Vector3.ZERO) * normals)
	var cols := PackedColorArray()
	cols.resize(verts.size())
	cols.fill(color)
	_colors.append_array(cols)
	var start: int = _indices.size()
	_indices.append_array(indices)
	if base > 0:
		for i in range(start, _indices.size()):
			_indices[i] += base

func commit() -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _verts
	arrays[Mesh.ARRAY_NORMAL] = _normals
	arrays[Mesh.ARRAY_COLOR] = _colors
	arrays[Mesh.ARRAY_INDEX] = _indices
	var am := ArrayMesh.new()
	if not _verts.is_empty():
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return am
