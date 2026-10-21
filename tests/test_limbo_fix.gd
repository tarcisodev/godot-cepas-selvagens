extends SceneTree

var _started: bool = false

func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false

func _run() -> void:
	print("\n========================================================")
	print("🛡 TESTANDO SISTEMA ANTI-LIMBO E RESGATE DO VAZIO")
	print("========================================================")
	
	# 1. Testar paredes do terreno e piso de segurança
	var landscape_script = load("res://scripts/landscape_generator.gd")
	var landscape = landscape_script.new()
	root.add_child(landscape)
	landscape.generate_landscape()
	
	var col_body = landscape.get_node_or_null("TerrainCollision") as StaticBody3D
	assert(col_body != null, "StaticBody de colisão criado")
	# Deve ter: trimesh + 4 paredes + 1 piso = 6 shapes
	assert(col_body.get_child_count() >= 6, "Paredes de contenção e piso de segurança criados")
	print("  ✓ Paredes de contenção de borda e piso de segurança instalados")
	
	# 2. Testar resgate do jogador ao cair no abismo
	var player_scene = load("res://scenes/player.tscn")
	var player = player_scene.instantiate() as Player
	root.add_child(player)
	player.global_position = Vector3(0.0, 1.2, 0.0)
	player.last_safe_position = Vector3(0.0, 1.2, 0.0)
	
	# Simula queda no vazio (y = -35.0) com velocidade vertical
	player.global_position = Vector3(5.0, -35.0, 5.0)
	player.velocity = Vector3(0.0, -50.0, 0.0)
	player._physics_process(0.016)
	
	assert(player.global_position.y > -5.0, "Jogador resgatado do abismo")
	assert(player.velocity == Vector3.ZERO, "Velocidade resetada após resgate")
	print("  ✓ Resgate automático de queda no vazio validado (y: %.2f)" % player.global_position.y)
	
	# 3. Testar sanitização de save corrompido no limbo
	var save_game_script = load("res://scripts/core/save_game.gd")
	var save_game = save_game_script.new()
	var bad_save = {
		"version": 1,
		"position": [10.0, -500.0, 20.0]
	}
	save_game.apply_save(player, bad_save)
	assert(player.global_position.y > 0.0, "Save com posição no limbo normalizado para área segura")
	print("  ✓ Sanitização de saves corrompidos no limbo validada (pos: %s)" % str(player.global_position))
	
	save_game.free()
	player.free()
	landscape.free()
	print("\n🎉 SISTEMA ANTI-LIMBO PASSOU COM SUCESSO!\n")
	quit(0)
