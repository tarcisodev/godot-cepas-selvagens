extends SceneTree

## B38 / GDD-17 fase 1: Ficha do NPC. Perfil (horário, saudação por período, Conversar),
## [E] abre a Ficha com o NPC em 3D num mundo próprio, ações inline e com tela própria,
## ação cinza fora do horário ou sem requisito, fecha ao se afastar, e o Mestre de Armas
## da vila passa pela Ficha.

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const TrainerScene: PackedScene = preload("res://scenes/weapon_trainer.tscn")
const _NpcProfile = preload("res://scripts/npc/npc_profile.gd")
const _NpcAction = preload("res://scripts/npc/npc_action.gd")
const _NpcDialog = preload("res://scripts/ui/npc_dialog.gd")
const _TownNPC = preload("res://scripts/town/town_npc.gd")

var _started: bool = false

func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false

func _run() -> void:
	print("\n========================================================")
	print("⭐ TESTANDO A FICHA DO NPC (B38)")
	print("========================================================")
	test_profile_rules()
	var player: Player = PlayerScene.instantiate() as Player
	root.add_child(player)
	player._setup_components()
	player.set_physics_process(false)
	var sun := DayNightCycle.new()
	sun.is_paused = true
	root.add_child(sun)
	test_dialog_flow(player, sun)
	test_trainer_uses_dialog(player)
	print("\n🎉 TODOS OS TESTES DA FICHA DO NPC PASSARAM COM SUCESSO!")
	print("========================================================\n")
	quit(0)

func test_profile_rules() -> void:
	print("\n[1/3] Perfil: horário, saudação e Conversar...")
	var p := _NpcProfile.make(&"boticaria", "Nhá Sálvia", "Boticária", "⚗️", "Costela") \
		.hours(7.0, 19.0, "ela está na Estalagem") \
		.greet("manha", "Bom dia!") \
		.greet("noite", "Já é tarde.") \
		.greet("sempre", "Olá.") \
		.topic("Pergunta?", "Resposta.")
	assert(p.is_open_at(7.0) and p.is_open_at(18.9), "Aberta no horário")
	assert(not p.is_open_at(19.0) and not p.is_open_at(3.0), "Fechada fora do horário")
	assert(p.closed_reason(21.0).contains("abre às 7h") and p.closed_reason(21.0).contains("Estalagem"), "Motivo diz quando abre e onde ela está")
	assert(p.closed_reason(10.0) == "", "Sem motivo quando aberta")
	var night := _NpcProfile.make(&"mascate", "Mascate", "Feira do Ventre", "🌙").hours(20.0, 4.0)
	assert(night.is_open_at(23.0) and night.is_open_at(2.0) and not night.is_open_at(12.0), "Horário que atravessa a meia-noite")
	assert(_NpcProfile.make(&"guarda", "Guarda", "", "🛡️").is_open_at(3.0), "Sem horário atende 24 h")
	assert(p.greeting_at(8.0) == "Bom dia!" and p.greeting_at(22.0) == "Já é tarde.", "Saudação pelo período")
	assert(p.greeting_at(14.0) == "Olá.", "Período sem fala usa 'sempre'")
	var list := p.all_actions()
	assert(list.size() == 1 and list[0].kind == _NpcAction.Kind.TALK and not list[0].needs_open, "Assuntos viram Conversar, que vale fora do horário")
	print("  ✓ Perfil validado")

func test_dialog_flow(player: Player, sun: DayNightCycle) -> void:
	print("\n[2/3] [E] abre a Ficha com retrato 3D e ações...")
	var bought: Array = []
	var has_coin := [false]
	var npc = _TownNPC.new()
	npc.name = "Boticaria"
	npc.snap_to_ground = false
	npc.dna = CharacterDNA.randomized(42)
	root.add_child(npc)
	npc.profile = _NpcProfile.make(&"boticaria", "Nhá Sálvia", "Boticária", "⚗️", "Costela") \
		.hours(7.0, 19.0) \
		.greet("sempre", "Olá, caçador.") \
		.add(_NpcAction.make(&"comprar", _NpcAction.Kind.BUY, "Comprar", func(p): bought.append(p))) \
		.add(_NpcAction.make(&"vip", _NpcAction.Kind.SERVICE, "Sala dos fundos", func(_p): pass) \
			.with_check(func(_p): return "" if has_coin[0] else "Precisa de 1 $S")) \
		.topic("Quem é você?", "A boticária da Costela.")
	assert(npc.is_in_group("talkable"), "Perfil depois do _ready ainda deixa o NPC falável")
	player.global_position = Vector3(1.5, 0.0, 0.0)
	sun.current_time_hours = 10.0

	npc.talk_to(player)
	var dialog := _NpcDialog.instance
	assert(dialog != null and dialog.is_open() and dialog.is_in_group("open_menus"), "Ficha abre e trava o combate")
	assert(dialog.profile == npc.profile, "Ficha mostra o perfil do NPC")
	assert(dialog.portrait != null and dialog.portrait.dna == npc.visual.dna, "Retrato usa o mesmo corpo do NPC")
	assert(dialog._viewport.own_world_3d and dialog.portrait.get_viewport() == dialog._viewport, "Retrato vive num mundo 3D próprio")
	assert(dialog._name_label.text.contains("Nhá Sálvia") and dialog._title_label.text.contains("Boticária"), "Nome e papel ao lado")
	assert(dialog._status_label.text.contains("ABERTO"), "Status aberto às 10h")
	assert(dialog._speech_label.text.contains("Olá, caçador."), "Saudação no balão")
	assert(dialog._buttons.size() == 3, "Comprar, Sala dos fundos e Conversar")
	assert(not dialog._buttons[0].disabled and dialog._buttons[1].disabled, "Ação com requisito aparece cinza")
	assert(not dialog.choose(1), "Ação cinza não roda")
	assert(dialog._speech_label.text.contains("Precisa de 1 $S"), "O NPC diz o motivo")

	assert(dialog.choose(2) and dialog.current_action != null, "Conversar abre dentro da Ficha")
	assert(dialog.is_open() and dialog._buttons.size() == 1, "Um botão por assunto")
	dialog._buttons[0].pressed.emit()
	assert(dialog._speech_label.text.contains("A boticária da Costela."), "Resposta no balão")
	dialog.back()
	assert(dialog.current_action == null and dialog._buttons.size() == 3, "Voltar para a lista")

	sun.current_time_hours = 21.0
	dialog.refresh()
	assert(dialog._status_label.text.contains("FECHADO") and dialog._buttons[0].disabled, "Fora do horário a loja fica cinza")
	assert(not dialog._buttons[2].disabled, "Conversar continua fora do horário")
	sun.current_time_hours = 10.0
	dialog.refresh()
	assert(dialog.choose(0), "Comprar roda no horário")
	assert(bought.size() == 1 and bought[0] == player, "Handler recebe o jogador")
	assert(not dialog.is_open() and not dialog.is_in_group("open_menus"), "Ação com tela própria fecha a Ficha")

	npc.talk_to(player)
	player.global_position = Vector3(10.0, 0.0, 0.0)
	dialog._process(0.016)
	assert(not dialog.is_open(), "Afastar-se fecha a Ficha (o mundo não para)")
	npc.free()
	print("  ✓ Ficha validada")

func test_trainer_uses_dialog(player: Player) -> void:
	print("\n[3/3] Mestre de Armas da vila passa pela Ficha...")
	var trainer: WeaponTrainer = TrainerScene.instantiate() as WeaponTrainer
	root.add_child(trainer)
	player.global_position = trainer.global_position + Vector3(1.0, 0.0, 0.0)
	trainer.talk_to(player)
	var dialog := _NpcDialog.instance
	assert(dialog.is_open() and dialog.profile == trainer.profile, "[E] abre a Ficha do Mestre de Armas")
	assert(not trainer.is_open, "Menu de estilos ainda fechado")
	assert(dialog.choose(0), "Armas de treino")
	assert(not dialog.is_open() and trainer.is_open, "Ficha fecha e abre o menu de estilos")
	trainer.free()
	print("  ✓ Mestre de Armas validado")
