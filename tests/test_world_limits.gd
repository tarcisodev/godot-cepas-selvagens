extends SceneTree

## Regressão: descer do Planador longe do centro mandava o jogador de volta ao estábulo. O resgate
## do limbo usava os limites do mapa antigo (88 m e 130 m); o mapa vai até WorldBounds.HALF.

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")

var _started: bool = false

func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false

func _run() -> void:
	print("\n========================================================")
	print("🗺️ TESTANDO OS LIMITES DO MAPA NO RESGATE DO JOGADOR")
	print("========================================================")
	var player: Player = PlayerScene.instantiate() as Player
	root.add_child(player)
	player._setup_components()
	player.set_physics_process(false)
	player.last_safe_position = Vector3(2, 1, 2)

	# Longe do centro, mas dentro do mapa (onde o Planador leva): não é resgatado
	var far := Vector3(WorldBounds.HALF - 15.0, 5.0, -(WorldBounds.HALF - 25.0))
	player.global_position = far
	player._physics_process(0.016)
	assert(Vector2(player.global_position.x, player.global_position.z).distance_to(Vector2(far.x, far.z)) < 1.0, "A 150+ m do centro o jogador fica onde desceu (estava em %s)" % player.global_position)

	# Fora do mapa: volta para a última posição segura
	player.global_position = Vector3(WorldBounds.HALF + 40.0, 5.0, 0.0)
	player._physics_process(0.016)
	assert(player.global_position.distance_to(Vector3(2, 2, 2)) < 1.5, "Fora do mapa volta para o último lugar seguro")
	player.free()
	print("  ✓ Longe do centro fica; fora do mapa é resgatado")
	print("\n🎉 TODOS OS TESTES DOS LIMITES DO MAPA PASSARAM COM SUCESSO!")
	print("========================================================\n")
	quit(0)
