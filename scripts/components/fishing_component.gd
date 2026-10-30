class_name FishingComponent
extends Node

## Pesca (GDD-10 §8). Com a Vara de Pesca na roda rápida, [G] lança a boia na água à frente.
## A boia atrai um peixe de verdade do rio (WildCreature do grupo "fish") que esteja perto;
## sem peixe por perto, nada morde. Quando ele fisga, a boia afunda: clique na hora.
## Depois é a briga: segurar o clique recolhe e estica a linha, soltar afrouxa. Linha esticada
## demais arrebenta; frouxa demais o peixe escapa. O peixe pescado sai do rio (o ecossistema
## repõe com o tempo) e vira item com qualidade pelo porte do DNA.
## Nada desacelera o tempo; andar, nadar, montar ou levar dano recolhe a linha.

signal state_changed(state: State)

enum State { IDLE, CASTING, WAITING, BITE, REELING }

const CAST_DISTANCE: float = 7.0
const CAST_TIME: float = 0.7
const ROD_LENGTH: float = 1.9
## Raio em volta da boia em que um peixe sente a isca
const LURE_RADIUS: float = 9.0
## Espera pela mordida (s), antes dos bônus
const BITE_WAIT: Vector2 = Vector2(6.0, 14.0)
## Sem peixe perto, desiste depois disso
const EMPTY_WAIT: float = 20.0
## Janela para fisgar depois que a boia afunda (s)
const HOOK_WINDOW: float = 1.0
const REEL_TENSION_UP: float = 0.5
const REEL_TENSION_DOWN: float = 0.65
const SLACK_ESCAPE: float = 2.5
## Por espécie: força dos puxões (tensão somada), progresso por segundo recolhendo, item e XP
const FISH: Dictionary = {
	CreatureDNA.Species.LAMBARI: {"pull": 0.12, "reel": 0.45, "item": &"peixe_lambari", "xp": 4.0},
	CreatureDNA.Species.TRAIRA: {"pull": 0.22, "reel": 0.28, "item": &"peixe_traira", "xp": 10.0},
	CreatureDNA.Species.DOURADO: {"pull": 0.32, "reel": 0.2, "item": &"peixe_dourado", "xp": 22.0},
}

var player: Player
var state: State = State.IDLE
var bobber_pos: Vector3
var fish: WildCreature
var tension: float = 0.0
var progress: float = 0.0
var used_bait: bool = false

var _timer: float = 0.0
var _slack: float = 0.0
var _pull: float = 0.0
var _next_pull: float = 0.0
var _start_health: float = 0.0
var _rng := RandomNumberGenerator.new()
var _bobber: MeshInstance3D
var _line: MeshInstance3D
var _line_mesh: ImmediateMesh
var _rod: MeshInstance3D
var _ui: Control
var _tension_bar: ProgressBar
var _progress_bar: ProgressBar
var _hint: Label
var _splash: AudioStreamPlayer3D

func _ready() -> void:
	if player == null:
		player = get_parent() as Player
	_rng.randomize()

func is_busy() -> bool:
	return state != State.IDLE

## [G] com a vara: lança se está parado, recolhe se já está pescando
func toggle() -> bool:
	if state != State.IDLE:
		stop("🎣 Você recolheu a linha")
		return true
	return cast()

func cast() -> bool:
	if player == null or state != State.IDLE:
		return false
	if player.is_swimming or player.mounted_on != null or player.is_downed:
		_say("🎣 Pesque com os pés no chão, da margem ou do raso")
		return false
	var spot := _cast_point()
	if spot == Vector3.INF:
		_say("🎣 Vire para a água: a boia precisa cair no rio (até %d m)" % CAST_DISTANCE)
		return false
	return cast_at(spot)

## Lança a boia num ponto da água (também usado pelos testes)
func cast_at(spot: Vector3) -> bool:
	if not RiverSystem.is_in_water(Vector3(spot.x, RiverSystem.get_water_height(spot.z), spot.z)):
		return false
	bobber_pos = Vector3(spot.x, RiverSystem.get_water_height(spot.z), spot.z)
	used_bait = player.inventory != null and player.inventory.consume_materials({&"besouro": 1})
	_start_health = player.pools.current_health if player.pools else 0.0
	_set_state(State.CASTING)
	_timer = CAST_TIME
	_build_visuals()
	if player.character_visual:
		player.character_visual.play_timed(&"OverhandThrow", CAST_TIME, true)
	_say("🎣 Linha na água%s · espere a boia afundar" % (" (isca de besouro)" if used_bait else ""))
	return true

## Recolhe tudo e solta o peixe que estava vindo ou fisgado
func stop(msg: String = "") -> void:
	if fish and is_instance_valid(fish):
		fish.lure = Vector3.INF
		fish.hooked = false
	fish = null
	tension = 0.0
	progress = 0.0
	_set_state(State.IDLE)
	_clear_visuals()
	if not msg.is_empty():
		_say(msg)

func _process(delta: float) -> void:
	if state == State.IDLE or player == null:
		return
	var menus_open := not get_tree().get_nodes_in_group("open_menus").is_empty()
	tick(delta, Input.is_action_pressed("attack") and not menus_open, Input.is_action_just_pressed("attack") and not menus_open)
	_update_visuals()

## Um passo da pesca. `reel` = segurando o clique; `click` = clicou neste frame.
func tick(delta: float, reel: bool, click: bool) -> void:
	if player.wants_move or player.is_swimming or player.mounted_on != null or player.is_downed:
		stop("🎣 Linha recolhida")
		return
	if player.pools and player.pools.current_health < _start_health:
		stop("🎣 O golpe fez você soltar a linha!")
		return
	match state:
		State.CASTING:
			_timer -= delta
			if _timer <= 0.0:
				_play_splash(-14.0)
				_set_state(State.WAITING)
				_timer = _bite_wait()
		State.WAITING:
			if fish == null or not is_instance_valid(fish) or not fish.is_alive():
				fish = _find_fish()
				if fish:
					fish.lure = bobber_pos
			_timer -= delta
			if _timer <= 0.0:
				if fish == null:
					stop("🎣 Nenhum peixe por aqui. Tente outro ponto do rio")
					return
				_set_state(State.BITE)
				_timer = HOOK_WINDOW
				_play_splash(-6.0)
				_say("❗ A boia afundou! CLIQUE para fisgar")
		State.BITE:
			if click:
				_hook()
				return
			_timer -= delta
			if _timer <= 0.0:
				var name := fish.dna.species_name() if fish and is_instance_valid(fish) else "peixe"
				stop("🐟 O %s roubou a isca e fugiu. Clique mais rápido quando a boia afundar" % name)
		State.REELING:
			_reel(delta, reel)

func _hook() -> void:
	if fish == null or not is_instance_valid(fish):
		stop("🐟 Escapou")
		return
	fish.hooked = true
	fish.lure = Vector3.INF
	tension = 0.35
	progress = 0.0
	_slack = 0.0
	_next_pull = _rng.randf_range(0.6, 1.6)
	_set_state(State.REELING)
	_say("🎣 Fisgou um %s! Segure o clique para recolher, solte se a linha esticar demais" % fish.dna.species_name())

func _reel(delta: float, reel: bool) -> void:
	if fish == null or not is_instance_valid(fish):
		stop("🐟 Escapou")
		return
	var info: Dictionary = FISH.get(fish.dna.species, FISH[CreatureDNA.Species.LAMBARI])
	var strength := float(info["pull"]) * (0.7 + 0.6 * fish.dna.size_factor())
	# Puxões do peixe: de tempos em tempos ele dispara e estica a linha por um instante
	_next_pull -= delta
	if _next_pull <= 0.0:
		_pull = 0.45
		_next_pull = _rng.randf_range(0.9, 2.4)
	var pulling := _pull > 0.0
	_pull = maxf(0.0, _pull - delta)
	if reel:
		tension += REEL_TENSION_UP * delta
		progress += float(info["reel"]) * delta * (0.35 if pulling else 1.0)
	else:
		tension -= REEL_TENSION_DOWN * delta
		progress = maxf(0.0, progress - 0.04 * delta)
	if pulling:
		tension += strength * delta / 0.45
	tension = clampf(tension, 0.0, 1.0)
	_slack = _slack + delta if tension <= 0.05 else 0.0
	if tension >= 1.0:
		stop("💥 A linha arrebentou! O %s levou%s" % [fish.dna.species_name(), " a isca" if used_bait else ""])
		return
	if _slack >= SLACK_ESCAPE:
		stop("🐟 Linha frouxa demais: o %s escapou" % fish.dna.species_name())
		return
	# O peixe vem vindo para a margem conforme recolhe
	var rod_tip := _rod_tip()
	var from := bobber_pos
	var target := from.lerp(Vector3(rod_tip.x, from.y, rod_tip.z), progress * 0.8)
	target.y = RiverSystem.get_water_height(target.z) - 0.15
	fish.global_position = fish.global_position.lerp(target + Vector3(sin(Time.get_ticks_msec() * 0.008) * 0.3 * (1.0 if pulling else 0.3), 0, 0), minf(1.0, delta * 4.0))
	if progress >= 1.0:
		_land_fish()

func _land_fish() -> void:
	var c := fish
	var info: Dictionary = FISH.get(c.dna.species, FISH[CreatureDNA.Species.LAMBARI])
	# Qualidade pelo porte: tt 1★ · Tt 2★ · TT 3★; mutante +1★ com a cor rara
	var quality := {0.5: 1, 0.75: 2, 1.0: 3}.get(c.dna.size_factor(), 1) as int
	var traits: Array = []
	if c.dna.is_mutant():
		quality += 1
		traits.append(&"mutante")
	var item: StringName = info["item"]
	if player.inventory:
		player.inventory.add_material(item, 1, quality, traits)
	EventBusAutoload.report(player, &"pesca", {"material": String(item), "species": c.dna.species_name(), "quality": quality})
	if player.mastery:
		player.mastery.add_xp(&"coleta", float(info["xp"]))
	fish = null
	c.hooked = false
	c.take_away()
	stop()
	_play_splash(-8.0)
	_say("🐟 Pescou: %s %s" % [MaterialData.of(item).display_name, "★".repeat(quality)])

func _find_fish() -> WildCreature:
	var best: WildCreature = null
	var best_d := LURE_RADIUS
	for n in get_tree().get_nodes_in_group("fish"):
		var c := n as WildCreature
		if c == null or not c.is_alive() or c.hooked or (c.lure != Vector3.INF and c.lure != bobber_pos):
			continue
		if not FISH.has(c.dna.species):
			continue
		var d := c.global_position.distance_to(bobber_pos)
		if d < best_d:
			best = c
			best_d = d
	return best

## Espera da mordida: isca, alvorada/entardecer e chuva apressam
func _bite_wait() -> float:
	var t := _rng.randf_range(BITE_WAIT.x, BITE_WAIT.y)
	if used_bait:
		t *= 0.6
	var sun := get_tree().current_scene.get_node_or_null("Sun") if get_tree().current_scene else null
	var hour: float = sun.get("current_time_hours") if sun and sun.get("current_time_hours") != null else 12.0
	if (hour >= 5.0 and hour <= 8.0) or (hour >= 17.0 and hour <= 19.5):
		t *= 0.7
	var weather := get_tree().get_first_node_in_group("weather")
	if weather and float(weather.get("rain")) > 0.3:
		t *= 0.8
	return maxf(t, 2.0) if _find_fish() else EMPTY_WAIT

## Ponto da água à frente da câmera, de perto para longe até CAST_DISTANCE
func _cast_point() -> Vector3:
	var yaw: float = player.camera_rig.global_rotation.y if player.camera_rig else player.visual_mesh.global_rotation.y
	var fwd := -Basis(Vector3.UP, yaw).z
	for i in range(int(CAST_DISTANCE), 1, -1):
		var p := player.global_position + fwd * float(i)
		var surface := RiverSystem.get_water_height(p.z)
		if RiverSystem.is_in_water(Vector3(p.x, surface, p.z)) and player._ground_at(p.x, p.z) < surface - 0.2:
			return Vector3(p.x, surface, p.z)
	return Vector3.INF

func _set_state(s: State) -> void:
	state = s
	state_changed.emit(s)
	if _ui:
		_ui.visible = s == State.REELING or s == State.BITE

func _say(msg: String) -> void:
	if player:
		player.posture_changed.emit(msg)

# ---------------------------------------------------------------- visual

func _rod_tip() -> Vector3:
	if _rod and _rod.is_inside_tree():
		return _rod.global_transform * Vector3(0, ROD_LENGTH * 0.5, 0)
	return player.global_position + Vector3(0, 1.8, 0)

## Mão direita no mundo (osso hand_r); sem esqueleto, à frente do peito
func _hand() -> Vector3:
	var cv := player.character_visual
	if cv and cv.skeleton:
		var bone := cv.skeleton.find_bone(&"hand_r")
		if bone >= 0:
			return cv.skeleton.global_transform * cv.skeleton.get_bone_global_pose(bone).origin
	return player.global_position + Vector3(0, 1.1, 0)

## A vara sai da mão inclinada para a boia; esticada, a ponta sobe e enverga para trás
func _place_rod() -> void:
	if _rod == null:
		return
	var to := bobber_pos - player.global_position
	to.y = 0.0
	var fwd := to.normalized() if to.length() > 0.1 else Vector3.FORWARD
	var lift := 0.55 + (tension * 0.6 if state == State.REELING else 0.0)
	var dir := (fwd + Vector3.UP * lift).normalized()
	var side := fwd.cross(Vector3.UP).normalized()
	var basis := Basis(side, dir, side.cross(dir).normalized())
	_rod.global_transform = Transform3D(basis, _hand() + dir * (ROD_LENGTH * 0.5 - 0.1))

func _build_visuals() -> void:
	if not player.is_inside_tree():
		return
	var world := player.get_parent()
	if _bobber == null:
		_bobber = MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.11
		sm.height = 0.22
		_bobber.mesh = sm
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.9, 0.15, 0.1)
		m.emission_enabled = true
		m.emission = Color(0.5, 0.05, 0.02)
		_bobber.material_override = m
		_bobber.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		world.add_child(_bobber)
		_line_mesh = ImmediateMesh.new()
		_line = MeshInstance3D.new()
		_line.mesh = _line_mesh
		var lm := StandardMaterial3D.new()
		lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		lm.albedo_color = Color(0.12, 0.1, 0.08)
		_line.material_override = lm
		_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		world.add_child(_line)
		_splash = AudioStreamPlayer3D.new()
		_splash.bus = &"Efeitos"
		_splash.stream = load("res://assets/audio/Small_Sound_Kit/Small Sound Kit/Magic/Mgc_Water_Hit_Short_01.wav")
		world.add_child(_splash)
	if _rod == null and player.character_visual:
		_rod = MeshInstance3D.new()
		_rod.name = "FishingRod"
		var cm := CylinderMesh.new()
		cm.top_radius = 0.008
		cm.bottom_radius = 0.02
		cm.height = ROD_LENGTH
		_rod.mesh = cm
		var rm := StandardMaterial3D.new()
		rm.albedo_color = Color(0.55, 0.4, 0.22)
		_rod.material_override = rm
		_rod.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		player.get_parent().add_child(_rod)
	if _ui == null:
		_build_ui()
	_bobber.visible = true
	_line.visible = true
	if _rod:
		_rod.visible = true
	_set_weapon_visible(false)

func _clear_visuals() -> void:
	if _bobber:
		_bobber.visible = false
	if _line:
		_line.visible = false
	if _rod:
		_rod.visible = false
	_set_weapon_visible(true)

## Guarda arma e escudo enquanto segura a vara
func _set_weapon_visible(on: bool) -> void:
	if player:
		player.set_hand_gear_visible(on)

func _update_visuals() -> void:
	if _bobber == null or state == State.IDLE:
		return
	_place_rod()
	_face_bobber()
	var t := Time.get_ticks_msec() / 1000.0
	var pos := bobber_pos + Vector3(0, sin(t * 2.5) * 0.02, 0)
	if state == State.CASTING:
		pos = _rod_tip().lerp(bobber_pos, 1.0 - _timer / CAST_TIME) + Vector3(0, sin((1.0 - _timer / CAST_TIME) * PI) * 1.5, 0)
	elif state == State.BITE:
		pos.y -= 0.12
	elif state == State.REELING and fish and is_instance_valid(fish):
		pos = fish.global_position + Vector3(0, 0.15, 0)
		pos.y = RiverSystem.get_water_height(pos.z) - (0.05 if _pull > 0.0 else 0.0)
	_bobber.global_position = pos
	_line_mesh.clear_surfaces()
	_line_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	var a := _rod_tip()
	var sag := 0.6 * (1.0 - tension) if state == State.REELING else 0.5
	for i in 9:
		var k := i / 8.0
		_line_mesh.surface_add_vertex(a.lerp(pos, k) - Vector3(0, sin(k * PI) * sag, 0))
	_line_mesh.surface_end()
	if _ui and _ui.visible:
		_tension_bar.value = tension
		_progress_bar.value = progress
		_tension_bar.modulate = Color(1.0, 0.3, 0.25) if tension > 0.8 else (Color(1.0, 0.85, 0.3) if tension < 0.12 else Color(0.5, 0.9, 0.6))
		_hint.text = "❗ CLIQUE!" if state == State.BITE else ("Segure o clique para recolher · solte se esticar" if tension < 0.8 else "Solte! A linha vai arrebentar!")
	if player.character_visual and state != State.CASTING:
		player.character_visual.play(&"Spell_Simple_Idle" if state != State.REELING else &"Sword_Block", 1.0)

## Vira o corpo para a boia
func _face_bobber() -> void:
	var to := bobber_pos - player.global_position
	if to.length_squared() > 0.01 and player.visual_mesh:
		player.visual_mesh.rotation.y = lerp_angle(player.visual_mesh.rotation.y, atan2(-to.x, -to.z), 0.2)

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	_ui = VBoxContainer.new()
	_ui.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_ui.position = Vector2(-160, -190)
	_ui.custom_minimum_size = Vector2(320, 0)
	_ui.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_ui.visible = false
	layer.add_child(_ui)
	_hint = Label.new()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size", 18)
	_hint.add_theme_constant_override("outline_size", 6)
	_hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_ui.add_child(_hint)
	var t_label := Label.new()
	t_label.text = "Tensão da linha"
	_ui.add_child(t_label)
	_tension_bar = ProgressBar.new()
	_tension_bar.max_value = 1.0
	_tension_bar.show_percentage = false
	_tension_bar.custom_minimum_size = Vector2(320, 14)
	_ui.add_child(_tension_bar)
	var p_label := Label.new()
	p_label.text = "Recolhendo"
	_ui.add_child(p_label)
	_progress_bar = ProgressBar.new()
	_progress_bar.max_value = 1.0
	_progress_bar.show_percentage = false
	_progress_bar.custom_minimum_size = Vector2(320, 10)
	_progress_bar.modulate = Color(0.55, 0.8, 1.0)
	_ui.add_child(_progress_bar)

func _play_splash(volume: float) -> void:
	if _splash and _splash.is_inside_tree():
		_splash.global_position = bobber_pos
		_splash.volume_db = volume
		_splash.pitch_scale = _rng.randf_range(0.9, 1.2)
		_splash.play()

func _exit_tree() -> void:
	for n in [_bobber, _line, _splash, _rod]:
		if n and is_instance_valid(n):
			n.queue_free()
