extends Control
class_name CharacterCreation

## Criação de personagem da conta online (B09/B24): nome + aparência no AppearanceEditor.
# "Começar jornada" grava o personagem no servidor (remoto ou o hospedado no PC) e entra
# no mundo com ele; "Voltar" (ou Esc) retorna ao título.

const BACKGROUND: String = "res://assets/ui/menu_background.png"
const MAIN_MENU: String = "res://scenes/main_menu.tscn"
const DEFAULT_DNA: String = "res://resources/characters/player_dna.tres"
const DEFAULT_NAME := "Andarilho"

var editor: AppearanceEditor
var _error_lbl: Label

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
		# Cliente conectado ou host hospedando no PC: o personagem vai para a conta no servidor
		var networked: bool = st == NetworkManagerAutoload.NetworkState.CONNECTED_CLIENT \
			or st == NetworkManagerAutoload.NetworkState.HOSTING_SERVER
		if networked and not str(net.get("current_account")).is_empty():
			is_online = true

	# Jogo só online: sem conta autenticada não há onde gravar o personagem
	if not is_online:
		_show_error("Sessão expirada: entre na sua conta novamente.")
		return

	var dna_dict: Dictionary = dna.to_dict()
	# Conecta antes de enviar: no host a resposta é emitida na mesma chamada
	net.character_created.connect(func(success: bool, message: String, _cdata: Dictionary):
		if success:
			net.send_enter_world_request(final_name)
			# Pelo caminho do nó: o identificador global do autoload não existe em scripts rodados com -s (testes).
			get_node("/root/SaveGame").enter_online_world(final_name, {}, dna)
		else:
			push_error("[CharacterCreation] Falha ao criar personagem online: %s" % message)
			_show_error(message)
	, CONNECT_ONE_SHOT)
	net.send_create_character_request(final_name, dna_dict)

func _show_error(message: String) -> void:
	if _error_lbl == null:
		_error_lbl = Label.new()
		_error_lbl.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 24)
		_error_lbl.grow_horizontal = Control.GROW_DIRECTION_BOTH
		_error_lbl.add_theme_font_size_override("font_size", 16)
		_error_lbl.add_theme_color_override("font_color", Color(1, 0.5, 0.4))
		add_child(_error_lbl)
	_error_lbl.text = "❌ %s" % message

func _back() -> void:
	get_tree().change_scene_to_file(MAIN_MENU)
