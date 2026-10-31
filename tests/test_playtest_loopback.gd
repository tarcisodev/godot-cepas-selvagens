extends SceneTree

## Teste de rede de verdade (B41 fase 0): um servidor e dois clientes ENet em 127.0.0.1, no mesmo processo.
## Cada NetworkManager tem o próprio SceneMultiplayer (set_multiplayer por subárvore).
## Valida login, entrada no mundo com personagem próprio, posição repassada pelo servidor com o peer
## carimbado, e que cliente não consegue falar direto com outro cliente nem forjar perfil.

const ServerPersistenceClass = preload("res://scripts/core/server_persistence.gd")
const NetworkManagerClass = preload("res://scripts/core/network_manager.gd")
const LedgerServiceClass = preload("res://scripts/net/ledger_service.gd")

const PORT := 9891
const TIMEOUT_FRAMES := 600

var _started: bool = false
var _sp
var _srv
var _a
var _b

func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false

func _run() -> void:
	print("\n========================================================")
	print("🌐 TESTANDO REDE DE VERDADE: SERVIDOR + 2 CLIENTES (B41)")
	print("========================================================")

	# Avatares remotos precisam de uma cena atual
	var scene := Node3D.new()
	scene.name = "LoopbackWorld"
	root.add_child(scene)
	current_scene = scene

	_sp = root.get_node_or_null("/root/ServerPersistence")
	if _sp == null:
		_sp = ServerPersistenceClass.new()
		_sp.name = "ServerPersistence"
		root.add_child(_sp)
	_prepare_accounts()

	_srv = _make_manager("Srv")
	_a = _make_manager("CliA")
	_b = _make_manager("CliB")
	# No jogo o ServerPersistence acha o NetworkManager em /root; aqui o servidor está numa subárvore
	_sp._net = _srv
	_srv.peer_left.connect(_sp._on_peer_left)
	var ledger = root.get_node_or_null("/root/LedgerService")
	if ledger == null:
		ledger = LedgerServiceClass.new()
		ledger.name = "LedgerService"
		ledger.net = _srv
		root.add_child(ledger)
	else:
		ledger.net = _srv
	_srv.peer_left.connect(ledger.close_book)
	assert(_srv.start_server(PORT, 8, false) == OK, "Servidor deve abrir a porta %d" % PORT)
	assert(_a.start_client("127.0.0.1", PORT) == OK, "Cliente A deve iniciar")
	assert(_b.start_client("127.0.0.1", PORT) == OK, "Cliente B deve iniciar")
	assert(await _wait(func(): return _srv.multiplayer.get_peers().size() == 2), "Os dois clientes devem conectar")
	var id_a: int = _a.multiplayer.get_unique_id()
	var id_b: int = _b.multiplayer.get_unique_id()

	# 1. Login e entrada no mundo
	_a.send_auth_request("login", "LoopA", "SenhaSegura123!")
	_b.send_auth_request("login", "LoopB", "SenhaSegura123!")
	assert(await _wait(func(): return _a.current_account == "LoopA" and _b.current_account == "LoopB"), "Os dois devem logar")

	# A tenta entrar com o personagem de B: o servidor recusa
	var refused := {"got": false, "ok": true}
	_a.entered_world.connect(func(ok: bool, _d: Dictionary): refused["got"] = true; refused["ok"] = ok, CONNECT_ONE_SHOT)
	_a.send_enter_world_request("Loop_Beta")
	assert(await _wait(func(): return refused["got"]), "A deve receber resposta da entrada")
	assert(not refused["ok"], "A não entra com o personagem de B")
	assert(not _srv.players_info.has(id_a), "Servidor não coloca A no mundo com personagem alheio")
	print("     ✓ Entrada com personagem alheio recusada pela rede")

	_a.send_enter_world_request("Loop_Alfa")
	_b.send_enter_world_request("Loop_Beta")
	assert(await _wait(func(): return _a.players_info.has(id_b) and _b.players_info.has(id_a)), "Cada cliente deve receber o perfil do outro")
	assert(_b.players_info[id_a].get("name") == "Loop_Alfa", "B vê A com o nome que o servidor conhece")
	print("     ✓ Login, entrada no mundo e perfis trocados pelo servidor")

	# Livro do servidor: A recebe o retrato com o kit do explorador (fica pendente até existir Player)
	assert(await _wait(func(): return int(_a._pending_ledger.get("money", -1)) == ServerPersistenceClass.STARTER_MONEY), "A deve receber o retrato do livro com o dinheiro inicial")
	var srv_ledger = root.get_node_or_null("/root/LedgerService")
	if srv_ledger:
		assert(srv_ledger.has_book(id_a) and srv_ledger.has_book(id_b), "Servidor abre um livro por jogador no mundo")
		assert(srv_ledger.wallet_of(id_a).money == ServerPersistenceClass.STARTER_MONEY, "Servidor abre o livro de A")
	print("     ✓ Livro aberto no servidor e retrato entregue ao dono")

	# 2. Posição: A manda ao servidor, que repassa para B com o peer de A
	_a.rpc_id(1, "rpc_submit_transform", Vector3(12, 1, -7), 0.25, &"Walk")
	assert(await _wait(func(): return _b.remote_avatars.has(id_a) and (_b.remote_avatars[id_a] as Node3D).get_meta("target_pos", Vector3.ZERO) == Vector3(12, 1, -7)), "B deve ver A na posição enviada")
	assert(_srv.remote_avatars.has(id_a), "Servidor guarda o avatar de A (posição para o save)")
	print("     ✓ Posição repassada pelo servidor com o peer carimbado")

	# 3. Forjas: A tenta mover o avatar de B e trocar o próprio nome
	_a.rpc_id(1, "rpc_sync_transform", id_b, Vector3(999, 999, 999), 0.0, &"Idle")
	_a.rpc_id(1, "rpc_sync_profile", id_a, "Nome_Forjado", {})
	_a.rpc_id(id_b, "rpc_sync_transform", id_b, Vector3(999, 999, 999), 0.0, &"Idle")
	for i in range(30):
		await process_frame
	assert(_srv.players_info[id_a].get("name") == "Loop_Alfa", "Servidor ignora perfil forjado pelo cliente")
	assert(_b.players_info[id_a].get("name") == "Loop_Alfa", "B continua vendo o nome verdadeiro de A")
	var b_on_srv: Node3D = _srv.remote_avatars.get(id_b)
	assert(b_on_srv == null or b_on_srv.get_meta("target_pos", Vector3.ZERO) != Vector3(999, 999, 999), "A não move o avatar de B no servidor")
	print("     ✓ Cliente não fala direto com cliente nem forja perfil ou posição alheia")

	# 4. Saída: B fica sabendo e o servidor salva a posição de A
	_a.cleanup_peer()
	assert(await _wait(func(): return not _b.players_info.has(id_a) and not _b.remote_avatars.has(id_a)), "B deve ser avisado da saída de A")
	var saved: Array = _sp.load_player_data("Loop_Alfa").get("position", [])
	assert(saved.size() == 3, "Servidor deve salvar a posição de A ao sair")
	print("     ✓ Saída avisada aos outros e posição salva no servidor")

	_b.cleanup_peer()
	_srv.cleanup_peer()
	_cleanup_accounts()
	print("\n🎉 TODOS OS TESTES DE REDE DE VERDADE PASSARAM COM SUCESSO!")
	print("========================================================\n")
	quit(0)

func _make_manager(holder_name: String) -> Node:
	var holder := Node.new()
	holder.name = holder_name
	root.add_child(holder)
	set_multiplayer(SceneMultiplayer.new(), holder.get_path())
	var nm = NetworkManagerClass.new()
	nm.name = "NetworkManager"
	holder.add_child(nm)
	return nm

func _wait(cond: Callable) -> bool:
	for i in range(TIMEOUT_FRAMES):
		if cond.call():
			return true
		await process_frame
	return false

func _prepare_accounts() -> void:
	_cleanup_accounts()
	_sp.register_account("LoopA", "SenhaSegura123!")
	_sp.register_account("LoopB", "SenhaSegura123!")
	_sp.create_character_for_account("LoopA", "Loop_Alfa", {})
	_sp.create_character_for_account("LoopB", "Loop_Beta", {})

func _cleanup_accounts() -> void:
	var files := [
		"%s/loopa.json" % ServerPersistenceClass.ACCOUNTS_DIR,
		"%s/loopb.json" % ServerPersistenceClass.ACCOUNTS_DIR,
		"%s/Loop_Alfa.json" % ServerPersistenceClass.PLAYERS_DIR,
		"%s/Loop_Beta.json" % ServerPersistenceClass.PLAYERS_DIR,
	]
	for f in files:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
