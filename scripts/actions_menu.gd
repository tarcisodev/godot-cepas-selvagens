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
@onready var close_button: Button = $PanelContainer/MarginContainer/VBoxContainer/CloseButton

var is_open: bool = false

func _ready() -> void:
	visible = false
	sit_button.pressed.connect(_on_sit_pressed)
	wait_button.pressed.connect(_on_wait_pressed)
	pov_button.pressed.connect(_on_pov_pressed)
	if forge_button:
		forge_button.pressed.connect(_on_forge_pressed)
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
	if player:
		if player.is_sitting:
			sit_button.text = "🚶 Levantar e Caminhar"
		else:
			sit_button.text = "🧘 Sentar no Chão e Descansar"
		
		if forge_status_label and player.inventory != null:
			var inv: InventoryComponent = player.inventory
			var integros := inv.get_material_count(&"chifre_integro")
			var lascados := inv.get_material_count(&"chifre_lascado")
			var placas := inv.get_material_count(&"placa_carapaca")
			var capacete: StringName = inv.equipped.get(&"head", &"")
			if not capacete.is_empty():
				forge_status_label.text = "Equipado: %s\nInsumos: %d Íntegros · %d Lascados · %d Placas" % [capacete, integros, lascados, placas]
			else:
				forge_status_label.text = "Insumos: %d Íntegros · %d Lascados · %d Placas" % [integros, lascados, placas]

func _on_forge_pressed() -> void:
	if player == null or player.inventory == null:
		return
	
	var inv: InventoryComponent = player.inventory
	if inv.get_material_count(&"chifre_integro") > 0 and inv.get_material_count(&"placa_carapaca") >= 1:
		var ok := inv.craft_and_equip_horn_helmet(&"chifre_integro")
		if ok and forge_status_label:
			forge_status_label.text = "✨ Forjado Elmo Íntegro!\nTrait 'Casca Rígida' (+25% Poise, +20% Defesa) ativo."
	elif inv.get_material_count(&"chifre_lascado") > 0 and inv.get_material_count(&"placa_carapaca") >= 1:
		var ok := inv.craft_and_equip_horn_helmet(&"chifre_lascado")
		if ok and forge_status_label:
			forge_status_label.text = "🔨 Forjado Elmo Fragmentado!\nTrait 'Reforçado' (+12% Poise, +10% Defesa) ativo."
	else:
		if forge_status_label:
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
