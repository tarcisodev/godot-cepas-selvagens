extends SceneTree

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const DummyScene: PackedScene = preload("res://scenes/dummy_creature.tscn")
const Card3DScene: PackedScene = preload("res://scenes/card_3d.tscn")
const CardAlbumScene: PackedScene = preload("res://scenes/card_album.tscn")

func _init() -> void:
	print("\n========================================================")
	print("🃏 VALIDANDO COLEÇÃO DE CARTAS 3D E MINI-GAME (B08)")
	print("Catálogo, Modelos 3D, Inspeção com Tilt/Flip e Recompensas")
	print("========================================================")
	
	test_card_data_and_database()
	test_card_collection_component()
	test_combat_reward_unlock()
	test_card_3d_inspection_and_flip()
	test_card_album_ui()
	
	print("\n🎉 SISTEMA DE CARTAS 3D VALIDADO COM 100% DE SUCESSO!")
	print("========================================================\n")
	quit(0)

func test_card_data_and_database() -> void:
	print("\n[1/5] Testando CardData e CardDatabase...")
	var total: int = CardDatabase.get_total_count()
	assert(total >= 8, "Database deve conter pelo menos 8 cartas registradas")
	
	var earth_card: CardData = CardDatabase.get_card(&"element_earth")
	assert(earth_card != null, "Carta 'element_earth' deve existir")
	assert(earth_card.title == "Elemento Terra", "Título deve ser 'Elemento Terra'")
	assert(earth_card.element == CardData.CardElement.EARTH, "Elemento deve ser Terra")
	assert(earth_card.ether_cost == 2, "Custo de Éter deve ser 2")
	assert(earth_card.power == 3, "Poder deve ser 3")
	assert(earth_card.poise == 7, "Postura deve ser 7")
	assert(not earth_card.trait_name.is_empty(), "Deve conter trait de mini-game")
	assert(ResourceLoader.exists(earth_card.model_path), "Caminho do modelo 3D deve ser válido")
	assert(ResourceLoader.exists(earth_card.render_path), "Caminho da render 2D deve ser válido")
	
	# Cores e raridade
	assert(earth_card.get_rarity_name() == "Incomum", "Raridade deve ser Incomum")
	assert(earth_card.get_rarity_color() != Color.BLACK, "Cor de raridade deve ser válida")
	assert(earth_card.get_element_color() != Color.BLACK, "Cor de elemento deve ser válida")
	
	# Filtro por categoria
	var bestiary_cards = CardDatabase.get_cards_by_category("Bestiário")
	assert(bestiary_cards.size() >= 2, "Deve conter pelo menos 2 cartas de Bestiário")
	
	print("  ✓ CardData, atributos de mini-game e CardDatabase validados!")

func test_card_collection_component() -> void:
	print("\n[2/5] Testando CardCollectionComponent...")
	var collection := CardCollectionComponent.new()
	root.add_child(collection)
	
	# Cartas iniciais do andarilho
	assert(collection.is_card_unlocked(&"element_earth"), "Andarilho deve iniciar com Elemento Terra")
	assert(collection.is_card_unlocked(&"coin"), "Andarilho deve iniciar com Moeda Clandestina")
	assert(collection.is_card_unlocked(&"trenchcoat_mushrooms"), "Andarilho deve iniciar com Cogumelos de Sobretudo")
	assert(not collection.is_card_unlocked(&"beast_horn"), "Besta Chifre-de-Pedra não deve estar liberada no início")
	
	# Desbloqueio de nova carta
	var signal_received: Array[bool] = [false]
	collection.card_unlocked.connect(func(card: CardData):
		signal_received[0] = true
		assert(card.id == &"beast_horn", "Sinal deve passar a carta correta")
	)
	
	var ok := collection.unlock_card(&"beast_horn")
	assert(ok, "Deve destrancar com sucesso carta inédita")
	assert(signal_received[0], "Sinal card_unlocked deve ser emitido")
	assert(collection.is_card_unlocked(&"beast_horn"), "Besta Chifre-de-Pedra agora deve estar destrancada")
	
	# Tentativa de desbloqueio duplicado
	var duplicate_ok := collection.unlock_card(&"beast_horn")
	assert(not duplicate_ok, "Não deve destrancar duplicata")
	
	# Progresso da coleção
	var progress = collection.get_progress()
	assert(progress["unlocked"] == 4, "Devem haver 4 cartas destrancadas")
	assert(progress["total"] >= 8, "Total deve refletir o banco")
	assert(progress["percent"] > 0.0, "Percentual deve ser maior que 0")
	
	collection.free()
	print("  ✓ Componente de coleção, sinais e progresso validados!")

func test_combat_reward_unlock() -> void:
	print("\n[3/5] Testando desbloqueio contextual de cartas via combate (quebra e abate)...")
	var player: Player = PlayerScene.instantiate() as Player
	player.name = "Player"
	root.add_child(player)
	player._setup_components()
	
	var dummy: DummyCreature = DummyScene.instantiate() as DummyCreature
	dummy.name = "DummyCreature"
	root.add_child(dummy)
	dummy._setup_components()
	
	var cards: CardCollectionComponent = player.card_collection
	assert(cards != null, "Player deve possuir CardCollectionComponent")
	assert(not cards.is_card_unlocked(&"beast_horn"), "Carta do Chifre não deve estar destrancada antes do combate")
	
	# 1. Quebra do chifre da besta em combate -> destranca carta lendária da Besta Chifre-de-Pedra
	dummy.anatomy.damage_part(&"horn", 55.0)
	assert(dummy.anatomy.is_part_broken(&"horn"), "Chifre deve ter quebrado")
	assert(cards.is_card_unlocked(&"beast_horn"), "Carta Besta Chifre-de-Pedra deve ter sido desbloqueada pela quebra anatômica!")
	
	# 2. Abate cuidadoso com chifre intacto em uma segunda besta -> destranca Polinização Arcana
	var dummy2: DummyCreature = DummyScene.instantiate() as DummyCreature
	root.add_child(dummy2)
	dummy2._setup_components()
	
	assert(not cards.is_card_unlocked(&"polinization"), "Polinização não deve estar destrancada antes")
	dummy2._on_health_depleted()
	assert(cards.is_card_unlocked(&"polinization"), "Carta Polinização Arcana deve ter sido desbloqueada pelo abate cuidadoso!")
	
	dummy.free()
	dummy2.free()
	player.free()
	print("  ✓ Desbloqueio contextual por quebra anatômica e abate verificado com louvor!")

func test_card_3d_inspection_and_flip() -> void:
	print("\n[4/5] Testando cena 3D Card, iluminação e flip 180°...")
	var card_3d: Card3D = Card3DScene.instantiate() as Card3D
	root.add_child(card_3d)
	card_3d._ready()
	
	# Validação da hierarquia 3D
	assert(card_3d.container_anchor.get_child_count() > 0, "Deve instanciar a moldura Container da carta")
	assert(card_3d.front_anchor.get_child_count() > 0, "Deve instanciar a face frontal")
	assert(card_3d.back_anchor.get_child_count() > 0, "Deve instanciar a face traseira")
	
	# Exibição de carta
	var earth_card: CardData = CardDatabase.get_card(&"element_earth")
	card_3d.display_card(earth_card)
	assert(card_3d.diorama_anchor.get_child_count() > 0, "Deve instanciar o modelo 3D interno do diorama da carta")
	assert(card_3d.rim_light.light_color == earth_card.get_rarity_color(), "Luz deve refletir a cor da raridade")
	
	# Teste de tilt com cursor normalizado
	card_3d.set_tilt_normalized(Vector2(0.5, -0.5))
	assert(card_3d._target_tilt_x != 0.0 and card_3d._target_tilt_y != 0.0, "Alvos de tilt devem ser calculados")
	
	# Teste de Flip (Giro 180°)
	assert(card_3d.is_front_facing(), "Carta deve iniciar virada para a frente")
	card_3d.toggle_flip()
	assert(card_3d.is_flipped, "Carta deve alternar para verso")
	assert(is_equal_approx(card_3d._target_flip_angle, PI), "Ângulo de giro alvo deve ser PI (180°)")
	assert(not card_3d.is_front_facing(), "Face frontal não deve mais ser a visível")
	
	card_3d.toggle_flip()
	assert(!card_3d.is_flipped, "Carta deve retornar à face frontal")
	assert(is_equal_approx(card_3d._target_flip_angle, 0.0), "Ângulo alvo deve ser 0")
	
	# Teste de órbita 3D manual com arrasto de mouse
	card_3d.add_manual_orbit(15.0, 10.0)
	assert(card_3d._manual_yaw != 0.0, "Yaw manual deve ser modificado pelo arrasto")
	
	card_3d.reset_orientation()
	assert(is_equal_approx(card_3d._manual_yaw, 0.0), "Reset deve zerar yaw manual")
	
	card_3d.free()
	print("  ✓ Modelo 3D, diorama, iluminação de raridade, tilt e flip validados!")

func test_card_album_ui() -> void:
	print("\n[5/5] Testando Interface do Álbum (grade, filtro por categoria e seleção 3D)...")
	var album: CardAlbum = CardAlbumScene.instantiate() as CardAlbum
	root.add_child(album)
	
	# Criando componente de coleção para alimentar o álbum
	var collection := CardCollectionComponent.new()
	root.add_child(collection)
	album.collection_component = collection
	
	# Abertura do álbum
	album.open_album()
	assert(album.visible, "Álbum deve ficar visível ao ser aberto")
	assert(album.cards_grid.get_child_count() >= 8, "Grade deve conter botões para todas as cartas cadastradas")
	
	# Seleção de carta
	var earth_card: CardData = CardDatabase.get_card(&"element_earth")
	album.select_card(earth_card)
	assert(album._selected_card == earth_card, "Carta selecionada deve ser Elemento Terra")
	assert(album.card_title_label.text == "Elemento Terra", "Título no painel deve refletir a carta")
	assert(album.card_stats_label.text.contains("⚡ Éter: 2"), "Stats de mini-game devem aparecer no painel")
	assert(album.card_trait_label.text.contains("Resonância Telúrica"), "Trait tático deve aparecer no painel")
	
	# Filtro por categoria
	album._on_filter_button_pressed("Magia")
	assert(album._current_filter == "Magia", "Filtro ativo deve ser Magia")
	var magic_count: int = album.cards_grid.get_child_count()
	assert(magic_count < CardDatabase.get_total_count(), "Grade filtrada deve conter menos cartas que o total")
	assert(magic_count >= 2, "Devem haver cartas de magia listadas")
	
	# Fechamento do álbum
	album.close_album()
	assert(!album.visible, "Álbum deve ficar oculto ao fechar")
	
	collection.free()
	album.free()
	print("  ✓ Grade do álbum, painel de stats de mini-game e filtro por categoria validados!")
