class_name CreatureBody
extends Node3D

## Corpo procedural de criatura (GDD-09 §2): monta cápsulas, esferas e cones a partir do
## CreatureDNA e anima sem esqueleto — pernas pela velocidade, asas batem/planam, nadadeiras
## ondulam, e o bicho parado respira. A frente é -Z (como o look_at do Godot).

@export var dna: CreatureDNA

## Ponto onde o cavaleiro senta (topo do dorso)
var saddle: Marker3D
## Altura do dorso acima do chão/água (para o cavaleiro e a câmera)
var back_height: float = 1.0

var _legs: Array[Node3D] = []
var _wings: Array[Node3D] = []
var _fins: Array[Node3D] = []
var _tail: Node3D
var _head: Node3D
var _torso: Node3D
## Cabeça baixa (bebendo ou pastando)
var head_down: bool = false
var _phase: float = 0.0
var _flap: float = 0.0
var _batches: Dictionary = {}  # pivô -> MeshBatch

func _ready() -> void:
	if dna == null:
		dna = CreatureDNA.randomized(CreatureDNA.Species.TROTADOR, 1)
	build()

func build() -> void:
	for c in get_children():
		c.free()
	_legs.clear()
	_wings.clear()
	_fins.clear()
	_batches.clear()
	_torso = Node3D.new()
	_torso.name = "Torso"
	add_child(_torso)
	match dna.plan():
		CreatureDNA.Plan.QUADRUPED:
			_build_quadruped()
		CreatureDNA.Plan.BIRD:
			_build_bird()
		CreatureDNA.Plan.FISH:
			_build_fish()
	_flush()
	saddle = Marker3D.new()
	saddle.name = "Saddle"
	saddle.position = Vector3(0, back_height, 0.05)
	_torso.add_child(saddle)

## Anima pelo movimento: `speed` em m/s; `climb` > 0 subindo (asas batem mais); `airborne` voando
func animate(delta: float, speed: float, climb: float = 0.0, airborne: bool = false) -> void:
	var f := dna.size_factor()
	_phase += delta * (2.0 + speed * 2.2 / maxf(f, 0.4))
	var t := Time.get_ticks_msec() / 1000.0
	match dna.plan():
		CreatureDNA.Plan.QUADRUPED:
			var swing := clampf(speed / 6.0, 0.0, 1.0) * 0.7
			for i in _legs.size():
				var offset := 0.0 if i == 0 or i == 3 else PI
				_legs[i].rotation.x = sin(_phase + offset) * swing
			_torso.position.y = absf(sin(_phase)) * swing * 0.06 * f + sin(t * 1.6) * 0.008
			if _head:
				var target_x := 0.95 if head_down else sin(_phase * 2.0) * swing * 0.12 + (0.25 if speed < 0.3 and fmod(t, 9.0) < 3.0 else 0.0)
				_head.rotation.x = lerpf(_head.rotation.x, target_x, minf(1.0, delta * 6.0))
			if _tail:
				_tail.rotation.y = sin(t * 2.3) * 0.35
		CreatureDNA.Plan.BIRD:
			var flap_speed := 9.0 if (climb > 0.1 or not airborne) else 4.0
			_flap += delta * flap_speed
			var amp := 0.9 if climb > 0.1 else (0.45 if airborne and fmod(t, 4.0) < 2.5 else 0.08)
			if not airborne:
				amp = 0.05
			for i in _wings.size():
				var side := -1.0 if i == 0 else 1.0
				# No chão as asas dobram para trás, junto ao corpo
				_wings[i].rotation.y = lerpf(_wings[i].rotation.y, 0.0 if airborne else -side * 1.3, minf(1.0, delta * 6.0))
				_wings[i].rotation.z = side * (sin(_flap) * amp + (0.05 if airborne else 0.25))
			if _tail:
				_tail.rotation.x = sin(t * 1.3) * 0.08
			_torso.position.y = sin(_flap) * amp * 0.05
		CreatureDNA.Plan.FISH:
			var wave := 1.5 + speed * 1.2
			for i in _fins.size():
				var side := -1.0 if i == 0 else 1.0
				_fins[i].rotation.z = side * sin(t * wave + side * 0.4) * 0.35
			if _tail:
				_tail.rotation.y = sin(t * wave * 1.6) * 0.45

# ---------------------------------------------------------------- planos de corpo

func _build_quadruped() -> void:
	var info := dna.info()
	var f := dna.size_factor()
	var body: Vector3 = info["body"] * f
	var leg: float = info["leg"] * f
	var hip_y := leg
	back_height = hip_y + body.y * 0.95
	var body_center := Vector3(0, hip_y + body.y * 0.5, 0)
	_ellipsoid(_torso, body, body_center, dna.coat_color())
	_ellipsoid(_torso, Vector3(body.x * 0.85, body.y * 0.55, body.z * 0.8), body_center - Vector3(0, body.y * 0.2, 0), dna.belly_color)
	_pattern(body, body_center)
	# Pernas: frente esquerda, frente direita, trás esquerda, trás direita
	for side_z in [-1.0, 1.0]:
		for side_x in [-1.0, 1.0]:
			var pivot := Node3D.new()
			pivot.position = Vector3(side_x * body.x * 0.3, hip_y + 0.05 * f, side_z * body.z * 0.32)
			_torso.add_child(pivot)
			# Coxa larga junto ao corpo, canela fina e casco
			_ellipsoid(pivot, Vector3(body.x * 0.32, leg * 0.62, body.z * 0.2), Vector3(0, -leg * 0.18, 0), dna.coat_color())
			_capsule(pivot, leg * 0.065, leg * 0.75, Vector3(0, -leg * 0.6, 0), dna.coat_color().darkened(0.12))
			_ellipsoid(pivot, Vector3(leg * 0.15, leg * 0.09, leg * 0.18), Vector3(0, -leg + leg * 0.03, -leg * 0.02), Color(0.18, 0.14, 0.11))
			_legs.append(pivot)
	# Pescoço e cabeça
	var neck_len: float = maxf(info["neck"] * f, body.y * 0.25)
	_head = Node3D.new()
	_head.position = body_center + Vector3(0, body.y * 0.2, -body.z * 0.45)
	_head.rotation.x = 0.15
	_torso.add_child(_head)
	var neck_dir := Vector3(0, 0.75, -0.66).normalized()
	_capsule(_head, body.x * 0.22, neck_len + body.x * 0.3, neck_dir * neck_len * 0.5, dna.coat_color(), Basis(Vector3.RIGHT, -0.85))
	var skull := neck_dir * neck_len
	var head_size := body.x * 0.42
	_ellipsoid(_head, Vector3(head_size * 0.8, head_size * 0.8, head_size * 1.3), skull + Vector3(0, 0, -head_size * 0.3), dna.coat_color())
	_ellipsoid(_head, Vector3(head_size * 0.55, head_size * 0.5, head_size * 0.6), skull + Vector3(0, -head_size * 0.15, -head_size * 0.95), dna.belly_color)
	for side in [-1.0, 1.0]:
		_ellipsoid(_head, Vector3(head_size * 0.12, head_size * 0.12, head_size * 0.12), skull + Vector3(side * head_size * 0.36, head_size * 0.12, -head_size * 0.55), Color(0.05, 0.04, 0.03))
		var ear: float = info["ears"] * f
		_cone(_head, head_size * 0.12, ear, skull + Vector3(side * head_size * 0.28, head_size * 0.35 + ear * 0.4, head_size * 0.1), dna.coat_color().darkened(0.1), Basis(Vector3.BACK, side * 0.35))
		if dna.has_horns():
			_cone(_head, head_size * 0.1, head_size * 1.1, skull + Vector3(side * head_size * 0.2, head_size * 0.55 + head_size * 0.4, -head_size * 0.1), Color(0.86, 0.8, 0.66), Basis(Vector3.RIGHT, -0.5) * Basis(Vector3.BACK, side * 0.3))
	# Cauda
	_tail = Node3D.new()
	_tail.position = body_center + Vector3(0, body.y * 0.25, body.z * 0.48)
	_torso.add_child(_tail)
	var tail_len: float = info["tail"] * f
	_capsule(_tail, tail_len * 0.12, tail_len, Vector3(0, -tail_len * 0.35, tail_len * 0.3), dna.coat_color().darkened(0.2), Basis(Vector3.RIGHT, 0.7))

func _build_bird() -> void:
	var info := dna.info()
	var f := dna.size_factor()
	var body: Vector3 = info["body"] * f
	var leg := 0.45 * f
	back_height = leg + body.y * 0.9
	var center := Vector3(0, leg + body.y * 0.5, 0)
	_ellipsoid(_torso, body, center, dna.coat_color())
	_ellipsoid(_torso, Vector3(body.x * 0.8, body.y * 0.6, body.z * 0.7), center - Vector3(0, body.y * 0.2, 0.05), dna.belly_color)
	_pattern(body, center)
	for side in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.position = Vector3(side * body.x * 0.4, back_height * 0.95, -body.z * 0.08)
		_torso.add_child(pivot)
		var span: float = info["wing"] * f * 0.5
		_ellipsoid(pivot, Vector3(span, 0.08 * f, body.z * 0.55), Vector3(side * span * 0.5, 0, 0.05), dna.coat_color().darkened(0.08))
		_ellipsoid(pivot, Vector3(span * 0.6, 0.06 * f, body.z * 0.35), Vector3(side * span * 0.85, -0.01, 0.15), dna.coat_color().lightened(0.12))
		_wings.append(pivot)
		var leg_pivot := Node3D.new()
		leg_pivot.position = Vector3(side * body.x * 0.18, leg, 0.05)
		_torso.add_child(leg_pivot)
		_capsule(leg_pivot, 0.04 * f, leg, Vector3(0, -leg * 0.5, 0), Color(0.85, 0.65, 0.3))
		_legs.append(leg_pivot)
	_head = Node3D.new()
	_head.position = center + Vector3(0, body.y * 0.35, -body.z * 0.45)
	_torso.add_child(_head)
	var neck: float = info["neck"] * f
	_capsule(_head, body.x * 0.18, neck, Vector3(0, neck * 0.35, -neck * 0.2), dna.coat_color(), Basis(Vector3.RIGHT, -0.5))
	var hs := body.x * 0.38
	var skull := Vector3(0, neck * 0.75, -neck * 0.35)
	_ellipsoid(_head, Vector3(hs, hs, hs * 1.1), skull, dna.coat_color())
	_cone(_head, hs * 0.22, hs * 0.9, skull + Vector3(0, -hs * 0.08, -hs * 0.8), Color(0.95, 0.75, 0.25), Basis(Vector3.RIGHT, -PI * 0.5))
	for side in [-1.0, 1.0]:
		_ellipsoid(_head, Vector3.ONE * hs * 0.16, skull + Vector3(side * hs * 0.38, hs * 0.1, -hs * 0.3), Color(0.05, 0.04, 0.03))
	if dna.has_horns():
		# Penacho: crista de penas
		for i in 3:
			_cone(_head, hs * 0.1, hs * (0.9 - i * 0.15), skull + Vector3(0, hs * 0.55, hs * (0.1 + i * 0.22)), dna.belly_color.lerp(Color(0.95, 0.35, 0.2), 0.6), Basis(Vector3.RIGHT, 0.5 + i * 0.25))
	_tail = Node3D.new()
	_tail.position = center + Vector3(0, body.y * 0.1, body.z * 0.45)
	_torso.add_child(_tail)
	var tail: float = info["tail"] * f
	_ellipsoid(_tail, Vector3(body.x * 0.9, 0.05 * f, tail), Vector3(0, 0, tail * 0.45), dna.coat_color().darkened(0.12))

func _build_fish() -> void:
	var info := dna.info()
	# Peixe comum tem proporções de 1 m em "body" e "tail": multiplica pelo tamanho da espécie.
	# A Raia (wide) já vem em metros.
	var f := dna.size_factor() * (1.0 if info.get("wide", false) else float(info["size"]))
	var body: Vector3 = info["body"] * f
	back_height = body.y * 0.6
	var center := Vector3.ZERO
	_ellipsoid(_torso, body, center, dna.coat_color())
	_ellipsoid(_torso, Vector3(body.x * 0.9, body.y * 0.5, body.z * 0.9), center - Vector3(0, body.y * 0.22, 0), dna.belly_color)
	_pattern(body, center)
	if info.get("wide", false):
		# Raia: as bordas do disco ondulam como asas
		for side in [-1.0, 1.0]:
			var pivot := Node3D.new()
			pivot.position = Vector3(side * body.x * 0.32, 0, 0)
			_torso.add_child(pivot)
			_ellipsoid(pivot, Vector3(body.x * 0.45, body.y * 0.35, body.z * 0.7), Vector3(side * body.x * 0.2, 0, 0.05), dna.coat_color().darkened(0.05))
			_fins.append(pivot)
		for side in [-1.0, 1.0]:
			_ellipsoid(_torso, Vector3.ONE * body.y * 0.25, Vector3(side * body.x * 0.12, body.y * 0.35, -body.z * 0.38), Color(0.05, 0.05, 0.05))
	else:
		var fin_color: Color = info.get("fin", dna.belly_color)
		# Faixa lateral brilhante (Lambari) ou escura (Traíra), da guelra ao rabo
		if info.has("stripe"):
			_ellipsoid(_torso, Vector3(body.x * 1.02, body.y * 0.16, body.z * 0.78), center + Vector3(0, body.y * 0.05, body.z * 0.06), info["stripe"])
		for side in [-1.0, 1.0]:
			var pivot := Node3D.new()
			pivot.position = Vector3(side * body.x * 0.45, -body.y * 0.1, -body.z * 0.1)
			_torso.add_child(pivot)
			_ellipsoid(pivot, Vector3(body.x * 0.5, 0.02 * f, body.z * 0.2), Vector3(side * body.x * 0.2, 0, 0), fin_color)
			_fins.append(pivot)
			_ellipsoid(_torso, Vector3.ONE * body.x * 0.25, Vector3(side * body.x * 0.38, body.y * 0.12, -body.z * 0.32), Color(0.05, 0.05, 0.05))
		_cone(_torso, body.x * 0.05, body.y * 0.6, Vector3(0, body.y * 0.55, 0.05), fin_color.darkened(0.15), Basis.IDENTITY)
	_tail = Node3D.new()
	_tail.position = Vector3(0, 0, body.z * 0.48)
	_torso.add_child(_tail)
	var tail: float = info["tail"] * f
	if info.get("wide", false):
		_capsule(_tail, 0.03 * f, tail, Vector3(0, 0, tail * 0.5), dna.coat_color().darkened(0.3), Basis(Vector3.RIGHT, PI * 0.5))
	else:
		_ellipsoid(_tail, Vector3(0.03 * f, body.y * 1.1, tail * 0.6), Vector3(0, 0, tail * 0.3), info.get("fin", dna.coat_color().darkened(0.1)))

## Listras (gene P_) e pintas (mutação)
func _pattern(body: Vector3, center: Vector3) -> void:
	var dark := dna.coat_color().darkened(0.35)
	if dna.is_striped():
		for i in 4:
			var z := lerpf(-body.z * 0.3, body.z * 0.3, i / 3.0)
			var k := sqrt(maxf(0.0, 1.0 - pow(z / (body.z * 0.5), 2.0)))
			_ellipsoid(_torso, Vector3(body.x * k * 1.02, body.y * k * 1.02, body.z * 0.07), center + Vector3(0, body.y * 0.04, z), dark)
	if dna.is_mutant():
		var rng := RandomNumberGenerator.new()
		rng.seed = dna.dna_seed
		for i in 7:
			var a := rng.randf_range(-1.2, 1.2)
			var z := rng.randf_range(-0.35, 0.35) * body.z
			var p := center + Vector3(sin(a) * body.x * 0.47, cos(a) * body.y * 0.47, z)
			_ellipsoid(_torso, Vector3.ONE * body.x * 0.12, p, Color(0.95, 0.95, 1.0).lerp(dark, 0.2))

# ---------------------------------------------------------------- primitivas
# Cada parte é somada à malha do pivô a que pertence (tronco, cada perna, cabeça, cauda, asa):
# o bicho inteiro vira ~8 chamadas de desenho em vez de ~30.

static var _shared_mats: Dictionary = {}

func _batch(parent: Node3D) -> MeshBatch:
	if not _batches.has(parent):
		_batches[parent] = MeshBatch.new()
	return _batches[parent]

## Fecha as malhas acumuladas: uma MeshInstance por pivô
func _flush() -> void:
	for parent in _batches:
		var mi := MeshInstance3D.new()
		mi.mesh = (_batches[parent] as MeshBatch).commit()
		mi.material_override = _material(dna.is_mutant())
		mi.visibility_range_end = 90.0
		# Peixe nada debaixo d'água: sombra não aparece e custa uma passada a mais
		if dna.plan() == CreatureDNA.Plan.FISH:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		(parent as Node3D).add_child(mi)
	_batches.clear()

static func _material(mutant: bool) -> StandardMaterial3D:
	if not _shared_mats.has(mutant):
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.vertex_color_is_srgb = true
		m.roughness = 0.45 if mutant else 0.85
		m.metallic = 0.35 if mutant else 0.0
		_shared_mats[mutant] = m
	return _shared_mats[mutant]

func _ellipsoid(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> void:
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 12
	sm.rings = 6
	_append(parent, sm, "creature_sphere", Transform3D(Basis.IDENTITY.scaled(size), pos), color)

func _capsule(parent: Node3D, radius: float, height: float, pos: Vector3, color: Color, rot: Basis = Basis.IDENTITY) -> void:
	var cm := CapsuleMesh.new()
	cm.radius = radius
	cm.height = maxf(height, radius * 2.0)
	cm.radial_segments = 10
	cm.rings = 4
	_append(parent, cm, "", Transform3D(rot, pos), color)

func _cone(parent: Node3D, radius: float, height: float, pos: Vector3, color: Color, rot: Basis) -> void:
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = radius
	cm.height = height
	cm.radial_segments = 8
	_append(parent, cm, "", Transform3D(rot, pos), color)

func _append(parent: Node3D, mesh: PrimitiveMesh, key: String, xform: Transform3D, color: Color) -> void:
	_batch(parent).append(MeshBatch.arrays_of(mesh, key), xform, color)
