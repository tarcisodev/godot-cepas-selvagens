extends Node

## Objetivos do MVP: guia o jogador pelo loop caçar → quebrar → esfolar → forjar (GDD-03/06).
# Quando o mundo abre (existe um player), monta um painel no canto superior direito.
# Cada etapa é conferida pelo estado do jogo (inventário, besta, elmo) e, uma vez cumprida,
# fica marcada — inclusive no save (get_state/set_state).

signal objective_completed(id: StringName)
signal all_completed()

const STEPS: Array[Dictionary] = [
	{"id": &"find", "text": "Encontre a Besta de Sucata no morro a noroeste"},
	{"id": &"break", "text": "Quebre o chifre dela ou derrote-a (clique esq./dir.)"},
	{"id": &"harvest", "text": "Segure [E] no corpo para esfolar"},
	{"id": &"forge", "text": "Forje o Elmo Chifre-de-Pedra na bigorna do acampamento ([E])"},
	{"id": &"album", "text": "Veja suas cartas no álbum ([K])"},
]
const FIND_DISTANCE: float = 9.0

var done: Dictionary = {}
var _panel: CanvasLayer = null
var _labels: Dictionary = {}
var _title: Label
var _check_timer: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func reset() -> void:
	done.clear()
	_refresh()

func get_state() -> Array:
	return done.keys().map(func(k): return String(k))

func set_state(ids: Array) -> void:
	done.clear()
	for id in ids:
		done[StringName(id)] = true
	_refresh()

func is_done(id: StringName) -> bool:
	return done.has(id)

func complete(id: StringName) -> void:
	if done.has(id):
		return
	done[id] = true
	objective_completed.emit(id)
	_refresh()
	if done.size() == STEPS.size():
		all_completed.emit()

func _process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") if is_inside_tree() else null
	if player == null or get_tree().current_scene == null or not get_tree().current_scene.is_ancestor_of(player):
		return
	if _panel == null or not is_instance_valid(_panel):
		_build_panel()
	# Some enquanto um menu estiver aberto (fica em camada acima do HUD)
	_panel.visible = get_tree().get_nodes_in_group("open_menus").is_empty()
	_check_timer -= delta
	if _check_timer > 0.0:
		return
	_check_timer = 0.4
	_check(player)

## Confere cada etapa no estado do jogo (em ordem: a próxima só conta depois da anterior).
func _check(player: Node) -> void:
	var inv = player.get("inventory")
	var beast := get_tree().current_scene.get_node_or_null("DummyCreature") as Node3D
	var has_horn: bool = inv != null and inv.get_material_count(&"chifre_rinolito") > 0
	var helmet: bool = inv != null and inv.equipped.get(&"head", &"") != &""

	if beast and (player as Node3D).global_position.distance_to(beast.global_position) < FIND_DISTANCE:
		complete(&"find")
	if is_done(&"find") and beast:
		var dead: bool = beast.pools != null and beast.pools.current_health <= 0.0
		if dead or (beast.anatomy and beast.anatomy.is_part_broken(&"horn")):
			complete(&"break")
	if is_done(&"break") and (has_horn or helmet):
		complete(&"harvest")
	if is_done(&"harvest") and helmet:
		complete(&"forge")
	if is_done(&"forge"):
		var album := get_tree().current_scene.find_child("CardAlbum", true, false) as CanvasItem
		if album and album.visible:
			complete(&"album")

func _build_panel() -> void:
	_panel = CanvasLayer.new()
	_panel.name = "ObjectivesPanel"
	_panel.layer = 5
	get_tree().current_scene.add_child(_panel)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	margin.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 22)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(margin)

	var bg := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.07, 0.06, 0.55)
	style.set_corner_radius_all(8)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	bg.add_theme_stylebox_override("panel", style)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(bg)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	bg.add_child(box)

	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 16)
	_title.add_theme_color_override("font_color", Color(0.95, 0.86, 0.6))
	box.add_child(_title)

	_labels.clear()
	for step in STEPS:
		var l := Label.new()
		l.add_theme_font_size_override("font_size", 13)
		box.add_child(l)
		_labels[step.id] = l
	_refresh()

func _refresh() -> void:
	if _panel == null or not is_instance_valid(_panel):
		return
	var next_found := false
	for step in STEPS:
		var l: Label = _labels[step.id]
		if done.has(step.id):
			l.text = "✔  " + step.text
			l.add_theme_color_override("font_color", Color(0.6, 0.85, 0.6, 0.85))
		elif not next_found:
			next_found = true
			l.text = "➤  " + step.text
			l.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		else:
			l.text = "•  " + step.text
			l.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 0.5))
	_title.text = "🏁 Caçada concluída! Explore à vontade." if done.size() == STEPS.size() else "Objetivos (%d/%d)" % [done.size(), STEPS.size()]
