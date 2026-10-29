extends SceneTree

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const ZoneManagerClass = preload("res://scripts/core/zone_manager.gd")
const ClaimTotemClass = preload("res://scripts/claim_totem.gd")
const BuildablePieceClass = preload("res://scripts/buildable_piece.gd")
const BuildingSystemClass = preload("res://scripts/building_system.gd")
const CityHubClass = preload("res://scripts/city_hub.gd")

var _started: bool = false

func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false

func _run() -> void:
	print("\n========================================================")
	print("🏛️ TESTANDO CIDADE PRINCIPAL, ZONEAMENTO E CONSTRUÇÃO")
	print("Vila da Esperança, Zonas de Bloqueio, Totem de Território e Peças")
	print("========================================================")
	
	test_zone_manager_rules()
	test_claim_totem_territory()
	test_buildable_pieces_and_door()
	test_building_system_flow()
	test_city_hub_structures_and_npcs()
	await test_territory_rules_gdd08()
	test_structures_save_roundtrip()
	test_unburied_props_and_floor_snapping()

	print("\n🎉 TODOS OS TESTES DE CIDADE E CONSTRUÇÃO PASSARAM COM SUCESSO!")
	print("========================================================\n")
	quit(0)

func test_zone_manager_rules() -> void:
	print("\n[1/7] Validando regras de zoneamento (Cidade, Perigo, Natureza)...")
	var zm := ZoneManagerClass.new()
	root.add_child(zm)
	
	# Posição central da Cidade (1.5, 4.5)
	var city_pos := Vector3(1.5, 0.0, 4.5)
	assert(zm.get_zone_at(city_pos) == ZoneManagerClass.ZoneType.CITY, "Centro deve ser Zona da Cidade")
	assert(not zm.can_combat_at(city_pos), "Combate deve ser desativado na Cidade")
	assert(zm.can_combat_at(city_pos, true), "Duelo aceito libera o combate na Cidade (GDD-08 §8)")
	
	# Posição na Natureza aberta, a mais de 20 m da paliçada (B36: a vila cresceu)
	var wild_pos := Vector3(45.0, 0.0, 30.0)
	assert(zm.get_zone_at(wild_pos) == ZoneManagerClass.ZoneType.WILDERNESS, "Deve ser Zona Selvagem")
	assert(zm.can_combat_at(wild_pos), "Combate deve ser liberado na Natureza")
	
	# Posição de Perigo (Arena em -27, 3)
	var arena_pos := Vector3(-27.0, 0.0, 3.0)
	assert(zm.get_zone_at(arena_pos) == ZoneManagerClass.ZoneType.DANGER, "Arena deve ser Zona de Perigo")
	
	# Tentativa de construir na Cidade sem permissão
	var check_city := zm.can_build_at(city_pos, &"piso_madeira")
	assert(not check_city["allowed"], "Não deve permitir construir no centro da cidade")
	assert(check_city["reason"].contains("Urbana"), "Motivo deve citar Zona Urbana")
	
	# Tentativa de fincar Totem na Natureza
	var check_totem := zm.can_build_at(wild_pos, &"claim_totem")
	assert(check_totem["allowed"], "Deve permitir fincar Totem na Natureza")
	
	# Tentativa de construir peça na Natureza sem Totem
	var check_no_claim := zm.can_build_at(wild_pos, &"piso_madeira")
	assert(not check_no_claim["allowed"], "Não deve permitir construir na natureza sem Totem de Território")
	
	zm.free()
	print("  ✓ Zonas urbana, perigo e natureza validadas com bloqueios corretos!")

func test_claim_totem_territory() -> void:
	print("\n[2/7] Testando Totem de Território e concessão de permissão de posse...")
	var zm := ZoneManagerClass.new()
	root.add_child(zm)
	
	var totem_spot := Vector3(48.0, 0.0, 32.0)
	var totem := ClaimTotemClass.new()
	totem.position = totem_spot
	totem.owner_name = "Explorador"
	totem.radius = 14.0
	root.add_child(totem)
	
	# Posição dentro do raio do Totem (distância 6m)
	var inside_pos := totem_spot + Vector3(4.0, 0.0, 4.0)
	assert(zm.get_zone_at(inside_pos) == ZoneManagerClass.ZoneType.CLAIMED, "Posição dentro do raio deve ser CLAIMED")
	assert(zm.get_claim_at(inside_pos) == totem, "Deve associar a posição ao totem correto")
	
	# Construção dentro do território pelo dono
	var check_owner := zm.can_build_at(inside_pos, &"piso_madeira", "Explorador")
	assert(check_owner["allowed"], "Dono deve ter permissão de construir dentro do seu território")
	
	# Construção por outro jogador não autorizado
	var check_stranger := zm.can_build_at(inside_pos, &"piso_madeira", "Invasor")
	assert(not check_stranger["allowed"], "Estranho não deve poder construir no terreno de outro")
	
	totem.free()
	zm.free()
	print("  ✓ Reivindicação de território, raio de posse e permissões de dono validadas!")

func test_buildable_pieces_and_door() -> void:
	print("\n[3/7] Testando catálogo de peças modulares, porta móvel e desmontagem...")
	var player: Player = PlayerScene.instantiate() as Player
	root.add_child(player)
	player._setup_components()
	
	# 1. Piso de madeira
	var floor_piece := BuildablePieceClass.new()
	floor_piece.piece_type = BuildablePieceClass.PieceType.PISO_MADEIRA
	root.add_child(floor_piece)
	assert(floor_piece.get_child_count() > 0, "Piso deve gerar malha e colisão")
	
	# 2. Parede com Porta e mecanismo de abrir/fechar
	var door_piece := BuildablePieceClass.new()
	door_piece.piece_type = BuildablePieceClass.PieceType.PAREDE_PORTA
	root.add_child(door_piece)
	assert(not door_piece.is_door_open, "Porta deve iniciar fechada")
	door_piece.talk_to(player)
	assert(door_piece.is_door_open, "Porta deve abrir ao interagir com [E]")
	door_piece.talk_to(player)
	assert(not door_piece.is_door_open, "Porta deve fechar na segunda interação")
	
	# 3. Desmontagem: peça antiga devolve 50% (arredondado para baixo)
	var before_wood := player.inventory.get_material_count(&"madeira")
	var refunds := floor_piece.dismantle(player)
	assert(refunds.get(&"madeira", 0) == 1, "Piso antigo (2 madeira) devolve 1")
	assert(player.inventory.get_material_count(&"madeira") == before_wood + 1, "Player deve receber 1 madeira de volta")

	# 4. Desmontar na janela de 2 min devolve 100%
	var wall := BuildablePieceClass.new()
	wall.piece_type = BuildablePieceClass.PieceType.PAREDE_MADEIRA
	wall.placed_at_msec = Time.get_ticks_msec()
	root.add_child(wall)
	var full := wall.dismantle(player)
	assert(full.get(&"madeira", 0) == 3 and full.get(&"fibra", 0) == 1, "Janela de 2 min devolve o custo inteiro")

	# 5. Fora da janela, 1 fibra vira 0 (ralo)
	var old_wall := BuildablePieceClass.new()
	old_wall.piece_type = BuildablePieceClass.PieceType.PAREDE_MADEIRA
	old_wall.placed_at_msec = Time.get_ticks_msec() - BuildablePieceClass.FULL_REFUND_WINDOW_MS - 1000
	root.add_child(old_wall)
	var half := old_wall.dismantle(player)
	assert(half.get(&"madeira", 0) == 1 and not half.has(&"fibra"), "Fora da janela: 3 madeira -> 1, 1 fibra -> 0")

	door_piece.free()
	player.free()
	print("  ✓ Peças modulares, abertura de portas e reembolso de desmontagem validados!")

func test_building_system_flow() -> void:
	print("\n[4/7] Testando fluxo do BuildingSystem (B, preview e consumo)...")
	var zm := ZoneManagerClass.new()
	root.add_child(zm)
	
	var player: Player = PlayerScene.instantiate() as Player
	root.add_child(player)
	player._setup_components()
	player.position = Vector3(40.0, 0.0, 40.0) # Natureza
	
	var bs := BuildingSystemClass.new()
	bs.player = player
	bs.zone_manager = zm
	root.add_child(bs)
	
	# Ativando modo construção
	assert(not bs.is_building, "Inicia desligado")
	bs.set_building_mode(true)
	assert(bs.is_building, "Deve ficar ativo")
	
	# Dá materiais para o Totem
	player.inventory.add_material(&"madeira", 10)
	player.inventory.add_material(&"pedra", 10)
	
	# Seleciona Totem (índice 0) e atualiza posição na frente do player
	bs.current_piece_index = 0
	bs._process(0.016)
	var ok := bs._try_place_piece()
	assert(ok, "Deve conseguir colocar o Totem de Território na Natureza com materiais")
	assert(player.inventory.get_material_count(&"madeira") == 6, "Deve ter consumido 4 madeiras (sobram 6)")
	var placed: Array = get_nodes_in_group("claim_totems")
	assert(placed.size() == 1 and placed[0].placed_at_msec >= 0, "Totem recém-fincado ganha a janela de reembolso total")

	# Mesmo dono não finca um segundo totem
	bs._process(0.016)
	assert(not bs._try_place_piece(), "Segundo totem do mesmo dono deve ser negado")
	for t in placed:
		t.free()

	bs.set_building_mode(false)
	bs.free()
	player.free()
	zm.free()
	print("  ✓ Modo de construção, atalhos, validação e consumo de materiais aprovados!")

func test_city_hub_structures_and_npcs() -> void:
	print("\n[5/7] Testando montagem da Cidade Principal (Vila da Esperança)...")
	var city := CityHubClass.new()
	root.add_child(city)
	
	var child_count := city.get_child_count()
	assert(child_count >= 6, "Cidade deve gerar pórticos, placas, estradas e NPCs (atual: %d)" % child_count)
	
	city.free()
	print("  ✓ Vila da Esperança montada com praça, portões e NPCs de profissões!")

func test_territory_rules_gdd08() -> void:
	print("\n[6/7] Testando regras de território do GDD-08 (distâncias, 1 totem, catálogo, desmontar)...")
	var zm := ZoneManagerClass.new()
	root.add_child(zm)
	
	# Totem a menos de 20 m da paliçada (elipse do B36, portão sul em z = 40): (1.5, 50) fica a ~10 m
	var near_city := zm.can_build_at(Vector3(1.5, 0.0, 50.0), &"claim_totem", "Explorador")
	assert(not near_city["allowed"] and near_city["reason"].contains("Vila"), "Totem colado na vila deve ser negado")
	
	var totem := ClaimTotemClass.new()
	totem.owner_name = "Explorador"
	totem.position = Vector3(50.0, 0.0, 50.0)
	root.add_child(totem)
	
	# Mesmo dono não finca um segundo totem, mesmo longe
	var second := zm.can_build_at(Vector3(-60.0, 0.0, -60.0), &"claim_totem", "Explorador")
	assert(not second["allowed"] and second["reason"].contains("Um só"), "Só 1 totem por personagem")
	
	# Vizinho: bordas a menos de 6 m (centros a 30 m, raios 14+14 = 28 -> folga 2 m)
	var neighbor := zm.can_build_at(Vector3(80.0, 0.0, 50.0), &"claim_totem", "Vizinho")
	assert(not neighbor["allowed"] and neighbor["reason"].contains("folga"), "Territórios precisam de 6 m de folga")
	# Centros a 35 m -> folga 7 m: liberado
	var neighbor_ok := zm.can_build_at(Vector3(50.0, 0.0, 85.0), &"claim_totem", "Vizinho")
	assert(neighbor_ok["allowed"], "Com 7 m de folga o vizinho pode fincar (motivo: %s)" % neighbor_ok["reason"])
	
	# Catálogo único: totem + peças (com Fogueira, Banco, Cama e Caldeirão), custos iguais aos de BuildablePiece
	var catalog := BuildingSystemClass.build_catalog()
	assert(catalog.size() == BuildablePieceClass.PieceType.size() + 1, "Catálogo deve ter totem + peças (tem %d)" % catalog.size())
	assert(catalog[0]["is_totem"], "Tecla 1 = totem")
	assert(catalog[7]["id"] == &"bancada", "Bancada do Rancho entrou no catálogo")
	assert(catalog[2]["costs"] == BuildablePieceClass.PIECE_CONFIG[BuildablePieceClass.PieceType.PAREDE_MADEIRA]["costs"], "Custos vêm de PIECE_CONFIG")
	
	# Desmontar pelo BuildingSystem: totem com peça dentro não sai; peça sai; depois o totem sai
	var player: Player = PlayerScene.instantiate() as Player
	player.name = "Explorador"
	root.add_child(player)
	player._setup_components()
	var bs := BuildingSystemClass.new()
	bs.player = player
	bs.zone_manager = zm
	root.add_child(bs)
	
	var piece := BuildablePieceClass.new()
	piece.owner_name = "Explorador"
	piece.position = Vector3(54.0, 0.0, 50.0)
	root.add_child(piece)
	assert(not bs.try_dismantle_at(Vector3(50.0, 0.0, 50.0)), "Totem com construção dentro não pode ser desmontado")
	assert(bs.try_dismantle_at(Vector3(54.0, 0.0, 50.0)), "Dono desmonta a própria peça")
	await process_frame
	assert(bs.try_dismantle_at(Vector3(50.0, 0.0, 50.0)), "Território vazio: totem sai")
	await process_frame
	assert(zm.get_claim_at(Vector3(50.0, 0.0, 50.0)) == null, "Totem desmontado deixa de reivindicar a área")
	
	bs.free()
	player.free()
	zm.free()
	print("  ✓ Distância da vila, 1 totem por dono, folga entre territórios, catálogo único e desmontagem validados!")

func test_structures_save_roundtrip() -> void:
	print("\n[7/7] Testando save das construções (ida e volta por JSON)...")
	var zm := ZoneManagerClass.new()
	root.add_child(zm)
	var world := Node3D.new()
	root.add_child(world)
	
	var totem := ClaimTotemClass.new()
	totem.owner_name = "Explorador"
	totem.position = Vector3(-50.0, 1.0, 60.0)
	world.add_child(totem)
	var door := BuildablePieceClass.new()
	door.piece_type = BuildablePieceClass.PieceType.PAREDE_PORTA
	door.owner_name = "Explorador"
	door.position = Vector3(-48.0, 1.0, 60.0)
	door.rotation.y = PI * 0.5
	world.add_child(door)
	
	var saved: Array = JSON.parse_string(JSON.stringify(BuildingSystemClass.collect_structures(self)))
	assert(saved.size() == 2, "Deve salvar totem e porta (salvou %d)" % saved.size())
	assert(saved[0]["kind"] == "totem", "Totem vem primeiro no save")
	
	totem.free()
	door.free()
	assert(get_nodes_in_group("built_structures").is_empty(), "Mundo limpo antes de carregar")
	
	BuildingSystemClass.restore_structures(world, saved)
	var pieces := get_nodes_in_group("built_structures")
	var totems := get_nodes_in_group("claim_totems")
	assert(pieces.size() == 1 and totems.size() == 1, "Carregar recria 1 totem e 1 peça")
	var restored = pieces[0]
	assert(restored.piece_type == BuildablePieceClass.PieceType.PAREDE_PORTA, "Tipo da peça preservado")
	assert(restored.owner_name == "Explorador", "Dono preservado")
	assert(restored.position.distance_to(Vector3(-48.0, 1.0, 60.0)) < 0.01, "Posição preservada")
	assert(absf(restored.rotation.y - PI * 0.5) < 0.01, "Rotação preservada")
	assert(restored.placed_at_msec == -1, "Peça carregada não ganha janela de reembolso total")
	assert(zm.get_claim_at(Vector3(-50.0, 0.0, 60.0)) != null, "Totem carregado volta a reivindicar a área")
	
	world.free()
	zm.free()
	print("  ✓ Totens e peças sobrevivem ao save/load com tipo, dono, posição e rotação!")

func test_unburied_props_and_floor_snapping() -> void:
	print("\n[8/8] Validando elevação de banners e snapping de peças sobre pisos...")
	# 1. Banners na Vila da Esperança não estão enterrados
	var city := CityHubClass.new()
	root.add_child(city)
	var found_elevated_banner := false
	for child in city.get_children():
		var n3d := child as Node3D
		if n3d and (n3d.name.contains("Banner") or n3d.position.z == -3.2):
			assert(n3d.position.y >= 0.9, "Banners devem ter elevação positiva para não enterrar o mastro (atual: %f)" % n3d.position.y)
			found_elevated_banner = true
	assert(found_elevated_banner, "Pelo menos um banner verificado na praça")
	city.free()

	# 2. Snapping do BuildingSystem em cima de piso existente
	var zm := ZoneManagerClass.new()
	root.add_child(zm)
	var player: Player = PlayerScene.instantiate() as Player
	player.position = Vector3(40.0, 0.0, 40.0)
	root.add_child(player)
	player._setup_components()

	# Cria um piso de madeira elevado em Y = 2.0
	var floor_piece := BuildablePieceClass.new()
	floor_piece.piece_type = BuildablePieceClass.PieceType.PISO_MADEIRA
	floor_piece.position = Vector3(40.0, 2.0, 40.0)
	root.add_child(floor_piece)

	var bs := BuildingSystemClass.new()
	bs.player = player
	bs.zone_manager = zm
	root.add_child(bs)
	bs.set_building_mode(true)

	# Simula posicionamento sobre o piso
	player.position = Vector3(40.0, 2.12, 43.0)
	for i in bs.catalog.size():
		if bs.catalog[i].get("id") == &"cama":
			bs.current_piece_index = i
			break
	bs._process(0.016)

	assert(bs.ghost_root.global_position.y >= 2.11, "Peça posicionada sobre piso deve apoiar no topo da madeira (Y >= 2.12, atual: %f)" % bs.ghost_root.global_position.y)

	# 3. Piso adjacente alinha a altura com o piso existente
	for i in bs.catalog.size():
		if bs.catalog[i].get("id") == &"piso_madeira":
			bs.current_piece_index = i
			break
	player.position = Vector3(42.0, 0.0, 43.0)
	bs._process(0.016)
	assert(absf(bs.ghost_root.global_position.y - 2.0) < 0.01, "Piso adjacente deve alinhar altura com o piso vizinho (Y == 2.0, atual: %f)" % bs.ghost_root.global_position.y)

	bs.set_building_mode(false)
	bs.free()
	floor_piece.free()
	player.free()
	zm.free()
	print("  ✓ Elevação de banners e snapping de pisos/móveis 100% validados!")
