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
## Pose de ataque (bichos que lutam, GDD-12 §9): &"head_low" abaixa a cabeça, &"rear" empina,
## &"paw" raspa a pata da frente. `pose_amount` 0–1 vai suave até o alvo.
var pose: StringName = &""
var pose_amount: float = 0.0
var _pose_now: float = 0.0
## Peças que podem quebrar e sumir na luta (cada uma num pivô próprio)
var horn_node: Node3D
var plates_node: Node3D
## Núcleo que brilha no peito da Sentinela (quebrável); `core_glow` 0–1 é o quanto ele brilha
var core_node: Node3D
var core_glow: float = 0.4
var _core_mat: StandardMaterial3D
var _arms: Array[Node3D] = []
var _phase: float = 0.0
var _flap: float = 0.0
var _batches: Dictionary = {}  # pivô -> MeshBatch

func _ready() -> void:
	if dna == null:
		dna = CreatureDNA.randomized(CreatureDNA.Species.TROTADOR, 1)
	build()

func build() -> void:
	scale = Vector3.ONE * (dna.stage_scale() if dna else 1.0)
	for c in get_children():
		c.free()
	_legs.clear()
	_wings.clear()
	_fins.clear()
	_arms.clear()
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
		CreatureDNA.Plan.GOLEM:
			_build_golem()
	_flush()
	if dna.is_eclipse() and dna.plan() == CreatureDNA.Plan.BIRD:
		_eclipse_rim()
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
			_pose_now = move_toward(_pose_now, pose_amount if pose != &"" else 0.0, delta * 5.0)
			for i in _legs.size():
				var offset := 0.0 if i == 0 or i == 3 else PI
				_legs[i].rotation.x = sin(_phase + offset) * swing
			if pose == &"paw" and not _legs.is_empty():
				# Raspa a pata da frente no chão antes de investir
				_legs[0].rotation.x = -0.25 * _pose_now + sin(t * 14.0) * 0.45 * _pose_now
			var rear := _pose_now if pose == &"rear" else 0.0
			_torso.rotation.x = rear * 0.42
			_torso.position.y = absf(sin(_phase)) * swing * 0.06 * f + sin(t * 1.6) * 0.008 + rear * 0.35 * f
			if pose == &"rear":
				# Patas da frente no ar, as de trás seguram o peso
				for i in [0, 1]:
					if i < _legs.size():
						_legs[i].rotation.x = -0.6 * rear
			if _head:
				var target_x := 0.95 if head_down else sin(_phase * 2.0) * swing * 0.12 + (0.25 if speed < 0.3 and fmod(t, 9.0) < 3.0 else 0.0)
				if pose == &"head_low" or pose == &"paw":
					# Negativo abaixa a cabeça e põe o chifre para a frente
					target_x = -0.6 * _pose_now
				_head.rotation.x = lerpf(_head.rotation.x, target_x, minf(1.0, delta * 8.0))
			if _tail:
				_tail.rotation.y = sin(t * 2.3) * 0.35
		CreatureDNA.Plan.BIRD:
			_pose_now = move_toward(_pose_now, pose_amount if pose != &"" else 0.0, delta * 5.0)
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
			# Poses de luta no chão (Matriarca do Eclipse): bicada puxa a cabeça para trás, rajada
			# abre as asas e bate forte, mergulho agacha antes do salto
			if not airborne and _pose_now > 0.01:
				match pose:
					&"head_low":
						if _head:
							_head.rotation.x = 0.7 * _pose_now
					&"rear":
						for i in _wings.size():
							var side := -1.0 if i == 0 else 1.0
							_wings[i].rotation.y = lerpf(_wings[i].rotation.y, 0.0, _pose_now)
							_wings[i].rotation.z = side * (0.3 + sin(t * 16.0) * 0.6) * _pose_now
					&"paw":
						_torso.position.y -= 0.25 * _pose_now * dna.size_factor()
			elif _head:
				_head.rotation.x = lerpf(_head.rotation.x, 0.0, minf(1.0, delta * 6.0))
		CreatureDNA.Plan.GOLEM:
			_animate_golem(delta, speed, t)
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
	# Chifre do focinho (Rinolito): pivô próprio, some quando quebra na luta
	if info.has("nose_horn"):
		horn_node = Node3D.new()
		horn_node.name = "NoseHorn"
		horn_node.position = skull + Vector3(0, head_size * 0.1, -head_size * 1.05)
		_head.add_child(horn_node)
		var nh: float = float(info["nose_horn"]) * f
		_cone(horn_node, head_size * 0.3, nh, Vector3(0, nh * 0.42, -nh * 0.12), Color(0.82, 0.76, 0.62), Basis(Vector3.RIGHT, -0.35))
		_cone(horn_node, head_size * 0.16, nh * 0.45, Vector3(0, head_size * 0.35, head_size * 0.5), Color(0.78, 0.72, 0.6), Basis(Vector3.RIGHT, -0.2))
	# Placas de carapaça no dorso (Rinolito): pivô próprio, somem quando a carapaça quebra
	if info.has("plates"):
		plates_node = Node3D.new()
		plates_node.name = "Plates"
		_torso.add_child(plates_node)
		var n: int = int(info["plates"])
		var plate_color := dna.coat_color().darkened(0.3)
		for i in n:
			var z := lerpf(-body.z * 0.36, body.z * 0.34, float(i) / float(maxi(n - 1, 1)))
			var k := sqrt(maxf(0.0, 1.0 - pow(z / (body.z * 0.52), 2.0)))
			var top := body_center + Vector3(0, body.y * 0.5 * k, z)
			_ellipsoid(plates_node, Vector3(body.x * 0.78 * k, body.y * 0.2, body.z * 0.2), top, plate_color.lightened(0.06 * (i % 2)))
			_cone(plates_node, body.x * 0.08, body.y * 0.28 * k, top + Vector3(0, body.y * 0.14, 0), plate_color.darkened(0.2), Basis.IDENTITY)
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

## Sentinela (GDD-18 §7.1): blocos de pedra empilhados em duas pernas, braços até o chão, núcleo
## no peito e blocos de couraça nos ombros e nas costas
func _build_golem() -> void:
	var info := dna.info()
	var f := dna.size_factor()
	var body: Vector3 = info["body"] * f
	var leg: float = float(info["leg"]) * f
	var arm: float = float(info.get("arm", 1.5)) * f
	var stone := dna.coat_color()
	var dark := dna.belly_color
	back_height = leg + body.y
	var center := Vector3(0, leg + body.y * 0.5, 0)
	_box(_torso, body, center, stone)
	_box(_torso, Vector3(body.x * 0.7, body.y * 0.35, body.z * 0.85), center - Vector3(0, body.y * 0.55, 0), dark)
	for side in [-1.0, 1.0]:
		var hip := Node3D.new()
		hip.position = Vector3(side * body.x * 0.25, leg, 0)
		_torso.add_child(hip)
		_box(hip, Vector3(body.x * 0.32, leg * 0.95, body.z * 0.55), Vector3(0, -leg * 0.5, 0), stone.darkened(0.08))
		_box(hip, Vector3(body.x * 0.38, leg * 0.18, body.z * 0.75), Vector3(0, -leg + leg * 0.09, -body.z * 0.08), dark)
		_legs.append(hip)
		var shoulder := Node3D.new()
		shoulder.position = center + Vector3(side * (body.x * 0.5 + body.x * 0.16), body.y * 0.3, 0)
		_torso.add_child(shoulder)
		_box(shoulder, Vector3(body.x * 0.3, arm * 0.55, body.z * 0.5), Vector3(0, -arm * 0.25, 0), stone.darkened(0.04))
		_box(shoulder, Vector3(body.x * 0.36, arm * 0.5, body.z * 0.6), Vector3(0, -arm * 0.72, -body.z * 0.05), stone.darkened(0.12))
		_arms.append(shoulder)
	_head = Node3D.new()
	_head.position = center + Vector3(0, body.y * 0.5, -body.z * 0.1)
	_torso.add_child(_head)
	var hs := body.x * 0.32
	_box(_head, Vector3(hs, hs * 0.85, hs * 0.9), Vector3(0, hs * 0.45, 0), stone.lightened(0.05))
	for side in [-1.0, 1.0]:
		_ellipsoid(_head, Vector3.ONE * hs * 0.16, Vector3(side * hs * 0.22, hs * 0.5, -hs * 0.46), info["core"])
	if info.has("plates"):
		plates_node = Node3D.new()
		plates_node.name = "Plates"
		_torso.add_child(plates_node)
		for side in [-1.0, 1.0]:
			_box(plates_node, Vector3(body.x * 0.42, body.y * 0.28, body.z * 0.8), center + Vector3(side * body.x * 0.62, body.y * 0.55, 0), stone.darkened(0.25))
		for i in maxi(0, int(info["plates"]) - 2):
			_box(plates_node, Vector3(body.x * 0.8, body.y * 0.25, body.z * 0.3), center + Vector3(0, body.y * (0.3 - i * 0.35), body.z * 0.6), stone.darkened(0.2))
	# Núcleo: malha própria com brilho (não vai para o lote do resto do corpo)
	core_node = Node3D.new()
	core_node.name = "Core"
	core_node.position = center + Vector3(0, body.y * 0.1, -body.z * 0.5)
	_torso.add_child(core_node)
	var gem := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = body.x * 0.16
	sm.height = body.x * 0.32
	gem.mesh = sm
	_core_mat = StandardMaterial3D.new()
	_core_mat.albedo_color = info["core"]
	_core_mat.emission_enabled = true
	_core_mat.emission = info["core"]
	gem.material_override = _core_mat
	core_node.add_child(gem)

func _animate_golem(delta: float, speed: float, t: float) -> void:
	var swing := clampf(speed / 4.0, 0.0, 1.0) * 0.45
	_pose_now = move_toward(_pose_now, pose_amount if pose != &"" else 0.0, delta * 4.0)
	var sit := _pose_now if pose == &"sit" else 0.0
	for i in _legs.size():
		_legs[i].rotation.x = sin(_phase + (0.0 if i == 0 else PI)) * swing - 1.2 * sit
	for i in _arms.size():
		var rest := -sin(_phase + (PI if i == 0 else 0.0)) * swing * 0.8
		match pose:
			&"head_low":
				# Punho: puxa o braço direito para trás
				rest += (0.9 if i == 1 else -0.2) * _pose_now
			&"rear":
				# Martelo: os dois braços sobem acima da cabeça
				rest -= 2.7 * _pose_now
			&"paw":
				# Avanço de ombro: braços para a frente
				rest -= 0.8 * _pose_now
		_arms[i].rotation.x = rest
	var leg: float = float(dna.info()["leg"]) * dna.size_factor()
	_torso.rotation.x = -0.35 * _pose_now if pose == &"paw" else 0.0
	_torso.position.y = -leg * 0.55 * sit + sin(t * 1.1) * 0.01
	if _core_mat:
		var pulse := core_glow * (0.85 + sin(t * 3.0) * 0.15)
		_core_mat.emission_energy_multiplier = 0.4 + pulse * 5.0

## Borda das asas que brilha (Planador do Eclipse): malha própria, por cima das asas
func _eclipse_rim() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = CreatureDNA.ECLIPSE_GLOW
	mat.emission_enabled = true
	mat.emission = CreatureDNA.ECLIPSE_GLOW
	mat.emission_energy_multiplier = 2.5
	var info := dna.info()
	var f := dna.size_factor()
	var body: Vector3 = info["body"] * f
	var span: float = float(info["wing"]) * f * 0.5
	for i in _wings.size():
		var side := -1.0 if i == 0 else 1.0
		var rim := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.5
		sm.height = 1.0
		rim.mesh = sm
		rim.material_override = mat
		rim.scale = Vector3(span * 0.95, 0.03 * f, body.z * 0.12)
		rim.position = Vector3(side * span * 0.55, 0.03, body.z * 0.3)
		_wings[i].add_child(rim)

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

func _box(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> void:
	var bm := BoxMesh.new()
	_append(parent, bm, "creature_box", Transform3D(Basis.IDENTITY.scaled(size), pos), color)

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
