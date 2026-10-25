extends SceneTree

## Teste automatizado de Segurança do Servidor, Versionamento Semver e Conexão Padrão (Playtest Fechado).
## Valida GAME_VERSION, rejeição com "atualize o jogo", rate limiting por IP, limite de conexões simultâneas,
## 32 jogadores, remoção de _process na server_world e opções de servidor avançado no client.

const NetworkManagerClass = preload("res://scripts/core/network_manager.gd")
const DedicatedServerBootClass = preload("res://scripts/net/dedicated_server_boot.gd")
const ServerPersistenceClass = preload("res://scripts/core/server_persistence.gd")
const OnlineAuthModalClass = preload("res://scripts/ui/online_auth_modal.gd")
const DayNightCycleClass = preload("res://scripts/day_night_cycle.gd")
const TerrainChunkManagerClass = preload("res://scripts/world/terrain_chunk_manager.gd")

var _started: bool = false

func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false

func _run() -> void:
	print("\n========================================================")
	print("🛡️ TESTANDO SEGURANÇA DO SERVIDOR, VERSIONAMENTO E PLAYTEST")
	print("========================================================")

	_test_game_version_and_mismatch()
	_test_rate_limiting_and_limits()
	_test_server_world_process_optimization()
	_test_online_auth_modal_defaults_and_adv_toggle()
	_test_dedicated_server_settings()

	print("\n🎉 TODOS OS TESTES DE SEGURANÇA E VERSIONAMENTO PASSARAM COM SUCESSO!")
	print("========================================================\n")
	quit(0)

func _test_game_version_and_mismatch() -> void:
	print("  1. Verificando GAME_VERSION e rejeição com instrução de atualizar...")
	var net: NetworkManagerAutoload = NetworkManagerClass.new()
	root.add_child(net)

	# 1.1 Constante semver existe
	assert(NetworkManagerClass.GAME_VERSION != "", "GAME_VERSION deve existir e não ser vazia")
	var parts := NetworkManagerClass.GAME_VERSION.split(".")
	assert(parts.size() == 3, "GAME_VERSION deve seguir formato semver (X.Y.Z), obtido: %s" % NetworkManagerClass.GAME_VERSION)

	# 1.2 Handshake com versão incompatível deve ser recusado com mensagem clara
	var res := {"received": false, "ok": true, "msg": ""}

	net.auth_result.connect(func(ok: bool, msg: String, _chars: Array):
		res.received = true
		res.ok = ok
		res.msg = msg
	)

	# Simula envio de versão antiga pelo cliente
	net.send_auth_request("login", "TesterAntigo", "123456", "0.0.1")
	assert(res.received, "auth_result deve ser emitido")
	assert(not res.ok, "Login com versão diferente do servidor deve falhar")
	assert(res.msg.to_lower().contains("atualize o jogo"), "Mensagem de erro deve conter 'atualize o jogo', obtido: '%s'" % res.msg)

	net.queue_free()
	print("     ✓ GAME_VERSION semver validada e recusa explicativa confirmada")

func _test_rate_limiting_and_limits() -> void:
	print("  2. Verificando rate limit de login por IP e limites de conexão...")
	var net: NetworkManagerAutoload = NetworkManagerClass.new()
	root.add_child(net)

	# 2.1 Limites configurados
	assert(NetworkManagerClass.MAX_PLAYERS == 32, "Capacidade máxima deve ser de 32 jogadores")
	assert(NetworkManagerClass.MAX_CONNECTIONS_PER_IP == 3, "Limite de conexões simultâneas por IP deve ser 3")
	assert(NetworkManagerClass.MAX_LOGIN_ATTEMPTS_PER_MINUTE == 5, "Limite de tentativas de login por minuto deve ser 5")

	# 2.2 Teste de rate limit com 5 tentativas permitidas e 6ª bloqueada
	var test_ip := "203.0.113.42"
	for i in range(5):
		var allowed: bool = net._check_login_rate_limit(test_ip)
		assert(allowed, "Tentativa %d de 5 deve ser permitida" % (i + 1))

	var blocked: bool = net._check_login_rate_limit(test_ip)
	assert(not blocked, "6ª tentativa dentro do minuto deve ser bloqueada por rate limit")

	# IP diferente ainda deve ser permitido
	var other_ip := "198.51.100.77"
	assert(net._check_login_rate_limit(other_ip), "Outro IP não deve ser afetado pelo rate limit do primeiro")

	# 2.3 Contagem de conexões simultâneas
	net.peer_ips[10] = test_ip
	net.peer_ips[11] = test_ip
	net.peer_ips[12] = test_ip
	assert(net.count_active_connections_from_ip(test_ip) == 3, "Deve contar 3 conexões ativas para test_ip")
	assert(net.count_active_connections_from_ip(other_ip) == 0, "Deve contar 0 conexões ativas para other_ip")

	net.queue_free()
	print("     ✓ Rate limit de 5 req/min/IP e contagem de conexões simultâneas validados")

func _test_server_world_process_optimization() -> void:
	print("  3. Verificando eliminação de _process desnecessário em server_world...")
	var scene_res := load(DedicatedServerBootClass.SERVER_WORLD_SCENE) as PackedScene
	assert(scene_res != null, "Cena server_world.tscn deve ser carregável")

	var world: Node3D = scene_res.instantiate() as Node3D
	root.add_child(world)

	# 3.1 Sun (DayNightCycle)
	var sun: DayNightCycle = world.get_node_or_null("Sun") as DayNightCycle
	assert(sun != null, "Sun deve existir na server_world")
	assert(sun.use_timer_update, "Sun na server_world deve ter use_timer_update = true")
	assert(not sun.is_processing(), "Sun não deve rodar _process na server_world")
	assert(sun.get_node_or_null("SunUpdateTimer") != null, "Sun deve conter SunUpdateTimer ativo")

	# 3.2 TerrainChunkManager
	var chunks: TerrainChunkManager = world.get_node_or_null("TerrainChunkManager") as TerrainChunkManager
	assert(chunks != null, "TerrainChunkManager deve existir na server_world")
	assert(not chunks.is_processing(), "TerrainChunkManager não deve rodar _process")
	assert(chunks.get_node_or_null("ChunkUpdateTimer") != null, "TerrainChunkManager deve conter ChunkUpdateTimer")

	# 3.3 ServerPersistence
	var sp: ServerPersistenceAutoload = ServerPersistenceClass.new()
	root.add_child(sp)
	assert(not sp.is_processing(), "ServerPersistence não deve rodar _process a cada frame")
	assert(sp.get_node_or_null("AutosaveTimer") != null, "ServerPersistence deve conter AutosaveTimer")

	sp.queue_free()
	world.queue_free()
	print("     ✓ Nós da server_world usam Timers dedicados e não executam _process ocioso")

func _test_online_auth_modal_defaults_and_adv_toggle() -> void:
	print("  4. Verificando OnlineAuthModal com conexão padrão e gaveta avançada oculta...")
	var modal: OnlineAuthModal = OnlineAuthModalClass.new()
	modal.is_host_mode = false
	root.add_child(modal)

	# 4.1 Gaveta de servidor avançado deve começar oculta
	assert(modal._adv_box != null, "_adv_box deve existir no modo cliente")
	assert(not modal._adv_box.visible, "_adv_box deve iniciar oculta para o jogador comum")

	# 4.2 Valores padrão de conexão apontam para o servidor oficial
	assert(modal._adv_host_input.text == NetworkManagerClass.DEFAULT_HOST, "Host padrão deve ser %s" % NetworkManagerClass.DEFAULT_HOST)
	assert(modal._adv_host_input.text == "jogar.tarciso.dev", "Host padrão deve ser jogar.tarciso.dev")
	assert(modal._adv_port_input.text == str(NetworkManagerClass.DEFAULT_PORT), "Porta padrão deve ser 8787")

	# 4.3 Botão de alternância expande os campos para desenvolvedores
	assert(modal._adv_toggle_btn != null, "Botão _adv_toggle_btn deve existir")
	modal._adv_toggle_btn.pressed.emit()
	assert(modal._adv_box.visible, "Clicar no botão deve exibir os campos de servidor avançado")
	modal._adv_toggle_btn.pressed.emit()
	assert(not modal._adv_box.visible, "Clicar novamente deve ocultar a gaveta")

	modal.queue_free()
	print("     ✓ Conexão padrão jogar.tarciso.dev:8787 e gaveta avançada dev validadas")

func _test_dedicated_server_settings() -> void:
	print("  5. Verificando inicialização do DedicatedServerBoot e Low CPU Mode...")
	# Verifica que DedicatedServerBootAutoload define OS.low_processor_usage_mode = true
	var boot: DedicatedServerBootAutoload = DedicatedServerBootClass.new()
	root.add_child(boot)

	# Simula chamada de boot_server
	boot.boot_server(8787, false, 20, 20)
	assert(OS.low_processor_usage_mode == true, "OS.low_processor_usage_mode deve ser true no servidor")
	assert(Engine.max_fps == 20, "Engine.max_fps deve ser configurado para 20")
	assert(Engine.physics_ticks_per_second == 20, "Engine.physics_ticks_per_second deve ser configurado para 20")

	boot.queue_free()
	print("     ✓ DedicatedServerBoot ativa OS.low_processor_usage_mode e limites de loop")
