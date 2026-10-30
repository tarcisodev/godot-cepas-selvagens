class_name NetworkManagerAutoload
extends Node

## Gerenciador de rede autoritativo e Coop LAN (ADR-0002).
## Suporta modo local/offline (ID 1) e sessões multiplayer via ENetMultiplayerPeer
## para até 16 jogadores na mesma rede local (Wi-Fi/LAN) ou via túnel/IP direto.
## Sincroniza avatares 3D (CharacterVisual + DNA + Cosméticos), animações, nomes e ciclo do céu.

# Preloads de tipos essenciais para registro sequencial no ScriptServer (evita "Could not find type")
const _CharacterDNA = preload("res://scripts/data/character_dna.gd")
const _CharacterVisual = preload("res://scripts/components/character_visual.gd")
const _WorldBounds = preload("res://scripts/core/world_bounds.gd")
const _HitEvent = preload("res://scripts/data/hit_event.gd")
const _GuildBook = preload("res://scripts/systems/guild_book.gd")
const _GuildSystem = preload("res://scripts/systems/guild_system.gd")
const _DamageType = preload("res://scripts/data/damage_type.gd")
const _CombatResolver = preload("res://scripts/systems/combat_resolver.gd")
const _PoolsComponent = preload("res://scripts/components/pools_component.gd")
const _StyleAttack = preload("res://scripts/data/style_attack.gd")
const _EquipmentPiece = preload("res://scripts/data/equipment_piece.gd")
const _WeaponStyle = preload("res://scripts/data/weapon_style.gd")

const GAME_VERSION: String = "0.1.1"
const DEFAULT_PORT: int = 8787
const DEFAULT_HOST: String = "jogar.tarciso.dev"
const DEFAULT_LOCAL_HOST: String = "127.0.0.1"
const MAX_PLAYERS: int = 32
const MAX_CONNECTIONS_PER_IP: int = 3
const MAX_LOGIN_ATTEMPTS_PER_MINUTE: int = 5
const LOGIN_RATE_WINDOW_SECONDS: float = 60.0
const SYNC_INTERVAL: float = 0.05 # 20 Hz

enum NetworkState {
	OFFLINE_HOST,      ## Host local (single-player com autoridade de servidor)
	HOSTING_SERVER,    ## Servidor multiplayer ativo (escutando conexões)
	CONNECTED_CLIENT,  ## Cliente conectado a um servidor remoto
	DISCONNECTED       ## Desconectado
}

signal network_state_changed(new_state: NetworkState)
signal peer_joined(peer_id: int)
signal peer_left(peer_id: int)
signal connection_established()
signal connection_lost()
signal players_updated()
signal auth_result(success: bool, message: String, characters: Array)
signal character_created(success: bool, message: String, character_data: Dictionary)
signal character_deleted(success: bool, message: String, character_name: String)
signal entered_world(success: bool, world_data: Dictionary)

var state: NetworkState = NetworkState.OFFLINE_HOST
var peer: MultiplayerPeer = null

## Sessão do jogador autenticado
var current_account: String = ""
var _pending_auth_username: String = ""
var current_character: String = ""
var current_characters_data: Array = []
## No servidor: peer_id -> username
var peer_accounts: Dictionary = {}

## Rastreamento de conexões e segurança do servidor
var peer_ips: Dictionary = {}
var login_attempts_by_ip: Dictionary = {}

## peer_id -> {"name": String, "dna": Dictionary}
var players_info: Dictionary = {}
var remote_avatars: Dictionary = {}

var _sync_timer: float = 0.0
var _last_dna_hash: int = 0

func _ready() -> void:
	setup_offline_host()

## Configura o peer como host local offline (ID 1)
func setup_offline_host() -> void:
	cleanup_peer()
	state = NetworkState.OFFLINE_HOST
	network_state_changed.emit(state)
	players_updated.emit()

func _get_mp() -> MultiplayerAPI:
	if is_inside_tree() and multiplayer != null:
		return multiplayer
	var main_loop := Engine.get_main_loop()
	if main_loop is SceneTree and main_loop.root != null:
		return main_loop.root.get_multiplayer()
	return null

## Retorna o IP da placa de rede local (Wi-Fi / Cabo) para facilitar conexão em casa
static func get_lan_ip() -> String:
	var candidates: Array[String] = []
	for ip in IP.get_local_addresses():
		if ip.begins_with("192.168.") or ip.begins_with("10.") or ip.begins_with("172."):
			if ip.begins_with("192.168."):
				return ip
			candidates.append(ip)
	return candidates[0] if not candidates.is_empty() else "127.0.0.1"

## Inicia servidor autoritativo (até max_clients jogadores). Suporta ENet (UDP) ou WebSocket (Cloudflare Tunnel)
func start_server(port: int = DEFAULT_PORT, max_clients: int = MAX_PLAYERS, use_websocket: bool = false) -> Error:
	cleanup_peer()
	var err: Error = OK
	if use_websocket:
		var ws := WebSocketMultiplayerPeer.new()
		err = ws.create_server(port)
		peer = ws
	else:
		var enet := ENetMultiplayerPeer.new()
		err = enet.create_server(port, max_clients)
		peer = enet

	if err != OK:
		push_error("Falha ao iniciar servidor na porta %d: %s" % [port, error_string(err)])
		setup_offline_host()
		return err

	var mp := _get_mp()
	if mp != null:
		mp.multiplayer_peer = peer
		if not mp.peer_connected.is_connected(_on_peer_connected):
			mp.peer_connected.connect(_on_peer_connected)
		if not mp.peer_disconnected.is_connected(_on_peer_disconnected):
			mp.peer_disconnected.connect(_on_peer_disconnected)

	state = NetworkState.HOSTING_SERVER
	# Guildas e Livros do Totem voltam com o servidor (GDD-19 §7)
	var sp := get_node_or_null("/root/ServerPersistence")
	if sp and sp.has_method("load_guilds"):
		sp.load_guilds()
	_register_self_profile()
	network_state_changed.emit(state)
	players_updated.emit()
	var peer_id := mp.get_unique_id() if mp != null else 1
	var proto_name: String = "WebSocket (Cloudflare Tunnel)" if use_websocket else "ENet (UDP)"
	print("[NetworkManager] Servidor iniciado via %s na porta %d (Peer ID: %d, LAN IP: %s)" % [proto_name, port, peer_id, get_lan_ip()])
	return OK

## Conecta cliente a um servidor (via IP ou URL Cloudflare: ws:// ou wss://)
func start_client(host_or_url: String = DEFAULT_HOST, port: int = DEFAULT_PORT) -> Error:
	cleanup_peer()
	var target := host_or_url.strip_edges()
	var is_ws: bool = target.begins_with("ws://") or target.begins_with("wss://")
	var err: Error = OK

	if is_ws:
		var ws := WebSocketMultiplayerPeer.new()
		err = ws.create_client(target)
		peer = ws
	else:
		var enet := ENetMultiplayerPeer.new()
		err = enet.create_client(target, port)
		peer = enet

	if err != OK:
		push_error("Falha ao conectar cliente em %s:%d: %s" % [target, port, error_string(err)])
		setup_offline_host()
		return err

	var mp := _get_mp()
	if mp != null:
		mp.multiplayer_peer = peer
		if not mp.connected_to_server.is_connected(_on_connected_to_server):
			mp.connected_to_server.connect(_on_connected_to_server)
		if not mp.connection_failed.is_connected(_on_connection_failed):
			mp.connection_failed.connect(_on_connection_failed)
		if not mp.server_disconnected.is_connected(_on_server_disconnected):
			mp.server_disconnected.connect(_on_server_disconnected)

	state = NetworkState.CONNECTED_CLIENT
	network_state_changed.emit(state)
	players_updated.emit()
	print("[NetworkManager] Tentando conectar cliente em %s..." % target)
	return OK

func cleanup_peer() -> void:
	for id in remote_avatars.keys():
		_remove_remote_avatar(id)
	remote_avatars.clear()
	players_info.clear()
	peer_ips.clear()
	if peer != null:
		peer.close()
		peer = null
	var mp := _get_mp()
	if mp != null and mp.has_multiplayer_peer():
		mp.multiplayer_peer = null

## Retorna o endereço IP remoto associado a um peer_id conectado
func get_peer_ip(peer_id: int) -> String:
	if peer_ips.has(peer_id):
		return peer_ips[peer_id]
	if peer == null:
		return "127.0.0.1"
	if peer is ENetMultiplayerPeer:
		var enet := peer as ENetMultiplayerPeer
		var packet_peer := enet.get_peer(peer_id)
		if packet_peer != null:
			var addr := packet_peer.get_remote_address()
			if not addr.is_empty():
				return addr
	elif peer is WebSocketMultiplayerPeer:
		var ws := peer as WebSocketMultiplayerPeer
		var ws_peer := ws.get_peer(peer_id)
		if ws_peer != null:
			var host := ws_peer.get_connected_host()
			if not host.is_empty():
				return host
	return "127.0.0.1"

## Conta quantas conexões ativas existem a partir de um mesmo IP
func count_active_connections_from_ip(ip: String) -> int:
	var count := 0
	for p_id in peer_ips:
		if peer_ips[p_id] == ip:
			count += 1
	return count

## Desconecta um peer com segurança suportando ENet e WebSocket
func disconnect_peer_safe(peer_id: int) -> void:
	if peer != null:
		if peer is ENetMultiplayerPeer:
			(peer as ENetMultiplayerPeer).disconnect_peer(peer_id)
		elif peer is WebSocketMultiplayerPeer:
			(peer as WebSocketMultiplayerPeer).disconnect_peer(peer_id)

## Verifica se o IP excedeu o limite de tentativas de login por minuto (rate limiting)
func _check_login_rate_limit(ip: String) -> bool:
	var now: float = float(Time.get_ticks_msec()) / 1000.0
	var attempts: Array = login_attempts_by_ip.get(ip, [])
	var filtered: Array = []
	for t in attempts:
		if (now - float(t)) < LOGIN_RATE_WINDOW_SECONDS:
			filtered.append(t)
	if filtered.size() >= MAX_LOGIN_ATTEMPTS_PER_MINUTE:
		login_attempts_by_ip[ip] = filtered
		return false
	filtered.append(now)
	login_attempts_by_ip[ip] = filtered
	return true

## Retorna true se este nó possui autoridade de servidor (ID 1 ou modo offline host)
func is_server_authoritative() -> bool:
	if state == NetworkState.OFFLINE_HOST or state == NetworkState.HOSTING_SERVER:
		return true
	var mp := _get_mp()
	if mp != null and mp.has_multiplayer_peer():
		return mp.is_server()
	return true

func _process(delta: float) -> void:
	# Interpola movimento suave dos avatares remotos em todos os frames
	for id in remote_avatars:
		var av: Node3D = remote_avatars[id]
		if not is_instance_valid(av):
			continue
		if av.has_meta("target_pos"):
			var tpos: Vector3 = av.get_meta("target_pos")
			av.global_position = av.global_position.lerp(tpos, minf(1.0, delta * 14.0))
		if av.has_meta("target_yaw"):
			var tyaw: float = av.get_meta("target_yaw")
			av.rotation.y = lerp_angle(av.rotation.y, tyaw, minf(1.0, delta * 14.0))

	if state != NetworkState.HOSTING_SERVER and state != NetworkState.CONNECTED_CLIENT:
		return
	var mp := _get_mp()
	if mp == null or not mp.has_multiplayer_peer():
		return
	if state == NetworkState.CONNECTED_CLIENT and peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return

	_sync_timer -= delta
	if _sync_timer > 0.0:
		return
	_sync_timer = SYNC_INTERVAL

	var local_player := _local_player()
	if local_player == null:
		return

	var my_id := mp.get_unique_id()
	var visual: CharacterVisual = local_player.get("character_visual")
	if visual and visual.dna:
		var h := visual.dna.to_dict().hash()
		if h != _last_dna_hash:
			_last_dna_hash = h
			_register_self_profile()
			rpc_sync_profile.rpc(my_id, _local_player_name(), visual.dna.to_dict())

	var cur_anim: StringName = visual.current() if visual else &"Idle"
	var body_yaw: float = visual.rotation.y if visual else local_player.rotation.y
	rpc_sync_transform.rpc(my_id, local_player.global_position, body_yaw, cur_anim)

	# Host sincroniza hora do sol e clima para que todos vejam o mesmo céu, chuva e estrelas
	if state == NetworkState.HOSTING_SERVER and is_inside_tree() and get_tree().current_scene:
		var sun := get_tree().current_scene.get_node_or_null("Sun")
		var weather := get_tree().current_scene.get_node_or_null("WeatherSystem")
		if sun and "current_time_hours" in sun:
			var h_val: float = float(sun.current_time_hours)
			var d_val: int = int(sun.get("day_count"))
			var hum: float = float(weather.get("humidity")) if weather else 0.45
			var cld: float = float(weather.get("clouds")) if weather else 0.1
			var rn: float = float(weather.get("rain")) if weather else 0.0
			rpc_sync_world_environment.rpc(h_val, d_val, hum, cld, rn)

func _local_player() -> Node3D:
	if not is_inside_tree():
		return null
	return get_tree().get_first_node_in_group("player") as Node3D

func _local_player_name() -> String:
	var sg := get_node_or_null("/root/SaveGame") if is_inside_tree() else null
	var n := str(sg.get("character_name")).strip_edges() if sg else ""
	if not n.is_empty():
		return n
	return "Host" if state == NetworkState.HOSTING_SERVER else "Explorador(a)"

func _register_self_profile() -> void:
	var mp := _get_mp()
	var my_id := mp.get_unique_id() if mp and mp.has_multiplayer_peer() else 1
	var p := _local_player()
	var visual: CharacterVisual = p.get("character_visual") if p else null
	var dna_dict: Dictionary = visual.dna.to_dict() if (visual and visual.dna) else CharacterDNA.new().to_dict()
	players_info[my_id] = {"name": _local_player_name(), "dna": dna_dict}

# ---------------------------------------------------------------- RPCs de Coop / Rede

@rpc("any_peer", "reliable")
func rpc_sync_profile(peer_id: int, p_name: String, dna_dict: Dictionary) -> void:
	players_info[peer_id] = {"name": p_name, "dna": dna_dict}
	_ensure_remote_avatar(peer_id, p_name, dna_dict)
	players_updated.emit()

@rpc("any_peer", "unreliable_ordered")
func rpc_sync_transform(peer_id: int, pos: Vector3, yaw: float, anim: StringName) -> void:
	var mp := _get_mp()
	if mp and peer_id == mp.get_unique_id():
		return
	var av := _ensure_remote_avatar(peer_id, players_info.get(peer_id, {}).get("name", "Explorador #%d" % peer_id), players_info.get(peer_id, {}).get("dna", {}))
	if av == null:
		return
	if not av.has_meta("target_pos"):
		av.global_position = pos
	av.set_meta("target_pos", pos)
	av.set_meta("target_yaw", yaw)
	var vis := av.get_node_or_null("CharacterVisual") as CharacterVisual
	if vis and anim != &"":
		vis.play(anim)

@rpc("authority", "unreliable_ordered")
func rpc_sync_world_environment(hour: float, day: int, humidity: float, clouds: float, rain: float) -> void:
	if is_server_authoritative() or not is_inside_tree() or get_tree().current_scene == null:
		return
	var sun := get_tree().current_scene.get_node_or_null("Sun")
	if sun and sun.has_method("_update_sun_position_and_lighting"):
		sun.set("current_time_hours", hour)
		sun.set("day_count", day)
		sun._update_sun_position_and_lighting()
	var weather := get_tree().current_scene.get_node_or_null("WeatherSystem")
	if weather:
		weather.set("humidity", humidity)
		weather.set("clouds", clouds)
		weather.set("rain", rain)

## Cria ou atualiza o avatar 3D de outro jogador conectado na cena
func _ensure_remote_avatar(peer_id: int, p_name: String, dna_dict: Dictionary) -> Node3D:
	var mp := _get_mp()
	if mp and mp.has_multiplayer_peer() and peer_id == mp.get_unique_id():
		return null
	if not is_inside_tree() or get_tree().current_scene == null:
		return null

	var av: Node3D = remote_avatars.get(peer_id)
	if av == null or not is_instance_valid(av):
		av = Node3D.new()
		av.name = "RemotePlayer_%d" % peer_id
		av.add_to_group("remote_players")
		get_tree().current_scene.add_child(av)

		var vis := CharacterVisual.new()
		vis.name = "CharacterVisual"
		vis.dna = CharacterDNA.from_dict(dna_dict) if not dna_dict.is_empty() else CharacterDNA.randomized(peer_id)
		av.add_child(vis)

		var name_lbl := Label3D.new()
		name_lbl.name = "NameTag"
		name_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		name_lbl.font_size = 24
		name_lbl.outline_size = 5
		name_lbl.modulate = Color(0.98, 0.90, 0.58)
		name_lbl.position = Vector3(0.0, 2.15, 0.0)
		av.add_child(name_lbl)

		remote_avatars[peer_id] = av

	var tag := av.get_node_or_null("NameTag") as Label3D
	if tag:
		tag.text = "👤 %s" % p_name
	if not dna_dict.is_empty():
		var vis := av.get_node_or_null("CharacterVisual") as CharacterVisual
		var new_hash := dna_dict.hash()
		if vis and av.get_meta("dna_hash", 0) != new_hash:
			av.set_meta("dna_hash", new_hash)
			vis.rebuild(CharacterDNA.from_dict(dna_dict))
	return av

func _remove_remote_avatar(peer_id: int) -> void:
	if remote_avatars.has(peer_id):
		var av: Node = remote_avatars[peer_id]
		if is_instance_valid(av):
			av.queue_free()
		remote_avatars.erase(peer_id)

## Solicitação de dano / combate autoritativo (RPC cliente -> servidor)
@rpc("any_peer", "call_local", "reliable")
func request_combat_hit(attacker_path: NodePath, target_path: NodePath, ability_name: StringName, part_id: StringName = &"") -> void:
	if not is_server_authoritative():
		return

	var attacker: Node = get_node_or_null(attacker_path)
	var target: Node = get_node_or_null(target_path)

	if target == null:
		return

	var hit := HitEvent.new()
	hit.attacker = attacker
	hit.target = target
	hit.part_id = part_id
	hit.raw_damage = 25.0
	hit.poise_damage = 15.0
	hit.damage_type = DamageType.Type.SLASH

	var result: Dictionary = CombatResolver.resolve_hit(hit)
	sync_combat_result.rpc(target_path, result[&"effective_damage"], result[&"poise_broken"], result[&"part_broken"], part_id)

@rpc("authority", "call_local", "reliable")
func sync_combat_result(target_path: NodePath, damage: float, poise_broken: bool, part_broken: bool, part_id: StringName) -> void:
	var target: Node = get_node_or_null(target_path)
	if target != null:
		var pools: PoolsComponent = target.get_node_or_null("PoolsComponent") as PoolsComponent
		if pools != null and not is_server_authoritative():
			pools.take_damage(damage)

func _on_peer_connected(id: int) -> void:
	if is_server_authoritative() and state == NetworkState.HOSTING_SERVER:
		var mp := _get_mp()
		var peer_count := mp.get_peers().size() if mp != null else 0
		if peer_count > MAX_PLAYERS:
			print("[Security] Recusa de conexão: limite máximo de %d jogadores atingido (%d conectados). Desconectando peer %d." % [MAX_PLAYERS, peer_count, id])
			disconnect_peer_safe(id)
			return

		var ip := get_peer_ip(id)
		peer_ips[id] = ip

		var conn_count := count_active_connections_from_ip(ip)
		if conn_count > MAX_CONNECTIONS_PER_IP:
			print("[Security] Recusa de conexão: limite de %d conexões simultâneas por IP excedido para o IP %s (Peer: %d, Ativas: %d)." % [
				MAX_CONNECTIONS_PER_IP, ip, id, conn_count
			])
			peer_ips.erase(id)
			disconnect_peer_safe(id)
			return

	print("[NetworkManager] Novo jogador conectado: %d (IP: %s)" % [id, peer_ips.get(id, "local")])
	_register_self_profile()
	var mp := _get_mp()
	var my_id := mp.get_unique_id() if mp else 1
	if players_info.has(my_id):
		var me: Dictionary = players_info[my_id]
		rpc_sync_profile.rpc_id(id, my_id, me.get("name", "Host"), me.get("dna", {}))
	peer_joined.emit(id)
	players_updated.emit()

func _on_peer_disconnected(id: int) -> void:
	var ip: String = peer_ips.get(id, "")
	peer_ips.erase(id)
	peer_accounts.erase(id)
	print("[NetworkManager] Jogador desconectado: %d%s" % [id, " (IP: " + ip + ")" if not ip.is_empty() else ""])
	_remove_remote_avatar(id)
	players_info.erase(id)
	peer_left.emit(id)
	players_updated.emit()

func _on_connected_to_server() -> void:
	print("[NetworkManager] Conexão com o servidor estabelecida com sucesso!")
	_register_self_profile()
	var mp := _get_mp()
	var my_id := mp.get_unique_id() if mp else 2
	if players_info.has(my_id):
		var me: Dictionary = players_info[my_id]
		rpc_sync_profile.rpc(my_id, me.get("name", "Explorador(a)"), me.get("dna", {}))
	connection_established.emit()
	players_updated.emit()

func _on_connection_failed() -> void:
	push_error("[NetworkManager] Falha na conexão com o servidor.")
	setup_offline_host()
	connection_lost.emit()

func _on_server_disconnected() -> void:
	print("[NetworkManager] Desconectado do servidor.")
	setup_offline_host()
	connection_lost.emit()

## ===================================================================
## Autenticação de Contas & Criação de Personagens (B24)
## ===================================================================

## Envia solicitação de Login ou Registro para o servidor
func send_auth_request(mode: String, username: String, password_raw: String, client_version: String = GAME_VERSION) -> void:
	_pending_auth_username = username.strip_edges()
	if client_version != GAME_VERSION:
		var msg := "Versão incompatível do jogo (Cliente: %s | Servidor: %s). Por favor, atualize o jogo para entrar no playtest." % [
			client_version if not client_version.is_empty() else "desconhecida",
			GAME_VERSION
		]
		print("[Security] Recusa de autenticação: versão incompatível (cliente: '%s', servidor: '%s')" % [client_version, GAME_VERSION])
		auth_result.emit(false, msg, [])
		return

	if state != NetworkState.CONNECTED_CLIENT and state != NetworkState.HOSTING_SERVER:
		auth_result.emit(false, "Não conectado a nenhum servidor.", [])
		return
	var sp = get_node_or_null("/root/ServerPersistence")
	if is_server_authoritative() and sp != null:
		var res: Dictionary = sp.register_account(username, password_raw) if mode == "register" else sp.login_account(username, password_raw)
		var ok: bool = res.get("success", false)
		if ok:
			current_account = username
			current_characters_data = res.get("characters_data", [])
		else:
			current_characters_data = []
		auth_result.emit(ok, res.get("message", ""), res.get("characters", []))
		return
	rpc_id(1, "rpc_request_auth", mode, username, password_raw, client_version)

## Envia solicitação de criação de personagem
func send_create_character_request(character_name: String, dna_dict: Dictionary) -> void:
	var sp = get_node_or_null("/root/ServerPersistence")
	if is_server_authoritative() and sp != null:
		var res: Dictionary = sp.create_character_for_account(current_account, character_name, dna_dict)
		var ok: bool = res.get("success", false)
		if ok:
			var c_dict: Dictionary = res.get("character", {})
			current_characters_data.append({
				"name": character_name,
				"money": int(c_dict.get("money", 50)),
				"play_time": float(c_dict.get("play_time", 0.0))
			})
		character_created.emit(ok, res.get("message", ""), res.get("character", {}))
		return
	rpc_id(1, "rpc_request_create_character", character_name, dna_dict)

## Envia solicitação de exclusão de personagem
func send_delete_character_request(character_name: String) -> void:
	var sp = get_node_or_null("/root/ServerPersistence")
	if is_server_authoritative() and sp != null:
		var res: Dictionary = sp.delete_character_for_account(current_account, character_name)
		var ok: bool = res.get("success", false)
		if ok:
			_remove_character_data(character_name)
		character_deleted.emit(ok, res.get("message", ""), character_name)
		return
	rpc_id(1, "rpc_request_delete_character", character_name)

func _remove_character_data(character_name: String) -> void:
	for i in range(current_characters_data.size() - 1, -1, -1):
		var item = current_characters_data[i]
		if (item is Dictionary and item.get("name") == character_name) or str(item) == character_name:
			current_characters_data.remove_at(i)

## Solicita entrada no mundo com o personagem selecionado
func send_enter_world_request(character_name: String) -> void:
	current_character = character_name
	var sp = get_node_or_null("/root/ServerPersistence")
	if is_server_authoritative() and sp != null:
		var pdata: Dictionary = sp.load_player_data(character_name)
		entered_world.emit(true, pdata)
		return
	rpc_id(1, "rpc_request_enter_world", character_name)

@rpc("any_peer", "call_remote", "reliable")
func rpc_request_auth(mode: String, username: String, pass_hash_or_raw: String, client_version: String = "") -> void:
	if not is_server_authoritative():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	var ip := get_peer_ip(sender_id)

	# 1. Validação de versão (Task 2)
	if client_version != GAME_VERSION:
		var mismatch_msg := "Versão incompatível do jogo (Cliente: %s | Servidor: %s). Por favor, atualize o jogo para entrar no playtest." % [
			client_version if not client_version.is_empty() else "desconhecida",
			GAME_VERSION
		]
		print("[Security] Recusa de login: versão incompatível '%s' (esperado '%s') para o IP %s (Peer: %d)" % [
			client_version, GAME_VERSION, ip, sender_id
		])
		rpc_id(sender_id, "rpc_response_auth", false, mismatch_msg, [])
		return

	# 2. Rate limit de tentativas por IP (Task 3)
	if not _check_login_rate_limit(ip):
		var limit_msg := "Muitas tentativas de login a partir deste endereço. Aguarde um minuto antes de tentar novamente."
		print("[Security] Recusa de login: rate limit excedido (> %d tentativas/min) para o IP %s (Peer: %d)" % [
			MAX_LOGIN_ATTEMPTS_PER_MINUTE, ip, sender_id
		])
		rpc_id(sender_id, "rpc_response_auth", false, limit_msg, [])
		return

	var sp = get_node_or_null("/root/ServerPersistence")
	if sp == null:
		rpc_id(sender_id, "rpc_response_auth", false, "Servidor sem persistência ativa.", [])
		return
	var res: Dictionary = sp.register_account(username, pass_hash_or_raw) if mode == "register" else sp.login_account(username, pass_hash_or_raw)
	var ok: bool = res.get("success", false)
	if ok:
		peer_accounts[sender_id] = username
		print("[NetworkManager] Conta '%s' autenticada com sucesso (Peer: %d, IP: %s)" % [username, sender_id, ip])
	else:
		print("[Security] Falha de autenticação para conta '%s' do IP %s: %s" % [username, ip, res.get("message", "")])
	rpc_id(sender_id, "rpc_response_auth", ok, res.get("message", ""), res.get("characters", []), username if ok else "", res.get("characters_data", []))

@rpc("authority", "call_remote", "reliable")
func rpc_response_auth(success: bool, message: String, characters: Array, auth_account: String = "", characters_data: Array = []) -> void:
	if success:
		current_account = auth_account if not auth_account.is_empty() else _pending_auth_username
		current_characters_data = characters_data
	else:
		current_account = ""
		current_characters_data = []
	auth_result.emit(success, message, characters)

@rpc("any_peer", "call_remote", "reliable")
func rpc_request_create_character(character_name: String, dna_dict: Dictionary) -> void:
	if not is_server_authoritative():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	var sp = get_node_or_null("/root/ServerPersistence")
	var account: String = peer_accounts.get(sender_id, "")
	if account.is_empty() or sp == null:
		rpc_id(sender_id, "rpc_response_create_character", false, "Não autenticado no servidor.", {})
		return
	var res: Dictionary = sp.create_character_for_account(account, character_name, dna_dict)
	rpc_id(sender_id, "rpc_response_create_character", res.get("success", false), res.get("message", ""), res.get("character", {}))

@rpc("authority", "call_remote", "reliable")
func rpc_response_create_character(success: bool, message: String, character_data: Dictionary) -> void:
	if success and not character_data.is_empty():
		var cname: String = str(character_data.get("name", ""))
		if not cname.is_empty():
			current_characters_data.append({
				"name": cname,
				"money": int(character_data.get("money", 50)),
				"play_time": float(character_data.get("play_time", 0.0))
			})
	character_created.emit(success, message, character_data)

@rpc("any_peer", "call_remote", "reliable")
func rpc_request_delete_character(character_name: String) -> void:
	if not is_server_authoritative():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	var sp = get_node_or_null("/root/ServerPersistence")
	var account: String = peer_accounts.get(sender_id, "")
	if account.is_empty() or sp == null:
		rpc_id(sender_id, "rpc_response_delete_character", false, "Não autenticado no servidor.", character_name)
		return
	var res: Dictionary = sp.delete_character_for_account(account, character_name)
	rpc_id(sender_id, "rpc_response_delete_character", res.get("success", false), res.get("message", ""), character_name)

@rpc("authority", "call_remote", "reliable")
func rpc_response_delete_character(success: bool, message: String, character_name: String) -> void:
	if success:
		_remove_character_data(character_name)
	character_deleted.emit(success, message, character_name)

@rpc("any_peer", "call_remote", "reliable")
func rpc_request_enter_world(character_name: String) -> void:
	if not is_server_authoritative():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	var sp = get_node_or_null("/root/ServerPersistence")
	var account: String = peer_accounts.get(sender_id, "")
	if account.is_empty() or sp == null:
		rpc_id(sender_id, "rpc_response_enter_world", false, {})
		return
	var pdata: Dictionary = sp.load_player_data(character_name)
	players_info[sender_id] = {
		"name": character_name,
		"dna": pdata.get("dna", {}),
		"account": account
	}
	rpc_id(sender_id, "rpc_response_enter_world", true, pdata)
	players_updated.emit()
	rpc_sync_profile.rpc(sender_id, character_name, pdata.get("dna", {}))

@rpc("authority", "call_remote", "reliable")
func rpc_response_enter_world(success: bool, world_data: Dictionary) -> void:
	entered_world.emit(success, world_data)

# ---------------------------------------------------------------- Diário do Caçador (GDD-19 §7)

## Peer dono de um avatar remoto (0 se não for avatar de rede)
func peer_of(avatar: Node) -> int:
	for id in remote_avatars:
		if remote_avatars[id] == avatar:
			return int(id)
	return 0

## Mostrar o Diário a outro jogador: o cliente pede ao servidor, que repassa só para o alvo
func send_diary_showcase(target: Node, payload: Dictionary) -> bool:
	var target_peer := peer_of(target)
	var mp := _get_mp()
	if target_peer == 0 or mp == null or not mp.has_multiplayer_peer():
		return false
	if is_server_authoritative():
		var me: Dictionary = players_info.get(mp.get_unique_id(), {})
		payload["from"] = me.get("name", _local_player_name())
		rpc_id(target_peer, "rpc_receive_diary_showcase", payload)
	else:
		rpc_id(1, "rpc_request_diary_showcase", target_peer, payload)
	return true

@rpc("any_peer", "call_remote", "reliable")
func rpc_request_diary_showcase(target_peer: int, payload: Dictionary) -> void:
	if not is_server_authoritative():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	if not players_info.has(sender_id) or not players_info.has(target_peer):
		return
	# Quem mostra é quem o servidor diz que é, não o que o cliente escreveu
	payload["from"] = players_info[sender_id].get("name", "?")
	rpc_id(target_peer, "rpc_receive_diary_showcase", payload)

@rpc("authority", "call_remote", "reliable")
func rpc_receive_diary_showcase(payload: Dictionary) -> void:
	var p := _local_player()
	var diary := p.get_node_or_null("DiaryComponent") if p else null
	if diary:
		diary.receive_showcase(payload)

## Servidor manda a cópia atualizada do Diário para o dono (o cliente só lê; ADR-0002)
func push_diary(peer_id: int, data: Dictionary) -> void:
	if is_server_authoritative() and peer_id != 0:
		rpc_id(peer_id, "rpc_receive_diary", data)

@rpc("authority", "call_remote", "reliable")
func rpc_receive_diary(data: Dictionary) -> void:
	var p := _local_player()
	var diary := p.get_node_or_null("DiaryComponent") if p else null
	if diary:
		diary.apply_snapshot(data)

# ---------------------------------------------------------------- Livro do Totem e Placar (GDD-19 §7)

signal guild_board_received(data: Dictionary)

## Cliente pede o Placar das Guildas e o Livro da própria guilda (no máximo a cada 2 s)
var _board_asked_msec: int = -100000

func request_guild_board() -> bool:
	var mp := _get_mp()
	if is_server_authoritative() or mp == null or not mp.has_multiplayer_peer():
		return false
	if Time.get_ticks_msec() - _board_asked_msec < 2000:
		return false
	_board_asked_msec = Time.get_ticks_msec()
	rpc_id(1, "rpc_request_guild_board")
	return true

@rpc("any_peer", "call_remote", "reliable")
func rpc_request_guild_board() -> void:
	if not is_server_authoritative():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	if not players_info.has(sender_id):
		return
	# Quem lê é quem o servidor diz que é: o Livro só vai para membro da guilda
	var reader: String = players_info[sender_id].get("name", "")
	var data := {"board": _GuildBook.scoreboard()}
	var book := _GuildBook.book_view(_GuildSystem.get_instance().get_player_guild(reader), reader)
	if not book.is_empty():
		data["book"] = book
	rpc_id(sender_id, "rpc_receive_guild_board", data)

@rpc("authority", "call_remote", "reliable")
func rpc_receive_guild_board(data: Dictionary) -> void:
	_GuildBook.board_cache = data
	guild_board_received.emit(data)
