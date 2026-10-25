extends SceneTree

## Coluna de equipamento da tela [I] (GDD-12 §1): boneco 3D vestido com o que está equipado,
## lista de peças por encaixe, equipar e tirar pela tela, opção de esconder o capacete e zoom.

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")

var _started: bool = false

func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false

func _run() -> void:
	print("\n========================================================")
	print("🧍 TESTANDO A COLUNA DE EQUIPAMENTO DO INVENTÁRIO")
	print("========================================================")
	var player: Player = PlayerScene.instantiate() as Player
	root.add_child(player)
	player._setup_components()
	player.set_physics_process(false)
	var inv := player.inventory
	var rng := RandomNumberGenerator.new()
	inv.add_material(&"couro_trotador", 6, 2)
	inv.add_material(&"tendao_elastico", 1, 2)
	inv.add_material(&"fibra", 4, 2)
	inv.add_material(&"chifre_rinolito", 1, 3)
	inv.add_material(&"placa_carapaca", 2, 3)
	var couro := Forge.forge(inv, &"gibao_andarilho", inv.get_stacks(&"couro_trotador")[0], inv.get_stacks(&"tendao_elastico")[0], {}, 1, false, rng)
	var pano := Forge.forge(inv, &"gibao_andarilho", inv.get_stacks(&"couro_trotador")[0], inv.get_stacks(&"fibra")[0], {}, 1, false, rng)
	var elmo := Forge.forge(inv, &"elmo_chifre_de_pedra", inv.get_stacks(&"chifre_rinolito")[0], inv.get_stacks(&"placa_carapaca")[0], {}, 1, false, rng)
	inv.add_item(couro)
	inv.add_item(pano)
	inv.add_item(elmo)

	var screen := InventoryScreen.new()
	screen.player = player
	root.add_child(screen)
	screen.open()
	await process_frame
	var panel: EquipmentPanel = screen._equipment
	assert(panel != null and panel.player == player, "A tela [I] tem a coluna de equipamento ligada ao jogador")
	assert(panel._slot_buttons.size() == 7, "Os 7 encaixes aparecem")
	assert(panel.candidates(ForgedItem.Slot.BODY).size() == 2 and panel.candidates(ForgedItem.Slot.HEAD).size() == 1, "Lista só o que cabe no encaixe")

	panel.equip_item(pano)
	assert(inv.equipped_in(ForgedItem.Slot.BODY) == pano, "Equipar pela tela")
	assert(panel._slot_buttons[ForgedItem.Slot.BODY].text.contains("Gibão"), "O botão do peito mostra a peça")
	assert(panel._summary.text.contains("[5] Véu"), "O resumo mostra a habilidade do peito de pano")
	await process_frame
	assert(panel.preview.skeleton != null and panel._gear._sockets.any(func(k): return is_instance_valid(k) and not k.is_queued_for_deletion() and k.get_parent() == panel.preview.skeleton), "O boneco veste a peça")
	panel.equip_item(couro)
	assert(inv.equipped_in(ForgedItem.Slot.BODY) == couro and panel._summary.text.contains("[5] Esquivo"), "Trocar a peça troca a habilidade")
	panel.unequip_slot(ForgedItem.Slot.BODY)
	assert(inv.equipped_in(ForgedItem.Slot.BODY) == null and panel._slot_buttons[ForgedItem.Slot.BODY].text.contains("vazio"), "Tirar pela tela")
	assert(player.character_visual == null or panel.preview.dna == player.character_visual.dna, "O boneco tem o DNA do jogador")

	# Opção de esconder capacete: esconde no visual sem perder defesa nem habilidade
	var slash_before := player.stats.get_stat(&"resist_slash")
	panel.equip_item(elmo)
	await process_frame
	assert(player.stats.get_stat(&"resist_slash") > slash_before, "Elmo equipado dá defesa")
	assert(panel._gear._sockets.any(func(k): return is_instance_valid(k) and not k.is_queued_for_deletion() and k.name == "Gear_Head"), "Elmo visível na cabeça antes de esconder")
	panel.toggle_hide_helmet()
	await process_frame
	assert(inv.hide_helmet, "Opção de esconder capacete ativada")
	assert(inv.equipped_in(ForgedItem.Slot.HEAD) == elmo and player.stats.get_stat(&"resist_slash") > slash_before, "Esconder capacete mantém a peça equipada e os atributos")
	assert(panel._summary.text.contains("[4] Investida"), "Esconder capacete mantém a habilidade do elmo")
	assert(panel._slot_buttons[ForgedItem.Slot.HEAD].text.contains("(oculto)"), "Botão da cabeça indica que está oculto")
	assert(not panel._gear._sockets.any(func(k): return is_instance_valid(k) and not k.is_queued_for_deletion() and k.name == "Gear_Head"), "Elmo sumiu do boneco 3D")
	var saved_gear := inv.items_to_save()
	assert(saved_gear.get("hide_helmet", false) == true, "Save guarda a preferência de esconder capacete")
	panel.toggle_hide_helmet()
	await process_frame
	assert(not inv.hide_helmet and panel._gear._sockets.any(func(k): return is_instance_valid(k) and not k.is_queued_for_deletion() and k.name == "Gear_Head"), "Mostrar capacete devolve o elmo ao boneco 3D")

	for i in 30:
		panel.zoom_by(-0.3)
	assert(is_equal_approx(panel._zoom, EquipmentPanel.ZOOM_MIN), "Zoom tem limite perto")
	for i in 30:
		panel.zoom_by(0.3)
	assert(is_equal_approx(panel._zoom, EquipmentPanel.ZOOM_MAX), "Zoom tem limite longe")
	screen.close()
	print("  ✓ Encaixes, lista por encaixe, equipar/trocar/tirar, esconder capacete, boneco vestido e zoom")
	print("\n🎉 TODOS OS TESTES DA COLUNA DE EQUIPAMENTO PASSARAM COM SUCESSO!")
	print("========================================================\n")
	quit(0)
