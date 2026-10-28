extends SceneTree

## Teste automatizado de Autenticação de Contas, Criação de Personagens e Conexão WebSocket/Cloudflare (B24).

const ServerPersistenceClass = preload("res://scripts/core/server_persistence.gd")
const NetworkManagerClass = preload("res://scripts/core/network_manager.gd")

var _started: bool = false

func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false

func _run() -> void:
	print("\n========================================================")
	print("🛡️ TESTANDO AUTENTICAÇÃO, CONTAS E WEBSOCKET")
	print("========================================================")

	_test_account_registration_and_login()
	_test_character_creation_and_binding()
	_test_autosave_keeps_character_identity()
	_test_host_creates_character_on_own_server()
	_test_websocket_peer_init()

	print("\n🎉 TODOS OS TESTES DE AUTENTICAÇÃO E WEBSOCKET PASSARAM COM SUCESSO!")
	print("========================================================\n")
	quit(0)

func _test_account_registration_and_login() -> void:
	print("  1. Verificando registro e login de contas...")
	var sp = ServerPersistenceClass.new()
	root.add_child(sp)

	var user := "BetaTester2026"
	var pwd := "SenhaSegura123!"

	# Limpa antes do teste se houver resíduo
	var acct_file := "%s/%s.json" % [ServerPersistenceClass.ACCOUNTS_DIR, user.to_lower()]
	if FileAccess.file_exists(acct_file):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(acct_file))

	# 1. Registro
	var reg_res := sp.register_account(user, pwd)
	assert(reg_res.get("success", false), "Registro deve ser bem-sucedido")
	assert(FileAccess.file_exists(acct_file), "Arquivo de conta deve ser criado no disco")

	# Tentativa de duplicar o mesmo usuário
	var dup_res := sp.register_account(user, pwd)
	assert(not dup_res.get("success", false), "Não deve permitir conta duplicada com mesmo nome")

	# 2. Login com senha errada
	var wrong_res := sp.login_account(user, "SenhaErrada!")
	assert(not wrong_res.get("success", false), "Login com senha errada deve falhar")

	# 3. Login com senha correta
	var ok_res := sp.login_account(user, pwd)
	assert(ok_res.get("success", false), "Login com senha correta deve ter sucesso")
	assert(ok_res.get("characters", []).is_empty(), "Conta nova deve começar com lista vazia de personagens")

	sp.queue_free()
	print("     ✓ Registro, proteção contra duplicação e login validados com sucesso")

func _test_character_creation_and_binding() -> void:
	print("  2. Verificando criação de personagem vinculado à conta...")
	var sp = ServerPersistenceClass.new()
	root.add_child(sp)

	var user := "BetaTester2026"
	var char1 := "Valquíria_Beta"
	var char2 := "Cavaleiro_Beta"
	var test_dna := {"skin_color": "ffe0b2", "hair_id": 2, "hair_color": "3e2723"}

	# 1. Cria primeiro personagem
	var c1_res := sp.create_character_for_account(user, char1, test_dna)
	assert(c1_res.get("success", false), "Primeiro personagem deve ser criado com sucesso")
	assert(sp.has_player_save(char1), "Save do personagem deve existir")

	# Tentativa de criar outro personagem com mesmo nome no mundo
	var dup_char := sp.create_character_for_account(user, char1, test_dna)
	assert(not dup_char.get("success", false), "Não deve permitir personagem com nome já existente")

	# 2. Cria segundo personagem na mesma conta
	var c2_res := sp.create_character_for_account(user, char2, test_dna)
	assert(c2_res.get("success", false), "Segundo personagem deve ser criado")

	# 3. Faz login e verifica se ambos os personagens vêm na lista
	var login_res := sp.login_account(user, "SenhaSegura123!")
	var chars: Array = login_res.get("characters", [])
	assert(chars.has(char1) and chars.has(char2), "A conta deve listar todos os seus personagens vinculados")

	# Limpa dados do teste
	var acct_file := "%s/%s.json" % [ServerPersistenceClass.ACCOUNTS_DIR, user.to_lower()]
	var p1_file := "%s/%s.json" % [ServerPersistenceClass.PLAYERS_DIR, char1]
	var p2_file := "%s/%s.json" % [ServerPersistenceClass.PLAYERS_DIR, char2]
	for f in [acct_file, p1_file, p2_file]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f))

	sp.queue_free()
	print("     ✓ Criação de múltiplos personagens vinculados à conta validada com sucesso")

func _test_autosave_keeps_character_identity() -> void:
	print("  3. Verificando que o autosave não apaga DNA e conta do personagem...")
	var sp = ServerPersistenceClass.new()
	root.add_child(sp)

	var user := "AutosaveTester"
	var char_name := "Persistente_Beta"
	var test_dna := {"skin_color": "ffe0b2", "hair_id": 3}
	_cleanup_account(user, [char_name])
	sp.register_account(user, "SenhaSegura123!")
	var res: Dictionary = sp.create_character_for_account(user, char_name, test_dna)
	assert(res.get("success", false), "Personagem deve ser criado")

	# Autosave grava só posição/vida: o resto precisa sobreviver
	sp.update_player_data(char_name, {"position": [5.0, 1.0, 5.0], "health": 80.0})
	var data: Dictionary = sp.load_player_data(char_name)
	var saved_dna: Dictionary = data.get("dna", {})
	# JSON devolve números como float: compara campo a campo
	assert(saved_dna.get("skin_color", "") == "ffe0b2" and int(saved_dna.get("hair_id", -1)) == 3, "DNA deve continuar salvo após o autosave")
	assert(data.get("account", "") == user, "Conta deve continuar vinculada após o autosave")
	assert(float(data.get("health", 0.0)) == 80.0, "Estado novo deve ser gravado")

	_cleanup_account(user, [char_name])
	sp.queue_free()
	print("     ✓ Autosave mescla o estado sem perder DNA e conta")

func _test_host_creates_character_on_own_server() -> void:
	print("  4. Verificando criação de personagem pelo host do PC...")
	var sp = root.get_node_or_null("/root/ServerPersistence")
	var created_sp: bool = false
	if sp == null:
		sp = ServerPersistenceClass.new()
		sp.name = "ServerPersistence"
		root.add_child(sp)
		created_sp = true
	var net = root.get_node_or_null("/root/NetworkManager")
	var created_net: bool = false
	if net == null:
		net = NetworkManagerClass.new()
		root.add_child(net)
		created_net = true

	var user := "HostTester"
	var char_name := "Anfitriao_Beta"
	_cleanup_account(user, [char_name])
	assert(net.start_server(9878, 8, false) == OK, "Servidor do host deve iniciar")
	net.send_auth_request("register", user, "SenhaSegura123!")
	assert(net.current_account == user, "Host deve ficar autenticado na própria conta")

	# No host a resposta sai na mesma chamada: quem escuta precisa conectar antes
	var got := {"ok": false}
	net.character_created.connect(func(success: bool, _m: String, _c: Dictionary): got["ok"] = success, CONNECT_ONE_SHOT)
	net.send_create_character_request(char_name, {"hair_id": 1})
	assert(got["ok"], "Host deve receber character_created com sucesso")
	var chars: Array = sp.login_account(user, "SenhaSegura123!").get("characters", [])
	assert(chars.has(char_name), "Personagem do host deve ficar gravado na conta")

	# Teste de cliente recebendo rpc_response_auth
	net.current_account = ""
	net.rpc_response_auth(true, "Login remoto bem-sucedido", [], "ClientTester")
	assert(net.current_account == "ClientTester", "Cliente remoto deve gravar current_account ao receber rpc_response_auth")
	net.current_account = ""

	_cleanup_account(user, [char_name])
	net.current_account = ""
	net.cleanup_peer()
	net.setup_offline_host()
	if created_net:
		net.queue_free()
	if created_sp:
		sp.queue_free()
	print("     ✓ Host cria e persiste personagem no próprio servidor")

func _cleanup_account(user: String, char_names: Array) -> void:
	var files: Array = ["%s/%s.json" % [ServerPersistenceClass.ACCOUNTS_DIR, user.to_lower()]]
	for c in char_names:
		files.append("%s/%s.json" % [ServerPersistenceClass.PLAYERS_DIR, String(c).validate_filename()])
	for f in files:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f))

func _test_websocket_peer_init() -> void:
	print("  5. Verificando inicialização de WebSocketMultiplayerPeer para Cloudflare Tunnel...")
	var net = root.get_node_or_null("/root/NetworkManager")
	var created_net: bool = false
	if net == null:
		net = NetworkManagerClass.new()
		root.add_child(net)
		created_net = true

	# Inicia servidor WebSocket na porta temporária 9877
	var err: Error = net.start_server(9877, 8, true)
	assert(err == OK, "Servidor WebSocket deve inicializar com código OK")
	assert(net.peer is WebSocketMultiplayerPeer, "Peer ativo deve ser WebSocketMultiplayerPeer")
	assert(net.state == NetworkManagerAutoload.NetworkState.HOSTING_SERVER, "Estado deve ser HOSTING_SERVER")

	# Limpa
	net.cleanup_peer()
	net.setup_offline_host()
	if created_net:
		net.queue_free()
	print("     ✓ Servidor WebSocket (Cloudflare Tunnel) inicializado e liberado com sucesso")
