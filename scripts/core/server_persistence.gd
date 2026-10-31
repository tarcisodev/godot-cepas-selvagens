class_name ServerPersistenceAutoload
extends Node

## Módulo de Persistência do Servidor Autoritativo (B24).
## Salva e recupera o estado de jogadores e do mundo em sessões dedicadas / coop LAN
## no diretório user://server_saves/.

const BASE_SAVE_DIR: String = "user://server_saves"
const PLAYERS_DIR: String = "user://server_saves/players"
const ACCOUNTS_DIR: String = "user://server_saves/accounts"
const WORLD_FILE: String = "user://server_saves/world/world_state.json"
const AUTOSAVE_INTERVAL: float = 60.0
const GUILDS_FILE: String = "user://server_saves/world/guilds.json"
## Senhas (B41): PBKDF2-HMAC-SHA256 com salt aleatório por conta
const PASSWORD_ALGO: String = "pbkdf2_sha256"
const PASSWORD_ITERATIONS: int = 10000
const PASSWORD_MIN_LENGTH: int = 6
const PASSWORD_MAX_LENGTH: int = 128
const MAX_CHARACTERS_PER_ACCOUNT: int = 3
## Kit do explorador (B41): o servidor entrega na criação do personagem; o cliente não dá mais nada.
## 50 $S da carteira nova + 150 do kit; as 2 placas de carapaça são as que todo inventário novo traz.
const STARTER_MONEY: int = 200
const STARTER_MATERIALS: Array = [
	{"id": "placa_carapaca", "quality": 1, "traits": [], "amount": 2},
	{"id": "tocha", "quality": 1, "traits": [], "amount": 1},
	{"id": "vara_pesca", "quality": 1, "traits": [], "amount": 1},
	{"id": "laco_fibra", "quality": 1, "traits": [], "amount": 2},
	{"id": "pocao", "quality": 1, "traits": [], "amount": 2},
]
const _GuildSystem = preload("res://scripts/systems/guild_system.gd")

signal player_saved(player_name: String)
signal player_loaded(player_name: String)

var _autosave_timer: float = AUTOSAVE_INTERVAL
var _autosave_timer_node: Timer
var _net: Node

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_directories()
	_net = get_node_or_null("/root/NetworkManager")
	if _net != null:
		if _net.has_signal("peer_left"):
			_net.connect("peer_left", Callable(self, "_on_peer_left"))

	# Desativa _process contínuo e usa Timer a cada 60s
	set_process(false)
	_autosave_timer_node = Timer.new()
	_autosave_timer_node.name = "AutosaveTimer"
	_autosave_timer_node.wait_time = AUTOSAVE_INTERVAL
	_autosave_timer_node.autostart = true
	_autosave_timer_node.timeout.connect(autosave_all_active_players)
	add_child(_autosave_timer_node)

func _ensure_directories() -> void:
	var global_base := ProjectSettings.globalize_path(BASE_SAVE_DIR)
	var global_players := ProjectSettings.globalize_path(PLAYERS_DIR)
	var global_accounts := ProjectSettings.globalize_path(ACCOUNTS_DIR)
	var global_world := ProjectSettings.globalize_path("user://server_saves/world")
	DirAccess.make_dir_recursive_absolute(global_base)
	DirAccess.make_dir_recursive_absolute(global_players)
	DirAccess.make_dir_recursive_absolute(global_accounts)
	DirAccess.make_dir_recursive_absolute(global_world)

func _process(_delta: float) -> void:
	autosave_all_active_players()

## Salva os dados de um jogador pelo nome
func save_player_data(player_name: String, data: Dictionary) -> bool:
	if player_name.strip_edges().is_empty():
		return false
	_ensure_directories()
	var safe_name := player_name.validate_filename()
	var file_path := "%s/%s.json" % [PLAYERS_DIR, safe_name]
	var payload := {
		"version": 1,
		"saved_at": Time.get_datetime_string_from_system(),
		"name": player_name,
		"data": data
	}
	if not write_json_atomic(file_path, payload):
		return false
	player_saved.emit(player_name)
	return true

## Grava em "<arquivo>.tmp" e só depois troca pelo arquivo final: uma queda no meio não corrompe o save
static func write_json_atomic(file_path: String, data: Variant) -> bool:
	var tmp_path := file_path + ".tmp"
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		push_error("[ServerPersistence] Falha ao abrir arquivo para escrita: %s (erro: %d)" % [tmp_path, FileAccess.get_open_error()])
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	var err := DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp_path), ProjectSettings.globalize_path(file_path))
	if err != OK:
		push_error("[ServerPersistence] Falha ao trocar %s pelo arquivo final (erro: %d)" % [tmp_path, err])
		return false
	return true

## Carrega os dados de um jogador pelo nome
func load_player_data(player_name: String) -> Dictionary:
	var safe_name := player_name.validate_filename()
	var file_path := "%s/%s.json" % [PLAYERS_DIR, safe_name]
	if not FileAccess.file_exists(file_path):
		return {}
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return {}
	var content := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(content) != OK:
		push_error("[ServerPersistence] Erro de parse JSON em %s" % file_path)
		return {}
	var parsed: Variant = json.data
	if parsed is Dictionary and parsed.has("data"):
		player_loaded.emit(player_name)
		return parsed["data"] as Dictionary
	return {}

func has_player_save(player_name: String) -> bool:
	var safe_name := player_name.validate_filename()
	return FileAccess.file_exists("%s/%s.json" % [PLAYERS_DIR, safe_name])

## Serializa o estado atual de um nó Player
static func serialize_player(player: Node) -> Dictionary:
	if player == null:
		return {}
	var dict: Dictionary = {
		"position": [player.global_position.x, player.global_position.y, player.global_position.z],
		"rotation_y": player.rotation.y,
	}

	# Pools de vida/postura
	var pools = player.get("pools")
	if pools:
		dict["health"] = pools.get("current_health")
		dict["posture"] = pools.get("current_posture")

	# Aparência: sem ela o personagem volta com o DNA padrão no próximo login
	var visual = player.get("character_visual")
	if visual and visual.get("dna"):
		dict["dna"] = visual.dna.to_dict()

	# Carteira
	var wallet = player.get("wallet")
	if wallet and "money" in wallet:
		dict["money"] = int(wallet.money)
	if "play_time" in player:
		dict["play_time"] = float(player.get("play_time"))

	# Inventário (mesmas chaves do save local e do livro do servidor: materials e gear)
	var inv = player.get("inventory")
	if inv and inv.has_method("stacks_to_save"):
		dict["materials"] = inv.stacks_to_save()
		dict["gear"] = inv.items_to_save()

	# Diário do Caçador (GDD-19): o servidor é quem escreve
	var diary = player.get_node_or_null("DiaryComponent")
	if diary:
		dict["diary"] = diary.to_dict()

	# Montaria atual
	var mount = player.get("mounted_on")
	if mount != null:
		dict["is_mounted"] = true
		dict["mount_name"] = mount.get("display_name")
	else:
		dict["is_mounted"] = false

	return dict

## Desserializa e aplica o estado salvo em um nó Player
static func apply_player_data(player: Node, data: Dictionary) -> void:
	if player == null or data.is_empty():
		return
	if data.has("position"):
		var p: Array = data["position"]
		if p.size() >= 3:
			player.global_position = Vector3(p[0], p[1], p[2])
	if data.has("rotation_y"):
		player.rotation.y = float(data["rotation_y"])

	if data.has("health"):
		var pools = player.get("pools")
		if pools and "current_health" in pools:
			pools.current_health = float(data["health"])

	if data.has("money"):
		var wallet = player.get("wallet")
		if wallet and wallet.has_method("set_money"):
			wallet.set_money(int(data["money"]))
	if data.has("play_time") and "play_time" in player:
		player.set("play_time", float(data["play_time"]))

	var inv = player.get("inventory")
	if inv and data.get("materials") is Array:
		inv.load_from_save(data["materials"])
	if inv and data.get("gear") is Dictionary:
		inv.load_items(data["gear"])

	if data.has("diary"):
		var diary = player.get_node_or_null("DiaryComponent")
		if diary:
			diary.from_dict(data["diary"])

func autosave_all_active_players() -> void:
	var tree := get_tree()
	if tree == null:
		return
	if _net != null and _net.get("state") == _net.NetworkState.HOSTING_SERVER:
		save_guilds()
	for player in tree.get_nodes_in_group("player"):
		var p_name: String = player.get("character_name") if "character_name" in player else ""
		if p_name.is_empty() and player.has_meta("player_name"):
			p_name = player.get_meta("player_name")
		if not p_name.is_empty():
			update_player_data(p_name, serialize_player(player))
	# Jogadores online: no servidor, cada peer que entrou no mundo tem um avatar com a posição dele
	if _net != null and _net.get("state") == _net.NetworkState.HOSTING_SERVER:
		var remotes: Dictionary = _net.get("remote_avatars")
		var infos: Dictionary = _net.get("players_info")
		for peer_id in infos:
			var avatar: Node = remotes.get(peer_id)
			var online_name: String = infos[peer_id].get("name", "")
			if avatar != null and is_instance_valid(avatar) and not online_name.is_empty():
				update_player_data(online_name, serialize_player(avatar))

## Mescla o estado novo no save existente: preserva nome, conta e DNA gravados na criação
func update_player_data(player_name: String, data: Dictionary) -> bool:
	var merged := load_player_data(player_name)
	merged.merge(data, true)
	return save_player_data(player_name, merged)

func _on_peer_left(peer_id: int) -> void:
	if _net == null:
		return
	var players_info: Dictionary = _net.get("players_info") if "players_info" in _net else {}
	if players_info.has(peer_id):
		var info: Dictionary = players_info[peer_id]
		var p_name: String = info.get("name", "")
		if not p_name.is_empty():
			var remotes: Dictionary = _net.get("remote_avatars") if "remote_avatars" in _net else {}
			var avatar: Node = remotes.get(peer_id)
			if avatar != null:
				update_player_data(p_name, serialize_player(avatar))
				print("[ServerPersistence] Progresso salvo para '%s' ao desconectar." % p_name)

## Hash antigo (B24): SHA-256 único com salt fixo do jogo. Só serve para migrar contas no próximo login.
static func hash_password(password: String, username: String) -> String:
	return (password + ":" + username.strip_edges().to_lower() + ":cepas_selvagens_beta_2026").sha256_text()

## PBKDF2-HMAC-SHA256 (RFC 8018), um bloco de 32 bytes
static func pbkdf2_sha256(password: String, salt: PackedByteArray, iterations: int) -> PackedByteArray:
	var crypto := Crypto.new()
	var key := password.to_utf8_buffer()
	var first := salt.duplicate()
	first.append_array(PackedByteArray([0, 0, 0, 1]))
	var u := crypto.hmac_digest(HashingContext.HASH_SHA256, key, first)
	var out := u.duplicate()
	for _i in range(iterations - 1):
		u = crypto.hmac_digest(HashingContext.HASH_SHA256, key, u)
		for j in range(out.size()):
			out[j] = out[j] ^ u[j]
	return out

## Campos de senha da conta: salt aleatório por conta e hash PBKDF2
static func make_password_fields(password: String) -> Dictionary:
	var salt := Crypto.new().generate_random_bytes(16)
	return {
		"password_algo": PASSWORD_ALGO,
		"password_iterations": PASSWORD_ITERATIONS,
		"password_salt": salt.hex_encode(),
		"password_hash": pbkdf2_sha256(password, salt, PASSWORD_ITERATIONS).hex_encode()
	}

## Confere a senha contra os campos da conta (PBKDF2 ou o hash antigo). Nunca aceita hash pronto vindo do cliente.
static func password_matches(data: Dictionary, password: String, username: String) -> bool:
	var expected: String = data.get("password_hash", "")
	if expected.is_empty():
		return false
	if data.get("password_algo", "") == PASSWORD_ALGO:
		var salt := String(data.get("password_salt", "")).hex_decode()
		var iterations := int(data.get("password_iterations", PASSWORD_ITERATIONS))
		return _same_text(expected, pbkdf2_sha256(password, salt, iterations).hex_encode())
	return _same_text(expected, hash_password(password, username))

## Comparação em tempo constante (não vaza quantos caracteres batem)
static func _same_text(a: String, b: String) -> bool:
	if a.length() != b.length():
		return false
	var diff := 0
	for i in range(a.length()):
		diff |= a.unicode_at(i) ^ b.unicode_at(i)
	return diff == 0

func _account_path(username: String) -> String:
	return "%s/%s.json" % [ACCOUNTS_DIR, username.strip_edges().validate_filename().to_lower()]

## Lê o arquivo da conta ({} se não existir ou estiver corrompido)
func _read_account(username: String) -> Dictionary:
	var path := _account_path(username)
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}

## O personagem está na lista da conta? (entrar no mundo só com personagem próprio)
func account_owns_character(username: String, char_name: String) -> bool:
	if username.strip_edges().is_empty():
		return false
	var chars: Array = _read_account(username).get("characters", [])
	return chars.has(char_name.strip_edges())

## Registra uma nova conta no servidor
func register_account(username: String, password: String) -> Dictionary:
	var clean_user := username.strip_edges()
	if clean_user.length() < 3 or clean_user.length() > 24:
		return {"success": false, "message": "O nome de usuário deve ter entre 3 e 24 caracteres."}
	if password.length() < PASSWORD_MIN_LENGTH or password.length() > PASSWORD_MAX_LENGTH:
		return {"success": false, "message": "A senha deve ter entre %d e %d caracteres." % [PASSWORD_MIN_LENGTH, PASSWORD_MAX_LENGTH]}
	_ensure_directories()
	var file_path := _account_path(clean_user)
	if FileAccess.file_exists(file_path):
		return {"success": false, "message": "Este nome de usuário já está em uso."}

	var payload := {
		"username": clean_user,
		"created_at": Time.get_datetime_string_from_system(),
		"characters": []
	}
	payload.merge(make_password_fields(password))
	if not write_json_atomic(file_path, payload):
		return {"success": false, "message": "Erro ao criar arquivo de conta no servidor."}
	return {"success": true, "message": "Conta criada com sucesso!", "characters": []}

## Autentica uma conta existente
func login_account(username: String, password: String) -> Dictionary:
	var clean_user := username.strip_edges()
	var file_path := _account_path(clean_user)
	if not FileAccess.file_exists(file_path):
		return {"success": false, "message": "Conta não encontrada."}
	var data := _read_account(clean_user)
	if data.is_empty():
		return {"success": false, "message": "Dados de conta corrompidos."}
	if password.length() > PASSWORD_MAX_LENGTH or not password_matches(data, password, clean_user):
		return {"success": false, "message": "Senha incorreta."}

	# Conta do hash antigo: migra para PBKDF2 agora que a senha foi conferida
	if data.get("password_algo", "") != PASSWORD_ALGO:
		data.merge(make_password_fields(password), true)
		write_json_atomic(file_path, data)

	var chars: Array = data.get("characters", [])
	var chars_data: Array = []
	for cname in chars:
		chars_data.append(get_character_summary(str(cname)))
	return {"success": true, "message": "Login efetuado com sucesso!", "characters": chars, "characters_data": chars_data}

## Retorna o resumo do personagem (nome, saldo, tempo jogado) para telas de seleção
func get_character_summary(char_name: String) -> Dictionary:
	var p_data := load_player_data(char_name)
	return {
		"name": char_name,
		"money": int(p_data.get("money", 50)),
		"play_time": float(p_data.get("play_time", 0.0))
	}

## Vincula um personagem à conta
func create_character_for_account(username: String, char_name: String, dna_dict: Dictionary) -> Dictionary:
	var clean_char := char_name.strip_edges()
	if clean_char.length() < 2 or clean_char.length() > 20:
		return {"success": false, "message": "Nome do personagem inválido (2 a 20 caracteres)."}

	var clean_user := username.strip_edges()
	var acct_path := _account_path(clean_user)
	if not FileAccess.file_exists(acct_path):
		return {"success": false, "message": "Conta inexistente."}
	var acct_data := _read_account(clean_user)
	var char_list: Array = acct_data.get("characters", [])
	if char_list.size() >= MAX_CHARACTERS_PER_ACCOUNT:
		return {"success": false, "message": "Limite de %d personagens por conta." % MAX_CHARACTERS_PER_ACCOUNT}

	if has_player_save(clean_char):
		return {"success": false, "message": "Já existe um personagem com este nome no mundo."}

	var initial_player_data := {
		"name": clean_char,
		"account": clean_user,
		"position": [0.0, 1.0, 0.0],
		"rotation_y": 0.0,
		"health": 100.0,
		"money": STARTER_MONEY,
		"materials": STARTER_MATERIALS.duplicate(true),
		"play_time": 0.0,
		"dna": dna_dict
	}
	save_player_data(clean_char, initial_player_data)

	if not char_list.has(clean_char):
		char_list.append(clean_char)
		acct_data["characters"] = char_list
		write_json_atomic(acct_path, acct_data)

	return {"success": true, "message": "Personagem criado com sucesso!", "character": initial_player_data}

## Remove o vínculo do personagem da conta e apaga o save do disco
func delete_character_for_account(username: String, char_name: String) -> Dictionary:
	var clean_char := char_name.strip_edges()
	var clean_user := username.strip_edges()
	var acct_path := _account_path(clean_user)
	if not FileAccess.file_exists(acct_path):
		return {"success": false, "message": "Conta inexistente."}
	var acct_data := _read_account(clean_user)
	if acct_data.is_empty():
		return {"success": false, "message": "Dados de conta corrompidos."}

	var chars: Array = acct_data.get("characters", [])
	if not chars.has(clean_char):
		return {"success": false, "message": "Personagem não pertence a esta conta."}

	chars.erase(clean_char)
	acct_data["characters"] = chars
	write_json_atomic(acct_path, acct_data)

	# Exclui o arquivo de save do jogador
	var safe_char := clean_char.validate_filename()
	var p_path := "%s/%s.json" % [PLAYERS_DIR, safe_char]
	if FileAccess.file_exists(p_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p_path))

	return {
		"success": true,
		"message": "Personagem '%s' excluído com sucesso." % clean_char,
		"characters": chars
	}

## Guildas e o Livro do Totem de cada uma (GDD-15, GDD-19 §7): ficam no mundo, não no jogador
func save_guilds(path: String = GUILDS_FILE) -> bool:
	_ensure_directories()
	return write_json_atomic(path, {"version": 1, "guilds": _GuildSystem.get_instance().to_array()})

func load_guilds(path: String = GUILDS_FILE) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary) or not (parsed.get("guilds") is Array):
		return false
	_GuildSystem.get_instance().load_from_array(parsed["guilds"])
	return true
