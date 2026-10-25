extends Control
class_name CharacterCreation

## Criação de personagem do Novo jogo (B09): nome + aparência no AppearanceEditor.
# "Começar jornada" entra no mundo com esse personagem; "Voltar" (ou Esc) retorna ao título
# sem apagar o save, que só é substituído quando o jogo novo começa de fato.

const BACKGROUND: String = "res://assets/ui/menu_background.png"
const MAIN_MENU: String = "res://scenes/main_menu.tscn"
const DEFAULT_DNA: String = "res://resources/characters/player_dna.tres"
const DEFAULT_NAME := "Andarilho"

var editor: AppearanceEditor

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	var bg := ColorRect.new()
	bg.color = Color(0.09, 0.13, 0.1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	if ResourceLoader.exists(BACKGROUND):
		var tex := TextureRect.new()
		tex.texture = load(BACKGROUND)
		tex.set_anchors_preset(Control.PRESET_FULL_RECT)
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tex.modulate = Color(0.55, 0.55, 0.55)
		add_child(tex)

	editor = AppearanceEditor.new()
	editor.title_text = "🌱 Novo personagem"
	editor.confirm_text = "Começar jornada ▶"
	editor.cancel_text = "Voltar [Esc]"
	editor.show_name = true
	editor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 32)
	editor.confirmed.connect(_on_confirmed)
	editor.cancelled.connect(_back)
	add_child(editor)
	editor.edit(load(DEFAULT_DNA) as CharacterDNA)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_back()
		get_viewport().set_input_as_handled()

func _on_confirmed(dna: CharacterDNA) -> void:
	var character_name := editor.get_character_name()
	var final_name := character_name if character_name != "" else DEFAULT_NAME
	var net: Node = get_node_or_null("/root/NetworkManager")
	var is_online: bool = false
	if net != null and "state" in net:
		var st = net.get("state")
		if st == NetworkManagerAutoload.NetworkState.CONNECTED_CLIENT and not net.get("current_account").is_empty():
			is_online = true

	if is_online:
		var dna_dict: Dictionary = dna.to_dict()
		net.send_create_character_request(final_name, dna_dict)
		net.character_created.connect(func(success: bool, message: String, _cdata: Dictionary):
			if success:
				net.send_enter_world_request(final_name)
				get_tree().change_scene_to_file("res://scenes/world.tscn")
			else:
				push_error("[CharacterCreation] Falha ao criar personagem online: %s" % message)
		, CONNECT_ONE_SHOT)
	else:
		# Pelo caminho do nó: o identificador global do autoload não existe em scripts rodados com -s (testes).
		get_node("/root/SaveGame").start_new_game(dna, final_name)

func _back() -> void:
	get_tree().change_scene_to_file(MAIN_MENU)
