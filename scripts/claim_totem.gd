class_name ClaimTotem
extends StaticBody3D

## Totem de Território (Estaca de Reivindicação do Rancho / Guilda)
## Demarca uma área circular de posse onde o jogador constrói livremente.
## Integra Cofre de Manutenção, Decaimento em Ruína e Desmanche Público (GDD-08 §4, §8 Decisão 7, GDD-05 §5).

const BuildablePieceClass = preload("res://scripts/buildable_piece.gd")
const _BuildingSystem = preload("res://scripts/building_system.gd")
const _TerritoryScreen = preload("res://scripts/ui/territory_screen.gd")
const _WalletComponent = preload("res://scripts/components/wallet_component.gd")

const DISPLAY_NAME: String = "Totem de Território"
const COSTS: Dictionary = { &"madeira": 4, &"pedra": 4 }
const SIZE: Vector3 = Vector3(0.8, 2.4, 0.8)
const DEFAULT_RADIUS: float = 14.0

## Manutenção Territorial (GDD-08 §4, §8 Decisão 7, GDD-05 §5)
const DAILY_UPKEEP: int = 5 ## 5 $S por dia de jogo
const MAX_FUNDS: int = 250 ## Cofre comporta até 50 dias de manutenção (ralo de moeda)
const GRACE_PERIOD_DAYS: float = 3.0 ## Tolerância de dias sem fundos antes de virar Ruína

enum Status {
	ACTIVE,      ## Cofre abastecido (> 0 $S), base protegida
	VULNERABLE,  ## Cofre zerado, período de carência ativo (3 dias)
	ABANDONED    ## Carência esgotada: ruína aberta para saque e desmanche público (25% sucata)
}

@export var owner_name: String = "Andarilho"
@export var guild_name: String = ""
@export var radius: float = DEFAULT_RADIUS
## Ticks (ms) de quando foi fincado; -1 = sem janela de reembolso total
var placed_at_msec: int = -1

@export var maintenance_funds: int = 25 ## Começa com 25 $S (5 dias de proteção inclusos)
@export var grace_days_elapsed: float = 0.0
var status: Status = Status.ACTIVE
var allowed_builders: Array[String] = []

var label_prompt: Label3D
var ring_mesh: MeshInstance3D
var ring_mat: StandardMaterial3D
var crystal_mesh: MeshInstance3D
var crystal_mat: StandardMaterial3D
var crystal_light: OmniLight3D

func _ready() -> void:
	add_to_group("claim_totems")
	add_to_group("talkable")
	
	_build_visual()
	_build_boundary_ring()
	_build_label()
	_update_status()
	
	# Registra no ZoneManager se estiver presente na árvore
	var zm := _get_zone_manager()
	if zm and zm.has_method("register_totem"):
		zm.register_totem(self)

func _exit_tree() -> void:
	var zm := _get_zone_manager()
	if zm and zm.has_method("unregister_totem"):
		zm.unregister_totem(self)

func _get_zone_manager() -> Node:
	if not is_inside_tree():
		return null
	var node := get_tree().get_first_node_in_group("zone_manager")
	if node == null and get_node_or_null("/root/ZoneManager") != null:
		node = get_node_or_null("/root/ZoneManager")
	return node

func _build_visual() -> void:
	# Colisão do Totem
	var col := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.35
	cyl.height = 2.4
	col.shape = cyl
	col.position.y = 1.2
	add_child(col)
	
	# Base de pedra
	var base := MeshInstance3D.new()
	var base_mesh := CylinderMesh.new()
	base_mesh.top_radius = 0.5
	base_mesh.bottom_radius = 0.65
	base_mesh.height = 0.5
	base.mesh = base_mesh
	base.position.y = 0.25
	var stone_mat := StandardMaterial3D.new()
	stone_mat.albedo_color = Color(0.42, 0.42, 0.45)
	stone_mat.roughness = 0.95
	base.material_override = stone_mat
	add_child(base)
	
	# Poste de tora entalhada
	var pole := MeshInstance3D.new()
	var pole_mesh := CylinderMesh.new()
	pole_mesh.top_radius = 0.24
	pole_mesh.bottom_radius = 0.28
	pole_mesh.height = 2.0
	pole.mesh = pole_mesh
	pole.position.y = 1.3
	var wood_mat := StandardMaterial3D.new()
	wood_mat.albedo_color = Color(0.38, 0.24, 0.14)
	wood_mat.roughness = 0.85
	pole.material_override = wood_mat
	add_child(pole)
	
	# Cristal / Luz no topo do totem
	crystal_mesh = MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(0.35, 0.45, 0.35)
	crystal_mesh.mesh = prism
	crystal_mesh.position.y = 2.4
	
	crystal_mat = StandardMaterial3D.new()
	crystal_mat.albedo_color = Color(0.2, 0.85, 0.6)
	crystal_mat.emission_enabled = true
	crystal_mat.emission = Color(0.15, 0.95, 0.65)
	crystal_mat.emission_energy_multiplier = 1.5
	crystal_mesh.material_override = crystal_mat
	add_child(crystal_mesh)
	
	crystal_light = OmniLight3D.new()
	crystal_light.light_color = Color(0.3, 0.9, 0.65)
	crystal_light.light_energy = 0.8
	crystal_light.omni_range = 5.0
	crystal_light.position.y = 2.4
	add_child(crystal_light)

func _build_boundary_ring() -> void:
	ring_mesh = MeshInstance3D.new()
	ring_mesh.name = "PerimeterRing"
	
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_LINES)
	
	var segments := 48
	for i in segments:
		var a0 := TAU * float(i) / float(segments)
		var a1 := TAU * float(i + 1) / float(segments)
		var p0 := Vector3(cos(a0) * radius, 0.1, sin(a0) * radius)
		var p1 := Vector3(cos(a1) * radius, 0.1, sin(a1) * radius)
		st.set_color(Color(0.2, 0.9, 0.6, 0.45))
		st.add_vertex(p0)
		st.set_color(Color(0.2, 0.9, 0.6, 0.45))
		st.add_vertex(p1)
	
	ring_mesh.mesh = st.commit()
	ring_mat = StandardMaterial3D.new()
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.vertex_color_use_as_albedo = true
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mesh.material_override = ring_mat
	ring_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring_mesh)

func _build_label() -> void:
	label_prompt = Label3D.new()
	label_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label_prompt.font_size = 22
	label_prompt.outline_size = 5
	label_prompt.outline_modulate = Color(0, 0, 0, 0.9)
	label_prompt.modulate = Color(0.7, 1.0, 0.85)
	label_prompt.visibility_range_end = 12.0
	label_prompt.position.y = 2.85
	add_child(label_prompt)
	_update_label()

func _update_label() -> void:
	if label_prompt:
		var g_text := " [%s]" % guild_name if not guild_name.is_empty() else ""
		var status_str := ""
		match status:
			Status.ACTIVE:
				var days_left: float = float(maintenance_funds) / float(DAILY_UPKEEP)
				status_str = "🟢 Protegido (%d $S • ~%.1fd)" % [maintenance_funds, days_left]
			Status.VULNERABLE:
				var car_left: float = maxf(0.0, GRACE_PERIOD_DAYS - grace_days_elapsed)
				status_str = "🟡 VULNERÁVEL (0 $S • Carência: %.1fd)" % car_left
			Status.ABANDONED:
				status_str = "🔴 RUÍNA ABANDONADA • Saque Público (25%)"
		label_prompt.text = "🏕️ Território de %s%s\n%s\nRaio: %.0fm • [E] Gerenciar Rancho" % [owner_name, g_text, status_str, radius]

func _update_status() -> void:
	if maintenance_funds > 0:
		status = Status.ACTIVE
		grace_days_elapsed = 0.0
	elif grace_days_elapsed < GRACE_PERIOD_DAYS:
		status = Status.VULNERABLE
	else:
		status = Status.ABANDONED
	_refresh_visuals()
	_update_label()

func _refresh_visuals() -> void:
	if crystal_mat:
		match status:
			Status.ACTIVE:
				crystal_mat.albedo_color = Color(0.2, 0.85, 0.6)
				crystal_mat.emission = Color(0.15, 0.95, 0.65)
				crystal_mat.emission_energy_multiplier = 1.5
			Status.VULNERABLE:
				crystal_mat.albedo_color = Color(0.9, 0.65, 0.2)
				crystal_mat.emission = Color(0.95, 0.6, 0.1)
				crystal_mat.emission_energy_multiplier = 1.2
			Status.ABANDONED:
				crystal_mat.albedo_color = Color(0.4, 0.15, 0.15)
				crystal_mat.emission = Color(0.3, 0.05, 0.05)
				crystal_mat.emission_energy_multiplier = 0.3
	if crystal_light:
		match status:
			Status.ACTIVE:
				crystal_light.light_color = Color(0.3, 0.9, 0.65)
				crystal_light.light_energy = 0.8
			Status.VULNERABLE:
				crystal_light.light_color = Color(0.95, 0.65, 0.2)
				crystal_light.light_energy = 0.6
			Status.ABANDONED:
				crystal_light.light_color = Color(0.5, 0.1, 0.1)
				crystal_light.light_energy = 0.2
	if ring_mat:
		match status:
			Status.ACTIVE:
				ring_mat.albedo_color = Color(0.2, 0.9, 0.6, 0.45)
			Status.VULNERABLE:
				ring_mat.albedo_color = Color(0.95, 0.65, 0.2, 0.5)
			Status.ABANDONED:
				ring_mat.albedo_color = Color(0.6, 0.15, 0.15, 0.25)

## Deposita moedas no cofre de manutenção (do próprio jogador ou direto).
func deposit_maintenance(amount: int, player: Node = null) -> bool:
	if amount <= 0:
		return false
	if player != null:
		var wallet := _get_wallet(player)
		if wallet == null or wallet.money < amount:
			return false
		wallet.spend(amount)
	var paid := mini(amount, MAX_FUNDS - maintenance_funds)
	maintenance_funds = mini(MAX_FUNDS, maintenance_funds + amount)
	if player != null and paid > 0:
		EventBusAutoload.report(player, &"manutencao", {"money": paid})
	grace_days_elapsed = 0.0
	_update_status()
	return true

## Retira moedas do cofre (apenas o dono).
func withdraw_maintenance(amount: int, player: Node = null) -> bool:
	if player != null:
		var me := _BuildingSystem.owner_name_of(player)
		if me != owner_name:
			return false
	if amount <= 0 or amount > maintenance_funds:
		return false
	maintenance_funds -= amount
	if player != null:
		var wallet := _get_wallet(player)
		if wallet:
			wallet.add(amount)
		EventBusAutoload.report(player, &"manutencao_retirada", {"money": amount})
	_update_status()
	return true

## Avança a passagem do tempo em dias de jogo e debita o consumo diário
func advance_days(days: float) -> void:
	if days <= 0.0:
		return
	var cost := days * float(DAILY_UPKEEP)
	if float(maintenance_funds) >= cost:
		maintenance_funds -= int(ceil(cost))
	else:
		var days_funded := float(maintenance_funds) / float(DAILY_UPKEEP)
		maintenance_funds = 0
		grace_days_elapsed += (days - days_funded)
	_update_status()

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

## Valida permissão de construção no território
func can_player_build(p_name: String) -> bool:
	if status == Status.ABANDONED or status == Status.VULNERABLE:
		return false
	if p_name == owner_name:
		return true
	if allowed_builders.has(p_name):
		return true
	return false

## Valida permissão de desmanche: dono pode sempre, visitantes apenas se for Ruína Abandonada
func can_player_dismantle(p_name: String) -> bool:
	if status == Status.ABANDONED:
		return true
	if p_name == owner_name:
		return true
	return false

## Gerenciamento da Whitelist de Construtores Autorizados
func add_allowed_builder(p_name: String) -> bool:
	if not p_name.is_empty() and not allowed_builders.has(p_name):
		allowed_builders.append(p_name)
		return true
	return false

func remove_allowed_builder(p_name: String) -> bool:
	if allowed_builders.has(p_name):
		allowed_builders.erase(p_name)
		return true
	return false

## Interação ao apertar [E] perto do totem
func talk_to(player: Node) -> void:
	if player == null or not player.is_inside_tree():
		return
	for menu in player.get_tree().get_nodes_in_group("open_menus"):
		if menu is _TerritoryScreen:
			return
	var screen := _TerritoryScreen.new()
	player.get_tree().root.add_child(screen)
	screen.open(self, player)

## Desmonta o totem (mudar de lugar = desmontar). Quem chama garante que o território está vazio.
func dismantle(player: Node, is_ruin: bool = false) -> Dictionary:
	var ruin_mode := is_ruin or (status == Status.ABANDONED)
	var refunds := BuildablePieceClass.refund_costs(COSTS, placed_at_msec, player, ruin_mode)
	queue_free()
	return refunds

## Serialização para SaveGame
func to_dict() -> Dictionary:
	return {
		"owner": owner_name,
		"guild": guild_name,
		"radius": radius,
		"maintenance_funds": maintenance_funds,
		"grace_days_elapsed": grace_days_elapsed,
		"status": int(status),
		"allowed_builders": allowed_builders.duplicate()
	}

func from_dict(d: Dictionary) -> void:
	if d.has("owner"):
		owner_name = str(d["owner"])
	if d.has("guild"):
		guild_name = str(d["guild"])
	if d.has("radius"):
		radius = float(d["radius"])
	if d.has("maintenance_funds"):
		maintenance_funds = int(d["maintenance_funds"])
	if d.has("grace_days_elapsed"):
		grace_days_elapsed = float(d["grace_days_elapsed"])
	if d.has("allowed_builders") and d["allowed_builders"] is Array:
		allowed_builders.clear()
		for b in d["allowed_builders"]:
			allowed_builders.append(str(b))
	_update_status()
