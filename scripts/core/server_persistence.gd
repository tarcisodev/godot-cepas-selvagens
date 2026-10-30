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
	var json_str := JSON.stringify(payload, "\t")
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		push_error("[ServerPersistence] Falha ao abrir arquivo para escrita: %s (erro: %d)" % [file_path, FileAccess.get_open_error()])
		return false
	file.store_string(json_str)
	file.close()
	player_saved.emit(player_name)
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

	# Inventário
	var inv = player.get("inventory")
	if inv and inv.has_method("serialize"):
		dict["inventory"] = inv.serialize()

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

	if data.has("inventory"):
		var inv = player.get("inventory")
		if inv and inv.has_method("deserialize"):
			inv.deserialize(data["inventory"])

	if data.has("diary"):
		var diary = player.get_node_or_null("DiaryComponent")
		if diary:
			diary.from_dict(data["diary"])

func autosave_all_active_players() -> void:
	var tree := get_tree()
	if tree == null:
		return
	for player in tree.get_nodes_in_group("player"):
		var p_name: String = player.get("character_name") if "character_name" in player else ""
		if p_name.is_empty() and player.has_meta("player_name"):
			p_name = player.get_meta("player_name")
		if not p_name.is_empty():
			update_player_data(p_name, serialize_player(player))

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

## Hasheia senha com salt seguro do jogo
static func hash_password(password: String, username: String) -> String:
	return (password + ":" + username.strip_edges().to_lower() + ":cepas_selvagens_beta_2026").sha256_text()

## Registra uma nova conta no servidor
func register_account(username: String, pass_hash_or_raw: String) -> Dictionary:
	var clean_user := username.strip_edges()
	if clean_user.length() < 3 or clean_user.length() > 24:
		return {"success": false, "message": "O nome de usuário deve ter entre 3 e 24 caracteres."}
	_ensure_directories()
	var safe_user := clean_user.validate_filename().to_lower()
	var file_path := "%s/%s.json" % [ACCOUNTS_DIR, safe_user]
	if FileAccess.file_exists(file_path):
		return {"success": false, "message": "Este nome de usuário já está em uso."}

	var pass_hash: String = pass_hash_or_raw
	if pass_hash.length() != 64:
		pass_hash = hash_password(pass_hash, clean_user)

	var payload := {
		"username": clean_user,
		"password_hash": pass_hash,
		"created_at": Time.get_datetime_string_from_system(),
		"characters": []
	}
	var f := FileAccess.open(file_path, FileAccess.WRITE)
	if f == null:
		return {"success": false, "message": "Erro ao criar arquivo de conta no servidor."}
	f.store_string(JSON.stringify(payload, "\t"))
	f.close()
	return {"success": true, "message": "Conta criada com sucesso!", "characters": []}

## Autentica uma conta existente
func login_account(username: String, pass_hash_or_raw: String) -> Dictionary:
	var clean_user := username.strip_edges()
	var safe_user := clean_user.validate_filename().to_lower()
	var file_path := "%s/%s.json" % [ACCOUNTS_DIR, safe_user]
	if not FileAccess.file_exists(file_path):
		return {"success": false, "message": "Conta não encontrada."}

	var f := FileAccess.open(file_path, FileAccess.READ)
	if f == null:
		return {"success": false, "message": "Erro ao ler dados da conta."}
	var text := f.get_as_text()
	f.close()

	var json := JSON.new()
	if json.parse(text) != OK:
		return {"success": false, "message": "Dados de conta corrompidos."}
	var data: Dictionary = json.data as Dictionary

	var expected_hash: String = data.get("password_hash", "")
	var provided_hash: String = pass_hash_or_raw
	if provided_hash.length() != 64:
		provided_hash = hash_password(provided_hash, clean_user)

	if expected_hash != provided_hash:
		return {"success": false, "message": "Senha incorreta."}

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
	var safe_user := clean_user.validate_filename().to_lower()
	var acct_path := "%s/%s.json" % [ACCOUNTS_DIR, safe_user]
	if not FileAccess.file_exists(acct_path):
		return {"success": false, "message": "Conta inexistente."}

	if has_player_save(clean_char):
		return {"success": false, "message": "Já existe um personagem com este nome no mundo."}

	var initial_player_data := {
		"name": clean_char,
		"account": clean_user,
		"position": [0.0, 1.0, 0.0],
		"rotation_y": 0.0,
		"health": 100.0,
		"money": 50,
		"play_time": 0.0,
		"dna": dna_dict
	}
	save_player_data(clean_char, initial_player_data)

	var f := FileAccess.open(acct_path, FileAccess.READ)
	var acct_text := f.get_as_text() if f else "{}"
	if f: f.close()

	var json := JSON.new()
	var acct_data: Dictionary = {}
	if json.parse(acct_text) == OK and json.data is Dictionary:
		acct_data = json.data as Dictionary

	var char_list: Array = acct_data.get("characters", [])
	if not char_list.has(clean_char):
		char_list.append(clean_char)
		acct_data["characters"] = char_list
		var fw := FileAccess.open(acct_path, FileAccess.WRITE)
		if fw:
			fw.store_string(JSON.stringify(acct_data, "\t"))
			fw.close()

	return {"success": true, "message": "Personagem criado com sucesso!", "character": initial_player_data}

## Remove o vínculo do personagem da conta e apaga o save do disco
func delete_character_for_account(username: String, char_name: String) -> Dictionary:
	var clean_char := char_name.strip_edges()
	var clean_user := username.strip_edges()
	var safe_user := clean_user.validate_filename().to_lower()
	var acct_path := "%s/%s.json" % [ACCOUNTS_DIR, safe_user]
	if not FileAccess.file_exists(acct_path):
		return {"success": false, "message": "Conta inexistente."}

	var f := FileAccess.open(acct_path, FileAccess.READ)
	if f == null:
		return {"success": false, "message": "Erro ao acessar arquivo de conta."}
	var text := f.get_as_text()
	f.close()

	var json := JSON.new()
	if json.parse(text) != OK or not (json.data is Dictionary):
		return {"success": false, "message": "Dados de conta corrompidos."}
	var acct_data: Dictionary = json.data as Dictionary

	var chars: Array = acct_data.get("characters", [])
	if not chars.has(clean_char):
		return {"success": false, "message": "Personagem não pertence a esta conta."}

	chars.erase(clean_char)
	acct_data["characters"] = chars

	var fw := FileAccess.open(acct_path, FileAccess.WRITE)
	if fw:
		fw.store_string(JSON.stringify(acct_data, "\t"))
		fw.close()

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
