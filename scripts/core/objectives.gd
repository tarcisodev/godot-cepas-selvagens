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
var panel_container: PanelContainer = null
var _labels: Dictionary = {}
var _title: Label
var _check_timer: float = 0.0
var _fade_tween: Tween = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func reset() -> void:
	done.clear()
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	if panel_container and is_instance_valid(panel_container):
		panel_container.modulate.a = 1.0
		panel_container.visible = true
	_refresh()

func get_state() -> Array:
	return done.keys().map(func(k): return String(k))

func set_state(ids: Array) -> void:
	done.clear()
	for id in ids:
		done[StringName(id)] = true
	_refresh()
	if done.size() == STEPS.size() and panel_container and is_instance_valid(panel_container):
		panel_container.visible = false

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
		_fade_out_panel_completed()

func _fade_out_panel_completed() -> void:
	if _panel == null or not is_instance_valid(_panel) or panel_container == null or not is_instance_valid(panel_container):
		return
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween()
	# Dá 4.0 segundos para o jogador ver a mensagem "🏁 Caçada concluída!"
	_fade_tween.tween_interval(4.0)
	_fade_tween.tween_property(panel_container, "modulate:a", 0.0, 1.0)
	_fade_tween.tween_callback(func():
		if panel_container and is_instance_valid(panel_container):
			panel_container.visible = false
	)

func _process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") if is_inside_tree() else null
	if player == null or get_tree().current_scene == null or not get_tree().current_scene.is_ancestor_of(player):
		return
	if _panel == null or not is_instance_valid(_panel):
		_build_panel()
	# Some enquanto um menu estiver aberto (fica em camada acima do HUD)
	var has_open_menus := not get_tree().get_nodes_in_group("open_menus").is_empty()
	if has_open_menus:
		_panel.visible = false
	else:
		if done.size() == STEPS.size() and panel_container and not panel_container.visible:
			_panel.visible = false
		else:
			_panel.visible = true
	_check_timer -= delta
	if _check_timer > 0.0:
		return
	_check_timer = 0.4
	_check(player)

## Confere cada etapa no estado do jogo (em ordem: a próxima só conta depois da anterior).
func _check(player: Node) -> void:
	var tree: SceneTree = get_tree() if is_inside_tree() else (Engine.get_main_loop() as SceneTree)
	if tree == null:
		return
	var cur_scene := tree.current_scene
	var inv = player.get("inventory") if player != null else null
	var beast: Node3D = cur_scene.get_node_or_null("DummyCreature") as Node3D if cur_scene != null else null
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
		var album: Node = tree.get_first_node_in_group("card_album")
		if album == null and cur_scene != null:
			album = cur_scene.find_child("CardAlbum", true, false)
		if album == null and tree.root != null:
			album = tree.root.find_child("CardAlbum", true, false)
		if album and bool(album.get("visible")):
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
	bg.name = "QuestPanelContainer"
	panel_container = bg
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.07, 0.06, 0.62)
	style.border_color = Color(0.82, 0.68, 0.36, 0.86)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 3)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	bg.add_theme_stylebox_override("panel", style)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(bg)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	bg.add_child(box)

	_title = Label.new()
	var title_ls := LabelSettings.new()
	title_ls.font_size = 16
	title_ls.font_color = Color(0.98, 0.88, 0.54)
	title_ls.outline_size = 4
	title_ls.outline_color = Color(0.02, 0.03, 0.04, 0.96)
	title_ls.shadow_size = 3
	title_ls.shadow_color = Color(0, 0, 0, 0.82)
	title_ls.shadow_offset = Vector2(1, 2)
	_title.label_settings = title_ls
	box.add_child(_title)

	_labels.clear()
	for step in STEPS:
		var l := Label.new()
		var step_ls := LabelSettings.new()
		step_ls.font_size = 12
		step_ls.outline_size = 3
		step_ls.outline_color = Color(0.02, 0.03, 0.04, 0.95)
		step_ls.shadow_size = 2
		step_ls.shadow_color = Color(0, 0, 0, 0.78)
		step_ls.shadow_offset = Vector2(1, 1)
		l.label_settings = step_ls
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
			l.visible = false
			if l.label_settings:
				l.label_settings.font_color = Color(0.58, 0.92, 0.62, 0.92)
		elif not next_found:
			next_found = true
			l.text = "➤  " + step.text
			l.visible = true
			if l.label_settings:
				l.label_settings.font_color = Color(1.0, 0.98, 0.90, 1.0)
		else:
			l.text = "•  " + step.text
			l.visible = false
			if l.label_settings:
				l.label_settings.font_color = Color(0.82, 0.85, 0.82, 0.68)
	_title.text = "🏁 Caçada concluída!" if done.size() == STEPS.size() else "🎯 Objetivo (%d/%d)" % [done.size(), STEPS.size()]
