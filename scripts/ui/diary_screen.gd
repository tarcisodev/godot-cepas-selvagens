class_name DiaryScreen
extends Control

const _Player = preload("res://scripts/player.gd")
const _DiaryComponent = preload("res://scripts/components/diary_component.gd")
const _FeatLedger = preload("res://scripts/data/feat_ledger.gd")
const _MilestoneDef = preload("res://scripts/data/milestone_def.gd")
const _MilestoneTable = preload("res://scripts/data/milestone_table.gd")
const _GuildBook = preload("res://scripts/systems/guild_book.gd")
const _GuildLedger = preload("res://scripts/data/guild_ledger.gd")

## Tela do Diário do Caçador ([L], GDD-19 §4 a §7, B40 fase 4): capa com os totais e o título,
## um separador por capítulo (feitos, recordes, maestria e Marcos), as Páginas com filtro,
## todos os Marcos e as mostras recebidas. Embaixo, mostrar o separador aberto a quem está perto.
## Só lê o FeatLedger; quem escreve é o DiaryComponent com autoridade (ADR-0002).

const PANEL_BG := Color(0.11, 0.085, 0.065, 0.97)
const PAGE_BG := Color(0.93, 0.87, 0.74)
const INK := Color(0.2, 0.14, 0.09)
const INK_DIM := Color(0.42, 0.34, 0.25)
const LEATHER := Color(0.42, 0.26, 0.15)
const GOLD := Color(0.9, 0.72, 0.36)
const TIER_COLORS: Array[Color] = [Color(0.55, 0.42, 0.3), Color(0.55, 0.6, 0.66), Color(0.85, 0.65, 0.2)]

## Separadores: capa, os oito capítulos e as listas
const TABS: Array[Dictionary] = [
	{"id": &"capa", "name": "Capa", "icon": "📖"},
	{"id": &"caca", "name": "Caça", "icon": "🏹"},
	{"id": &"coleta", "name": "Coleta", "icon": "🌿"},
	{"id": &"forja", "name": "Forja", "icon": "🔨"},
	{"id": &"fogao", "name": "Fogão", "icon": "🍲"},
	{"id": &"criadouro", "name": "Criadouro", "icon": "🐎"},
	{"id": &"sangue", "name": "Sangue", "icon": "⚔️"},
	{"id": &"andancas", "name": "Andanças", "icon": "🧭"},
	{"id": &"balcao", "name": "Balcão", "icon": "⚖️"},
	{"id": &"paginas", "name": "Páginas", "icon": "📜"},
	{"id": &"marcos", "name": "Marcos", "icon": "🏅"},
	{"id": &"mostras", "name": "Mostras", "icon": "🤝"},
	{"id": &"totem", "name": "Totem", "icon": "📕"},
]
const COUNTER_NAMES: Dictionary = {
	"abates": "Abates", "assistencias": "Assistências", "quedas": "Quedas",
	"partes_quebradas": "Partes quebradas", "duas_partes": "Duas partes antes da queda",
	"chefes": "Chefes derrubados", "chefes_ilesos": "Chefes sem golpe forte",
	"recursos": "Recursos colhidos", "peixes": "Peixes", "pecas": "Peças forjadas",
	"barras": "Barras fundidas", "pratos": "Pratos", "queimados": "Queimados",
	"capturas": "Capturas", "crias": "Crias", "perdidas": "Companheiras perdidas",
	"abates_dignos": "Abates dignos", "lendas_abatidas": "Lendas derrubadas",
	"metros_a_pe": "Metros a pé", "metros_montado": "Metros montado", "lugares": "Lugares pisados",
	"ilhas": "Ilhas", "vendas": "Vendas", "compras": "Compras", "moedas": "Moedas ganhas",
	"missoes": "Missões do Quadro", "caravanas": "Caravanas entregues",
}
const PREFIX_NAMES: Dictionary = {"especie:": "Por espécie", "material:": "Por material", "familia:": "Por família", "receita:": "Por receita"}
const RECORD_NAMES: Dictionary = {
	"maior_caca": "Maior caça", "melhor_coleta": "Melhor coleta", "melhor_peixe": "Melhor peixe",
	"melhor_peca": "Melhor peça", "melhor_prato": "Melhor prato", "maior_geracao": "Maior geração",
	"maior_elo": "Maior Elo", "maior_venda": "Maior venda",
}
## Maestrias mostradas ao lado de cada capítulo (GDD-02); o Diário não dá XP
const CHAPTER_MASTERY: Dictionary = {
	&"caca": [&"lâmina", &"concussão", &"canalização", &"esfola"],
	&"coleta": [&"coleta"],
	&"forja": [&"forja"],
	&"sangue": [&"lâmina", &"concussão", &"canalização"],
}
const PAGE_FILTERS: Array[Array] = [["", "Todas"], ["abate", "Abates"], ["assistencia", "Assistências"], ["queda", "Quedas"], ["marco", "Marcos"], ["perda", "Perdas"]]
const PAGE_ICONS: Dictionary = {"abate": "🗡", "assistencia": "🤝", "queda": "💀", "marco": "🏅", "perda": "🕯"}

@export var player: Node

var current_tab: StringName = &"capa"
var page_filter: String = ""
## Índice (no ledger) da Página escolhida para mostrar
var selected_page: int = -1

var _diary: _DiaryComponent
var _tab_buttons: Dictionary = {}
var _content: VBoxContainer
var _scroll: ScrollContainer
var _header_title: Label
var _target_pick: OptionButton
var _show_btn: Button
var _status: Label

func _ready() -> void:
	# Aberta antes de entrar na árvore (ferramentas, testes): não esconde de novo
	visible = is_in_group("open_menus")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 20
	_build_ui()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_L:
		if visible or get_tree().get_nodes_in_group("open_menus").is_empty():
			toggle()
			get_viewport().set_input_as_handled()
	elif visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

func toggle() -> void:
	if visible:
		close()
	else:
		open()

func open() -> void:
	CustomCursor.ensure_installed(get_tree())
	_bind()
	visible = true
	add_to_group("open_menus")
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	refresh()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.15)

func close() -> void:
	visible = false
	remove_from_group("open_menus")
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _bind() -> void:
	if player == null and is_inside_tree():
		player = get_tree().get_first_node_in_group("player")
	var d: _DiaryComponent = player.get_node_or_null("DiaryComponent") as _DiaryComponent if player else null
	if d == _diary:
		return
	for sig in ["page_written", "milestone_reached", "showcase_received", "snapshot_applied", "guild_feat_reached"]:
		if _diary and _diary.is_connected(sig, _on_diary_changed):
			_diary.disconnect(sig, _on_diary_changed)
	_diary = d
	# Cliente online: o Livro do Totem chega do servidor depois de pedido
	var net := get_node_or_null("/root/NetworkManager")
	if net and net.has_signal("guild_board_received") and not net.guild_board_received.is_connected(_on_diary_changed):
		net.guild_board_received.connect(_on_diary_changed)
	if _diary:
		for sig in ["page_written", "milestone_reached", "showcase_received", "snapshot_applied", "guild_feat_reached"]:
			_diary.connect(sig, _on_diary_changed)

func _on_diary_changed(_arg = null) -> void:
	if visible:
		refresh()

func select_tab(id: StringName) -> void:
	current_tab = id
	selected_page = -1
	refresh()

# ---------------------------------------------------------------- montagem

func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var book := PanelContainer.new()
	book.custom_minimum_size = Vector2(1000, 620)
	book.add_theme_stylebox_override("panel", _box(PANEL_BG, LEATHER, 14, 3, Vector2(14, 12)))
	center.add_child(book)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	book.add_child(col)

	var head := HBoxContainer.new()
	col.add_child(head)
	_header_title = _label("📖 Diário do Caçador", 22, GOLD)
	_header_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_header_title)
	var close_btn := Button.new()
	close_btn.text = "✕ Fechar [L]"
	close_btn.pressed.connect(close)
	head.add_child(close_btn)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	col.add_child(body)

	var tabs := VBoxContainer.new()
	tabs.custom_minimum_size.x = 170
	tabs.add_theme_constant_override("separation", 4)
	body.add_child(tabs)
	for t in TABS:
		var b := Button.new()
		b.text = "%s  %s" % [t.icon, t.name]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.toggle_mode = true
		b.pressed.connect(select_tab.bind(t.id))
		tabs.add_child(b)
		_tab_buttons[t.id] = b

	var page := PanelContainer.new()
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_theme_stylebox_override("panel", _box(PAGE_BG, LEATHER.darkened(0.2), 8, 2, Vector2(16, 12)))
	body.add_child(page)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(_scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 6)
	_scroll.add_child(_content)

	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 8)
	col.add_child(foot)
	foot.add_child(_label("Mostrar a:", 14, PAGE_BG))
	_target_pick = OptionButton.new()
	_target_pick.custom_minimum_size.x = 220
	foot.add_child(_target_pick)
	_show_btn = Button.new()
	_show_btn.text = "🤝 Mostrar"
	_show_btn.pressed.connect(_on_show_pressed)
	foot.add_child(_show_btn)
	_status = _label("", 13, GOLD)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(_status)

# ---------------------------------------------------------------- conteúdo

func refresh() -> void:
	if _content == null:
		return
	for b in _tab_buttons:
		_tab_buttons[b].button_pressed = b == current_tab
	for c in _content.get_children():
		_content.remove_child(c)
		c.queue_free()
	if _diary == null:
		_content.add_child(_label("Sem Diário.", 16, INK))
		return
	var l := _diary.ledger
	_header_title.text = "📖 Diário de %s%s" % [_DiaryComponent.describe(player)["name"], ("  ·  " + l.active_title) if l.active_title != "" else ""]
	match current_tab:
		&"capa":
			_build_cover(l)
		&"paginas":
			_build_pages(l)
		&"marcos":
			_build_all_milestones(l)
		&"mostras":
			_build_showcases()
		&"totem":
			_build_guild_book()
		_:
			_build_chapter(l, current_tab)
	_refresh_targets()

func _build_cover(l: _FeatLedger) -> void:
	_content.add_child(_heading("Capa"))
	var hours := float(player.get("play_time")) / 3600.0 if player and player.get("play_time") != null else 0.0
	var tiers := [0, 0, 0]
	for id in l.milestones:
		var def := _MilestoneTable.get_def(StringName(id))
		if def:
			tiers[def.tier] += 1
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 26)
	grid.add_theme_constant_override("v_separation", 10)
	_content.add_child(grid)
	for pair in [
		["Tempo jogado", "%dh %02dmin" % [floori(hours), floori(fmod(hours, 1.0) * 60.0)]],
		["Abates", str(l.count(&"capa", "abates"))],
		["Quedas", str(l.count(&"capa", "quedas"))],
		["Lugares pisados", str(l.count(&"andancas", "lugares"))],
		["Páginas", str(l.pages.size())],
		["Marcos", "%d Rastro · %d Trilha · %d Lenda" % tiers],
	]:
		grid.add_child(_stat(pair[0], pair[1]))

	_content.add_child(_heading("Título embaixo do nome"))
	var pick := OptionButton.new()
	pick.name = "TitlePick"
	pick.add_item("(sem título)")
	for t in l.titles:
		pick.add_item(t)
	pick.selected = l.titles.find(l.active_title) + 1
	pick.item_selected.connect(func(i): choose_title("" if i == 0 else l.titles[i - 1]))
	_content.add_child(pick)
	if l.titles.is_empty():
		_content.add_child(_label("Crave um Marco para ganhar o primeiro título.", 13, INK_DIM))

	_content.add_child(_heading("Adornos"))
	_content.add_child(_label(", ".join(l.adornos.map(func(a): return a.capitalize())) if not l.adornos.is_empty() else "Nenhum ainda (vêm dos Marcos de Lenda).", 14, INK, true))
	if not l.board_access.is_empty():
		_content.add_child(_heading("Contratos de Mestre no Quadro"))
		_content.add_child(_label(", ".join(l.board_access.map(func(c): return _tab_name(StringName(c)))), 14, INK))

func _build_chapter(l: _FeatLedger, chapter: StringName) -> void:
	_content.add_child(_heading("%s %s" % [_tab_icon(chapter), _tab_name(chapter)]))
	var counters: Dictionary = l.counters.get(String(chapter), {})
	var plain: Array = []
	var grouped: Dictionary = {}
	for key in counters:
		var k := String(key)
		var prefix := ""
		for p in PREFIX_NAMES:
			if k.begins_with(p):
				prefix = p
		if prefix != "":
			grouped.get_or_add(prefix, []).append("%s %d" % [k.trim_prefix(prefix).capitalize(), counters[key]])
		elif not k.begins_with("lugar:"):
			plain.append([COUNTER_NAMES.get(k, k.capitalize()), str(counters[key])])
	if plain.is_empty() and grouped.is_empty():
		_content.add_child(_label("Nada escrito aqui ainda.", 14, INK_DIM))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 26)
	grid.add_theme_constant_override("v_separation", 8)
	_content.add_child(grid)
	for pair in plain:
		grid.add_child(_stat(pair[0], pair[1]))
	for p in grouped:
		_content.add_child(_label("%s: %s" % [PREFIX_NAMES[p], ", ".join(grouped[p])], 13, INK, true))
	if chapter == &"coleta" and l.distinct(&"coleta", "lugar:") > 0:
		_content.add_child(_label("Colheu em %d lugares" % l.distinct(&"coleta", "lugar:"), 13, INK))

	var records: Dictionary = l.records.get(String(chapter), {})
	if not records.is_empty():
		_content.add_child(_heading("Recordes"))
		for key in records:
			var r: Dictionary = records[key]
			_content.add_child(_label("%s: %s (%s) — dia %d" % [RECORD_NAMES.get(key, key), str(r.get("label", "")), _num(r.get("value", 0)), int(r.get("day", 0))], 14, INK))

	var tags: Array = CHAPTER_MASTERY.get(chapter, [])
	var mastery = player.get("mastery") if player else null
	if not tags.is_empty() and mastery:
		_content.add_child(_heading("Maestria (só para ver)"))
		_content.add_child(_label("  ·  ".join(tags.map(func(t): return "%s %d" % [String(t).capitalize(), mastery.get_level(t)])), 14, INK))

	_content.add_child(_heading("Marcos"))
	for def in _MilestoneTable.all():
		if def.chapter == chapter:
			_content.add_child(_milestone_row(l, def))

func _build_pages(l: _FeatLedger) -> void:
	_content.add_child(_heading("Páginas"))
	var bar := HBoxContainer.new()
	_content.add_child(bar)
	for f in PAGE_FILTERS:
		var b := Button.new()
		b.text = f[1]
		b.toggle_mode = true
		b.button_pressed = page_filter == f[0]
		b.pressed.connect(func(): page_filter = f[0]; selected_page = -1; refresh())
		bar.add_child(b)
	var any := false
	for i in range(l.pages.size() - 1, -1, -1):
		var p: Dictionary = l.pages[i]
		if page_filter != "" and p.get("kind", "") != page_filter:
			continue
		any = true
		var row := Button.new()
		row.text = page_text(p)
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.toggle_mode = true
		row.button_pressed = i == selected_page
		row.clip_text = true
		row.pressed.connect(func(): selected_page = i; refresh())
		_content.add_child(row)
	if not any:
		_content.add_child(_label("Nenhuma Página aqui ainda.", 14, INK_DIM))

func _build_all_milestones(l: _FeatLedger) -> void:
	_content.add_child(_heading("Marcos (%d de %d)" % [l.milestones.size(), _MilestoneTable.all().size()]))
	var last: StringName = &""
	for def in _MilestoneTable.all():
		if def.chapter != last:
			last = def.chapter
			_content.add_child(_label("%s %s" % [_tab_icon(last), _tab_name(last)], 15, LEATHER))
		_content.add_child(_milestone_row(l, def))

func _build_showcases() -> void:
	_content.add_child(_heading("Mostras recebidas"))
	if _diary.showcases.is_empty():
		_content.add_child(_label("Quando alguém perto mostrar o Diário para você, aparece aqui.", 14, INK_DIM))
	for s in _diary.showcases:
		_content.add_child(_label(showcase_text(s), 14, INK, true))

## Livro do Totem da guilda do dono (GDD-19 §7): o Diário abre o mesmo Livro do Totem
func _build_guild_book() -> void:
	_content.add_child(_heading("📕 Livro do Totem"))
	var book: Dictionary = _GuildBook.view_for(player).get("book", {})
	if book.is_empty():
		_content.add_child(_label("Sem guilda, sem Livro do Totem. Quem é membro vê aqui quem deu o quê na semana.", 14, INK_DIM, true))
		return
	_content.add_child(_label("[%s] %s · semana de %s" % [book.get("tag", ""), book.get("guild", ""), _GuildLedger.week_start_text(int(book["week"]))], 14, INK_DIM))
	var rows: Array = book.get("rows", [])
	if rows.is_empty():
		_content.add_child(_label("Ninguém contribuiu nesta semana ainda.", 14, INK_DIM))
	for row in rows:
		_content.add_child(_label(_GuildBook.row_text(row), 14, INK, true))
	_content.add_child(_heading("Feitos da Guilda"))
	for line in _GuildBook.feat_lines(book):
		_content.add_child(_label(line, 14, LEATHER if line.begins_with("✔") else INK, true))

func _milestone_row(l: _FeatLedger, def: _MilestoneDef) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var done := l.has_milestone(def.id)
	var tier := _label(_MilestoneDef.TIER_NAMES[def.tier], 13, TIER_COLORS[def.tier])
	tier.custom_minimum_size.x = 56
	row.add_child(tier)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	text.add_child(_label(("✔ " if done else "") + def.description + ("  (aguardando)" if def.pending else ""), 14, INK if not def.pending else INK_DIM, true))
	var rewards: Array[String] = ["título “%s”" % def.title]
	if def.card_id != &"":
		rewards.append("carta")
	if def.adorno != &"":
		rewards.append("adorno")
	if def.board_access:
		rewards.append("Contrato de Mestre")
	text.add_child(_label("Dá: " + ", ".join(rewards), 12, INK_DIM))
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(140, 14)
	bar.show_percentage = false
	bar.value = 100.0 if done else def.progress(l) * 100.0
	bar.add_theme_stylebox_override("background", _box(PAGE_BG.darkened(0.18), LEATHER.darkened(0.1), 4, 1))
	bar.add_theme_stylebox_override("fill", _box(TIER_COLORS[def.tier] if done else LEATHER.lightened(0.15), Color.TRANSPARENT, 4, 0))
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(bar)
	var count := _label("%s/%s" % [_num(minf(def.current(l), def.threshold)), _num(def.threshold)], 12, INK_DIM)
	count.custom_minimum_size.x = 52
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(count)
	return row

# ---------------------------------------------------------------- título e mostrar

func choose_title(t: String) -> bool:
	if _diary == null or not _diary.ledger.set_title(t):
		return false
	_status.text = "Título: %s" % (t if t != "" else "nenhum")
	refresh()
	return true

## O que o separador aberto mostra: capa → título, capítulo → capítulo, Páginas → a escolhida
func current_showcase() -> Array:
	match current_tab:
		&"capa":
			return ["titulo", null]
		&"paginas":
			return ["pagina", selected_page] if selected_page >= 0 else []
		&"marcos", &"mostras", &"totem":
			return []
		_:
			return ["capitulo", String(current_tab)]

func _refresh_targets() -> void:
	_target_pick.clear()
	var near: Array[Node] = _diary.nearby_players() if _diary else []
	for n in near:
		_target_pick.add_item(_DiaryComponent.describe(n)["name"])
		_target_pick.set_item_metadata(_target_pick.item_count - 1, n)
	if near.is_empty():
		_target_pick.add_item("ninguém perto (%d m)" % int(_DiaryComponent.SHOW_RANGE))
	var what := current_showcase()
	_show_btn.disabled = near.is_empty() or what.is_empty()
	_show_btn.tooltip_text = "Escolha uma Página primeiro" if current_tab == &"paginas" and what.is_empty() else ""

func _on_show_pressed() -> void:
	var target = _target_pick.get_item_metadata(_target_pick.selected) if _target_pick.selected >= 0 else null
	var what := current_showcase()
	if target == null or what.is_empty():
		return
	var ok := _diary.show_to(target, what[0], what[1])
	_status.text = ("Mostrado a %s" % _DiaryComponent.describe(target)["name"]) if ok else "Não deu para mostrar"

# ---------------------------------------------------------------- textos

static func page_text(p: Dictionary) -> String:
	var who: Dictionary = p.get("who", {})
	var with_: Dictionary = p.get("with", {})
	var head := "%s Dia %d, %02dh — " % [PAGE_ICONS.get(p.get("kind", ""), "•"), int(p.get("day", 0)), int(p.get("hour", 0.0))]
	var name_str := str(who.get("name", "?")) + ((" (" + str(who["guild"]) + ")") if str(who.get("guild", "")) != "" else "")
	var line := ""
	match p.get("kind", ""):
		"abate":
			line = "Abateu %s" % name_str
		"assistencia":
			line = "Ajudou a derrubar %s" % name_str
		"queda":
			line = "Caiu para %s" % name_str
		"marco":
			return head + "Marco de %s: %s" % [who.get("tier", ""), name_str]
		"perda":
			return head + "Perdeu %s (Elo %d)" % [name_str, int(p.get("elo", 0))]
	if str(with_.get("weapon", "")) != "":
		line += " com %s" % with_["weapon"]
	if not p.get("parts", []).is_empty():
		line += " · partes: %s" % ", ".join(p["parts"])
	if not p.get("helpers", []).is_empty():
		line += " · ajuda: %s" % ", ".join(p["helpers"])
	if p.has("digno") and not p["digno"]:
		line += " · não digno"
	if p.get("criado", false):
		line += " · de cercado"
	return head + line

static func showcase_text(s: Dictionary) -> String:
	var who := "%s%s" % [s.get("from", "?"), (" · " + str(s["title"])) if str(s.get("title", "")) != "" else ""]
	match s.get("kind", ""):
		"titulo":
			return "%s mostrou o título: %d Marcos%s" % [who, int(s.get("marcos", 0)), " (tem Lenda)" if s.get("lenda", false) else ""]
		"capitulo":
			var parts: Array[String] = []
			var counters: Dictionary = s.get("counters", {})
			for k in counters:
				if COUNTER_NAMES.has(String(k)):
					parts.append("%s %d" % [COUNTER_NAMES[String(k)], int(counters[k])])
			return "%s mostrou %s: %s" % [who, _tab_name(StringName(s.get("chapter", ""))), ", ".join(parts) if not parts.is_empty() else "vazio"]
		"pagina":
			return "%s mostrou uma Página: %s" % [who, page_text(s.get("page", {}))]
	return who

## Nome do Feito da Guilda para o aviso do HUD
static func guild_feat_name(id: String) -> String:
	for row in _GuildBook.FEATS:
		if row[0] == id:
			return "%s (%s)" % [row[1], row[4]]
	return id

static func _tab_name(id: StringName) -> String:
	for t in TABS:
		if t.id == id:
			return t.name
	return String(id)

static func _tab_icon(id: StringName) -> String:
	for t in TABS:
		if t.id == id:
			return t.icon
	return ""

static func _num(v: Variant) -> String:
	var f := float(v)
	return str(int(f)) if is_equal_approx(f, roundf(f)) else "%.1f" % f

func _heading(text: String) -> Label:
	var l := _label(text, 17, LEATHER)
	l.add_theme_constant_override("outline_size", 0)
	return l

func _stat(title: String, value: String) -> Control:
	var v := VBoxContainer.new()
	v.add_child(_label(value, 20, INK))
	v.add_child(_label(title, 12, INK_DIM))
	return v

## wrap só onde o pai dá largura (VBox do conteúdo); em grade ou linha a quebra espreme o texto
func _label(text: String, size: int, color: Color, wrap: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

func _box(bg: Color, border: Color, radius: int, border_w: int, pad: Vector2 = Vector2.ZERO) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(radius)
	s.content_margin_left = pad.x
	s.content_margin_right = pad.x
	s.content_margin_top = pad.y
	s.content_margin_bottom = pad.y
	return s
