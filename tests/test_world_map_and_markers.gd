extends SceneTree

## B21 / GDD-11:
## Teste da Carta Cartográfica do Vale (WorldMapScreen [M]),
## MapImageBaker (Textura de Pergaminho 512x512) e Marcadores Pessoais.

const _WorldMapScreen = preload("res://scripts/ui/world_map_screen.gd")
const _MapImageBaker = preload("res://scripts/systems/map_image_baker.gd")
const _PoolsComponent = preload("res://scripts/components/pools_component.gd")

var _started := false

func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false

func _run() -> void:
	print("\n========================================================")
	print("🗺️ TESTANDO CARTA DO VALE, IMAGE BAKER & MARCADORES (B21)")
	print("========================================================")
	test_map_image_baker()
	test_world_map_open_close_and_zoom()
	test_personal_markers_crud_and_limit()
	test_active_marker_compass_guidance()
	test_damage_closes_map()
	print("\n🎉 TODOS OS TESTES DA CARTA DO VALE E MARCADORES PASSARAM COM SUCESSO!")
	print("========================================================\n")
	quit(0)

func test_map_image_baker() -> void:
	print("\n[1/5] MapImageBaker: geração procedural de textura de pergaminho 512x512...")
	var tex := _MapImageBaker.get_or_bake_map(null)
	assert(tex != null, "Textura gerada com sucesso")
	assert(tex.get_width() == _MapImageBaker.MAP_RESOLUTION, "Largura é 512 px")
	assert(tex.get_height() == _MapImageBaker.MAP_RESOLUTION, "Altura é 512 px")

	var img := tex.get_image()
	assert(img != null, "Imagem acessível")

	# Verifica se os pixels do rio têm componente azul dominante
	# O leito do rio no Z=0 fica perto de X=15
	var px_river := int((15.0 + WorldBounds.HALF) / (WorldBounds.HALF * 2.0) * float(_MapImageBaker.MAP_RESOLUTION))
	var py_river := int((0.0 + WorldBounds.HALF) / (WorldBounds.HALF * 2.0) * float(_MapImageBaker.MAP_RESOLUTION))
	var col_river := img.get_pixel(px_river, py_river)
	assert(col_river.b > col_river.r, "Área do rio possui tonalidade azulada de tinta cartográfica")

func test_world_map_open_close_and_zoom() -> void:
	print("\n[2/5] WorldMapScreen: abertura, fechamento e controle de zoom 1× a 4×...")
	var map_screen := _WorldMapScreen.new()
	root.add_child(map_screen)

	var p_mock := Node3D.new()
	p_mock.position = Vector3(25.0, 1.5, -40.0)
	root.add_child(p_mock)

	assert(not map_screen.is_open, "Mapa inicia fechado")
	assert(not map_screen.visible, "Mapa inicia invisível")

	# Abre o mapa
	map_screen.open_map(p_mock)
	assert(map_screen.is_open, "Mapa está aberto")
	assert(map_screen.visible, "Mapa está visível")

	# Zoom
	map_screen.set_zoom_level(2.5)
	assert(is_equal_approx(map_screen.zoom, 2.5), "Zoom atualizado para 2.5×")

	map_screen.set_zoom_level(5.0)
	assert(is_equal_approx(map_screen.zoom, 4.0), "Zoom limitado no máximo em 4.0×")

	map_screen.set_zoom_level(0.2)
	assert(is_equal_approx(map_screen.zoom, 1.0), "Zoom limitado no mínimo em 1.0×")

	# Centralizar no jogador (com zoom, já que em 1× o mapa inteiro cabe na moldura)
	map_screen.set_zoom_level(2.5)
	map_screen.center_on_player()
	assert(map_screen.pan_offset != Vector2.ZERO, "Pan ajustado para centralizar no jogador")

	# Fecha o mapa
	map_screen.close_map()
	assert(not map_screen.is_open, "Mapa foi fechado")
	assert(not map_screen.visible, "Mapa ficou invisível")

	p_mock.queue_free()
	map_screen.queue_free()

func test_personal_markers_crud_and_limit() -> void:
	print("\n[3/5] Marcadores Pessoais: adição, limite estrito de 20 e exclusão...")
	var map_screen := _WorldMapScreen.new()
	root.add_child(map_screen)

	# Adiciona marcadores até o limite
	for i in _WorldMapScreen.MAX_PERSONAL_MARKERS:
		var ok := map_screen.add_marker(Vector2(float(i * 10), float(i * 5)), "🚩", "Marco %d" % i)
		assert(ok, "Marcador %d adicionado com sucesso" % i)

	assert(map_screen.personal_markers.size() == 20, "Possui exatamente 20 marcadores")

	# Tentar adicionar o 21º deve ser recusado
	var ok_overflow := map_screen.add_marker(Vector2(100.0, 100.0), "⭐", "Excedente")
	assert(not ok_overflow, "21º marcador recusado pelo limite de 20")
	assert(map_screen.personal_markers.size() == 20, "Mantém 20 marcadores")

	# Remover marcador próximo à posição
	var removed := map_screen.remove_marker_near(Vector2(0.0, 0.0), 2.0)
	assert(removed, "Marcador na origem removido")
	assert(map_screen.personal_markers.size() == 19, "Total reduziu para 19 marcadores")

	# Serialização save/load
	var saved_data: Array = map_screen.get_markers_data()
	assert(saved_data.size() == 19, "Array de save contém 19 marcadores")

	var map_restore := _WorldMapScreen.new()
	map_restore.load_markers_data(saved_data)
	assert(map_restore.personal_markers.size() == 19, "19 marcadores restaurados com sucesso")

	map_screen.queue_free()
	map_restore.queue_free()

func test_active_marker_compass_guidance() -> void:
	print("\n[4/5] Marcador Ativo: seleção para guia na bússola do HUD...")
	var map_screen := _WorldMapScreen.new()
	root.add_child(map_screen)

	map_screen.add_marker(Vector2(50.0, -80.0), "💀", "Covil do Boss")
	map_screen.add_marker(Vector2(-30.0, 45.0), "🐟", "Pesca Rara")

	assert(map_screen.active_marker_idx == -1, "Nenhum marcador ativo inicialmente")

	# Define marcador 1 como ativo
	map_screen.set_active_marker(1)
	assert(map_screen.active_marker_idx == 1, "Marcador 1 ativo")

	# Desativa marcador
	map_screen.set_active_marker(-1)
	assert(map_screen.active_marker_idx == -1, "Marcador desativado")

	map_screen.queue_free()

func test_damage_closes_map() -> void:
	print("\n[5/5] GDD-11 §2: Tomar dano fecha o mapa imediatamente...")
	var map_screen := _WorldMapScreen.new()
	root.add_child(map_screen)

	var p_mock := Node3D.new()
	var pools := _PoolsComponent.new()
	pools.name = "PoolsComponent"
	pools.current_health = 100.0
	p_mock.add_child(pools)
	root.add_child(p_mock)

	map_screen.open_map(p_mock)
	assert(map_screen.is_open, "Mapa aberto enquanto o jogador explora")

	# Simula dano sofrido
	pools.current_health = 75.0
	map_screen._check_player_damage()

	assert(not map_screen.is_open, "Tomar dano fechou o mapa imediatamente!")
	assert(not map_screen.visible, "Mapa ficou invisível após o dano")

	p_mock.queue_free()
	map_screen.queue_free()
