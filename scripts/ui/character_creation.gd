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
	# Pelo caminho do nó: o identificador global do autoload não existe em scripts rodados com -s (testes).
	get_node("/root/SaveGame").start_new_game(dna, character_name if character_name != "" else DEFAULT_NAME)

func _back() -> void:
	get_tree().change_scene_to_file(MAIN_MENU)
