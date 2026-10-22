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
	WILDERNESS    ## Natureza aberta (liberada para fincar novo Totem)
}

const RiverClass = preload("res://scripts/river_system.gd")

## Centro e raio da Cidade Principal (Vila da Esperança)
const CITY_CENTER: Vector2 = Vector2(1.5, 4.5)
const CITY_RADIUS: float = 16.5

## Centros de perigo (Arena de monstros e Morro da Besta)
const DANGER_ZONES: Array[Dictionary] = [
	{ "center": Vector2(-17.0, 6.0), "radius": 14.0, "name": "Arena de Teste" },
	{ "center": Vector2(-3.5, -6.5), "radius": 9.5, "name": "Covil da Besta de Sucata" }
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
	
	# 1. Cidade Principal
	if p2.distance_to(CITY_CENTER) <= CITY_RADIUS:
		return ZoneType.CITY
	
	# 2. Zonas de Perigo dos Monstros
	for dz in DANGER_ZONES:
		if p2.distance_to(dz["center"]) <= dz["radius"]:
			return ZoneType.DANGER
	
	# 3. Rio e Água Profunda
	if RiverClass.is_in_water(pos):
		return ZoneType.WATER
	
	# 4. Território Reivindicado por Totem
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

## Define se o combate é permitido na posição (Cidade é Zona de Paz)
func can_combat_at(pos: Vector3) -> bool:
	return get_zone_at(pos) != ZoneType.CITY

## Nome descritivo da zona para exibição no HUD
func get_zone_name_at(pos: Vector3) -> String:
	match get_zone_at(pos):
		ZoneType.CITY:
			return "🏛️ Vila da Esperança (Zona Segura)"
		ZoneType.DANGER:
			return "⚠️ Covil Selvagem (Área de Risco)"
		ZoneType.WATER:
			return "🌊 Rio da Cachoeira"
		ZoneType.CLAIMED:
			var totem := get_claim_at(pos)
			var owner_name: String = totem.get("owner_name") if totem and "owner_name" in totem else "Andarilho"
			return "🏕️ Território de %s" % owner_name
		_:
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
	
	# Se for o Totem de Território sendo colocado na Natureza:
	if piece_type == &"claim_totem":
		var existing := get_claim_at(pos)
		if existing != null:
			return {
				"allowed": false,
				"reason": "Sobreposição: Já existe um território reivindicado aqui.",
				"zone": zone
			}
		return { "allowed": true, "reason": "Área selvagem livre para novo território!", "zone": zone }
	
	# Para peças normais (paredes, pisos, telhados, canteiros):
	var claim := get_claim_at(pos)
	if claim == null:
		return {
			"allowed": false,
			"reason": "Terra de Ninguém: Finque um Totem de Território antes de erguer estruturas.",
			"zone": zone
		}
	
	# Validação de posse do Totem (se houver dono)
	var owner_of_claim: String = claim.get("owner_name") if "owner_name" in claim else ""
	if not owner_of_claim.is_empty() and not player_name.is_empty() and owner_of_claim != player_name:
		return {
			"allowed": false,
			"reason": "Propriedade Privada: Território pertence a %s." % owner_of_claim,
			"zone": zone
		}
	
	return { "allowed": true, "reason": "Construção permitida dentro do território!", "zone": zone }
