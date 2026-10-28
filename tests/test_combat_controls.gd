extends SceneTree

## Validação dos Controles de Combate (Mouse 1, Mouse 2 e Mouse 1+2 Especial) e HUD Minimalista:
## 1. Cajado Arcano: Mouse 1 (Golpe de cajado), Mouse 2 (Dardo arcano) e Mouse 1+2 (Explosão Astral).
## 2. Martelo Pesado: Mouse 1 (Balanço de martelo), Mouse 2 (Investida demolidora) e Mouse 1+2 (Abalo Sísmico).
## 3. Espada e Escudo: Mouse 1 (Golpe de espada), Mouse 2 (Pancada com escudo) e Mouse 1+2 (Investida de Bastião).
## 4. HUD: Opacidade e Transparência (StyleBoxFlat.bg_color alpha), Barra Minimalista (TextureButton + tooltip_text)
##    e Controles de Expansão (Tween) e Bloqueio (mouse_filter = MOUSE_FILTER_IGNORE).

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const SWORD: WeaponStyle = preload("res://resources/weapons/sword_shield.tres")
const HAMMER: WeaponStyle = preload("res://resources/weapons/heavy_hammer.tres")
const STAFF: WeaponStyle = preload("res://resources/weapons/arcane_staff.tres")
const HORN: WeaponStyle = preload("res://resources/weapons/hunting_horn.tres")

var _started: bool = false

func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false

func _run() -> void:
	print("\n========================================================")
	print("🎯 VALIDANDO CONTROLES DE COMBATE (M1 / M2 / M1+M2) E HUD")
	print("========================================================")

	test_staff_attacks_and_special()
	test_hammer_swing_lunge_and_special()
	test_sword_shield_attacks_and_special()
	test_hud_opacity_tooltips_expand_and_lock()
	test_custom_cursor_and_inventory_drop()

	print("\n🎉 CONTROLES DE COMBATE, HUD, CURSOR CRIATIVO E DESCARTE DE ITENS PASSARAM COM SUCESSO!")
	print("========================================================\n")
	quit(0)

func _spawn_player() -> Player:
	var player: Player = PlayerScene.instantiate() as Player
	root.add_child(player)
	return player

func test_staff_attacks_and_special() -> void:
	print("\n[1/4] Cajado Arcano: Mouse 1 (físico), Mouse 2 (dardo arcano) e Mouse 1+2 (Explosão Astral)...")
	var player := _spawn_player()
	player.equip_style(STAFF)

	# 1. Mouse 1: Golpe físico (primary)
	assert(player.weapon_style.primary != null, "Cajado tem ataque primário (Mouse 1)")
	assert(player.weapon_style.primary.kind == StyleAttack.Kind.MELEE, "Primário do cajado é corpo a corpo")
	var vigor_before: float = player.pools.current_vigor
	assert(player.try_attack(player.weapon_style.primary), "Golpe melee de cajado inicia com sucesso")
	assert(is_equal_approx(player.pools.current_vigor, vigor_before - player.weapon_style.primary.cost), "Golpe físico gasta Vigor")
	player._process_attack(player.weapon_style.primary.hit_delay + 0.05)
	assert(player.attack_hitbox._is_active, "Hitbox corpo a corpo ativa")
	assert(is_equal_approx(player.attack_hitbox.damage, 18.0), "Dano do golpe físico é 18")
	player._process_attack(player.weapon_style.primary.duration)
	assert(player.current_attack == null, "Golpe físico finalizado")

	# 2. Mouse 2: Dardo arcano (secondary)
	assert(player.weapon_style.secondary != null, "Cajado tem ataque secundário (Mouse 2)")
	assert(player.weapon_style.secondary.kind == StyleAttack.Kind.PROJECTILE, "Secundário do cajado é projétil arcano")
	var ether_before: float = player.pools.current_ether
	assert(player.try_attack(player.weapon_style.secondary), "Dardo arcano inicia no Mouse 2")
	assert(is_equal_approx(player.pools.current_ether, ether_before - player.weapon_style.secondary.cost), "Dardo arcano consome Éter")

	var child_count_before: int = root.get_child_count()
	player._process_attack(player.weapon_style.secondary.hit_delay + 0.02)
	assert(root.get_child_count() == child_count_before + 1, "ArcaneBolt instanciado no mundo")
	var bolt: Node = root.get_child(root.get_child_count() - 1)
	assert(bolt is ArcaneBolt, "Projétil é da classe ArcaneBolt")
	bolt.free()
	player._process_attack(player.weapon_style.secondary.duration)

	# 3. Mouse 1 + Mouse 2 juntos: Explosão Astral (special)
	assert(player.weapon_style.special != null, "Cajado possui golpe especial (Mouse 1 + Mouse 2)")
	assert(player.weapon_style.special.kind == StyleAttack.Kind.AREA, "Especial do cajado é área arcana")
	player.pools.reset_all()
	assert(player.try_special_attack(), "Golpe especial do cajado inicia")
	player._process_attack(player.weapon_style.special.duration)
	for c in root.get_children():
		if c is EarthBurst:
			c.free()

	player.free()
	print("  ✓ Cajado arcano (M1, M2 e M1+M2 Especial) validado!")

func test_hammer_swing_lunge_and_special() -> void:
	print("\n[2/4] Martelo Pesado: Mouse 1 (balanço), Mouse 2 (investida) e Mouse 1+2 (Abalo Sísmico)...")
	var player := _spawn_player()
	player.equip_style(HAMMER)

	# 1. Mouse 1: Balanço rápido (primary)
	assert(player.weapon_style.primary.kind == StyleAttack.Kind.MELEE, "Primário do martelo é golpe rápido MELEE")
	assert(player.weapon_style.primary.damage == 26.0, "Dano do balanço rápido é 26")
	var vigor_before: float = player.pools.current_vigor
	assert(player.try_attack(player.weapon_style.primary), "Balanço rápido inicia")
	assert(is_equal_approx(player.pools.current_vigor, vigor_before - player.weapon_style.primary.cost), "Balanço gasta Vigor")
	player._process_attack(player.weapon_style.primary.duration)

	# 2. Mouse 2: Investida demolidora (secondary)
	assert(player.weapon_style.secondary.kind == StyleAttack.Kind.LUNGE, "Secundário do martelo é LUNGE")
	assert(player.weapon_style.secondary.damage == 48.0, "Investida tem alto dano de 48")
	vigor_before = player.pools.current_vigor
	assert(player.try_attack(player.weapon_style.secondary), "Investida pesada inicia")
	assert(is_equal_approx(player.pools.current_vigor, vigor_before - player.weapon_style.secondary.cost), "Investida consome Vigor")
	player._process_attack(player.weapon_style.secondary.hit_delay + 0.05)
	assert(player._is_lunging(), "Jogador está em movimento de avanço / lunge")
	player._process_attack(player.weapon_style.secondary.duration)
	assert(not player._is_lunging(), "Avanço termina após duração do golpe")

	# 3. Mouse 1 + Mouse 2: Abalo Sísmico (special)
	assert(player.weapon_style.special != null and player.weapon_style.special.display_name == "Abalo Sísmico", "Especial do martelo é Abalo Sísmico")
	player.pools.reset_all()
	assert(player.try_special_attack(), "Abalo Sísmico inicia")
	player._process_attack(player.weapon_style.special.duration)
	for c in root.get_children():
		if c is EarthBurst:
			c.free()

	player.free()
	print("  ✓ Martelo pesado (M1, M2 e M1+M2 Especial) validado!")

func test_sword_shield_attacks_and_special() -> void:
	print("\n[3/4] Espada e Escudo: Mouse 1 (corte), Mouse 2 (pancada com escudo) e Mouse 1+2 (Investida de Bastião)...")
	var player := _spawn_player()
	player.equip_style(SWORD)

	# 1. Mouse 1: Golpe de espada (primary)
	assert(player.weapon_style.primary.kind == StyleAttack.Kind.MELEE, "Primário é corte de espada")
	assert(player.weapon_style.primary.damage == 22.0, "Dano de espada 22")

	# 2. Mouse 2: Pancada com escudo (secondary)
	assert(player.weapon_style.secondary != null and player.weapon_style.secondary.display_name == "Pancada com escudo", "Secundário é Pancada com escudo")
	assert(player.weapon_style.secondary.kind == StyleAttack.Kind.MELEE, "Pancada é dano de impacto MELEE")
	assert(player.weapon_style.secondary.poise_damage == 28.0, "Pancada causa 28 de dano na postura")

	var vigor_before: float = player.pools.current_vigor
	assert(player.try_attack(player.weapon_style.secondary), "Pancada com escudo inicia")
	assert(is_equal_approx(player.pools.current_vigor, vigor_before - player.weapon_style.secondary.cost), "Pancada gasta Vigor")
	player._process_attack(player.weapon_style.secondary.hit_delay + 0.05)
	assert(player.attack_hitbox._is_active, "Hitbox da pancada de escudo ativada")
	assert(is_equal_approx(player.attack_hitbox.damage, 16.0), "Dano da pancada é 16")
	player._process_attack(player.weapon_style.secondary.duration)

	# 3. Mouse 1 + Mouse 2: Investida de Bastião (special) + teste de upgrade de acorde (chord window)
	assert(player.weapon_style.special != null and player.weapon_style.special.display_name == "Investida de Bastião", "Especial de espada e escudo é Investida de Bastião")
	player.pools.reset_all()
	assert(player.try_attack(player.weapon_style.primary), "Iniciou golpe primário")
	player._process_attack(0.03) # Dentro da janela de 0.12s antes do hit_delay
	player._cancel_windup_for_chord()
	assert(is_equal_approx(player.pools.current_vigor, 100.0), "Cancelamento para acorde devolveu o Vigor do windup")
	assert(player.try_special_attack(), "Investida de Bastião disparada pelo acorde M1+M2")
	player._process_attack(player.weapon_style.special.duration)

	player.free()
	print("  ✓ Espada e escudo (M1, M2 e M1+M2 Especial) validados!")

func test_hud_opacity_tooltips_expand_and_lock() -> void:
	print("\n[4/4] HUD: Transparência de fundo, Barra Minimalista (TextureButton + Tooltips), Expansão (Tween) e Cadeado...")
	var player := _spawn_player()
	var hud := WorldHUD.new()
	hud.player = player
	var margin := MarginContainer.new()
	margin.name = "MarginContainer"
	hud.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.name = "VBoxContainer"
	margin.add_child(vbox)
	var time_lbl := Label.new()
	time_lbl.name = "TimeLabel"
	vbox.add_child(time_lbl)
	var mode_lbl := Label.new()
	mode_lbl.name = "ModeLabel"
	vbox.add_child(mode_lbl)
	var bars := VBoxContainer.new()
	bars.name = "StatusBars"
	vbox.add_child(bars)
	for bar_name in ["HealthBar", "EtherBar", "VigorBar", "PoiseBar"]:
		var pb := ProgressBar.new()
		pb.name = bar_name
		bars.add_child(pb)
	var reticle := Control.new()
	reticle.name = "Reticle"
	reticle.visible = false
	hud.add_child(reticle)
	root.add_child(hud)

	# 1. Opacidade e Transparência do StyleBoxFlat.bg_color (tema global e PanelContainers principais)
	var global_sb := root.theme.get_stylebox("panel", "PanelContainer") as StyleBoxFlat
	assert(global_sb != null and is_equal_approx(global_sb.bg_color.a, WorldHUD.PANEL_BG_ALPHA), "Tema global tem StyleBoxFlat.bg_color com transparência suave")
	var card_sb := hud.explorer_card.get_theme_stylebox("panel") as StyleBoxFlat
	var nav_sb := hud.quick_nav_panel.get_theme_stylebox("panel") as StyleBoxFlat
	assert(is_equal_approx(card_sb.bg_color.a, WorldHUD.PANEL_BG_ALPHA), "HUD superior esquerdo com fundo levemente transparente")
	assert(is_equal_approx(nav_sb.bg_color.a, WorldHUD.PANEL_BG_ALPHA), "Barra inferior com fundo levemente transparente")
	assert(is_equal_approx(hud.health_bar.modulate.a, 1.0) and is_equal_approx(hud.time_label.modulate.a, 1.0), "Barras de status e textos permanecem 100% opacos")
	var hp_fg := hud.health_bar.get_theme_stylebox("fill") as StyleBoxFlat
	assert(hp_fg != null, "HealthBar possui StyleBoxFlat no fill")
	assert(hp_fg.border_width_top == 0 and hp_fg.border_width_bottom == 0 and hp_fg.border_width_left == 0 and hp_fg.border_width_right == 0, "Fill da HealthBar não possui bordas/traços espúrios")
	assert(hp_fg.corner_radius_top_right == 0 and hp_fg.corner_radius_bottom_right == 0, "Fill da HealthBar tem corte reto à direita para medidor preciso")
	assert(hud.health_bar.custom_minimum_size.y >= 16.0, "HealthBar tem altura legível para texto de PV")
	assert(hud.poise_bar.custom_minimum_size.y >= 7.0, "PoiseBar tem altura suficiente para não parecer um fio/traço")
	assert(not hud.health_bar.tooltip_text.is_empty(), "HealthBar possui tooltip informativo")
	assert(not hud.vigor_bar.tooltip_text.is_empty(), "VigorBar possui tooltip informativo")
	assert(not hud.ether_bar.tooltip_text.is_empty(), "EtherBar possui tooltip informativo")
	assert(not hud.poise_bar.tooltip_text.is_empty(), "PoiseBar possui tooltip informativo")

	# 2. Barra de Ações Minimalista: sem Labels constantes na HBox, apenas TextureButtons com tooltip_text, KeyBadge "(Tecla)" e HoverBanner
	assert(hud.shortcut_buttons.size() == WorldHUD.ACTION_SHORTCUTS.size(), "Todos os atalhos foram criados como TextureButton")
	for child in hud.quick_nav_row.get_children():
		assert(child is TextureButton, "Barra inferior usa apenas TextureButton (sem rótulos Label constantes)")
	assert(hud.shortcut_buttons[0].tooltip_text == "[M] Mapa", "Primeiro TextureButton tem tooltip_text '[M] Mapa'")
	assert(hud.shortcut_buttons[1].tooltip_text == "[TAB] Central", "Segundo TextureButton tem tooltip_text '[TAB] Central'")
	var badge0 := hud.shortcut_buttons[0].get_node_or_null("KeyBadge") as Label
	var badge1 := hud.shortcut_buttons[1].get_node_or_null("KeyBadge") as Label
	assert(badge0 != null and badge0.text == "(M)", "Primeiro botão exibe '(M)' entre parênteses no KeyBadge")
	assert(badge1 != null and badge1.text == "(Tab)", "Segundo botão exibe '(Tab)' entre parênteses no KeyBadge")
	hud._show_hover_banner("🗺️ Mapa Mundial (M)")
	assert(hud._hover_banner.visible and hud._hover_label.text == "🗺️ Mapa Mundial (M)", "Banner de hover instantâneo exibe a descrição da ação ao passar o mouse")
	hud._hide_hover_banner()
	assert(not hud._hover_banner.visible, "Banner de hover esconde ao sair o mouse")

	# 3. Controle de Expansão/Recolhimento com Tween
	assert(hud.expand_toggle_btn != null and hud.is_ability_bar_expanded, "Começa com a barra de habilidades expandida")
	var expanded_y := hud._ability_anchor.position.y
	hud.toggle_ability_bar_expanded()
	assert(not hud.is_ability_bar_expanded, "Alternou para recolhido")
	assert(hud._ability_bar_tween != null, "Tween criado para animar a posição vertical")
	hud.set_ability_bar_expanded(false, false)
	assert(hud._ability_anchor.position.y > expanded_y, "Posição vertical recolhida deslocou para baixo")
	hud.set_ability_bar_expanded(true, false)
	assert(is_equal_approx(hud._ability_anchor.position.y, expanded_y), "Posição vertical voltou ao estado expandido")

	# 4. Controle de Bloqueio (Lock/Unlock) alterando mouse_filter para MOUSE_FILTER_IGNORE
	assert(hud.lock_toggle_btn != null and not hud.is_hud_locked, "Começa destrancado")
	hud.toggle_hud_lock()
	assert(hud.is_hud_locked, "HUD trancado pelo botão de cadeado")
	assert(hud.explorer_card.mouse_filter == Control.MOUSE_FILTER_IGNORE, "ExplorerCard ignora mouse quando trancado")
	assert(hud.quick_nav_panel.mouse_filter == Control.MOUSE_FILTER_IGNORE, "QuickNavPanel ignora mouse quando trancado")
	assert(hud.shortcut_buttons[0].mouse_filter == Control.MOUSE_FILTER_IGNORE, "Botões de atalho ignoram mouse quando trancado")
	hud.toggle_hud_lock()
	assert(not hud.is_hud_locked and hud.quick_nav_panel.mouse_filter == Control.MOUSE_FILTER_STOP, "Destrancar restaura mouse_filter")

	hud.free()
	player.free()
	print("  ✓ Opacidade, TextureButtons com Tooltips, Tween de Expansão e Cadeado Lock/Unlock validados!")

func test_custom_cursor_and_inventory_drop() -> void:
	print("\n[5/5] Cursor Criativo, Botão Direito do Mouse, Clicar e Arrastar e Jogar Itens no Chão...")
	# 1. Valida texturas procedurais e camada reativa do CustomCursor
	var arrow_tex := CustomCursor._build_arrow_cursor()
	var point_tex := CustomCursor._build_pointing_cursor()
	var drag_tex := CustomCursor._build_drag_cursor()
	var forbid_tex := CustomCursor._build_forbidden_cursor()
	assert(arrow_tex != null and arrow_tex.get_size() == Vector2(32, 32), "Ponteiro principal Espinho de Quartzo-Lume gerado (32x32)")
	assert(point_tex != null and drag_tex != null and forbid_tex != null, "Cursores de interação, arraste e bloqueio gerados")

	var cursor := CustomCursor.new()
	root.add_child(cursor)
	cursor._push_trail_point(Vector2(100, 100))
	cursor._push_trail_point(Vector2(120, 115))
	cursor._spawn_ripple(Vector2(120, 115), true)
	assert(cursor._trail.size() == 2 and cursor._ripples.size() == 1, "Rastro bioluminescente e pulso de clique direito registrados")
	cursor.free()

	# 2. Jogador pesado / sobrecarregado -> Jogar itens no chão (Botão Direito, Arrastar e Aliviar Excesso)
	var player := _spawn_player()
	var inv_screen := InventoryScreen.new()
	inv_screen.player = player
	root.add_child(inv_screen)
	inv_screen.open()

	# Adiciona 30 pedras (30 * 1.2 kg = 36 kg > 20 kg limite, causando sobrecarga)
	player.inventory.add_material(&"pedra", 30, 1)
	player.inventory.add_material(&"madeira", 6, 1)
	inv_screen.refresh()
	assert(player.inventory.get_total_weight() > player.inventory.carry_capacity(), "Jogador está acima da capacidade da mochila")
	assert(player.is_overloaded(), "Jogador está sobrecarregado (>150% do limite)")
	assert(inv_screen._relieve_btn.visible, "Botão de Aliviar Excesso aparece quando pesado")

	# 3. Ação com Botão Direito do Mouse (Menu de Contexto: Jogar 1, Metade, Tudo)
	var stone_stacks := player.inventory.get_stacks(&"pedra")
	assert(not stone_stacks.is_empty(), "Pilha de pedra presente")
	var stone_stack: Dictionary = stone_stacks[0]
	inv_screen._open_context_menu(stone_stack, Vector2(200, 200))
	assert(inv_screen._context_menu.item_count >= 5, "Menu de contexto de clique direito populado com opções de jogar no chão")

	var stones_before: int = player.inventory.get_material_count(&"pedra")
	inv_screen._on_context_menu_id_pressed(InventoryScreen.ContextAction.DROP_ONE)
	assert(player.inventory.get_material_count(&"pedra") == stones_before - 1, "Clique direito 'Jogar 1 no chão' removeu 1 pedra da mochila")

	var loot_nodes := get_nodes_in_group("dropped_loot")
	assert(loot_nodes.size() >= 1, "Trouxa 3D (DroppedLoot) instanciada no chão do mundo")
	var first_loot := loot_nodes[0] as DroppedLoot
	assert(first_loot != null and int(first_loot.stack.get("amount", 0)) == 1, "Trouxa no chão contém 1 pedra")

	# Coleta de volta do chão com [E] (talk_to)
	first_loot.talk_to(player)
	assert(player.inventory.get_material_count(&"pedra") == stones_before, "Recolher a trouxa do chão com [E] devolveu o item à mochila")

	# 4. Clicar e Arrastar (Drag & Drop) para jogar metade na GroundDropZone e trocar ordem de slots
	var first_slot_btn := inv_screen._grid.get_child(0) as Button
	assert(first_slot_btn != null, "Slot criado na grade")
	var drag_data: Variant = first_slot_btn._get_drag_data(Vector2(10, 10))
	assert(drag_data is Dictionary and (drag_data as Dictionary).get("type") == &"material_stack", "_get_drag_data retorna os dados da pilha arrastada")
	assert(inv_screen._drop_zone_bar._can_drop_data(Vector2.ZERO, drag_data), "GroundDropZone aceita o item arrastado")

	# Soltar no modo 2 (Metade)
	var dragged_id: StringName = (drag_data as Dictionary)["stack"]["id"]
	var count_before_drag: int = player.inventory.get_material_count(dragged_id)
	var expected_half: int = maxi(1, int((drag_data as Dictionary)["stack"]["amount"]) / 2)
	inv_screen.handle_ground_drop(drag_data, 2)
	assert(player.inventory.get_material_count(dragged_id) == count_before_drag - expected_half, "Arrastar e soltar em 'Metade' jogou metade da pilha no chão")

	# 5. Botão 'Aliviar Excesso' traz o peso de volta para dentro da capacidade da mochila
	if player.inventory.get_total_weight() > player.inventory.carry_capacity():
		var relieved: int = inv_screen.relieve_excess_weight()
		assert(relieved > 0, "Aliviar Excesso descartou unidades pesadas no chão")
		assert(player.inventory.get_total_weight() <= player.inventory.carry_capacity() + 0.01, "Peso voltou ao limite da mochila e jogador não está mais lento")

	for n in get_nodes_in_group("dropped_loot"):
		n.free()
	inv_screen.free()
	player.free()
	print("  ✓ Cursor criativo, menu de clique direito, arrastar e soltar e trouxas 3D no chão validados!")
