extends SceneTree

## Teste automatizado de Autenticação de Contas, Criação de Personagens e Conexão WebSocket/Cloudflare (B24).

const ServerPersistenceClass = preload("res://scripts/core/server_persistence.gd")
const NetworkManagerClass = preload("res://scripts/core/network_manager.gd")
const OnlineAuthModalClass = preload("res://scripts/ui/online_auth_modal.gd")

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
	_test_character_delete_and_stats()
	_test_remember_credentials()

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

func _test_character_delete_and_stats() -> void:
	print("  6. Verificando exclusão de personagem, formatação de tempo e dinheiro...")
	var sp = ServerPersistenceClass.new()
	root.add_child(sp)

	var user := "StatsTester2026"
	var pwd := "SenhaValida123!"
	var char_name := "Guerreira_Temp"
	var test_dna := {"skin_color": "ffe0b2", "hair_id": 1, "hair_color": "000000"}

	# Limpa antes do teste
	var acct_file := "%s/%s.json" % [ServerPersistenceClass.ACCOUNTS_DIR, user.to_lower()]
	var char_file := "%s/%s.json" % [ServerPersistenceClass.PLAYERS_DIR, char_name]
	for f in [acct_file, char_file]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f))

	# 1. Registra e cria personagem
	sp.register_account(user, pwd)
	var c_res := sp.create_character_for_account(user, char_name, test_dna)
	assert(c_res.get("success", false), "Criação deve ser bem sucedida")

	# 2. Verifica resumo de saldo e tempo inicial
	var summary_initial: Dictionary = sp.get_character_summary(char_name)
	assert(summary_initial.get("money") == 50, "Saldo inicial deve ser 50")
	assert(summary_initial.get("play_time") == 0.0, "Tempo inicial de jogo deve ser 0.0")

	# 3. Atualiza dados com dinheiro e tempo jogado
	sp.update_player_data(char_name, {"money": 350, "play_time": 3725.0})
	var summary_updated: Dictionary = sp.get_character_summary(char_name)
	assert(summary_updated.get("money") == 350, "Saldo atualizado deve ser 350")
	assert(absf(summary_updated.get("play_time") - 3725.0) < 0.1, "Tempo atualizado deve ser 3725.0s")

	# 4. Formatação de tempo em OnlineAuthModal
	assert(OnlineAuthModalClass.format_play_time(0.0) == "Recém-criado", "0s deve formatar como Recém-criado")
	assert(OnlineAuthModalClass.format_play_time(42.0) == "42 seg", "42s deve formatar como 42 seg")
	assert(OnlineAuthModalClass.format_play_time(180.0) == "3 min", "180s deve formatar como 3 min")
	assert(OnlineAuthModalClass.format_play_time(3725.0) == "1h 02min", "3725s deve formatar como 1h 02min")

	# 5. Login na conta retorna characters e characters_data
	var login_res := sp.login_account(user, pwd)
	var chars_data: Array = login_res.get("characters_data", [])
	assert(not chars_data.is_empty(), "Login deve retornar characters_data")
	assert(chars_data[0].get("money") == 350, "Saldo no login deve ser 350")

	# 6. Exclusão de personagem
	# Tentar excluir personagem que não pertence à conta deve falhar
	var del_wrong := sp.delete_character_for_account(user, "Personagem_Inexistente")
	assert(not del_wrong.get("success", false), "Exclusão de personagem inexistente deve falhar")

	# Excluir com sucesso
	var del_ok := sp.delete_character_for_account(user, char_name)
	assert(del_ok.get("success", false), "Exclusão do personagem deve ter sucesso")
	assert(not FileAccess.file_exists(char_file), "Arquivo de save do personagem deve ser deletado do disco")

	# Verifica se removeu da conta
	var login_after := sp.login_account(user, pwd)
	assert(login_after.get("characters", []).is_empty(), "Lista de personagens da conta deve estar vazia após exclusão")

	# Limpa
	if FileAccess.file_exists(acct_file):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(acct_file))
	sp.queue_free()
	print("     ✓ Exclusão de personagem, resumo com dinheiro e formatação de tempo validados com sucesso")

func _test_remember_credentials() -> void:
	print("  7. Verificando opção de 'Lembrar usuário e senha' no login...")
	# 7.1 Garante estado limpo antes do teste
	OnlineAuthModalClass.clear_saved_credentials()
	var creds_initial := OnlineAuthModalClass.load_saved_credentials()
	assert(not creds_initial.get("remember", false), "Inicialmente não deve ter credenciais salvas")

	# 7.2 Salva credenciais com remember = true
	OnlineAuthModalClass.save_credentials("HeroiDoVale", "SuperSenhaSecreta99!", true)
	var creds_saved := OnlineAuthModalClass.load_saved_credentials()
	assert(creds_saved.get("remember", false), "remember deve ser true")
	assert(creds_saved.get("username", "") == "HeroiDoVale", "Usuário recuperado deve ser HeroiDoVale")
	assert(creds_saved.get("password", "") == "SuperSenhaSecreta99!", "Senha recuperada deve corresponder à original")

	# 7.3 Instancia OnlineAuthModal e verifica preenchimento automático
	var modal: OnlineAuthModal = OnlineAuthModalClass.new()
	modal.is_host_mode = false
	root.add_child(modal)

	assert(modal._remember_check != null, "_remember_check deve existir")
	assert(modal._remember_check.button_pressed, "_remember_check deve iniciar marcado quando há credenciais salvas")
	assert(modal._user_input.text == "HeroiDoVale", "_user_input deve ser preenchido automaticamente")
	assert(modal._pass_input.text == "SuperSenhaSecreta99!", "_pass_input deve ser preenchido automaticamente")

	# 7.4 Desmarcar o checkbox limpa as credenciais salvas
	modal._remember_check.button_pressed = false
	var creds_after_untoggle := OnlineAuthModalClass.load_saved_credentials()
	assert(not creds_after_untoggle.get("remember", false), "Desmarcar _remember_check deve limpar as credenciais salvas")

	modal.queue_free()

	# 7.5 Limpeza final de teste
	OnlineAuthModalClass.clear_saved_credentials()
	print("     ✓ Salvar, carregar, auto-preenchimento e limpeza de credenciais validados com sucesso")
