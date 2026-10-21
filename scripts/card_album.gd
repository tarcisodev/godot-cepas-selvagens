class_name CardAlbum
extends CanvasLayer

## Interface do Álbum de Cartas Colecionáveis e Palco de Inspeção 3D (GDD-07 e B08).
## Permite navegar pelas cartas descobertas, inspecionar em 3D, girar, virar (flip) e ver dados táticos.

signal album_opened()
signal album_closed()

@export var collection_component: CardCollectionComponent

@onready var main_panel: Control = $MainPanel
@onready var progress_label: Label = $MainPanel/Margin/VBox/Header/ProgressLabel
@onready var cards_grid: GridContainer = $MainPanel/Margin/VBox/Content/LeftPane/Scroll/CardsGrid
@onready var filter_container: HBoxContainer = $MainPanel/Margin/VBox/FilterBar
@onready var close_button: Button = $MainPanel/Margin/VBox/Header/CloseButton

# Palco 3D
@onready var viewport_container: SubViewportContainer = $MainPanel/Margin/VBox/Content/RightPane/ViewportContainer
@onready var card_3d_stage: Card3D = $MainPanel/Margin/VBox/Content/RightPane/ViewportContainer/SubViewport/Card3D
@onready var card_title_label: Label = $MainPanel/Margin/VBox/Content/RightPane/Details/TitleLabel
@onready var card_badge_label: Label = $MainPanel/Margin/VBox/Content/RightPane/Details/BadgeLabel
@onready var card_stats_label: Label = $MainPanel/Margin/VBox/Content/RightPane/Details/StatsLabel
@onready var card_trait_label: Label = $MainPanel/Margin/VBox/Content/RightPane/Details/TraitLabel
@onready var card_desc_label: Label = $MainPanel/Margin/VBox/Content/RightPane/Details/DescLabel
@onready var flip_button: Button = $MainPanel/Margin/VBox/Content/RightPane/FlipButton

var _current_filter: String = "Todas"
var _selected_card: CardData = null
var _is_dragging_3d: bool = false
var _last_mouse_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
	_setup_nodes()
	visible = false
	if close_button and not close_button.pressed.is_connected(close_album):
		close_button.pressed.connect(close_album)
	if flip_button and not flip_button.pressed.is_connected(_on_flip_pressed):
		flip_button.pressed.connect(_on_flip_pressed)
	
	_setup_filters()

func _setup_nodes() -> void:
	if main_panel == null:
		main_panel = get_node_or_null("MainPanel")
	if progress_label == null and main_panel != null:
		progress_label = get_node_or_null("MainPanel/Margin/VBox/Header/ProgressLabel")
	if cards_grid == null and main_panel != null:
		cards_grid = get_node_or_null("MainPanel/Margin/VBox/Content/LeftPane/Scroll/CardsGrid")
	if filter_container == null and main_panel != null:
		filter_container = get_node_or_null("MainPanel/Margin/VBox/FilterBar")
	if close_button == null and main_panel != null:
		close_button = get_node_or_null("MainPanel/Margin/VBox/Header/CloseButton")
	if viewport_container == null and main_panel != null:
		viewport_container = get_node_or_null("MainPanel/Margin/VBox/Content/RightPane/ViewportContainer")
	if card_3d_stage == null and main_panel != null:
		card_3d_stage = get_node_or_null("MainPanel/Margin/VBox/Content/RightPane/ViewportContainer/SubViewport/Card3D")
	if card_title_label == null and main_panel != null:
		card_title_label = get_node_or_null("MainPanel/Margin/VBox/Content/RightPane/Details/TitleLabel")
	if card_badge_label == null and main_panel != null:
		card_badge_label = get_node_or_null("MainPanel/Margin/VBox/Content/RightPane/Details/BadgeLabel")
	if card_stats_label == null and main_panel != null:
		card_stats_label = get_node_or_null("MainPanel/Margin/VBox/Content/RightPane/Details/StatsLabel")
	if card_trait_label == null and main_panel != null:
		card_trait_label = get_node_or_null("MainPanel/Margin/VBox/Content/RightPane/Details/TraitLabel")
	if card_desc_label == null and main_panel != null:
		card_desc_label = get_node_or_null("MainPanel/Margin/VBox/Content/RightPane/Details/DescLabel")
	if flip_button == null and main_panel != null:
		flip_button = get_node_or_null("MainPanel/Margin/VBox/Content/RightPane/FlipButton")

func _setup_filters() -> void:
	if filter_container == null:
		return
	
	for child in filter_container.get_children():
		if child is Button:
			var btn_text = child.text
			var cb = _on_filter_button_pressed.bind(btn_text)
			if not child.pressed.is_connected(cb):
				child.pressed.connect(cb)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_just_pressed("ui_cancel") and visible:
		close_album()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_K:
			toggle_album()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_SPACE and visible and card_3d_stage != null:
			card_3d_stage.toggle_flip()
			get_viewport().set_input_as_handled()

func toggle_album() -> void:
	if visible:
		close_album()
	else:
		open_album()

func open_album() -> void:
	_setup_nodes()
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	refresh_collection()
	album_opened.emit()

func close_album() -> void:
	visible = false
	album_closed.emit()

## Atualiza a grade de cartas e métricas de progresso
func refresh_collection() -> void:
	_setup_nodes()
	if collection_component == null:
		var player = get_tree().get_first_node_in_group("player") if is_inside_tree() else null
		if player != null:
			collection_component = player.get_node_or_null("CardCollectionComponent") as CardCollectionComponent
	
	# Atualiza contador de progresso
	var progress = collection_component.get_progress() if collection_component else { "unlocked": 0, "total": CardDatabase.get_total_count(), "percent": 0.0 }
	if progress_label:
		progress_label.text = "Coleção: %d / %d (%.0f%%)" % [progress["unlocked"], progress["total"], progress["percent"]]
	
	# Reconstrói a grade
	if cards_grid == null:
		return
	
	for child in cards_grid.get_children():
		cards_grid.remove_child(child)
		child.free()
	
	var all_cards = CardDatabase.get_all_cards()
	var first_unlocked: CardData = null
	
	for card in all_cards:
		if _current_filter != "Todas" and card.category.to_lower() != _current_filter.to_lower():
			continue
		
		var is_unlocked: bool = collection_component != null and collection_component.is_card_unlocked(card.id)
		var btn = _create_card_slot_button(card, is_unlocked)
		cards_grid.add_child(btn)
		
		if is_unlocked and first_unlocked == null:
			first_unlocked = card
	
	# Seleciona a primeira carta desbloqueada se nenhuma estiver selecionada
	if first_unlocked != null:
		select_card(first_unlocked)

func _create_card_slot_button(card: CardData, is_unlocked: bool) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(100, 140)
	btn.clip_text = true
	
	if is_unlocked:
		btn.text = "%s\n[%s]" % [card.title, card.get_element_name()]
		btn.modulate = card.get_rarity_color()
		btn.pressed.connect(func(): select_card(card))
		
		# Carrega miniatura se disponível
		if not card.render_path.is_empty() and ResourceLoader.exists(card.render_path):
			var tex: Texture2D = load(card.render_path) as Texture2D
			if tex:
				btn.icon = tex
				btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
				btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
				btn.expand_icon = true
	else:
		btn.text = "🔒 Bloqueada\n[ ? ]"
		btn.modulate = Color(0.4, 0.4, 0.45, 0.8)
		btn.disabled = false
		btn.pressed.connect(func(): _show_locked_details(card))
	
	return btn

## Exibe os dados da carta selecionada no palco 3D e nos painéis
func select_card(card: CardData) -> void:
	_selected_card = card
	if card_3d_stage:
		card_3d_stage.reset_orientation()
		card_3d_stage.display_card(card)
	
	if card_title_label:
		card_title_label.text = card.title
		card_title_label.modulate = card.get_rarity_color()
	
	if card_badge_label:
		card_badge_label.text = "%s • %s • %s" % [card.category, card.get_element_name(), card.get_rarity_name()]
		card_badge_label.modulate = card.get_element_color()
	
	if card_stats_label:
		card_stats_label.text = "⚡ Éter: %d   |   ⚔️ Poder: %d   |   🛡️ Postura: %d" % [
			card.ether_cost, card.power, card.poise
		]
	
	if card_trait_label:
		card_trait_label.text = "Trait: %s — %s" % [card.trait_name, card.trait_description]
	
	if card_desc_label:
		card_desc_label.text = "%s\n\n\"%s\"" % [card.description, card.flavor_lore]

func _show_locked_details(card: CardData) -> void:
	if card_3d_stage:
		card_3d_stage.display_card(null)
	
	if card_title_label:
		card_title_label.text = "??? (Não Descoberta)"
		card_title_label.modulate = Color(0.5, 0.5, 0.5)
	
	if card_badge_label:
		card_badge_label.text = "%s • Desconhecida" % [card.category]
		card_badge_label.modulate = Color(0.6, 0.6, 0.6)
	
	if card_stats_label:
		card_stats_label.text = "⚡ Éter: ?   |   ⚔️ Poder: ?   |   🛡️ Postura: ?"
	
	if card_trait_label:
		card_trait_label.text = "Trait: Oculto"
	
	if card_desc_label:
		card_desc_label.text = "Derrote monstros, quebre partes anatômicas ou cultive espécimes para catalogar este exemplar."

func _on_filter_button_pressed(category: String) -> void:
	_current_filter = category
	refresh_collection()

func _on_flip_pressed() -> void:
	if card_3d_stage:
		card_3d_stage.toggle_flip()

func _on_viewport_gui_input(event: InputEvent) -> void:
	if card_3d_stage == null:
		return
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_is_dragging_3d = event.pressed
			_last_mouse_pos = event.position
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			card_3d_stage.toggle_flip()
	
	elif event is InputEventMouseMotion:
		if _is_dragging_3d:
			var delta: Vector2 = event.position - _last_mouse_pos
			card_3d_stage.add_manual_orbit(delta.x, delta.y)
			_last_mouse_pos = event.position
		else:
			# Tilt holográfico baseado na posição do mouse dentro do container
			var size: Vector2 = viewport_container.size if viewport_container else Vector2(300, 300)
			var norm: Vector2 = ((event.position / size) * 2.0) - Vector2.ONE
			card_3d_stage.set_tilt_normalized(norm)
