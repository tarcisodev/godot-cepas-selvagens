class_name DedicatedServerBootAutoload
extends Node

## Autoload de Inicialização para Servidor Dedicado Headless (B24).
## Lê argumentos de linha de comando: se encontrar '--server', inicia o servidor
## na porta informada por '--port' (padrão 8787) e troca para a cena mínima de servidor.
## Exemplo: godot --headless --path . -- --server --port 8787

const SERVER_WORLD_SCENE: String = "res://scenes/server_world.tscn"
const DEFAULT_PORT: int = 8787

var is_dedicated: bool = false
var server_port: int = DEFAULT_PORT

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var args := get_combined_args()
	if parse_is_server(args):
		is_dedicated = true
		server_port = parse_port(args, DEFAULT_PORT)
		var use_ws := parse_use_websocket(args)
		boot_server(server_port, use_ws)

## Retorna todos os argumentos disponíveis (usuário após '--' ou diretos da linha de comando)
static func get_combined_args() -> PackedStringArray:
	var user_args := OS.get_cmdline_user_args()
	if not user_args.is_empty():
		return user_args
	return OS.get_cmdline_args()

## Verifica se o argumento '--server' foi passado
static func parse_is_server(args: PackedStringArray) -> bool:
	for a in args:
		if a == "--server" or a == "-server":
			return true
	return false

## Lê o valor do argumento '--port' ou retorna o padrão 8787
static func parse_port(args: PackedStringArray, default_port: int = DEFAULT_PORT) -> int:
	for i in range(args.size()):
		var a := args[i]
		if (a == "--port" or a == "-port") and (i + 1) < args.size():
			var val := args[i + 1].strip_edges()
			if val.is_valid_int():
				return val.to_int()
		elif a.begins_with("--port="):
			var val := a.substr(7).strip_edges()
			if val.is_valid_int():
				return val.to_int()
	return default_port

## Verifica se o protocolo WebSocket foi requisitado
static func parse_use_websocket(args: PackedStringArray) -> bool:
	for a in args:
		if a == "--ws" or a == "--websocket":
			return true
	return false

## Inicializa o NetworkManager no modo servidor e troca de cena
func boot_server(port: int, use_ws: bool = false) -> void:
	print("========================================================")
	print("🚀 [DedicatedServerBoot] MODO SERVIDOR DEDICADO ATIVO")
	print("   Porta: %d | Protocolo: %s" % [port, "WebSocket" if use_ws else "ENet (UDP)"])
	print("========================================================")

	var net: Node = get_node_or_null("/root/NetworkManager")
	if net != null:
		var err: int = net.start_server(port, 16, use_ws)
		if err != OK:
			push_error("[DedicatedServerBoot] Falha ao iniciar servidor na porta %d (erro: %d)" % [port, err])
			return
		print("[DedicatedServerBoot] Servidor iniciado com sucesso via NetworkManager.")

	call_deferred("_change_to_server_scene")

func _change_to_server_scene() -> void:
	if ResourceLoader.exists(SERVER_WORLD_SCENE):
		print("[DedicatedServerBoot] Trocando para cena mínima: %s" % SERVER_WORLD_SCENE)
		get_tree().change_scene_to_file(SERVER_WORLD_SCENE)
	else:
		print("[DedicatedServerBoot] Cena de servidor não encontrada, usando res://scenes/world.tscn")
		get_tree().change_scene_to_file("res://scenes/world.tscn")
