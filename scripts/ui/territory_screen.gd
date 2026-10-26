class_name TerritoryScreen
extends Control

## Tela de Gerenciamento do Território / Rancho (GDD-08 §4, §8, GDD-05 §5)
## Permite ao jogador controlar o Cofre de Manutenção ($S), verificar o status
## de proteção/vulnerabilidade/ruína, gerenciar a lista de construtores autorizados
## e realizar desmanche ou saque público de ruínas.

const _ClaimTotem = preload("res://scripts/claim_totem.gd")
const _BuildingSystem = preload("res://scripts/building_system.gd")
const _WalletComponent = preload("res://scripts/components/wallet_component.gd")

var totem: _ClaimTotem
var player: Node

const TEXT := Color(0.92, 0.92, 0.95)
const TEXT_DIM := Color(0.62, 0.64, 0.70)
const GOLD := Color(0.95, 0.78, 0.35)
const GREEN := Color(0.35, 0.85, 0.45)
const ORANGE := Color(0.95, 0.65, 0.20)
const RED := Color(0.92, 0.30, 0.30)
const PANEL_BG := Color(0.08, 0.08, 0.10, 0.95)

var _status_lbl: Label
var _funds_lbl: Label
var _funds_bar: ProgressBar
var _days_lbl: Label
var _player_balance_lbl: Label
var _whitelist_container: VBoxContainer
var _add_friend_edit: LineEdit
var _btn_deposit_10: Button
var _btn_deposit_25: Button
var _btn_deposit_50: Button
var _btn_deposit_max: Button
var _btn_withdraw: Button
var _btn_dismantle: Button

func _ready() -> void:
	visible = false
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	_build_ui()

func open(p_totem: _ClaimTotem, p_player: Node) -> void:
	totem = p_totem
	player = p_player
	visible = true
	add_to_group("open_menus")
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_refresh()

func close() -> void:
	remove_from_group("open_menus")
	visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and (event.keycode == KEY_ESCAPE or event.keycode == KEY_E)):
		close()
		get_viewport().set_input_as_handled()

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.65)
	bg.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg)
	
	var center := CenterContainer.new()
	center.set_anchors_preset(PRESET_FULL_RECT)
	add_child(center)
	
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(580, 500)
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL_BG
	sb.border_color = Color(0.28, 0.32, 0.40)
	sb.border_width_bottom = 2
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_width_top = 2
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.content_margin_left = 24
	sb.content_margin_right = 24
	sb.content_margin_top = 20
	sb.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)
	
	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 14)
	panel.add_child(main_vbox)
	
	# Cabeçalho
	var header := HBoxContainer.new()
	var title_vbox := VBoxContainer.new()
	var title := Label.new()
	title.text = "🏕️ Totem de Território do Rancho"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", GOLD)
	title_vbox.add_child(title)
	
	_status_lbl = Label.new()
	_status_lbl.text = "🟢 Protegido • Rancho Ativo"
	_status_lbl.add_theme_font_size_override("font_size", 13)
	title_vbox.add_child(_status_lbl)
	header.add_child(title_vbox)
	
	header.add_spacer(false)
	var btn_close := Button.new()
	btn_close.text = "✕ Fechar [ESC]"
	btn_close.focus_mode = FOCUS_NONE
	btn_close.pressed.connect(close)
	header.add_child(btn_close)
	main_vbox.add_child(header)
	
	main_vbox.add_child(HSeparator.new())
	
	# Painel do Cofre de Manutenção
	var vault_panel := VBoxContainer.new()
	vault_panel.add_theme_constant_override("separation", 6)
	
	var v_title := Label.new()
	v_title.text = "💰 Cofre de Manutenção Territorial (GDD-08 §8 Decisão 7)"
	v_title.add_theme_font_size_override("font_size", 14)
	v_title.add_theme_color_override("font_color", TEXT)
	vault_panel.add_child(v_title)
	
	var funds_row := HBoxContainer.new()
	_funds_lbl = Label.new()
	_funds_lbl.text = "Fundos: 25 $S / 250 $S"
	_funds_lbl.add_theme_color_override("font_color", GOLD)
	funds_row.add_child(_funds_lbl)
	
	funds_row.add_spacer(false)
	_days_lbl = Label.new()
	_days_lbl.text = "Tempo Restante: ~5.0 dias"
	_days_lbl.add_theme_color_override("font_color", TEXT_DIM)
	funds_row.add_child(_days_lbl)
	vault_panel.add_child(funds_row)
	
	_funds_bar = ProgressBar.new()
	_funds_bar.min_value = 0
	_funds_bar.max_value = 250
	_funds_bar.value = 25
	_funds_bar.show_percentage = false
	_funds_bar.custom_minimum_size.y = 12
	vault_panel.add_child(_funds_bar)
	
	_player_balance_lbl = Label.new()
	_player_balance_lbl.text = "Seu Saldo: 50 $S • Consumo diário: 5 $S / dia"
	_player_balance_lbl.add_theme_font_size_override("font_size", 12)
	_player_balance_lbl.add_theme_color_override("font_color", TEXT_DIM)
	vault_panel.add_child(_player_balance_lbl)
	
	# Botões de depósito rápido
	var dep_row := HBoxContainer.new()
	dep_row.add_theme_constant_override("separation", 8)
	
	_btn_deposit_10 = Button.new()
	_btn_deposit_10.text = "+10 $S (2d)"
	_btn_deposit_10.pressed.connect(func(): _deposit(10))
	dep_row.add_child(_btn_deposit_10)
	
	_btn_deposit_25 = Button.new()
	_btn_deposit_25.text = "+25 $S (5d)"
	_btn_deposit_25.pressed.connect(func(): _deposit(25))
	dep_row.add_child(_btn_deposit_25)
	
	_btn_deposit_50 = Button.new()
	_btn_deposit_50.text = "+50 $S (10d)"
	_btn_deposit_50.pressed.connect(func(): _deposit(50))
	dep_row.add_child(_btn_deposit_50)
	
	_btn_deposit_max = Button.new()
	_btn_deposit_max.text = "Completar Cofre"
	_btn_deposit_max.pressed.connect(_deposit_max)
	dep_row.add_child(_btn_deposit_max)
	
	dep_row.add_spacer(false)
	_btn_withdraw = Button.new()
	_btn_withdraw.text = "Sacar Cofre"
	_btn_withdraw.pressed.connect(_withdraw)
	dep_row.add_child(_btn_withdraw)
	
	vault_panel.add_child(dep_row)
	main_vbox.add_child(vault_panel)
	
	main_vbox.add_child(HSeparator.new())
	
	# Permissões e Whitelist
	var perm_panel := VBoxContainer.new()
	perm_panel.add_theme_constant_override("separation", 6)
	
	var p_title := Label.new()
	p_title.text = "👥 Construtores Autorizados (Amigos & Guilda)"
	p_title.add_theme_font_size_override("font_size", 14)
	p_title.add_theme_color_override("font_color", TEXT)
	perm_panel.add_child(p_title)
	
	var add_row := HBoxContainer.new()
	add_row.add_theme_constant_override("separation", 8)
	_add_friend_edit = LineEdit.new()
	_add_friend_edit.placeholder_text = "Nome do jogador parceiro..."
	_add_friend_edit.size_flags_horizontal = SIZE_EXPAND_FILL
	add_row.add_child(_add_friend_edit)
	
	var btn_add := Button.new()
	btn_add.text = "Autorizar"
	btn_add.pressed.connect(_on_add_builder)
	add_row.add_child(btn_add)
	perm_panel.add_child(add_row)
	
	_whitelist_container = VBoxContainer.new()
	perm_panel.add_child(_whitelist_container)
	main_vbox.add_child(perm_panel)
	
	main_vbox.add_spacer(false)
	
	# Rodapé: Desmanche / Saque
	var footer := HBoxContainer.new()
	_btn_dismantle = Button.new()
	_btn_dismantle.text = "🔨 Desmontar Território (50% Reembolso)"
	_btn_dismantle.pressed.connect(_on_dismantle_pressed)
	footer.add_child(_btn_dismantle)
	
	footer.add_spacer(false)
	var hint_lbl := Label.new()
	hint_lbl.text = "Ruínas sem manutenção podem ser desmontadas por qualquer um."
	hint_lbl.add_theme_font_size_override("font_size", 11)
	hint_lbl.add_theme_color_override("font_color", TEXT_DIM)
	footer.add_child(hint_lbl)
	main_vbox.add_child(footer)

func _refresh() -> void:
	if totem == null:
		return
	
	var is_owner := false
	if player:
		is_owner = (_BuildingSystem.owner_name_of(player) == totem.owner_name)
	
	# Status
	match totem.status:
		_ClaimTotem.Status.ACTIVE:
			_status_lbl.text = "🟢 Protegido • Rancho Ativo (%s)" % totem.owner_name
			_status_lbl.add_theme_color_override("font_color", GREEN)
			var days_left: float = float(totem.maintenance_funds) / float(_ClaimTotem.DAILY_UPKEEP)
			_days_lbl.text = "Tempo Restante: ~%.1f dias" % days_left
			_days_lbl.add_theme_color_override("font_color", GREEN)
			_btn_dismantle.text = "🔨 Desmontar Território (50% Reembolso)"
			_btn_dismantle.visible = is_owner
		_ClaimTotem.Status.VULNERABLE:
			var car_left: float = maxf(0.0, _ClaimTotem.GRACE_PERIOD_DAYS - totem.grace_days_elapsed)
			_status_lbl.text = "🟡 VULNERÁVEL • Cofre Zerado (Carência: %.1fd)" % car_left
			_status_lbl.add_theme_color_override("font_color", ORANGE)
			_days_lbl.text = "CARÊNCIA: %.1f dias restantes!" % car_left
			_days_lbl.add_theme_color_override("font_color", ORANGE)
			_btn_dismantle.text = "🔨 Desmontar Território (50% Reembolso)"
			_btn_dismantle.visible = is_owner
		_ClaimTotem.Status.ABANDONED:
			_status_lbl.text = "🔴 RUÍNA ABANDONADA • Desmanche Público Liberado"
			_status_lbl.add_theme_color_override("font_color", RED)
			_days_lbl.text = "ABANDONADO (Manutenção Vencida)"
			_days_lbl.add_theme_color_override("font_color", RED)
			_btn_dismantle.text = "⛏️ Saquear e Desmanchar Ruína (25% Sucata)"
			_btn_dismantle.visible = true
	
	_funds_lbl.text = "Fundos no Cofre: %d $S / %d $S" % [totem.maintenance_funds, _ClaimTotem.MAX_FUNDS]
	_funds_bar.value = totem.maintenance_funds
	
	var p_balance := 0
	var wallet := _get_player_wallet()
	if wallet:
		p_balance = wallet.money
	_player_balance_lbl.text = "Seu Saldo: %d $S • Consumo diário: %d $S / dia" % [p_balance, _ClaimTotem.DAILY_UPKEEP]
	
	_btn_withdraw.visible = is_owner and totem.maintenance_funds > 0
	_btn_deposit_10.disabled = (p_balance < 10)
	_btn_deposit_25.disabled = (p_balance < 25)
	_btn_deposit_50.disabled = (p_balance < 50)
	_btn_deposit_max.disabled = (p_balance <= 0 or totem.maintenance_funds >= _ClaimTotem.MAX_FUNDS)
	
	# Whitelist
	for child in _whitelist_container.get_children():
		child.queue_free()
	
	if totem.allowed_builders.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "Nenhum amigo adicionado (Apenas %s constrói)" % totem.owner_name
		empty_lbl.add_theme_font_size_override("font_size", 12)
		empty_lbl.add_theme_color_override("font_color", TEXT_DIM)
		_whitelist_container.add_child(empty_lbl)
	else:
		for b_name in totem.allowed_builders:
			var row := HBoxContainer.new()
			var name_lbl := Label.new()
			name_lbl.text = "• %s" % b_name
			name_lbl.add_theme_font_size_override("font_size", 13)
			row.add_child(name_lbl)
			row.add_spacer(false)
			if is_owner:
				var btn_del := Button.new()
				btn_del.text = "Remover"
				btn_del.pressed.connect(func(): _remove_builder(b_name))
				row.add_child(btn_del)
			_whitelist_container.add_child(row)

func _deposit(amount: int) -> void:
	if totem and player:
		if totem.deposit_maintenance(amount, player):
			_notify("Depósito de %d $S efetuado no cofre do rancho!" % amount)
			_refresh()
		else:
			_notify("Saldo insuficiente em Dólares de Sucata.")

func _deposit_max() -> void:
	if totem and player:
		var wallet := _get_player_wallet()
		if wallet:
			var needed: int = _ClaimTotem.MAX_FUNDS - totem.maintenance_funds
			var to_add: int = mini(wallet.money, needed)
			if to_add > 0:
				_deposit(to_add)

func _withdraw() -> void:
	if totem and player:
		var amt: int = totem.maintenance_funds
		if totem.withdraw_maintenance(amt, player):
			_notify("Retirados %d $S do cofre territorial." % amt)
			_refresh()

func _on_add_builder() -> void:
	var name_to_add := _add_friend_edit.text.strip_edges()
	if name_to_add.is_empty():
		return
	if totem:
		if totem.add_allowed_builder(name_to_add):
			_notify("%s agora tem permissão para construir no rancho." % name_to_add)
			_add_friend_edit.text = ""
			_refresh()

func _remove_builder(b_name: String) -> void:
	if totem:
		if totem.remove_allowed_builder(b_name):
			_notify("Permissão de %s revogada." % b_name)
			_refresh()

func _on_dismantle_pressed() -> void:
	if totem and player:
		var is_ruin := (totem.status == _ClaimTotem.Status.ABANDONED)
		totem.dismantle(player, is_ruin)
		if is_ruin:
			_notify("Ruína desmanchada e sucateada! (+25% materiais)")
		else:
			_notify("Totem desmontado com sucesso.")
		close()

func _get_player_wallet() -> _WalletComponent:
	if player == null:
		return null
	if player.has_meta("wallet") and player.get_meta("wallet") is _WalletComponent:
		return player.get_meta("wallet") as _WalletComponent
	if player.get("wallet") is _WalletComponent:
		return player.get("wallet") as _WalletComponent
	var comp = player.get_node_or_null("WalletComponent") as _WalletComponent
	if comp:
		return comp
	for c in player.get_children():
		if c is _WalletComponent:
			return c as _WalletComponent
	return null

func _notify(msg: String) -> void:
	if player and player.has_signal("posture_changed"):
		player.posture_changed.emit(msg)
