extends Control
class_name ActionsMenu

## Menu de Ações do Personagem (Aba TAB)
# Permite sentar/descansar, avançar as horas do dia, meditar e alternar visual.

@export var player: Player
@export var day_night: DirectionalLight3D

@onready var panel: PanelContainer = $PanelContainer
@onready var sit_button: Button = $PanelContainer/MarginContainer/VBoxContainer/SitButton
@onready var wait_button: Button = $PanelContainer/MarginContainer/VBoxContainer/WaitButton
@onready var pov_button: Button = $PanelContainer/MarginContainer/VBoxContainer/PovButton
@onready var forge_button: Button = get_node_or_null("PanelContainer/MarginContainer/VBoxContainer/ForgeButton")
@onready var forge_status_label: Label = get_node_or_null("PanelContainer/MarginContainer/VBoxContainer/ForgeStatusLabel")
@onready var cards_button: Button = get_node_or_null("PanelContainer/MarginContainer/VBoxContainer/CardsButton")
@onready var close_button: Button = $PanelContainer/MarginContainer/VBoxContainer/CloseButton

var is_open: bool = false
var _craft_buttons: Dictionary = {}

func _ready() -> void:
	visible = false
	sit_button.pressed.connect(_on_sit_pressed)
	wait_button.pressed.connect(_on_wait_pressed)
	pov_button.pressed.connect(_on_pov_pressed)
	if forge_button:
		forge_button.pressed.connect(_on_forge_pressed)
	if cards_button:
		cards_button.pressed.connect(_on_cards_pressed)
	
	var build_btn: Button = get_node_or_null("PanelContainer/MarginContainer/VBoxContainer/BuildButton")
	if build_btn == null:
		build_btn = Button.new()
		build_btn.name = "BuildButton"
		build_btn.text = "🏗️ Modo Construção ([B])"
		$PanelContainer/MarginContainer/VBoxContainer.add_child(build_btn)
		$PanelContainer/MarginContainer/VBoxContainer.move_child(build_btn, close_button.get_index())
	build_btn.pressed.connect(_on_build_pressed)

	# Ofícios de captura (GDD-03 §9): laço e sedativo
	for recipe_id in InventoryComponent.RECIPES:
		var craft_btn := Button.new()
		craft_btn.name = "Craft_" + String(recipe_id)
		$PanelContainer/MarginContainer/VBoxContainer.add_child(craft_btn)
		$PanelContainer/MarginContainer/VBoxContainer.move_child(craft_btn, build_btn.get_index())
		craft_btn.pressed.connect(_on_craft_pressed.bind(recipe_id))
		_craft_buttons[recipe_id] = craft_btn
	
	var inv_btn := Button.new()
	inv_btn.name = "InventoryButton"
	inv_btn.text = "🎒 Inventário ([I])"
	$PanelContainer/MarginContainer/VBoxContainer.add_child(inv_btn)
	$PanelContainer/MarginContainer/VBoxContainer.move_child(inv_btn, build_btn.get_index())
	inv_btn.pressed.connect(_on_inventory_pressed)

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
	_update_button_texts()

func close_menu() -> void:
	is_open = false
	visible = false
	remove_from_group("open_menus")
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _update_button_texts() -> void:
	for recipe_id in _craft_buttons:
		var data := MaterialData.of(recipe_id)
		var parts: Array[String] = []
		for mat in InventoryComponent.RECIPES[recipe_id]:
			parts.append("%d %s" % [InventoryComponent.RECIPES[recipe_id][mat], MaterialData.of(mat).display_name.get_slice(" ", 0)])
		var have: int = player.inventory.get_material_count(recipe_id) if player and player.inventory else 0
		_craft_buttons[recipe_id].text = "%s Fazer %s (%s) · tem %d" % [data.icon, data.display_name, " + ".join(parts), have]
		_craft_buttons[recipe_id].disabled = player == null or player.inventory == null or not player.inventory.has_materials(InventoryComponent.RECIPES[recipe_id])
	if player:
		if player.is_sitting:
			sit_button.text = "🚶 Levantar e Caminhar"
		else:
			sit_button.text = "🧘 Sentar no Chão e Descansar"
		
		if forge_status_label and player.inventory != null:
			var inv: InventoryComponent = player.inventory
			var capacete: StringName = inv.equipped.get(&"head", &"")
			var eq_text: String = "Equipado: %s\n" % capacete if not capacete.is_empty() else ""
			var horn := inv.best_stack(&"chifre_rinolito")
			var horn_text: String = "Melhor chifre: %s %s" % ["★".repeat(horn.quality), "(Íntegro)" if horn.traits.has(&"integro") else ""] if not horn.is_empty() else "Sem chifre"
			forge_status_label.text = "%s%s · %d Placas\nMateriais e coleta: [I] Inventário" % [eq_text, horn_text, inv.get_material_count(&"placa_carapaca")]

func _on_forge_pressed() -> void:
	if player == null or player.inventory == null:
		return

	var inv: InventoryComponent = player.inventory
	var horn := inv.best_stack(&"chifre_rinolito")
	var integro: bool = not horn.is_empty() and horn.traits.has(&"integro")
	if inv.craft_and_equip_horn_helmet(horn):
		if forge_status_label:
			if integro:
				forge_status_label.text = "✨ Forjado Elmo Íntegro!\nTrait 'Casca Rígida' (+25% Poise, +20% Defesa) ativo."
			else:
				forge_status_label.text = "🔨 Forjado Elmo Fragmentado!\nTrait 'Reforçado' (+12% Poise, +10% Defesa) ativo."
	elif forge_status_label:
		forge_status_label.text = "❌ Faltam materiais!\nDerrote a besta (Íntegro) ou quebre o chifre (Lascado)."

func _on_sit_pressed() -> void:
	if player:
		player.toggle_sit()
		_update_button_texts()
	close_menu()

func _on_wait_pressed() -> void:
	if day_night and day_night.has_method("get_formatted_time"):
		# Avança 4 horas no ciclo natural
		var target_hour = fposmod(day_night.current_time_hours + 4.0, 24.0)
		var tween = create_tween()
		tween.tween_property(day_night, "current_time_hours", target_hour, 1.2).set_trans(Tween.TRANS_SINE)
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
