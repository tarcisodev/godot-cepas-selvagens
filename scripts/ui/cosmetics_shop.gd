class_name CosmeticsShop
extends Control

## Loja de Cosméticos ("Ateliê Estelar & Boutique da Vila").
## Permite provar em 3D, comprar com moedas do jogo ($S), equipar/desequipar
## chapéus, capas, auras e trajes, além de demonstrar a futura aba de apoio via PIX.

@export var player: Player

var is_open: bool = false
var _wallet_label: Label
var _status_label: Label
var _tabs: TabContainer
var _preview_visual: CharacterVisual
var _preview_camera: Camera3D
var _preview_dna: CharacterDNA
var _item_buttons: Array[Callable] = []

func _ready() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F9:
			if is_open:
				close_shop()
			else:
				open_shop(player)
			get_viewport().set_input_as_handled()
		elif is_open and event.keycode == KEY_ESCAPE:
			close_shop()
			get_viewport().set_input_as_handled()

func open_shop(p: Player = null) -> void:
	if p != null:
		player = p
	if player == null and is_inside_tree():
		player = get_tree().get_first_node_in_group("player") as Player
	if player == null or player.character_visual == null or player.character_visual.dna == null:
		return

	_preview_dna = player.character_visual.dna.duplicate()
	if _preview_visual:
		_preview_visual.rebuild(_preview_dna)

	is_open = true
	visible = true
	add_to_group("open_menus")
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_refresh_ui()

func close_shop() -> void:
	if not is_open:
		return
	is_open = false
	visible = false
	remove_from_group("open_menus")
	if get_tree().get_nodes_in_group("open_menus").is_empty():
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.05, 0.78)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := MarginContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.add_theme_constant_override("margin_left", 48)
	center.add_theme_constant_override("margin_right", 48)
	center.add_theme_constant_override("margin_top", 34)
	center.add_theme_constant_override("margin_bottom", 34)
	add_child(center)

	var main_panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.10, 0.09, 0.96)
	sb.border_color = Color(0.78, 0.64, 0.34, 0.85)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 18
	sb.content_margin_bottom = 18
	main_panel.add_theme_stylebox_override("panel", sb)
	center.add_child(main_panel)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 12)
	main_panel.add_child(root_vbox)

	# Cabeçalho
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	root_vbox.add_child(header)

	var title := Label.new()
	title.text = "✨ ATELIÊ ESTELAR — LOJA DE COSMÉTICOS"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.98, 0.86, 0.52))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	_wallet_label = Label.new()
	_wallet_label.add_theme_font_size_override("font_size", 18)
	_wallet_label.add_theme_color_override("font_color", Color(0.95, 0.88, 0.42))
	header.add_child(_wallet_label)

	var close_btn := Button.new()
	close_btn.text = "✕ Fechar [Esc]"
	close_btn.pressed.connect(close_shop)
	header.add_child(close_btn)

	# Corpo dividido: Catálogo à esquerda + Provador 3D à direita
	var split := HBoxContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_theme_constant_override("separation", 18)
	root_vbox.add_child(split)

	var left_col := VBoxContainer.new()
	left_col.custom_minimum_size = Vector2(560, 0)
	left_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_col.add_theme_constant_override("separation", 8)
	split.add_child(left_col)

	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_col.add_child(_tabs)

	_build_slot_tab("🌸 Chapéus & Coroas", "hat")
	_build_slot_tab("🌿 Capas & Mantos", "cape")
	_build_slot_tab("✨ Auras & Luz", "aura")
	_build_slot_tab("👗 Trajes", "outfit")
	_build_pix_tab()

	_status_label = Label.new()
	_status_label.text = "Dica: Clique em 'Provar' para ver no personagem em 3D antes de comprar!"
	_status_label.add_theme_font_size_override("font_size", 14)
	_status_label.add_theme_color_override("font_color", Color(0.75, 0.88, 0.78))
	left_col.add_child(_status_label)

	split.add_child(_build_3d_preview())

func _build_slot_tab(tab_title: String, slot: String) -> void:
	var scroll := ScrollContainer.new()
	scroll.name = tab_title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_tabs.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)

	for item in CosmeticsCatalog.items_by_slot(slot):
		var card := PanelContainer.new()
		var csb := StyleBoxFlat.new()
		csb.bg_color = Color(0.12, 0.15, 0.14, 0.92)
		csb.border_color = Color(0.32, 0.42, 0.36, 0.7)
		csb.set_border_width_all(1)
		csb.set_corner_radius_all(8)
		csb.content_margin_left = 12
		csb.content_margin_right = 12
		csb.content_margin_top = 8
		csb.content_margin_bottom = 8
		card.add_theme_stylebox_override("panel", csb)
		list.add_child(card)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		card.add_child(row)

		var info_box := VBoxContainer.new()
		info_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info_box)

		var name_lbl := Label.new()
		name_lbl.text = "%s  %s" % [item.icon, item.name]
		name_lbl.add_theme_font_size_override("font_size", 16)
		name_lbl.add_theme_color_override("font_color", Color(0.96, 0.92, 0.80))
		info_box.add_child(name_lbl)

		var desc_lbl := Label.new()
		desc_lbl.text = item.desc
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.add_theme_font_size_override("font_size", 13)
		desc_lbl.add_theme_color_override("font_color", Color(0.75, 0.78, 0.75))
		info_box.add_child(desc_lbl)

		var try_btn := Button.new()
		try_btn.text = "👁 Provar"
		try_btn.custom_minimum_size = Vector2(85, 36)
		try_btn.pressed.connect(_on_try_item.bind(item))
		row.add_child(try_btn)

		var act_btn := Button.new()
		act_btn.custom_minimum_size = Vector2(145, 36)
		act_btn.pressed.connect(_on_action_item.bind(item))
		row.add_child(act_btn)

		var item_ref := item
		_item_buttons.append(func() -> void:
			if player == null or player.character_visual == null or player.character_visual.dna == null:
				return
			var dna := player.character_visual.dna
			var owned := dna.has_cosmetic(item_ref.id)
			var equipped := _is_equipped(dna, item_ref)
			if not owned:
				act_btn.text = "💰 %d $S · Comprar" % item_ref.price
				act_btn.modulate = Color(1.0, 0.95, 0.75)
			elif equipped:
				act_btn.text = "✓ Equipado (Tirar)"
				act_btn.modulate = Color(0.55, 1.0, 0.65)
			else:
				act_btn.text = "Vestir"
				act_btn.modulate = Color(0.85, 0.95, 1.0)
		)

func _build_pix_tab() -> void:
	var scroll := ScrollContainer.new()
	scroll.name = "💎 Apoiar via PIX"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_tabs.add_child(scroll)

	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 12)
	scroll.add_child(box)

	var banner := Label.new()
	banner.text = "💎 APOIO DIRETO AO PROJETO (PRÉVIA PIX)\nDurante a fase de testes, todos os itens podem ser comprados com moedas do jogo ($S).\nNo futuro, pacotes de apoiador via PIX desbloquearão cosméticos exclusivos instantaneamente!"
	banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	banner.add_theme_font_size_override("font_size", 14)
	banner.add_theme_color_override("font_color", Color(0.92, 0.86, 0.65))
	box.add_child(banner)

	var test_stipend_btn := Button.new()
	test_stipend_btn.text = "🎁 Resgatar Bolsa de Testes (+200 $S grátis para testar a loja!)"
	test_stipend_btn.custom_minimum_size = Vector2(0, 42)
	test_stipend_btn.pressed.connect(func() -> void:
		if player and player.wallet:
			player.wallet.add(200)
			_status_label.text = "🎉 +200 $S adicionados à sua bolsa para testar os cosméticos!"
			_refresh_ui()
	)
	# Dinheiro de teste não existe no online: o servidor não entrega $S sem fonte (B41)
	test_stipend_btn.visible = not _online()
	box.add_child(test_stipend_btn)

	for pack in CosmeticsCatalog.PIX_PACKS:
		var card := PanelContainer.new()
		var csb := StyleBoxFlat.new()
		csb.bg_color = Color(0.14, 0.12, 0.20, 0.92)
		csb.border_color = Color(0.68, 0.48, 0.88, 0.8)
		csb.set_border_width_all(1)
		csb.set_corner_radius_all(8)
		csb.content_margin_left = 14
		csb.content_margin_right = 14
		csb.content_margin_top = 10
		csb.content_margin_bottom = 10
		card.add_theme_stylebox_override("panel", csb)
		box.add_child(card)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		card.add_child(row)

		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)

		var t := Label.new()
		t.text = "%s  —  %s" % [pack.name, pack.price_brl]
		t.add_theme_font_size_override("font_size", 16)
		t.add_theme_color_override("font_color", Color(0.95, 0.82, 1.0))
		info.add_child(t)

		var d := Label.new()
		d.text = pack.desc
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.add_theme_font_size_override("font_size", 13)
		info.add_child(d)

		var sim_btn := Button.new()
		sim_btn.text = "⚡ Simular PIX (Teste)"
		sim_btn.pressed.connect(func() -> void:
			if player == null or player.character_visual == null:
				return
			var dna := player.character_visual.dna
			for id in ["coroa_flores", "halo_anelado", "manto_estrelado", "aura_cosmica"]:
				dna.unlock_cosmetic(id)
			if player.wallet:
				player.wallet.add(int(pack.bonus_gold))
			_status_label.text = "💎 Pacote Apoiador simulado! Cosméticos estelares liberados + %d $S!" % int(pack.bonus_gold)
			_refresh_ui()
		)
		sim_btn.visible = not _online()
		row.add_child(sim_btn)

func _build_3d_preview() -> Control:
	var container := SubViewportContainer.new()
	container.stretch = true
	container.custom_minimum_size = Vector2(360, 0)
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.gui_input.connect(func(event: InputEvent) -> void:
		var m := event as InputEventMouseMotion
		if m and (m.button_mask & MOUSE_BUTTON_MASK_LEFT):
			if _preview_visual:
				_preview_visual.rotation.y += m.relative.x * 0.012
	)

	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	container.add_child(vp)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.09, 0.11, 0.14)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.65, 0.72, 0.85)
	env.ambient_light_energy = 0.75
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-30.0, 28.0, 0.0)
	key.light_energy = 1.35
	vp.add_child(key)

	var pedestal := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.72
	cyl.bottom_radius = 0.78
	cyl.height = 0.06
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Color(0.24, 0.22, 0.18)
	cyl.material = pmat
	pedestal.mesh = cyl
	pedestal.position.y = -0.03
	vp.add_child(pedestal)

	_preview_visual = CharacterVisual.new()
	_preview_visual.weapon_scene = null
	_preview_visual.dna = CharacterDNA.new()
	_preview_visual.rotation.y = PI
	vp.add_child(_preview_visual)

	_preview_camera = Camera3D.new()
	_preview_camera.fov = 36.0
	_preview_camera.transform = Transform3D(Basis(), Vector3(0.0, 1.15, 3.8)).looking_at(Vector3(0.0, 1.0, 0.0))
	vp.add_child(_preview_camera)

	var hint := Label.new()
	hint.text = "🔄 Arraste para girar o personagem"
	hint.position = Vector2(14, 14)
	hint.add_theme_font_size_override("font_size", 13)
	hint.modulate = Color(1, 1, 1, 0.75)
	container.add_child(hint)
	return container

func _is_equipped(dna: CharacterDNA, item: Dictionary) -> bool:
	match item.slot:
		"hat": return dna.cosmetic_hat == item.id
		"cape": return dna.cosmetic_cape == item.id
		"aura": return dna.cosmetic_aura == item.id
		"outfit": return dna.shirt_color.is_equal_approx(item.shirt)
	return false

func _apply_item_to_dna(dna: CharacterDNA, item: Dictionary, toggle_off_if_same: bool = false) -> void:
	match item.slot:
		"hat":
			dna.cosmetic_hat = "" if (toggle_off_if_same and dna.cosmetic_hat == item.id) else item.id
		"cape":
			dna.cosmetic_cape = "" if (toggle_off_if_same and dna.cosmetic_cape == item.id) else item.id
		"aura":
			dna.cosmetic_aura = "" if (toggle_off_if_same and dna.cosmetic_aura == item.id) else item.id
		"outfit":
			dna.shirt_color = item.shirt
			dna.pants_color = item.pants
			dna.boots_color = item.boots

func _on_try_item(item: Dictionary) -> void:
	if _preview_dna == null:
		return
	_apply_item_to_dna(_preview_dna, item, true)
	if _preview_visual:
		_preview_visual.rebuild(_preview_dna)
	_status_label.text = "👁 Provando: %s %s" % [item.icon, item.name]

func _on_action_item(item: Dictionary) -> void:
	if player == null or player.character_visual == null or player.character_visual.dna == null:
		return
	var dna := player.character_visual.dna
	var wallet := player.wallet
	if not dna.has_cosmetic(item.id):
		if wallet == null or not wallet.spend(int(item.price)):
			_status_label.text = "❌ Moedas insuficientes! Você precisa de %d $S (dica: use a aba PIX para bolsa de teste)." % int(item.price)
			return
		dna.unlock_cosmetic(item.id)
		_apply_item_to_dna(dna, item, false)
		_status_label.text = "✨ Comprou e vestiu: %s %s!" % [item.icon, item.name]
	else:
		_apply_item_to_dna(dna, item, true)
		_status_label.text = "✓ Atualizado: %s %s" % [item.icon, item.name]

	player.character_visual.rebuild(dna)
	_preview_dna = dna.duplicate()
	if _preview_visual:
		_preview_visual.rebuild(_preview_dna)

	var sg := get_node_or_null("/root/SaveGame")
	if sg and sg.has_method("save_game"):
		sg.save_game()
	_refresh_ui()

func _refresh_ui() -> void:
	if _wallet_label and player and player.wallet:
		_wallet_label.text = "💰 Bolsa: %s" % WalletComponent.format(player.wallet.money)
	for fn in _item_buttons:
		fn.call()

## Cliente online: a carteira é do servidor (B41), então os atalhos de teste somem
func _online() -> bool:
	return player != null and player.wallet != null and player.wallet.ledger != null and player.wallet.ledger.should_route()
