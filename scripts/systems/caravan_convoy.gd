class_name CaravanConvoy
extends CharacterBody3D
const _LedgerSources = preload("res://scripts/net/ledger_sources.gd")

## Comboio de Caravana Itinerante & Escolta Armada (GDD-05 §2, §5; GDD-11).
## Caravana de mercadores que viaja fisicamente entre assentamentos pelas estradas do vale.
## O jogador pode se alistar como escolta militar, defender o comboio contra emboscadas
## e receber recompensas substanciais em $S, reputação e XP ao alcançar o destino.

const _WalletComponent = preload("res://scripts/components/wallet_component.gd")

signal convoy_status_changed(new_status: ConvoyStatus)
signal ambush_started(convoy: CaravanConvoy, threat_name: String)
signal ambush_defeated(convoy: CaravanConvoy)
signal convoy_arrived(convoy: CaravanConvoy, destination_id: StringName)
signal convoy_destroyed(convoy: CaravanConvoy)

enum ConvoyStatus {
	IDLE,           ## Aguardando partida no entreposto
	TRAVELING,      ## Em marcha pelas estradas sinalizadas
	UNDER_ATTACK,   ## Sob emboscada inimiga (parada para defesa)
	ARRIVED,        ## Chegada segura ao entreposto de destino
	DESTROYED       ## Cargas destruídas / saqueadas
}

@export var origin_id: StringName = &"vila_esperanca"
@export var destination_id: StringName = &"porto_bruma"
@export var speed: float = 3.5
@export var max_health: float = 300.0
var current_health: float = 300.0
var status: ConvoyStatus = ConvoyStatus.IDLE
var bounty_reward: int = 40 ## Recompensa padrão de escolta

var waypoints: Array[Vector3] = []
var current_waypoint_idx: int = 0
var escorting_players: Array[Node] = []
var active_attackers: int = 0

var cart_mesh: MeshInstance3D
var label_overhead: Label3D

func _ready() -> void:
	add_to_group("caravans")
	_build_visual()
	_build_label()

func start_journey(p_waypoints: Array[Vector3], p_origin: StringName, p_dest: StringName) -> void:
	waypoints = p_waypoints
	origin_id = p_origin
	destination_id = p_dest
	current_waypoint_idx = 0
	current_health = max_health
	active_attackers = 0
	status = ConvoyStatus.TRAVELING
	if not waypoints.is_empty():
		global_position = waypoints[0]
	_update_label()
	convoy_status_changed.emit(status)

func add_escort_player(player: Node) -> bool:
	if player and not escorting_players.has(player):
		escorting_players.append(player)
		_notify_player(player, "🛡️ Alistado como Escolta da Caravana! Defenda o comboio até o destino.")
		return true
	return false

func remove_escort_player(player: Node) -> void:
	escorting_players.erase(player)

func _physics_process(delta: float) -> void:
	if status == ConvoyStatus.TRAVELING:
		_process_movement(delta)

func _process_movement(delta: float) -> void:
	if waypoints.is_empty() or current_waypoint_idx >= waypoints.size():
		_reach_destination()
		return
	
	var target := waypoints[current_waypoint_idx]
	var dir := (target - global_position)
	dir.y = 0.0 # Mantém no plano horizontal
	
	if dir.length() < 1.0:
		current_waypoint_idx += 1
		if current_waypoint_idx >= waypoints.size():
			_reach_destination()
			return
		target = waypoints[current_waypoint_idx]
		dir = (target - global_position)
		dir.y = 0.0
	
	var move_vec := dir.normalized() * speed
	velocity.x = move_vec.x
	velocity.z = move_vec.z
	move_and_slide()
	
	if dir.length_squared() > 0.01:
		rotation.y = atan2(-dir.x, -dir.z)

## Dispara uma emboscada na rota
func trigger_ambush(threat_name: String, attacker_count: int = 3) -> void:
	if status != ConvoyStatus.TRAVELING:
		return
	status = ConvoyStatus.UNDER_ATTACK
	active_attackers = attacker_count
	velocity = Vector3.ZERO
	_update_label()
	
	for p in escorting_players:
		_notify_player(p, "⚠️ EMBOSCADA! %s atacando a caravana! Defenda o comboio!" % threat_name)
	
	ambush_started.emit(self, threat_name)
	convoy_status_changed.emit(status)

## Notifica abate de um salteador/fera da emboscada
func report_attacker_defeated() -> void:
	if status != ConvoyStatus.UNDER_ATTACK:
		return
	active_attackers = maxi(0, active_attackers - 1)
	if active_attackers == 0:
		status = ConvoyStatus.TRAVELING
		_update_label()
		for p in escorting_players:
			_notify_player(p, "⚔️ Emboscada repelida com bravura! A caravana retoma a marcha.")
		ambush_defeated.emit(self)
		convoy_status_changed.emit(status)

## Aplica dano sofrido pela caravana
func take_damage(amount: float) -> void:
	if status == ConvoyStatus.ARRIVED or status == ConvoyStatus.DESTROYED:
		return
	current_health = maxf(0.0, current_health - amount)
	_update_label()
	
	if current_health <= 0.0:
		status = ConvoyStatus.DESTROYED
		_update_label()
		for p in escorting_players:
			_notify_player(p, "💀 A Caravana foi destruída e as cargas foram perdidas!")
		convoy_destroyed.emit(self)
		convoy_status_changed.emit(status)

func _reach_destination() -> void:
	# Cliente online: o que esta troca gasta e dá vai ao servidor como uma fonte só (B41 fase 3)
	_LedgerSources.gain(&"caravan", name, func(): _reach_destination_body())

func _reach_destination_body() -> void:
	status = ConvoyStatus.ARRIVED
	velocity = Vector3.ZERO
	_update_label()
	
	# Paga recompensa de escolta para todos os jogadores acompanhantes
	for p in escorting_players:
		var wallet := _get_wallet(p)
		if wallet:
			wallet.add(bounty_reward)
		_notify_player(p, "🎉 Caravana chegou em segurança a %s! Recompensa recebida: +%d $S." % [String(destination_id).capitalize(), bounty_reward])
	
	convoy_arrived.emit(self, destination_id)
	convoy_status_changed.emit(status)

func _build_visual() -> void:
	# Colisão de carroça
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.0, 1.6, 3.2)
	col.shape = box
	col.position.y = 0.8
	add_child(col)
	
	# Carreta / Carroça de madeira
	cart_mesh = MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.8, 1.2, 3.0)
	cart_mesh.mesh = mesh
	cart_mesh.position.y = 0.8
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.40, 0.28, 0.16)
	cart_mesh.material_override = mat
	add_child(cart_mesh)
	
	# Toldos e fardos empilhados
	var cargo := MeshInstance3D.new()
	var cargo_mesh := BoxMesh.new()
	cargo_mesh.size = Vector3(1.6, 0.8, 2.6)
	cargo.mesh = cargo_mesh
	cargo.position.y = 1.5
	var cargo_mat := StandardMaterial3D.new()
	cargo_mat.albedo_color = Color(0.85, 0.76, 0.55) # Lona de juta
	cargo.material_override = cargo_mat
	add_child(cargo)
	
	# Lanterna guia
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.8, 0.4)
	light.light_energy = 1.2
	light.omni_range = 6.0
	light.position = Vector3(0, 1.8, -1.6)
	add_child(light)

func _build_label() -> void:
	label_overhead = Label3D.new()
	label_overhead.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label_overhead.font_size = 20
	label_overhead.outline_size = 6
	label_overhead.outline_modulate = Color(0, 0, 0, 0.9)
	label_overhead.visibility_range_end = 25.0
	label_overhead.position.y = 2.4
	add_child(label_overhead)
	_update_label()

func _update_label() -> void:
	if label_overhead:
		var status_str := ""
		match status:
			ConvoyStatus.IDLE:
				status_str = "Aguardando Partida"
			ConvoyStatus.TRAVELING:
				status_str = "Em Marcha para %s" % String(destination_id).capitalize()
			ConvoyStatus.UNDER_ATTACK:
				status_str = "⚠️ SOB ATAQUE! (%d inimigos)" % active_attackers
			ConvoyStatus.ARRIVED:
				status_str = "✅ Chegada Concluída"
			ConvoyStatus.DESTROYED:
				status_str = "💀 Destruída"
		label_overhead.text = "🛡️ Caravana Mercante\nIntegridade: %.0f/%.0f HP\n[%s]" % [current_health, max_health, status_str]

func _get_wallet(player: Node) -> _WalletComponent:
	if player == null:
		return null
	if player.has_meta("wallet") and player.get_meta("wallet") is _WalletComponent:
		return player.get_meta("wallet") as _WalletComponent
	if player.get("wallet") is _WalletComponent:
		return player.get("wallet") as _WalletComponent
	var comp = player.get_node_or_null("WalletComponent") as _WalletComponent
	if comp:
		return comp
	for c in player.get_children():
		if c is _WalletComponent:
			return c as _WalletComponent
	return null

func _notify_player(player: Node, msg: String) -> void:
	if player and player.has_signal("posture_changed"):
		player.posture_changed.emit(msg)
