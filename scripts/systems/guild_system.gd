class_name GuildSystem
extends RefCounted

const _Self = preload("res://scripts/systems/guild_system.gd")
const _GuildData = preload("res://scripts/data/guild_data.gd")

## Gerenciador Central de Guildas e Heráldica (GDD-15).
## Mantém o registro de todas as guildas ativas, membros, sede e territórios.

static var _instance = null
var guilds: Dictionary = {} # StringName -> _GuildData

static func get_instance() -> RefCounted:
	if _instance == null:
		_instance = _Self.new()
	return _instance

## Registra ou cria uma nova guilda
func create_guild(
	p_id: StringName,
	p_name: String,
	p_tag: String,
	leader_username: String,
	prim_color: Color = Color(0.55, 0.12, 0.14),
	sec_color: Color = Color(0.85, 0.72, 0.25),
	emblem: StringName = &"lobo"
) -> _GuildData:
	if guilds.has(p_id):
		return guilds[p_id]
	
	var g := _GuildData.new(p_id, p_name, p_tag)
	g.primary_color = prim_color
	g.secondary_color = sec_color
	g.emblem_id = emblem
	g.add_member(leader_username, _GuildData.Role.LEADER)
	guilds[p_id] = g
	return g

## Busca guilda por ID
func get_guild(p_id: StringName) -> _GuildData:
	return guilds.get(p_id, null)

## Busca a guilda a qual um jogador pertence
func get_player_guild(username: String) -> _GuildData:
	if username.is_empty():
		return null
	for g in guilds.values():
		if g.is_member(username):
			return g
	return null

## Serialização para Save e Servidor Dedicado
func to_array() -> Array:
	var out: Array = []
	for g in guilds.values():
		out.append(g.to_dict())
	return out

func load_from_array(data: Array) -> void:
	guilds.clear()
	for d in data:
		if d is Dictionary:
			var g := _GuildData.from_dict(d)
			guilds[g.id] = g
