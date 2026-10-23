class_name CardTableScreen
extends Control

## Tela da mesa do Duelo de Cepas (GDD-07 §7): escolhe a aposta, joga contra a Taverneira e
## mostra o resultado. Clique numa carta da mão e depois numa fileira sua vazia para baixar.

enum Phase { BET, PLAY, RESULT }

const PANEL_BG := Color(0.08, 0.075, 0.07, 0.97)
const TEXT := Color(0.92, 0.9, 0.86)
const TEXT_DIM := Color(0.6, 0.57, 0.52)
const GOLD := Color(0.95, 0.78, 0.35)
const RED := Color(0.9, 0.42, 0.38)
const GREEN := Color(0.55, 0.88, 0.55)
const AI_DELAY: float = 0.8

var table: TavernTable
var player: Player
var phase: Phase = Phase.BET

var _bet: int = 5
var _selected_hand: int = -1
var _last_result: Dictionary = {}
var _message: String = ""
var _money_label: Label
var _body: VBoxContainer
var _textures: Dictionary = {}

func _ready() -> void:
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_frame()

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

func open(p: Player) -> void:
	player = p
	phase = Phase.PLAY if table.duel != null else Phase.BET
	visible = true
	add_to_group("open_menus")
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	refresh()

func close() -> void:
	# Sair com a partida rolando é desistir (a aposta fica na mesa)
	if phase == Phase.PLAY and table.duel != null and not table.duel.is_over():
		table.forfeit()
		if player:
			player.posture_changed.emit("🃏 Você largou a partida; a aposta ficou com a Taverneira")
	phase = Phase.BET
	visible = false
	remove_from_group("open_menus")
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func refresh() -> void:
	if not visible:
		return
	_money_label.text = "💰 %s" % WalletComponent.format(player.wallet.money if player and player.wallet else 0)
	for c in _body.get_children():
		c.queue_free()
	match phase:
		Phase.BET:
			_show_bet()
		Phase.PLAY:
			_show_play()
		Phase.RESULT:
			_show_result()

# ---------------------------------------------------------------- fases

func _show_bet() -> void:
	_body.add_child(_label("A Taverneira embaralha o baralho dela e olha para você.", 16, TEXT))
	_body.add_child(_label("Seu baralho: 3 cópias de cada carta da sua coleção, completado com Recrutas de Taverna até 12. Vida 15; o Éter sobe 1 por turno até 5. No fim do seu turno cada carta bate na fileira da frente; fileira vazia acerta a Vida. Água > Fogo > Ar > Terra > Raio > Água (+2 de dano).", 13, TEXT_DIM, true))
	var owned: int = player.card_collection.get_unlocked_ids().size() if player.card_collection else 0
	_body.add_child(_label("Você tem %d cartas na coleção. Vencer a Taverneira dá uma carta nova (enquanto houver prêmio)." % owned, 13, GOLD, true))
	_body.add_child(_label("Aposta (vencer paga 2× menos 10% da casa; empate devolve):", 15, TEXT))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	for amount in TavernTable.BETS:
		var b := Button.new()
		b.text = "Sem aposta" if amount == 0 else WalletComponent.format(amount)
		_style_button(b, GOLD, amount == _bet)
		b.disabled = amount > 0 and player.wallet and player.wallet.money < amount
		b.pressed.connect(func(): _bet = amount; refresh())
		row.add_child(b)
	_body.add_child(row)
	var play := Button.new()
	play.text = "🃏  Sentar e jogar"
	_style_button(play, GOLD, true)
	play.pressed.connect(_start)
	_body.add_child(play)
	if _message != "":
		_body.add_child(_label(_message, 14, RED))

func _start() -> void:
	var err := table.start_match(player, _bet)
	if err != "":
		_message = err
		refresh()
		return
	_message = ""
	_selected_hand = -1
	phase = Phase.PLAY
	refresh()

func _show_play() -> void:
	var duel := table.duel
	if duel == null:
		phase = Phase.BET
		refresh()
		return
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 16)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_child(cols)

	var field := VBoxContainer.new()
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field.add_theme_constant_override("separation", 8)
	cols.add_child(field)
	field.add_child(_label("🍺 Taverneira — ❤️ %d   ⚡ %d/%d   🂠 %d na mão" % [duel.life[1], duel.ether[1], duel.ether_max[1], duel.hands[1].size()], 15, RED))
	field.add_child(_lanes(1))
	var mid := _label("Rodada %d de %d · %s" % [duel.round_num, CardDuel.MAX_ROUNDS, "sua vez" if duel.current == 0 else "vez da Taverneira…"], 13, GOLD)
	mid.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	field.add_child(mid)
	field.add_child(_lanes(0))
	field.add_child(_label("🧑 Você — ❤️ %d   ⚡ %d/%d   🂠 %d no baralho" % [duel.life[0], duel.ether[0], duel.ether_max[0], duel.decks[0].size()], 15, GREEN))
	var hand := HBoxContainer.new()
	hand.add_theme_constant_override("separation", 6)
	for i in duel.hands[0].size():
		var card: CardData = duel.hands[0][i]
		var playable := duel.current == 0 and card.ether_cost <= duel.ether[0]
		var w := _card_widget(card, card.poise, i == _selected_hand, playable)
		var index: int = i
		w.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT and playable:
				_selected_hand = -1 if _selected_hand == index else index
				refresh())
		hand.add_child(w)
	field.add_child(hand)

	var side := VBoxContainer.new()
	side.custom_minimum_size = Vector2(270, 0)
	side.add_theme_constant_override("separation", 8)
	cols.add_child(side)
	side.add_child(_label("Aposta: %s" % (WalletComponent.format(table.bet) if table.bet > 0 else "nenhuma"), 13, GOLD))
	var hint := "Escolha uma carta da mão e clique numa fileira sua vazia." if _selected_hand < 0 else "Agora clique numa fileira sua vazia (embaixo)."
	side.add_child(_label(hint, 12, TEXT_DIM, true))
	var end_btn := Button.new()
	end_btn.text = "⚔  Encerrar turno"
	end_btn.disabled = duel.current != 0
	_style_button(end_btn, GOLD, true)
	end_btn.pressed.connect(_end_turn)
	side.add_child(end_btn)
	if _message != "":
		side.add_child(_label(_message, 13, RED, true))
	var log_box := VBoxContainer.new()
	log_box.add_theme_constant_override("separation", 2)
	var lines := duel.log_lines.slice(maxi(0, duel.log_lines.size() - 12))
	for line in lines:
		log_box.add_child(_label("• " + line, 12, TEXT_DIM, true))
	side.add_child(log_box)

func _lanes(p: int) -> HBoxContainer:
	var duel := table.duel
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for lane in CardDuel.LANES:
		var slot: Dictionary = duel.board[p][lane]
		var w: Control
		if slot.is_empty():
			w = _empty_slot(p == 0 and _selected_hand >= 0)
		else:
			w = _card_widget(slot.card, slot.poise, false, true, slot.burn > 0)
		if p == 0:
			var l: int = lane
			w.gui_input.connect(func(ev: InputEvent):
				if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
					_play_on(l))
		row.add_child(w)
	return row

func _play_on(lane: int) -> void:
	if _selected_hand < 0 or table.duel == null:
		return
	var err := table.duel.play(0, _selected_hand, lane)
	_message = err
	_selected_hand = -1
	refresh()

func _end_turn() -> void:
	var duel := table.duel
	if duel == null or duel.current != 0:
		return
	_message = ""
	_selected_hand = -1
	duel.end_turn(0)
	refresh()
	if not duel.is_over():
		await get_tree().create_timer(AI_DELAY).timeout
		if table.duel == duel and visible:
			duel.ai_turn(1)
	if table.duel == duel and duel.is_over():
		_finish(duel)
	refresh()

func _finish(duel: CardDuel) -> void:
	var outcome := duel.winner
	_last_result = table.settle()
	_last_result["winner"] = outcome
	_last_result["life"] = duel.life.duplicate()
	phase = Phase.RESULT
	if player:
		var msg := "🃏 Venceu a Taverneira!" if outcome == 0 else ("🃏 Empate na mesa" if outcome == 2 else "🃏 A Taverneira levou essa")
		player.posture_changed.emit(msg)

func _show_result() -> void:
	var w: int = _last_result.get("winner", 1)
	var title := "🏆 Você venceu!" if w == 0 else ("🤝 Empate" if w == 2 else "💀 A Taverneira venceu")
	_body.add_child(_label(title, 26, GREEN if w == 0 else (GOLD if w == 2 else RED)))
	var life: Array = _last_result.get("life", [0, 0])
	_body.add_child(_label("Vida final: você %d × %d Taverneira" % [life[0], life[1]], 15, TEXT))
	var money: int = _last_result.get("money", 0)
	if money > 0:
		_body.add_child(_label("💰 Recebeu %s" % WalletComponent.format(money), 16, GREEN))
	var card: CardData = _last_result.get("card")
	if card:
		_body.add_child(_label("✨ Carta nova na coleção: %s" % card.title, 16, GOLD))
		_body.add_child(_card_widget(card, card.poise, false, true))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var again := Button.new()
	again.text = "Jogar de novo"
	_style_button(again, GOLD, true)
	again.pressed.connect(func(): phase = Phase.BET; refresh())
	row.add_child(again)
	var leave := Button.new()
	leave.text = "Levantar da mesa"
	_style_button(leave, GOLD, false)
	leave.pressed.connect(close)
	row.add_child(leave)
	_body.add_child(row)

# ---------------------------------------------------------------- peças da tela

func _card_widget(card: CardData, poise: int, selected: bool, active: bool, burning: bool = false) -> PanelContainer:
	var accent := card.get_element_color()
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(132, 178)
	frame.mouse_filter = Control.MOUSE_FILTER_STOP
	frame.add_theme_stylebox_override("panel", _box(Color(accent.r, accent.g, accent.b, 0.16 if active else 0.05), Color(GOLD if selected else accent, 1.0 if selected else (0.75 if active else 0.3)), 8, 3 if selected else 1, Vector2(6, 6)))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(box)
	var tex := _texture(card.render_path)
	if tex:
		var img := TextureRect.new()
		img.texture = tex
		img.custom_minimum_size = Vector2(120, 74)
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		img.modulate = Color.WHITE if active else Color(1, 1, 1, 0.45)
		box.add_child(img)
	else:
		var art := _label("🍺", 34, TEXT)
		art.custom_minimum_size = Vector2(120, 74)
		art.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		art.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		box.add_child(art)
	var name_l := _label(card.title, 12, TEXT if active else TEXT_DIM, true)
	name_l.custom_minimum_size = Vector2(120, 0)
	box.add_child(name_l)
	box.add_child(_label("⚡%d  ⚔%d  🛡%d%s" % [card.ether_cost, card.power, poise, " 🔥" if burning else ""], 13, GOLD if active else TEXT_DIM))
	box.add_child(_label(card.get_element_name() + ("" if card.trait_name == "" else " · " + card.trait_name), 10, accent, true))
	return frame

func _empty_slot(highlight: bool) -> PanelContainer:
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(132, 178)
	frame.mouse_filter = Control.MOUSE_FILTER_STOP
	frame.add_theme_stylebox_override("panel", _box(Color(1, 1, 1, 0.05 if highlight else 0.02), Color(GOLD.r, GOLD.g, GOLD.b, 0.8 if highlight else 0.15), 8, 2 if highlight else 1))
	var l := _label("＋" if highlight else "", 30, GOLD)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	frame.add_child(l)
	return frame

func _texture(path: String) -> Texture2D:
	if path == "":
		return null
	if not _textures.has(path):
		_textures[path] = load(path) if ResourceLoader.exists(path) else null
	return _textures[path]

func _build_frame() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(1060, 640)
	panel.add_theme_stylebox_override("panel", _box(PANEL_BG, Color(GOLD.r, GOLD.g, GOLD.b, 0.25), 14, 1))
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	panel.add_child(margin)
	var root_box := VBoxContainer.new()
	root_box.add_theme_constant_override("separation", 10)
	margin.add_child(root_box)
	var header := HBoxContainer.new()
	var title := _label("🃏  Duelo de Cepas — mesa da Taverna", 22, TEXT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_money_label = _label("", 15, Color(0.75, 0.95, 0.6))
	header.add_child(_money_label)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(14, 0)
	header.add_child(gap)
	var close_btn := Button.new()
	close_btn.text = "  ✕  "
	_style_button(close_btn, RED, false)
	close_btn.pressed.connect(close)
	header.add_child(close_btn)
	root_box.add_child(header)
	_body = VBoxContainer.new()
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 10)
	root_box.add_child(_body)

func _label(text: String, size: int, color: Color, wrap: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = maxf(l.custom_minimum_size.x, 120.0)
	return l

func _style_button(btn: Button, accent: Color, filled: bool) -> void:
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 14)
	var fg := Color(0.12, 0.09, 0.05) if filled else TEXT
	for c in ["font_color", "font_hover_color", "font_pressed_color"]:
		btn.add_theme_color_override(c, fg)
	btn.add_theme_color_override("font_disabled_color", Color(0.45, 0.43, 0.4))
	var bg := accent if filled else Color(accent.r, accent.g, accent.b, 0.12)
	btn.add_theme_stylebox_override("normal", _box(bg, accent, 10, 1, Vector2(14, 6)))
	btn.add_theme_stylebox_override("hover", _box(bg.lightened(0.12), accent, 10, 1, Vector2(14, 6)))
	btn.add_theme_stylebox_override("pressed", _box(bg.darkened(0.1), accent, 10, 1, Vector2(14, 6)))
	btn.add_theme_stylebox_override("disabled", _box(Color(1, 1, 1, 0.03), Color(1, 1, 1, 0.08), 10, 1, Vector2(14, 6)))

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
