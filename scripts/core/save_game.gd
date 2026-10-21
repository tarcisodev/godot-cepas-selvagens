extends Node

## Salvamento do progresso do jogador (MVP) em user://savegame.json.
# Guarda: nome, posição, hora do dia, aparência (DNA), materiais, elmo equipado, maestrias, cartas e objetivos.
# "Continuar" na tela de título marca `load_on_enter`; quando o mundo entra na árvore,
# o save é aplicado. Com o mundo aberto, salva sozinho a cada AUTOSAVE_SECONDS.

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
var _autosave_timer: float = AUTOSAVE_SECONDS
var _applied_to: Node = null

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
		save_game()
	_autosave_timer -= delta
	if _autosave_timer <= 0.0:
		_autosave_timer = AUTOSAVE_SECONDS
		save_game()

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))

## Começa um jogo novo com o personagem montado na tela de criação.
func start_new_game(dna: CharacterDNA, p_name: String) -> void:
	_new_character = dna
	character_name = p_name
	enter_world(false)

## Veste no player o DNA vindo da criação de personagem.
func dress_new_character(player: Node) -> void:
	var visual = player.get("character_visual")
	if visual and _new_character:
		visual.rebuild(_new_character)
	_new_character = null

## Nome gravado no save (vazio se não houver).
func saved_name() -> String:
	return str(read_save().get("name", ""))

## Abre o mundo; com `continue_game`, aplica o save ao entrar.
func enter_world(continue_game: bool) -> void:
	load_on_enter = continue_game and has_save()
	if not continue_game:
		delete_save()
		var objectives := _objectives()
		if objectives:
			objectives.reset()
	get_tree().paused = false
	get_tree().change_scene_to_file(WORLD_SCENE)

## Monta o dicionário do progresso a partir do player e do mundo.
func collect(player: Node) -> Dictionary:
	var data := {"version": SAVE_VERSION}
	data["name"] = character_name
	var pos := _get_pos(player as Node3D)
	data["position"] = [pos.x, pos.y, pos.z]
	var sun := _world_sun(player)
	if sun and "current_time_hours" in sun:
		data["time_hours"] = sun.current_time_hours
	var visual = player.get("character_visual")
	if visual and visual.dna:
		data["appearance"] = visual.dna.to_dict()
	var inv = player.get("inventory")
	if inv:
		data["materials"] = _keys_to_str(inv.materials)
		data["equipped"] = _keys_to_str(inv.equipped)
	var mastery = player.get("mastery")
	if mastery:
		data["mastery"] = _keys_to_str(mastery._masteries)
	var cards = player.get("card_collection")
	if cards:
		data["cards"] = cards.get_unlocked_ids().map(func(id): return String(id))
	var objectives := _objectives()
	if objectives:
		data["objectives"] = objectives.get_state()
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

	var inv = player.get("inventory")
	if inv:
		inv.materials = _keys_to_sn(data.get("materials", {}), true)
		# O elmo volta refazendo a forja com o mesmo chifre (reaplica os modificadores)
		var head: String = data.get("equipped", {}).get("head", "")
		if head != "":
			var horn: StringName = &"chifre_integro" if "Íntegro" in head else &"chifre_lascado"
			inv.add_material(horn, 1)
			inv.add_material(&"placa_carapaca", 1)
			inv.craft_and_equip_horn_helmet(horn)

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

	if data.has("position"):
		var pos: Array = data["position"]
		var px: float = float(pos[0])
		var py: float = float(pos[1])
		var pz: float = float(pos[2])
		# Se a posição estiver no limbo ou fora dos limites do mapa, restaura na área segura inicial
		if py < -6.0 or py > 70.0 or absf(px) > 88.0 or absf(pz) > 88.0:
			_set_pos(player as Node3D, Vector3(0.0, 1.2, 0.0))
		else:
			_set_pos(player as Node3D, Vector3(px, py + 0.2, pz))
	var sun := _world_sun(player)
	if sun and data.has("time_hours") and sun.has_method("_update_sun_position_and_lighting"):
		sun.current_time_hours = float(data["time_hours"])
		sun._update_sun_position_and_lighting()

	var objectives := _objectives()
	if objectives and data.has("objectives"):
		objectives.set_state(data["objectives"])
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
