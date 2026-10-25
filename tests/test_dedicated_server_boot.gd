extends SceneTree

## Teste automatizado do DedicatedServerBoot (B24).
## Valida parsing de argumentos de linha de comando (--server, --port, --ws) e existência da cena mínima de servidor.

const DedicatedServerBootClass = preload("res://scripts/net/dedicated_server_boot.gd")

var _started: bool = false

func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false

func _run() -> void:
	print("\n========================================================")
	print("🖥️ TESTANDO DEDICATED SERVER BOOT")
	print("========================================================")

	_test_arg_parsing()
	_test_server_scene_exists()

	print("\n🎉 TODOS OS TESTES DO DEDICATED SERVER BOOT PASSARAM COM SUCESSO!")
	print("========================================================\n")
	quit(0)

func _test_arg_parsing() -> void:
	print("  1. Verificando parsing de argumentos...")

	# Checagem de --server
	var args_server := PackedStringArray(["--server", "--port", "9000"])
	assert(DedicatedServerBootClass.parse_is_server(args_server), "Deve identificar --server")
	assert(DedicatedServerBootClass.parse_port(args_server, 8787) == 9000, "Deve ler porta 9000")

	# Checagem de porta padrão
	var args_default := PackedStringArray(["--server"])
	assert(DedicatedServerBootClass.parse_is_server(args_default), "Deve identificar --server")
	assert(DedicatedServerBootClass.parse_port(args_default, 8787) == 8787, "Deve retornar porta padrão 8787")

	# Checagem de --port=8888
	var args_eq := PackedStringArray(["--server", "--port=8888"])
	assert(DedicatedServerBootClass.parse_port(args_eq, 8787) == 8888, "Deve ler porta no formato --port=8888")

	# Sem flag de server
	var args_client := PackedStringArray(["--client", "127.0.0.1"])
	assert(not DedicatedServerBootClass.parse_is_server(args_client), "Não deve identificar server quando não houver flag")

	# Checagem de WebSocket
	var args_ws := PackedStringArray(["--server", "--ws"])
	assert(DedicatedServerBootClass.parse_use_websocket(args_ws), "Deve identificar flag --ws")
	assert(not DedicatedServerBootClass.parse_use_websocket(args_default), "Sem flag --ws deve retornar false")

	# Checagem de FPS máximo do servidor (padrão 20)
	var args_fps := PackedStringArray(["--server", "--max-fps", "25"])
	assert(DedicatedServerBootClass.parse_max_fps(args_fps, 20) == 25, "Deve ler --max-fps 25")
	var args_fps_eq := PackedStringArray(["--server", "--fps=15"])
	assert(DedicatedServerBootClass.parse_max_fps(args_fps_eq, 20) == 15, "Deve ler --fps=15")
	assert(DedicatedServerBootClass.parse_max_fps(args_default, 20) == 20, "Sem flag deve retornar padrão 20 fps")

	# Checagem de ticks de física por segundo (padrão 20 Hz)
	var args_ticks := PackedStringArray(["--server", "--physics-ticks", "30"])
	assert(DedicatedServerBootClass.parse_physics_ticks(args_ticks, 20) == 30, "Deve ler --physics-ticks 30")
	var args_ticks_eq := PackedStringArray(["--server", "--ticks=24"])
	assert(DedicatedServerBootClass.parse_physics_ticks(args_ticks_eq, 20) == 24, "Deve ler --ticks=24")
	assert(DedicatedServerBootClass.parse_physics_ticks(args_default, 20) == 20, "Sem flag deve retornar padrão 20 ticks")

	print("     ✓ Parsing de argumentos validado com sucesso")

func _test_server_scene_exists() -> void:
	print("  2. Verificando existência da cena mínima de servidor...")
	var scene_path := DedicatedServerBootClass.SERVER_WORLD_SCENE
	assert(ResourceLoader.exists(scene_path), "Cena mínima de servidor deve existir em %s" % scene_path)

	var scene := load(scene_path) as PackedScene
	assert(scene != null, "Cena de servidor deve ser carregável")

	var inst := scene.instantiate()
	assert(inst != null, "Cena de servidor deve instanciar sem erros")

	# Garante que não possui nós de UI nem jogador local
	assert(inst.get_node_or_null("HUD") == null, "Cena de servidor não deve conter HUD")
	assert(inst.get_node_or_null("PauseMenu") == null, "Cena de servidor não deve conter PauseMenu")
	assert(inst.get_node_or_null("Player") == null, "Cena de servidor não deve conter nó de jogador local")

	inst.free()
	print("     ✓ Cena mínima de servidor validada sem dependências de UI")
