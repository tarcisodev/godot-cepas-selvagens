class_name ServerPersistenceAutoload
extends Node

## Módulo de Persistência do Servidor Autoritativo (B24).
## Salva e recupera o estado de jogadores e do mundo em sessões dedicadas / coop LAN
## no diretório user://server_saves/.

const BASE_SAVE_DIR: String = "user://server_saves"
const PLAYERS_DIR: String = "user://server_saves/players"
const WORLD_FILE: String = "user://server_saves/world/world_state.json"
const AUTOSAVE_INTERVAL: float = 60.0

signal player_saved(player_name: String)
signal player_loaded(player_name: String)

var _autosave_timer: float = AUTOSAVE_INTERVAL
var _net: Node

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_directories()
	_net = get_node_or_null("/root/NetworkManager")
	if _net != null:
		if _net.has_signal("peer_left"):
			_net.connect("peer_left", Callable(self, "_on_peer_left"))

func _ensure_directories() -> void:
	var global_base := ProjectSettings.globalize_path(BASE_SAVE_DIR)
	var global_players := ProjectSettings.globalize_path(PLAYERS_DIR)
	var global_world := ProjectSettings.globalize_path("user://server_saves/world")
	DirAccess.make_dir_recursive_absolute(global_base)
	DirAccess.make_dir_recursive_absolute(global_players)
	DirAccess.make_dir_recursive_absolute(global_world)

func _process(delta: float) -> void:
	_autosave_timer -= delta
	if _autosave_timer <= 0.0:
		_autosave_timer = AUTOSAVE_INTERVAL
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

	# Carteira
	var wallet = player.get("wallet")
	if wallet and wallet.has_method("get_balance"):
		dict["money"] = wallet.get_balance()

	# Inventário
	var inv = player.get("inventory")
	if inv and inv.has_method("serialize"):
		dict["inventory"] = inv.serialize()

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
		if wallet and wallet.has_method("set_balance"):
			wallet.set_balance(int(data["money"]))

	if data.has("inventory"):
		var inv = player.get("inventory")
		if inv and inv.has_method("deserialize"):
			inv.deserialize(data["inventory"])

func autosave_all_active_players() -> void:
	var tree := get_tree()
	if tree == null:
		return
	for player in tree.get_nodes_in_group("player"):
		var p_name: String = player.get("character_name") if "character_name" in player else ""
		if p_name.is_empty() and player.has_meta("player_name"):
			p_name = player.get_meta("player_name")
		if not p_name.is_empty():
			var data := serialize_player(player)
			save_player_data(p_name, data)

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
				var data := serialize_player(avatar)
				save_player_data(p_name, data)
				print("[ServerPersistence] Progresso salvo para '%s' ao desconectar." % p_name)
