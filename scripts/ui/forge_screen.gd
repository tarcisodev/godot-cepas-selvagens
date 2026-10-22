class_name ForgeScreen
extends Control

## Tela da bigorna (GDD-06 §6): escolhe a receita e a pilha de cada slot (núcleo, revestimento,
## tempero), mostra a prévia (★, traits, crítico, efeitos) e forja. Ao lado, as peças que você tem:
## equipar/desequipar, reparar e desmanchar. O mundo continua rodando com a tela aberta.

const TEXT := Color(0.92, 0.9, 0.86)
const TEXT_DIM := Color(0.6, 0.57, 0.52)
const EMBER := Color(1.0, 0.55, 0.2)
const SLOT_TITLES: Array[String] = ["Núcleo", "Revestimento", "Tempero"]
const SLOT_KEYS: Array[String] = ["core", "coat", "temper"]
const STAT_NAMES: Dictionary = {
	&"resist_slash": "Corte", &"resist_impact": "Impacto", &"poise_resist": "Postura",
	&"dodge_cost": "Custo da esquiva", &"ether_regen": "Regen. de Éter", &"vigor_regen": "Regen. de Vigor", &"load": "Carga",
}

var player: Player
var public_forge: bool = false

var _recipe: StringName = &"elmo_chifre_de_pedra"
## Índice escolhido na lista de pilhas de cada slot (-1 = nenhuma, só no tempero)
var _pick: Array[int] = [0, 0, -1]
var _rng := RandomNumberGenerator.new()
var _recipes_box: VBoxContainer
var _slots_box: VBoxContainer
var _preview: VBoxContainer
var _items_box: VBoxContainer
var _status: Label

func _ready() -> void:
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_rng.randomize()
	_build_ui()

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

func open(p: Player, has_public_forge: bool) -> void:
	player = p
	public_forge = has_public_forge
	visible = true
	add_to_group("open_menus")
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_status.text = ""
	refresh()

func close() -> void:
	visible = false
	remove_from_group("open_menus")
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _forge_level() -> int:
	return player.mastery.get_level(&"forja") if player and player.mastery else 1

## Pilhas que servem para o slot (qualquer opção da receita com quantidade suficiente)
func candidates(slot_key: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if player == null:
		return out
	for o in Forge.RECIPES[_recipe][slot_key]:
		for s in player.inventory.get_stacks(o.id):
			if s.amount >= o.n:
				out.append(s)
	out.sort_custom(func(a, b): return a.quality > b.quality)
	return out

func _chosen(i: int) -> Dictionary:
	var list := candidates(SLOT_KEYS[i])
	if _pick[i] < 0 or list.is_empty():
		return {}
	return list[clampi(_pick[i], 0, list.size() - 1)]

func refresh() -> void:
	if player == null:
		return
	for box in [_recipes_box, _slots_box, _preview, _items_box]:
		for c in box.get_children():
			c.queue_free()
	for id in Forge.RECIPES:
		var r: Dictionary = Forge.RECIPES[id]
		var b := _button("%s  %s\n%s · %s" % [r.icon, r.name, ForgedItem.SLOT_NAMES[r.slot], r["class"]], id == _recipe)
		b.custom_minimum_size = Vector2(250, 52)
		b.pressed.connect(func(): _recipe = id; _pick = [0, 0, -1]; refresh())
		_recipes_box.add_child(b)
	for i in 3:
		_slots_box.add_child(_slot_row(i))
	_build_preview()
	_build_items()

func _slot_row(i: int) -> Control:
	var key := SLOT_KEYS[i]
	var r: Dictionary = Forge.RECIPES[_recipe]
	var col := VBoxContainer.new()
	var need: Array[String] = []
	for o in r[key]:
		need.append("%d %s" % [o.n, MaterialData.of(o.id).display_name] + (" → %s" % Forge.TRAIT_NAMES.get(o.trait, "") if o.has("trait") else ""))
	col.add_child(_label("%s%s: %s" % [SLOT_TITLES[i], " (opcional)" if i == 2 else "", " ou ".join(need)], 12, TEXT_DIM))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var list := candidates(key)
	var locked := i == 2 and _forge_level() < Forge.TEMPER_LEVEL
	var prev := _button("◀", false)
	var next := _button("▶", false)
	var s := _chosen(i)
	var text := "—"
	if locked:
		text = "🔒 Tempero libera na forja %d (você: %d)" % [Forge.TEMPER_LEVEL, _forge_level()]
	elif s.is_empty():
		text = "nenhum" if i == 2 else "❌ Falta material"
	else:
		var d := MaterialData.of(s.id)
		text = "%s %s  %s  ×%d%s" % [d.icon, d.display_name, "★".repeat(s.quality), s.amount, ("  ✦ " + ", ".join(s.traits.map(func(t): return Forge.TRAIT_NAMES.get(t, String(t))))) if not s.traits.is_empty() else ""]
	prev.disabled = locked or list.size() <= (0 if i == 2 else 1)
	next.disabled = prev.disabled
	prev.pressed.connect(func(): _cycle(i, -1))
	next.pressed.connect(func(): _cycle(i, 1))
	row.add_child(prev)
	var lab := _label(text, 15, TEXT)
	lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lab)
	row.add_child(next)
	col.add_child(row)
	return col

func _cycle(i: int, step: int) -> void:
	var n := candidates(SLOT_KEYS[i]).size()
	if i == 2:
		# Tempero: -1 (nenhum), 0..n-1
		_pick[i] = posmod(_pick[i] + 1 + step, n + 1) - 1
	elif n > 0:
		_pick[i] = posmod(_pick[i] + step, n)
	refresh()

func _build_preview() -> void:
	var p := Forge.preview(_recipe, _chosen(0), _chosen(1), _chosen(2), _forge_level(), public_forge)
	_preview.add_child(HSeparator.new())
	if not p.ok:
		_preview.add_child(_label("❌ " + p.reason, 15, Color(0.9, 0.45, 0.4)))
		return
	var traits: Array = p.traits.map(func(t): return Forge.TRAIT_NAMES.get(t, String(t)))
	_preview.add_child(_label("Resultado: %s  %s%s" % ["★".repeat(p.quality), Forge.RECIPES[_recipe].name, ("  ✦ " + ", ".join(traits)) if not traits.is_empty() else ""], 16, MaterialData.rarity_color(p.quality)))
	_preview.add_child(_label("Chance de crítico (+1★): %d%%%s" % [roundi(p.crit * 100.0), " · Forja Pública +10%" if public_forge else ""], 12, TEXT_DIM))
	var fake := ForgedItem.new()
	fake.recipe_id = _recipe
	fake.quality = p.quality
	fake.traits.assign(p.traits)
	_preview.add_child(_label(_effects_text(fake), 13, TEXT))
	var forge_btn := _button("🔨  Forjar", true)
	forge_btn.pressed.connect(_do_forge)
	_preview.add_child(forge_btn)

func _do_forge() -> void:
	var item := Forge.forge(player.inventory, _recipe, _chosen(0), _chosen(1), _chosen(2), _forge_level(), public_forge, _rng)
	if item == null:
		_status.text = "Não deu para forjar"
		return
	player.inventory.add_item(item)
	player.mastery.add_xp(&"forja", 20.0 + item.quality * 8.0)
	_status.text = "✨ Forjou %s %s" % [item.display_name, "★".repeat(item.quality)]
	_pick = [0, 0, -1]
	refresh()

func _build_items() -> void:
	_items_box.add_child(_label("Suas peças", 16, TEXT))
	if player.inventory.items.is_empty():
		_items_box.add_child(_label("Nenhuma ainda. Forje algo ao lado.", 13, TEXT_DIM, 300.0))
	for item in player.inventory.items:
		var equipped := player.inventory.equipped_in(item.slot) == item
		var box := VBoxContainer.new()
		box.add_child(_label("%s %s  %s%s" % ["🟢" if equipped else "⚪", item.display_name, "★".repeat(item.quality), "  (quebrado)" if item.is_broken() else ""], 14, MaterialData.rarity_color(item.quality), 300.0))
		box.add_child(_label("%s · Durabilidade %d/%d%s" % [ForgedItem.SLOT_NAMES[item.slot], roundi(item.durability), roundi(item.max_durability), ("  ✦ " + ", ".join(item.trait_names())) if not item.traits.is_empty() else ""], 11, TEXT_DIM, 300.0))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var eq := _button("Desequipar" if equipped else "Equipar", not equipped)
		eq.pressed.connect(func():
			if equipped:
				player.inventory.unequip(item.slot)
			else:
				player.inventory.equip(item)
			refresh())
		row.add_child(eq)
		var rep := _button("Reparar (5 $S)", false)
		rep.disabled = item.durability >= item.max_durability - 0.01
		rep.pressed.connect(func():
			var err := Forge.repair(item, player.inventory, player.wallet)
			if err.is_empty():
				if equipped:
					player.inventory.equip(item) # reaplica os efeitos com a peça inteira
				_status.text = "🔧 Reparado: máximo agora %d" % roundi(item.max_durability)
			else:
				_status.text = "❌ " + err
			refresh())
		row.add_child(rep)
		var sal := _button("Desmanchar", false)
		sal.pressed.connect(func():
			var back := Forge.salvage(item, player.inventory)
			player.inventory.remove_item(item)
			var parts: Array[String] = []
			for id in back:
				parts.append("%d %s" % [back[id], MaterialData.of(id).display_name])
			_status.text = "♻️ Desmanchou: " + (", ".join(parts) if not parts.is_empty() else "nada aproveitável")
			refresh())
		row.add_child(sal)
		box.add_child(row)
		_items_box.add_child(box)
		_items_box.add_child(HSeparator.new())

func _effects_text(item: ForgedItem) -> String:
	var parts: Array[String] = []
	var fx := item.effects()
	for stat in fx:
		var v: float = fx[stat]
		var stat_label: String = STAT_NAMES.get(stat, String(stat))
		if String(stat).begins_with("resist_") or stat == &"poise_resist":
			parts.append("%s %+d%%" % [stat_label, roundi(v * 100.0)])
		else:
			parts.append("%s %+.1f" % [stat_label, v])
	return " · ".join(parts)

# ---------------------------------------------------------------- montagem

func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(1180, 620)
	panel.add_theme_stylebox_override("panel", _box(Color(0.09, 0.07, 0.06, 0.96), Color(EMBER.r, EMBER.g, EMBER.b, 0.35), 14, 1, Vector2(20, 18)))
	center.add_child(panel)
	var root_box := VBoxContainer.new()
	root_box.add_theme_constant_override("separation", 10)
	panel.add_child(root_box)
	var header := HBoxContainer.new()
	header.add_child(_label("⚒️  Bigorna", 24, TEXT))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	_status = _label("", 14, EMBER)
	header.add_child(_status)
	var close_btn := _button("  ✕  ", false)
	close_btn.pressed.connect(close)
	header.add_child(close_btn)
	root_box.add_child(header)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	root_box.add_child(body)
	_recipes_box = VBoxContainer.new()
	_recipes_box.add_theme_constant_override("separation", 8)
	body.add_child(_recipes_box)
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 12)
	body.add_child(mid)
	_slots_box = VBoxContainer.new()
	_slots_box.add_theme_constant_override("separation", 12)
	mid.add_child(_slots_box)
	_preview = VBoxContainer.new()
	_preview.add_theme_constant_override("separation", 8)
	mid.add_child(_preview)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(330, 0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	_items_box = VBoxContainer.new()
	_items_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_items_box.add_theme_constant_override("separation", 6)
	scroll.add_child(_items_box)

## `wrap_width` > 0 quebra linha nessa largura (coluna de peças); sem isso, uma linha só
func _label(text: String, size: int, color: Color, wrap_width: float = 0.0) -> Label:
	var l := Label.new()
	l.text = text
	if wrap_width > 0.0:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = wrap_width
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

func _button(text: String, filled: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 13)
	var fg := Color(0.12, 0.08, 0.04) if filled else TEXT
	for c in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(c, fg)
	b.add_theme_color_override("font_disabled_color", Color(0.42, 0.4, 0.38))
	var bg := EMBER if filled else Color(EMBER.r, EMBER.g, EMBER.b, 0.1)
	b.add_theme_stylebox_override("normal", _box(bg, EMBER, 10, 1, Vector2(12, 6)))
	b.add_theme_stylebox_override("hover", _box(bg.lightened(0.12), EMBER, 10, 1, Vector2(12, 6)))
	b.add_theme_stylebox_override("pressed", _box(bg.darkened(0.1), EMBER, 10, 1, Vector2(12, 6)))
	b.add_theme_stylebox_override("disabled", _box(Color(1, 1, 1, 0.03), Color(1, 1, 1, 0.08), 10, 1, Vector2(12, 6)))
	return b

func _box(bg: Color, border: Color, radius: int, border_w: int, pad: Vector2 = Vector2.ZERO) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(radius)
	s.content_margin_left = pad.x
	s.content_margin_right = pad.x
	s.content_margin_top = pad.y
	s.content_margin_bottom = pad.y
	return s
