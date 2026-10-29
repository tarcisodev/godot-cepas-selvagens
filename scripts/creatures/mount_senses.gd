class_name MountSenses
extends Node

## Sentidos da Companheira (GDD-16 §6), filho da Mount. Montado, segurar [Q] por HOLD_TIME:
## - Faro (faixa Parceira): rastros dos bichos num raio (pegadas no chão e o nome) por TRAIL_TIME;
##   a voadora no ar enxerga de cima, mais longe.
## - Olho de caça (Companheira plena): também marca as partes que quebram e a Vida (%) das presas
##   perto, por EYE_TIME. Ajuda a cansar sem matar (Exausto < 20%) e caçar Íntegro; não dá dano.
## Recarrega em COOLDOWN. As marcas são só de quem farejou; no online o servidor decide o que revela.

const HOLD_TIME: float = 1.0
const COOLDOWN: float = 45.0
const SCENT_RADIUS: float = 60.0
const SKY_RADIUS: float = 90.0
const TRAIL_TIME: float = 20.0
const EYE_RADIUS: float = 25.0
const EYE_TIME: float = 8.0
## Pegadas do rastro: quantas e o espaço entre elas, para trás do bicho
const PRINTS: int = 5
const PRINT_GAP: float = 0.9
const PART_NAMES: Dictionary = {&"horn": "Chifre", &"carapace": "Carapaça", &"leg": "Pata", &"tail": "Cauda", &"wing": "Asa"}

var mount: Mount
var cooldown: float = 0.0
var _hold: float = 0.0

func _ready() -> void:
	mount = get_parent() as Mount

func _process(delta: float) -> void:
	cooldown = maxf(0.0, cooldown - delta)
	if mount == null or mount.rider == null:
		_hold = 0.0
		return
	var tree := get_tree()
	var menus_open := tree != null and not tree.get_nodes_in_group("open_menus").is_empty()
	if Input.is_physical_key_pressed(KEY_Q) and not menus_open:
		_hold += delta
		if _hold >= HOLD_TIME:
			_hold = -INF # só uma vez por aperto
			use()
	else:
		_hold = 0.0

## Fareja agora. Devolve o motivo: &"ok", &"sem_elo" (precisa ser Companheira Parceira+) ou &"recarga"
func use() -> StringName:
	var p := mount.rider
	var bond := mount.bond
	if bond == null or not bond.companion or bond.band() < 2:
		_tell(p, "👃 Só a Companheira Parceira (Elo 50) empresta o faro")
		return &"sem_elo"
	if cooldown > 0.0:
		_tell(p, "👃 Faro recarregando (%d s)" % ceili(cooldown))
		return &"recarga"
	cooldown = COOLDOWN
	var eye := bond.band() >= MountBond.BAND_MIN.size() - 1
	var found := sniff()
	for c in found:
		_mark_trail(c)
	var prey := 0
	if eye:
		for c in found:
			if (c as Node3D).global_position.distance_to(mount.global_position) <= EYE_RADIUS:
				_mark_eye(c)
				prey += 1
	var what := "%d rastros" % found.size() if not found.is_empty() else "nenhum rastro"
	_tell(p, "👃 %s farejou: %s%s" % [mount.display_name, what, " · 👁 %d presas marcadas" % prey if eye and prey > 0 else ""])
	return &"ok"

## Bichos vivos no raio do faro (voadora no ar: raio de cima). Peixe não deixa rastro em terra.
func sniff() -> Array[Node3D]:
	var radius := SKY_RADIUS if mount.kind == Mount.Kind.AIR and mount.airborne else SCENT_RADIUS
	var out: Array[Node3D] = []
	for group in ["wild_creatures", "monsters"]:
		for n in mount.get_tree().get_nodes_in_group(group):
			var c := n as Node3D
			if c == null or c == mount or out.has(c) or c.is_in_group("fish"):
				continue
			if c.has_method("is_alive") and not c.is_alive():
				continue
			if c.global_position.distance_to(mount.global_position) <= radius:
				out.append(c)
	return out

static func creature_name(c: Node) -> String:
	var cfg: Variant = c.get("config")
	if cfg is Dictionary and cfg.has("name"):
		return str(cfg.name)
	var dna: Variant = c.get("dna")
	return (dna as CreatureDNA).species_name().get_slice("-", 0) if dna is CreatureDNA else "Bicho"

## Pegadas para trás do bicho (de onde ele veio) e o nome em cima delas; somem em TRAIL_TIME
func _mark_trail(c: Node3D) -> void:
	var root := _marks_parent()
	var trail := Node3D.new()
	trail.name = "Rastro"
	trail.add_to_group("scent_marks")
	trail.add_to_group("scent_trails")
	root.add_child(trail)
	var back := c.global_transform.basis.z
	back.y = 0.0
	back = back.normalized() if back.length() > 0.01 else Vector3.BACK
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.95, 0.78, 0.35, 0.85)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true
	for i in PRINTS:
		var pos := c.global_position + back * (PRINT_GAP * (i + 1))
		var side := back.cross(Vector3.UP) * (0.16 if i % 2 == 0 else -0.16)
		var mesh := MeshInstance3D.new()
		var disc := CylinderMesh.new()
		disc.top_radius = 0.13
		disc.bottom_radius = 0.13
		disc.height = 0.02
		mesh.mesh = disc
		mesh.material_override = mat
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		trail.add_child(mesh)
		mesh.global_position = Vector3(pos.x + side.x, mount._ground(pos.x, pos.z) + 0.03, pos.z + side.z)
	var label := _label("🐾 %s · %d m" % [creature_name(c), roundi(c.global_position.distance_to(mount.global_position))], Color(0.95, 0.85, 0.55))
	trail.add_child(label)
	label.global_position = c.global_position + Vector3(0, 1.6, 0)
	_expire(trail, TRAIL_TIME)

## Olho de caça: partes que quebram e Vida (%), presas no bicho (acompanham ele) por EYE_TIME
func _mark_eye(c: Node3D) -> void:
	var eye := Node3D.new()
	eye.name = "OlhoDeCaca"
	eye.add_to_group("scent_marks")
	eye.add_to_group("scent_eyes")
	c.add_child(eye)
	var pools: Variant = c.get("pools")
	var stats: Variant = c.get("stats")
	if pools is PoolsComponent and stats is StatsComponent:
		var frac: float = (pools as PoolsComponent).current_health / maxf(1.0, (stats as StatsComponent).get_stat(&"max_health"))
		var hp := _label("❤ %d%%" % roundi(frac * 100.0), Color(1.0, 0.45, 0.4) if frac < 0.2 else Color(0.95, 0.9, 0.9))
		eye.add_child(hp)
		hp.position = Vector3(0, 2.2, 0)
	for hb in c.find_children("*", "HurtboxComponent", true, false):
		var part: StringName = (hb as HurtboxComponent).part_id
		if part == &"body" or part.is_empty():
			continue
		var mark := _label("◎ %s" % PART_NAMES.get(part, String(part).capitalize()), Color(1.0, 0.35, 0.3))
		eye.add_child(mark)
		mark.global_position = (hb as Node3D).global_position
	_expire(eye, EYE_TIME)

func _label(text: String, color: Color) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.font_size = 22
	l.outline_size = 6
	l.modulate = color
	l.visibility_range_end = SKY_RADIUS + 20.0
	return l

func _expire(node: Node, seconds: float) -> void:
	var t := Timer.new()
	t.one_shot = true
	t.wait_time = seconds
	t.timeout.connect(node.queue_free)
	node.add_child(t)
	t.start()

func _marks_parent() -> Node:
	var tree := mount.get_tree()
	return tree.current_scene if tree.current_scene else tree.root

func _tell(p: Node, msg: String) -> void:
	if p and p.has_signal("posture_changed"):
		p.posture_changed.emit(msg)
