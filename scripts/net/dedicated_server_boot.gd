class_name DedicatedServerBootAutoload
extends Node

## Autoload de Inicialização para Servidor Dedicado Headless (B24).
## Lê argumentos de linha de comando: se encontrar '--server', inicia o servidor
## na porta informada por '--port' (padrão 8787), limita o FPS (padrão 20) e
## a taxa de física physics_ticks_per_second (padrão 20 Hz) para manter o consumo
## de CPU ocioso no mínimo possível (~1-5% de 1 core), e troca para a cena mínima de servidor.
## Exemplo: godot --headless --path . -- --server --port 8787 --max-fps 20 --ticks 20

const SERVER_WORLD_SCENE: String = "res://scenes/server_world.tscn"
const DEFAULT_PORT: int = 8787
const DEFAULT_SERVER_FPS: int = 20
const DEFAULT_PHYSICS_TICKS: int = 20

var is_dedicated: bool = false
var server_port: int = DEFAULT_PORT
var server_max_fps: int = DEFAULT_SERVER_FPS
var server_physics_ticks: int = DEFAULT_PHYSICS_TICKS

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var args := get_combined_args()
	if parse_is_server(args):
		is_dedicated = true
		server_port = parse_port(args, DEFAULT_PORT)
		server_max_fps = parse_max_fps(args, DEFAULT_SERVER_FPS)
		server_physics_ticks = parse_physics_ticks(args, DEFAULT_PHYSICS_TICKS)
		var use_ws := parse_use_websocket(args)
		boot_server(server_port, use_ws, server_max_fps, server_physics_ticks)

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

## Lê o limite de FPS para o loop headless (padrão 20 fps para evitar consumo de CPU ocioso)
static func parse_max_fps(args: PackedStringArray, default_fps: int = DEFAULT_SERVER_FPS) -> int:
	for i in range(args.size()):
		var a := args[i]
		if (a == "--max-fps" or a == "--fps" or a == "-fps") and (i + 1) < args.size():
			var val := args[i + 1].strip_edges()
			if val.is_valid_int() and val.to_int() > 0:
				return val.to_int()
		elif a.begins_with("--max-fps="):
			var val := a.substr(10).strip_edges()
			if val.is_valid_int() and val.to_int() > 0:
				return val.to_int()
		elif a.begins_with("--fps="):
			var val := a.substr(6).strip_edges()
			if val.is_valid_int() and val.to_int() > 0:
				return val.to_int()
	return default_fps

## Lê o limite de ticks de física por segundo (padrão 20 Hz, alinhado ao tick de rede)
static func parse_physics_ticks(args: PackedStringArray, default_ticks: int = DEFAULT_PHYSICS_TICKS) -> int:
	for i in range(args.size()):
		var a := args[i]
		if (a == "--physics-ticks" or a == "--ticks" or a == "-ticks") and (i + 1) < args.size():
			var val := args[i + 1].strip_edges()
			if val.is_valid_int() and val.to_int() > 0:
				return val.to_int()
		elif a.begins_with("--physics-ticks="):
			var val := a.substr(16).strip_edges()
			if val.is_valid_int() and val.to_int() > 0:
				return val.to_int()
		elif a.begins_with("--ticks="):
			var val := a.substr(8).strip_edges()
			if val.is_valid_int() and val.to_int() > 0:
				return val.to_int()
	return default_ticks

## Verifica se o protocolo WebSocket foi requisitado
static func parse_use_websocket(args: PackedStringArray) -> bool:
	for a in args:
		if a == "--ws" or a == "--websocket":
			return true
	return false

## Inicializa o NetworkManager no modo servidor, limita FPS e taxa de física da Engine e troca de cena
func boot_server(port: int, use_ws: bool = false, max_fps: int = DEFAULT_SERVER_FPS, physics_ticks: int = DEFAULT_PHYSICS_TICKS) -> void:
	OS.low_processor_usage_mode = true
	Engine.max_fps = max_fps
	Engine.physics_ticks_per_second = physics_ticks
	print("========================================================")
	print("🚀 [DedicatedServerBoot] MODO SERVIDOR DEDICADO ATIVO")
	print("   Porta: %d | Protocolo: %s | Max FPS: %d | Physics: %d Hz | Low CPU: Ativo" % [
		port,
		"WebSocket" if use_ws else "ENet (UDP)",
		max_fps,
		physics_ticks
	])
	print("========================================================")

	var net: Node = get_node_or_null("/root/NetworkManager")
	if net != null:
		var err: int = net.start_server(port, 32, use_ws)
		if err != OK:
			push_error("[DedicatedServerBoot] Falha ao iniciar servidor na porta %d (erro: %d)" % [port, err])
			return
		print("[DedicatedServerBoot] Servidor iniciado com sucesso via NetworkManager (limite 32 jogadores).")

	call_deferred("_change_to_server_scene")

func _change_to_server_scene() -> void:
	if ResourceLoader.exists(SERVER_WORLD_SCENE):
		print("[DedicatedServerBoot] Trocando para cena mínima: %s" % SERVER_WORLD_SCENE)
		get_tree().change_scene_to_file(SERVER_WORLD_SCENE)
	else:
		print("[DedicatedServerBoot] Cena de servidor não encontrada, usando res://scenes/world.tscn")
		get_tree().change_scene_to_file("res://scenes/world.tscn")
