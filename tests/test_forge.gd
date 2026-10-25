extends SceneTree

## B16 / GDD-06 §6: forja modular — prévia, qualidade, traits, equipar, desgaste, reparo, desmanche,
## save e peças visíveis.

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
	test_preview(player)
	test_forge_and_equip(player)
	test_wear_repair_salvage(player)
	await test_save_and_visuals(player)
	print("\n🎉 TODOS OS TESTES DA FORJA PASSARAM COM SUCESSO!")
	print("========================================================\n")
	quit(0)

func test_preview(player: Player) -> void:
	print("\n[1/4] Prévia: qualidade ponderada, traits e tempero travado...")
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
	print("\n[2/4] Forjar gasta o material, equipar aplica os efeitos...")
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
	print("\n[3/4] Desgaste, quebra, reparo e desmanche...")
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
	print("\n[4/4] Save das peças e peça visível no corpo...")
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
