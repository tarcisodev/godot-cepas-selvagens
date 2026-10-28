extends Node

## Salvamento do progresso do jogador (MVP) em user://savegame.json.
# Guarda: nome, posição, hora e dia, aparência (DNA), materiais, peças forjadas e equipadas, maestrias, cartas, objetivos
# construções (totens e peças), obras da vila com a Reputação, montarias e a natureza
# (plantas, bichos, solo, clima e cheia do rio).
# O jogo é só online: o personagem entra pelo login (`enter_online_world`) e o estado dele
# vive no ServerPersistence. Este arquivo local ainda é gravado a cada AUTOSAVE_SECONDS,
# mas não é mais carregado ao entrar (o mundo do host ainda não persiste no servidor).

const BuildingSystemClass = preload("res://scripts/building_system.gd")
const ServerPersistenceClass = preload("res://scripts/core/server_persistence.gd")

const SAVE_PATH: String = "user://savegame.json"
const SAVE_VERSION: int = 1
const WORLD_SCENE: String = "res://scenes/world.tscn"
const AUTOSAVE_SECONDS: float = 120.0

signal saved()
signal loaded()

var load_on_enter: bool = false
## Nome do personagem atual (vem da criação de personagem ou do save).
var character_name: String = ""
## Aparência escolhida na criação de personagem, aplicada quando o mundo abre.
var _new_character: CharacterDNA = null
var _show_new_game_welcome: bool = false
var _autosave_timer: float = AUTOSAVE_SECONDS
var _applied_to: Node = null
## Personagem de conta (B24) entrando no mundo: dados do servidor a aplicar no player.
var _pending_online: bool = false
var _pending_server_data: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta: float) -> void:
	var player := _find_player()
	if player == null:
		return
	# Aplica o save pendente assim que o player do mundo existir (uma vez por mundo)
	if load_on_enter and _applied_to != player and player.is_node_ready():
		_applied_to = player
		load_on_enter = false
		apply_save(player)
	# Personagem recém-criado: veste o DNA escolhido e já grava o primeiro save
	if _new_character and _applied_to != player and player.is_node_ready():
		_applied_to = player
		dress_new_character(player)
		if _show_new_game_welcome:
			_show_new_game_welcome = false
			_grant_starter_explorer_kit(player)
		save_game()
	# Personagem de conta (host ou cliente): aplica o estado do servidor e marca o nome
	# para o autosave do ServerPersistence achar o player
	if _pending_online and player.is_node_ready():
		_pending_online = false
		player.set_meta("player_name", character_name)
		if not _pending_server_data.is_empty():
			ServerPersistenceClass.apply_player_data(player, _pending_server_data)
			_pending_server_data = {}
	_autosave_timer -= delta
	if _autosave_timer <= 0.0:
		_autosave_timer = AUTOSAVE_SECONDS
		save_game()

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

## Entra no mundo com um personagem de conta (B24). `new_dna` vem da criação de personagem;
## sem ele, veste o DNA salvo no servidor (`server_data`) e reaplica o resto do estado.
func enter_online_world(p_name: String, server_data: Dictionary, new_dna: CharacterDNA = null) -> void:
	character_name = p_name
	_pending_online = true
	_pending_server_data = {}
	if new_dna:
		_new_character = new_dna
		_show_new_game_welcome = true
		var objectives := _objectives()
		if objectives:
			objectives.reset()
	else:
		var dna_dict = server_data.get("dna", {})
		if dna_dict is Dictionary and not dna_dict.is_empty():
			_new_character = CharacterDNA.from_dict(dna_dict)
		_pending_server_data = server_data
	load_on_enter = false
	get_tree().paused = false
	get_tree().change_scene_to_file(WORLD_SCENE)

func _grant_starter_explorer_kit(player: Node) -> void:
	var wallet = player.get("wallet")
	if wallet and wallet.has_method("add"):
		wallet.add(150)
	var inv = player.get("inventory")
	if inv and inv.has_method("add_material"):
		inv.add_material(&"tocha", 1)
		inv.add_material(&"vara_pesca", 1)
		inv.add_material(&"laco_fibra", 2)
		inv.add_material(&"pocao", 2)
	if player.is_inside_tree() and player.get_tree().current_scene:
		var guide := player.get_tree().current_scene.find_child("ExplorerGuide", true, false)
		if guide and guide.has_method("open_guide"):
			guide.open_guide(player)

## Veste no player o DNA vindo da criação de personagem.
func dress_new_character(player: Node) -> void:
	var visual = player.get("character_visual")
	if visual and _new_character:
		visual.rebuild(_new_character)
	_new_character = null
	if player.has_method("ensure_starter_weapons"):
		player.ensure_starter_weapons()

## Nome gravado no save (vazio se não houver).
func saved_name() -> String:
	return str(read_save().get("name", ""))

## Monta o dicionário do progresso a partir do player e do mundo.
func collect(player: Node) -> Dictionary:
	var data := {"version": SAVE_VERSION}
	data["name"] = character_name
	var pos := _get_pos(player as Node3D)
	data["position"] = [pos.x, pos.y, pos.z]
	var sun := _world_sun(player)
	if sun and "current_time_hours" in sun:
		data["time_hours"] = sun.current_time_hours
		data["day"] = sun.get("day_count")
	var visual = player.get("character_visual")
	if visual and visual.dna:
		data["appearance"] = visual.dna.to_dict()
	var inv = player.get("inventory")
	if inv:
		data["materials"] = inv.stacks_to_save()
		data["gear"] = inv.items_to_save()
	var wallet = player.get("wallet")
	if wallet:
		data["money"] = wallet.money
	var mastery = player.get("mastery")
	if mastery:
		data["mastery"] = _keys_to_str(mastery._masteries)
	var cards = player.get("card_collection")
	if cards:
		data["cards"] = cards.get_unlocked_ids().map(func(id): return String(id))
	var eco_comp = player.get("ecology")
	if eco_comp and eco_comp.has_method("to_dict"):
		data["ecology_knowledge"] = eco_comp.to_dict()
	var objectives := _objectives()
	if objectives:
		data["objectives"] = objectives.get_state()
	# Descanso (GDD-10 §10): buff Descansado e a cama marcada para renascer
	var rest = player.get("rest")
	if rest:
		data["rest"] = rest.get_state()
	var bed = player.get("marked_bed")
	if bed and is_instance_valid(bed):
		var bp: Vector3 = _get_pos(bed)
		data["bed"] = [bp.x, bp.y, bp.z]
	if player.is_inside_tree():
		var map_scr = player.get_tree().root.find_child("WorldMapScreen", true, false)
		if map_scr and map_scr.has_method("get_markers_data"):
			data["map_markers"] = map_scr.get_markers_data()
		data["structures"] = BuildingSystemClass.collect_structures(player.get_tree())
		var city := player.get_tree().get_first_node_in_group("city_hub")
		if city:
			data["town"] = city.get_state()
		var eco := player.get_tree().get_first_node_in_group("ecosystem")
		if eco:
			data["mounts"] = eco.owned_state()
		# Natureza (GDD-10): plantas e bichos vivos, solo, clima e cheia do rio
		var nature := {}
		if eco:
			nature = eco.nature_state()
		var ecology := player.get_tree().get_first_node_in_group("ecology")
		if ecology:
			nature["soil"] = ecology.get_state()
		var weather := player.get_tree().get_first_node_in_group("weather")
		if weather:
			nature["weather"] = weather.get_state()
		if not nature.is_empty():
			data["nature"] = nature
	return data

func save_game() -> bool:
	var player := _find_player()
	if player == null:
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveGame: não deu para escrever %s" % SAVE_PATH)
		return false
	file.store_string(JSON.stringify(collect(player), "\t"))
	saved.emit()
	return true

func read_save() -> Dictionary:
	if not has_save():
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	return parsed if parsed is Dictionary else {}

## Aplica o save do disco (ou `data`, se passado) ao player.
func apply_save(player: Node, data: Dictionary = {}) -> void:
	if data.is_empty():
		data = read_save()
	if data.is_empty():
		return

	character_name = str(data.get("name", ""))
	var visual = player.get("character_visual")
	if visual and data.has("appearance"):
		visual.rebuild(CharacterDNA.from_dict(data["appearance"]))

	var wallet = player.get("wallet")
	if wallet and data.has("money"):
		wallet.set_money(int(data["money"]))

	var inv = player.get("inventory")
	if inv:
		inv.load_from_save(data.get("materials", []))
		# Peças forjadas e o que estava equipado (reaplica os efeitos)
		inv.load_items(data.get("gear", {}))
		# Saves de antes das armas forjadas (GDD-12 §7): ganham espada e escudo de treino
		if player.has_method("ensure_starter_weapons"):
			player.ensure_starter_weapons()

	# Maestrias depois do elmo: a forja de restauração não pode contar XP
	var mastery = player.get("mastery")
	if mastery and data.has("mastery"):
		var restored := {}
		for tag in data["mastery"]:
			var entry: Dictionary = data["mastery"][tag]
			restored[StringName(tag)] = {"level": int(entry.get("level", 1)), "xp": float(entry.get("xp", 0.0))}
		mastery._masteries = restored

	var cards = player.get("card_collection")
	if cards:
		for id in data.get("cards", []):
			cards.unlock_card(StringName(id), false)

	if data.has("ecology_knowledge"):
		var eco_comp = player.get("ecology")
		if eco_comp and eco_comp.has_method("from_dict"):
			eco_comp.from_dict(data["ecology_knowledge"])

	if data.has("map_markers") and player.is_inside_tree():
		var map_scr = player.get_tree().root.find_child("WorldMapScreen", true, false)
		if map_scr and map_scr.has_method("load_markers_data"):
			map_scr.load_markers_data(data["map_markers"])

	if data.has("position"):
		var pos: Array = data["position"]
		var px: float = float(pos[0])
		var py: float = float(pos[1])
		var pz: float = float(pos[2])
		# Se a posição estiver no limbo ou fora dos limites do mapa, restaura na área segura inicial
		if py < -6.0 or py > 80.0 or not WorldBounds.inside(px, pz, 2.0):
			_set_pos(player as Node3D, Vector3(0.0, 1.2, 0.0))
		else:
			_set_pos(player as Node3D, Vector3(px, py + 0.2, pz))
	var sun := _world_sun(player)
	if sun and data.has("time_hours") and sun.has_method("_update_sun_position_and_lighting"):
		sun.current_time_hours = float(data["time_hours"])
		if data.has("day"):
			sun.set("day_count", int(data["day"]))
		sun._update_sun_position_and_lighting()

	var objectives := _objectives()
	if objectives and data.has("objectives"):
		objectives.set_state(data["objectives"])

	# Totens e peças voltam como filhos do mundo (irmãos do player)
	var world := player.get_parent()
	if world and data.has("structures"):
		BuildingSystemClass.restore_structures(world, data["structures"])
	var rest = player.get("rest")
	if rest and data.has("rest"):
		rest.apply_state(data["rest"])
	if data.has("bed") and player.is_inside_tree():
		var saved: Array = data["bed"]
		var at := Vector3(float(saved[0]), float(saved[1]), float(saved[2]))
		for b in player.get_tree().get_nodes_in_group("beds"):
			if not b.is_queued_for_deletion() and _get_pos(b).distance_to(at) < 0.5:
				player.set("marked_bed", b)
				break
	# Obras da vila e Reputação (GDD-08 §6.1)
	var city := player.get_tree().get_first_node_in_group("city_hub") if player.is_inside_tree() else null
	if city and data.has("town"):
		city.apply_state(data["town"])
	# Montarias capturadas (GDD-03 §9.3)
	var eco := player.get_tree().get_first_node_in_group("ecosystem") if player.is_inside_tree() else null
	if eco and data.has("mounts"):
		eco.restore_owned(data["mounts"])
	if data.has("nature") and player.is_inside_tree():
		var nature: Dictionary = data["nature"]
		if eco and nature.has("plants"):
			eco.restore_nature(nature)
		var ecology := player.get_tree().get_first_node_in_group("ecology")
		if ecology and nature.has("soil"):
			ecology.apply_state(nature["soil"])
		var weather := player.get_tree().get_first_node_in_group("weather")
		if weather and nature.has("weather"):
			weather.apply_state(nature["weather"])
	loaded.emit()

# O player é filho direto do mundo; fora da árvore só a posição local existe
static func _get_pos(n: Node3D) -> Vector3:
	return n.global_position if n.is_inside_tree() else n.position

static func _set_pos(n: Node3D, v: Vector3) -> void:
	if n.is_inside_tree():
		n.global_position = v
	else:
		n.position = v

## Autoload Objectives pela raiz do SceneTree (funciona mesmo antes de este nó entrar na árvore).
static func _objectives() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("Objectives") if tree else null

## Sol (DayNightCycle) do mundo onde o player está; null fora do mundo (ex.: testes).
func _world_sun(player: Node) -> Node:
	if not player.is_inside_tree() or player.get_tree().current_scene == null:
		return null
	return player.get_tree().current_scene.get_node_or_null("Sun")

func _find_player() -> Node:
	if not is_inside_tree():
		return null
	return get_tree().get_first_node_in_group("player")

static func _keys_to_str(d: Dictionary) -> Dictionary:
	var out := {}
	for k in d:
		out[String(k)] = String(d[k]) if d[k] is StringName else d[k]
	return out

static func _keys_to_sn(d: Dictionary, int_values: bool = false) -> Dictionary:
	var out := {}
	for k in d:
		out[StringName(k)] = int(d[k]) if int_values else d[k]
	return out
