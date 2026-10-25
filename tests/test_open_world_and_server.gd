extends SceneTree

## Teste automatizado do Bloco B24: Mundo Aberto em Chunks, MultiMesh e Persistência do Servidor.

const LandscapeClass = preload("res://scripts/landscape_generator.gd")
const TerrainChunkManagerClass = preload("res://scripts/world/terrain_chunk_manager.gd")
const ServerPersistenceClass = preload("res://scripts/core/server_persistence.gd")

var _started: bool = false

func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false

func _run() -> void:
	print("\n========================================================")
	print("🌍 TESTANDO MUNDO ABERTO (CHUNKS, MULTIMESH & SERVIDOR)")
	print("========================================================")

	_test_world_bounds_expansion()
	_test_landscape_unbounded_height()
	_test_chunk_manager_and_multimesh()
	_test_server_persistence()

	print("\n🎉 TODOS OS TESTES DE MUNDO ABERTO E SERVIDOR PASSARAM COM SUCESSO!")
	print("========================================================\n")
	quit(0)

func _test_world_bounds_expansion() -> void:
	print("  1. Verificando expansão de fronteiras do WorldBounds...")
	WorldBounds.open_world_enabled = false
	assert(WorldBounds.get_half() == 180.0, "Modo padrão deve ter meia-largura de 180m")
	assert(WorldBounds.inside(100.0, 100.0), "Dentro do vale 100m deve retornar true")
	assert(not WorldBounds.inside(250.0, 250.0), "Fora do vale (250m) deve retornar false no modo fechado")

	WorldBounds.open_world_enabled = true
	assert(WorldBounds.get_half() == WorldBounds.EXTENDED_HALF, "Modo mundo aberto deve ter meia-largura de 1500m")
	assert(WorldBounds.inside(250.0, 250.0), "250m deve ser permitido no mundo aberto")
	assert(WorldBounds.inside(1200.0, -1200.0), "1200m deve ser permitido para montarias de longa distância")
	assert(not WorldBounds.inside(1600.0, 0.0), "Além dos 1500m deve retornar false")
	WorldBounds.open_world_enabled = false
	print("     ✓ WorldBounds comuta perfeitamente entre Vale e Mundo Aberto (3 km)")

func _test_landscape_unbounded_height() -> void:
	print("  2. Verificando alturas contínuas no relevo procedural...")
	var landscape = LandscapeClass.new()
	root.add_child(landscape)

	WorldBounds.open_world_enabled = false
	assert(landscape.get_height_at(300.0, 300.0) == 0.0, "Fora dos bounds no modo fechado deve retornar 0")

	WorldBounds.open_world_enabled = true
	var h_outer: float = landscape.get_height_at(300.0, 300.0)
	# A altura deve ser avaliada de forma procedural pelo ruído Simplex
	var col := landscape.get_vertex_color_at(Vector3(300.0, h_outer, 300.0))
	assert(col.a > 0.0, "Cor de vértice nas terras distantes deve ser válida")

	landscape.queue_free()
	WorldBounds.open_world_enabled = false
	print("     ✓ Altura e cores avaliadas com sucesso fora das fronteiras originais")

func _test_chunk_manager_and_multimesh() -> void:
	print("  3. Verificando TerrainChunkManager e MultiMesh por chunk...")
	var landscape = LandscapeClass.new()
	root.add_child(landscape)

	var mgr = TerrainChunkManagerClass.new()
	mgr.landscape = landscape
	mgr.chunk_size = 64.0
	mgr.subdivisions = 8 # subdivisão leve para teste rápido
	mgr.grass_per_chunk = 50
	mgr.flowers_per_chunk = 10
	root.add_child(mgr)

	# Chunk central (0, 0) fica dentro do vale central (já atendido pelo Landscape nativo)
	assert(mgr._is_inside_central_valley(Vector2i(0, 0)), "Chunk 0,0 deve estar no vale central")
	# Chunk (4, 4) fica a 256m de distância (terra selvagem externa)
	assert(not mgr._is_inside_central_valley(Vector2i(4, 4)), "Chunk 4,4 deve ser considerado terra selvagem externa")

	# Gera um chunk externo sob demanda
	var test_coord := Vector2i(4, 4)
	mgr._load_chunk(test_coord)
	assert(mgr.active_chunks.has(test_coord), "Chunk 4,4 deve estar na lista de ativos")

	var chunk_node: Node3D = mgr.active_chunks[test_coord]
	assert(chunk_node != null, "Nó do chunk deve existir")

	# Verifica presença da malha do terreno
	var mesh_inst: MeshInstance3D = null
	var static_body: StaticBody3D = null
	var multimeshes: Array[MultiMeshInstance3D] = []

	for c in chunk_node.get_children():
		if c is MeshInstance3D and not (c is MultiMeshInstance3D):
			mesh_inst = c
		elif c is StaticBody3D:
			static_body = c
		elif c is MultiMeshInstance3D:
			multimeshes.append(c)

	assert(mesh_inst != null and mesh_inst.mesh != null, "Chunk deve conter ArrayMesh gerado")
	assert(static_body != null and static_body.get_child_count() > 0, "Chunk deve conter colisão física StaticBody3D")
	assert(multimeshes.size() > 0, "Chunk deve conter MultiMeshInstance3D para vegetação")

	# Descarrega o chunk
	mgr._unload_chunk(test_coord)
	assert(not mgr.active_chunks.has(test_coord), "Chunk deve ser descarregado da lista")

	mgr.queue_free()
	landscape.queue_free()
	WorldBounds.open_world_enabled = false
	print("     ✓ Chunks e MultiMeshes gerados e descarregados com sucesso")

func _test_server_persistence() -> void:
	print("  4. Verificando ServerPersistence (gravação e restauração de perfil)...")
	var sp = ServerPersistenceClass.new()
	root.add_child(sp)

	var test_name := "Guerreiro_Beta_101"
	var profile_data := {
		"position": [520.5, 14.2, -310.8],
		"rotation_y": 1.57,
		"health": 85.0,
		"money": 320,
		"is_mounted": true,
		"mount_name": "Trotador Ágil"
	}

	var saved: bool = sp.save_player_data(test_name, profile_data)
	assert(saved, "save_player_data deve retornar true")
	assert(sp.has_player_save(test_name), "has_player_save deve confirmar arquivo existente")

	var loaded: Dictionary = sp.load_player_data(test_name)
	assert(loaded.has("position") and loaded["position"][0] == 520.5, "Posição deve ser preservada com exatidão")
	assert(loaded.has("money") and int(loaded["money"]) == 320, "Saldo financeiro do jogador deve ser preservado")
	assert(loaded.has("mount_name") and loaded["mount_name"] == "Trotador Ágil", "Montaria deve ser preservada")

	# Limpa o arquivo de teste gerado
	var file_path: String = "%s/%s.json" % [ServerPersistenceClass.PLAYERS_DIR, test_name]
	if FileAccess.file_exists(file_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(file_path))

	sp.queue_free()
	print("     ✓ Persistência do servidor validada com 100% de integridade")
