extends SceneTree

## Probe para validação de conectividade UDP/ENet com o servidor dedicado live em jogar.tarciso.dev:8787

const NetworkManagerClass = preload("res://scripts/core/network_manager.gd")

const HOST: String = "jogar.tarciso.dev"
const PORT: int = 8787
const TIMEOUT_SEC: float = 10.0

var _net: NetworkManagerAutoload
var _time_elapsed: float = 0.0
var _started: bool = false
var _connected: bool = false

func _process(delta: float) -> bool:
	if not _started:
		_started = true
		_start_probe()
		return false

	_time_elapsed += delta
	if not _connected and _time_elapsed >= TIMEOUT_SEC:
		print("❌ TIMEOUT: Não foi possível conectar a %s:%d após %.1f segundos." % [HOST, PORT, TIMEOUT_SEC])
		print("Verifique se as portas 8787/udp e 8787/tcp estão liberadas no ufw e no firewall da Hostinger.")
		quit(1)
		return true

	return false

func _start_probe() -> void:
	print("========================================================")
	print("🌐 TESTE DE CONECTIVIDADE COM SERVIDOR DEDICADO REMOTO")
	print("Alvo: %s:%d (ENet / UDP)" % [HOST, PORT])
	print("========================================================")

	_net = NetworkManagerClass.new()
	_net.name = "NetworkManager"
	root.add_child(_net)

	_net.connection_established.connect(_on_connected)
	_net.connection_lost.connect(_on_failed)

	var err := _net.start_client(HOST, PORT)
	if err != OK:
		print("❌ Erro imediato ao iniciar cliente: %d" % err)
		quit(1)
		return

	print("📡 Enviando pacotes UDP de handshake ENet para %s:%d..." % [HOST, PORT])

func _on_connected() -> void:
	_connected = true
	var mp := root.get_multiplayer()
	var my_id := mp.get_unique_id()
	print("\n🎉 SUCESSO: CONEXÃO ESTABELECIDA COM O SERVIDOR DEDICADO!")
	print("  - Host: %s:%d" % [HOST, PORT])
	print("  - Protocolo: ENet / UDP")
	print("  - Peer ID atribuído pelo servidor: %d" % my_id)
	print("  - Latência de conexão: %.2f segundos" % _time_elapsed)
	print("========================================================\n")
	_net.cleanup_peer()
	quit(0)

func _on_failed() -> void:
	if not _connected:
		print("❌ Falha na conexão ENet com %s:%d." % [HOST, PORT])
		quit(1)
