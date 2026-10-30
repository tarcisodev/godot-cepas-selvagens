class_name GuildData
extends Resource

const _Self = preload("res://scripts/data/guild_data.gd")
const _GuildLedger = preload("res://scripts/data/guild_ledger.gd")

## Dados e Heráldica da Guilda (GDD-15).
## Armazena identificação, brasão heráldico, membros com cargos, nível da sede (1 a 3),
## raio de território e progresso de contribuição comunitária.

enum Role { RECRUIT, MEMBER, OFFICER, LEADER }
enum Occasion { PERSONAL, GALA, WAR }

const EMBLEMS: Dictionary = {
	&"lobo": {"icon": "🐺", "name": "Cabeça de Lobo"},
	&"rinolito": {"icon": "🦏", "name": "Chifre de Rinolito"},
	&"pinheira": {"icon": "🌲", "name": "Pinheira Flamejante"},
	&"espadas": {"icon": "⚔️", "name": "Espadas Cruzadas"},
	&"ancora": {"icon": "⚓", "name": "Âncora do Rio"},
	&"falcao": {"icon": "🦅", "name": "Falcão Real"}
}

## Requisitos de doação para evolução da sede (GDD-15 §2)
const LEVEL_UP_REQUIREMENTS: Dictionary = {
	2: { &"madeira": 40, &"pedra": 30, &"barra_ferro": 10 },
	3: { &"pedra": 80, &"barra_ferro": 40, &"quartzo_lume": 15 }
}

## Raio do território por nível da sede (GDD-15 §1)
const TERRITORY_RADIUS_BY_LEVEL: Dictionary = {
	1: 40.0,
	2: 60.0,
	3: 80.0
}

@export var id: StringName = &""
@export var name: String = ""
@export var tag: String = ""
@export var motto: String = ""
@export var primary_color: Color = Color(0.55, 0.12, 0.14)   # Vinho heráldico padrão
@export var secondary_color: Color = Color(0.85, 0.72, 0.25) # Ouro heráldico padrão
@export var emblem_id: StringName = &"lobo"
@export var level: int = 1
@export var members: Dictionary = {}   # String (username) -> int (Role)
@export var donations: Dictionary = {} # StringName (material_id) -> int (amount)
## Livro do Totem: quem deu o quê, por semana (GDD-19 §7)
var book: _GuildLedger = _GuildLedger.new()

func _init(p_id: StringName = &"", p_name: String = "", p_tag: String = "") -> void:
	id = p_id
	name = p_name
	tag = p_tag

## Retorna o raio atual do território em metros
func get_territory_radius() -> float:
	return float(TERRITORY_RADIUS_BY_LEVEL.get(level, 40.0))

## Retorna o ícone do emblema heráldico
func get_emblem_icon() -> String:
	return EMBLEMS.get(emblem_id, {}).get("icon", "⚔️")

## Adiciona ou atualiza membro na guilda
func add_member(username: String, role: Role = Role.RECRUIT) -> void:
	if not username.is_empty():
		members[username] = int(role)

## Remove membro da guilda
func remove_member(username: String) -> void:
	members.erase(username)

## Altera o cargo de um membro
func set_member_role(username: String, role: Role) -> void:
	if members.has(username):
		members[username] = int(role)

## Verifica se o jogador é membro da guilda
func is_member(username: String) -> bool:
	return members.has(username)

## Verifica se o membro possui permissão de construir ou gerenciar (Membro ou superior)
func can_build(username: String) -> bool:
	if not members.has(username):
		return false
	var r: int = int(members[username])
	return r >= int(Role.MEMBER)

## Verifica se o membro é oficial ou líder
func is_officer_or_leader(username: String) -> bool:
	if not members.has(username):
		return false
	var r: int = int(members[username])
	return r >= int(Role.OFFICER)

## Retorna o nome amigável do cargo
static func role_name(role: int) -> String:
	match role:
		Role.LEADER: return "Mestre / Líder"
		Role.OFFICER: return "Oficial"
		Role.MEMBER: return "Membro"
		_: return "Recruta"

## Adiciona doação de material para a sede
func add_donation(mat_id: StringName, amount: int) -> bool:
	if amount <= 0 or level >= 3:
		return false
	var reqs: Dictionary = LEVEL_UP_REQUIREMENTS.get(level + 1, {})
	if not reqs.has(mat_id):
		return false
	var current: int = int(donations.get(mat_id, 0))
	var needed: int = int(reqs.get(mat_id, 0))
	var take := mini(amount, needed - current)
	if take <= 0:
		return false
	donations[mat_id] = current + take
	_check_level_up()
	return true

## Verifica se todos os materiais foram atingidos para avançar de nível
func _check_level_up() -> void:
	if level >= 3:
		return
	var reqs: Dictionary = LEVEL_UP_REQUIREMENTS.get(level + 1, {})
	var complete := true
	for mat_id in reqs:
		if int(donations.get(mat_id, 0)) < int(reqs[mat_id]):
			complete = false
			break
	if complete:
		level += 1
		donations.clear()

## Serialização para Save e Rede
func to_dict() -> Dictionary:
	var members_dict: Dictionary = {}
	for u in members:
		members_dict[u] = int(members[u])
	var donations_dict: Dictionary = {}
	for m in donations:
		donations_dict[String(m)] = int(donations[m])
	return {
		"id": String(id),
		"name": name,
		"tag": tag,
		"motto": motto,
		"primary_color": primary_color.to_html(),
		"secondary_color": secondary_color.to_html(),
		"emblem_id": String(emblem_id),
		"level": level,
		"members": members_dict,
		"donations": donations_dict,
		"book": book.to_dict()
	}

static func from_dict(d: Dictionary) -> Resource:
	var g := _Self.new(StringName(d.get("id", "")), d.get("name", ""), d.get("tag", ""))
	g.motto = d.get("motto", "")
	if d.has("primary_color"):
		g.primary_color = Color.from_string(d.get("primary_color", ""), g.primary_color)
	if d.has("secondary_color"):
		g.secondary_color = Color.from_string(d.get("secondary_color", ""), g.secondary_color)
	g.emblem_id = StringName(d.get("emblem_id", "lobo"))
	g.level = int(d.get("level", 1))
	var m_dict: Dictionary = d.get("members", {})
	for u in m_dict:
		g.members[String(u)] = int(m_dict[u])
	var d_dict: Dictionary = d.get("donations", {})
	for m in d_dict:
		g.donations[StringName(m)] = int(d_dict[m])
	g.book.from_dict(d.get("book", {}))
	return g
