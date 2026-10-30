class_name DiaryComponent
extends Node

const _FeatLedger = preload("res://scripts/data/feat_ledger.gd")
const _ForgedItem = preload("res://scripts/data/forged_item.gd")
const _HitEvent = preload("res://scripts/data/hit_event.gd")

## Diário do Caçador (GDD-19 §4 e §5, B40 fase 1).
## Escuta o EventBus (ADR-0003) e escreve no FeatLedger do dono: contadores, abates,
## assistências e quedas. Só quem tem autoridade escreve (ADR-0002); o cliente só lê.

signal page_written(page: Dictionary)

## Acertou o alvo nesse intervalo antes da queda dele e outro deu o golpe final: assistência
const ASSIST_WINDOW: float = 15.0

var ledger: _FeatLedger = _FeatLedger.new()

## Alvos que o dono acertou: id da instância -> {t, damage, damage_type, weapon, parts, last_damage}
var _hits_dealt: Dictionary = {}
## Outros jogadores que acertaram cada alvo, mesmo antes do dono: id -> {nome -> t}
var _other_hitters: Dictionary = {}
## Último golpe que o dono levou: {damage, damage_type, part, who, weapon}
var _last_taken: Dictionary = {}

func _ready() -> void:
	var bus := get_node_or_null("/root/EventBus")
	if bus == null:
		return
	if not bus.hit_resolved.is_connected(_on_hit_resolved):
		bus.hit_resolved.connect(_on_hit_resolved)
	if not bus.entity_defeated.is_connected(_on_entity_defeated):
		bus.entity_defeated.connect(_on_entity_defeated)

func _is_authority() -> bool:
	var net := get_node_or_null("/root/NetworkManager")
	if net and net.has_method("is_server_authoritative"):
		return net.is_server_authoritative()
	return true

static func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

## Listener do EventBus de combate
func _on_hit_resolved(hit: _HitEvent, final_damage: float, is_part_broken: bool) -> void:
	var me := get_parent()
	if hit == null or hit.target == null or me == null or not _is_authority():
		return
	if hit.target == me:
		_last_taken = {
			"damage": final_damage,
			"damage_type": String(DamageType.to_string_name(hit.damage_type)),
			"part": String(hit.part_id),
			"who": describe(hit.attacker),
			"weapon": weapon_of(hit.attacker),
		}
		return
	var id := hit.target.get_instance_id()
	if hit.attacker == me:
		var entry: Dictionary = _hits_dealt.get_or_add(id, {"parts": []})
		entry["t"] = _now()
		entry["damage"] = final_damage
		entry["damage_type"] = String(DamageType.to_string_name(hit.damage_type))
		entry["weapon"] = weapon_of(me)
		if is_part_broken and not entry["parts"].has(String(hit.part_id)):
			entry["parts"].append(String(hit.part_id))
			if not is_player(hit.target):
				ledger.add(&"caca", "partes_quebradas")
	elif is_player(hit.attacker):
		# Outro jogador acertou o alvo: se o dono der o golpe final, entra como ajuda na Página
		_other_hitters.get_or_add(id, {})[describe(hit.attacker)["name"]] = _now()
	if _hits_dealt.has(id):
		# Golpe sem dano em quem já caiu não é o golpe final
		_hits_dealt[id]["last_damage"] = final_damage
	_prune()

## Listener do EventBus de combate
func _on_entity_defeated(entity: Node, killer: Node) -> void:
	var me := get_parent()
	if entity == null or me == null or not _is_authority():
		return
	if entity == me:
		if float(_last_taken.get("damage", 0.0)) > 0.0:
			_write_fall(killer)
		_last_taken = {}
		return
	var id := entity.get_instance_id()
	var entry: Dictionary = _hits_dealt.get(id, {})
	if entry.is_empty() or float(entry.get("last_damage", 0.0)) <= 0.0:
		_other_hitters.erase(id)
		return
	_hits_dealt.erase(id)
	entry["helpers"] = _other_hitters.get(id, {})
	_other_hitters.erase(id)
	if killer == me:
		_write_kill(entity, entry, "abate")
	elif _now() - float(entry.get("t", -INF)) <= ASSIST_WINDOW:
		_write_kill(entity, entry, "assistencia")

func _write_kill(entity: Node, entry: Dictionary, kind: String) -> void:
	var who := describe(entity)
	var helpers: Array[String] = []
	for h in entry.get("helpers", {}):
		if _now() - float(entry["helpers"][h]) <= ASSIST_WINDOW:
			helpers.append(h)
	var page := _page(kind, entity)
	page["who"] = who
	page["with"] = entry.get("weapon", {}).merged({"damage_type": entry.get("damage_type", "")})
	page["parts"] = entry.get("parts", []).duplicate()
	page["helpers"] = helpers
	page["keep"] = who.get("boss", false)
	var player_target: bool = who["kind"] == "jogador"
	var chapter: StringName = &"sangue" if player_target else &"caca"
	if kind == "abate":
		ledger.add(chapter, "abates")
		ledger.add(&"capa", "abates")
		if not player_target:
			ledger.add(&"caca", "especie:" + who["name"])
			if who.get("boss", false):
				ledger.add(&"caca", "chefes")
	else:
		ledger.add(chapter, "assistencias")
	_commit(page)

func _write_fall(killer: Node) -> void:
	var page := _page("queda", get_parent())
	var who: Dictionary = _last_taken.get("who", {})
	if killer == null and _last_taken.get("part", "") == "queda":
		who = {"kind": "ambiente", "name": "Queda"}
	page["who"] = who
	page["with"] = _last_taken.get("weapon", {}).merged({"damage_type": _last_taken.get("damage_type", "")})
	ledger.add(&"capa", "quedas")
	match who.get("kind", ""):
		"jogador":
			ledger.add(&"sangue", "quedas")
		"criatura":
			ledger.add(&"caca", "quedas")
	_commit(page)

func _commit(page: Dictionary) -> void:
	ledger.add_page(page)
	page_written.emit(page)

## Dia, hora e lugar da Página (GDD-19 §5)
func _page(kind: String, where: Node) -> Dictionary:
	var page := {"kind": kind, "day": 0, "hour": 0.0, "pos": [0, 0]}
	var sun: Node = null
	if is_inside_tree() and get_tree().current_scene:
		sun = get_tree().current_scene.get_node_or_null("Sun")
	if sun and "day_count" in sun:
		page["day"] = int(sun.day_count)
		page["hour"] = snappedf(float(sun.current_time_hours), 0.1)
	if where is Node3D and where.is_inside_tree():
		var p: Vector3 = (where as Node3D).global_position
		page["pos"] = [roundi(p.x), roundi(p.z)]
	return page

func _prune() -> void:
	var now := _now()
	for id in _hits_dealt.keys():
		if now - float(_hits_dealt[id].get("t", now)) > ASSIST_WINDOW * 2.0:
			_hits_dealt.erase(id)
	for id in _other_hitters.keys():
		var hitters: Dictionary = _other_hitters[id]
		for h in hitters.keys():
			if now - float(hitters[h]) > ASSIST_WINDOW:
				hitters.erase(h)
		if hitters.is_empty():
			_other_hitters.erase(id)

static func is_player(n: Node) -> bool:
	return n != null and (n.is_in_group("player") or n.is_in_group("remote_players"))

## Quem é, para a Página: jogador (nome e guilda), criatura (espécie, chefe) ou ambiente
static func describe(n: Node) -> Dictionary:
	if n == null or not is_instance_valid(n):
		return {"kind": "ambiente", "name": "?"}
	if is_player(n):
		var p_name: String = str(n.get("character_name")) if n.get("character_name") else ""
		if p_name.is_empty() and n.has_meta("player_name"):
			p_name = str(n.get_meta("player_name"))
		var save := n.get_node_or_null("/root/SaveGame") if n.is_inside_tree() else null
		if p_name.is_empty() and n.is_in_group("player") and save and str(save.get("character_name")) != "":
			p_name = str(save.get("character_name"))
		if p_name.is_empty():
			p_name = String(n.name)
		var g = n.get("guild")
		return {"kind": "jogador", "name": p_name, "guild": String(g.guild_id) if g else ""}
	var c_name: String = String(n.name)
	var dna = n.get("dna")
	if dna and dna.has_method("species_name"):
		c_name = dna.species_name()
	elif n.get("display_name"):
		c_name = str(n.get("display_name"))
	return {"kind": "criatura", "name": c_name, "boss": n.is_in_group("boss")}

## Com o quê: a peça na mão principal (nome e família)
static func weapon_of(n: Node) -> Dictionary:
	if n == null or not is_instance_valid(n):
		return {}
	var inv = n.get("inventory")
	if inv and inv.has_method("equipped_in"):
		var item: _ForgedItem = inv.equipped_in(_ForgedItem.Slot.MAIN_HAND)
		if item:
			return {"weapon": item.display_name, "family": String(item.family)}
	return {}

func to_dict() -> Dictionary:
	return ledger.to_dict()

func from_dict(data: Dictionary) -> void:
	ledger.from_dict(data)
