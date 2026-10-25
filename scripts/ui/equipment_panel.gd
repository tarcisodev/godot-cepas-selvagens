class_name EquipmentPanel
extends VBoxContainer

## Coluna de equipamento da tela de inventário ([I], GDD-12 §1): o personagem em 3D vestido com o
## que está equipado (arrastar gira, roda do mouse dá zoom), os 7 encaixes com a peça de cada um
## (clicar abre a lista do que dá para pôr ali, ou tira a peça) e um resumo de Carga, mochila e
## habilidades. O boneco usa o mesmo DNA do jogador e o mesmo GearVisual do corpo de verdade.

const TEXT := Color(0.9, 0.9, 0.94)
const TEXT_DIM := Color(0.55, 0.57, 0.64)
const SLOT_ICONS: Array[String] = ["⛑️", "🦺", "🥾", "🗡️", "🛡", "🧣", "🎒"]
## Ordem dos encaixes na tela: armadura à esquerda, armas e o resto à direita
const LEFT_SLOTS: Array[int] = [ForgedItem.Slot.HEAD, ForgedItem.Slot.BODY, ForgedItem.Slot.FEET, ForgedItem.Slot.CAPE]
const RIGHT_SLOTS: Array[int] = [ForgedItem.Slot.MAIN_HAND, ForgedItem.Slot.OFF_HAND, ForgedItem.Slot.BAG]
const ZOOM_MIN: float = 1.4
const ZOOM_MAX: float = 4.6

var player: Player
var preview: CharacterVisual
var _gear: GearVisual
var _camera: Camera3D
var _zoom: float = 3.6
var _slot_buttons: Dictionary = {}
var _summary: Label
var _menu: PopupMenu
var _menu_slot: int = -1
var _menu_items: Array[ForgedItem] = []

func _ready() -> void:
	custom_minimum_size = Vector2(470, 0)
	add_theme_constant_override("separation", 8)
	_build()

func bind(p: Player) -> void:
	if p == player:
		refresh()
		return
	player = p
	if player and player.inventory:
		player.inventory.equipment_changed.connect(func(_s, _n): refresh())
		player.inventory.items_changed.connect(refresh)
		player.style_changed.connect(func(_st): _dress_weapons())
		_gear.inventory = player.inventory
	refresh()

func refresh() -> void:
	if player == null or not is_inside_tree():
		return
	var dna: CharacterDNA = player.character_visual.dna if player.character_visual else null
	if dna and preview.dna != dna:
		preview.rebuild(dna)
		preview.play(&"Idle")
	_dress_weapons()
	_gear.refresh()
	for slot in _slot_buttons:
		_paint_slot(slot)
	_summary.text = _summary_text()

## Armas e ombreiras do estilo atual, como no corpo
func _dress_weapons() -> void:
	if player and player.weapon_style and preview.skeleton:
		preview.set_equipment(player.weapon_style.pieces)

func _paint_slot(slot: int) -> void:
	var b: Button = _slot_buttons[slot]
	var it: ForgedItem = player.inventory.equipped_in(slot) if player else null
	var title := "%s %s" % [SLOT_ICONS[slot], ForgedItem.SLOT_NAMES[slot]]
	if it == null:
		b.text = "%s\n— vazio —" % title
		b.modulate = Color(1, 1, 1, 0.55)
		b.tooltip_text = "Clique para escolher uma peça"
		return
	b.modulate = Color(1, 1, 1, 1)
	var fam := (" · %s" % it.family_name()) if it.family != &"" else ""
	b.text = "%s\n%s %s%s" % [title, it.display_name, "★".repeat(it.quality), "  (quebrado)" if it.is_broken() else ""]
	b.add_theme_color_override("font_color", MaterialData.rarity_color(it.quality))
	var lines: Array[String] = ["%s%s · Durabilidade %d/%d" % [it.display_name, fam, roundi(it.durability), roundi(it.max_durability)]]
	var ab := it.ability_id()
	if ab != &"":
		var info := ArmorAbilities.info(ab)
		lines.append("[%s] %s %s: %s" % [ArmorAbilities.KEY_NAMES[slot], info.icon, info.name, info.desc])
	if not it.traits.is_empty():
		lines.append("✦ " + ", ".join(it.trait_names()))
	lines.append("Clique para trocar ou tirar")
	b.tooltip_text = "\n".join(lines)

func _summary_text() -> String:
	if player == null:
		return ""
	var parts: Array[String] = []
	parts.append("⚖ Carga %.0f" % player.stats.get_stat(&"load"))
	var inv := player.inventory
	parts.append("🎒 %.0f / %.0f kg" % [inv.get_total_weight(), inv.carry_capacity()])
	parts.append("⚔ %s" % (player.weapon_style.display_name if player.weapon_style else "—"))
	var abilities: Array[String] = []
	for slot in ForgedItem.ARMOR_SLOTS:
		var id := player.armor_abilities.ability_in(slot) if player.armor_abilities else &""
		abilities.append("[%s] %s" % [ArmorAbilities.KEY_NAMES[slot], ArmorAbilities.info(id).name if id != &"" else "—"])
	return "  ·  ".join(parts) + "\n" + "   ".join(abilities)

# ---------------------------------------------------------------- equipar / tirar

## Peças que cabem no encaixe (a equipada vem marcada)
func candidates(slot: int) -> Array[ForgedItem]:
	var out: Array[ForgedItem] = []
	if player == null:
		return out
	for it in player.inventory.items:
		if it.slot == slot:
			out.append(it)
	out.sort_custom(func(a, b): return a.quality > b.quality)
	return out

func _open_slot_menu(slot: int) -> void:
	_menu_slot = slot
	_menu_items = candidates(slot)
	_menu.clear()
	var current: ForgedItem = player.inventory.equipped_in(slot)
	for i in _menu_items.size():
		var it := _menu_items[i]
		var tag := "  (quebrado)" if it.is_broken() else ""
		_menu.add_item("%s %s %s%s" % ["●" if it == current else "○", it.display_name, "★".repeat(it.quality), tag], i)
	if _menu_items.is_empty():
		_menu.add_item("Nenhuma peça para %s (forje na bigorna)" % ForgedItem.SLOT_NAMES[slot], -2)
		_menu.set_item_disabled(0, true)
	if current:
		_menu.add_separator()
		_menu.add_item("✕ Tirar %s" % current.display_name, -1)
	var b: Button = _slot_buttons[slot]
	_menu.position = Vector2i(b.get_screen_position() + Vector2(0, b.size.y))
	_menu.popup()

func _on_menu_pick(id: int) -> void:
	if id == -1:
		unequip_slot(_menu_slot)
	elif id >= 0 and id < _menu_items.size():
		equip_item(_menu_items[id])

func equip_item(it: ForgedItem) -> void:
	player.inventory.equip(it)
	refresh()

func unequip_slot(slot: int) -> void:
	player.inventory.unequip(slot)
	refresh()

# ---------------------------------------------------------------- montagem

func _build() -> void:
	var title := Label.new()
	title.text = "🧍  Equipamento"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", TEXT)
	add_child(title)

	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 6)
	add_child(row)
	row.add_child(_slot_column(LEFT_SLOTS))
	row.add_child(_build_preview())
	row.add_child(_slot_column(RIGHT_SLOTS))

	_summary = Label.new()
	_summary.add_theme_font_size_override("font_size", 12)
	_summary.add_theme_color_override("font_color", TEXT_DIM)
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_summary)

	_menu = PopupMenu.new()
	_menu.id_pressed.connect(_on_menu_pick)
	add_child(_menu)

func _slot_column(slots: Array[int]) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	for slot in slots:
		var b := Button.new()
		b.custom_minimum_size = Vector2(150, 62)
		b.focus_mode = Control.FOCUS_NONE
		b.clip_text = true
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		b.add_theme_font_size_override("font_size", 11)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(1, 1, 1, 0.04)
		sb.border_color = Color(1, 1, 1, 0.12)
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(8)
		sb.content_margin_left = 8
		sb.content_margin_right = 8
		b.add_theme_stylebox_override("normal", sb)
		var hov := sb.duplicate() as StyleBoxFlat
		hov.bg_color = Color(1, 1, 1, 0.1)
		b.add_theme_stylebox_override("hover", hov)
		b.pressed.connect(_open_slot_menu.bind(slot))
		col.add_child(b)
		_slot_buttons[slot] = b
	return col

## Prévia num mundo 3D próprio (como no editor de aparência): arrastar gira, roda dá zoom
func _build_preview() -> Control:
	var container := SubViewportContainer.new()
	container.stretch = true
	container.custom_minimum_size = Vector2(170, 330)
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.gui_input.connect(_on_preview_input)

	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	container.add_child(viewport)

	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#1d1f24")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#8c8f99")
	environment.ambient_light_energy = 0.6
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.environment = environment
	viewport.add_child(world)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35.0, 25.0, 0.0)
	key.light_energy = 1.3
	viewport.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-20.0, 200.0, 0.0)
	rim.light_energy = 0.5
	viewport.add_child(rim)

	var stand := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.6
	disc.bottom_radius = 0.6
	disc.height = 0.04
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color("#3a3630")
	disc.material = floor_material
	stand.mesh = disc
	stand.position.y = -0.02
	viewport.add_child(stand)

	preview = CharacterVisual.new()
	preview.weapon_scene = null
	preview.dna = CharacterDNA.new()
	# O CharacterVisual olha para -Z; a câmera está em +Z
	preview.rotation.y = PI
	viewport.add_child(preview)
	_gear = GearVisual.new()
	_gear.visual = preview
	add_child(_gear)

	_camera = Camera3D.new()
	_camera.fov = 35.0
	viewport.add_child(_camera)
	_frame_camera()

	var hint := Label.new()
	hint.text = "Arraste: girar · Roda: zoom"
	hint.modulate = Color(1, 1, 1, 0.5)
	hint.add_theme_font_size_override("font_size", 11)
	hint.position = Vector2(8, 6)
	container.add_child(hint)
	return container

func _frame_camera() -> void:
	# Zoom perto mira o rosto; longe, o corpo inteiro
	var t := inverse_lerp(ZOOM_MAX, ZOOM_MIN, _zoom)
	var look_y := lerpf(0.95, 1.45, t)
	_camera.transform = Transform3D(Basis(), Vector3(0.0, look_y + 0.15, _zoom)).looking_at(Vector3(0.0, look_y, 0.0))

func _on_preview_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion and motion.button_mask & MOUSE_BUTTON_MASK_LEFT:
		preview.rotation.y += motion.relative.x * 0.01
	var button := event as InputEventMouseButton
	if button and button.pressed:
		if button.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_by(-0.3)
		elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_by(0.3)

func zoom_by(amount: float) -> void:
	_zoom = clampf(_zoom + amount, ZOOM_MIN, ZOOM_MAX)
	_frame_camera()
