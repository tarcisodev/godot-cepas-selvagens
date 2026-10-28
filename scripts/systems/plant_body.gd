class_name PlantBody
extends Node3D

## Planta procedural (GDD-09 §3) montada a partir do PlantDNA. Todas as partes viram UMA
## malha com cor por vértice (1 chamada de desenho por planta), para caber centenas no vale.
## Árvores ganham colisão no tronco; o cogumelo-lume tem chapéu que brilha à noite.
## Ciclo de vida (GDD-10 §4): semente → broto → jovem → adulta → florida → com fruto → (semeia)
## → volta a adulta; cresce com água, nutriente e luz da célula de solo (Ecology); definha sem
## isso e morre de velhice ou de penúria, devolvendo nutriente.

enum Stage { SEMENTE, BROTO, JOVEM, ADULTA, FLORIDA, FRUTO }

## Dias de jogo em cada estágio [semente, broto, jovem, adulta→flor, florida, fruto] e vida total
const TIMES: Dictionary = {
	PlantDNA.Kind.ARVORE: [0.3, 0.8, 2.0, 1.5, 0.6, 0.8, 20.0],
	PlantDNA.Kind.ARBUSTO: [0.2, 0.5, 1.0, 0.8, 0.5, 0.6, 12.0],
	PlantDNA.Kind.CEPA: [0.1, 0.25, 0.4, 0.3, 0.3, 0.3, 5.0],
	PlantDNA.Kind.COGUMELO: [0.1, 0.15, 0.2, 0.4, 0.2, 0.2, 3.0],
	# Pinheira-Lume (GDD-10 §9): o broto aparece 2 dias depois de plantar
	PlantDNA.Kind.PINHEIRA: [2.0, 1.5, 3.0, 1.5, 1.0, 1.5, 40.0],
}
## Escala visual por estágio
const STAGE_SCALE: Array[float] = [0.0, 0.18, 0.5, 1.0, 1.0, 1.0]
## A Pinheira cresce contínuo dentro da etapa: escala [no começo, no fim] de cada estágio.
## O broto sobe de 13 cm a 60 cm; a jovem sai do chão a 6% da árvore (~75 cm) e chega inteira.
const PINHEIRA_GROWTH: Array = [[1.0, 1.0], [0.35, 1.6], [0.06, 1.0], [1.0, 1.0], [1.0, 1.0], [1.0, 1.0]]
## Quão rápido o tamanho na tela alcança o do progresso (1/s); o progresso só anda a cada tick da Ecology
const GROW_FOLLOW: float = 1.5
## Duração da troca de etapa (s): a malha velha some enquanto a nova cresce
const STAGE_BLEND: float = 0.7
## Luz da Pinheira adulta: alcance máximo (m) com brilho forte
const LUME_RANGE: float = 8.0
## Quanto aguenta sem água/nutriente antes de morrer (dias)
const STARVE_DAYS: float = 1.5

@export var dna: PlantDNA
@export var stage: Stage = Stage.ADULTA

var age: float = 0.0
var progress: float = 0.0
var stress: float = 0.0
## Plantada num Canteiro de Cultivo: solo regado e adubado fixo (GDD-10 §9)
var garden: bool = false
## Adubada com Adubo de Monstro (fertilizante mineralizado)
var is_fertilized: bool = false
## Quem plantou (vazio = nasceu sozinha)
var planted_by: String = ""

var _st: MeshBatch
var _glow: MeshBatch
var _rng := RandomNumberGenerator.new()
var _crown: Array[Vector3] = []
## Escala que está na tela (persegue growth_scale) e o fator da transição de etapa
var _shown: float = 1.0
var _pop: float = 1.0
static var _material: StandardMaterial3D
static var _glow_material: StandardMaterial3D

func _ready() -> void:
	add_to_group("plants")
	if dna == null:
		dna = PlantDNA.randomized(PlantDNA.Kind.ARVORE, 1)
	if dna.kind == PlantDNA.Kind.PINHEIRA:
		add_to_group("pinheiras")
		add_to_group("harvestable") # sacudir a árvore com pinhas
	build()

func lifespan() -> float:
	return TIMES[dna.kind][6] * (1.2 if dna.mutant else 1.0)

## Aplica Adubo de Monstro: acelera crescimento em +50% e potencializa mutações
func fertilize() -> bool:
	if is_fertilized:
		return false
	is_fertilized = true
	if is_inside_tree() and dna and dna.kind == PlantDNA.Kind.PINHEIRA:
		_sparkle()
	return true

## Um passo de vida: `cell` = {"moisture", "nutrients"} da célula; `light` = é dia.
## Devolve o que a planta tirou do solo e o que aconteceu: {"water", "food", "event"},
## event = "", "grew", "seeds" ou "died".
func life_tick(days: float, cell: Dictionary, light: bool) -> Dictionary:
	age += days
	var out := {"water": 0.0, "food": 0.0, "event": ""}
	var need_w := 0.3 if dna.kind == PlantDNA.Kind.COGUMELO else 0.2
	var ok: bool = cell.get("moisture", 0.0) >= need_w and cell.get("nutrients", 0.0) >= 0.12
	if dna.kind == PlantDNA.Kind.COGUMELO:
		light = true # cogumelo não precisa de sol
	if age > lifespan() or stress > STARVE_DAYS:
		out.event = "died"
		return out
	if not light:
		return out
	if not ok:
		stress += days
		return out
	stress = maxf(0.0, stress - days * 0.5)
	var growing := stage < Stage.ADULTA
	var growth_mult := 1.5 if is_fertilized else 1.0
	out.water = days * (0.25 if growing else 0.12)
	out.food = days * (0.12 if growing else 0.05)
	progress += (days * growth_mult) / float(TIMES[dna.kind][stage])
	if progress >= 1.0:
		progress = 0.0
		if stage == Stage.FRUTO:
			stage = Stage.ADULTA
			out.event = "seeds"
		else:
			stage = (stage + 1) as Stage
			out.event = "grew"
		build(true, out.event == "grew")
	return out

## Escala que a planta deve ter agora; a Pinheira acompanha o progresso dentro da etapa
func growth_scale() -> float:
	if dna.kind == PlantDNA.Kind.PINHEIRA:
		var g: Array = PINHEIRA_GROWTH[stage]
		return lerpf(g[0], g[1], clampf(progress, 0.0, 1.0))
	return maxf(STAGE_SCALE[stage], 0.001)

## Só a Pinheira de broto ou jovem cresce na frente do jogador (no máximo 36 no vale)
func grows_visibly() -> bool:
	return dna.kind == PlantDNA.Kind.PINHEIRA and (stage == Stage.BROTO or stage == Stage.JOVEM)

func _process(delta: float) -> void:
	_shown = lerpf(_shown, growth_scale(), 1.0 - exp(-delta * GROW_FOLLOW))
	_apply_scale()

func _apply_scale() -> void:
	scale = Vector3.ONE * maxf(_shown * _pop, 0.001)

## Monta a malha do estágio atual. `animate`: troca de etapa à vista (a velha some, a nova cresce);
## `sparkle`: faíscas na cor do lume quando a planta sobe de etapa.
func build(animate: bool = false, sparkle: bool = false) -> void:
	var old: Array[Node] = get_children()
	var old_scale := scale.x
	var blend := animate and is_inside_tree()
	if not blend:
		for c in old:
			c.free()
		old.clear()
	_shown = growth_scale()
	_pop = 1.0
	_apply_scale()
	_build_meshes()
	set_process(grows_visibly())
	if blend:
		_blend_from(old, old_scale)
		if sparkle and dna.kind == PlantDNA.Kind.PINHEIRA:
			_sparkle()

## Troca de etapa sem salto. Se o tamanho muda (pinhão → broto → jovem), a malha velha encolhe
## até sumir enquanto a nova sai do zero; se é o mesmo tamanho, a árvore só "respira".
func _blend_from(old: Array[Node], old_scale: float) -> void:
	# A malha velha vai para um irmão no lugar da planta, com a escala que tinha: assim
	# a transição da nova (que mexe na escala do corpo) não a arrasta junto
	var leaving := Node3D.new()
	leaving.name = "PlantaSaindo"
	get_parent().add_child(leaving)
	leaving.global_transform = Transform3D(global_basis.orthonormalized().scaled(Vector3.ONE * old_scale), global_position)
	for c in old:
		if c is CPUParticles3D:
			continue # faíscas de uma troca anterior terminam sozinhas
		if c is CollisionObject3D or c is Light3D:
			c.free() # a colisão e a luz já vêm da malha nova
		else:
			c.reparent(leaving, false)
	var resized := absf(old_scale - scale.x) > 0.05 * maxf(old_scale, scale.x)
	var from := 0.0 if resized else 0.94
	_set_pop(from) # já neste quadro, antes do tween dar o primeiro passo
	var tw := create_tween().set_parallel()
	tw.tween_method(_set_pop, from, 1.0, STAGE_BLEND) \
		.set_trans(Tween.TRANS_BACK if not resized else Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if resized:
		tw.tween_property(leaving, "scale", Vector3.ONE * 0.001, STAGE_BLEND).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tw.chain().tween_callback(leaving.queue_free)
	else:
		leaving.free()

func _set_pop(v: float) -> void:
	_pop = v
	_apply_scale()

## Faíscas na cor do lume subindo da planta quando ela muda de etapa
func _sparkle() -> void:
	var p := CPUParticles3D.new()
	p.name = "Faiscas"
	p.top_level = true
	add_child(p)
	var tall := (12.0 * dna.size_factor() if stage >= Stage.JOVEM else 0.5) * scale.x
	p.global_position = global_position + Vector3.UP * maxf(tall * 0.5, 0.25)
	p.one_shot = true
	p.explosiveness = 0.6
	p.amount = 28
	p.lifetime = 1.4
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = maxf(tall * 0.35, 0.3)
	p.direction = Vector3.UP
	p.spread = 35.0
	p.gravity = Vector3(0, 0.4, 0)
	p.initial_velocity_min = 0.3
	p.initial_velocity_max = 0.9
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	p.scale_amount_curve = curve
	var sm := SphereMesh.new()
	sm.radius = 0.035
	sm.height = 0.07
	sm.radial_segments = 6
	sm.rings = 3
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = dna.lume_color().lightened(0.3)
	sm.material = m
	p.mesh = sm
	p.emitting = true
	p.finished.connect(p.queue_free)

func _build_meshes() -> void:
	var pinheira := dna.kind == PlantDNA.Kind.PINHEIRA
	if stage == Stage.SEMENTE:
		if dna.kind == PlantDNA.Kind.PINHEIRA:
			# Pinhão plantado: só um montinho de terra marca o lugar até o broto sair
			var mound := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.16
			sm.height = 0.1
			sm.radial_segments = 8
			sm.rings = 3
			mound.mesh = sm
			var soil := StandardMaterial3D.new()
			soil.albedo_color = Color(0.3, 0.2, 0.13)
			soil.roughness = 1.0
			mound.material_override = soil
			mound.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mound)
		return
	_rng.seed = dna.dna_seed
	_crown.clear()
	_st = MeshBatch.new()
	_glow = MeshBatch.new()
	match dna.kind:
		PlantDNA.Kind.PINHEIRA:
			if stage == Stage.BROTO:
				_build_pinheira_sprout()
			else:
				_build_pinheira()
		PlantDNA.Kind.ARVORE:
			_build_tree()
		PlantDNA.Kind.ARBUSTO:
			_build_bush()
		PlantDNA.Kind.CEPA:
			_build_cepa()
		PlantDNA.Kind.COGUMELO:
			_build_mushrooms()
	var mi := MeshInstance3D.new()
	mi.mesh = _st.commit()
	mi.material_override = _shared_material()
	# A Pinheira é alta e acende à noite: marco de longe
	mi.visibility_range_end = 220.0 if pinheira else 110.0
	# Plantas baixas e novas: a sombra quase não aparece e dobra o custo de desenho
	if dna.kind == PlantDNA.Kind.CEPA or dna.kind == PlantDNA.Kind.COGUMELO or stage < Stage.ADULTA:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	if not _glow.is_empty():
		var gi := MeshInstance3D.new()
		gi.mesh = _glow.commit()
		gi.material_override = PinhaShape.glow_material()
		gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		gi.visibility_range_end = mi.visibility_range_end
		add_child(gi)
	if dna.mutant and stage >= Stage.JOVEM:
		_add_mutant_glow()

## Brilho de esporos em volta da planta mutante (o "raro" que se vê de longe)
func _add_mutant_glow() -> void:
	if _glow_material == null:
		_glow_material = StandardMaterial3D.new()
		_glow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_glow_material.vertex_color_use_as_albedo = true
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var height := 10.0 if dna.kind == PlantDNA.Kind.PINHEIRA else (4.0 if dna.kind == PlantDNA.Kind.ARVORE else 1.2)
	var sm := SphereMesh.new()
	sm.radius = 0.06
	sm.height = 0.12
	sm.radial_segments = 6
	sm.rings = 3
	var arrays := sm.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for i in 10:
		var p := Vector3(_rng.randf_range(-0.8, 0.8), _rng.randf_range(0.3, 1.0) * height, _rng.randf_range(-0.8, 0.8))
		for idx in indices:
			st.set_color(dna.flower_color.lightened(0.3))
			st.add_vertex(verts[idx] + p)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _glow_material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

static func _shared_material() -> StandardMaterial3D:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.vertex_color_use_as_albedo = true
		_material.vertex_color_is_srgb = true
		_material.roughness = 0.9
	return _material

# ---------------------------------------------------------------- tipos

func _build_tree() -> void:
	var f := dna.size_factor()
	var h := (4.5 + _rng.randf() * 1.5) * f
	var trunk_r := 0.2 * f
	_add_cylinder(Vector3.ZERO, Vector3(0, h * 0.62, 0), trunk_r, trunk_r * 0.7, dna.trunk_color)
	var crown_y := h * 0.62
	for i in dna.branches:
		var a := TAU * i / dna.branches + _rng.randf() * 0.4
		var start := Vector3(0, crown_y * _rng.randf_range(0.7, 0.95), 0)
		var dir := Vector3(cos(a), _rng.randf_range(0.5, 0.9), sin(a)).normalized()
		var end := start + dir * h * _rng.randf_range(0.28, 0.4)
		_add_cylinder(start, end, trunk_r * 0.45, trunk_r * 0.25, dna.trunk_color)
		var blob_size := h * _rng.randf_range(0.2, 0.28)
		_add_blob(end + Vector3(0, 0.25 * f, 0), Vector3.ONE * blob_size, _leaf_variant())
		_crown.append(end + Vector3(0, 0.25 * f, 0))
		_crown.append(Vector3(blob_size * 0.5, 0, 0))
	_add_blob(Vector3(0, h * 0.85, 0), Vector3(h * 0.38, h * 0.32, h * 0.38), _leaf_variant())
	_crown.append(Vector3(0, h * 0.85, 0))
	_crown.append(Vector3(h * 0.19, 0, 0))
	_add_blossoms_or_fruit(0.09 * f, 0.13 * f)
	# Colisão só no tronco
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = trunk_r
	shape.height = h * 0.62
	col.shape = shape
	col.position.y = h * 0.31
	body.add_child(col)
	add_child(body)

func _build_bush() -> void:
	var f := dna.size_factor()
	var n := _rng.randi_range(3, 5)
	for i in n:
		var a := TAU * i / n
		var p := Vector3(cos(a) * 0.35 * f, 0.35 * f, sin(a) * 0.35 * f)
		var blob := _rng.randf_range(0.55, 0.8) * f
		_add_blob(p, Vector3.ONE * blob, _leaf_variant())
		_crown.append(p)
		_crown.append(Vector3(blob * 0.5, 0, 0))
	_add_blossoms_or_fruit(0.07 * f, 0.08 * f)

func _build_cepa() -> void:
	var f := dna.size_factor()
	var h := (1.5 + _rng.randf() * 0.6) * f
	_add_cylinder(Vector3.ZERO, Vector3(0, h, 0), 0.05 * f, 0.03 * f, dna.leaf_color.darkened(0.3))
	var levels := 4
	for lv in levels:
		var y := h * (0.25 + 0.7 * lv / float(levels))
		var sc := (1.0 - lv * 0.18) * f
		for side in 2:
			var a := lv * 1.1 + side * PI
			_add_fan_leaf(Vector3(0, y, 0), a, 0.55 * sc)
	# Botão no topo, com a cor da "flor" do gene
	var bud := dna.leaf_color.lerp(dna.flower_color, 0.6) if stage >= Stage.FLORIDA else dna.leaf_color.darkened(0.1)
	_add_blob(Vector3(0, h + 0.08 * f, 0), Vector3(0.2, 0.34, 0.2) * f, bud)

## Folha em leque (5–7 folíolos), a marca visual da Cepa Selvagem
func _add_fan_leaf(origin: Vector3, yaw: float, length: float) -> void:
	var count := 7
	for i in count:
		var spread := lerpf(-1.1, 1.1, i / float(count - 1))
		var l := length * (1.0 - absf(spread) * 0.35)
		var dir := Basis(Vector3.UP, yaw) * Vector3(sin(spread) * 0.9, 0.35 + cos(spread) * 0.25, cos(spread)).normalized()
		var center := origin + dir * l * 0.55
		var rot := Basis.looking_at(dir, Vector3.UP)
		_add_sphere(Transform3D(rot.scaled(Vector3(0.18 * l, 0.03, 1.0 * l)), center), dna.leaf_color.lerp(Color(0.1, 0.25, 0.1), _rng.randf() * 0.2))

func _build_mushrooms() -> void:
	var f := dna.size_factor()
	var n := _rng.randi_range(3, 5)
	var caps := Node3D.new()
	add_child(caps)
	for i in n:
		var a := _rng.randf() * TAU
		var r := _rng.randf_range(0.0, 0.3) * f
		var base := Vector3(cos(a) * r, 0, sin(a) * r)
		var h := _rng.randf_range(0.18, 0.4) * f
		_add_cylinder(base, base + Vector3(0, h, 0), 0.04 * f, 0.035 * f, dna.leaf_color)
		# Chapéu em malha própria, emissiva, para brilhar no escuro
		var cap := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.12 * f * (h / (0.3 * f))
		sm.height = sm.radius
		sm.is_hemisphere = true
		sm.radial_segments = 10
		sm.rings = 4
		cap.mesh = sm
		cap.position = base + Vector3(0, h, 0)
		var m := StandardMaterial3D.new()
		m.albedo_color = dna.flower_color
		m.emission_enabled = true
		m.emission = dna.flower_color
		m.emission_energy_multiplier = 1.2
		cap.material_override = m
		caps.add_child(cap)

## Florida: flores na copa; com fruto: frutos pendurados
func _add_blossoms_or_fruit(flower_size: float, fruit_size: float) -> void:
	if stage < Stage.FLORIDA or _crown.is_empty():
		return
	var fruit_color := Color(0.75, 0.12, 0.2).lerp(dna.flower_color, 0.25)
	for i in 14:
		var k := (_rng.randi() % (_crown.size() / 2)) * 2
		var c: Vector3 = _crown[k]
		var r: float = _crown[k + 1].x
		var dir := Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-0.6, 1.0), _rng.randf_range(-1, 1)).normalized()
		var p := c + dir * r * 0.95
		if stage == Stage.FLORIDA:
			_add_flower(p, flower_size)
		else:
			_add_sphere(Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * fruit_size), p - Vector3(0, fruit_size * 0.5, 0)), fruit_color)

# ---------------------------------------------------------------- Pinheira-Lume (GDD-10 §9)

## Broto: caule fino, dois cotilédones, tufos de agulha e um botão aceso na ponta
func _build_pinheira_sprout() -> void:
	var stem := 0.38
	_add_cylinder(Vector3.ZERO, Vector3(0, stem, 0), 0.018, 0.012, dna.leaf_color.darkened(0.2))
	for side in 2:
		var a := side * PI + _rng.randf() * 0.3
		var dir := Vector3(cos(a), 0.35, sin(a)).normalized()
		_add_needles(Vector3(0, 0.1, 0) + dir * 0.06, dir, 0.13, dna.leaf_color.lightened(0.15))
	for i in 3:
		var a := TAU * i / 3.0 + 0.5
		var dir := Vector3(cos(a), 0.9, sin(a)).normalized()
		_add_needles(Vector3(0, stem * 0.8, 0) + dir * 0.04, dir, 0.1, dna.leaf_color)
	_add_glow(Vector3(0, stem + 0.03, 0), Vector3.ONE * 0.06, dna.lume_color(), 0.8)

func _build_pinheira() -> void:
	var f := dna.size_factor()
	var h := (12.0 + _rng.randf() * 1.5) * f
	var rb := 0.34 * f
	var lean := Vector3(_rng.randf_range(-0.2, 0.2), 0, _rng.randf_range(-0.2, 0.2)) * f
	var top := Vector3(0, h, 0) + lean
	_add_cylinder(Vector3.ZERO, top, rb, rb * 0.4, dna.trunk_color)
	var copa := dna.copa_type()
	# Faixa de altura dos verticilos, comprimento dos galhos (base → topo), subida do galho e da ponta
	var y0 := 0.78
	var len0 := 0.27
	var len1 := 0.12
	var rise := 0.12
	var tip := 0.55
	var per_whorl := 5
	var whorls := dna.branches
	match copa:
		PlantDNA.Copa.CONE:
			y0 = 0.28; len0 = 0.3; len1 = 0.05; rise = -0.12; tip = 0.3
		PlantDNA.Copa.CHORONA:
			y0 = 0.62; len0 = 0.25; len1 = 0.13; rise = 0.18; tip = -0.85
		PlantDNA.Copa.ESPIRAL:
			y0 = 0.35; len0 = 0.28; len1 = 0.06; rise = 0.05; tip = 0.45
			per_whorl = 3
			whorls *= 2
	var glow_a := dna.glow_strength() * (0.55 if stage == Stage.JOVEM else 1.0)
	for w in whorls:
		var t := w / float(maxi(1, whorls - 1))
		var y := lerpf(y0, 0.97, t)
		var center := Vector3(0, h * y, 0) + lean * y
		var L := h * lerpf(len0, len1, t)
		var offset := w * PlantDNA.GOLDEN_ANGLE if copa == PlantDNA.Copa.ESPIRAL else w * 0.6
		for b in per_whorl:
			var a := offset + TAU * b / per_whorl + _rng.randf_range(-0.15, 0.15)
			var out := Vector3(cos(a), 0, sin(a))
			var mid := center + out * L * 0.65 + Vector3.UP * L * rise
			var end := mid + out * L * 0.35 + Vector3.UP * L * tip
			_add_cylinder(center, mid, 0.08 * f, 0.05 * f, dna.trunk_color)
			_add_cylinder(mid, end, 0.05 * f, 0.03 * f, dna.trunk_color)
			# Tufos de agulhas em corda: um ao longo da ponta e dois menores no meio do galho
			_add_needles(mid, (end - mid).normalized(), L * 0.5, _leaf_variant())
			for k in 2:
				var p := center.lerp(mid, 0.45 + k * 0.3)
				var side := out.cross(Vector3.UP) * (1.0 if k == 0 else -1.0)
				_add_needles(p, (side + out * 0.6 + Vector3.UP * 0.4).normalized(), L * 0.22, _leaf_variant())
			_add_glow(end, Vector3.ONE * 0.2 * f, dna.lume_color(), glow_a)
			if stage == Stage.FLORIDA:
				# Estróbilos de pólen: espigas acesas, mais claras, apontando para cima
				_add_glow(end + Vector3.UP * 0.22 * f, Vector3(0.1, 0.32, 0.1) * f, dna.lume_color().lightened(0.4), glow_a)
			if t > 0.45:
				_crown.append(mid)
	_add_needles(top, Vector3.UP, h * 0.07, _leaf_variant())
	_add_glow(top + Vector3.UP * h * 0.06, Vector3.ONE * 0.25 * f, dna.lume_color(), glow_a)
	if stage == Stage.FRUTO:
		_add_pinhas(f)
	if stage >= Stage.ADULTA:
		_add_lume_light(h * 0.85)
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = rb
	shape.height = h * 0.9
	col.shape = shape
	col.position.y = h * 0.45
	body.add_child(col)
	add_child(body)

## Pinhas em cima dos galhos do alto, como na araucária
func _add_pinhas(f: float) -> void:
	if _crown.is_empty():
		return
	var count := mini(_crown.size(), 4 + _rng.randi() % 4)
	var picks := _crown.duplicate()
	for i in count:
		var p: Vector3 = picks.pop_at(_rng.randi() % picks.size())
		var size := 0.55 * f
		PinhaShape.append(_glow, _st, dna, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * size), p + Vector3.UP * size * 0.45))

## Luz na copa da adulta; a força e a hora de acender ficam com a Ecology (grupo `lume_lights`)
func _add_lume_light(y: float) -> void:
	var light := OmniLight3D.new()
	light.name = "Lume"
	light.position.y = y
	light.light_color = dna.lume_color()
	light.omni_range = LUME_RANGE * (0.5 + 0.5 * dna.glow_strength())
	light.omni_attenuation = 1.4
	light.shadow_enabled = false
	light.light_energy = 0.0
	light.distance_fade_enabled = true
	light.distance_fade_begin = 70.0
	light.distance_fade_length = 25.0
	light.set_meta("strength", dna.glow_strength())
	light.add_to_group("lume_lights")
	add_child(light)

## Tufo de agulhas: fuso alongado na direção `dir`
func _add_needles(origin: Vector3, dir: Vector3, length: float, color: Color) -> void:
	var up := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.98 else Vector3.FORWARD
	var b := Basis.looking_at(dir, up) * Basis.from_scale(Vector3(length * 0.32, length * 0.32, length))
	_add_sphere(Transform3D(b, origin + dir * length * 0.45), color)

func _add_glow(center: Vector3, size: Vector3, color: Color, strength: float) -> void:
	var c := color
	c.a = strength
	PinhaShape._add(_glow, Transform3D(Basis.IDENTITY.scaled(size), center), c)

## Contrato 'harvestable' do Player: sacudir a Pinheira com pinhas derruba 2 (GDD-10 §9)
func is_harvestable() -> bool:
	return dna.kind == PlantDNA.Kind.PINHEIRA and stage == Stage.FRUTO

func next_harvest_label() -> String:
	return "Pinhas da Pinheira-Lume"

func get_harvest_verb() -> String:
	return "Sacudindo"

func get_gather_time(_mastery = null) -> float:
	return 1.5

func harvest_next(_harvester: Node = null) -> String:
	if not is_harvestable():
		return ""
	var eco := get_tree().get_first_node_in_group("ecology") if is_inside_tree() else null
	if eco:
		eco.drop_pinhas(self, 2)
	stage = Stage.ADULTA
	progress = 0.0
	build(true)
	return "2 Pinhas-Lume caíram"

# ---------------------------------------------------------------- malha

func _leaf_variant() -> Color:
	return dna.leaf_color.lerp(Color(0.15, 0.3, 0.12) if _rng.randf() < 0.5 else Color(0.55, 0.7, 0.3), _rng.randf() * 0.18)

func _add_flower(p: Vector3, size: float) -> void:
	for i in dna.petals:
		var a := TAU * i / dna.petals
		var off := Vector3(cos(a), 0, sin(a)) * size * 0.6
		_add_sphere(Transform3D(Basis.IDENTITY.scaled(Vector3(size * 0.6, size * 0.25, size * 0.6)), p + off), dna.flower_color)
	_add_sphere(Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * size * 0.45), p + Vector3(0, size * 0.1, 0)), Color(0.98, 0.85, 0.3))

func _add_blob(center: Vector3, size: Vector3, color: Color) -> void:
	_add_sphere(Transform3D(Basis.IDENTITY.scaled(size), center), color)

func _add_sphere(xform: Transform3D, color: Color) -> void:
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 8
	sm.rings = 5
	_st.append(MeshBatch.arrays_of(sm, "plant_sphere"), xform, color)

func _add_cylinder(a: Vector3, b: Vector3, r_bottom: float, r_top: float, color: Color) -> void:
	var cm := CylinderMesh.new()
	cm.bottom_radius = r_bottom
	cm.top_radius = r_top
	cm.height = a.distance_to(b)
	cm.radial_segments = 7
	cm.rings = 1
	var up := (b - a).normalized()
	var side := up.cross(Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.95 else Vector3.RIGHT).normalized()
	var rot := Basis(side, up, side.cross(up))
	_st.append(MeshBatch.arrays_of(cm), Transform3D(rot, (a + b) * 0.5), color)
