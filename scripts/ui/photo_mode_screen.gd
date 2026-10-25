class_name PhotoModeScreen
extends Control

## Tela do Modo Foto & Câmera de Reconhecimento da Natureza (GDD-05 §5, GDD-04, GDD-03).
## Permite ao jogador enquadrar a fauna e flora, fotografar espécimes,
## cumprir contratos de reconhecimento ecológico e catalogar espécimes no Álbum de Cartas.

const _Player = preload("res://scripts/player.gd")
const _WildCreature = preload("res://scripts/creatures/wild_creature.gd")
const _CreatureDNA = preload("res://scripts/data/creature_dna.gd")
const _MissionBoardSystem = preload("res://scripts/systems/mission_board_system.gd")

signal photo_taken(subject_species: String, subject_name: String, metadata: Dictionary)

var player: _Player
var mission_system: _MissionBoardSystem
var is_active: bool = false
var zoom_level: float = 1.0

var _flash_rect: ColorRect
var _reticle_box: PanelContainer
var _subject_label: Label
var _distance_label: Label
var _zoom_label: Label
var _toast_banner: PanelContainer
var _toast_label: Label
var _toast_timer: float = 0.0

var _current_target: Node3D = null
var _current_species: String = ""
var _current_name: String = ""

func _ready() -> void:
	add_to_group("photo_mode")
	visible = false
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	_build_ui()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_P:
			if is_active:
				close_photo_mode()
			else:
				open_photo_mode(player)
			get_viewport().set_input_as_handled()
		elif is_active and event.keycode == KEY_ESCAPE:
			close_photo_mode()
			get_viewport().set_input_as_handled()
		elif is_active and event.keycode == KEY_SPACE:
			take_photo()
			get_viewport().set_input_as_handled()
	elif is_active and event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_adjust_zoom(0.2)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_adjust_zoom(-0.2)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			take_photo()
			get_viewport().set_input_as_handled()

func open_photo_mode(p_player: _Player = null) -> void:
	if p_player != null:
		player = p_player
	if player == null and is_inside_tree():
		player = get_tree().get_first_node_in_group("player") as _Player
	is_active = true
	visible = true
	add_to_group("open_menus")
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_show_toast("📷 Modo Foto Ativado. [Espaço] / [Clique] para fotografar.")

func close_photo_mode() -> void:
	if not is_active:
		return
	is_active = false
	visible = false
	remove_from_group("open_menus")
	if is_inside_tree() and get_tree().get_nodes_in_group("open_menus").is_empty():
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _process(delta: float) -> void:
	if not is_active:
		return
	if _toast_timer > 0.0:
		_toast_timer -= delta
		if _toast_timer <= 0.0 and _toast_banner:
			_toast_banner.visible = false
	_scan_viewfinder()

func _scan_viewfinder() -> void:
	_current_target = null
	_current_species = ""
	_current_name = ""

	var cam := get_viewport().get_camera_3d()
	if cam == null:
		_reticle_box.visible = false
		return

	var cam_pos := cam.global_position
	var cam_fwd := -cam.global_transform.basis.z.normalized()

	var closest_target: Node3D = null
	var closest_dist: float = 40.0 # alcance da lente de 40 metros

	# Procura por criaturas selvagens
	var candidates: Array = []
	if is_inside_tree():
		candidates.append_array(get_tree().get_nodes_in_group("wild_creatures"))
		candidates.append_array(get_tree().get_nodes_in_group("plants"))

	for node in candidates:
		var n3d := node as Node3D
		if n3d == null or not n3d.is_inside_tree() or n3d.is_queued_for_deletion():
			continue
		var to_target := n3d.global_position - cam_pos
		var dist := to_target.length()
		if dist > closest_dist or dist < 1.0:
			continue
		var dir := to_target.normalized()
		var dot := cam_fwd.dot(dir)
		# Ângulo de foco dentro de 25 graus do centro da mira
		if dot > 0.90:
			closest_dist = dist
			closest_target = n3d

	if closest_target != null:
		_current_target = closest_target
		_reticle_box.visible = true
		_distance_label.text = "Distância: %.1f m" % closest_dist

		if closest_target is _WildCreature:
			var wc := closest_target as _WildCreature
			var sp_name := wc.dna.species_name() if wc.dna else "Criatura"
			var gender_str := "Macho" if wc.dna and wc.dna.is_male() else "Fêmea"
			var stage_str := "Adulto"
			if wc.dna:
				match wc.dna.stage:
					_CreatureDNA.LifeStage.BABY: stage_str = "Filhote"
					_CreatureDNA.LifeStage.JUVENILE: stage_str = "Jovem"
					_CreatureDNA.LifeStage.ADULT: stage_str = "Adulto"
					_CreatureDNA.LifeStage.ELDER: stage_str = "Ancião"
			_current_species = sp_name.to_lower()
			_current_name = "%s (%s, %s)" % [sp_name, gender_str, stage_str]
			_subject_label.text = "🎯 Espécime: %s" % _current_name
			_subject_label.add_theme_color_override("font_color", Color(0.4, 0.95, 0.5))
		else:
			# Planta / Pinheira
			_current_species = "pinheira" if closest_target.name.to_lower().contains("pinheira") else "cepa"
			_current_name = "Pinheira-Lume Nativa" if _current_species == "pinheira" else "Cepa Selvagem"
			_subject_label.text = "🌿 Botânica: %s" % _current_name
			_subject_label.add_theme_color_override("font_color", Color(0.5, 0.85, 1.0))
	else:
		_reticle_box.visible = false

func take_photo() -> void:
	# Flash do obturador
	_flash_rect.visible = true
	_flash_rect.color.a = 0.75
	var tween := create_tween()
	tween.tween_property(_flash_rect, "color:a", 0.0, 0.20)
	tween.tween_callback(func(): _flash_rect.visible = false)

	if _current_target != null and not _current_species.is_empty():
		var meta := {"name": _current_name, "distance": _distance_label.text, "zoom": zoom_level}
		photo_taken.emit(_current_species, _current_name, meta)

		# Avança contratos no MissionBoardSystem
		if mission_system:
			var completed := mission_system.record_photo(_current_species, meta)
			for comp in completed:
				_show_toast("🏆 Missão Concluída: %s!" % comp.title)

		# Desbloqueia carta no Álbum de Cartas do Jogador se aplicável
		if player and player.card_collection:
			var card_id := StringName(_current_species)
			player.card_collection.unlock_card(card_id)

		_show_toast("📸 Foto Registrada: %s! Salva no Diário de Campo!" % _current_name)
	else:
		_show_toast("📸 Paisagem do Vale fotografada!")

func _adjust_zoom(amount: float) -> void:
	zoom_level = clampf(zoom_level + amount, 1.0, 4.0)
	_zoom_label.text = "Zoom: %.1f×" % zoom_level
	var cam := get_viewport().get_camera_3d()
	if cam:
		cam.fov = 75.0 / zoom_level

func _show_toast(msg: String) -> void:
	_toast_label.text = msg
	_toast_banner.visible = true
	_toast_timer = 3.5

func _build_ui() -> void:
	# Borda / Vinheta do visor
	var border := ReferenceRect.new()
	border.set_anchors_preset(PRESET_FULL_RECT)
	border.border_color = Color(1.0, 1.0, 1.0, 0.3)
	border.border_width = 2.0
	border.editor_only = false
	add_child(border)

	# Linhas dos terços fotográficos
	var thirds_overlay := Control.new()
	thirds_overlay.set_anchors_preset(PRESET_FULL_RECT)
	thirds_overlay.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(thirds_overlay)

	# Barra superior de dados da câmera
	var top_bar := HBoxContainer.new()
	top_bar.set_anchors_preset(PRESET_TOP_WIDE)
	top_bar.offset_top = 16
	top_bar.offset_left = 32
	top_bar.offset_right = -32
	top_bar.add_theme_constant_override("separation", 24)
	add_child(top_bar)

	var mode_title := Label.new()
	mode_title.text = "📷 CÂMERA DE RECONHECIMENTO & MODO FOTO"
	mode_title.add_theme_font_size_override("font_size", 14)
	mode_title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	top_bar.add_child(mode_title)

	_zoom_label = Label.new()
	_zoom_label.text = "Zoom: 1.0×"
	_zoom_label.add_theme_font_size_override("font_size", 13)
	_zoom_label.size_flags_horizontal = SIZE_EXPAND_FILL
	top_bar.add_child(_zoom_label)

	var close_btn := Button.new()
	close_btn.text = " ✕ Sair [Esc] "
	close_btn.pressed.connect(close_photo_mode)
	top_bar.add_child(close_btn)

	# Caixa de identificação do espécime focado
	_reticle_box = PanelContainer.new()
	_reticle_box.set_anchors_preset(PRESET_CENTER)
	_reticle_box.offset_left = -160
	_reticle_box.offset_top = -120
	_reticle_box.offset_right = 160
	_reticle_box.offset_bottom = -50
	_reticle_box.visible = false

	var r_style := StyleBoxFlat.new()
	r_style.bg_color = Color(0.08, 0.1, 0.12, 0.82)
	r_style.border_color = Color(0.4, 0.9, 0.5)
	r_style.set_border_width_all(2)
	r_style.set_corner_radius_all(6)
	r_style.content_margin_left = 12
	r_style.content_margin_right = 12
	r_style.content_margin_top = 8
	r_style.content_margin_bottom = 8
	_reticle_box.add_theme_stylebox_override("panel", r_style)
	add_child(_reticle_box)

	var r_vbox := VBoxContainer.new()
	_reticle_box.add_child(r_vbox)

	_subject_label = Label.new()
	_subject_label.text = "🎯 Espécime em Foco"
	_subject_label.add_theme_font_size_override("font_size", 13)
	r_vbox.add_child(_subject_label)

	_distance_label = Label.new()
	_distance_label.text = "Distância: 12.0 m"
	_distance_label.add_theme_font_size_override("font_size", 11)
	_distance_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	r_vbox.add_child(_distance_label)

	# Mira central
	var crosshair := Label.new()
	crosshair.text = "⌜   ⌝\n⌞   ⌟"
	crosshair.set_anchors_preset(PRESET_CENTER)
	crosshair.offset_left = -25
	crosshair.offset_top = -25
	crosshair.offset_right = 25
	crosshair.offset_bottom = 25
	crosshair.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crosshair.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	crosshair.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.8))
	crosshair.add_theme_font_size_override("font_size", 22)
	crosshair.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(crosshair)

	# Barra inferior com botão de obturador
	var btm_bar := HBoxContainer.new()
	btm_bar.set_anchors_preset(PRESET_BOTTOM_WIDE)
	btm_bar.offset_bottom = -24
	btm_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(btm_bar)

	var shutter_btn := Button.new()
	shutter_btn.text = " 📸 Fotografar Espécime [Espaço] "
	shutter_btn.custom_minimum_size = Vector2(280, 44)
	shutter_btn.pressed.connect(take_photo)
	btm_bar.add_child(shutter_btn)

	# Toast Banner
	_toast_banner = PanelContainer.new()
	_toast_banner.set_anchors_preset(PRESET_CENTER_TOP)
	_toast_banner.offset_top = 64
	_toast_banner.offset_left = -220
	_toast_banner.offset_right = 220
	_toast_banner.offset_bottom = 110
	_toast_banner.visible = false

	var t_style := StyleBoxFlat.new()
	t_style.bg_color = Color(0.1, 0.12, 0.15, 0.95)
	t_style.border_color = Color(1.0, 0.85, 0.35)
	t_style.set_border_width_all(2)
	t_style.set_corner_radius_all(8)
	t_style.content_margin_left = 16
	t_style.content_margin_right = 16
	t_style.content_margin_top = 8
	t_style.content_margin_bottom = 8
	_toast_banner.add_theme_stylebox_override("panel", t_style)
	add_child(_toast_banner)

	_toast_label = Label.new()
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.add_theme_font_size_override("font_size", 13)
	_toast_banner.add_child(_toast_label)

	# Flash ColorRect
	_flash_rect = ColorRect.new()
	_flash_rect.color = Color(1.0, 1.0, 1.0, 0.0)
	_flash_rect.set_anchors_preset(PRESET_FULL_RECT)
	_flash_rect.visible = false
	_flash_rect.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_flash_rect)
