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
	
	print("\n🎉 TODOS OS TESTES DE CIDADE E CONSTRUÇÃO PASSARAM COM SUCESSO!")
	print("========================================================\n")
	quit(0)

func test_zone_manager_rules() -> void:
	print("\n[1/5] Validando regras de zoneamento (Cidade, Perigo, Natureza)...")
	var zm := ZoneManagerClass.new()
	root.add_child(zm)
	
	# Posição central da Cidade (1.5, 4.5)
	var city_pos := Vector3(1.5, 0.0, 4.5)
	assert(zm.get_zone_at(city_pos) == ZoneManagerClass.ZoneType.CITY, "Centro deve ser Zona da Cidade")
	assert(not zm.can_combat_at(city_pos), "Combate deve ser desativado na Cidade")
	
	# Posição na Natureza aberta (30, 0, 30)
	var wild_pos := Vector3(30.0, 0.0, 30.0)
	assert(zm.get_zone_at(wild_pos) == ZoneManagerClass.ZoneType.WILDERNESS, "Deve ser Zona Selvagem")
	assert(zm.can_combat_at(wild_pos), "Combate deve ser liberado na Natureza")
	
	# Posição de Perigo (Arena em -17, 6)
	var arena_pos := Vector3(-17.0, 0.0, 6.0)
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
	print("\n[2/5] Testando Totem de Território e concessão de permissão de posse...")
	var zm := ZoneManagerClass.new()
	root.add_child(zm)
	
	var totem_spot := Vector3(35.0, 0.0, 25.0)
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
	print("\n[3/5] Testando catálogo de peças modulares, porta móvel e desmontagem...")
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
	
	# 3. Desmontagem com reembolso de 50%
	var before_wood := player.inventory.get_material_count(&"madeira")
	var refunds := floor_piece.dismantle(player)
	assert(refunds.has(&"madeira"), "Reembolso deve conter madeira")
	assert(player.inventory.get_material_count(&"madeira") > before_wood, "Player deve receber materiais de volta")
	
	door_piece.free()
	player.free()
	print("  ✓ Peças modulares, abertura de portas e reembolso de desmontagem validados!")

func test_building_system_flow() -> void:
	print("\n[4/5] Testando fluxo do BuildingSystem (B, preview e consumo)...")
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
	
	bs.set_building_mode(false)
	bs.free()
	player.free()
	zm.free()
	print("  ✓ Modo de construção, atalhos, validação e consumo de materiais aprovados!")

func test_city_hub_structures_and_npcs() -> void:
	print("\n[5/5] Testando montagem da Cidade Principal (Vila da Esperança)...")
	var city := CityHubClass.new()
	root.add_child(city)
	
	var child_count := city.get_child_count()
	assert(child_count >= 6, "Cidade deve gerar pórticos, placas, estradas e NPCs (atual: %d)" % child_count)
	
	city.free()
	print("  ✓ Vila da Esperança montada com praça, portões e NPCs de profissões!")
