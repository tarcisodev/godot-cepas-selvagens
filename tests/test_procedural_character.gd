extends SceneTree

## Valida o gerador procedural de personagens (B09): DNA determinístico, rig, pesos e animação.

const RIG: PackedScene = preload("res://assets/models/character/animations/UAL1_Standard.glb")

var _failures := 0
var _frames := 0
var _long: CharacterVisual
var _short: CharacterVisual
## Altura da ponta do pé lida logo após a correção da pelve (o Godot restaura a pose depois do frame).
var _toe_y := {}

func _init() -> void:
	print("\n========================================================")
	print("🧬 VALIDANDO GERADOR PROCEDURAL DE PERSONAGENS (B09)")
	print("========================================================")
	test_dna()
	test_builder()

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error("FALHOU: " + message)

func test_dna() -> void:
	print("\n[1/3] CharacterDNA: seed determinística e serialização...")
	var a := CharacterDNA.randomized(42)
	var b := CharacterDNA.randomized(42)
	var c := CharacterDNA.randomized(43)
	_check(a.to_dict() == b.to_dict(), "a mesma seed deve gerar o mesmo DNA")
	_check(a.to_dict() != c.to_dict(), "seeds diferentes devem gerar DNAs diferentes")
	var copy := CharacterDNA.from_dict(a.to_dict())
	_check(copy.to_dict() == a.to_dict(), "from_dict(to_dict()) deve devolver o mesmo DNA")
	_check(copy.shirt_color.to_html() == a.shirt_color.to_html(), "cores devem sobreviver à serialização (8 bits por canal)")
	var styles := {}
	for i in 200:
		styles[CharacterDNA.randomized(i).hair_style] = true
	_check(styles.size() == CharacterDNA.HairStyle.size(), "200 seeds devem cobrir todos os cabelos")
	print("  ✓ DNA validado")

func test_builder() -> void:
	print("\n[2/3] ProceduralCharacterBuilder: esqueleto, malha e pesos...")
	for i in 30:
		var model := ProceduralCharacterBuilder.build(CharacterDNA.randomized(i), RIG)
		var skeleton := model.find_child("Skeleton3D", true, false) as Skeleton3D
		var body := skeleton.get_node("Body") as MeshInstance3D
		_check(skeleton.get_bone_count() == 65, "esqueleto deve ter os 65 ossos do UAL")
		_check(body.skin.get_bind_count() == 65, "skin deve ligar os 65 ossos")
		var arrays := body.mesh.surface_get_arrays(0)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		_check(verts.size() > 2000, "malha deve ter corpo completo")
		_check(bones.size() == verts.size() * 4 and weights.size() == verts.size() * 4, "4 influências por vértice")
		var bad_weights := 0
		for v in verts.size():
			var total := weights[v * 4] + weights[v * 4 + 1] + weights[v * 4 + 2] + weights[v * 4 + 3]
			if absf(total - 1.0) > 0.001 or bones[v * 4] < 0 or bones[v * 4] >= 65:
				bad_weights += 1
		_check(bad_weights == 0, "pesos devem somar 1 e apontar para ossos válidos (%d ruins)" % bad_weights)
		var aabb := body.mesh.get_aabb()
		_check(aabb.position.y > -0.01 and aabb.position.y < 0.02, "sola do pé deve ficar no chão (y=%.3f)" % aabb.position.y)
		_check(aabb.end.y > 1.65 and aabb.end.y < 2.0, "altura de repouso plausível (%.2f)" % aabb.end.y)
		model.free()
	print("  ✓ 30 personagens montados")

func start_animation_test() -> void:
	print("\n[3/3] CharacterVisual com DNA: animação e correção da pelve...")
	_long = _visual(1.12)
	_short = _visual(0.88)
	_check(_long.has(&"Walk") and _long.has(&"Sword_Regular_A"), "bibliotecas UAL1/UAL2 devem estar carregadas")
	_check(_long.weapon != null, "arma deve encaixar na mão procedural")

func _visual(leg_length: float) -> CharacterVisual:
	var dna := CharacterDNA.randomized(7)
	dna.leg_length = leg_length
	var visual := CharacterVisual.new()
	visual.dna = dna
	root.add_child(visual)
	var skeleton := visual.skeleton
	var modifier := skeleton.get_node("PelvisHeight") as SkeletonModifier3D
	modifier.modification_processed.connect(func() -> void:
		_toe_y[leg_length] = (skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone("ball_leaf_l"))).origin.y)
	return visual

func _process(_delta: float) -> bool:
	_frames += 1
	# No _init a árvore ainda não roda, então o _ready do CharacterVisual só acontece aqui.
	if _frames == 1:
		start_animation_test()
	if _frames < 20:
		return false
	# Nas duas pernas extremas, a ponta do pé animada deve continuar no chão.
	for visual in [_long, _short]:
		var toe_y: float = _toe_y.get(visual.dna.leg_length, INF)
		_check(absf(toe_y) < 0.04, "pé deve ficar no chão com leg_length %.2f (y=%.3f)" % [visual.dna.leg_length, toe_y])
	if _failures == 0:
		print("  ✓ animação tocando e pés no chão")
		print("\n🎉 GERADOR PROCEDURAL VALIDADO COM 100% DE SUCESSO!")
	else:
		print("\n❌ %d verificação(ões) falharam" % _failures)
	print("========================================================\n")
	quit(1 if _failures > 0 else 0)
	return true
