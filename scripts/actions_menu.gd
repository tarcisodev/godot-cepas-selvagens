extends Control
class_name ActionsMenu

## Central do Andarilho (Menu TAB):
## Painel amplo em duas colunas com Ações do Mundo, Atalhos de Sistemas (Mochila, Construção,
## Cartas, Forja, Cosméticos, Guia e Feedback) e Ofícios de Mão (Fabricação Rápida).
## Não existe "esperar": o relógio do mundo nunca pula (ADR-0006).

@export var player: Player
@export var day_night: DirectionalLight3D

@onready var panel: PanelContainer = $PanelContainer
@onready var sit_button: Button = $PanelContainer/MarginContainer/VBoxContainer/SitButton
@onready var pov_button: Button = $PanelContainer/MarginContainer/VBoxContainer/PovButton
@onready var forge_button: Button = get_node_or_null("PanelContainer/MarginContainer/VBoxContainer/ForgeButton")
@onready var forge_status_label: Label = get_node_or_null("PanelContainer/MarginContainer/VBoxContainer/ForgeStatusLabel")
@onready var cards_button: Button = get_node_or_null("PanelContainer/MarginContainer/VBoxContainer/CardsButton")
@onready var close_button: Button = $PanelContainer/MarginContainer/VBoxContainer/CloseButton

var is_open: bool = false
var _craft_buttons: Dictionary = {}
var _header_status: Label

func _ready() -> void:
	visible = false
	_rebuild_stylish_layout()

func _rebuild_stylish_layout() -> void:
	# Fundo escurecido suave atrás do painel
	var dim := ColorRect.new()
	dim.name = "BackdropDim"
	dim.color = Color(0.02, 0.03, 0.04, 0.68)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	move_child(dim, 0)

	# amplia e estiliza o PanelContainer central
	panel.offset_left = -390.0
	panel.offset_top = -245.0
	panel.offset_right = 390.0
	panel.offset_bottom = 245.0

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.10, 0.09, 0.96)
	sb.border_color = Color(0.78, 0.64, 0.34, 0.88)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 12
	panel.add_theme_stylebox_override("panel", sb)

	var old_vbox := $PanelContainer/MarginContainer/VBoxContainer as VBoxContainer
	var title_lbl := old_vbox.get_node_or_null("Title") as Label
	if title_lbl:
		title_lbl.visible = false

	# Criamos um cabeçalho + duas colunas dentro de old_vbox
	var top_bar := HBoxContainer.new()
	top_bar.add_theme_constant_override("separation", 12)
	old_vbox.add_child(top_bar)
	old_vbox.move_child(top_bar, 0)

	var header_title := Label.new()
	header_title.text = "⛺ CENTRAL DO ANDARILHO — [TAB]"
	header_title.add_theme_font_size_override("font_size", 20)
	header_title.add_theme_color_override("font_color", Color(0.98, 0.86, 0.52))
	header_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(header_title)

	_header_status = Label.new()
	_header_status.add_theme_font_size_override("font_size", 15)
	_header_status.add_theme_color_override("font_color", Color(0.92, 0.88, 0.55))
	top_bar.add_child(_header_status)

	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 20)
	old_vbox.add_child(columns)

	var left_col := VBoxContainer.new()
	left_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_col.add_theme_constant_override("separation", 7)
	columns.add_child(left_col)

	var right_col := VBoxContainer.new()
	right_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_col.add_theme_constant_override("separation", 8)
	columns.add_child(right_col)

	var left_header := Label.new()
	left_header.text = "🧭 Ações & Sistemas"
	left_header.add_theme_font_size_override("font_size", 15)
	left_header.add_theme_color_override("font_color", Color(0.95, 0.80, 0.45))
	left_col.add_child(left_header)

	# Reorganiza botões existentes na coluna esquerda
	for btn in [sit_button, pov_button, cards_button, forge_button]:
		if btn:
			btn.reparent(left_col)
			btn.alignment = HORIZONTAL_ALIGNMENT_LEFT

	var inv_btn := Button.new()
	inv_btn.name = "InventoryButton"
	inv_btn.text = "🎒 Mochila & Equipamentos ([I])"
	inv_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	inv_btn.pressed.connect(_on_inventory_pressed)
	left_col.add_child(inv_btn)

	var build_btn := Button.new()
	build_btn.name = "BuildButton"
	build_btn.text = "🏗️ Modo Construção ([B])"
	build_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	build_btn.pressed.connect(_on_build_pressed)
	left_col.add_child(build_btn)

	var shop_btn := Button.new()
	shop_btn.name = "CosmeticsButton"
	shop_btn.text = "✨ Ateliê de Cosméticos & PIX ([F9])"
	shop_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	shop_btn.pressed.connect(_on_cosmetics_pressed)
	left_col.add_child(shop_btn)

	var guide_btn := Button.new()
	guide_btn.name = "GuideButton"
	guide_btn.text = "🧭 Guia do Explorador & Tutorial ([J])"
	guide_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	guide_btn.pressed.connect(_on_guide_pressed)
	left_col.add_child(guide_btn)

	var fb_btn := Button.new()
	fb_btn.name = "FeedbackButton"
	fb_btn.text = "💬 Mural de Feedback dos Jogadores ([F8])"
	fb_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	fb_btn.pressed.connect(_on_feedback_pressed)
	left_col.add_child(fb_btn)

	var coop_btn := Button.new()
	coop_btn.name = "CoopButton"
	coop_btn.text = "🌐 Jogar Junto / Sala Coop LAN ([F7])"
	coop_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	coop_btn.pressed.connect(_on_coop_pressed)
	left_col.add_child(coop_btn)

	var mobile_btn := Button.new()
	mobile_btn.name = "MobileTouchButton"
	mobile_btn.text = "📱 Modo Celular / Controles Touch ([F6])"
	mobile_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	mobile_btn.pressed.connect(_on_mobile_touch_pressed)
	left_col.add_child(mobile_btn)

	# Coluna direita: Ofícios de mão (tocha, laço, sedativo, vara) + Status da Forja
	var craft_header := Label.new()
	craft_header.name = "CraftHeader"
	craft_header.text = "🔨 Ofícios de Mão (Fabricar no Campo)"
	craft_header.add_theme_font_size_override("font_size", 15)
	craft_header.add_theme_color_override("font_color", Color(0.95, 0.80, 0.45))
	right_col.add_child(craft_header)

	for recipe_id in InventoryComponent.RECIPES:
		var craft_btn := Button.new()
		craft_btn.name = "Craft_" + String(recipe_id)
		craft_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		craft_btn.custom_minimum_size = Vector2(0, 48)
		craft_btn.tooltip_text = MaterialData.of(recipe_id).description
		right_col.add_child(craft_btn)
		craft_btn.pressed.connect(_on_craft_pressed.bind(recipe_id))
		_craft_buttons[recipe_id] = craft_btn

	if forge_status_label:
		forge_status_label.reparent(right_col)
		forge_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		forge_status_label.add_theme_color_override("font_color", Color(0.80, 0.88, 0.80))

	if close_button:
		close_button.reparent(old_vbox)
		close_button.text = "✕ Fechar Central (Tab / Esc)"

	sit_button.pressed.connect(_on_sit_pressed)
	pov_button.pressed.connect(_on_pov_pressed)
	if forge_button:
		forge_button.pressed.connect(_on_forge_pressed)
	if cards_button:
		cards_button.pressed.connect(_on_cards_pressed)
	close_button.pressed.connect(close_menu)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("open_actions"):
		toggle_menu()
	elif is_open and event.is_action_pressed("ui_cancel"):
		close_menu()
		get_viewport().set_input_as_handled()

func toggle_menu() -> void:
	if is_open:
		close_menu()
	else:
		open_menu()

func open_menu() -> void:
	is_open = true
	visible = true
	add_to_group("open_menus")
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if player and player.inventory and not player.inventory.stacks_changed.is_connected(_update_button_texts):
		player.inventory.stacks_changed.connect(_update_button_texts)
	_update_button_texts()

func close_menu() -> void:
	is_open = false
	visible = false
	remove_from_group("open_menus")
	if get_tree().get_nodes_in_group("open_menus").is_empty():
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _update_button_texts() -> void:
	if _header_status and player:
		var gold_txt := ("💰 %s" % WalletComponent.format(player.wallet.money)) if player.wallet else ""
		var weight_txt := ("   ·   🎒 %.0f / %.0f kg" % [player.inventory.get_total_weight(), player.inventory.carry_capacity()]) if player.inventory else ""
		_header_status.text = gold_txt + weight_txt

	for recipe_id in _craft_buttons:
		var data := MaterialData.of(recipe_id)
		var inv: InventoryComponent = player.inventory if player else null
		var parts: Array[String] = []
		for mat in InventoryComponent.RECIPES[recipe_id]:
			var need: int = InventoryComponent.RECIPES[recipe_id][mat]
			var got: int = inv.get_material_count(mat) if inv else 0
			parts.append("%s %d/%d %s" % ["✓" if got >= need else "✗", mini(got, need), need, MaterialData.of(mat).display_name.get_slice(" ", 0)])
		var have: int = inv.get_material_count(recipe_id) if inv else 0
		var shortcut: String = " · [T] usa" if recipe_id == TorchComponent.ITEM else ""
		_craft_buttons[recipe_id].text = "%s %s  (na mochila: %d%s)\n      %s" % [data.icon, data.display_name, have, shortcut, "   ".join(parts)]
		_craft_buttons[recipe_id].disabled = inv == null or not inv.has_materials(InventoryComponent.RECIPES[recipe_id])

	if player:
		if player.is_sitting:
			sit_button.text = "🚶 Levantar e Caminhar"
		else:
			sit_button.text = "🔥 Descansar (sentar)"

		if forge_status_label and player.inventory != null:
			var inv: InventoryComponent = player.inventory
			var capacete: StringName = inv.equipped.get(&"head", &"")
			var eq_text: String = "Equipado: %s\n" % capacete if not capacete.is_empty() else ""
			var horn := inv.best_stack(&"chifre_rinolito")
			var horn_text: String = "Melhor chifre: %s %s" % ["★".repeat(horn.quality), "(Íntegro)" if horn.traits.has(&"integro") else ""] if not horn.is_empty() else "Sem chifre"
			forge_status_label.text = "⚒️ %s%s · %d Placas" % [eq_text, horn_text, inv.get_material_count(&"placa_carapaca")]

func _on_forge_pressed() -> void:
	if player == null or player.inventory == null:
		return
	var station := ForgeStation.nearest_in_range(player)
	if station:
		close_menu()
		station.open_for(player)
		return
	if forge_status_label:
		forge_status_label.text = "⚒️ Forja: vá até a Bigorna da Vila e aperte [E]"

func _on_sit_pressed() -> void:
	if player:
		player.toggle_sit()
		_update_button_texts()
	close_menu()

func _on_pov_pressed() -> void:
	if player and player.camera_rig:
		var ev = InputEventAction.new()
		ev.action = "toggle_camera"
		ev.pressed = true
		Input.parse_input_event(ev)
	close_menu()

func _on_cards_pressed() -> void:
	close_menu()
	var album = get_tree().get_first_node_in_group("card_album") if is_inside_tree() else null
	if album == null:
		album = get_node_or_null("../../CardAlbum")
	if album != null and album.has_method("open_album"):
		album.open_album()

func _on_craft_pressed(recipe_id: StringName) -> void:
	if player == null or player.inventory == null:
		return
	var data := MaterialData.of(recipe_id)
	if player.inventory.craft(recipe_id):
		player.posture_changed.emit("%s Fez %s" % [data.icon, data.display_name])
	else:
		player.posture_changed.emit("Faltam materiais para %s" % data.display_name)
	_update_button_texts()

func _on_inventory_pressed() -> void:
	close_menu()
	var screen := get_node_or_null("../InventoryScreen")
	if screen and screen.has_method("open"):
		screen.open()

func _on_build_pressed() -> void:
	close_menu()
	var bs = get_tree().get_first_node_in_group("building_system") if is_inside_tree() else null
	if bs and bs.has_method("set_building_mode"):
		bs.set_building_mode(true)

func _on_cosmetics_pressed() -> void:
	close_menu()
	var shop := get_node_or_null("../CosmeticsShop")
	if shop and shop.has_method("open_shop"):
		shop.open_shop(player)

func _on_guide_pressed() -> void:
	close_menu()
	var guide := get_node_or_null("../ExplorerGuide")
	if guide and guide.has_method("open_guide"):
		guide.open_guide(player)

func _on_feedback_pressed() -> void:
	close_menu()
	var fb := get_node_or_null("../FeedbackModal")
	if fb and fb.has_method("open_modal"):
		fb.open_modal()

func _on_coop_pressed() -> void:
	close_menu()
	var coop := get_node_or_null("../CoopMenu")
	if coop and coop.has_method("open_menu"):
		coop.open_menu(player)

func _on_mobile_touch_pressed() -> void:
	close_menu()
	var touch := get_node_or_null("../MobileTouchControls")
	if touch and touch.has_method("toggle_touch_mode"):
		touch.toggle_touch_mode()
