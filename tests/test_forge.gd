extends SceneTree

## B16 / GDD-06 §6: forja modular — prévia, qualidade, traits, equipar, desgaste, reparo, desmanche,
## save, peças visíveis, e tela da bigorna com boneco 3D, filtro de equipamentos/derivações e esconder capacete.

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")

var _started: bool = false

func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false

func _run() -> void:
	print("\n========================================================")
	print("⚒️ TESTANDO A FORJA MODULAR (B16 / GDD-06 §6)")
	print("========================================================")
	var player: Player = PlayerScene.instantiate() as Player
	root.add_child(player)
	player._setup_components()
	player.set_physics_process(false)
	test_preview(player)
	test_forge_and_equip(player)
	test_wear_repair_salvage(player)
	await test_save_and_visuals(player)
	await test_forge_screen_preview_and_filters(player)
	print("\n🎉 TODOS OS TESTES DA FORJA PASSARAM COM SUCESSO!")
	print("========================================================\n")
	quit(0)

func test_preview(player: Player) -> void:
	print("\n[1/5] Prévia: qualidade ponderada, traits e tempero travado...")
	var inv := player.inventory
	inv.add_material(&"couro_trotador", 3, 3, [&"integro"])
	inv.add_material(&"fibra", 4, 1)
	inv.add_material(&"erva", 2, 1)
	var core: Dictionary = inv.get_stacks(&"couro_trotador")[0]
	var coat: Dictionary = inv.get_stacks(&"fibra")[0]
	var temper: Dictionary = inv.get_stacks(&"erva")[0]
	var p := Forge.preview(&"gibao_andarilho", core, coat, {}, 1, false)
	assert(p.ok and p.quality == 2, "Núcleo 3★ pesa 2, revestimento 1★: (6+1)/3 = 2★ (saiu %s)" % [p.get("quality")])
	assert(p.traits == [&"integro"], "Slot 1 herda o trait do núcleo")
	assert(not Forge.preview(&"gibao_andarilho", core, coat, temper, 1, false).ok, "Tempero travado antes da forja 10")
	var p10 := Forge.preview(&"gibao_andarilho", core, coat, temper, 10, false)
	assert(p10.ok and p10.traits.has(&"calma_fria"), "Com forja 10 o tempero dá Calma Fria")
	assert(is_equal_approx(Forge.preview(&"gibao_andarilho", core, coat, {}, 25, true).crit, 0.2), "Crítico: 0,4%/nível + 10% da Forja Pública")
	assert(not Forge.preview(&"capuz_penacho", {}, coat, {}, 1, false).ok, "Sem núcleo não forja")
	print("  ✓ Qualidade ponderada, herança de trait, tempero na forja 10 e crítico")

func test_forge_and_equip(player: Player) -> void:
	print("\n[2/5] Forjar gasta o material, equipar aplica os efeitos...")
	var inv := player.inventory
	var stats := player.stats
	var slash0 := stats.get_stat(&"resist_slash")
	var dodge0 := stats.get_stat(&"dodge_cost")
	var load0 := stats.get_stat(&"load")
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var item := Forge.forge(inv, &"gibao_andarilho", inv.get_stacks(&"couro_trotador")[0], inv.get_stacks(&"fibra")[0], {}, 1, false, rng)
	assert(item != null and item.slot == ForgedItem.Slot.BODY, "Forjou o gibão")
	assert(inv.get_material_count(&"couro_trotador") == 0 and inv.get_material_count(&"fibra") == 0, "Gastou 3 couros e 4 fibras")
	assert(item.display_name.contains("Íntegro") and is_equal_approx(item.max_durability, 115.0), "Íntegro: nome e +15% durabilidade")
	inv.add_item(item)
	inv.equip(item)
	var mult: float = ForgedItem.QUALITY_MULT[item.quality]
	# Revestimento de fibra = família Pano (GDD-12 §2.1): mitigação ×0,6 e Carga ×0,5 do couro
	assert(item.family == &"pano" and item.display_name.contains("de Pano"), "Fibra no revestimento faz o gibão de pano")
	assert(is_equal_approx(stats.get_stat(&"resist_slash") - slash0, 0.08 * mult * 0.6), "Corte +8% × qualidade × pano")
	assert(stats.get_stat(&"dodge_cost") < dodge0, "Esquiva mais barata")
	assert(is_equal_approx(stats.get_stat(&"load") - load0, 2.5), "Carga 5 × 0,5 do pano (não escala com qualidade)")
	assert(inv.equipped[&"body"] != &"", "Nome no encaixe do peito")
	# Trocar a peça do mesmo encaixe tira os efeitos da anterior
	inv.add_material(&"couro_trotador", 3)
	inv.add_material(&"tendao_elastico", 1)
	var item2 := Forge.forge(inv, &"gibao_andarilho", inv.get_stacks(&"couro_trotador")[0], inv.get_stacks(&"tendao_elastico")[0], {}, 1, false, rng)
	inv.add_item(item2)
	inv.equip(item2)
	assert(item2.family == &"couro" and is_equal_approx(stats.get_stat(&"load") - load0, 5.0), "Tendão faz o gibão de couro, e só uma peça por encaixe (Carga não soma)")
	inv.unequip(ForgedItem.Slot.BODY)
	assert(is_equal_approx(stats.get_stat(&"resist_slash"), slash0), "Desequipar tira os efeitos")
	inv.equip(item)
	print("  ✓ Gasto de material, efeitos × qualidade, Carga, troca e desequipar")

func test_wear_repair_salvage(player: Player) -> void:
	print("\n[3/5] Desgaste, quebra, reparo e desmanche...")
	var inv := player.inventory
	var stats := player.stats
	var item := inv.equipped_in(ForgedItem.Slot.BODY)
	var slash_on := stats.get_stat(&"resist_slash")
	inv.wear_equipped(1.0)
	assert(is_equal_approx(item.durability, item.max_durability - 1.0), "Golpe gasta 1 de durabilidade")
	inv.wear_equipped(0.0, 0.10)
	assert(is_equal_approx(item.max_durability, 115.0 * 0.9), "Queda tira 10% do máximo")
	inv.wear_equipped(999.0)
	assert(item.is_broken() and stats.get_stat(&"resist_slash") < slash_on, "Quebrado não protege")
	assert(stats.get_stat(&"load") >= 2.5, "Quebrado ainda pesa")
	player.wallet.set_money(10)
	inv.add_material(&"fibra", 1)
	var max_before := item.max_durability
	assert(Forge.repair(item, inv, player.wallet).is_empty(), "Reparo com 5 $S e 1 fibra")
	inv.equip(item)
	assert(player.wallet.money == 5 and inv.get_material_count(&"fibra") == 0, "Gastou 5 $S e 1 fibra")
	assert(is_equal_approx(item.durability, item.max_durability) and is_equal_approx(item.max_durability, max_before * 0.96), "Inteiro, mas o máximo caiu 4%")
	assert(is_equal_approx(stats.get_stat(&"resist_slash"), slash_on), "Reparado protege de novo")
	var spare: ForgedItem = inv.items[1]
	var back := Forge.salvage(spare, inv)
	inv.remove_item(spare)
	assert(back.get(&"couro_trotador", 0) == 1 and inv.items.size() == 1, "Desmanche devolve 40% (3 couros → 1)")
	var salvaged := inv.get_stacks(&"couro_trotador")
	assert(not salvaged.is_empty() and salvaged[0].quality == maxi(1, spare.quality - 1), "Material volta com −1★")
	print("  ✓ Golpe, queda, quebra, reparo com perda de máximo e desmanche")

func test_save_and_visuals(player: Player) -> void:
	print("\n[4/5] Save das peças e peça visível no corpo...")
	var inv := player.inventory
	var data: Dictionary = JSON.parse_string(JSON.stringify(inv.items_to_save()))
	var item := inv.equipped_in(ForgedItem.Slot.BODY)
	var name_before := item.display_name
	var q := item.quality
	inv.load_items({})
	assert(inv.items.is_empty() and inv.equipped[&"body"] == &"", "Limpou")
	inv.load_items(data)
	var back := inv.equipped_in(ForgedItem.Slot.BODY)
	assert(back != null and back.display_name == name_before and back.quality == q, "Peça e encaixe voltam do save")
	await process_frame
	var gear := player.get_node_or_null("GearVisual") as GearVisual
	assert(gear != null, "Player tem GearVisual")
	gear.refresh()
	assert(not gear._sockets.is_empty(), "Gibão aparece preso ao osso do peito")
	print("  ✓ Save das peças e gibão visível")

func test_forge_screen_preview_and_filters(player: Player) -> void:
	print("\n[5/5] Tela da bigorna: personagem 3D com a peça, filtros de equipamento/derivação e esconder capacete...")
	var screen := ForgeScreen.new()
	root.add_child(screen)
	screen.open(player, true)
	await process_frame
	assert(screen.preview != null and screen.preview.skeleton != null, "A bigorna tem o boneco 3D com esqueleto")
	assert(player.character_visual == null or screen.preview.dna == player.character_visual.dna, "O boneco da bigorna usa o DNA do personagem")

	# Mesmo sem chifre de Rinolito na mochila, o boneco veste a prévia do Elmo Chifre-de-Pedra
	assert(screen._recipe == &"elmo_chifre_de_pedra", "Receita inicial é o elmo")
	var demo_elmo := screen.current_preview_item()
	assert(demo_elmo != null and demo_elmo.recipe_id == &"elmo_chifre_de_pedra" and demo_elmo.family == &"ferro", "Prévia inicial: elmo de ferro")
	assert(screen._gear._sockets.any(func(k): return is_instance_valid(k) and not k.is_queued_for_deletion() and k.name == "Gear_Head"), "O elmo aparece na cabeça do boneco na bigorna")

	# Trocar derivação do elmo para Couro muda a peça e o material na prévia 3D
	screen.select_derivation_family(&"couro")
	await process_frame
	var demo_elmo_couro := screen.current_preview_item()
	assert(demo_elmo_couro.family == &"couro" and demo_elmo_couro.display_name.contains("de Couro"), "Derivação trocada para Elmo de Couro")

	# Esconder capacete direto na bigorna
	screen.toggle_hide_helmet()
	await process_frame
	assert(player.inventory.hide_helmet, "Escondeu o capacete")
	assert(not screen._gear._sockets.any(func(k): return is_instance_valid(k) and not k.is_queued_for_deletion() and k.name == "Gear_Head"), "Capacete sumiu da cabeça do boneco na bigorna")
	screen.toggle_hide_helmet()
	await process_frame
	assert(not player.inventory.hide_helmet and screen._gear._sockets.any(func(k): return is_instance_valid(k) and not k.is_queued_for_deletion() and k.name == "Gear_Head"), "Capacete voltou ao boneco na bigorna")

	# Filtrar por encaixe (Botas) e testar as 3 derivações (Pano, Couro, Ferro)
	screen.set_slot_filter(ForgedItem.Slot.FEET)
	await process_frame
	assert(screen.filtered_recipes() == [&"botas_saltarelo"] and screen._recipe == &"botas_saltarelo", "Filtro de Botas seleciona Botas de Saltarelo")
	for fam in [&"pano", &"couro", &"ferro"]:
		screen.select_derivation_family(fam)
		await process_frame
		assert(screen.current_preview_item().family == fam, "Botas na derivação %s" % fam)
		assert(screen._gear._sockets.any(func(k): return is_instance_valid(k) and not k.is_queued_for_deletion() and k.name == "Gear_calf_l"), "Botas visíveis nas pernas do boneco")

	# Filtrar por derivação (Ferro) em todos os encaixes
	screen.set_slot_filter(-1)
	screen.set_family_filter(&"ferro")
	await process_frame
	var ferro_recipes := screen.filtered_recipes()
	assert(ferro_recipes.has(&"cota_ferro") and ferro_recipes.has(&"couraca_galhada") and not ferro_recipes.has(&"capuz_penacho"), "Filtro de Ferro mostra só receitas que têm derivação de ferro")
	assert(screen.filtered_items().is_empty(), "Filtro também filtra 'Suas peças' (o jogador só tem um gibão de pano)")
	screen.set_family_filter(&"pano")
	assert(screen.filtered_items().size() == 1, "Filtro de Pano mostra o gibão de pano em 'Suas peças'")
	screen.set_family_filter(&"")

	# Prévia de armas no boneco da bigorna
	screen.select_recipe(&"mangual")
	await process_frame
	assert(screen.preview.weapon != null, "Selecionar Mangual mostra a arma nas mãos do boneco na bigorna")
	screen.select_slot_option(0, 1) # núcleo de pedra (−15% dano)
	assert(is_equal_approx(screen.current_preview_item().weapon_power(), 0.85), "Derivação de núcleo de pedra no mangual mostra força 0,85")
	screen.select_recipe(&"berrante_caca")
	await process_frame
	assert(screen.preview.weapon != null and screen.preview.weapon.has_node("HornBell"), "Selecionar Berrante de Caça mostra a campana acústica nas mãos do boneco na bigorna")

	screen.close()
	screen.free()
	print("  ✓ Boneco 3D na bigorna, troca de derivações, filtros por encaixe/família, prévia de armas e esconder capacete")
