class_name TutorialTrail
extends Node3D

const _WorldLabel = preload("res://scripts/ui/world_label.gd")
const LANTERN_SCENE = preload("res://assets/models/tools/lantern.gltf")

## Caminho do Tutorial (Trilha do Iniciado):
## Guia físico e interativo adaptado para o estado atual completo de Cepa Selvagem.
## Cria 8 Estações no mundo ligadas por uma trilha de Pedras-Guia Luminosas no chão,
## detecta automaticamente quando o jogador cumpre cada etapa (ou permite avançar com [E] / botão)
## e apresenta desde Customização/Cosméticos até Combate, Coleta, Rio, Caçada, Forja, Mapa [M] e Coop [F7].

signal step_changed(step_index: int, step_data: Dictionary)
signal trail_completed()

@export var landscape: Node3D
@export var player: Player

const BEACON_COUNT: int = 14

const TRAIL_STEPS: Array[Dictionary] = [
	{
		"id": &"despertar",
		"title": "Passo 1/8 · Despertar, Estilo & Cosméticos",
		"short": "Explore a Praça, fale com o Barbeiro ou abra o Ateliê [F9]",
		"detail": "Bem-vindo(a) à Vila da Esperança! Você começou com 150 $S de Ouro. Aperte [F9] para vestir Coroas, Capas e Auras, fale com o Barbeiro na Feira (12.6, 14.6) ou toque no Marco [E] para seguir.",
		"pos": Vector3(1.6, 0.0, -0.6),
		"icon": "✨",
	},
	{
		"id": &"suprimentos",
		"title": "Passo 2/8 · Baú de Suprimentos & Mochila",
		"short": "Pegue itens no Baú [E] (-2.4, 1.0) ou abra a Mochila [I]",
		"detail": "Interaja com o Baú de Suprimentos [E] na chegada da praça para abastecer poções, ervas e carnes, ou aperte [I] para ver sua Mochila e Equipamentos.",
		"pos": Vector3(-1.6, 0.0, 2.2),
		"icon": "🎒",
	},
	{
		"id": &"armas",
		"title": "Passo 3/8 · Mestre de Armas & Estilos",
		"short": "No Pátio de Armas (oeste), fale com o Mestre [E] e teste Espada, Martelo ou Cajado",
		"detail": "Siga a Rua da Forja até o Pátio de Armas e fale com o Mestre de Armas (-10.2, 9.4) com [E] para alternar entre os 3 estilos: Espada & Escudo, Martelo Pesado e Cajado Arcano (mira no botão direito!).",
		"pos": Vector3(-8.6, 0.0, 8.4),
		"icon": "⚔️",
	},
	{
		"id": &"coleta_oficios",
		"title": "Passo 4/8 · Coleta na Natureza & Central [TAB]",
		"short": "Saia pelo Portão Sul, colete recursos [E] ou abra a Central [TAB]",
		"detail": "Desça a Avenida Sul, passe pela Colina da Capela e saia pelo portal! Colete madeira, pedra ou fibra com [E] e abra a Central do Andarilho [TAB] para fabricar Tocha [T], Laço e Vara de Pesca.",
		"pos": Vector3(-1.5, 0.0, 44.0),
		"icon": "🌲",
	},
	{
		"id": &"rio_pesca",
		"title": "Passo 5/8 · O Rio Vivo, Nado & Pesca",
		"short": "Vá ao Cais do Rio, a leste da praça (9.0, 2.2)",
		"detail": "Ande até a ponta do píer, onde o Seu Lambari pesca! No rio você pode nadar, mergulhar no leito fundo, ver a cheia quando chove e usar sua Vara de Pesca.",
		"pos": Vector3(7.6, 0.0, 2.8),
		"icon": "🌊",
	},
	{
		"id": &"cacada_besta",
		"title": "Passo 6/8 · Caçada Anatômica: Besta de Sucata",
		"short": "Saia pelo Portão Norte até o Covil (-5, -11), quebre o chifre e esfole [E]",
		"detail": "Siga o caminho dourado até o Covil da Besta de Sucata! Golpeie a cabeça para quebrar o chifre (ou abata com cuidado para Chifre 3★ Íntegro) e segure [E] no corpo para esfolar.",
		"pos": Vector3(-5.0, 0.0, -11.0),
		"icon": "🦴",
	},
	{
		"id": &"forja_obras",
		"title": "Passo 7/8 · Bigorna da Forja & Obras da Vila",
		"short": "Volte à Bigorna da Rua da Forja (-8.6, 3.0) ou visite o Quadro de Obras",
		"detail": "Na Bigorna da Vila [E] você transforma partes de criaturas em equipamentos com habilidades ativas! Na chegada da praça, no Quadro de Obras (4.4, 1.2), você reconstrói a cidade.",
		"pos": Vector3(-7.6, 0.0, 4.6),
		"icon": "⚒️",
	},
	{
		"id": &"taverna_mundo",
		"title": "Passo 8/8 · Taverna, Céu, Mapa [M] & Coop [F7]",
		"short": "Visite a Mesa de Cartas na varanda da Taverna (-3.6, 18.2) ou abra o Mapa [M]",
		"detail": "Jogue Duelo de Cepas na Taverna ([K] abre o Álbum), olhe para o Planeta com Anéis no céu, erga sua base com [B], convide amigos no [F7] e abra o Mapa [M] para viajar a Porto Bruma, Vigia do Norte e Santuário Astral!",
		"pos": Vector3(-2.4, 0.0, 17.2),
		"icon": "🗺️",
	},
]

var current_step: int = 0
var is_completed: bool = false
var trail_visible: bool = true

var _station_nodes: Array[Node3D] = []
var _beacons: Array[MeshInstance3D] = []
var _beacon_mat: StandardMaterial3D
var _active_pillar_mat: StandardMaterial3D
var _done_pillar_mat: StandardMaterial3D
var _pending_pillar_mat: StandardMaterial3D
var _time: float = 0.0

var _hud_layer: CanvasLayer
var _hud_panel: PanelContainer
var _step_title_lbl: Label
var _step_desc_lbl: Label
var _dist_lbl: Label

func _ready() -> void:
	add_to_group("tutorial_trail")
	if landscape == null and get_parent():
		landscape = get_parent().get_node_or_null("Landscape")
	if player == null and get_parent():
		player = get_parent().get_node_or_null("Player") as Player

	_init_materials()
	_build_stations()
	_build_beacon_pool()
	_build_hud_tracker()
	_refresh_stations()

func _ground_y(x: float, z: float) -> float:
	if landscape and landscape.has_method("get_height_at"):
		return landscape.get_height_at(x, z)
	return 0.0

func _init_materials() -> void:
	_beacon_mat = StandardMaterial3D.new()
	_beacon_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_beacon_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_beacon_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_beacon_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_beacon_mat.albedo_texture = soft_dot()
	_beacon_mat.albedo_color = Color(1.0, 0.85, 0.45, 0.85)

	_active_pillar_mat = StandardMaterial3D.new()
	_active_pillar_mat.albedo_color = Color(0.98, 0.84, 0.35)
	_active_pillar_mat.emission_enabled = true
	_active_pillar_mat.emission = Color(0.92, 0.72, 0.22)
	_active_pillar_mat.emission_energy_multiplier = 2.2

	_done_pillar_mat = StandardMaterial3D.new()
	_done_pillar_mat.albedo_color = Color(0.32, 0.78, 0.48)
	_done_pillar_mat.emission_enabled = true
	_done_pillar_mat.emission = Color(0.22, 0.58, 0.35)
	_done_pillar_mat.emission_energy_multiplier = 1.1

	_pending_pillar_mat = StandardMaterial3D.new()
	_pending_pillar_mat.albedo_color = Color(0.38, 0.42, 0.40)
	_pending_pillar_mat.roughness = 0.85

func _build_stations() -> void:
	for i in TRAIL_STEPS.size():
		var step: Dictionary = TRAIL_STEPS[i]
		var pos: Vector3 = step.pos
		var st := TutorialStationNode.new()
		st.name = "EstacaoTutorial_%d" % (i + 1)
		st.step_index = i
		st.trail = self
		st.position = Vector3(pos.x, _ground_y(pos.x, pos.z), pos.z)
		add_child(st)
		_station_nodes.append(st)

static var _soft_dot: GradientTexture2D

## Mancha redonda de borda suave (brilho da lanterna e das luzinhas-guia).
static func soft_dot() -> GradientTexture2D:
	if _soft_dot == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.3, Color(1, 1, 1, 0.7))
		_soft_dot = GradientTexture2D.new()
		_soft_dot.gradient = g
		_soft_dot.fill = GradientTexture2D.FILL_RADIAL
		_soft_dot.fill_from = Vector2(0.5, 0.5)
		_soft_dot.fill_to = Vector2(0.5, 0.0)
		_soft_dot.width = 64
		_soft_dot.height = 64
	return _soft_dot

## Luzinhas-guia (B25: no lugar das esferas amarelas): pontos de luz suaves rente ao chão.
func _build_beacon_pool() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(0.22, 0.22)
	for i in BEACON_COUNT:
		var b := MeshInstance3D.new()
		b.name = "TrailBeacon_%d" % i
		b.mesh = quad
		b.material_override = _beacon_mat
		b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(b)
		_beacons.append(b)

func _build_hud_tracker() -> void:
	_hud_layer = CanvasLayer.new()
	_hud_layer.layer = 5
	add_child(_hud_layer)

	_hud_panel = PanelContainer.new()
	_hud_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_hud_panel.position = Vector2(18, -102)
	_hud_panel.custom_minimum_size = Vector2(320, 78)

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.09, 0.08, 0.62)
	sb.border_color = Color(0.86, 0.72, 0.36, 0.72)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	_hud_panel.add_theme_stylebox_override("panel", sb)
	_hud_layer.add_child(_hud_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	_hud_panel.add_child(vbox)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 6)
	vbox.add_child(top_row)

	_step_title_lbl = Label.new()
	_step_title_lbl.add_theme_font_size_override("font_size", 12)
	_step_title_lbl.add_theme_color_override("font_color", Color(0.98, 0.88, 0.52))
	_step_title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(_step_title_lbl)

	_dist_lbl = Label.new()
	_dist_lbl.add_theme_font_size_override("font_size", 11)
	_dist_lbl.add_theme_color_override("font_color", Color(0.68, 0.94, 0.76))
	top_row.add_child(_dist_lbl)

	_step_desc_lbl = Label.new()
	_step_desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_step_desc_lbl.add_theme_font_size_override("font_size", 11)
	_step_desc_lbl.add_theme_color_override("font_color", Color(0.88, 0.90, 0.88))
	vbox.add_child(_step_desc_lbl)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 6)
	vbox.add_child(btn_row)

	var next_btn := Button.new()
	next_btn.text = "⏭️ Próximo"
	next_btn.custom_minimum_size = Vector2(90, 22)
	next_btn.add_theme_font_size_override("font_size", 11)
	next_btn.focus_mode = Control.FOCUS_NONE
	next_btn.pressed.connect(advance_step)
	btn_row.add_child(next_btn)

	var map_btn := Button.new()
	map_btn.text = "🗺️ Mapa (M)"
	map_btn.custom_minimum_size = Vector2(90, 22)
	map_btn.add_theme_font_size_override("font_size", 11)
	map_btn.focus_mode = Control.FOCUS_NONE
	map_btn.pressed.connect(_open_world_map)
	btn_row.add_child(map_btn)

	var toggle_btn := Button.new()
	toggle_btn.text = "👁️ Ocultar"
	toggle_btn.custom_minimum_size = Vector2(85, 22)
	toggle_btn.add_theme_font_size_override("font_size", 11)
	toggle_btn.focus_mode = Control.FOCUS_NONE
	toggle_btn.pressed.connect(func() -> void:
		trail_visible = not trail_visible
		toggle_btn.text = "👁️ Ocultar" if trail_visible else "👁️ Mostrar"
		_refresh_stations()
	)
	btn_row.add_child(toggle_btn)

func _open_world_map() -> void:
	if not is_inside_tree() or get_tree().current_scene == null:
		return
	var map_screen := get_tree().current_scene.find_child("WorldMapScreen", true, false)
	if map_screen and map_screen.has_method("open_map"):
		map_screen.open_map(player)

func _process(delta: float) -> void:
	_time += delta
	if player == null and is_inside_tree():
		player = get_tree().get_first_node_in_group("player") as Player
	if player == null:
		return

	if _hud_panel and is_inside_tree():
		var menus_empty := get_tree().get_nodes_in_group("open_menus").is_empty()
		_hud_panel.visible = menus_empty and not is_completed and trail_visible

	if is_completed or not trail_visible:
		for b in _beacons:
			b.visible = false
		return

	_check_auto_progress()
	_update_beacons_and_hud()

func _check_auto_progress() -> void:
	if is_completed or current_step >= TRAIL_STEPS.size():
		return
	var step_id: StringName = TRAIL_STEPS[current_step].id
	var scene := get_tree().current_scene if is_inside_tree() else null
	if scene == null:
		return

	match step_id:
		&"despertar":
			var shop := scene.find_child("CosmeticsShop", true, false)
			var stylist := scene.get_node_or_null("CharacterStylist") as Node3D
			if (shop and shop.get("is_open")) or (stylist and player.global_position.distance_to(stylist.global_position) < 3.2):
				advance_step()
		&"suprimentos":
			var inv_screen := scene.find_child("InventoryScreen", true, false) as CanvasItem
			var chest := scene.get_node_or_null("SupplyChest") as Node3D
			if (inv_screen and inv_screen.visible) or (chest and player.global_position.distance_to(chest.global_position) < 2.6):
				advance_step()
		&"armas":
			var trainer := scene.get_node_or_null("WeaponTrainer") as Node3D
			if trainer and player.global_position.distance_to(trainer.global_position) < 3.2:
				advance_step()
		&"coleta_oficios":
			var act := scene.find_child("ActionsMenu", true, false)
			var target_pos: Vector3 = TRAIL_STEPS[current_step].pos
			if (act and act.get("is_open")) or Vector2(player.global_position.x - target_pos.x, player.global_position.z - target_pos.z).length() < 4.5:
				advance_step()
		&"rio_pesca":
			var target_pos: Vector3 = TRAIL_STEPS[current_step].pos
			if RiverSystem.is_in_water(player.global_position) or Vector2(player.global_position.x - target_pos.x, player.global_position.z - target_pos.z).length() < 5.0:
				advance_step()
		&"cacada_besta":
			var obj := get_node_or_null("/root/Objectives")
			if obj and (obj.call("is_done", &"harvest") or obj.call("is_done", &"break")):
				advance_step()
		&"forja_obras":
			var obj := get_node_or_null("/root/Objectives")
			if obj and obj.call("is_done", &"forge"):
				advance_step()
		&"taverna_mundo":
			var map_s := scene.find_child("WorldMapScreen", true, false)
			var album := scene.find_child("CardAlbum", true, false)
			if (map_s and map_s.get("is_open")) or (album and bool(album.get("visible"))):
				advance_step()

func _update_beacons_and_hud() -> void:
	var step: Dictionary = TRAIL_STEPS[current_step]
	var target: Vector3 = step.pos
	target.y = _ground_y(target.x, target.z)

	var p_pos := player.global_position
	var flat_delta := Vector2(target.x - p_pos.x, target.z - p_pos.z)
	var dist := flat_delta.length()

	if _step_title_lbl:
		_step_title_lbl.text = "%s %s" % [step.icon, step.title]
	if _step_desc_lbl:
		_step_desc_lbl.text = str(step.short)
	if _dist_lbl:
		_dist_lbl.text = "📍 %.0f m" % dist

	# Posiciona as Pedras-Guia Luminosas no chão entre o player e a estação atual
	for i in BEACON_COUNT:
		var b := _beacons[i]
		b.visible = dist > 2.2
		if not b.visible:
			continue
		var t := float(i + 1) / float(BEACON_COUNT + 1)
		var bx := lerpf(p_pos.x, target.x, t)
		var bz := lerpf(p_pos.z, target.z, t)
		var by := _ground_y(bx, bz)
		var wave := sin(_time * 4.5 - float(i) * 0.55)
		b.global_position = Vector3(bx, by + 0.22 + maxf(0.0, wave) * 0.14, bz)
		var s := 0.85 + maxf(0.0, wave) * 0.45
		b.scale = Vector3.ONE * s

func advance_step() -> void:
	if is_completed:
		return
	current_step += 1
	if current_step >= TRAIL_STEPS.size():
		is_completed = true
		_refresh_stations()
		for b in _beacons:
			b.visible = false
		if player and player.has_signal("posture_changed"):
			player.posture_changed.emit("🎓 Trilha do Iniciado concluída! Abra o Mapa [M] para explorar todas as vilas e regiões.")
		trail_completed.emit()
		return

	_refresh_stations()
	var step: Dictionary = TRAIL_STEPS[current_step]
	if player and player.has_signal("posture_changed"):
		player.posture_changed.emit("%s %s — %s" % [step.icon, step.title, step.short])
	step_changed.emit(current_step, step)

func jump_to_step(index: int) -> void:
	current_step = clampi(index, 0, TRAIL_STEPS.size() - 1)
	is_completed = false
	trail_visible = true
	_refresh_stations()

func _refresh_stations() -> void:
	for i in _station_nodes.size():
		var st := _station_nodes[i]
		st.visible = trail_visible
		if is_completed or i < current_step:
			st.set_visual_state(1, _done_pillar_mat)
		elif i == current_step:
			st.set_visual_state(0, _active_pillar_mat)
		else:
			st.set_visual_state(-1, _pending_pillar_mat)


## Marco físico de cada Estação do Tutorial (interativo com [E])
class TutorialStationNode extends Node3D:
	var step_index: int = 0
	var trail: TutorialTrail
	var _ribbons: Array[MeshInstance3D] = []  # fita na cor do estado (B25: sai a esfera)
	var _lantern_light: OmniLight3D
	var _lantern_glow: MeshInstance3D
	var _label: _WorldLabel
	var _prompt: _WorldLabel

	func _ready() -> void:
		add_to_group("talkable")
		_build()

	## Estaca de madeira com ponta, fita amarrada e lanterna pendurada.
	func _build() -> void:
		var wood := StandardMaterial3D.new()
		wood.albedo_color = Color(0.4, 0.27, 0.15)
		wood.roughness = 0.92

		var stake := Node3D.new()
		stake.rotation = Vector3(deg_to_rad(3.0), float(step_index) * 2.1, deg_to_rad(-2.0))  # fincada à mão
		add_child(stake)
		var post := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.09
		cyl.bottom_radius = 0.11
		cyl.height = 1.5
		cyl.radial_segments = 6  # facetada, cara de tora lascada
		cyl.rings = 1
		post.mesh = cyl
		post.material_override = wood
		post.position.y = 0.75
		stake.add_child(post)
		var tip := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 0.09
		cone.height = 0.22
		cone.radial_segments = 6
		cone.rings = 1
		tip.mesh = cone
		tip.material_override = wood
		tip.position.y = 1.61
		stake.add_child(tip)

		# Fita: volta amarrada na estaca e duas pontas soltas
		var knot := MeshInstance3D.new()
		var band := CylinderMesh.new()
		band.top_radius = 0.105
		band.bottom_radius = 0.105
		band.height = 0.07
		band.radial_segments = 6
		knot.mesh = band
		knot.position.y = 1.32
		stake.add_child(knot)
		_ribbons.append(knot)
		for i in 2:
			var tail := MeshInstance3D.new()
			var strip := BoxMesh.new()
			strip.size = Vector3(0.05, 0.42 - i * 0.1, 0.008)
			tail.mesh = strip
			tail.position = Vector3(0.1, 1.12 + i * 0.04, 0.03 - i * 0.05)
			tail.rotation = Vector3(0.1, 0.4 * i, 0.25 + i * 0.15)
			tail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			stake.add_child(tail)
			_ribbons.append(tail)

		# Lanterna pendurada num toco de galho que sai da estaca
		var peg := MeshInstance3D.new()
		var peg_mesh := CylinderMesh.new()
		peg_mesh.top_radius = 0.022
		peg_mesh.bottom_radius = 0.03
		peg_mesh.height = 0.3
		peg_mesh.radial_segments = 5
		peg.mesh = peg_mesh
		peg.material_override = wood
		peg.position = Vector3(0, 1.2, 0.17)
		peg.rotation.x = deg_to_rad(80.0)
		stake.add_child(peg)
		var lantern := LANTERN_SCENE.instantiate() as Node3D
		if lantern:
			lantern.scale = Vector3.ONE * 0.32
			lantern.position = Vector3(0, 0.86, 0.29)
			stake.add_child(lantern)
		_lantern_glow = MeshInstance3D.new()
		var glow := QuadMesh.new()
		glow.size = Vector2(0.35, 0.35)
		var glow_mat := StandardMaterial3D.new()
		glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		glow_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		glow_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		glow_mat.albedo_texture = TutorialTrail.soft_dot()
		glow_mat.albedo_color = Color(1.0, 0.75, 0.35, 0.8)
		glow.material = glow_mat
		_lantern_glow.mesh = glow
		_lantern_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_lantern_glow.position = Vector3(0, 0.98, 0.29)
		stake.add_child(_lantern_glow)
		_lantern_light = OmniLight3D.new()
		_lantern_light.light_color = Color(1.0, 0.72, 0.4)
		_lantern_light.omni_range = 3.0
		_lantern_light.light_energy = 1.1
		_lantern_light.shadow_enabled = false  # B25: sombra só nas 6 luzes grandes da vila
		_lantern_light.distance_fade_enabled = true
		_lantern_light.distance_fade_begin = 35.0
		_lantern_light.distance_fade_length = 10.0
		_lantern_light.position = Vector3(0, 0.98, 0.35)
		stake.add_child(_lantern_light)

		var step: Dictionary = TutorialTrail.TRAIL_STEPS[step_index]
		_label = _WorldLabel.make(_WorldLabel.Kind.NAME, "➤ %s %s" % [step.icon, step.title], step.icon)
		_label.position.y = 2.2
		add_child(_label)
		_prompt = _WorldLabel.make(_WorldLabel.Kind.PROMPT, "[E] Concluir Passo")
		_prompt.position.y = 2.0
		add_child(_prompt)

	func set_visual_state(state: int, mat: Material) -> void:
		for r in _ribbons:
			r.material_override = mat
		# Lanterna acesa só no passo atual
		if _lantern_light:
			_lantern_light.visible = (state == 0)
		if _lantern_glow:
			_lantern_glow.visible = (state == 0)
		# Só o passo atual mostra nome e [E]; os outros ficam calados
		if _label:
			_label.active = (state == 0)
		if _prompt:
			_prompt.active = (state == 0)

	func talk_to(p: Node) -> void:
		if trail == null:
			return
		var step: Dictionary = TutorialTrail.TRAIL_STEPS[step_index]
		if p and p.has_signal("posture_changed"):
			p.posture_changed.emit("%s %s: %s" % [step.icon, step.title, step.detail])
		if trail.current_step == step_index:
			trail.advance_step()
		else:
			trail.jump_to_step(step_index)
