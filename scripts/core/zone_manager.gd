class_name ZoneManager
extends Node

## Gerenciador Central de Zonas de Território e Regras de Construção (Fase 2)
## Controla Zonas Seguras (Cidade), Zonas de Perigo (Monstros/Arenas),
## Proteção de Estradas/Água e Territórios Reivindicados por Totens de Jogadores/Guildas.

enum ZoneType {
	CITY,         ## Cidade Principal (Segura, sem combate, sem construção livre)
	ROAD,         ## Estradas e caminhos de trânsito livre
	DANGER,       ## Ninhos de feras e arenas de monstros
	WATER,        ## Rios profundos e cachoeiras
	CLAIMED,      ## Território particular reivindicado por Totem
	WILDERNESS,   ## Natureza aberta = zona de Exploração do GDD-08 (liberada para fincar novo Totem)
	WILD_PVP      ## Zona Selvagem do GDD-05 (PvP aberto, full loot): sem construção por enquanto
}

const RiverClass = preload("res://scripts/river_system.gd")
const ClaimTotemClass = preload("res://scripts/claim_totem.gd")

## Totem precisa ficar a esta distância da borda da cidade (GDD-08 §8)
const CITY_BUILD_MARGIN: float = 20.0
## Folga mínima entre as bordas de dois territórios
const CLAIM_GAP: float = 6.0

## Áreas de Zona Selvagem (vazio até o mapa ter uma): { "center": Vector2, "radius": float, "name": String }
const WILD_PVP_ZONES: Array[Dictionary] = []

## Planta da Cidade Principal (Vila da Esperança): elipse da paliçada (B36)
const _VillageLayout = preload("res://scripts/town/village_layout.gd")

## Centros de perigo (Arena de monstros e Morro da Besta)
const DANGER_ZONES: Array[Dictionary] = [
	{ "center": Vector2(-27.0, 3.0), "radius": 10.0, "name": "Arena de Teste" },
	{ "center": Vector2(-5.0, -11.0), "radius": 6.0, "name": "Covil da Besta de Sucata" }
]

## Totens de território ativos no mundo
var active_totems: Array[Node3D] = []

func _ready() -> void:
	add_to_group("zone_manager")

## Registra um novo totem fincado no mundo
func register_totem(totem: Node3D) -> void:
	if not active_totems.has(totem):
		active_totems.append(totem)

## Desregistra um totem removido
func unregister_totem(totem: Node3D) -> void:
	active_totems.erase(totem)

## Retorna o tipo de zona em uma coordenada 3D
func get_zone_at(pos: Vector3) -> ZoneType:
	var p2 := Vector2(pos.x, pos.z)
	
	# 1. Zonas de Perigo dos Monstros (antes da cidade: um covil na borda continua sendo covil)
	for dz in DANGER_ZONES:
		if p2.distance_to(dz["center"]) <= dz["radius"]:
			return ZoneType.DANGER
	
	# 2. Cidade Principal
	if _VillageLayout.in_village(p2.x, p2.y, 0.0):
		return ZoneType.CITY
	
	# 3. Rio e Água Profunda
	if RiverClass.is_in_water(pos):
		return ZoneType.WATER

	# 4. Zona Selvagem (PvP aberto)
	for wz in WILD_PVP_ZONES:
		if p2.distance_to(wz["center"]) <= wz["radius"]:
			return ZoneType.WILD_PVP

	# 5. Território Reivindicado por Totem
	if get_claim_at(pos) != null:
		return ZoneType.CLAIMED
	
	return ZoneType.WILDERNESS

## Retorna o totem que cobre a posição (ou null)
func get_claim_at(pos: Vector3) -> Node3D:
	var p2 := Vector2(pos.x, pos.z)
	for totem in active_totems:
		if is_instance_valid(totem):
			var t_pos := Vector2(totem.global_position.x, totem.global_position.z)
			var r: float = totem.get("radius") if "radius" in totem else 14.0
			if p2.distance_to(t_pos) <= r:
				return totem
	return null

## Define se o combate é permitido na posição. Cidade é Zona de Paz, exceto em duelo aceito (GDD-05).
func can_combat_at(pos: Vector3, in_duel: bool = false) -> bool:
	return in_duel or get_zone_at(pos) != ZoneType.CITY

## Nome descritivo da zona para exibição no HUD
func get_zone_name_at(pos: Vector3) -> String:
	match get_zone_at(pos):
		ZoneType.CITY:
			return "🏛️ Vila da Esperança (Zona Segura)"
		ZoneType.DANGER:
			return "⚠️ Covil Selvagem (Área de Risco)"
		ZoneType.WATER:
			return "🌊 Rio da Cachoeira"
		ZoneType.WILD_PVP:
			return "☠️ Zona Selvagem (PvP aberto)"
		ZoneType.CLAIMED:
			var totem := get_claim_at(pos)
			var owner_name: String = totem.get("owner_name") if totem and "owner_name" in totem else "Andarilho"
			var status_str := ""
			if totem and "status" in totem:
				match totem.get("status"):
					ClaimTotemClass.Status.VULNERABLE:
						status_str = " [Vulnerável]"
					ClaimTotemClass.Status.ABANDONED:
						status_str = " [Ruína Abandonada]"
			return "🏕️ Território de %s%s" % [owner_name, status_str]
		_:
			var reg := WorldSettlements.get_settlement_or_region_at(pos)
			if not reg.is_empty():
				return reg
			return "🌲 Terras Selvagens"

## Valida se é permitido construir nesta posição
func can_build_at(pos: Vector3, piece_type: StringName = &"piece", player_name: String = "") -> Dictionary:
	var zone := get_zone_at(pos)
	
	if zone == ZoneType.CITY:
		return {
			"allowed": false,
			"reason": "Zona Urbana: Proibido construir no perímetro da cidade.",
			"zone": zone
		}
	
	if zone == ZoneType.WATER:
		return {
			"allowed": false,
			"reason": "Água Profunda: Fundação inundada no leito do rio.",
			"zone": zone
		}
	
	if zone == ZoneType.DANGER:
		return {
			"allowed": false,
			"reason": "Covil Selvagem: O perigo imediato de monstros impede construções.",
			"zone": zone
		}
	
	if zone == ZoneType.WILD_PVP:
		return {
			"allowed": false,
			"reason": "Zona Selvagem: Ninguém ergue base onde reina o saque.",
			"zone": zone
		}

	# Se for o Totem de Território sendo colocado na Natureza:
	if piece_type == &"claim_totem":
		return _check_new_totem(pos, player_name, zone)
	
	# Para peças normais (paredes, pisos, telhados, canteiros):
	var claim := get_claim_at(pos)
	if claim == null:
		return {
			"allowed": false,
			"reason": "Terra de Ninguém: Finque um Totem de Território antes de erguer estruturas.",
			"zone": zone
		}
	
	# Validação de posse e manutenção do Totem (GDD-08 §4, §8, GDD-05 §5)
	if claim.has_method("can_player_build"):
		if not claim.can_player_build(player_name):
			var c_status = claim.get("status")
			if c_status == ClaimTotemClass.Status.ABANDONED:
				return {
					"allowed": false,
					"reason": "Ruína Abandonada: Manutenção territorial vencida. Desmanche a ruína antes de erguer novas estruturas.",
					"zone": zone
				}
			elif c_status == ClaimTotemClass.Status.VULNERABLE:
				return {
					"allowed": false,
					"reason": "Território Vulnerável: Cofre zerado. Abasteça o totem de território para voltar a construir.",
					"zone": zone
				}
			return {
				"allowed": false,
				"reason": "Propriedade Privada: Território pertence a %s." % claim.get("owner_name"),
				"zone": zone
			}
	elif claim.has_method("can_member_build"):
		if not claim.can_member_build(player_name):
			return {
				"allowed": false,
				"reason": "Território de Guilda: Apenas membros autorizados podem construir aqui.",
				"zone": zone
			}
	else:
		var owner_of_claim: String = claim.get("owner_name") if "owner_name" in claim else ""
		if not owner_of_claim.is_empty() and not player_name.is_empty() and owner_of_claim != player_name:
			return {
				"allowed": false,
				"reason": "Propriedade Privada: Território pertence a %s." % owner_of_claim,
				"zone": zone
			}
	
	return { "allowed": true, "reason": "Construção permitida dentro do território!", "zone": zone }

## Regras de um novo totem (GDD-08 §8): 1 por dono, longe da cidade, folga entre territórios.
func _check_new_totem(pos: Vector3, player_name: String, zone: ZoneType) -> Dictionary:
	var p2 := Vector2(pos.x, pos.z)
	var r_new: float = ClaimTotemClass.DEFAULT_RADIUS
	
	if _VillageLayout.edge_distance(p2.x, p2.y) < CITY_BUILD_MARGIN:
		return {
			"allowed": false,
			"reason": "Arredores da Vila: Finque o totem a pelo menos %.0fm da cidade." % CITY_BUILD_MARGIN,
			"zone": zone
		}
	
	for totem in active_totems:
		if not is_instance_valid(totem) or totem.is_queued_for_deletion():
			continue
		var t_owner: String = totem.get("owner_name") if "owner_name" in totem else ""
		if not player_name.is_empty() and t_owner == player_name:
			return {
				"allowed": false,
				"reason": "Um só território: Desmonte seu totem atual para mudar de lugar.",
				"zone": zone
			}
		var t_pos := Vector2(totem.global_position.x, totem.global_position.z)
		var r: float = totem.get("radius") if "radius" in totem else ClaimTotemClass.DEFAULT_RADIUS
		if p2.distance_to(t_pos) - r - r_new < CLAIM_GAP:
			return {
				"allowed": false,
				"reason": "Vizinho perto demais: Territórios precisam de %.0fm de folga." % CLAIM_GAP,
				"zone": zone
			}
	
	return { "allowed": true, "reason": "Área selvagem livre para novo território!", "zone": zone }
