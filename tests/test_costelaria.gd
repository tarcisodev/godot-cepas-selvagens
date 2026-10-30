extends SceneTree

## B38 / GDD-17 fases 2–6: Costelária. Planta e terreno, elenco completo com Ficha, lojas
## com estoque do dia, compradores com bolsa e preço caindo, encomendas, Lições e Técnicas
## (só com o mestre), Compêndio, "Onde fica?", notícias, rotina pelo relógio e save.

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const _Layout = preload("res://scripts/costelaria/costelaria_layout.gd")
const _Cast = preload("res://scripts/costelaria/costelaria_cast.gd")
const _Hub = preload("res://scripts/costelaria/costelaria_hub.gd")
const _Economy = preload("res://scripts/costelaria/costelaria_economy.gd")
const _Techniques = preload("res://scripts/costelaria/master_techniques.gd")
const _Compendium = preload("res://scripts/costelaria/compendium.gd")
const _NpcDialog = preload("res://scripts/ui/npc_dialog.gd")
const _ZoneManager = preload("res://scripts/core/zone_manager.gd")

var _started: bool = false

func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false

func _run() -> void:
	print("\n========================================================")
	print("⭐ TESTANDO A COSTELÁRIA (B38)")
	print("========================================================")
	test_layout()
	var sun := DayNightCycle.new()
	sun.is_paused = true
	root.add_child(sun)
	sun.current_time_hours = 10.0
	var player: Player = PlayerScene.instantiate() as Player
	root.add_child(player)
	player._setup_components()
	player.set_physics_process(false)
	var hub = _Hub.new()
	root.add_child(hub)
	test_city_and_cast(hub, player)
	test_shops_and_buyers(hub, player)
	test_orders(hub, player)
	test_masters(hub, player)
	test_compendium_and_guides(hub, player)
	test_routines(hub, sun)
	test_save(hub, player)
	print("\n🎉 TODOS OS TESTES DA COSTELÁRIA PASSARAM COM SUCESSO!")
	print("========================================================\n")
	quit(0)

func test_layout() -> void:
	print("\n[1/8] Planta, terreno e zona...")
	for l in [Vector2(0, 0), Vector2(10, -20), Vector2(-5, 40)]:
		var w := _Layout.to_world(l)
		assert(_Layout.to_local(w.x, w.y).is_equal_approx(l), "Ida e volta do referencial do Colosso")
	var gate := _Layout.to_world(Vector2(0.0, 58.0))
	assert(gate.x > _Layout.CENTER.x + 50.0, "A cauda (portão) fica virada para a Vila, a leste")
	assert(_Layout.in_city(_Layout.CENTER.x, _Layout.CENTER.y) and not _Layout.in_city(0.0, 0.0), "Dentro e fora da cidade")
	var heart := _Layout.to_world(_Layout.HEART)
	assert(is_equal_approx(_Layout.shape_height(heart.x, heart.y, 7.0), _Layout.PLATEAU_Y), "Praça do Coração plana")
	assert(is_equal_approx(_Layout.shape_height(0.0, 0.0, 7.0), 7.0), "Fora da cidade o relevo fica intacto")
	assert(_Layout.is_paved(heart.x, heart.y), "Praça sem grama")
	var yard := _Layout.district_world(&"pelvis")
	assert(_Layout.in_training_yard(yard.x, yard.y) and not _Layout.in_training_yard(heart.x, heart.y), "Pátio dos Mestres")
	var zones := _ZoneManager.new()
	assert(zones.get_zone_at(Vector3(heart.x, 0, heart.y)) == _ZoneManager.ZoneType.CITY, "Costelária é zona segura")
	assert(not zones.can_combat_at(Vector3(heart.x, 0, heart.y)), "Sem combate na praça")
	assert(zones.can_combat_at(Vector3(yard.x, 0, yard.y)), "Combate liberado no Pátio dos Mestres")
	assert(not zones.can_build_at(Vector3(heart.x, 0, heart.y)).allowed, "Sem construir na cidade")
	zones.free()
	assert(_Layout.district_at(heart.x, heart.y) == &"coracao", "Bairro do ponto")
	assert(WorldSettlements.SETTLEMENTS.any(func(s): return s["id"] == &"costelaria" and s["can_fast_travel"]), "Costelária no mapa com Marco de Viagem")
	print("  ✓ Planta validada")

func test_city_and_cast(hub, player: Player) -> void:
	print("\n[2/8] Cidade e elenco completo...")
	assert(hub.skeleton != null and hub.skeleton.get_node("Ossos").mesh.get_surface_count() > 0, "Esqueleto do Colosso montado")
	assert(hub.skeleton.get_node("ColisaoDoEsqueleto").get_child_count() > 20, "Ossos que tocam o chão têm colisão")
	assert(hub.npcs.size() == _Cast.CAST.size() and _Cast.CAST.size() >= 30, "Elenco completo (%d)" % hub.npcs.size())
	for c in _Cast.CAST:
		var npc = hub.npcs[c["id"]]
		assert(npc.is_in_group("talkable") and npc.profile != null, "%s abre a Ficha" % c["name"])
	var roles := {}
	for c in _Cast.CAST:
		roles[c["role"]] = true
	for r in ["shop", "buyer", "shop_buyer", "master", "tutor", "folk"]:
		assert(roles.has(r), "Tem papel " + r)
	assert(hub.get_tree().get_nodes_in_group("costelaria_dummy").size() == 3, "Três bonecos de treino no Pátio")
	var dummy = hub.get_tree().get_nodes_in_group("costelaria_dummy")[0]
	assert(dummy.training_only, "Boneco do Pátio não dá loot")
	assert(hub.find_child("BigornaDaCostelaria", true, false) != null, "Bigorna no Salão das Forjas")
	# Ficha de uma loja: Comprar/Vender e Conversar; dentro dela compra de verdade
	var salvia = hub.npcs[&"nha_salvia"]
	player.global_position = salvia.global_position + Vector3(1.0, 0, 0)
	salvia.talk_to(player)
	var dialog = _NpcDialog.instance
	assert(dialog.is_open() and dialog.profile.title == "Boticária", "Ficha da Boticária")
	var ids: Array = dialog.actions().map(func(a): return a.id)
	assert(ids.has(&"comprar") and ids.has(&"vender") and ids.has(&"conversar"), "Comprar, Vender e Conversar")
	dialog.close()
	var corisca = hub.npcs[&"corisca"]
	ids = corisca.profile.all_actions().map(func(a): return a.id)
	assert(ids.has(&"licao_lâmina") and ids.has(&"tecnica_lâmina") and ids.has(&"onde_lâmina"), "Mestra: Lição, Técnica e Onde treinar")
	assert(hub.npcs[&"pena_de_osso"].profile.all_actions().any(func(a): return a.id == &"compendio"), "Arquivista abre o Compêndio")
	assert(hub.npcs[&"guarda_osmar"].profile.all_actions().any(func(a): return a.id == &"onde_fica"), "Guarda: Onde fica?")
	assert(hub.npcs[&"voz_de_trovao"].profile.all_actions().any(func(a): return a.id == &"noticias"), "Pregoeira: Notícias")
	print("  ✓ Cidade e elenco validados")

func test_shops_and_buyers(hub, player: Player) -> void:
	print("\n[3/8] Lojas e compradores com bolsa do dia...")
	var eco = hub.economy
	player.wallet.set_money(500)
	var before: int = eco.stock_of(&"nha_salvia", &"pocao")
	assert(before == _Economy.STOCK_PER_ITEM, "Estoque cheio ao amanhecer")
	assert(eco.buy(&"nha_salvia", &"pocao", player) == "", "Compra")
	assert(eco.stock_of(&"nha_salvia", &"pocao") == before - 1 and player.inventory.get_material_count(&"pocao") >= 1, "Sai do estoque e entra no inventário")
	assert(player.wallet.money == 500 - eco.price(&"nha_salvia", &"pocao"), "Paga o preço da tabela")
	for i in before - 1:
		eco.buy(&"nha_salvia", &"pocao", player)
	assert(eco.buy(&"nha_salvia", &"pocao", player).contains("Acabou"), "Estoque acaba no dia")
	# Comprador: 0,6 × valor-base e 3% a menos por unidade vendida na cidade
	var base := MaterialData.of(&"ossos").base_value
	var first: int = eco.offer(&"seu_graxa", &"ossos")
	assert(first == maxi(1, roundi(base * 0.6)), "Primeira unidade a 0,6 × valor-base")
	assert(eco.offer(&"seu_graxa", &"pocao") == 0, "Não compra o que não é dele")
	player.inventory.add_material(&"chifre_galhado", 12, 1)
	var p0: int = eco.offer(&"seu_graxa", &"chifre_galhado")
	var money: int = player.wallet.money
	assert(eco.sell(&"seu_graxa", &"chifre_galhado", player) == "", "Vende")
	assert(player.wallet.money == money + p0, "Recebe o preço da hora")
	assert(eco.sold_today[&"chifre_galhado"] == 1, "A venda conta para a cidade inteira")
	for i in 4:
		eco.sell(&"seu_graxa", &"chifre_galhado", player)
	assert(eco.offer(&"seu_graxa", &"chifre_galhado") < p0, "Preço cai a cada unidade vendida no dia")
	var guard := 0
	while eco.sell(&"seu_graxa", &"chifre_galhado", player) == "" and guard < 50:
		guard += 1
	assert(eco.purse_of(&"seu_graxa") < eco.offer(&"seu_graxa", &"chifre_galhado") or player.inventory.get_material_count(&"chifre_galhado") == 0, "Para na bolsa do dia ou quando acaba o material")
	assert(eco.purse_of(&"seu_graxa") <= _Economy.PURSE_PER_DAY, "Bolsa nunca passa do teto")
	# Amanhecer: tudo volta
	eco.ensure_day(eco.day + 1)
	assert(eco.stock_of(&"nha_salvia", &"pocao") == _Economy.STOCK_PER_ITEM and eco.purse_of(&"seu_graxa") == _Economy.PURSE_PER_DAY, "Repõe ao amanhecer")
	assert(eco.offer(&"seu_graxa", &"chifre_galhado") == maxi(1, roundi(MaterialData.of(&"chifre_galhado").base_value * 0.6)), "Preço volta ao amanhecer")
	assert(eco.night_offer.size() == _Economy.NIGHT_OFFER_SIZE, "Feira do Ventre sorteia a oferta do dia")
	var same := _Economy.new()
	same.ensure_day(eco.day)
	assert(same.night_offer == eco.night_offer and same.orders.size() == eco.orders.size(), "Sorteio do dia igual para todos (semente do dia)")
	print("  ✓ Comércio validado")

func test_orders(hub, player: Player) -> void:
	print("\n[4/8] Encomendas do Seu Graxa...")
	var eco = hub.economy
	assert(eco.orders.size() == _Economy.ORDERS_PER_DAY, "Duas encomendas por dia")
	var o: Dictionary = eco.orders[0]
	assert(eco.deliver(0, player).contains("Preciso"), "Sem a parte, não entrega")
	player.inventory.add_material(o["material"], o["amount"], 1)
	assert(eco.deliver(0, player).contains("Preciso"), "★ abaixo da mínima não conta")
	player.inventory.add_material(o["material"], o["amount"], o["min_q"])
	var money: int = player.wallet.money
	var rep: int = eco.reputation
	assert(eco.deliver(0, player) == "", "Entrega com a ★ certa")
	assert(player.wallet.money == money + o["reward"] and eco.reputation == rep + _Economy.ORDER_REPUTATION, "Prêmio e Reputação")
	assert(eco.deliver(0, player).contains("já entregou"), "Encomenda é de quem chegar primeiro")
	print("  ✓ Encomendas validadas")

func test_masters(hub, player: Player) -> void:
	print("\n[5/8] Mestres: Lição, Prova e Técnica só com o mestre...")
	var m: MasteryComponent = player.mastery
	assert(hub.technique_reason(&"lâmina", 10, player).contains("Precisa de"), "Sem o nível, sem Técnica")
	m._masteries[&"lâmina"] = {"level": 12, "xp": 0.0}
	assert(hub.technique_reason(&"lâmina", 10, player).contains("Prova"), "Nível sozinho não libera: falta a Prova")
	assert(m.technique_bonus(&"dmg_slash") == 0.0, "Marco alcançado sem mestre não dá bônus")
	# Lição de golpes nos bonecos do Pátio
	assert(hub.start_lesson(&"lâmina", player) == "", "Começa a Lição")
	var goal: int = hub.lesson["goal"]
	var dummy = hub.get_tree().get_nodes_in_group("costelaria_dummy")[0]
	var xp_before := m.get_xp(&"lâmina")
	for i in goal:
		var hit := HitEvent.new()
		hit.attacker = player
		hit.target = dummy
		hit.damage_type = DamageType.Type.SLASH
		hub._on_hit_resolved(hit, 5.0, false)
	assert(hub.lesson.is_empty() and m.has_lesson(&"lâmina", 1), "Lição completa marca a Prova da faixa")
	assert(m.get_xp(&"lâmina") > xp_before or m.get_level(&"lâmina") > 12, "Bônus de primeira vez")
	player.wallet.set_money(10)
	assert(hub.technique_reason(&"lâmina", 10, player).contains("$S"), "Técnica tem taxa")
	player.wallet.set_money(1000)
	assert(hub.learn_technique(&"lâmina", 10, player) == "", "Aprende com o mestre")
	assert(player.wallet.money == 1000 - _Techniques.COST[10] and m.has_technique(&"lâmina", 10), "Paga e aprende")
	assert(is_equal_approx(m.technique_bonus(&"dmg_slash"), 0.05), "Corte Firme: +5% de corte")
	assert(hub.technique_reason(&"lâmina", 25, player).contains("Precisa de"), "Próximo marco pede nível")
	# O bônus entra no CombatResolver
	assert(is_equal_approx(CombatResolver._technique(player, &"dmg_slash"), 0.05), "CombatResolver lê a Técnica do atacante")
	# Esfola: o degrau de tempo só vem com a Técnica
	m._masteries[&"esfola"] = {"level": 12, "xp": 0.0}
	assert(player.get_harvest_time() == 3.0, "Esfola 10 sem mestre continua 3 s")
	m.learn_technique(&"esfola", 10)
	assert(player.get_harvest_time() == 2.5, "Com a Faca Treinada, 2,5 s")
	# Forja: tempero só com Mão de Tempero
	assert(Forge.TEMPER_LEVEL == 10, "Marco da forja")
	# Lição de mostrar (coleta) confere na hora sem gastar
	m._masteries[&"coleta"] = {"level": 3, "xp": 0.0}
	assert(hub.start_lesson(&"coleta", player).contains("Ainda não"), "Sem coleta, sem Lição")
	player.inventory.add_material(&"madeira", 10, 1)
	var wood := player.inventory.get_material_count(&"madeira")
	assert(hub.start_lesson(&"coleta", player) == "" and m.has_lesson(&"coleta", 0), "Mostrar completa a Lição")
	assert(player.inventory.get_material_count(&"madeira") == wood, "Mostrar não gasta")
	# Conselho aponta a bússola
	hub._advise(player, &"esfola")
	assert(hub.last_compass.get("name", "").contains("Besta"), "Onde treinar esfola: Morro da Besta")
	print("  ✓ Mestres validados")

func test_compendium_and_guides(hub, player: Player) -> void:
	print("\n[6/8] Compêndio, Guarda, Cartógrafa e Pregoeira...")
	assert(hub.pages.has(&"treino_licao") and hub.pages.has(&"treino_tecnica"), "Lição e Técnica abriram páginas")
	var rep: int = hub.economy.reputation
	hub.unlock_page(&"ciclo_relogio")
	hub.unlock_page(&"ciclo_ventre")
	assert(hub.economy.reputation == rep + _Compendium.CHAPTER_REPUTATION, "Capítulo completo dá Reputação")
	hub.unlock_page(&"ciclo_ventre")
	assert(hub.economy.reputation == rep + _Compendium.CHAPTER_REPUTATION, "Página repetida não conta duas vezes")
	hub.show_npc(&"ambar", player)
	assert(hub.last_compass["name"] == "Âmbar" and hub.last_compass["pos"].is_equal_approx(hub.npcs[&"ambar"].global_position), "Onde fica: bússola até o NPC")
	hub.show_target(&"cranio", player)
	assert(hub.last_compass["name"].begins_with("Crânio"), "Mostre-me: bairro")
	var news: Array = hub.news()
	assert(news.size() >= 2 and news[0].contains("caravana"), "Notícias do vale")
	# Conversar com o Arquivista abre a página dele pela Ficha
	var archivist = hub.npcs[&"pena_de_osso"]
	player.global_position = archivist.global_position + Vector3(1, 0, 0)
	archivist.talk_to(player)
	var dialog = _NpcDialog.instance
	var list: Array = dialog.actions()
	var talk_index := list.map(func(a): return a.id).find(&"conversar")
	hub.pages.erase(&"ciclo_relogio")
	assert(dialog.choose(talk_index) and hub.pages.has(&"ciclo_relogio"), "Conversar abre a página")
	dialog.close()
	print("  ✓ Tutores validados")

func test_routines(hub, sun: DayNightCycle) -> void:
	print("\n[7/8] Rotina pelo relógio único...")
	var salvia = hub.npcs[&"nha_salvia"]
	var c := _Cast.by_id(&"nha_salvia")
	sun.current_time_hours = 22.0
	hub._update_routines(22.0, 0.5)
	var post: Vector2 = c["post"]
	assert(Vector2(salvia.position.x, salvia.position.z).distance_to(post) > 0.5, "Fora do horário ela sai do posto andando")
	assert(salvia.visual.current() == &"Walk", "Anda (sem teleporte)")
	hub.settle_routines()
	var home: Vector2 = c["home"]
	assert(Vector2(salvia.position.x, salvia.position.z).distance_to(home) < 0.2, "Dorme em casa")
	var mascate = hub.npcs[&"mascate_sombra"]
	assert(mascate.profile.is_open_at(22.0) and not salvia.profile.is_open_at(22.0), "De noite o Ventre abre e a Boticária fecha")
	var guard = hub.npcs[&"guarda_osmar"]
	assert(guard.profile.is_open_at(3.0), "Guarda atende 24 h")
	sun.current_time_hours = 10.0
	hub.settle_routines()
	assert(Vector2(salvia.position.x, salvia.position.z).distance_to(post) < 0.2, "De manhã volta ao posto")
	print("  ✓ Rotina validada")

func test_save(hub, _player: Player) -> void:
	print("\n[8/8] Save da Costelária...")
	var eco = hub.economy
	eco.ensure_day(0)
	eco.orders[0]["done"] = true
	eco.reputation = 37
	eco.stock[&"nha_salvia"][&"mega_pocao"] = 2
	var state: Dictionary = JSON.parse_string(JSON.stringify(hub.get_state()))
	var other = _Hub.new()
	root.add_child(other)
	other.apply_state(state)
	assert(other.economy.reputation == 37, "Reputação volta")
	assert(other.economy.stock_of(&"nha_salvia", &"mega_pocao") == 2, "Estoque do dia volta")
	assert(other.economy.orders[0]["done"] == eco.orders[0]["done"], "Encomenda entregue continua entregue")
	assert(other.pages.size() == hub.pages.size(), "Páginas do Compêndio voltam")
	other.queue_free()
	print("  ✓ Save validado")
