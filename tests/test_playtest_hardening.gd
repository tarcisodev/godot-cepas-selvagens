extends SceneTree

## Teste automatizado da blindagem do playtest (B41 fase 0).
## Valida senha com PBKDF2 e salt por conta, migração do hash antigo, posse do personagem ao entrar no mundo,
## posição e perfil carimbados pelo servidor, teto de mensagens, login duplicado, limite de personagens,
## salvamento ao desconectar e gravação atômica dos saves.

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
	print("🛡️ TESTANDO A BLINDAGEM DO PLAYTEST (B41 FASE 0)")
	print("========================================================")

	_test_pbkdf2_vectors()
	_test_salted_passwords_and_no_pass_the_hash()
	_test_legacy_hash_migrates_on_login()
	_test_character_limit_and_ownership()
	_test_enter_world_only_with_own_character()
	_test_sync_stamped_by_server()
	_test_message_rate_limit()
	_test_duplicate_login_drops_old_session()
	_test_disconnect_saves_before_cleanup()
	_test_atomic_json_write()

	print("\n🎉 TODOS OS TESTES DA BLINDAGEM DO PLAYTEST PASSARAM COM SUCESSO!")
	print("========================================================\n")
	quit(0)

func _cleanup_account(user: String, chars: Array) -> void:
	var files := ["%s/%s.json" % [ServerPersistenceClass.ACCOUNTS_DIR, user.to_lower()]]
	for c in chars:
		files.append("%s/%s.json" % [ServerPersistenceClass.PLAYERS_DIR, c])
	for f in files:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f))

## ServerPersistence e NetworkManager nos caminhos que o jogo usa (/root/...)
func _make_services() -> Array:
	var sp = root.get_node_or_null("/root/ServerPersistence")
	if sp == null:
		sp = ServerPersistenceClass.new()
		sp.name = "ServerPersistence"
		root.add_child(sp)
	var net = NetworkManagerClass.new()
	root.add_child(net)
	return [sp, net]

func _test_pbkdf2_vectors() -> void:
	print("  1. Verificando PBKDF2-HMAC-SHA256 com vetores conhecidos (password/salt)...")
	var salt := "salt".to_utf8_buffer()
	assert(ServerPersistenceClass.pbkdf2_sha256("password", salt, 1).hex_encode() == "120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b", "PBKDF2 c=1 deve bater com o vetor")
	assert(ServerPersistenceClass.pbkdf2_sha256("password", salt, 2).hex_encode() == "ae4d0c95af6b46d32d0adff928f06dd02a303f8ef3c251dfd6e2d85a95474c43", "PBKDF2 c=2 deve bater com o vetor")
	print("     ✓ PBKDF2 confere com os vetores conhecidos")

func _test_salted_passwords_and_no_pass_the_hash() -> void:
	print("  2. Verificando salt por conta e recusa de hash pronto...")
	var sp = ServerPersistenceClass.new()
	root.add_child(sp)
	var users := ["SaltTesterA", "SaltTesterB"]
	for u in users:
		_cleanup_account(u, [])
		assert(sp.register_account(u, "MesmaSenha123").get("success", false), "Registro de %s deve funcionar" % u)

	var a: Dictionary = sp._read_account(users[0])
	var b: Dictionary = sp._read_account(users[1])
	assert(a.get("password_algo") == ServerPersistenceClass.PASSWORD_ALGO, "Conta nova deve usar PBKDF2")
	assert(a.get("password_salt") != b.get("password_salt"), "Cada conta deve ter o próprio salt")
	assert(a.get("password_hash") != b.get("password_hash"), "Mesma senha em contas diferentes deve gerar hashes diferentes")

	assert(sp.login_account(users[0], "MesmaSenha123").get("success", false), "Senha certa deve entrar")
	assert(not sp.login_account(users[0], "SenhaErrada99").get("success", false), "Senha errada deve falhar")
	# Quem roubou o arquivo da conta não entra mandando o hash no lugar da senha
	assert(not sp.login_account(users[0], String(a.get("password_hash"))).get("success", false), "Hash pronto não pode servir de senha")
	assert(not sp.register_account("SenhaCurta", "123").get("success", false), "Senha curta demais deve ser recusada")

	for u in users:
		_cleanup_account(u, [])
	sp.queue_free()
	print("     ✓ Salt aleatório por conta e sem pass-the-hash")

func _test_legacy_hash_migrates_on_login() -> void:
	print("  3. Verificando migração do hash antigo no login...")
	var sp = ServerPersistenceClass.new()
	root.add_child(sp)
	var user := "LegadoTester"
	_cleanup_account(user, [])
	sp._ensure_directories()
	ServerPersistenceClass.write_json_atomic(sp._account_path(user), {
		"username": user,
		"password_hash": ServerPersistenceClass.hash_password("SenhaAntiga1", user),
		"characters": []
	})
	assert(not sp.login_account(user, "Errada000").get("success", false), "Senha errada não migra nem entra")
	assert(sp._read_account(user).get("password_algo", "") == "", "Conta não deve migrar com senha errada")
	assert(sp.login_account(user, "SenhaAntiga1").get("success", false), "Senha certa no hash antigo deve entrar")
	var migrated: Dictionary = sp._read_account(user)
	assert(migrated.get("password_algo") == ServerPersistenceClass.PASSWORD_ALGO, "Conta deve migrar para PBKDF2 após o login")
	assert(sp.login_account(user, "SenhaAntiga1").get("success", false), "Depois de migrar a mesma senha continua entrando")

	_cleanup_account(user, [])
	sp.queue_free()
	print("     ✓ Hash antigo migra para PBKDF2 no primeiro login certo")

func _test_character_limit_and_ownership() -> void:
	print("  4. Verificando limite de personagens e posse do personagem...")
	var sp = ServerPersistenceClass.new()
	root.add_child(sp)
	var user := "LimiteTester"
	var names := ["Limite_Um", "Limite_Dois", "Limite_Tres", "Limite_Quatro"]
	_cleanup_account(user, names)
	sp.register_account(user, "SenhaSegura123!")
	for i in range(ServerPersistenceClass.MAX_CHARACTERS_PER_ACCOUNT):
		assert(sp.create_character_for_account(user, names[i], {}).get("success", false), "Personagem %d deve ser criado" % (i + 1))
	assert(not sp.create_character_for_account(user, names[3], {}).get("success", false), "Passar do limite de personagens deve falhar")
	assert(sp.account_owns_character(user, names[0]), "A conta é dona do próprio personagem")
	assert(sp.account_owns_character(user.to_upper(), names[0]), "Nome da conta não diferencia maiúsculas")
	assert(not sp.account_owns_character(user, "Personagem_Alheio"), "Personagem fora da lista não é da conta")
	assert(not sp.account_owns_character("", names[0]), "Sem conta não há posse")

	_cleanup_account(user, names)
	sp.queue_free()
	print("     ✓ Limite de %d personagens e posse por conta" % ServerPersistenceClass.MAX_CHARACTERS_PER_ACCOUNT)

func _test_enter_world_only_with_own_character() -> void:
	print("  5. Verificando entrada no mundo só com personagem da própria conta...")
	var services := _make_services()
	var sp = services[0]
	var net = services[1]
	var owner_user := "DonoTester"
	var thief_user := "LadraoTester"
	var char_name := "Personagem_Do_Dono"
	_cleanup_account(owner_user, [char_name])
	_cleanup_account(thief_user, [])
	sp.register_account(owner_user, "SenhaSegura123!")
	sp.register_account(thief_user, "SenhaSegura123!")
	sp.create_character_for_account(owner_user, char_name, {"hair_id": 2})

	net.peer_accounts[21] = owner_user
	net.peer_accounts[22] = thief_user
	assert(not net.handle_enter_world(23, char_name).get("success", false), "Peer sem login não entra")
	assert(not net.handle_enter_world(22, char_name).get("success", false), "Outra conta não entra com o personagem do dono")
	assert(not net.players_info.has(22), "Tentativa recusada não coloca o peer no mundo")
	var ok: Dictionary = net.handle_enter_world(21, char_name)
	assert(ok.get("success", false), "Dono entra com o próprio personagem")
	assert(net.players_info[21].get("name") == char_name and net.players_info[21].get("account") == owner_user, "Servidor registra nome e conta do peer")

	_cleanup_account(owner_user, [char_name])
	_cleanup_account(thief_user, [])
	net.queue_free()
	print("     ✓ Personagem alheio é recusado na entrada do mundo")

func _test_sync_stamped_by_server() -> void:
	print("  6. Verificando posição e perfil carimbados pelo servidor...")
	var net = NetworkManagerClass.new()
	root.add_child(net)
	assert(not net.has_method("request_combat_hit"), "RPC de combate aberta deve ter sido removida")
	assert(not net.has_method("sync_combat_result"), "Resultado de combate sem RPC de pedido também sai")

	# Peer que não entrou no mundo não move avatar nem troca perfil
	assert(not net.handle_submit_transform(31, Vector3(1, 2, 3), 0.0, &"Idle"), "Posição de peer fora do mundo é ignorada")
	assert(not net.handle_submit_profile(31, {"hair_id": 1}), "Perfil de peer fora do mundo é ignorado")

	net.players_info[31] = {"name": "Nome_Do_Servidor", "dna": {}, "account": "conta"}
	assert(net.handle_submit_transform(31, Vector3(1, 2, 3), 0.5, &"Walk"), "Posição de peer no mundo é aceita")
	assert(not net.handle_submit_transform(31, Vector3(NAN, 0, 0), 0.0, &"Idle"), "Posição inválida é recusada")
	assert(not net.handle_submit_transform(31, Vector3.ZERO, INF, &"Idle"), "Rotação inválida é recusada")
	assert(not net.handle_submit_transform(31, Vector3.ZERO, 0.0, StringName("x".repeat(200))), "Nome de animação gigante é recusado")

	assert(net.handle_submit_profile(31, {"hair_id": 4}), "DNA pequeno é aceito")
	assert(net.players_info[31].get("name") == "Nome_Do_Servidor", "O cliente não troca o próprio nome pelo perfil")
	assert(int(net.players_info[31]["dna"].get("hair_id", 0)) == 4, "DNA novo fica guardado no servidor")
	var huge := {"blob": "x".repeat(NetworkManagerClass.MAX_DNA_BYTES)}
	assert(not net.handle_submit_profile(31, huge), "DNA acima do limite é recusado")

	net.queue_free()
	print("     ✓ Só quem está no mundo sincroniza, com nome do servidor e dados validados")

func _test_message_rate_limit() -> void:
	print("  7. Verificando teto de mensagens por peer...")
	var net = NetworkManagerClass.new()
	root.add_child(net)
	for i in range(NetworkManagerClass.MAX_TRANSFORMS_PER_SECOND):
		assert(net._allow_message(41, &"transform"), "Posição %d dentro do teto deve passar" % (i + 1))
	assert(not net._allow_message(41, &"transform"), "Posição acima do teto no mesmo segundo é descartada")
	assert(net._allow_message(42, &"transform"), "Outro peer tem o próprio teto")
	for i in range(NetworkManagerClass.MAX_REQUESTS_PER_WINDOW):
		assert(net._allow_message(41, &"request"), "Pedido %d dentro do teto deve passar" % (i + 1))
	assert(not net._allow_message(41, &"request"), "Pedido acima do teto na janela é descartado")
	net._clear_message_windows(41)
	assert(net._allow_message(41, &"request"), "Janela zera quando o peer sai")
	net.queue_free()
	print("     ✓ Teto de %d posições/s e %d pedidos por janela" % [NetworkManagerClass.MAX_TRANSFORMS_PER_SECOND, NetworkManagerClass.MAX_REQUESTS_PER_WINDOW])

func _test_duplicate_login_drops_old_session() -> void:
	print("  8. Verificando login duplicado derrubando a sessão antiga...")
	var net = NetworkManagerClass.new()
	root.add_child(net)
	net.peer_accounts[51] = "ContaDupla"
	net.players_info[51] = {"name": "Personagem_Duplo", "dna": {}, "account": "ContaDupla"}
	net.bind_account(52, "contadupla")
	assert(not net.peer_accounts.has(51), "Sessão antiga da mesma conta deve cair")
	assert(not net.players_info.has(51), "Peer antigo sai do mundo")
	assert(net.peer_accounts.get(52) == "contadupla", "Peer novo fica com a conta")
	net.bind_account(53, "OutraConta")
	assert(net.peer_accounts.has(52), "Conta diferente não derruba ninguém")
	net.queue_free()
	print("     ✓ Uma sessão por conta")

func _test_disconnect_saves_before_cleanup() -> void:
	print("  9. Verificando que a saída avisa antes de apagar o jogador...")
	var net = NetworkManagerClass.new()
	root.add_child(net)
	net.players_info[61] = {"name": "Saindo", "dna": {}, "account": "conta"}
	var seen := {"had_info": false}
	net.peer_left.connect(func(id: int): seen["had_info"] = net.players_info.has(id))
	net._on_peer_disconnected(61)
	assert(seen["had_info"], "peer_left deve sair com players_info ainda preenchido (o ServerPersistence salva nesse momento)")
	assert(not net.players_info.has(61), "Depois do aviso o jogador sai de players_info")
	net.queue_free()
	print("     ✓ Progresso pode ser salvo antes da limpeza")

func _test_atomic_json_write() -> void:
	print(" 10. Verificando gravação atômica dos saves...")
	var sp = ServerPersistenceClass.new()
	root.add_child(sp)
	sp._ensure_directories()
	var path := "%s/atomic_test.json" % ServerPersistenceClass.PLAYERS_DIR
	assert(ServerPersistenceClass.write_json_atomic(path, {"v": 1}), "Primeira gravação deve funcionar")
	assert(ServerPersistenceClass.write_json_atomic(path, {"v": 2}), "Gravar por cima de um arquivo existente deve funcionar")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(parsed is Dictionary and int(parsed.get("v", 0)) == 2, "Arquivo final deve ter o conteúdo novo")
	assert(not FileAccess.file_exists(path + ".tmp"), "Arquivo temporário não deve sobrar")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	sp.queue_free()
	print("     ✓ Save gravado em .tmp e trocado pelo final")
