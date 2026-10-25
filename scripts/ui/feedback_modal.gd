class_name FeedbackModal
extends Control

## Mural de Feedback dos Jogadores ("Caixa de Ideias & Avaliações da Vila").
## Permite que quem está testando o jogo (como o criador, sua esposa e amigos)
## deixe notas, estrelas, categorias e ideias diretamente dentro do jogo.

const FEEDBACK_JSON_PATH := "user://player_feedback.json"
const FEEDBACK_MD_PATH := "res://docs/feedback_jogadores.md"

const CATEGORIES: Array[String] = [
	"✨ Céu, Estrelas & Visual",
	"👗 Personagem Feminino & Cosméticos",
	"⚔️ Combate, Armas & Boss",
	"🌿 Clima, Chuva & Natureza",
	"🧭 HUD, Menu TAB & Tutorial",
	"💡 Nova Ideia para o Jogo",
	"🐛 Bug ou Ajuste de Ritmo",
]

var is_open: bool = false
var rating: int = 5
var _author_edit: LineEdit
var _category_opt: OptionButton
var _comment_edit: TextEdit
var _star_buttons: Array[Button] = []
var _status_label: Label
var _history_box: VBoxContainer

func _ready() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F8:
			if is_open:
				close_modal()
			else:
				open_modal()
			get_viewport().set_input_as_handled()
		elif is_open and event.keycode == KEY_ESCAPE:
			close_modal()
			get_viewport().set_input_as_handled()

func open_modal() -> void:
	is_open = true
	visible = true
	add_to_group("open_menus")
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	var sg := get_node_or_null("/root/SaveGame")
	if _author_edit and _author_edit.text.strip_edges().is_empty() and sg and not str(sg.get("character_name")).is_empty():
		_author_edit.text = str(sg.get("character_name"))
	_refresh_stars()
	_refresh_history()

func close_modal() -> void:
	if not is_open:
		return
	is_open = false
	visible = false
	remove_from_group("open_menus")
	if get_tree().get_nodes_in_group("open_menus").is_empty():
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.04, 0.78)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := MarginContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.add_theme_constant_override("margin_left", 70)
	center.add_theme_constant_override("margin_right", 70)
	center.add_theme_constant_override("margin_top", 45)
	center.add_theme_constant_override("margin_bottom", 45)
	add_child(center)

	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.10, 0.09, 0.96)
	sb.border_color = Color(0.76, 0.62, 0.34, 0.85)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 24
	sb.content_margin_right = 24
	sb.content_margin_top = 18
	sb.content_margin_bottom = 18
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 12)
	panel.add_child(root_vbox)

	# Cabeçalho
	var header := HBoxContainer.new()
	root_vbox.add_child(header)

	var title := Label.new()
	title.text = "💬 MURAL DOS EXPLORADORES — FEEDBACK & IDEIAS [F8]"
	title.add_theme_font_size_override("font_size", 21)
	title.add_theme_color_override("font_color", Color(0.98, 0.86, 0.52))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var close_btn := Button.new()
	close_btn.text = "✕ Fechar [Esc]"
	close_btn.pressed.connect(close_modal)
	header.add_child(close_btn)

	var sub := Label.new()
	sub.text = "Deixe aqui suas impressões de playtest, sugestões da sua sessão ou ideias novas! Tudo fica salvo no projeto."
	sub.add_theme_font_size_override("font_size", 14)
	sub.add_theme_color_override("font_color", Color(0.76, 0.84, 0.78))
	root_vbox.add_child(sub)

	var split := HBoxContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_theme_constant_override("separation", 20)
	root_vbox.add_child(split)

	# Coluna Esquerda: Formulário
	var form := VBoxContainer.new()
	form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form.add_theme_constant_override("separation", 10)
	split.add_child(form)

	var author_row := HBoxContainer.new()
	author_row.add_theme_constant_override("separation", 8)
	form.add_child(author_row)
	var author_lbl := Label.new()
	author_lbl.text = "Jogador(a):"
	author_lbl.custom_minimum_size = Vector2(105, 0)
	author_row.add_child(author_lbl)
	_author_edit = LineEdit.new()
	_author_edit.placeholder_text = "Ex: Tarcísio / Esposa / Convidado"
	_author_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	author_row.add_child(_author_edit)

	var star_row := HBoxContainer.new()
	star_row.add_theme_constant_override("separation", 8)
	form.add_child(star_row)
	var star_lbl := Label.new()
	star_lbl.text = "Avaliação:"
	star_lbl.custom_minimum_size = Vector2(105, 0)
	star_row.add_child(star_lbl)
	for i in range(1, 6):
		var sb_btn := Button.new()
		sb_btn.custom_minimum_size = Vector2(44, 34)
		sb_btn.pressed.connect(func() -> void:
			rating = i
			_refresh_stars()
		)
		star_row.add_child(sb_btn)
		_star_buttons.append(sb_btn)

	var cat_row := HBoxContainer.new()
	cat_row.add_theme_constant_override("separation", 8)
	form.add_child(cat_row)
	var cat_lbl := Label.new()
	cat_lbl.text = "Tema:"
	cat_lbl.custom_minimum_size = Vector2(105, 0)
	cat_row.add_child(cat_lbl)
	_category_opt = OptionButton.new()
	for c in CATEGORIES:
		_category_opt.add_item(c)
	_category_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cat_row.add_child(_category_opt)

	var msg_lbl := Label.new()
	msg_lbl.text = "O que você achou ou o que gostaria de ver no jogo?"
	form.add_child(msg_lbl)

	_comment_edit = TextEdit.new()
	_comment_edit.placeholder_text = "Escreva aqui seu comentário, elogio, bug encontrado ou ideia nova..."
	_comment_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_comment_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	form.add_child(_comment_edit)

	var submit_btn := Button.new()
	submit_btn.text = "📨 Registrar Feedback no Mural"
	submit_btn.custom_minimum_size = Vector2(0, 42)
	submit_btn.pressed.connect(_on_submit)
	form.add_child(submit_btn)

	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 14)
	_status_label.add_theme_color_override("font_color", Color(0.55, 0.95, 0.65))
	form.add_child(_status_label)

	# Coluna Direita: Histórico do Mural
	var right_col := VBoxContainer.new()
	right_col.custom_minimum_size = Vector2(360, 0)
	right_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_col.add_theme_constant_override("separation", 8)
	split.add_child(right_col)

	var hist_title := Label.new()
	hist_title.text = "📜 Registros Recentes no Mural"
	hist_title.add_theme_font_size_override("font_size", 16)
	hist_title.add_theme_color_override("font_color", Color(0.95, 0.84, 0.55))
	right_col.add_child(hist_title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right_col.add_child(scroll)

	_history_box = VBoxContainer.new()
	_history_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_history_box.add_theme_constant_override("separation", 8)
	scroll.add_child(_history_box)

func _refresh_stars() -> void:
	for i in _star_buttons.size():
		var active := (i + 1) <= rating
		_star_buttons[i].text = "★" if active else "☆"
		_star_buttons[i].modulate = Color(1.0, 0.85, 0.25) if active else Color(0.6, 0.6, 0.6)

func _on_submit() -> void:
	var text := _comment_edit.text.strip_edges()
	if text.is_empty():
		_status_label.text = "⚠️ Escreva uma mensagem antes de registrar!"
		return
	var author := _author_edit.text.strip_edges()
	if author.is_empty():
		author = "Explorador(a)"
	var category := CATEGORIES[_category_opt.selected] if _category_opt.selected >= 0 else CATEGORIES[0]
	var dt := Time.get_datetime_string_from_system(false, true)

	var entry := {
		"date": dt,
		"author": author,
		"rating": rating,
		"category": category,
		"comment": text,
	}
	save_feedback_entry(entry)
	_comment_edit.text = ""
	_status_label.text = "✅ Feedback registrado com sucesso! Obrigado por ajudar a construir Cepa Selvagem!"
	_refresh_history()

static func load_entries() -> Array:
	if not FileAccess.file_exists(FEEDBACK_JSON_PATH):
		return []
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(FEEDBACK_JSON_PATH))
	return parsed if parsed is Array else []

static func save_feedback_entry(entry: Dictionary) -> void:
	var list := load_entries()
	list.push_front(entry)
	var f := FileAccess.open(FEEDBACK_JSON_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(list, "\t"))
		f.close()

	# Também registra em docs/feedback_jogadores.md quando disponível
	var md_path := ProjectSettings.globalize_path(FEEDBACK_MD_PATH)
	var content := ""
	if FileAccess.file_exists(FEEDBACK_MD_PATH):
		content = FileAccess.get_file_as_string(FEEDBACK_MD_PATH)
	else:
		content = "# Mural de Feedback dos Jogadores — Cepa Selvagem\n\nRegistros enviados diretamente de dentro do jogo:\n\n"
	var stars := "★".repeat(int(entry.get("rating", 5))) + "☆".repeat(5 - int(entry.get("rating", 5)))
	content += "## %s — %s (%s)\n- **Tema:** %s\n- **Mensagem:** %s\n\n---\n\n" % [
		entry.get("author", "Explorador"),
		stars,
		entry.get("date", ""),
		entry.get("category", ""),
		entry.get("comment", ""),
	]
	var md_file := FileAccess.open(md_path, FileAccess.WRITE)
	if md_file:
		md_file.store_string(content)
		md_file.close()

func _refresh_history() -> void:
	if _history_box == null:
		return
	for c in _history_box.get_children():
		c.queue_free()
	var list := load_entries()
	if list.is_empty():
		var empty := Label.new()
		empty.text = "Nenhum feedback registrado ainda.\nSeja o primeiro a deixar sua avaliação!"
		empty.add_theme_color_override("font_color", Color(0.65, 0.7, 0.65))
		_history_box.add_child(empty)
		return
	for item in list:
		var card := PanelContainer.new()
		var csb := StyleBoxFlat.new()
		csb.bg_color = Color(0.12, 0.15, 0.14, 0.9)
		csb.set_corner_radius_all(8)
		csb.content_margin_left = 10
		csb.content_margin_right = 10
		csb.content_margin_top = 8
		csb.content_margin_bottom = 8
		card.add_theme_stylebox_override("panel", csb)
		_history_box.add_child(card)

		var vb := VBoxContainer.new()
		card.add_child(vb)

		var stars := "★".repeat(int(item.get("rating", 5)))
		var head := Label.new()
		head.text = "%s  ·  %s  (%s)" % [item.get("author", "Explorador"), stars, item.get("category", "")]
		head.add_theme_font_size_override("font_size", 14)
		head.add_theme_color_override("font_color", Color(0.98, 0.86, 0.48))
		vb.add_child(head)

		var msg := Label.new()
		msg.text = str(item.get("comment", ""))
		msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		msg.add_theme_font_size_override("font_size", 13)
		vb.add_child(msg)
