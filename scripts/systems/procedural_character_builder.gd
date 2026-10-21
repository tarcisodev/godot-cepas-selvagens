class_name ProceduralCharacterBuilder
extends RefCounted

## Gera um humanoide a partir de um CharacterDNA, sem modelo pronto (B09 / ADR-0004).
# O esqueleto é copiado do rig UAL (65 ossos) e só muda o comprimento dos ossos, então as
# bibliotecas UAL1/UAL2 tocam direto. A malha é montada por código (tubos elípticos e retalhos
# de elipsoide) já com pesos nesses ossos, e a roupa sai da cor de vértice.
# Coordenadas no espaço do esqueleto em pose T: frente = +Z, esquerda do personagem = +X.

const LIMB_SIDES := 10
const TORSO_SIDES := 16

## Pose de repouso do rig por cena de origem: [{name, parent, rest}].
static var _rig_cache: Dictionary = {}

var dna: CharacterDNA
var skeleton: Skeleton3D
## Pose global de repouso de cada osso, já com as proporções do DNA.
var _global: Array[Transform3D] = []
var _head_center: Vector3
var _head_radii: Vector3

## Monta Model/Armature/Skeleton3D (mesma estrutura do kit, para os caminhos das animações baterem).
static func build(p_dna: CharacterDNA, rig_source: PackedScene) -> Node3D:
	var builder := ProceduralCharacterBuilder.new()
	return builder._build(p_dna, rig_source)

func _build(p_dna: CharacterDNA, rig_source: PackedScene) -> Node3D:
	dna = p_dna
	var root := Node3D.new()
	root.name = "ProceduralCharacter"
	var armature := Node3D.new()
	armature.name = "Armature"
	root.add_child(armature)

	var pelvis_factor := _build_skeleton(rig_source)
	armature.add_child(skeleton)

	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = _build_mesh()
	body.skin = _build_skin()
	skeleton.add_child(body)
	body.skeleton = NodePath("..")

	var pelvis_fix := PelvisHeightModifier.new()
	pelvis_fix.name = "PelvisHeight"
	pelvis_fix.factor = pelvis_factor
	skeleton.add_child(pelvis_fix)

	root.scale = Vector3.ONE * dna.stature
	return root

# --- Esqueleto -------------------------------------------------------------------------------

func _build_skeleton(rig_source: PackedScene) -> float:
	var rig := _rig_rest(rig_source)
	skeleton = Skeleton3D.new()
	skeleton.name = "Skeleton3D"
	for bone in rig:
		skeleton.add_bone(bone.name)
	for i in rig.size():
		skeleton.set_bone_parent(i, rig[i].parent)

	var fem := dna.femininity
	var shoulder := lerpf(1.0, 0.9, fem) * (1.0 + 0.07 * dna.muscle + 0.04 * dna.mass)
	var hips := lerpf(1.0, 1.12, fem) * (1.0 + 0.06 * dna.mass)
	var stretch := {
		&"spine_01": dna.torso_length, &"spine_02": dna.torso_length, &"spine_03": dna.torso_length,
		&"neck_01": dna.torso_length, &"Head": dna.neck_length,
		&"calf_l": dna.leg_length, &"calf_r": dna.leg_length, &"foot_l": dna.leg_length, &"foot_r": dna.leg_length,
		&"lowerarm_l": dna.arm_length, &"lowerarm_r": dna.arm_length, &"hand_l": dna.arm_length, &"hand_r": dna.arm_length,
		&"upperarm_l": shoulder, &"upperarm_r": shoulder, &"thigh_l": hips, &"thigh_r": hips,
	}
	var rests: Array[Transform3D] = []
	for bone in rig:
		var rest: Transform3D = bone.rest
		rest.origin *= stretch.get(StringName(bone.name), 1.0)
		rests.append(rest)
	_global = _globals(rig, rests)

	# Sobe/desce a pelve para o tornozelo ficar na altura original (pé no chão).
	var pelvis := _bone("pelvis")
	var template_ankle_y := _globals(rig, _template_rests(rig))[_bone("foot_l")].origin.y
	var lift := template_ankle_y - _global[_bone("foot_l")].origin.y
	var parent_global := _global[rig[pelvis].parent] if rig[pelvis].parent >= 0 else Transform3D.IDENTITY
	var old_origin := rests[pelvis].origin
	var pelvis_rest := rests[pelvis]
	pelvis_rest.origin = parent_global.affine_inverse() * (_global[pelvis].origin + Vector3(0.0, lift, 0.0))
	rests[pelvis] = pelvis_rest
	_global = _globals(rig, rests)

	for i in rests.size():
		skeleton.set_bone_rest(i, rests[i])
	skeleton.reset_bone_poses()
	return rests[pelvis].origin.length() / maxf(old_origin.length(), 0.001)

static func _rig_rest(rig_source: PackedScene) -> Array:
	var key := rig_source.resource_path
	if not _rig_cache.has(key):
		var source := rig_source.instantiate()
		var source_skeleton := source.find_child("Skeleton3D", true, false) as Skeleton3D
		var bones := []
		for i in source_skeleton.get_bone_count():
			bones.append({
				name = source_skeleton.get_bone_name(i),
				parent = source_skeleton.get_bone_parent(i),
				rest = source_skeleton.get_bone_rest(i),
			})
		source.free()
		_rig_cache[key] = bones
	return _rig_cache[key]

static func _template_rests(rig: Array) -> Array[Transform3D]:
	var rests: Array[Transform3D] = []
	for bone in rig:
		rests.append(bone.rest)
	return rests

static func _globals(rig: Array, rests: Array[Transform3D]) -> Array[Transform3D]:
	var result: Array[Transform3D] = []
	for i in rig.size():
		var parent: int = rig[i].parent
		result.append(result[parent] * rests[i] if parent >= 0 else rests[i])
	return result

func _bone(bone_name: String) -> int:
	return skeleton.find_bone(bone_name)

func _pos(bone_name: String) -> Vector3:
	return _global[_bone(bone_name)].origin

func _build_skin() -> Skin:
	var skin := Skin.new()
	for i in _global.size():
		skin.add_bind(i, _global[i].affine_inverse())
	return skin

# --- Malha -----------------------------------------------------------------------------------

func _build_mesh() -> ArrayMesh:
	var md := MeshData.new()
	_torso(md)
	_neck(md)
	for side in ["l", "r"]:
		_leg(md, side)
		_shoe(md, side)
		_arm(md, side)
		_hand(md, side)
	_head(md)
	_hair(md)
	_beard(md)

	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 0.88
	material.metallic_specular = 0.25
	return md.to_mesh(material)

func _torso(md: MeshData) -> void:
	var fem := dna.femininity
	var mass := dna.mass
	var pelvis := _pos("pelvis")
	var spine_01 := _pos("spine_01")
	var spine_02 := _pos("spine_02")
	var spine_03 := _pos("spine_03")
	var neck := _pos("neck_01")
	var hip_y := _pos("thigh_l").y
	var shoulder_x := absf(_pos("upperarm_l").x)
	var neck_r := _neck_radius()

	# Seções de controle: [altura, meia largura, meia profundidade, deslocamento em z].
	var hip_w := _pos("thigh_l").x + 0.065 + 0.03 * mass
	var waist_w := 0.128 - 0.014 * fem + 0.07 * mass
	var chest_w := 0.152 + 0.022 * dna.muscle - 0.016 * fem + 0.035 * mass
	var belly := 0.07 * mass
	var bust := clampf((fem - 0.5) * 2.0, 0.0, 1.0)
	var sections := [
		[hip_y - 0.085, hip_w * 0.62, 0.075 + 0.02 * mass, pelvis.z],
		[hip_y + 0.01, hip_w, 0.1 + 0.03 * mass + 0.012 * fem, pelvis.z - 0.004],
		[spine_01.y + 0.035, waist_w, 0.092 + 0.05 * mass, spine_01.z + belly * 0.45],
		[spine_02.y + 0.01, lerpf(waist_w, chest_w, 0.5), 0.1 + 0.04 * mass, spine_02.z + belly * 0.3],
		[spine_03.y + 0.05, chest_w, 0.112 + 0.015 * dna.muscle + 0.025 * mass + 0.02 * bust, spine_03.z + 0.008 + 0.01 * bust],
		[_pos("upperarm_l").y - 0.005, shoulder_x - 0.045, 0.085 + 0.012 * mass, spine_03.z - 0.005],
		[neck.y + 0.008, neck_r * 1.55, neck_r * 1.35, neck.z],
	]
	var section_at := func(y: float) -> Array:
		if y <= sections[0][0]:
			return sections[0].slice(1)
		for i in sections.size() - 1:
			var a: Array = sections[i]
			var b: Array = sections[i + 1]
			if y <= b[0]:
				var t := smoothstep(0.0, 1.0, (y - a[0]) / (b[0] - a[0]))
				return [lerpf(a[1], b[1], t), lerpf(a[2], b[2], t), lerpf(a[3], b[3], t)]
		return sections[-1].slice(1)

	var belt_y := lerpf(hip_y, spine_01.y + 0.035, 0.6)
	var belt_lo := belt_y - 0.024
	var belt_hi := belt_y + 0.024
	var look := func(y: float) -> Array:
		if y < belt_lo:
			return [dna.pants_color, 1.0]
		if y <= belt_hi:
			return [dna.belt_color, 1.035]
		return [dna.shirt_color, 1.0]

	var chain_bones := [_bone("pelvis"), _bone("spine_01"), _bone("spine_02"), _bone("spine_03")]
	var chain_ys := [pelvis.y, spine_01.y, spine_02.y, spine_03.y, neck.y]
	var clavicle_y := spine_03.y + 0.04
	var shoulder_y := _pos("upperarm_l").y
	var crotch_y: float = sections[0][0]
	var weights := func(p: Vector3) -> Dictionary:
		var w := _chain_by_height(p.y, chain_ys, chain_bones, _bone("neck_01"))
		var side := "l" if p.x > 0.0 else "r"
		var clavicle := smoothstep(0.05, 0.15, absf(p.x)) * smoothstep(clavicle_y, shoulder_y, p.y) * 0.5
		w = _mix(w, {_bone("clavicle_" + side): 1.0}, clavicle)
		var thigh := smoothstep(0.03, 0.13, absf(p.x)) * (1.0 - smoothstep(crotch_y, hip_y + 0.04, p.y)) * 0.55
		return _mix(w, {_bone("thigh_" + side): 1.0}, thigh)

	var ys: Array[float] = []
	var steps := 16
	for i in steps + 1:
		ys.append(lerpf(crotch_y, sections[-1][0], float(i) / steps))
	var make_ring := func(y: float, color_y: float) -> Dictionary:
		var s: Array = section_at.call(y)
		var l: Array = look.call(color_y)
		return {c = Vector3(0.0, y, s[2]), rx = s[0] * l[1], rz = s[1] * l[1], col = l[0], w = weights}
	var rings := _rings_with_bounds(ys, [belt_lo, belt_hi], make_ring)
	md.loft(rings, TORSO_SIDES, Vector3.BACK, 2.5)

	# Fivela na frente do cinto.
	var waist: Array = section_at.call(belt_y)
	md.ellipsoid(Vector3(0.0, belt_y, waist[2] + waist[1] * 1.035), Vector3(0.022, 0.019, 0.008), Color("#b8a46a"), weights.call(Vector3(0.0, belt_y, 0.0)), 8, 5)

	# Busto: só a partir de femininity 0.5, bem embutido no peito para não parecer dois botões.
	if bust > 0.0:
		var y := spine_03.y + 0.01
		var s: Array = section_at.call(y)
		var r := (0.036 + 0.016 * bust) * (0.85 + 0.35 * mass)
		for x in [0.056, -0.056]:
			md.ellipsoid(Vector3(x, y, s[2] + s[1] - r * 0.72), Vector3(r * 1.1, r * 0.9, r), dna.shirt_color, {_bone("spine_03"): 1.0}, 12, 8)

func _neck_radius() -> float:
	return 0.048 + 0.012 * dna.mass + 0.008 * dna.muscle - 0.006 * dna.femininity

func _neck(md: MeshData) -> void:
	var base := _pos("neck_01")
	var head := _pos("Head")
	var r := _neck_radius()
	var rings := []
	for t in [-0.15, 0.4, 1.0, 1.4]:
		var c := base.lerp(head, t)
		var w := {_bone("neck_01"): 1.0}
		if t < 0.0:
			w = {_bone("neck_01"): 0.5, _bone("spine_03"): 0.5}
		elif t >= 1.0:
			w = {_bone("Head"): 1.0} if t > 1.0 else {_bone("neck_01"): 0.5, _bone("Head"): 0.5}
		rings.append({c = c, rx = r, rz = r * 1.05, col = dna.skin_color, w = w})
	md.loft(rings, LIMB_SIDES, Vector3.BACK)

func _leg(md: MeshData, side: String) -> void:
	var hip := _pos("thigh_" + side)
	var joints := [hip + Vector3(0.0, 0.04, 0.0), _pos("calf_" + side), _pos("foot_" + side)]
	var bones := [_bone("thigh_" + side), _bone("calf_" + side)]
	var mass := dna.mass
	var fem := dna.femininity
	var profile := [
		[0.0, 0.088 + 0.03 * mass + 0.012 * fem], [0.35, 0.074 + 0.024 * mass + 0.01 * dna.muscle],
		[0.92, 0.05 + 0.01 * mass], [1.0, 0.049 + 0.01 * mass], [1.3, 0.055 + 0.012 * dna.muscle + 0.014 * mass],
		[1.85, 0.037], [2.0, 0.036],
	]
	var pants_end := lerpf(0.75, 2.0, dna.pants_length)
	var boot_start := 2.0 - lerpf(0.12, 0.85, dna.boot_height)
	var look := func(u: float) -> Array:
		if u >= boot_start:
			return [dna.boots_color, 1.12]
		if u <= pants_end:
			return [dna.pants_color, 1.05]
		return [dna.skin_color, 1.0]
	_limb(md, joints, bones, _bone("pelvis"), profile, look, [pants_end, boot_start], Vector3.BACK)

func _arm(md: MeshData, side: String) -> void:
	var shoulder := _pos("upperarm_" + side)
	# Começa por dentro do tronco e fino, para a tampa não virar um canto quando o braço desce.
	var joints := [shoulder * Vector3(0.72, 1.0, 1.0), _pos("lowerarm_" + side), _pos("hand_" + side)]
	var bones := [_bone("upperarm_" + side), _bone("lowerarm_" + side)]
	var k := lerpf(1.0, 0.88, dna.femininity)
	var profile := [
		[0.0, (0.03 + 0.01 * dna.mass) * k], [0.16, (0.056 + 0.018 * dna.muscle + 0.016 * dna.mass) * k], [0.4, (0.047 + 0.02 * dna.muscle + 0.012 * dna.mass) * k],
		[1.0, 0.037 * k + 0.006 * dna.mass], [1.3, (0.041 + 0.01 * dna.muscle + 0.008 * dna.mass) * k],
		[1.95, 0.029 * k], [2.0, 0.028 * k],
	]
	var sleeve_end := dna.sleeve_length * 2.0 if dna.sleeve_length > 0.08 else -1.0
	var glove_start := 1.72 if dna.gloves else 3.0
	var look := func(u: float) -> Array:
		if u >= glove_start:
			return [dna.boots_color, 1.1]
		if u <= sleeve_end:
			return [dna.shirt_color, 1.07]
		return [dna.skin_color, 1.0]
	_limb(md, joints, bones, _bone("clavicle_" + side), profile, look, [sleeve_end, glove_start], Vector3.BACK)

## Mão em "luva": um bloco que segue a média dos dedos médio e anelar, mais o polegar.
func _hand(md: MeshData, side: String) -> void:
	var color := dna.boots_color if dna.gloves else dna.skin_color
	var hand := _bone("hand_" + side)
	var fingers := ["index", "middle", "ring", "pinky"]
	var centers: Array[Vector3] = []
	var widths: Array[float] = []
	for level in ["01", "02", "03", "04_leaf"]:
		var sum := Vector3.ZERO
		for f in fingers:
			sum += _pos("%s_%s_%s" % [f, level, side])
		centers.append(sum / 4.0)
		widths.append(_pos("index_%s_%s" % [level, side]).distance_to(_pos("pinky_%s_%s" % [level, side])) * 0.5 + 0.013)
	var wrist := _pos("hand_" + side)
	var finger_w := func(level: String, weight: float) -> Dictionary:
		return {_bone("middle_%s_%s" % [level, side]): weight * 0.5, _bone("ring_%s_%s" % [level, side]): weight * 0.5}
	var rings := [
		{c = wrist.lerp(centers[0], 0.05), rx = 0.022, rz = 0.032, w = {hand: 1.0}},
		{c = wrist.lerp(centers[0], 0.55), rx = 0.023, rz = widths[0] * 0.97, w = {hand: 1.0}},
		{c = centers[0], rx = 0.019, rz = widths[0], w = _mix({hand: 1.0}, finger_w.call("01", 1.0), 0.5)},
		{c = centers[1], rx = 0.016, rz = widths[1], w = _mix(finger_w.call("01", 1.0), finger_w.call("02", 1.0), 0.5)},
		{c = centers[2], rx = 0.014, rz = widths[2], w = _mix(finger_w.call("02", 1.0), finger_w.call("03", 1.0), 0.5)},
		{c = centers[3], rx = 0.011, rz = widths[3] * 0.9, w = finger_w.call("03", 1.0)},
	]
	for ring in rings:
		ring.col = color
	md.loft(rings, LIMB_SIDES, Vector3.BACK, 2.6)

	var thumb := []
	var radii := [0.017, 0.015, 0.013, 0.011]
	var levels := ["01", "02", "03", "04_leaf"]
	for i in levels.size():
		var w := {}
		if i == 0:
			w = {hand: 0.5, _bone("thumb_01_" + side): 0.5}
		elif i == 3:
			w = {_bone("thumb_03_" + side): 1.0}
		else:
			w = {_bone("thumb_%s_%s" % [levels[i - 1], side]): 0.5, _bone("thumb_%s_%s" % [levels[i], side]): 0.5}
		thumb.append({c = _pos("thumb_%s_%s" % [levels[i], side]), rx = radii[i], rz = radii[i], col = color, w = w})
	md.loft(thumb, 8, Vector3.UP)

func _shoe(md: MeshData, side: String) -> void:
	var foot := _pos("foot_" + side)
	var ball := _pos("ball_" + side)
	var toe := _pos("ball_leaf_" + side)
	var foot_bone := _bone("foot_" + side)
	var ball_bone := _bone("ball_" + side)
	# [z, meia largura, meia altura, pesos]
	var profile := [
		[foot.z - 0.06, 0.04, 0.048, {foot_bone: 1.0}],
		[foot.z - 0.01, 0.045, 0.065, {foot_bone: 1.0}],
		[lerpf(foot.z, ball.z, 0.55), 0.048, 0.05, {foot_bone: 1.0}],
		[ball.z, 0.05, 0.036, {foot_bone: 0.5, ball_bone: 0.5}],
		[lerpf(ball.z, toe.z, 0.6), 0.046, 0.03, {ball_bone: 1.0}],
		[toe.z + 0.005, 0.034, 0.024, {ball_bone: 1.0}],
	]
	var rings := []
	for p in profile:
		rings.append({c = Vector3(foot.x, p[2], p[0]), rx = p[1], rz = p[2], col = dna.boots_color, w = p[3]})
	md.loft(rings, LIMB_SIDES, Vector3.UP, 3.0)

# --- Cabeça ----------------------------------------------------------------------------------

func _head(md: MeshData) -> void:
	var hs := dna.head_size
	_head_center = _pos("Head") + Vector3(0.0, 0.1 * hs, 0.018)
	_head_radii = Vector3(0.094, 0.118, 0.104) * hs
	var head := _bone("Head")
	var neck := _bone("neck_01")
	var full := func(_phi: float) -> Vector2: return Vector2(0.0, PI)
	var weights := func(p: Vector3) -> Dictionary:
		var low := 1.0 - smoothstep(_head_center.y - _head_radii.y * 0.95, _head_center.y - _head_radii.y * 0.6, p.y)
		return _mix({head: 1.0}, {neck: 1.0}, low * 0.35)
	md.patch(_head_point.bind(1.0), _head_center, 0.0, TAU, full, 18, 12, dna.skin_color, weights)

	var w := {head: 1.0}
	var skin := dna.skin_color
	for sx in [1.0, -1.0]:
		var eye := _face_point(0.36 * sx, 0.08, 0.004)
		md.ellipsoid(eye, Vector3(0.019, 0.016, 0.01) * hs, Color("#f2ede4"), w, 8, 6)
		md.ellipsoid(eye + Vector3(0.0, 0.0, 0.0075 * hs), Vector3(0.0105, 0.0115, 0.005) * hs, dna.eye_color.darkened(0.2), w, 8, 6)
		md.ellipsoid(_face_point(0.37 * sx, 0.3, -0.004), Vector3(0.027, 0.0065, 0.009) * hs, dna.hair_color.darkened(0.15), w, 8, 4)
		var ear := _head_point(PI * 0.5 * sx, PI * 0.52, 0.97)
		md.ellipsoid(ear, Vector3(0.012, 0.029, 0.02) * hs, skin.darkened(0.04), w, 8, 6)
	var nose := 0.8 + 0.5 * dna.nose_size
	md.ellipsoid(_face_point(0.0, -0.1, -0.012), Vector3(0.014, 0.027, 0.021) * nose * hs, skin.darkened(0.06), w, 8, 6)
	md.ellipsoid(_face_point(0.0, -0.43, 0.002), Vector3(0.026, 0.0055, 0.006) * hs, skin.darkened(0.3).lerp(Color("#8a3b33"), 0.25), w, 8, 4)

## Ponto da superfície da cabeça. φ = 0 olha para a frente (+Z), φ = 90° para a esquerda (+X);
## θ = 0 no topo. A mandíbula afina para baixo conforme `jaw_width` e o crânio cresce para trás.
func _head_point(phi: float, theta: float, scale: float) -> Vector3:
	var d := Vector3(sin(theta) * sin(phi), cos(theta), sin(theta) * cos(phi))
	var p := d * _head_radii
	if d.y < 0.0:
		var down := -d.y
		p.x *= lerpf(1.0, lerpf(0.66, 0.93, dna.jaw_width), down)
		if d.z > 0.0:
			p.z *= lerpf(1.0, 1.07, down * d.z)
	elif d.z < 0.0:
		p.z *= 1.0 + 0.07 * d.y * -d.z
	return _head_center + p * scale

## Ponto na frente do rosto a partir de x/y normalizados (-1..1); `inset` > 0 afunda, < 0 projeta.
func _face_point(x: float, y: float, inset: float) -> Vector3:
	var d := Vector3(x, y, sqrt(maxf(0.0, 1.0 - x * x - y * y)))
	return _head_point(atan2(d.x, d.z), acos(clampf(d.y, -1.0, 1.0)), 1.0 - inset)

func _hair(md: MeshData) -> void:
	var color := dna.hair_color
	var head := {_bone("Head"): 1.0}
	# Calota: a borda desce da testa (front) até a nuca (back) e sobe por cima da orelha (ear_cut).
	var cap := func(scale: float, front: float, back: float, ear_cut: float) -> void:
		var edge := func(phi: float) -> Vector2:
			var t := (1.0 - cos(phi)) * 0.5
			return Vector2(0.0, PI * (lerpf(front, back, t) - ear_cut * pow(sin(phi), 4.0)))
		md.patch(_head_point.bind(scale), _head_center, 0.0, TAU, edge, 18, 6, color, head)
	match dna.hair_style:
		CharacterDNA.HairStyle.BALD:
			pass
		CharacterDNA.HairStyle.BUZZ:
			cap.call(1.025, 0.36, 0.64, 0.06)
		CharacterDNA.HairStyle.SHORT:
			cap.call(1.07, 0.38, 0.7, 0.07)
		CharacterDNA.HairStyle.TOPKNOT:
			cap.call(1.05, 0.36, 0.68, 0.06)
			md.ellipsoid(_head_point(PI, 0.18 * PI, 1.12), Vector3(0.045, 0.04, 0.045) * dna.head_size, color, head, 10, 7)
		CharacterDNA.HairStyle.PONYTAIL:
			cap.call(1.06, 0.37, 0.68, 0.06)
			var root := _head_point(PI, 0.38 * PI, 1.04)
			var k := 0.7 + 0.9 * dna.hair_length
			var tail := []
			var points := [root, root + Vector3(0.0, -0.06, -0.06), root + Vector3(0.0, -0.17 * k, -0.07 - 0.02 * k), root + Vector3(0.0, -0.27 * k, -0.05 - 0.03 * k)]
			var radii := [0.03, 0.028, 0.022, 0.01]
			for i in points.size():
				var w := head if i < 2 else _mix(head, {_bone("neck_01"): 1.0}, 0.3 * (i - 1))
				tail.append({c = points[i], rx = radii[i], rz = radii[i], col = color, w = w})
			md.loft(tail, 8, Vector3.RIGHT)
		CharacterDNA.HairStyle.LONG:
			cap.call(1.09, 0.38, 0.82, 0.0)
			_long_hair(md, 1.0, dna.hair_length > 0.35)
		CharacterDNA.HairStyle.MANE:
			cap.call(1.14, 0.35, 0.86, 0.0)
			_long_hair(md, 1.3, true)
		CharacterDNA.HairStyle.MOHAWK:
			var ridge := []
			for i in 8:
				var theta := lerpf(-0.32, 0.62, float(i) / 7.0) * PI
				var phi := 0.0 if theta >= 0.0 else PI
				var base := _head_point(phi, absf(theta), 1.0)
				var up := (base - _head_center).normalized()
				var height := 0.045 * sin(PI * (0.15 + 0.7 * float(i) / 7.0))
				ridge.append({c = base + up * height * 0.5, rx = height * 0.5 + 0.008, rz = 0.016, col = color, w = head})
			md.loft(ridge, 8, Vector3.RIGHT)

## Cortina de cabelo nas costas (comprimento por `hair_length`) e, com `locks`, mechas na frente dos ombros.
## `volume` engrossa tudo (juba).
func _long_hair(md: MeshData, volume: float, locks: bool) -> void:
	var color := dna.hair_color
	var head := {_bone("Head"): 1.0}
	var spine_03 := _pos("spine_03")
	var spine_02 := _pos("spine_02")
	var neck := _pos("neck_01")
	# Cabelo pesado demais na cabeça estica quando ela gira; abaixo da nuca ele segue a coluna.
	var weights := func(y: float) -> Dictionary:
		var w := _mix(head, {_bone("spine_03"): 1.0}, 0.8 * (1.0 - smoothstep(spine_03.y + 0.02, neck.y + 0.05, y)))
		return _mix(w, {_bone("spine_02"): 1.0}, 1.0 - smoothstep(spine_02.y, spine_03.y, y))
	# Costas: a superfície fica mais para trás com massa e músculo.
	var back_z := func(y: float) -> float:
		var upper := spine_03.z - 0.1 - 0.02 * dna.muscle - 0.02 * dna.mass
		var lower := spine_02.z - 0.1 - 0.04 * dna.mass
		return lerpf(lower, upper, smoothstep(spine_02.y, spine_03.y + 0.1, y)) - 0.015

	var top := _head_point(PI, 0.5 * PI, 1.0)
	var bottom_y := lerpf(neck.y - 0.03, spine_02.y - 0.02, dna.hair_length)
	var curtain := []
	for i in 6:
		var t := i / 5.0
		var y := lerpf(top.y, bottom_y, t)
		var z := lerpf(top.z, back_z.call(y), smoothstep(0.0, 0.45, t))
		curtain.append({c = Vector3(0.0, y, z), rx = lerpf(0.085, 0.072, t) * dna.head_size * volume,
			rz = lerpf(0.055, 0.02, t) * volume, col = color, w = weights.call(y)})
	md.loft(curtain, 12, Vector3.BACK, 2.4)

	if not locks:
		return
	var lock_end_y := lerpf(neck.y - 0.01, spine_03.y - 0.02, dna.hair_length)
	for sx in [1.0, -1.0]:
		var start := _head_point(deg_to_rad(78.0) * sx, 0.55 * PI, 1.0 + 0.06 * volume)
		var end := Vector3(sx * (0.095 + 0.01 * volume + 0.02 * dna.mass), lock_end_y, start.z + 0.03)
		var lock := []
		for i in 6:
			var t := i / 5.0
			var c := start.lerp(end, t)
			# Leve ondulação para a mecha não parecer uma vara.
			c.x += sx * 0.01 * sin(PI * t)
			c.z += 0.006 * sin(TAU * t)
			var r := lerpf(0.022, 0.009, t * t) * (0.85 + 0.15 * volume)
			lock.append({c = c, rx = r, rz = r * 0.85, col = color, w = weights.call(c.y)})
		md.loft(lock, 8, Vector3.BACK)

func _beard(md: MeshData) -> void:
	var color := dna.hair_color
	var w := {_bone("Head"): 1.0}
	if dna.beard == CharacterDNA.Beard.FULL:
		var reach := deg_to_rad(105.0)
		# Começa logo abaixo da boca na frente e sobe até a costeleta nos lados.
		var edge := func(phi: float) -> Vector2:
			var side := absf(phi) / reach
			return Vector2(PI * lerpf(0.69, 0.52, side), PI * lerpf(0.97, 0.7, side * side))
		md.patch(_head_point.bind(1.05), _head_center, -reach, reach, edge, 14, 5, color, w)
	elif dna.beard == CharacterDNA.Beard.GOATEE:
		var reach := deg_to_rad(32.0)
		var edge := func(_phi: float) -> Vector2: return Vector2(PI * 0.7, PI * 0.93)
		md.patch(_head_point.bind(1.06), _head_center, -reach, reach, edge, 6, 4, color, w)
	if dna.beard == CharacterDNA.Beard.MUSTACHE or dna.beard == CharacterDNA.Beard.FULL:
		md.ellipsoid(_face_point(0.0, -0.3, -0.018), Vector3(0.036, 0.009, 0.011) * dna.head_size, color, w, 10, 5)

	# Barba comprida: desce do queixo rente ao peito, afinando na ponta.
	var full := dna.beard == CharacterDNA.Beard.FULL
	if dna.beard_length < 0.02 or not (full or dna.beard == CharacterDNA.Beard.GOATEE):
		return
	var start := _head_point(0.0, (0.8 if full else 0.84) * PI, 1.03)
	var drop := (0.05 + 0.24 * dna.beard_length) if full else (0.03 + 0.11 * dna.beard_length)
	var width := (0.045 + 0.015 * dna.jaw_width) * dna.head_size if full else 0.022
	var chest_z := _pos("spine_03").z + 0.13 + 0.025 * dna.mass + 0.02
	var strand := []
	var depth := 0.038 if full else 0.018
	for i in 6:
		var t := i / 5.0
		var y := start.y - drop * t
		var z := maxf(lerpf(start.z, chest_z, t), start.z - 0.02 * t)
		# Cheia no meio e afinando em ponta, como uma barba de verdade.
		var bulge := 1.0 + 0.15 * sin(PI * t)
		strand.append({c = Vector3(0.0, y, z), rx = lerpf(width, width * 0.2, pow(t, 1.3)) * bulge, rz = lerpf(depth, depth * 0.35, t) * bulge,
			col = color, w = _mix(w, {_bone("spine_03"): 1.0}, 0.45 * t * t)})
	md.loft(strand, 10, Vector3.BACK)

# --- Utilidades ------------------------------------------------------------------------------

## Tubo com juntas: `profile` é [[u, raio]] com u em segmentos (0..n), `look(u)` devolve [cor, folga da roupa].
func _limb(md: MeshData, joints: Array, bones: Array, parent: int, profile: Array, look: Callable, bounds: Array, hint: Vector3) -> void:
	var n := bones.size()
	var us: Array[float] = []
	for s in n:
		for k in 5:
			us.append(float(s) + k / 5.0)
	us.append(float(n))
	var radius_at := func(u: float) -> float:
		for i in profile.size() - 1:
			if u <= profile[i + 1][0]:
				return lerpf(profile[i][1], profile[i + 1][1], (u - profile[i][0]) / (profile[i + 1][0] - profile[i][0]))
		return profile[-1][1]
	var make_ring := func(u: float, color_u: float) -> Dictionary:
		var s := mini(int(u), n - 1)
		var c: Vector3 = joints[s].lerp(joints[s + 1], u - s)
		var l: Array = look.call(color_u)
		var r: float = radius_at.call(u) * l[1]
		return {c = c, rx = r, rz = r, col = l[0], w = _chain(u, bones, parent)}
	var rings := _rings_with_bounds(us, bounds, make_ring)
	md.loft(rings, LIMB_SIDES, hint)

## Gera anéis nas posições `samples` e, em cada limite de cor, dois anéis no mesmo ponto
## (um com o visual de antes, outro com o de depois), para a barra da roupa ficar nítida.
func _rings_with_bounds(samples: Array[float], bounds: Array, make: Callable) -> Array:
	var lo := samples[0]
	var hi := samples[-1]
	var cuts: Array[float] = []
	for b in bounds:
		if b > lo + 0.001 and b < hi - 0.001:
			cuts.append(b)
	var all: Array[float] = []
	var gap := (hi - lo) / samples.size() * 0.35
	for s in samples:
		var near_cut := false
		for b in cuts:
			near_cut = near_cut or absf(s - b) <= gap
		if not near_cut:
			all.append(s)
	all.append_array(cuts)
	all.sort()
	var rings := []
	for s in all:
		if s in cuts:
			rings.append(make.call(s, s - 0.0001))
			rings.append(make.call(s, s + 0.0001))
		else:
			rings.append(make.call(s, s))
	return rings

## Pesos ao longo de uma cadeia de ossos; u em segmentos. Cada junta fica 50/50 entre os ossos vizinhos.
func _chain(u: float, bones: Array, parent: int) -> Dictionary:
	var n := bones.size()
	var s := clampi(int(u), 0, n - 1)
	var t := u - s
	var w := {bones[s]: 1.0}
	if t < 0.3:
		var prev: int = bones[s - 1] if s > 0 else parent
		if prev >= 0:
			w = _mix(w, {prev: 1.0}, 0.5 * (1.0 - t / 0.3))
	elif t > 0.7 and s < n - 1:
		w = _mix(w, {bones[s + 1]: 1.0}, 0.5 * (t - 0.7) / 0.3)
	return w

## Igual a `_chain`, mas por altura: `ys` tem uma altura a mais que `bones` (o topo do último).
func _chain_by_height(y: float, ys: Array, bones: Array, top_bone: int) -> Dictionary:
	if y <= ys[0]:
		return {bones[0]: 1.0}
	var chain := bones + [top_bone]
	for i in ys.size() - 1:
		if y <= ys[i + 1]:
			return _chain(i + (y - ys[i]) / (ys[i + 1] - ys[i]), chain, -1)
	return {top_bone: 1.0}

static func _mix(a: Dictionary, b: Dictionary, t: float) -> Dictionary:
	var result := {}
	for k in a:
		result[k] = a[k] * (1.0 - t)
	for k in b:
		result[k] = result.get(k, 0.0) + b[k] * t
	return result

## Acumula vértices com pesos de osso e devolve um ArrayMesh com skin.
class MeshData:
	var verts := PackedVector3Array()
	var colors := PackedColorArray()
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	var indices := PackedInt32Array()

	## Até 4 influências; os pesos são normalizados.
	func add_vertex(p: Vector3, color: Color, influences: Dictionary) -> int:
		var pairs := []
		for bone in influences:
			if influences[bone] > 0.0001:
				pairs.append([bone, influences[bone]])
		pairs.sort_custom(func(a: Array, b: Array) -> bool: return a[1] > b[1])
		pairs.resize(mini(pairs.size(), 4))
		var total := 0.0
		for pair in pairs:
			total += pair[1]
		for k in 4:
			bones.append(pairs[k][0] if k < pairs.size() else 0)
			weights.append(pairs[k][1] / total if k < pairs.size() else 0.0)
		verts.append(p)
		colors.append(color)
		return verts.size() - 1

	## `outward` é qualquer direção para fora da superfície; o Godot desenha a frente em sentido horário.
	func add_tri(a: int, b: int, c: int, outward: Vector3) -> void:
		var n := (verts[b] - verts[a]).cross(verts[c] - verts[a])
		if n.dot(outward) > 0.0:
			indices.append_array([a, c, b])
		else:
			indices.append_array([a, b, c])

	## Tubo por anéis elípticos {c, rx, rz, col, w}; `w` é {osso: peso} ou Callable(ponto) -> {osso: peso}.
	## `hint` orienta o eixo rz (deve fugir da direção do tubo); `squareness` > 2 deixa a seção mais quadrada.
	func loft(rings: Array, sides: int, hint: Vector3, squareness := 2.0, caps := true) -> void:
		var count := rings.size()
		var dirs: Array[Vector3] = []
		for i in count:
			var d: Vector3 = rings[mini(i + 1, count - 1)].c - rings[maxi(i - 1, 0)].c
			dirs.append(d.normalized() if d.length() > 0.00001 else (dirs[-1] if not dirs.is_empty() else Vector3.UP))
		var starts: Array[int] = []
		for i in count:
			var ring: Dictionary = rings[i]
			var az := (hint - dirs[i] * dirs[i].dot(hint)).normalized()
			var ax := dirs[i].cross(az)
			starts.append(verts.size())
			for k in sides:
				var angle := TAU * k / sides
				var cx := cos(angle)
				var sz := sin(angle)
				var x := signf(cx) * pow(absf(cx), 2.0 / squareness)
				var z := signf(sz) * pow(absf(sz), 2.0 / squareness)
				var p: Vector3 = ring.c + ax * x * ring.rx + az * z * ring.rz
				add_vertex(p, ring.col, ring.w.call(p) if ring.w is Callable else ring.w)
		for i in count - 1:
			var mid: Vector3 = (rings[i].c + rings[i + 1].c) * 0.5
			for k in sides:
				var a := starts[i] + k
				var b := starts[i] + (k + 1) % sides
				var c := starts[i + 1] + (k + 1) % sides
				var d := starts[i + 1] + k
				var out := (verts[a] + verts[c]) * 0.5 - mid
				add_tri(a, b, c, out)
				add_tri(a, c, d, out)
		if caps:
			_cap(rings[0], starts[0], sides, -dirs[0])
			_cap(rings[-1], starts[-1], sides, dirs[-1])

	## Tampa arredondada: um polo um pouco além do anel.
	func _cap(ring: Dictionary, start: int, sides: int, dir: Vector3) -> void:
		var depth: float = minf(ring.rx, ring.rz) * 0.55
		var pole_pos: Vector3 = ring.c + dir * depth
		var pole := add_vertex(pole_pos, ring.col, ring.w.call(pole_pos) if ring.w is Callable else ring.w)
		for k in sides:
			add_tri(start + k, start + (k + 1) % sides, pole, dir)

	## Retalho em coordenadas esféricas: `shape(φ, θ)` dá o ponto, `theta_range(φ)` limita cada meridiano.
	func patch(shape: Callable, center: Vector3, phi0: float, phi1: float, theta_range: Callable, cols: int, rows: int, color: Color, w: Variant) -> void:
		var closed := is_equal_approx(phi1 - phi0, TAU)
		var columns := cols if closed else cols + 1
		var start := verts.size()
		for c in columns:
			var phi := lerpf(phi0, phi1, float(c) / cols)
			var span: Vector2 = theta_range.call(phi)
			for r in rows + 1:
				var p: Vector3 = shape.call(phi, lerpf(span.x, span.y, float(r) / rows))
				add_vertex(p, color, w.call(p) if w is Callable else w)
		for c in cols:
			var c2 := (c + 1) % columns
			for r in rows:
				var a := start + c * (rows + 1) + r
				var b := start + c2 * (rows + 1) + r
				var out := (verts[a] + verts[b + 1]) * 0.5 - center
				add_tri(a, b, b + 1, out)
				add_tri(a, b + 1, a + 1, out)

	func ellipsoid(center: Vector3, radii: Vector3, color: Color, w: Dictionary, cols := 10, rows := 7) -> void:
		var shape := func(phi: float, theta: float) -> Vector3:
			return center + Vector3(sin(theta) * sin(phi), cos(theta), sin(theta) * cos(phi)) * radii
		var full := func(_phi: float) -> Vector2: return Vector2(0.0, PI)
		patch(shape, center, 0.0, TAU, full, cols, rows, color, w)

	func to_mesh(material: Material) -> ArrayMesh:
		var normals := PackedVector3Array()
		normals.resize(verts.size())
		for t in range(0, indices.size(), 3):
			var a := indices[t]
			var b := indices[t + 1]
			var c := indices[t + 2]
			# Horário visto de fora: este produto vetorial aponta para fora (e pesa pela área).
			var n := (verts[c] - verts[a]).cross(verts[b] - verts[a])
			normals[a] += n
			normals[b] += n
			normals[c] += n
		for i in normals.size():
			normals[i] = normals[i].normalized() if normals[i].length_squared() > 0.0 else Vector3.UP
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_COLOR] = colors
		arrays[Mesh.ARRAY_BONES] = bones
		arrays[Mesh.ARRAY_WEIGHTS] = weights
		arrays[Mesh.ARRAY_INDEX] = indices
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(0, material)
		return mesh
