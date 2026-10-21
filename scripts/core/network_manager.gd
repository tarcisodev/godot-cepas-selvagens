class_name NetworkManagerAutoload
extends Node

## Gerenciador de rede autoritativo (ADR-0002).
## Suporta modo local/offline (onde o peer local é autoridade ID 1)
## e arquitetura de servidor dedicado / cliente via ENetMultiplayerPeer.

const DEFAULT_PORT: int = 8787
const DEFAULT_HOST: String = "127.0.0.1"

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

var state: NetworkState = NetworkState.OFFLINE_HOST
var peer: ENetMultiplayerPeer = null

func _ready() -> void:
	# Por padrão no slice, inicializa no modo OFFLINE_HOST (autoridade total local)
	setup_offline_host()

## Configura o peer como host local offline (ID 1)
func setup_offline_host() -> void:
	cleanup_peer()
	state = NetworkState.OFFLINE_HOST
	network_state_changed.emit(state)

func _get_mp() -> MultiplayerAPI:
	if is_inside_tree() and multiplayer != null:
		return multiplayer
	var main_loop := Engine.get_main_loop()
	if main_loop is SceneTree and main_loop.root != null:
		return main_loop.root.get_multiplayer()
	return null

## Inicia servidor autoritativo
func start_server(port: int = DEFAULT_PORT, max_clients: int = 16) -> Error:
	cleanup_peer()
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_server(port, max_clients)
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
	network_state_changed.emit(state)
	var peer_id := mp.get_unique_id() if mp != null else 1
	print("[NetworkManager] Servidor autoritativo iniciado na porta %d (Peer ID: %d)" % [port, peer_id])
	return OK

## Conecta cliente a um servidor
func start_client(host: String = DEFAULT_HOST, port: int = DEFAULT_PORT) -> Error:
	cleanup_peer()
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_client(host, port)
	if err != OK:
		push_error("Falha ao conectar cliente em %s:%d: %s" % [host, port, error_string(err)])
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
	print("[NetworkManager] Tentando conectar cliente em %s:%d..." % [host, port])
	return OK

func cleanup_peer() -> void:
	if peer != null:
		peer.close()
		peer = null
	var mp := _get_mp()
	if mp != null and mp.has_multiplayer_peer():
		mp.multiplayer_peer = null

## Retorna true se este nó possui autoridade de servidor (ID 1 ou modo offline host)
func is_server_authoritative() -> bool:
	if state == NetworkState.OFFLINE_HOST or state == NetworkState.HOSTING_SERVER:
		return true
	var mp := _get_mp()
	if mp != null and mp.has_multiplayer_peer():
		return mp.is_server()
	return true

## Solicitação de dano / combate autoritativo (RPC cliente -> servidor)
@rpc("any_peer", "call_local", "reliable")
func request_combat_hit(attacker_path: NodePath, target_path: NodePath, ability_name: StringName, part_id: StringName = &"") -> void:
	# Só o servidor autoritativo resolve
	if not is_server_authoritative():
		return
	
	var attacker: Node = get_node_or_null(attacker_path)
	var target: Node = get_node_or_null(target_path)
	
	if target == null:
		return
	
	# Cria e resolve o HitEvent no servidor
	var hit := HitEvent.new()
	hit.attacker = attacker
	hit.target = target
	hit.part_id = part_id
	hit.raw_damage = 25.0
	hit.poise_damage = 15.0
	hit.damage_type = DamageType.Type.SLASH
	
	var result: Dictionary = CombatResolver.resolve_hit(hit)
	
	# Sincroniza resultado com todos os clientes
	sync_combat_result.rpc(target_path, result[&"effective_damage"], result[&"poise_broken"], result[&"part_broken"], part_id)

@rpc("authority", "call_local", "reliable")
func sync_combat_result(target_path: NodePath, damage: float, poise_broken: bool, part_broken: bool, part_id: StringName) -> void:
	var target: Node = get_node_or_null(target_path)
	if target != null:
		var pools: PoolsComponent = target.get_node_or_null("PoolsComponent") as PoolsComponent
		if pools != null and not is_server_authoritative():
			# No cliente não-host, sincroniza o dano visual
			pools.take_damage(damage)

func _on_peer_connected(id: int) -> void:
	print("[NetworkManager] Novo peer conectado: %d" % id)
	peer_joined.emit(id)

func _on_peer_disconnected(id: int) -> void:
	print("[NetworkManager] Peer desconectado: %d" % id)
	peer_left.emit(id)

func _on_connected_to_server() -> void:
	print("[NetworkManager] Conexão com o servidor estabelecida com sucesso!")
	connection_established.emit()

func _on_connection_failed() -> void:
	push_error("[NetworkManager] Falha na conexão com o servidor.")
	setup_offline_host()
	connection_lost.emit()

func _on_server_disconnected() -> void:
	print("[NetworkManager] Desconectado do servidor.")
	setup_offline_host()
	connection_lost.emit()
