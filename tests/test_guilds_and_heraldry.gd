extends SceneTree

const _Player = preload("res://scripts/player.gd")
const _GuildData = preload("res://scripts/data/guild_data.gd")
const _GuildSystem = preload("res://scripts/systems/guild_system.gd")
const _GuildComponent = preload("res://scripts/components/guild_component.gd")
const _GuildTotem = preload("res://scripts/town/guild_totem.gd")
const _GuildBanner3D = preload("res://scripts/world/guild_banner_3d.gd")
const _GuildScreen = preload("res://scripts/ui/guild_screen.gd")
const _ZoneManager = preload("res://scripts/core/zone_manager.gd")
const _GearVisual = preload("res://scripts/components/gear_visual.gd")
const _ForgedItem = preload("res://scripts/data/forged_item.gd")

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")

var _started: bool = false

func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false

func _run() -> void:
	print("\n========================================================")
	print("🏰 TESTANDO GUILDAS, TERRITÓRIO, HERÁLDICA E UNIFORMES (GDD-15)")
	print("========================================================")

	test_guild_creation_and_heraldry()
	test_guild_donations_and_level_up()
	test_guild_system_registry()
	test_guild_totem_and_zone_manager()
	test_guild_component_and_uniforms()
	test_guild_banner_and_screen()

	print("\n🎉 TODOS OS TESTES DE GUILDA E HERÁLDICA PASSARAM COM SUCESSO!")
	print("========================================================\n")
	quit(0)

func _spawn_player(p_name: String = "Explorador") -> _Player:
	var player: _Player = PlayerScene.instantiate() as _Player
	player.name = p_name
	root.add_child(player)
	player._setup_components()
	player.set_physics_process(false)
	return player

func test_guild_creation_and_heraldry() -> void:
	print("\n[1/6] Criação de guilda, cargos e heráldica...")
	var g := _GuildData.new(&"guardioes_pinheira", "Guardiões da Pinheira", "PIN")
	g.motto = "A Luz Brilha na Escuridão"
	g.primary_color = Color(0.12, 0.45, 0.22)   # Verde musgo
	g.secondary_color = Color(0.95, 0.78, 0.25) # Ouro
	g.emblem_id = &"pinheira"

	assert(g.name == "Guardiões da Pinheira", "Nome correto")
	assert(g.tag == "PIN", "Tag correta")
	assert(g.level == 1, "Inicia no Nível 1")
	assert(g.get_territory_radius() == 40.0, "Nível 1 cobre 40m")
	assert(g.get_emblem_icon() == "🌲", "Ícone da Pinheira")

	# Membros e Cargos
	g.add_member("Tarciso", _GuildData.Role.LEADER)
	g.add_member("Caua", _GuildData.Role.OFFICER)
	g.add_member("Iara", _GuildData.Role.MEMBER)
	g.add_member("Novato", _GuildData.Role.RECRUIT)

	assert(g.is_member("Tarciso"), "Líder é membro")
	assert(g.is_officer_or_leader("Tarciso"), "Líder é oficial/líder")
	assert(g.is_officer_or_leader("Caua"), "Cauã é oficial")
	assert(not g.is_officer_or_leader("Iara"), "Iara não é oficial")
	assert(g.can_build("Iara"), "Membro pode construir")
	assert(not g.can_build("Novato"), "Recruta não pode construir sem promoção")

	g.set_member_role("Novato", _GuildData.Role.MEMBER)
	assert(g.can_build("Novato"), "Promovido pode construir")

	g.remove_member("Novato")
	assert(not g.is_member("Novato"), "Removido com sucesso")
	print("  ✓ Criação, heráldica, regras de cargos e permissões validadas")

func test_guild_donations_and_level_up() -> void:
	print("\n[2/6] Contribuição comunitária e níveis da sede...")
	var g := _GuildData.new(&"lobo_solitario", "Aliança dos Lobos", "LOB")
	assert(g.level == 1 and g.get_territory_radius() == 40.0, "Nível 1 inicial")

	# Nível 2 requer: madeira 40, pedra 30, barra_ferro 10
	assert(g.add_donation(&"madeira", 40), "Doação de madeira")
	assert(g.add_donation(&"pedra", 30), "Doação de pedra")
	assert(g.level == 1, "Ainda falta ferro para o nível 2")

	assert(g.add_donation(&"barra_ferro", 10), "Doação de ferro completa")
	assert(g.level == 2, "Evoluiu para Nível 2 (Forte de Madeira)!")
	assert(g.get_territory_radius() == 60.0, "Raio do Nível 2 expandido para 60m")

	# Nível 3 requer: pedra 80, barra_ferro 40, quartzo_lume 15
	assert(g.add_donation(&"pedra", 80), "Doação pedra nível 3")
	assert(g.add_donation(&"barra_ferro", 40), "Doação ferro nível 3")
	assert(g.add_donation(&"quartzo_lume", 15), "Doação quartzo nível 3")
	assert(g.level == 3, "Evoluiu para Nível 3 (Cidadela de Pedra & Ferro)!")
	assert(g.get_territory_radius() == 80.0, "Raio do Nível 3 expandido para 80m")

	# Save/Load roundtrip
	var dict := g.to_dict()
	var g2: _GuildData = _GuildData.from_dict(dict)
	assert(g2.name == g.name and g2.level == 3 and g2.get_territory_radius() == 80.0, "Save/Load preserva estado da guilda")
	print("  ✓ Evolução da sede, expansão territorial e persistência validadas")

func test_guild_system_registry() -> void:
	print("\n[3/6] Registro central de guildas (GuildSystem)...")
	var gs: _GuildSystem = _GuildSystem.get_instance() as _GuildSystem
	var g1: _GuildData = gs.create_guild(&"clã_rinolito", "Clã do Rinolito", "RNO", "Thor", Color.RED, Color.YELLOW, &"rinolito")
	assert(gs.get_guild(&"clã_rinolito") == g1, "Recupera guilda por ID")
	assert(gs.get_player_guild("Thor") == g1, "Encontra guilda do jogador")
	assert(gs.get_player_guild("Desconhecido") == null, "Jogador sem guilda retorna null")

	var arr: Array = gs.to_array()
	assert(arr.size() >= 1, "Serialização em array")
	print("  ✓ Registro central de guildas validado")

func test_guild_totem_and_zone_manager() -> void:
	print("\n[4/6] Totem de Guilda e integração com ZoneManager...")
	var zm := _ZoneManager.new()
	root.add_child(zm)

	var g := _GuildData.new(&"valentes", "Os Valentes", "VAL")
	g.add_member("Guerreiro1", _GuildData.Role.LEADER)
	g.add_member("Guerreiro2", _GuildData.Role.MEMBER)

	var totem := _GuildTotem.new()
	totem.guild_data = g
	totem.position = Vector3(100.0, 0.0, 100.0)
	root.add_child(totem)

	var center_pos := Vector3(100.0, 0.0, 100.0)
	var inside_pos := Vector3(120.0, 0.0, 100.0) # 20m de distância (dentro do raio de 40m)
	var outside_pos := Vector3(160.0, 0.0, 100.0) # 60m de distância (fora do raio de 40m)

	assert(zm.get_zone_at(inside_pos) == _ZoneManager.ZoneType.CLAIMED, "Área dentro do totem é CLAIMED")
	assert(zm.get_claim_at(inside_pos) == totem, "Claim associado ao GuildTotem")

	# Membro da guilda tenta construir
	var check_member := zm.can_build_at(inside_pos, &"parede_madeira", "Guerreiro2")
	assert(check_member["allowed"], "Membro da guilda tem permissão de construir no território de guilda")

	# Estranho tenta construir
	var check_stranger := zm.can_build_at(inside_pos, &"parede_madeira", "Invasor")
	assert(not check_stranger["allowed"], "Não-membro é bloqueado no território da guilda")
	assert(check_stranger["reason"].contains("Guilda"), "Mensagem cita Território de Guilda")

	totem.free()
	zm.free()
	print("  ✓ Totem de guilda, demarcação de 40m e permissões de membros validadas")

func test_guild_component_and_uniforms() -> void:
	print("\n[5/6] Componente de guilda no jogador e uniformes de clã (GDD-15 §4)...")
	var player := _spawn_player("Almirante")
	var g_comp: _GuildComponent = player.guild
	assert(g_comp != null, "Player possui GuildComponent")

	var g := _GuildData.new(&"navegantes", "Navegantes do Rio", "NAV")
	g.primary_color = Color(0.1, 0.3, 0.7) # Azul marinho
	g.secondary_color = Color.WHITE
	g.emblem_id = &"ancora"
	g.add_member("Almirante", _GuildData.Role.LEADER)
	_GuildSystem.get_instance().guilds[g.id] = g

	g_comp.join_guild(g.id)
	assert(g_comp.get_guild_data() == g, "GuildComponent associado à guilda")

	# Modo Pessoal (livre)
	g_comp.set_occasion(_GuildData.Occasion.PERSONAL)
	assert(g_comp.get_heraldry_override().is_empty(), "Equipamento pessoal não tem override de cor")

	# Modo Gala (cerimonial)
	g_comp.set_occasion(_GuildData.Occasion.GALA)
	var gala_h := g_comp.get_heraldry_override()
	assert(not gala_h.is_empty(), "Modo Gala aplica heráldica")
	assert(gala_h.get("primary_color") == g.primary_color, "Cor primária da guilda")

	# Modo Guerra (batalha)
	g_comp.set_occasion(_GuildData.Occasion.WAR)
	var war_h := g_comp.get_heraldry_override()
	assert(war_h.get("emblem_icon") == "⚓", "Brasão de âncora presente no uniforme de guerra")

	player.free()
	print("  ✓ Troca de uniformes por ocasião (Pessoal, Gala, Guerra) validada")

func test_guild_banner_and_screen() -> void:
	print("\n[6/6] Estandarte 3D e interface da guilda...")
	var g := _GuildData.new(&"falcoes", "Falcões do Mirante", "FLC")
	g.emblem_id = &"falcao"

	var banner := _GuildBanner3D.new()
	banner.set_guild(g)
	root.add_child(banner)
	assert(banner.get_child_count() > 0, "Estandarte 3D gerado com mastro e tecido")
	banner.free()

	var player := _spawn_player()
	var screen := _GuildScreen.new()
	root.add_child(screen)
	screen.open(player, g)
	assert(screen.visible, "GuildScreen abre")
	screen.close()
	assert(not screen.visible, "GuildScreen fecha")

	screen.free()
	player.free()
	print("  ✓ Estandarte heráldico 3D e interface da guilda validados")
