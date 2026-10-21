extends SceneTree

## Valida o Barbeiro (B09): editor de aparência, gênero, cabelo/barba longos e aparência no save.

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const StylistScene: PackedScene = preload("res://scenes/character_stylist.tscn")
const SaveGameScript: GDScript = preload("res://scripts/core/save_game.gd")

var _failures := 0
var _frames := 0
var _player: Player
var _stylist: CharacterStylist

func _init() -> void:
	print("\n========================================================")
	print("✂ VALIDANDO BARBEIRO E EDITOR DE APARÊNCIA (B09)")
	print("========================================================")

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error("FALHOU: " + message)

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 1:
		_player = PlayerScene.instantiate()
		root.add_child(_player)
		_stylist = StylistScene.instantiate()
		_stylist.save_on_apply = false
		_stylist.position = Vector3(1.5, 0.0, 0.0)
		root.add_child(_stylist)
		return false
	if _frames == 2:
		test_long_hair_and_beard()
		test_editor_flow()
		test_appearance_in_save()
		if _failures == 0:
			print("\n🎉 BARBEIRO VALIDADO COM 100% DE SUCESSO!")
		else:
			print("\n❌ %d verificação(ões) falharam" % _failures)
		print("========================================================\n")
		quit(1 if _failures > 0 else 0)
		return true
	return false

func test_long_hair_and_beard() -> void:
	print("\n[1/3] Cabelo e barba compridos...")
	var rig: PackedScene = _player.character_visual.animation_sources[0]
	var short := CharacterDNA.randomized(5)
	short.hair_style = CharacterDNA.HairStyle.LONG
	short.hair_length = 0.0
	short.beard = CharacterDNA.Beard.FULL
	short.beard_length = 0.0
	var long := short.duplicate() as CharacterDNA
	long.hair_length = 1.0
	long.beard_length = 1.0
	var mane := long.duplicate() as CharacterDNA
	mane.hair_style = CharacterDNA.HairStyle.MANE
	_check(_vertex_count(short, rig) < _vertex_count(long, rig), "cabelo/barba longos devem gerar mais malha (mechas e barba pendente)")
	_check(_vertex_count(mane, rig) > 0, "juba deve montar")
	# A barba comprida desce abaixo do queixo
	_check(_lowest_hair_y(long, rig) < _lowest_hair_y(short, rig) - 0.1, "comprimento deve baixar a ponta do cabelo")
	print("  ✓ comprimento de cabelo e barba funcionando")

func test_editor_flow() -> void:
	print("\n[2/3] Editor: abrir, trocar gênero, cabelo, barba e aplicar...")
	var before: CharacterDNA = _player.character_visual.dna
	_stylist.talk_to(_player)
	_check(_stylist.is_open, "editor deve abrir com [E]")
	_check(_stylist._draft != before, "editor deve trabalhar numa cópia do DNA")
	_stylist.set_gender(true)
	_check(_stylist._draft.femininity >= 0.5, "botão Feminino deve mudar os traços")
	_check(_stylist._female_button.button_pressed and not _stylist._male_button.button_pressed, "botões de gênero devem refletir a escolha")
	_stylist._set_prop(CharacterDNA.HairStyle.MANE, "hair_style")
	_stylist._set_prop(1.0, "hair_length")
	_stylist._set_prop(CharacterDNA.Beard.FULL, "beard")
	_stylist._set_prop(0.8, "beard_length")
	_check(before.hair_style != CharacterDNA.HairStyle.MANE or before.beard_length != 0.8, "editar não deve mexer no DNA do player antes de aplicar")
	_stylist.apply()
	var after: CharacterDNA = _player.character_visual.dna
	_check(not _stylist.is_open, "aplicar deve fechar o editor")
	_check(after.femininity >= 0.5 and after.hair_style == CharacterDNA.HairStyle.MANE and after.beard == CharacterDNA.Beard.FULL,
		"player deve ficar com o visual escolhido (feminino, juba e barba cheia)")
	_check(after != _stylist._draft, "player deve receber uma cópia, não o rascunho")
	_check(_player.character_visual.has(&"Walk"), "player remontado deve continuar animado")
	_stylist.talk_to(_player)
	_stylist.set_gender(false)
	_stylist.close_editor()
	_check(_player.character_visual.dna.femininity >= 0.5, "cancelar não deve aplicar nada")
	print("  ✓ fluxo do editor validado")

func test_appearance_in_save() -> void:
	print("\n[3/3] Aparência no save...")
	var save_game: Node = SaveGameScript.new()
	var data: Dictionary = save_game.collect(_player)
	_check(data.has("appearance"), "save deve guardar a aparência")
	# Passa pelo JSON de verdade: números voltam como float
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(data))
	_player.character_visual.rebuild(CharacterDNA.randomized(99))
	save_game.apply_save(_player, parsed)
	var restored: CharacterDNA = _player.character_visual.dna
	_check(restored.hair_style == CharacterDNA.HairStyle.MANE and restored.beard == CharacterDNA.Beard.FULL, "save deve devolver cabelo e barba")
	_check(restored.to_dict() == CharacterDNA.from_dict(data["appearance"]).to_dict(), "aparência do save deve voltar idêntica")
	save_game.free()
	print("  ✓ aparência salva e restaurada")

func _vertex_count(dna: CharacterDNA, rig: PackedScene) -> int:
	var model := ProceduralCharacterBuilder.build(dna, rig)
	var count: int = (model.find_child("Body", true, false) as MeshInstance3D).mesh.surface_get_array_len(0)
	model.free()
	return count

## Altura mais baixa entre os vértices com a cor do cabelo.
func _lowest_hair_y(dna: CharacterDNA, rig: PackedScene) -> float:
	var model := ProceduralCharacterBuilder.build(dna, rig)
	var arrays := (model.find_child("Body", true, false) as MeshInstance3D).mesh.surface_get_arrays(0)
	model.free()
	var lowest := INF
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	for i in verts.size():
		# A cor do vértice volta em 8 bits por canal.
		var c := colors[i]
		if absf(c.r - dna.hair_color.r) + absf(c.g - dna.hair_color.g) + absf(c.b - dna.hair_color.b) < 0.02:
			lowest = minf(lowest, verts[i].y)
	return lowest
