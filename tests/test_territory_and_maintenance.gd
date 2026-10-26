extends SceneTree

const ClaimTotemClass = preload("res://scripts/claim_totem.gd")
const BuildablePieceClass = preload("res://scripts/buildable_piece.gd")
const BuildingSystemClass = preload("res://scripts/building_system.gd")
const ZoneManagerClass = preload("res://scripts/core/zone_manager.gd")
const TerritoryScreenClass = preload("res://scripts/ui/territory_screen.gd")
const WalletComponentClass = preload("res://scripts/components/wallet_component.gd")
const InventoryComponentClass = preload("res://scripts/components/inventory_component.gd")

var _started: bool = false

func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false

func _run() -> void:
	print("\n========================================================")
	print("🏕️ TESTANDO MANUTENÇÃO TERRITORIAL, COFRE E RUÍNAS (B32)")
	print("GDD-08 §4, §8 Decisão 7 e GDD-05 §5: Ralo de $S, Carência e Saque")
	print("========================================================")

	test_totem_initial_state()
	test_vault_deposit_and_withdraw()
	test_advance_days_consumption()
	test_grace_period_to_ruin_abandonment()
	test_ruin_recovery_by_owner_deposit()
	test_building_permissions_whitelist()
	test_dismantle_ruins_public_salvage()
	test_structures_save_roundtrip()
	test_territory_screen_ui()

	print("\n🎉 TODOS OS TESTES DE MANUTENÇÃO TERRITORIAL E RUÍNAS PASSARAM COM SUCESSO!")
	print("========================================================\n")
	quit(0)

func test_totem_initial_state() -> void:
	print("\n[1/9] Estado inicial do Totem de Território...")
	var totem := ClaimTotemClass.new()
	totem.owner_name = "Tarciso1"
	root.add_child(totem)

	assert(totem.maintenance_funds == 25, "Totem novo deve começar com 25 $S de saldo inicial")
	assert(totem.status == ClaimTotemClass.Status.ACTIVE, "Status inicial deve ser ACTIVE")
	assert(totem.grace_days_elapsed == 0.0, "Carência decorrida deve ser zero")
	assert(totem.radius == ClaimTotemClass.DEFAULT_RADIUS, "Raio padrão deve ser 14m")

	totem.free()
	print("  ✓ Estado inicial validado com sucesso.")

func test_vault_deposit_and_withdraw() -> void:
	print("\n[2/9] Depósito e retirada no Cofre de Manutenção...")
	var totem := ClaimTotemClass.new()
	totem.owner_name = "Tarciso2"
	root.add_child(totem)

	var player := Node3D.new()
	player.name = "Tarciso2"
	var wallet := WalletComponentClass.new()
	wallet.money = 100
	player.add_child(wallet)
	player.set_meta("wallet", wallet)
	root.add_child(player)

	# Depósito de 50 $S
	var ok := totem.deposit_maintenance(50, player)
	assert(ok, "Depósito deve ser aceito")
	assert(totem.maintenance_funds == 75, "Fundos devem ser 25 + 50 = 75 $S")
	assert(wallet.money == 50, "Carteira deve debitar 50 $S (resta 50 $S)")

	# Tentativa de depósito acima do teto de 250
	wallet.money = 500
	totem.deposit_maintenance(200, player)
	assert(totem.maintenance_funds == ClaimTotemClass.MAX_FUNDS, "Fundos não podem ultrapassar MAX_FUNDS (250 $S)")

	# Retirada pelo dono
	var withdraw_ok := totem.withdraw_maintenance(50, player)
	assert(withdraw_ok, "Dono deve poder retirar fundos do cofre")
	assert(totem.maintenance_funds == 200, "Cofre deve subtrair retirada")

	# Tentativa de retirada por estranho
	var stranger := Node3D.new()
	stranger.name = "Invasor"
	var stranger_wallet := WalletComponentClass.new()
	stranger.add_child(stranger_wallet)
	stranger.set_meta("wallet", stranger_wallet)
	root.add_child(stranger)

	var stolen := totem.withdraw_maintenance(50, stranger)
	assert(not stolen, "Estranho não pode retirar fundos do totem de outro jogador")

	totem.free()
	player.free()
	stranger.free()
	print("  ✓ Depósito, limites e permissões de saque validados.")

func test_advance_days_consumption() -> void:
	print("\n[3/9] Consumo diário de fundos com a passagem do tempo...")
	var totem := ClaimTotemClass.new()
	totem.owner_name = "Tarciso3"
	totem.maintenance_funds = 25
	root.add_child(totem)

	# Avançar 2 dias: 25 - (2 * 5) = 15 $S restantes
	totem.advance_days(2.0)
	assert(totem.maintenance_funds == 15, "Deve sobrar 15 $S após 2 dias (consumo 5 $S/dia)")
	assert(totem.status == ClaimTotemClass.Status.ACTIVE, "Deve continuar ACTIVE enquanto houver fundos")

	# Avançar 3 dias: 15 - (3 * 5) = 0 $S restantes
	totem.advance_days(3.0)
	assert(totem.maintenance_funds == 0, "Cofre deve zerar após 3 dias")
	assert(totem.status == ClaimTotemClass.Status.VULNERABLE, "Cofre zerado deve mudar status para VULNERABLE")
	assert(totem.grace_days_elapsed == 0.0, "Carência começa em 0.0 no momento exato em que zera")

	totem.free()
	print("  ✓ Débito diário e transição para VULNERABLE validados.")

func test_grace_period_to_ruin_abandonment() -> void:
	print("\n[4/9] Período de carência e decaimento em Ruína Abandonada...")
	var totem := ClaimTotemClass.new()
	totem.owner_name = "Tarciso4"
	totem.maintenance_funds = 0
	totem.grace_days_elapsed = 0.0
	root.add_child(totem)

	# 1.5 dias sem fundos (dentro da carência de 3.0 dias)
	totem.advance_days(1.5)
	assert(totem.status == ClaimTotemClass.Status.VULNERABLE, "Abaixo de 3.0 dias de carência deve permanecer VULNERABLE")
	assert(totem.grace_days_elapsed == 1.5, "Carência decorrida deve registrar 1.5 dias")

	# Mais 2.0 dias sem fundos (total 3.5 dias > 3.0) -> vira Ruína Abandonada
	totem.advance_days(2.0)
	assert(totem.grace_days_elapsed == 3.5, "Carência decorrida deve registrar 3.5 dias")
	assert(totem.status == ClaimTotemClass.Status.ABANDONED, "Carência esgotada deve mudar status para ABANDONED")

	totem.free()
	print("  ✓ Tolerância de carência e decaimento em Ruína validados.")

func test_ruin_recovery_by_owner_deposit() -> void:
	print("\n[5/9] Recuperação de rancho vulnerável via novo depósito...")
	var totem := ClaimTotemClass.new()
	totem.owner_name = "Tarciso5"
	root.add_child(totem)
	totem.maintenance_funds = 0
	totem.grace_days_elapsed = 2.0
	totem._update_status()

	assert(totem.status == ClaimTotemClass.Status.VULNERABLE, "Deve estar VULNERABLE")

	# Dono deposita 30 $S (6 dias de proteção)
	totem.deposit_maintenance(30)
	assert(totem.maintenance_funds == 30, "Cofre deve receber 30 $S")
	assert(totem.status == ClaimTotemClass.Status.ACTIVE, "Depósito deve restaurar status ACTIVE imediatamente")
	assert(totem.grace_days_elapsed == 0.0, "Carência decorrida deve ser resetada para 0.0")

	totem.free()
	print("  ✓ Reativação do cofre e reset de carência validados.")

func test_building_permissions_whitelist() -> void:
	print("\n[6/9] Permissões de construção e Whitelist...")
	var zm := ZoneManagerClass.new()
	root.add_child(zm)

	var totem := ClaimTotemClass.new()
	totem.owner_name = "Tarciso6"
	totem.position = Vector3(40.0, 0.0, 40.0)
	totem.maintenance_funds = 25
	root.add_child(totem)

	# 1. Dono constrói quando ACTIVE
	var res_owner := zm.can_build_at(Vector3(42.0, 0.0, 40.0), &"piece", "Tarciso6")
	assert(res_owner["allowed"], "Dono deve poder construir no seu território ativo")

	# 2. Visitante não autorizado não pode construir
	var res_stranger := zm.can_build_at(Vector3(42.0, 0.0, 40.0), &"piece", "Visitante")
	assert(not res_stranger["allowed"], "Visitante comum não pode construir em território alheio")

	# 3. Adicionar parceiro à whitelist
	totem.add_allowed_builder("Parceiro")
	assert(totem.can_player_build("Parceiro"), "Parceiro na whitelist deve ter permissão no totem")
	var res_partner := zm.can_build_at(Vector3(42.0, 0.0, 40.0), &"piece", "Parceiro")
	assert(res_partner["allowed"], "Parceiro autorizado pelo ZoneManager deve poder construir")

	# 4. Remover parceiro
	totem.remove_allowed_builder("Parceiro")
	assert(not totem.can_player_build("Parceiro"), "Removido da whitelist não deve poder construir")

	# 5. Congelamento de construção quando VULNERABLE
	totem.maintenance_funds = 0
	totem.advance_days(0.1) # status -> VULNERABLE
	assert(totem.status == ClaimTotemClass.Status.VULNERABLE)
	var res_vuln := zm.can_build_at(Vector3(42.0, 0.0, 40.0), &"piece", "Tarciso6")
	assert(not res_vuln["allowed"], "Construção deve ser congelada enquanto o cofre estiver zerado (VULNERABLE)")

	# 6. Bloqueio quando ABANDONED (Ruína)
	totem.advance_days(5.0) # status -> ABANDONED
	assert(totem.status == ClaimTotemClass.Status.ABANDONED)
	var res_ruin := zm.can_build_at(Vector3(42.0, 0.0, 40.0), &"piece", "Tarciso6")
	assert(not res_ruin["allowed"], "Construção bloqueada em ruínas abandonadas")

	totem.free()
	zm.free()
	print("  ✓ Permissões, whitelist e bloqueio por status validados.")

func test_dismantle_ruins_public_salvage() -> void:
	print("\n[7/9] Desmanche público de ruínas e sucata de 25%...")
	var zm := ZoneManagerClass.new()
	root.add_child(zm)

	var bs := BuildingSystemClass.new()
	bs.zone_manager = zm
	root.add_child(bs)

	# Totem abandonado com uma parede
	var totem := ClaimTotemClass.new()
	totem.owner_name = "Abandonador"
	totem.position = Vector3(50.0, 0.0, 50.0)
	totem.maintenance_funds = 0
	totem.grace_days_elapsed = 4.0 # Ruína
	root.add_child(totem)
	totem._update_status()

	var piece := BuildablePieceClass.new()
	piece.piece_type = BuildablePieceClass.PieceType.PAREDE_MADEIRA
	piece.owner_name = "Abandonador"
	piece.position = Vector3(51.0, 0.0, 50.0)
	root.add_child(piece)

	# Jogador saqueador
	var scavenger := Node3D.new()
	scavenger.name = "Sucateiro"
	var inv := InventoryComponentClass.new()
	scavenger.add_child(inv)
	scavenger.set_meta("inventory", inv)
	root.add_child(scavenger)
	bs.player = scavenger

	# 1. Desmanchar peça de ruína abandonada (PAREDE_MADEIRA custa {madeira: 3, fibra: 1})
	# 25% de 3 = maxi(1, int(3 * 0.25)) = 1 madeira; 25% de 1 = 1 fibra
	var dismantled_piece := bs.try_dismantle_at(Vector3(51.0, 0.0, 50.0))
	assert(dismantled_piece, "Qualquer jogador deve poder desmontar peças em ruínas abandonadas")
	assert(inv.get_material_count(&"madeira") == 1, "Deve reembolsar 1 madeira da ruína")
	assert(inv.get_material_count(&"fibra") == 1, "Deve reembolsar 1 fibra da ruína")

	# 2. Desmanchar o próprio totem de território abandonado ({madeira: 4, pedra: 4})
	# 25% de 4 = 1 madeira, 1 pedra
	var dismantled_totem := bs.try_dismantle_at(Vector3(50.0, 0.0, 50.0))
	assert(dismantled_totem, "Qualquer jogador deve poder desmanchar totem abandonado sem estruturas dentro")
	assert(inv.get_material_count(&"madeira") == 2, "Total de madeira recolhida deve ser 1 + 1 = 2")
	assert(inv.get_material_count(&"pedra") == 1, "Total de pedra recolhida deve ser 1")

	bs.free()
	zm.free()
	scavenger.free()
	print("  ✓ Saque público de 25% em ruínas validado com sucesso.")

func test_structures_save_roundtrip() -> void:
	print("\n[8/9] Persistência de manutenção e dados do Totem...")
	var parent := Node3D.new()
	root.add_child(parent)

	var totem := ClaimTotemClass.new()
	totem.owner_name = "TarcisoSave"
	totem.position = Vector3(10.0, 0.0, 10.0)
	totem.maintenance_funds = 85
	totem.allowed_builders = ["Amigo1", "Amigo2"]
	parent.add_child(totem)
	totem._update_status()

	# Serializar estruturas
	var saved_list := BuildingSystemClass.collect_structures(self)
	assert(saved_list.size() >= 1, "Deve coletar o totem salvo")

	var entry: Dictionary = {}
	for s in saved_list:
		if s.get("kind") == "totem" and s.get("owner") == "TarcisoSave":
			entry = s
			break
	assert(not entry.is_empty(), "Entrada do totem deve estar presente")
	assert(entry.has("totem_data"), "Totem deve incluir dicionário totem_data")
	var t_data: Dictionary = entry["totem_data"]
	assert(t_data["maintenance_funds"] == 85, "Fundos salvos devem ser 85")
	assert(t_data["allowed_builders"].size() == 2, "Whitelist deve conter 2 membros")

	# Restaurar estruturas em novo parent
	totem.free()
	var new_parent := Node3D.new()
	root.add_child(new_parent)
	BuildingSystemClass.restore_structures(new_parent, [entry])

	var restored_totem: ClaimTotemClass = null
	for c in new_parent.get_children():
		if c is ClaimTotemClass:
			restored_totem = c as ClaimTotemClass
			break
	assert(restored_totem != null, "Totem deve ter sido restaurado com sucesso")
	assert(restored_totem.maintenance_funds == 85, "Fundos restaurados devem ser 85")
	assert(restored_totem.allowed_builders.has("Amigo1"), "Whitelist restaurada deve ter Amigo1")

	restored_totem.free()
	parent.free()
	new_parent.free()
	print("  ✓ Serialização e restauração do cofre territorial validadas.")

func test_territory_screen_ui() -> void:
	print("\n[9/9] Interface do Usuário (TerritoryScreen)...")
	var totem := ClaimTotemClass.new()
	totem.owner_name = "TarcisoUI"
	totem.maintenance_funds = 50
	root.add_child(totem)

	var player := Node3D.new()
	player.name = "TarcisoUI"
	var wallet := WalletComponentClass.new()
	wallet.money = 100
	player.add_child(wallet)
	player.set_meta("wallet", wallet)
	root.add_child(player)

	var screen := TerritoryScreenClass.new()
	root.add_child(screen)
	screen.open(totem, player)

	assert(screen.visible, "Tela deve estar visível após open()")
	assert(totem.maintenance_funds == 50, "Cofre exibido deve manter 50 $S")

	# Testar depósito via UI
	screen._deposit(25)
	assert(totem.maintenance_funds == 75, "Depósito via UI deve atualizar o totem")
	assert(wallet.money == 75, "Carteira deve debitar 25 $S")

	# Testar adição de amigo via UI
	screen._add_friend_edit.text = "NovoAmigo"
	screen._on_add_builder()
	assert(totem.allowed_builders.has("NovoAmigo"), "Adição de amigo via UI deve registrar no totem")

	screen.close()
	totem.free()
	player.free()
	print("  ✓ Interface TerritoryScreen validada.")
