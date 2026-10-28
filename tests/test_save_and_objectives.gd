extends SceneTree

## Valida o save do MVP (SaveGame) e os objetivos (Objectives) sem tocar no save do disco:
# coleta do player → JSON (como no arquivo) → aplica num player novo → confere tudo.

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")

func _initialize() -> void:
	# Em _initialize os autoloads (SaveGame, Objectives) já estão na árvore; em _init ainda não
	print("\n========================================================")
	print("💾 VALIDANDO SAVE E OBJETIVOS DO MVP")
	print("========================================================")
	test_save_roundtrip()
	test_objectives_state()
	test_album_objective_check()
	print("\n🎉 SAVE E OBJETIVOS VALIDADOS COM SUCESSO!")
	print("========================================================\n")
	quit(0)

func test_save_roundtrip() -> void:
	print("\n[1/2] Coleta, JSON e restauração do progresso...")
	var save_game: Node = root.get_node("SaveGame")
	var objectives: Node = root.get_node("Objectives")
	objectives.reset()

	var p1: Player = PlayerScene.instantiate() as Player
	root.add_child(p1)
	p1._setup_components()
	p1.inventory.add_material(&"chifre_rinolito", 1, 3, [&"integro"])
	assert(p1.inventory.craft_and_equip_horn_helmet(), "Forja do elmo para o teste")
	p1.inventory.add_material(&"madeira", 4, 2)
	p1.inventory.add_material(&"tendao_elastico", 3)
	p1.mastery.add_xp(&"esfola", 500.0)
	p1.card_collection.unlock_card(&"beast_horn")
	objectives.complete(&"find")
	objectives.complete(&"break")
	var poise_with_helmet: float = p1.stats.get_stat(&"poise_resist")
	var esfola_level: int = p1.mastery.get_level(&"esfola")
	var esfola_xp: float = p1.mastery.get_xp(&"esfola")
	p1.position = Vector3(3.0, 1.5, -2.0)

	var data: Dictionary = save_game.collect(p1)
	var from_disk: Dictionary = JSON.parse_string(JSON.stringify(data))
	assert(from_disk.get("version") == 1, "Save tem versão")

	objectives.reset()
	var p2: Player = PlayerScene.instantiate() as Player
	root.add_child(p2)
	p2._setup_components()
	save_game.apply_save(p2, from_disk)

	assert(p2.inventory.get_material_count(&"tendao_elastico") == 3, "Materiais restaurados")
	assert(p2.inventory.get_material_count(&"chifre_rinolito") == 0, "Restaurar o elmo não deixa chifre sobrando")
	assert(p2.inventory.get_stacks(&"madeira").size() == 1 and p2.inventory.get_stacks(&"madeira")[0].quality == 2, "Qualidade das pilhas sobrevive ao save")
	assert(p2.inventory.equipped[&"head"] == &"Elmo Chifre-de-Pedra (Íntegro)", "Elmo equipado restaurado")
	assert(is_equal_approx(p2.stats.get_stat(&"poise_resist"), poise_with_helmet), "Modificadores do elmo reaplicados")
	assert(p2.mastery.get_level(&"esfola") == esfola_level, "Nível de maestria restaurado (sem XP extra da forja)")
	assert(is_equal_approx(p2.mastery.get_xp(&"esfola"), esfola_xp), "XP de maestria restaurado")
	assert(p2.card_collection.is_card_unlocked(&"beast_horn"), "Cartas restauradas")
	assert(p2.position.distance_to(Vector3(3.0, 1.7, -2.0)) < 0.01, "Posição restaurada (um pouco acima do chão)")
	assert(objectives.is_done(&"find") and objectives.is_done(&"break"), "Objetivos restaurados")
	assert(not objectives.is_done(&"harvest"), "Objetivo não cumprido continua aberto")

	p1.free()
	p2.free()
	print("  ✓ Progresso volta igual depois de passar pelo JSON")

func test_objectives_state() -> void:
	print("\n[2/2] Ordem e conclusão dos objetivos...")
	var objectives: Node = root.get_node("Objectives")
	objectives.reset()
	var completed: Array = []
	objectives.objective_completed.connect(func(id): completed.append(id))
	var finished := [false]
	objectives.all_completed.connect(func(): finished[0] = true)
	for step in objectives.STEPS:
		objectives.complete(step.id)
	objectives.complete(&"find") # repetir não dispara de novo
	assert(completed.size() == objectives.STEPS.size(), "Cada objetivo conclui uma vez só")
	assert(finished[0], "Concluir todos avisa o fim da caçada")
	assert(objectives.get_state().size() == objectives.STEPS.size(), "Estado salvável lista todos")
	objectives.reset()
	print("  ✓ Objetivos concluem em ordem, sem repetir")

func test_album_objective_check() -> void:
	print("\n[3/3] Conclusão do objetivo album ao abrir o CardAlbum...")
	var objectives: Node = root.get_node("Objectives")
	objectives.reset()
	objectives.complete(&"find")
	objectives.complete(&"break")
	objectives.complete(&"harvest")
	objectives.complete(&"forge")
	assert(not objectives.is_done(&"album"), "Album começa não concluído")

	var album := CanvasLayer.new()
	album.name = "CardAlbum"
	album.add_to_group("card_album")
	album.visible = false
	root.add_child(album)

	var p := PlayerScene.instantiate() as Player
	root.add_child(p)
	p._setup_components()

	objectives._check(p)
	assert(not objectives.is_done(&"album"), "Com álbum fechado, não conclui")

	album.visible = true
	objectives._check(p)
	assert(objectives.is_done(&"album"), "Com álbum visível, objetivo conclui!")
	assert(objectives.done.size() == objectives.STEPS.size(), "Todos os 5 objetivos concluídos")

	p.free()
	album.free()
	objectives.reset()
	print("  ✓ Objetivo do álbum conclui com CardAlbum visível")
