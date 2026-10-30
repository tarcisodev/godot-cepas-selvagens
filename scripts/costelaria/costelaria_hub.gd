class_name CostelariaHub
extends Node3D

## A Costelária (B38, GDD-17): segunda base, dentro do esqueleto do Colosso, a oeste do vale.
## Monta a cidade (esqueleto, cerca de presas, casas, bairros), o elenco completo com a Ficha
## do NPC e as ações de cada papel: comprar, vender, encomendas, Lições e Técnicas dos
## mestres, Compêndio, "Onde fica?", notícias da Pregoeira, rumo da Cartógrafa e a rotina
## de cada morador pelo relógio único.
##
## O nó fica no centro da planta, girado (CostelariaLayout.YAW): os filhos usam o referencial
## do Colosso direto (x = lx, z = lz). Economia, Reputação e Compêndio são estado da cidade
## (no online, do servidor; as páginas do Compêndio, do personagem).

const _Layout = preload("res://scripts/costelaria/costelaria_layout.gd")
const _Cast = preload("res://scripts/costelaria/costelaria_cast.gd")
const _Economy = preload("res://scripts/costelaria/costelaria_economy.gd")
const _Techniques = preload("res://scripts/costelaria/master_techniques.gd")
const _Compendium = preload("res://scripts/costelaria/compendium.gd")
const _Skeleton = preload("res://scripts/costelaria/colosso_skeleton.gd")
const _NpcProfile = preload("res://scripts/npc/npc_profile.gd")
const _NpcAction = preload("res://scripts/npc/npc_action.gd")
const _NpcDialog = preload("res://scripts/ui/npc_dialog.gd")
const _TownNPC = preload("res://scripts/town/town_npc.gd")
const _WorldLabel = preload("res://scripts/ui/world_label.gd")
const _MaterialData = preload("res://scripts/data/material_data.gd")
const _ForgeStation = preload("res://scripts/town/forge_station.gd")
const DUMMY_SCENE = preload("res://scenes/dummy_creature.tscn")
const FANTASY := "res://assets/models/props/fantasy/"

## Rumo da Cartógrafa (bússola até um assentamento ou marco)
const ROUTE_PRICE: int = 5
## Velocidade dos moradores indo e voltando do posto (m/s reais)
const WALK_SPEED: float = 2.2
## Lições do Pátio: tempo (s reais) e alvo por faixa
const LESSON_SECONDS: float = 45.0
## Onde treinar cada maestria: id de bairro da Costelária ou de assentamento/marco do mundo
const TRAIN_SPOTS: Dictionary = {
	&"lâmina": &"pelvis", &"concussão": &"pelvis", &"canalização": &"pelvis", &"esfola": &"covil_besta",
	&"forja": &"pulmao_oeste", &"mineracao": &"vigia_norte", &"coleta": &"bosque_lume", &"culinaria": &"pulmao_leste", &"elo": &"cauda",
}

@export var landscape: Node3D

var economy := _Economy.new()
## id → TownNPC
var npcs: Dictionary = {}
## Páginas do Compêndio abertas (ids)
var pages: Array[StringName] = []
## Lição em andamento: {"tag", "band", "kind", "goal", "count", "time_left", "player"}; vazio = nenhuma
var lesson: Dictionary = {}
## Último destino da bússola (nome, posição no mundo) — a Ficha e os testes leem
var last_compass: Dictionary = {}
var skeleton: ColossoSkeleton

var _rng := RandomNumberGenerator.new()
var _scene_cache: Dictionary = {}
var _mat_cache: Dictionary = {}
var _night_lights: Array[OmniLight3D] = []
var _lantern_mat: StandardMaterial3D
var _crystal: MeshInstance3D
var _last_hit_target: Node = null
var _watched_mastery: MasteryComponent = null

func _ready() -> void:
	add_to_group("costelaria")
	position = Vector3(_Layout.CENTER.x, _Layout.PLATEAU_Y, _Layout.CENTER.y)
	rotation.y = _Layout.YAW
	_rng.seed = 3800
	economy.ensure_day(_day())

	skeleton = _Skeleton.new()
	skeleton.name = "EsqueletoDoColosso"
	skeleton.ground = ground
	add_child(skeleton)
	_build_fence()
	_build_gate()
	_build_heart()
	_build_houses()
	_build_stalls()
	_build_lungs()
	_build_yard()
	_build_skull_quarter()
	_build_stable()
	_build_ventre_and_pulpit()
	_spawn_cast()

	var bus := get_node_or_null("/root/EventBus")
	if bus:
		bus.hit_resolved.connect(_on_hit_resolved)
		bus.poise_broken.connect(_on_poise_broken)

## Altura do chão no ponto local (lx, lz), relativa ao nó
func ground(lx: float, lz: float) -> float:
	var w := _Layout.to_world(Vector2(lx, lz))
	if landscape and landscape.has_method("get_height_at"):
		return landscape.get_height_at(w.x, w.y) - _Layout.PLATEAU_Y
	return 0.0

func _hour() -> float:
	return DayNightCycle.instance.current_time_hours if is_instance_valid(DayNightCycle.instance) else 12.0

func _day() -> int:
	return DayNightCycle.instance.day_count if is_instance_valid(DayNightCycle.instance) else 0

func _process(delta: float) -> void:
	economy.ensure_day(_day())
	var hour := _hour()
	_update_night(hour)
	_update_routines(hour, delta)
	_tick_lesson(delta)
	_watch_player_mastery()

# ================================================================ construção

func _build_fence() -> void:
	# Presas de osso fincadas no contorno, com vão no portão da cauda e nas saídas dos pulmões
	var tusk := CylinderMesh.new()
	tusk.top_radius = 0.03
	tusk.bottom_radius = 0.28
	tusk.height = 2.6
	tusk.radial_segments = 6
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = tusk
	var xforms: Array[Transform3D] = []
	var steps := 150
	for i in steps:
		var a := TAU * float(i) / float(steps)
		var l := Vector2(sin(a) * _Layout.RADII.x, cos(a) * _Layout.RADII.y)
		if l.y > 52.0 and absf(l.x) < 6.0:
			continue
		if absf(l.y + 8.0) < 3.5 and absf(l.x) > 24.0:
			continue
		var out := Vector3(l.x / _Layout.RADII.x, 0.0, l.y / _Layout.RADII.y).normalized()
		var basis := Basis(Vector3.UP.cross(out).normalized(), 0.22)
		basis = basis.scaled(Vector3.ONE * _rng.randf_range(0.8, 1.25))
		xforms.append(Transform3D(basis, Vector3(l.x, ground(l.x, l.y) + 1.0, l.y)))
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var inst := MultiMeshInstance3D.new()
	inst.name = "CercaDePresas"
	inst.multimesh = mm
	inst.material_override = skeleton.bone_material
	add_child(inst)

func _build_gate() -> void:
	# Duas presas enormes em arco no portão da cauda e a placa virada para a estrada
	for side in [-1.0, 1.0]:
		var pts := PackedVector3Array([Vector3(side * 4.2, ground(side * 4.2, 57.0) - 0.3, 57.0), Vector3(side * 4.0, 4.0, 57.5), Vector3(side * 2.0, 6.6, 57.8), Vector3(side * 0.4, 7.0, 58.0)])
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_Skeleton.add_tube(st, pts, PackedFloat32Array([0.7, 0.55, 0.35, 0.1]), 8)
		var m := MeshInstance3D.new()
		m.mesh = st.commit()
		m.material_override = skeleton.bone_material
		add_child(m)
	var sign_lbl := _WorldLabel.make(_WorldLabel.Kind.SIGN, "")
	sign_lbl.full_text = "🦴 COSTELÁRIA\nA cidade dentro do Colosso • Lojas, Mestres & Arquivo"
	sign_lbl.modulate = Color(0.98, 0.82, 0.55)
	sign_lbl.sign_range = 60.0
	sign_lbl.position = Vector3(0.0, 8.2, 58.0)
	add_child(sign_lbl)
	_lantern(Vector2(-4.5, 56.0), 2.2)
	_lantern(Vector2(4.5, 56.0), 2.2)

func _build_heart() -> void:
	var c := _Layout.HEART
	# Cristal de âmbar: o Marco de Viagem da cidade fica ao pé dele (WorldSettlements)
	_crystal = MeshInstance3D.new()
	_crystal.name = "CristalDeAmbar"
	var prism := CylinderMesh.new()
	prism.top_radius = 0.15
	prism.bottom_radius = 1.1
	prism.height = 4.2
	prism.radial_segments = 6
	_crystal.mesh = prism
	_crystal.material_override = skeleton.amber_material
	_crystal.position = Vector3(c.x, ground(c.x, c.y) + 2.6, c.y)
	add_child(_crystal)
	var base := _prop(FANTASY + "Vase_Rubble_Medium", c, 0.0, 2.2)
	base.name = "BaseDoCristal"
	var light := _night_light(Vector3(c.x, ground(c.x, c.y) + 3.0, c.y), Color(1.0, 0.6, 0.2), 2.4, 14.0)
	light.name = "LuzDoCoracao"
	# Bancos em roda e o Mural de Notícias
	for i in 6:
		var a := TAU * float(i) / 6.0 + 0.3
		var p := c + Vector2(sin(a), cos(a)) * 6.0
		_prop(FANTASY + "Bench", p, rad_to_deg(a) + 90.0)
	var mural := CostelariaMural.new()
	mural.name = "MuralDeNoticias"
	mural.hub = self
	var mp := c + Vector2(6.0, -6.5)
	mural.position = Vector3(mp.x, ground(mp.x, mp.y), mp.y)
	mural.rotation.y = PI * 0.75
	add_child(mural)

func _build_houses() -> void:
	# Uma casa de couro e osso em cada moradia do elenco (as repetidas ficam uma só)
	var done: Array[Vector2] = []
	for c in _Cast.CAST:
		var h: Vector2 = c["home"]
		if absf(h.x) < 18.0 or done.any(func(o): return o.distance_to(h) < 5.0):
			continue
		done.append(h)
		_house(h + Vector2(signf(h.x) * 2.5, 0.0), signf(h.x))
	_lantern(Vector2(-21.0, -2.0), 2.0)
	_lantern(Vector2(21.0, 2.0), 2.0)

func _house(at: Vector2, side: float) -> void:
	var y := ground(at.x, at.y)
	var walls := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(3.6, 2.4, 3.2)
	walls.mesh = box
	walls.material_override = _mat(Color(0.62, 0.52, 0.38), 0.9)
	walls.position = Vector3(at.x, y + 1.2, at.y)
	add_child(walls)
	var roof := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(4.2, 1.5, 3.8)
	roof.mesh = prism
	roof.material_override = _mat(Color(0.45, 0.28, 0.18), 0.85)
	roof.position = Vector3(at.x, y + 3.15, at.y)
	add_child(roof)
	# Costela pequena de enfeite na cumeeira
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_Skeleton.add_tube(st, PackedVector3Array([Vector3(at.x - side * 1.8, y + 2.4, at.y), Vector3(at.x, y + 4.4, at.y), Vector3(at.x + side * 1.8, y + 2.4, at.y)]), PackedFloat32Array([0.12, 0.16, 0.12]), 6)
	var rib := MeshInstance3D.new()
	rib.mesh = st.commit()
	rib.material_override = skeleton.bone_material
	add_child(rib)
	var body := StaticBody3D.new()
	var shape := BoxShape3D.new()
	shape.size = box.size
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position = walls.position
	body.add_child(col)
	add_child(body)

func _build_stalls() -> void:
	# Uma banca sob cada arco de costela com loja (o NPC fica atrás do balcão)
	for c in _Cast.CAST:
		if c["district"] != &"costelas" or not ["shop", "buyer", "shop_buyer"].has(c["role"]):
			continue
		var post: Vector2 = c["post"]
		var side := signf(post.x)
		var stall := _prop(FANTASY + "Stall_Empty", Vector2(post.x - side * 1.3, post.y), 90.0 * side)
		stall.name = "Banca_" + String(c["id"])
		var awning := MeshInstance3D.new()
		var cloth := BoxMesh.new()
		cloth.size = Vector3(3.0, 0.08, 2.6)
		awning.mesh = cloth
		awning.material_override = _mat(Color(c.get("color", Color(0.7, 0.5, 0.3))).darkened(0.25), 0.9)
		awning.position = Vector3(post.x - side * 0.6, ground(post.x, post.y) + 2.7, post.y)
		awning.rotation.z = side * 0.18
		add_child(awning)
		var goods := [FANTASY + "Crate_Wooden", FANTASY + "Barrel", FANTASY + "Bag", FANTASY + "Pot_1"]
		_prop(goods[_rng.randi() % goods.size()], Vector2(post.x + side * 0.9, post.y + 1.1), _rng.randf_range(0, 360), 0.9)
	_lantern(Vector2(-12.5, -15.0), 2.0)
	_lantern(Vector2(12.5, -15.0), 2.0)
	_lantern(Vector2(-12.5, 6.5), 2.0)
	_lantern(Vector2(12.5, 6.5), 2.0)

func _build_lungs() -> void:
	# Pulmão Oeste: Salão das Forjas (bigorna de verdade + bancada)
	var forge_at := Vector2(-25.0, -8.0)
	_pavilion(forge_at, Color(0.35, 0.22, 0.15))
	var forge := _ForgeStation.new()
	forge.name = "BigornaDaCostelaria"
	forge.position = Vector3(forge_at.x, ground(forge_at.x, forge_at.y), forge_at.y)
	add_child(forge)
	_prop(FANTASY + "Anvil_Log", forge_at + Vector2(1.6, 1.4), 30.0)
	_prop(FANTASY + "Workbench", forge_at + Vector2(-1.8, 1.8), 90.0)
	_prop(FANTASY + "WeaponStand", forge_at + Vector2(-1.8, -1.8), 90.0)
	_night_light(Vector3(forge_at.x, ground(forge_at.x, forge_at.y) + 2.0, forge_at.y), Color(1.0, 0.45, 0.15), 1.6, 8.0)
	# Pulmão Leste: Estalagem com lareira (descanso de fogueira, B22), mesas e cama
	var inn_at := Vector2(25.0, -8.0)
	_pavilion(inn_at, Color(0.42, 0.26, 0.2))
	var hearth := Campfire.new()
	hearth.name = "LareiraDaEstalagem"
	hearth.position = Vector3(inn_at.x, ground(inn_at.x, inn_at.y), inn_at.y)
	add_child(hearth)
	_prop(FANTASY + "Table_Large", inn_at + Vector2(-1.5, 2.2), 0.0)
	_prop(FANTASY + "Stool", inn_at + Vector2(-2.6, 2.4), 20.0)
	_prop(FANTASY + "Stool", inn_at + Vector2(-0.4, 2.6), 70.0)
	_prop(FANTASY + "Barrel_Holder", inn_at + Vector2(2.2, -2.0), 0.0)
	_prop(FANTASY + "Bed_Twin1", inn_at + Vector2(2.4, 2.0), 90.0)

func _pavilion(at: Vector2, roof_color: Color) -> void:
	var y := ground(at.x, at.y)
	for corner in [Vector2(-3, -3), Vector2(3, -3), Vector2(-3, 3), Vector2(3, 3)]:
		var post := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.18
		cyl.bottom_radius = 0.24
		cyl.height = 3.2
		post.mesh = cyl
		post.material_override = skeleton.bone_material
		post.position = Vector3(at.x + corner.x, y + 1.6, at.y + corner.y)
		add_child(post)
	var roof := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(7.4, 1.4, 7.4)
	roof.mesh = prism
	roof.material_override = _mat(roof_color, 0.85)
	roof.position = Vector3(at.x, y + 3.9, at.y)
	add_child(roof)

func _build_yard() -> void:
	# Pátio dos Mestres: anel de presas baixas, bonecos de treino que não dão loot
	var c: Vector2 = _Layout.DISTRICTS[&"pelvis"]["at"]
	for i in 3:
		var a := TAU * float(i) / 3.0 + 0.5
		var p := c + Vector2(sin(a), cos(a)) * 3.2
		var dummy := DUMMY_SCENE.instantiate()
		if dummy == null:
			continue
		dummy.name = "BonecoDoPatio%d" % (i + 1)
		dummy.set("training_only", true)
		dummy.add_to_group("costelaria_dummy")
		dummy.position = Vector3(p.x, ground(p.x, p.y), p.y)
		add_child(dummy)
	_prop(FANTASY + "WeaponStand", c + Vector2(-5.5, 4.0), 140.0)
	_prop(FANTASY + "Dummy", c + Vector2(5.0, 4.5), 200.0)
	_prop(FANTASY + "Shield_Wooden", c + Vector2(-6.0, -3.0), 60.0)
	var sign_lbl := _WorldLabel.make(_WorldLabel.Kind.SIGN, "")
	sign_lbl.full_text = "🎯 PÁTIO DOS MESTRES\nÚnico lugar da cidade onde se luta"
	sign_lbl.sign_range = 25.0
	sign_lbl.position = Vector3(c.x, ground(c.x, c.y) + 3.4, c.y)
	add_child(sign_lbl)
	_lantern(c + Vector2(-7.5, 0.0), 2.0)
	_lantern(c + Vector2(7.5, 0.0), 2.0)

func _build_skull_quarter() -> void:
	# Arquivo ao pé do crânio e a mesa de dissecção do Mestre Esfolador
	var at := Vector2(0.0, -38.5)
	for i in 3:
		_prop(FANTASY + "Bookcase_2", at + Vector2(-3.0 + 3.0 * i, -1.6), 180.0)
	_prop(FANTASY + "BookStand", at + Vector2(1.5, 1.6), 200.0)
	_prop(FANTASY + "CandleStick_Stand", at + Vector2(-2.0, 1.4), 0.0)
	_prop(FANTASY + "Table_Large", Vector2(-10.5, -36.0), 90.0)
	_prop(FANTASY + "Table_Knife", Vector2(-10.5, -36.0), 30.0, 1.0, 0.9)
	_night_light(Vector3(at.x, ground(at.x, at.y) + 2.5, at.y), Color(1.0, 0.75, 0.4), 1.2, 9.0)

func _build_stable() -> void:
	var at := Vector2(-13.0, 44.0)
	for i in 5:
		var x := at.x - 4.0 + 2.0 * i
		_prop(FANTASY + "Crate_Wooden", Vector2(x, at.y - 3.2), 0.0, 0.8)
	_prop(FANTASY + "FarmCrate_Empty", at + Vector2(2.5, 1.0), 20.0)
	_prop(FANTASY + "Bucket_Wooden_1", at + Vector2(3.2, 2.0), 0.0)
	_prop(FANTASY + "Rope_2", at + Vector2(-3.5, 1.5), 0.0)
	_pavilion(at + Vector2(-1.0, -1.5), Color(0.5, 0.38, 0.2))

func _build_ventre_and_pulpit() -> void:
	# Feira do Ventre: bancas baixas debaixo da espinha, lanternas roxas que só acendem à noite
	for p in [Vector2(-4.5, 9.0), Vector2(4.5, 11.0), Vector2(-4.5, 13.5)]:
		_prop(FANTASY + "Stall_Cart_Empty", p, 90.0 if p.x < 0.0 else -90.0, 0.85)
	_night_light(Vector3(0.0, ground(0.0, 11.0) + 2.4, 11.0), Color(0.6, 0.35, 1.0), 1.6, 10.0)
	# Púlpito de osso da Pregoeira
	var p := Vector2(3.0, 20.0)
	var podium := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.9
	cyl.bottom_radius = 1.1
	cyl.height = 0.6
	podium.mesh = cyl
	podium.material_override = skeleton.bone_material
	podium.position = Vector3(p.x, ground(p.x, p.y) + 0.3, p.y)
	add_child(podium)
	_lantern(Vector2(-3.0, 24.0), 2.0)
	_lantern(Vector2(3.0, 34.0), 2.0)

# ================================================================ elenco

func _spawn_cast() -> void:
	for c in _Cast.CAST:
		var npc := _TownNPC.new()
		npc.name = "NPC_" + String(c["id"])
		npc.dna = _dna_for(c)
		npc.icon = c["icon"]
		npc.idle_anim = c.get("anim", &"Idle_Talking")
		var post: Vector2 = c["post"]
		npc.position = Vector3(post.x, ground(post.x, post.y), post.y)
		npc.rotation.y = _yaw_to(post, c["face"])
		npc.snap_to_ground = false
		npc.set_meta("cast_id", c["id"])
		add_child(npc)
		npc.profile = _profile_for(c)
		npcs[c["id"]] = npc

func _dna_for(c: Dictionary) -> CharacterDNA:
	var dna := CharacterDNA.randomized(int(c["seed"]))
	if c.get("female", false):
		dna.femininity = 0.9
		dna.beard = CharacterDNA.Beard.NONE
		dna.hair_style = CharacterDNA.HairStyle.LONG
	if c.has("shirt"):
		dna.shirt_color = c["shirt"]
	if c.has("hat"):
		dna.cosmetic_hat = c["hat"]
	return dna

## Ângulo Y (no referencial do nó) para olhar de `from` para `to`
static func _yaw_to(from: Vector2, to: Vector2) -> float:
	var d := to - from
	return atan2(-d.x, -d.y)

func _profile_for(c: Dictionary) -> _NpcProfile:
	var p := _NpcProfile.make(c["id"], c["name"], c["title"], c["icon"], _Layout.DISTRICTS.get(c["district"], {}).get("name", ""))
	p.color = c.get("color", Color(0.85, 0.72, 0.35))
	if c.has("hours"):
		var h: Vector2 = c["hours"]
		p.hours(h.x, h.y, c.get("off", ""))
	for period in c.get("greet", {}):
		for line in c["greet"][period]:
			p.greet(period, line)
	for t in c.get("topics", []):
		p.topic(t[0], t[1])
	var id: StringName = c["id"]
	if not c.get("sells", {}).is_empty() or id == _Economy.NIGHT_NPC:
		p.add(_NpcAction.inline(&"comprar", _NpcAction.Kind.BUY, "Comprar", _panel_buy.bind(id)))
	if not c.get("buys", []).is_empty() or id == _Economy.NIGHT_NPC:
		p.add(_NpcAction.inline(&"vender", _NpcAction.Kind.SELL, "Vender", _panel_sell.bind(id)))
	if id == _Economy.ORDER_NPC:
		p.add(_NpcAction.inline(&"encomendas", _NpcAction.Kind.SERVICE, "Encomendas do dia", _panel_orders, "📦"))
	if id == &"luma_rosa":
		p.add(_NpcAction.inline(&"rumo", _NpcAction.Kind.ASK_WAY, "Comprar um rumo (%d $S)" % ROUTE_PRICE, _panel_routes, "🗺️"))
	for tag in c.get("masters", []):
		if _Techniques.TECHNIQUES.has(tag):
			p.add(_NpcAction.inline(StringName("licao_" + String(tag)), _NpcAction.Kind.TRAIN, "Lição de %s" % _Techniques.tag_name(tag), _panel_lesson.bind(tag), "🎯"))
			p.add(_NpcAction.inline(StringName("tecnica_" + String(tag)), _NpcAction.Kind.TRAIN, "Técnicas de %s" % _Techniques.tag_name(tag), _panel_techniques.bind(tag), "📜"))
		p.add(_NpcAction.make(StringName("onde_" + String(tag)), _NpcAction.Kind.ASK_WAY, "Onde treinar %s?" % _Techniques.tag_name(tag), _advise.bind(tag)).always_open())
	if id == &"pena_de_osso":
		p.add(_NpcAction.inline(&"compendio", _NpcAction.Kind.LEARN, "Compêndio (%d páginas)" % _Compendium.total_pages(), _panel_compendium))
	if id == &"guarda_osmar" or id == &"guarda_quiteria":
		p.add(_NpcAction.inline(&"onde_fica", _NpcAction.Kind.ASK_WAY, "Onde fica…?", _panel_where))
	if id == &"voz_de_trovao":
		p.add(_NpcAction.inline(&"noticias", _NpcAction.Kind.TALK, "Notícias do vale", _panel_news, "📣"))
	# Conversar com quem sabe abre a página do Compêndio
	if _Compendium.TALK_PAGES.has(id):
		var page: StringName = _Compendium.TALK_PAGES[id]
		p.add(_NpcAction.inline(&"conversar", _NpcAction.Kind.TALK, "Conversar", func(box: VBoxContainer, _pl, dialog):
			unlock_page(page)
			dialog._build_topics(box)
		).always_open())
	return p

# ================================================================ painéis da Ficha

func _row(box: VBoxContainer, text: String, button_text: String, on_press: Callable, disabled: bool = false) -> Button:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(label)
	var b := Button.new()
	b.text = button_text
	b.disabled = disabled
	b.pressed.connect(on_press)
	row.add_child(b)
	box.add_child(row)
	return b

func _note(box: VBoxContainer, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", Color(0.78, 0.74, 0.66))
	box.add_child(l)

func _material_name(id: StringName) -> String:
	var m := _MaterialData.of(id)
	return m.display_name if m and not m.display_name.is_empty() else String(id)

func _wallet_text(player: Node) -> String:
	var w = player.get("wallet") if player else null
	return "Sua bolsa: %d $S" % (w.money if w else 0)

func _panel_buy(box: VBoxContainer, player: Node, dialog, npc_id: StringName) -> void:
	_note(box, _wallet_text(player) + ("   ·   desconto da Reputação: %d%%" % roundi(economy.discount() * 100.0) if economy.discount() > 0.0 else ""))
	var catalog := economy.catalog(npc_id)
	for item in catalog:
		var left := economy.stock_of(npc_id, item)
		_row(box, "%s — %d $S  (%d hoje)" % [_material_name(item), economy.price(npc_id, item), left], "Comprar", func():
			var why := economy.buy(npc_id, item, player)
			if why.is_empty():
				unlock_page(&"eco_comprar")
				dialog.say("Leva. Bom uso.")
				dialog.gesture(&"Interact")
			else:
				dialog.say(why)
			dialog.refresh()
		, left <= 0)

func _panel_sell(box: VBoxContainer, player: Node, dialog, npc_id: StringName) -> void:
	_note(box, "Bolsa de hoje: %d $S. Cada unidade que a cidade vende baixa o preço daquele material até amanhã." % economy.purse_of(npc_id))
	var inv: InventoryComponent = player.get("inventory") if player else null
	var wanted: Array = economy.buys(npc_id)
	if npc_id == _Economy.NIGHT_NPC and inv:
		wanted = []
		for s in inv.get_stacks():
			if not wanted.has(s.id):
				wanted.append(s.id)
	var any := false
	for m in wanted:
		var have := inv.get_material_count(m) if inv else 0
		if have <= 0:
			continue
		any = true
		var pay := economy.offer(npc_id, m)
		_row(box, "%s ×%d — paga %d $S" % [_material_name(m), have, pay], "Vender 1", func():
			var why := economy.sell(npc_id, m, player)
			if why.is_empty():
				unlock_page(&"eco_vender")
				dialog.say("Fechado.")
				dialog.gesture(&"Interact")
			else:
				dialog.say(why)
			dialog.refresh()
		, economy.purse_of(npc_id) < pay)
	if not any:
		var names := ", ".join(wanted.map(func(m): return _material_name(m)))
		_note(box, "Você não tem nada que eu compre." + ("" if names.is_empty() else " Eu compro: " + names + "."))

func _panel_orders(box: VBoxContainer, player: Node, dialog) -> void:
	_note(box, "Duas por dia, para a cidade inteira. Quem entregar primeiro leva o prêmio e +%d de Reputação (Reputação: %d)." % [_Economy.ORDER_REPUTATION, economy.reputation])
	for i in economy.orders.size():
		var o: Dictionary = economy.orders[i]
		var text := "%d× %s de %d★ ou mais — %d $S" % [o["amount"], _material_name(o["material"]), o["min_q"], o["reward"]]
		_row(box, ("✅ " if o["done"] else "") + text, "Entregar", func():
			var why := economy.deliver(i, player)
			if why.is_empty():
				unlock_page(&"eco_encomenda")
				dialog.say("Isso sim é parte boa. O mestre vai gostar.")
				dialog.gesture(&"Interact")
			else:
				dialog.say(why)
			dialog.refresh()
		, o["done"])

func _panel_routes(box: VBoxContainer, player: Node, dialog) -> void:
	_note(box, _wallet_text(player))
	for s in WorldSettlements.SETTLEMENTS + WorldSettlements.LANDMARKS:
		if s["id"] == &"costelaria":
			continue
		var target: Vector3 = s["pos"]
		_row(box, str(s["name"]), "%d $S" % ROUTE_PRICE, func():
			var w = player.get("wallet")
			if w == null or not w.spend(ROUTE_PRICE):
				dialog.say("Rumo tem preço. Faltou dinheiro.")
				return
			point_compass(str(s["name"]), target, player)
			dialog.say("Siga a bússola. O caminho é seu.")
			dialog.gesture(&"Interact")
		)

func _panel_where(box: VBoxContainer, player: Node, dialog) -> void:
	var hour := _hour()
	_note(box, "Bairros")
	for id in _Layout.DISTRICTS:
		var name: String = _Layout.DISTRICTS[id]["name"]
		_row(box, name, "Mostrar", func():
			_show_district(id, player)
			dialog.say("Siga a bússola até %s." % name)
		)
	_note(box, "Moradores")
	for c in _Cast.CAST:
		if c["role"] == "folk":
			continue
		var npc: Node3D = npcs.get(c["id"])
		var prof: _NpcProfile = npc.profile if npc else null
		var status := "" if prof == null or prof.is_open_at(hour) else "  (fechado agora)"
		_row(box, "%s %s — %s%s" % [c["icon"], c["name"], c["title"], status], "Mostrar", func():
			show_npc(c["id"], player)
			dialog.say("%s? Siga a bússola." % c["name"])
		)

func _panel_news(box: VBoxContainer, _player: Node, dialog) -> void:
	var lines := news()
	for l in lines:
		_note(box, "• " + l)
	if not lines.is_empty():
		dialog.say(lines[0])

func _panel_compendium(box: VBoxContainer, player: Node, dialog) -> void:
	_note(box, "%d de %d páginas abertas. Capítulo completo: +%d de Reputação." % [pages.size(), _Compendium.total_pages(), _Compendium.CHAPTER_REPUTATION])
	for ch in _Compendium.CHAPTERS:
		var done := _Compendium.chapter_complete(ch, pages)
		var title := Label.new()
		title.text = "%s %s%s" % [ch["icon"], ch["title"], "  ✅" if done else ""]
		title.add_theme_font_size_override("font_size", 14)
		box.add_child(title)
		for pg in ch["pages"]:
			var open := pages.has(pg["id"])
			_row(box, ("📖 " + pg["title"]) if open else ("🔒 " + pg["hint"]), "Ler" if open else "Mostre-me", func():
				if open:
					dialog.say(pg["text"])
					dialog.gesture(&"Idle_Talking", 2.0)
				else:
					show_target(pg["show"], player)
					dialog.say("Vá até lá e faça. Depois volte e leia.")
			)

func _panel_lesson(box: VBoxContainer, player: Node, dialog, tag: StringName) -> void:
	var m: MasteryComponent = player.get("mastery") if player else null
	var level := m.get_level(tag) if m else 1
	var band := _Techniques.band_of(level)
	var spec := lesson_spec(tag, band)
	_note(box, "Sua %s: nível %d (faixa %d). %s" % [_Techniques.tag_name(tag), level, band, "Bônus de primeira vez já recebido nesta faixa." if m and m.has_lesson(tag, band) else "Primeira Lição desta faixa: bônus de XP."])
	_note(box, spec["text"])
	if not lesson.is_empty():
		_note(box, "Lição em andamento: %s (%d/%d, %d s)." % [_Techniques.tag_name(lesson["tag"]), lesson["count"], lesson["goal"], ceili(lesson["time_left"])])
	_row(box, "", "Mostrar agora" if spec["kind"] == "show" else "Começar", func():
		var why := start_lesson(tag, player)
		dialog.say(why if not why.is_empty() else ("Muito bem. Isso conta." if lesson.is_empty() else "Vai! O tempo está correndo."))
		dialog.gesture(&"Interact")
		dialog.refresh()
	)

func _panel_techniques(box: VBoxContainer, player: Node, dialog, tag: StringName) -> void:
	var m: MasteryComponent = player.get("mastery") if player else null
	var level := m.get_level(tag) if m else 1
	_note(box, "%s nível %d · %s" % [_Techniques.tag_name(tag), level, _wallet_text(player)])
	for ms in _Techniques.MILESTONES:
		var t := _Techniques.get_technique(tag, ms)
		if t.is_empty():
			continue
		var learned := m != null and m.has_technique(tag, ms)
		var why := technique_reason(tag, ms, player)
		var text := "%s %d · %s — %s" % ["✅" if learned else ("📜" if why.is_empty() else "🔒"), ms, t["name"], t["desc"]]
		if not learned:
			text += "  (%d $S)" % _Techniques.COST[ms] + ("" if why.is_empty() else "\n    " + why)
		_row(box, text, "Aprender", func():
			var r := learn_technique(tag, ms, player)
			dialog.say(r if not r.is_empty() else "%s é sua. Use bem." % t["name"])
			dialog.gesture(&"Interact")
			dialog.refresh()
		, learned or not why.is_empty())

func _advise(player: Node, tag: StringName) -> void:
	var spot: StringName = TRAIN_SPOTS.get(tag, &"pelvis")
	show_target(spot, player)
	if player and player.has_signal("posture_changed"):
		player.posture_changed.emit("🧭 Treine %s em: %s" % [_Techniques.tag_name(tag), last_compass.get("name", "")])

# ================================================================ Lições e Técnicas

## Desafio da faixa: "hits" (golpes do tipo nos bonecos), "parts" (partes quebradas nos
## bonecos) ou "show" (mostrar o que você fez/colheu, sem gastar)
func lesson_spec(tag: StringName, band: int) -> Dictionary:
	var q := clampi(1 + band / 2, 1, 4)
	match tag:
		&"lâmina", &"concussão", &"canalização":
			var n := 6 + 3 * band
			return {"kind": "hits", "goal": n, "text": "Acerte %d golpes de %s nos bonecos do Pátio em %d s." % [n, _Techniques.tag_name(tag), int(LESSON_SECONDS)]}
		&"esfola":
			var n := 1 + band / 2
			return {"kind": "parts", "goal": n, "text": "Quebre %d parte(s) dos bonecos do Pátio (chifre, cauda, carapaça) em %d s." % [n, int(LESSON_SECONDS)]}
		&"forja":
			return {"kind": "show", "goal": 1, "q": q, "items": [], "forged": true, "text": "Mostre uma peça forjada de %d★ ou mais." % q}
		&"mineracao":
			return {"kind": "show", "goal": 3 + band, "q": q, "items": [&"minerio_ferro", &"quartzo_lume", &"pedra"], "text": "Mostre %d minérios ou pedras de %d★ ou mais." % [3 + band, q]}
		&"coleta":
			return {"kind": "show", "goal": 5 + band * 2, "q": q, "items": [&"madeira", &"galho", &"folha", &"fibra", &"erva", &"frutinha", &"mel"], "text": "Mostre %d coletas do mato de %d★ ou mais." % [5 + band * 2, q]}
		&"culinaria":
			return {"kind": "show", "goal": 1, "q": q, "items": [&"ensopado_campeiro", &"peixe_ao_mel", &"assado_ermo", &"gisado_cacador", &"banquete_viagem", &"caldo_revigorante"], "text": "Mostre um prato de %d★ ou mais feito por você." % q}
	return {"kind": "show", "goal": 1, "q": 1, "items": [], "text": "Mostre o que sabe."}

## Começa (ou, se for de mostrar, confere na hora) a Lição; "" se começou/completou
func start_lesson(tag: StringName, player: Node) -> String:
	var m: MasteryComponent = player.get("mastery") if player else null
	if m == null:
		return "Sem maestria."
	if not lesson.is_empty() and lesson["player"] == player:
		return "Termine a Lição que já está fazendo."
	var band := _Techniques.band_of(m.get_level(tag))
	var spec := lesson_spec(tag, band)
	if spec["kind"] == "show":
		var have := _count_shown(player, spec)
		if have < int(spec["goal"]):
			return "Ainda não: você tem %d de %d." % [have, spec["goal"]]
		_complete_lesson(player, tag, band)
		return ""
	lesson = {"tag": tag, "band": band, "kind": spec["kind"], "goal": spec["goal"], "count": 0, "time_left": LESSON_SECONDS, "player": player}
	if player.has_signal("posture_changed"):
		player.posture_changed.emit("🎯 Lição: " + spec["text"])
	return ""

func _count_shown(player: Node, spec: Dictionary) -> int:
	var inv: InventoryComponent = player.get("inventory")
	if inv == null:
		return 0
	var q := int(spec.get("q", 1))
	if spec.get("forged", false):
		var n := 0
		var forged: Array = inv.items.duplicate()
		forged.append_array(inv.equipped_items.values())
		for it in forged:
			if it != null and int(it.quality) >= q:
				n += 1
		return n
	var total := 0
	for item in spec["items"]:
		for s in inv.get_stacks(item):
			if int(s.quality) >= q:
				total += int(s.amount)
	return total

func _tick_lesson(delta: float) -> void:
	if lesson.is_empty():
		return
	lesson["time_left"] -= delta
	if not is_instance_valid(lesson["player"]):
		lesson = {}
		return
	if lesson["time_left"] <= 0.0:
		var p: Node = lesson["player"]
		if p.has_signal("posture_changed"):
			p.posture_changed.emit("⌛ Lição de %s: o tempo acabou (%d/%d). Tente de novo com o mestre." % [_Techniques.tag_name(lesson["tag"]), lesson["count"], lesson["goal"]])
		lesson = {}

func _lesson_progress(amount: int) -> void:
	lesson["count"] += amount
	var p: Node = lesson["player"]
	if lesson["count"] >= lesson["goal"]:
		var tag: StringName = lesson["tag"]
		var band: int = lesson["band"]
		lesson = {}
		_complete_lesson(p, tag, band)
	elif p.has_signal("posture_changed"):
		p.posture_changed.emit("🎯 Lição: %d/%d · %d s" % [lesson["count"], lesson["goal"], ceili(lesson["time_left"])])

func _complete_lesson(player: Node, tag: StringName, band: int) -> void:
	var m: MasteryComponent = player.get("mastery")
	var first := not m.has_lesson(tag, band)
	m.mark_lesson(tag, band)
	unlock_page(&"treino_licao")
	if first:
		# Bônus de primeira vez da faixa: um quarto do que falta para o próximo nível
		m.add_xp(tag, MasteryComponent.get_xp_for_next_level(m.get_level(tag)) * 0.25)
	if player.has_signal("posture_changed"):
		player.posture_changed.emit("✅ Lição de %s completa!%s" % [_Techniques.tag_name(tag), " Bônus de primeira vez." if first else ""])

## "" se pode aprender; senão o motivo
func technique_reason(tag: StringName, milestone: int, player: Node) -> String:
	var m: MasteryComponent = player.get("mastery") if player else null
	if m == null:
		return "Sem maestria."
	if _Techniques.get_technique(tag, milestone).is_empty():
		return "Não ensino isso."
	if m.has_technique(tag, milestone):
		return "Já aprendida."
	var level := m.get_level(tag)
	if level < milestone:
		return "Precisa de %s %d (você: %d)." % [_Techniques.tag_name(tag), milestone, level]
	for prev in _Techniques.MILESTONES:
		if prev < milestone and not m.has_technique(tag, prev):
			return "Aprenda antes a Técnica do marco %d." % prev
	var band := _Techniques.band_of(milestone)
	var proven := false
	for b in range(band, 6):
		if m.has_lesson(tag, b):
			proven = true
	if not proven:
		return "Falta a Prova: faça a Lição da faixa %d ou acima." % band
	var w = player.get("wallet")
	if w == null or not w.can_afford(_Techniques.COST[milestone]):
		return "Custa %d $S." % _Techniques.COST[milestone]
	return ""

func learn_technique(tag: StringName, milestone: int, player: Node) -> String:
	var why := technique_reason(tag, milestone, player)
	if not why.is_empty():
		return why
	player.get("wallet").spend(_Techniques.COST[milestone])
	player.get("mastery").learn_technique(tag, milestone)
	unlock_page(&"treino_tecnica")
	return ""

func _on_hit_resolved(hit: HitEvent, damage: float, part_broken: bool) -> void:
	if hit == null:
		return
	var player := get_tree().get_first_node_in_group("player") if is_inside_tree() else null
	if hit.attacker != null and hit.attacker == player:
		_last_hit_target = hit.target
		if damage > 0.0:
			unlock_page(&"combate_golpe")
		if part_broken:
			unlock_page(&"caca_parte")
	if lesson.is_empty() or hit.attacker != lesson["player"] or hit.target == null or not hit.target.is_in_group("costelaria_dummy"):
		return
	match lesson["kind"]:
		"hits":
			if damage > 0.0 and CombatResolver._damage_stat(hit.damage_type) == _lesson_stat(lesson["tag"]):
				_lesson_progress(1)
		"parts":
			if part_broken:
				_lesson_progress(1)

static func _lesson_stat(tag: StringName) -> StringName:
	return {&"lâmina": &"dmg_slash", &"concussão": &"dmg_impact", &"canalização": &"dmg_magic"}.get(tag, &"")

func _on_poise_broken(target: Node) -> void:
	if target != null and target == _last_hit_target:
		unlock_page(&"combate_postura")

## Abre páginas pela maestria do jogador (esfola e forja contam a primeira vez)
func _watch_player_mastery() -> void:
	if _watched_mastery != null or not is_inside_tree():
		return
	var player := get_tree().get_first_node_in_group("player")
	var m: MasteryComponent = player.get("mastery") if player else null
	if m == null:
		return
	_watched_mastery = m
	m.xp_gained.connect(func(tag: StringName, _a, _l, _x, _n):
		if tag == &"esfola":
			unlock_page(&"caca_esfola")
		elif tag == &"forja":
			unlock_page(&"forja_peca")
	)

# ================================================================ Compêndio, bússola e notícias

func unlock_page(id: StringName) -> void:
	if pages.has(id) or _Compendium.page(id).is_empty():
		return
	pages.append(id)
	var ch := _Compendium.chapter_of(id)
	var player := get_tree().get_first_node_in_group("player") if is_inside_tree() else null
	if player and player.has_signal("posture_changed"):
		player.posture_changed.emit("📖 Compêndio: página nova — %s" % _Compendium.page(id)["title"])
	if _Compendium.chapter_complete(ch, pages):
		economy.reputation += _Compendium.CHAPTER_REPUTATION
		if player and player.has_signal("posture_changed"):
			player.posture_changed.emit("🏅 Capítulo completo: %s! +%d de Reputação na Costelária" % [ch["title"], _Compendium.CHAPTER_REPUTATION])

## Bússola até um bairro, NPC da Costelária ou assentamento/marco do mundo
func show_target(id: StringName, player: Node) -> void:
	if npcs.has(id):
		show_npc(id, player)
	elif _Layout.DISTRICTS.has(id):
		_show_district(id, player)
	else:
		for s in WorldSettlements.SETTLEMENTS + WorldSettlements.LANDMARKS:
			if s["id"] == id:
				point_compass(str(s["name"]), s["pos"], player)
				return

func show_npc(id: StringName, player: Node) -> void:
	var npc: Node3D = npcs.get(id)
	if npc:
		point_compass(_Cast.by_id(id).get("name", String(id)), npc.global_position, player)

func _show_district(id: StringName, player: Node) -> void:
	var w := _Layout.district_world(id)
	point_compass(_Layout.DISTRICTS[id]["name"], Vector3(w.x, 0.0, w.y), player)

func point_compass(target_name: String, pos: Vector3, player: Node) -> void:
	last_compass = {"name": target_name, "pos": pos}
	var guide := get_tree().current_scene.find_child("ExplorerGuide", true, false) if is_inside_tree() and get_tree().current_scene else null
	if guide and guide.has_method("point_to"):
		guide.point_to(target_name, pos)
	elif player and player.has_signal("posture_changed"):
		player.posture_changed.emit("🧭 %s" % target_name)

## Notícias do vale (Pregoeira e Mural): sempre do estado do mundo, igual para todos
func news() -> Array[String]:
	var out: Array[String] = []
	var hour := _hour()
	var next_caravan := -1
	for h in VillageMarket.CARAVAN_HOURS:
		if h > int(hour):
			next_caravan = h
			break
	out.append("A caravana passa pelo Mercado da Vila %s." % ("às %dh" % next_caravan if next_caravan >= 0 else "amanhã às %dh" % VillageMarket.CARAVAN_HOURS[0]))
	var open_orders := economy.orders.filter(func(o): return not o["done"])
	if not open_orders.is_empty():
		var o: Dictionary = open_orders[0]
		out.append("Seu Graxa paga %d $S por %d× %s de %d★! (%d encomenda(s) aberta(s))" % [o["reward"], o["amount"], _material_name(o["material"]), o["min_q"], open_orders.size()])
	else:
		out.append("As encomendas de hoje já foram entregues. Amanhã tem mais.")
	var cheap: Array[String] = []
	for m in economy.sold_today:
		if economy.sold_today[m] >= 5:
			cheap.append(_material_name(m))
	if not cheap.is_empty():
		out.append("Tem muito %s à venda hoje: os compradores estão pagando pouco." % ", ".join(cheap))
	var empty: Array[String] = []
	for c in _Cast.CAST:
		if economy.purse.has(c["id"]) and economy.purse_of(c["id"]) < 20:
			empty.append(c["name"])
	if not empty.is_empty():
		out.append("A bolsa de %s está quase vazia hoje." % ", ".join(empty))
	if hour >= 18.0 and hour < 20.0:
		out.append("A Feira do Ventre abre às 20h. O Mascate Sombra trouxe: %s." % ", ".join(economy.night_offer.keys().map(func(i): return _material_name(i))))
	elif hour >= 20.0 or hour < 4.0:
		out.append("A Feira do Ventre está aberta debaixo da espinha até as 4h.")
	var weather := get_tree().get_first_node_in_group("weather") if is_inside_tree() else null
	if weather and weather.has_method("get_state_name"):
		out.append("O tempo: %s." % weather.get_state_name())
	return out

# ================================================================ rotina e noite

## Fora do horário o morador vai para casa (andando pelo mundo, sem teleporte); no horário
## volta ao posto. A posição sai da hora do relógio único: todo mundo vê o mesmo.
func _update_routines(hour: float, delta: float) -> void:
	for c in _Cast.CAST:
		var npc: Node3D = npcs.get(c["id"])
		if npc == null:
			continue
		var target: Vector2 = c["post"]
		if c.has("hours") and not npc.profile.is_open_at(hour):
			target = c["home"]
		var here := Vector2(npc.position.x, npc.position.z)
		var dist := here.distance_to(target)
		var visual: CharacterVisual = npc.visual
		if dist > 0.15:
			var step := minf(dist, WALK_SPEED * delta)
			var next := here + (target - here) / dist * step
			npc.position = Vector3(next.x, ground(next.x, next.y), next.y)
			npc.rotation.y = _yaw_to(here, target)
			npc.look_at_player = false
			if visual and visual.current() != &"Walk":
				visual.play(&"Walk")
		elif visual and visual.current() == &"Walk":
			npc.position = Vector3(target.x, ground(target.x, target.y), target.y)
			npc.rotation.y = _yaw_to(target, c["face"] if target == c["post"] else c["post"])
			npc.look_at_player = true
			visual.play(npc.idle_anim if target == c["post"] else &"Idle")

## Posiciona todo morador onde deveria estar na hora (load do save e testes)
func settle_routines() -> void:
	var hour := _hour()
	for c in _Cast.CAST:
		var npc: Node3D = npcs.get(c["id"])
		if npc == null:
			continue
		var t: Vector2 = c["home"] if c.has("hours") and not npc.profile.is_open_at(hour) else c["post"]
		npc.position = Vector3(t.x, ground(t.x, t.y), t.y)

func _update_night(hour: float) -> void:
	var n := CityHub.night_factor(hour)
	skeleton.amber_material.emission_energy_multiplier = lerpf(0.4, 3.0, n)
	if _lantern_mat:
		_lantern_mat.emission_energy_multiplier = lerpf(0.1, 2.6, n)
	for light in _night_lights:
		light.visible = n > 0.05
		light.light_energy = n * float(light.get_meta("energy", 1.0))
	if _crystal:
		_crystal.scale = Vector3.ONE * (1.0 + 0.03 * sin(Time.get_ticks_msec() * 0.002) * n)

func _night_light(pos: Vector3, color: Color, energy: float, light_range: float) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.position = pos
	light.light_color = color
	light.omni_range = light_range
	light.shadow_enabled = false
	light.set_meta("energy", energy)
	light.visible = false
	add_child(light)
	_night_lights.append(light)
	return light

func _lantern(at: Vector2, height: float) -> void:
	if _lantern_mat == null:
		_lantern_mat = StandardMaterial3D.new()
		_lantern_mat.albedo_color = Color(1.0, 0.7, 0.3)
		_lantern_mat.emission_enabled = true
		_lantern_mat.emission = Color(1.0, 0.6, 0.2)
	var y := ground(at.x, at.y)
	var pole := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.06
	cyl.bottom_radius = 0.1
	cyl.height = height
	pole.mesh = cyl
	pole.material_override = skeleton.bone_material
	pole.position = Vector3(at.x, y + height * 0.5, at.y)
	add_child(pole)
	var glow := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.2
	sphere.height = 0.4
	glow.mesh = sphere
	glow.material_override = _lantern_mat
	glow.position = Vector3(at.x, y + height + 0.15, at.y)
	add_child(glow)

# ================================================================ save

func get_state() -> Dictionary:
	return {"economy": economy.get_state(), "pages": pages.map(func(p): return String(p))}

func apply_state(state: Dictionary) -> void:
	economy.apply_state(state.get("economy", {}))
	pages.clear()
	for p in state.get("pages", []):
		pages.append(StringName(p))
	economy.ensure_day(_day())
	settle_routines()

# ================================================================ peças

func _prop(path: String, at: Vector2, yaw_deg: float = 0.0, s: float = 1.0, y_off: float = 0.0) -> Node3D:
	if not _scene_cache.has(path):
		var full := path + ".gltf"
		_scene_cache[path] = load(full) as PackedScene if ResourceLoader.exists(full) else null
	var scene: PackedScene = _scene_cache[path]
	var n: Node3D = scene.instantiate() if scene else Node3D.new()
	n.position = Vector3(at.x, ground(at.x, at.y) + y_off, at.y)
	n.rotation.y = deg_to_rad(yaw_deg)
	n.scale = Vector3.ONE * s
	add_child(n)
	return n

func _mat(color: Color, roughness: float) -> StandardMaterial3D:
	var key := color.to_html() + str(roughness)
	if not _mat_cache.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = roughness
		_mat_cache[key] = m
	return _mat_cache[key]

## Mural de Notícias do Coração: [E] mostra as notícias da Pregoeira no HUD
class CostelariaMural extends Node3D:
	var hub: CostelariaHub

	func _ready() -> void:
		add_to_group("talkable")
		var board := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(2.2, 1.4, 0.12)
		board.mesh = box
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.5, 0.36, 0.22)
		board.material_override = mat
		board.position.y = 1.5
		add_child(board)
		var title := WorldLabel.make(WorldLabel.Kind.NAME, "Mural de Notícias", "📰")
		title.position.y = 2.6
		add_child(title)
		var prompt := WorldLabel.make(WorldLabel.Kind.PROMPT, "[E] Ler notícias")
		prompt.position.y = 2.3
		add_child(prompt)

	func talk_to(player: Node) -> void:
		if hub == null or player == null or not player.has_signal("posture_changed"):
			return
		var lines := hub.news()
		player.posture_changed.emit("📰 " + "  ·  ".join(lines.slice(0, 3)))
