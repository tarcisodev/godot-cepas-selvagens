extends SceneTree

## Coluna de equipamento da tela [I] (GDD-12 §1): boneco 3D vestido com o que está equipado,
## lista de peças por encaixe, equipar e tirar pela tela, zoom com limite.

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
	var couro := Forge.forge(inv, &"gibao_andarilho", inv.get_stacks(&"couro_trotador")[0], inv.get_stacks(&"tendao_elastico")[0], {}, 1, false, rng)
	var pano := Forge.forge(inv, &"gibao_andarilho", inv.get_stacks(&"couro_trotador")[0], inv.get_stacks(&"fibra")[0], {}, 1, false, rng)
	inv.add_item(couro)
	inv.add_item(pano)

	var screen := InventoryScreen.new()
	screen.player = player
	root.add_child(screen)
	screen.open()
	await process_frame
	var panel: EquipmentPanel = screen._equipment
	assert(panel != null and panel.player == player, "A tela [I] tem a coluna de equipamento ligada ao jogador")
	assert(panel._slot_buttons.size() == 7, "Os 7 encaixes aparecem")
	assert(panel.candidates(ForgedItem.Slot.BODY).size() == 2 and panel.candidates(ForgedItem.Slot.HEAD).is_empty(), "Lista só o que cabe no encaixe")

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

	for i in 30:
		panel.zoom_by(-0.3)
	assert(is_equal_approx(panel._zoom, EquipmentPanel.ZOOM_MIN), "Zoom tem limite perto")
	for i in 30:
		panel.zoom_by(0.3)
	assert(is_equal_approx(panel._zoom, EquipmentPanel.ZOOM_MAX), "Zoom tem limite longe")
	screen.close()
	print("  ✓ Encaixes, lista por encaixe, equipar/trocar/tirar, boneco vestido e zoom")
	print("\n🎉 TODOS OS TESTES DA COLUNA DE EQUIPAMENTO PASSARAM COM SUCESSO!")
	print("========================================================\n")
	quit(0)
