class_name MissionBoardScreen
extends Control

## Interface Gráfica do Quadro de Missões e Contratos da Vila (GDD-05 §5, GDD-03, GDD-04, GDD-13).
## Exibe contratos dinâmicos divididos em 4 abas (Caça, Forja, Culinária, Reconhecimento),
## permitindo aos jogadores entregarem recursos ou fotos para receberem $S, Reputação e XP.

const _Player = preload("res://scripts/player.gd")
const _MissionBoardSystem = preload("res://scripts/systems/mission_board_system.gd")
const _MaterialData = preload("res://scripts/data/material_data.gd")
const _WalletComponent = preload("res://scripts/components/wallet_component.gd")
const _InventoryComponent = preload("res://scripts/components/inventory_component.gd")
const _GuildBook = preload("res://scripts/systems/guild_book.gd")
const _GuildLedger = preload("res://scripts/data/guild_ledger.gd")

## Filtro especial: em vez de contratos, o Placar das Guildas (GDD-19 §7)
const FILTER_GUILD_BOARD: int = -2

var player: _Player
var mission_system: _MissionBoardSystem
var city_node: Node

var _panel: PanelContainer
var _contracts_list: VBoxContainer
var _category_tabs: HBoxContainer
var _active_filter: int = -1 # -1 = Todos
var _status_toast: Label

func _ready() -> void:
	visible = false
	# "and_offsets": só as âncoras manteriam o tamanho 0×0 de recém-criado e o painel
	# centralizaria no canto (0,0) da tela, cortado
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	_build_ui()

func open(p_player: _Player, p_system: _MissionBoardSystem, p_city: Node = null) -> void:
	player = p_player
	mission_system = p_system
	city_node = p_city
	visible = true
	add_to_group("open_menus")
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	# Cliente online: o Placar chega do servidor depois de pedido
	var net := get_node_or_null("/root/NetworkManager")
	if net and net.has_signal("guild_board_received") and not net.guild_board_received.is_connected(_on_guild_board):
		net.guild_board_received.connect(_on_guild_board)
	_refresh()

func close() -> void:
	if not visible:
		return
	visible = false
	remove_from_group("open_menus")
	if is_inside_tree() and get_tree().get_nodes_in_group("open_menus").is_empty():
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

func _build_ui() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.55)
	backdrop.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	backdrop.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			close()
	)
	add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	center.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(center)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(680, 520)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.11, 0.10, 0.12, 0.97)
	style.border_color = Color(0.85, 0.72, 0.35)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 18
	style.content_margin_bottom = 18
	_panel.add_theme_stylebox_override("panel", style)
	center.add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	_panel.add_child(vbox)

	# Cabeçalho
	var header := HBoxContainer.new()
	var title := Label.new()
	title.text = "📋 Quadro de Missões & Contratos da Vila"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.95, 0.82, 0.4))
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	header.add_child(title)

	var close_btn := Button.new()
	close_btn.text = " ✕ "
	close_btn.pressed.connect(close)
	header.add_child(close_btn)
	vbox.add_child(header)

	var desc := Label.new()
	desc.text = "Entregue partes anatômicas de caça, peças de forja, refeições no ponto ou fotos de reconhecimento para receber $S, Reputação e XP de Maestria."
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 12)
	desc.add_theme_color_override("font_color", Color(0.78, 0.75, 0.7))
	vbox.add_child(desc)

	# Filtros de Categoria
	_category_tabs = HBoxContainer.new()
	_category_tabs.add_theme_constant_override("separation", 6)
	vbox.add_child(_category_tabs)

	var tab_all := Button.new()
	tab_all.text = "📋 Todos"
	tab_all.pressed.connect(func(): _set_filter(-1))
	_category_tabs.add_child(tab_all)

	for cat in _MissionBoardSystem.Category.values():
		var btn := Button.new()
		var cat_name: String = _MissionBoardSystem.CATEGORY_NAMES[cat]
		var cat_icon: String = _MissionBoardSystem.CATEGORY_ICONS[cat]
		btn.text = "%s %s" % [cat_icon, cat_name]
		var c_val: int = cat
		btn.pressed.connect(func(): _set_filter(c_val))
		_category_tabs.add_child(btn)

	var tab_board := Button.new()
	tab_board.name = "GuildBoardTab"
	tab_board.text = "🏆 Placar das Guildas"
	tab_board.pressed.connect(func(): _set_filter(FILTER_GUILD_BOARD))
	_category_tabs.add_child(tab_board)

	# Toast / Mensagem de status
	_status_toast = Label.new()
	_status_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_toast.add_theme_font_size_override("font_size", 12)
	_status_toast.text = ""
	vbox.add_child(_status_toast)

	# Lista de Contratos
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 330
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	_contracts_list = VBoxContainer.new()
	_contracts_list.size_flags_horizontal = SIZE_EXPAND_FILL
	_contracts_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_contracts_list)

func _set_filter(cat: int) -> void:
	_active_filter = cat
	_refresh()

func _refresh() -> void:
	if mission_system == null and _active_filter != FILTER_GUILD_BOARD:
		return

	# Limpa lista anterior
	for c in _contracts_list.get_children():
		_contracts_list.remove_child(c)
		c.queue_free()

	if _active_filter == FILTER_GUILD_BOARD:
		_build_guild_board()
		return

	if mission_system == null:
		return
	var contracts := mission_system.active_contracts
	var filtered: Array = []
	for contract in contracts:
		if _active_filter == -1 or int(contract.get("category", 0)) == _active_filter:
			filtered.append(contract)

	if filtered.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "Nenhum contrato disponível nesta categoria no momento."
		empty_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		_contracts_list.add_child(empty_lbl)
		return

	for contract in filtered:
		_build_contract_card(contract)

func _build_contract_card(contract: Dictionary) -> void:
	var card := PanelContainer.new()
	var c_style := StyleBoxFlat.new()
	c_style.bg_color = Color(0.16, 0.15, 0.18, 0.94)
	c_style.border_color = Color(0.4, 0.38, 0.35)
	c_style.set_border_width_all(1)
	c_style.set_corner_radius_all(8)
	c_style.content_margin_left = 14
	c_style.content_margin_right = 14
	c_style.content_margin_top = 10
	c_style.content_margin_bottom = 10
	card.add_theme_stylebox_override("panel", c_style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 14)
	card.add_child(hbox)

	# Ícone
	var icon_lbl := Label.new()
	icon_lbl.text = str(contract.get("category_icon", "📜"))
	icon_lbl.add_theme_font_size_override("font_size", 26)
	hbox.add_child(icon_lbl)

	# Informações do Contrato
	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = SIZE_EXPAND_FILL
	info_vbox.add_theme_constant_override("separation", 3)
	hbox.add_child(info_vbox)

	var title_lbl := Label.new()
	title_lbl.text = "%s — Contratante: %s" % [contract.title, contract.client]
	title_lbl.add_theme_font_size_override("font_size", 14)
	title_lbl.add_theme_color_override("font_color", Color(0.95, 0.9, 0.75))
	info_vbox.add_child(title_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = contract.desc
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_font_size_override("font_size", 11)
	desc_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	info_vbox.add_child(desc_lbl)

	# Progresso do Objetivo
	var is_photo: bool = bool(contract.get("is_photo", false))
	var needed: int = int(contract.get("amount_needed", 1))
	var current: int = 0
	var obj_text := ""

	if is_photo:
		current = int(contract.get("amount_current", 0))
		obj_text = "📷 Objetivo: %s (%d / %d fotos registradas)" % [contract.target_name, current, needed]
	else:
		var inv: _InventoryComponent = player.inventory if player else null
		var target_id: StringName = contract.get("target_id", &"")
		var have: int = inv.get_material_count(target_id) if inv else 0
		current = have
		obj_text = "📦 Entregar: %d × %s (Você tem %d na mochila)" % [needed, contract.target_name, have]

	var obj_lbl := Label.new()
	obj_lbl.text = obj_text
	obj_lbl.add_theme_font_size_override("font_size", 12)
	var can_deliver: bool = mission_system.can_deliver(contract, player)
	obj_lbl.add_theme_color_override("font_color", Color(0.4, 0.95, 0.5) if can_deliver else Color(0.9, 0.75, 0.4))
	info_vbox.add_child(obj_lbl)

	# Recompensas
	var rew_hbox := HBoxContainer.new()
	rew_hbox.add_theme_constant_override("separation", 12)
	info_vbox.add_child(rew_hbox)

	var money_lbl := Label.new()
	money_lbl.text = "💰 +%s" % _WalletComponent.format(contract.reward_money)
	money_lbl.add_theme_color_override("font_color", Color(0.5, 0.95, 0.5))
	money_lbl.add_theme_font_size_override("font_size", 11)
	rew_hbox.add_child(money_lbl)

	var rep_lbl := Label.new()
	rep_lbl.text = "⭐ +%d Reputação" % contract.reward_rep
	rep_lbl.add_theme_color_override("font_color", Color(0.95, 0.8, 0.35))
	rep_lbl.add_theme_font_size_override("font_size", 11)
	rew_hbox.add_child(rep_lbl)

	if not str(contract.get("reward_mastery", "")).is_empty():
		var xp_lbl := Label.new()
		xp_lbl.text = "⚡ +%.0f XP %s" % [contract.reward_xp, str(contract.reward_mastery).capitalize()]
		xp_lbl.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
		xp_lbl.add_theme_font_size_override("font_size", 11)
		rew_hbox.add_child(xp_lbl)

	# Botão de Entrega
	var action_btn := Button.new()
	action_btn.custom_minimum_size = Vector2(100, 36)
	if can_deliver:
		action_btn.text = "Concluir"
		action_btn.disabled = false
		action_btn.pressed.connect(func(): _on_deliver(contract))
	elif is_photo:
		action_btn.text = "Ver no [P]"
		action_btn.disabled = true
	else:
		action_btn.text = "Falta material"
		action_btn.disabled = true
	hbox.add_child(action_btn)

	_contracts_list.add_child(card)

func _on_deliver(contract: Dictionary) -> void:
	if mission_system == null or player == null:
		return
	if mission_system.deliver_contract(contract, player, city_node):
		_status_toast.text = "🎉 Contrato cumprido! Recompensa de %s entregue!" % _WalletComponent.format(contract.reward_money)
		_status_toast.add_theme_color_override("font_color", Color(0.4, 0.95, 0.5))
		_refresh()

## Placar das Guildas da semana (7 dias reais): só guildas, ninguém vê ranking de jogador
func _build_guild_board() -> void:
	var board: Dictionary = _GuildBook.view_for(player).get("board", {})
	var head := Label.new()
	head.text = "🏆 Placar das Guildas · semana de %s" % _GuildLedger.week_start_text(int(board.get("week", _GuildLedger.week_of(_GuildLedger.now()))))
	head.add_theme_font_size_override("font_size", 15)
	head.add_theme_color_override("font_color", Color(0.95, 0.82, 0.4))
	_contracts_list.add_child(head)
	for col in _GuildBook.board_lines(board):
		var title := Label.new()
		title.text = col[0]
		title.add_theme_color_override("font_color", Color(0.85, 0.72, 0.35))
		_contracts_list.add_child(title)
		if col[1].is_empty():
			var none := Label.new()
			none.text = "   Nenhuma guilda nesta semana ainda."
			none.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
			_contracts_list.add_child(none)
		for line in col[1]:
			var lbl := Label.new()
			lbl.text = "   " + line
			_contracts_list.add_child(lbl)

func _on_guild_board(_data: Dictionary) -> void:
	if visible and _active_filter == FILTER_GUILD_BOARD:
		_refresh()
