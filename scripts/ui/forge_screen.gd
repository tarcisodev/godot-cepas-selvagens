class_name ForgeScreen
extends Control

const _Player = preload("res://scripts/player.gd")
const _ForgedItem = preload("res://scripts/data/forged_item.gd")
const _CharacterVisual = preload("res://scripts/components/character_visual.gd")
const _GearVisual = preload("res://scripts/components/gear_visual.gd")
const _Forge = preload("res://scripts/systems/forge.gd")

## Tela da bigorna (GDD-06 §6): filtra receitas e peças por encaixe e derivação (família), escolhe
## a receita, a derivação e a pilha de cada slot (núcleo, revestimento, tempero), mostra a prévia
## (atributos, ★, traits, crítico) e o personagem em 3D vestindo a peça/derivação escolhida
## (com opção de esconder o capacete). Ao lado, as peças que você tem: provar, equipar/desequipar,
## reparar e desmanchar. O mundo continua rodando com a tela aberta.

const TEXT := Color(0.92, 0.9, 0.86)
const TEXT_DIM := Color(0.6, 0.57, 0.52)
const EMBER := Color(1.0, 0.55, 0.2)
const SLOT_TITLES: Array[String] = ["Núcleo", "Revestimento", "Tempero"]
const SLOT_KEYS: Array[String] = ["core", "coat", "temper"]
const SLOT_FILTER_ICONS: Array[String] = ["⛑️", "🦺", "🥾", "🗡️", "🛡", "🧣", "🎒"]
const SLOT_SHORT_NAMES: Array[String] = ["Cabeça", "Peito", "Botas", "Primária", "Secundária", "Capa", "Mochila"]
const FAMILY_FILTERS: Array[Dictionary] = [
	{"id": &"", "label": "Todas"},
	{"id": &"pano", "label": "🧵 Pano"},
	{"id": &"couro", "label": "🦌 Couro"},
	{"id": &"ferro", "label": "⛓️ Ferro"},
]
const STAT_NAMES: Dictionary = {
	&"resist_slash": "Corte", &"resist_impact": "Impacto", &"poise_resist": "Postura",
	&"dodge_cost": "Custo da esquiva", &"ether_regen": "Regen. de Éter", &"vigor_regen": "Regen. de Vigor", &"load": "Carga",
	&"resist_pierce": "Perfuração", &"carry_capacity": "Mochila (kg)",
}
const ZOOM_MIN: float = 1.4
const ZOOM_MAX: float = 4.6

var player: Player
var public_forge: bool = false

## Filtros ativos (-1 = todos os encaixes; &"" = todas as famílias/derivações)
var slot_filter: int = -1
var family_filter: StringName = &""

var _recipe: StringName = &"elmo_chifre_de_pedra"
## Índice escolhido na lista de pilhas do inventário de cada slot (-1 = nenhuma, só no tempero)
var _pick: Array[int] = [0, 0, -1]
## Índice da opção da receita selecionada para prévia de derivação [core, coat, temper]
var _opt_pick: Array[int] = [0, 0, -1]
## Peça já forjada clicada em "Suas peças" para provar no boneco (null = mostra a receita atual)
var _inspected_item: ForgedItem = null

var _rng := RandomNumberGenerator.new()
var _slot_filter_bar: HBoxContainer
var _family_filter_bar: HBoxContainer
var _recipes_box: VBoxContainer
var _derivations_box: VBoxContainer
var _slots_box: VBoxContainer
var _preview: VBoxContainer
var _items_box: VBoxContainer
var _status: Label

## Prévia 3D do personagem na bigorna
var preview: CharacterVisual
var _gear: GearVisual
var _camera: Camera3D
var _zoom: float = 3.5
var _preview_caption: Label
var _helmet_toggle: Button

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
	_inspected_item = null
	if _gear and player:
		_gear.inventory = player.inventory
	visible = true
	add_to_group("open_menus")
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_status.text = ""
	_sync_picks_to_recipe()
	refresh()

func close() -> void:
	visible = false
	remove_from_group("open_menus")
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _forge_level() -> int:
	return player.mastery.get_level(&"forja") if player and player.mastery else 1

## Encaixe de tempero: nível 10 e a Técnica "Mão de Tempero" do mestre (B38)
func _temper_ok() -> bool:
	return player != null and player.mastery != null and player.mastery.has_technique(&"forja", 10)

func _crit_bonus() -> float:
	return player.mastery.technique_bonus(&"forge_crit") if player and player.mastery else 0.0

# ---------------------------------------------------------------- filtros e derivações

func set_slot_filter(slot: int) -> void:
	slot_filter = slot
	_inspected_item = null
	var list := filtered_recipes()
	if not list.is_empty() and not list.has(_recipe):
		_recipe = list[0]
		_sync_picks_to_recipe()
	refresh()

func set_family_filter(family: StringName) -> void:
	family_filter = family
	_inspected_item = null
	var list := filtered_recipes()
	if not list.is_empty() and not list.has(_recipe):
		_recipe = list[0]
		_sync_picks_to_recipe()
	if family_filter != &"":
		select_derivation_family(family_filter)
	else:
		refresh()

func filtered_recipes() -> Array[StringName]:
	var out: Array[StringName] = []
	for id in Forge.RECIPES:
		var r: Dictionary = Forge.RECIPES[id]
		if slot_filter >= 0 and int(r.slot) != slot_filter:
			continue
		if family_filter != &"" and not Forge.recipe_families(id).has(family_filter):
			continue
		out.append(id)
	return out

func filtered_items() -> Array[ForgedItem]:
	var out: Array[ForgedItem] = []
	if player == null or player.inventory == null:
		return out
	for it in player.inventory.items:
		if slot_filter >= 0 and int(it.slot) != slot_filter:
			continue
		if family_filter != &"" and it.family != family_filter:
			continue
		out.append(it)
	return out

func select_recipe(id: StringName) -> void:
	if not Forge.RECIPES.has(id):
		return
	_recipe = id
	_inspected_item = null
	_sync_picks_to_recipe()
	if family_filter != &"":
		select_derivation_family(family_filter)
	else:
		refresh()

## Seleciona a derivação de família (pano, couro, ferro) na receita atual
func select_derivation_family(family: StringName) -> void:
	var r: Dictionary = Forge.RECIPES.get(_recipe, {})
	if r.is_empty():
		return
	var base: StringName = r.get("family", &"")
	for i in r.coat.size():
		var fam: StringName = r.coat[i].get("family", base)
		if fam == family:
			select_slot_option(1, i)
			return
	refresh()

## Seleciona uma opção específica de material para o slot `slot_idx` (0=núcleo, 1=revestimento, 2=tempero)
func select_slot_option(slot_idx: int, opt_idx: int) -> void:
	var r: Dictionary = Forge.RECIPES.get(_recipe, {})
	if r.is_empty():
		return
	var key := SLOT_KEYS[slot_idx]
	var opts: Array = r.get(key, [])
	_inspected_item = null
	if slot_idx == 2 and opt_idx < 0:
		_opt_pick[2] = -1
		_pick[2] = -1
		refresh()
		return
	if opts.is_empty():
		return
	_opt_pick[slot_idx] = clampi(opt_idx, 0, opts.size() - 1)
	var mat_id: StringName = opts[_opt_pick[slot_idx]].id
	var list := candidates(key)
	for j in list.size():
		if list[j].id == mat_id:
			_pick[slot_idx] = j
			break
	refresh()

func _sync_picks_to_recipe() -> void:
	_pick = [0, 0, -1]
	_opt_pick = [0, 0, -1]
	var r: Dictionary = Forge.RECIPES.get(_recipe, {})
	if r.is_empty():
		return
	for i in 2:
		var s := _chosen(i)
		if not s.is_empty():
			var opts: Array = r[SLOT_KEYS[i]]
			for k in opts.size():
				if opts[k].id == s.id:
					_opt_pick[i] = k
					break

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

## Peça em exibição no boneco 3D (ou a peça clicada em "Suas peças", ou a derivação selecionada da receita)
func current_preview_item() -> ForgedItem:
	if _inspected_item != null:
		return _inspected_item
	var r: Dictionary = Forge.RECIPES.get(_recipe, {})
	if r.is_empty():
		return null
	var core_s := _chosen(0)
	var coat_s := _chosen(1)
	var temper_s := _chosen(2)
	var core_id: StringName = core_s.id if not core_s.is_empty() else (r.core[clampi(_opt_pick[0], 0, r.core.size() - 1)].id if not r.core.is_empty() else &"")
	# Se o usuário clicou numa opção específica em _opt_pick, prioriza a opção clicada para a prévia visual
	if not r.core.is_empty():
		var picked_core_id: StringName = r.core[clampi(_opt_pick[0], 0, r.core.size() - 1)].id
		if core_s.is_empty() or core_s.id != picked_core_id:
			core_id = picked_core_id
	var coat_id: StringName = coat_s.id if not coat_s.is_empty() else (r.coat[clampi(_opt_pick[1], 0, r.coat.size() - 1)].id if not r.coat.is_empty() else &"")
	if not r.coat.is_empty():
		var picked_coat_id: StringName = r.coat[clampi(_opt_pick[1], 0, r.coat.size() - 1)].id
		if coat_s.is_empty() or coat_s.id != picked_coat_id:
			coat_id = picked_coat_id
	var temper_id: StringName = &""
	if _opt_pick[2] >= 0 and _opt_pick[2] < r.temper.size():
		temper_id = r.temper[_opt_pick[2]].id
	elif not temper_s.is_empty():
		temper_id = temper_s.id
	var q := 1
	var core_traits: Array = []
	if not core_s.is_empty() and core_s.id == core_id:
		core_traits = core_s.traits
	if not core_s.is_empty() and not coat_s.is_empty() and core_s.id == core_id and coat_s.id == coat_id:
		q = roundi((core_s.quality * 2.0 + coat_s.quality) / 3.0)
	return Forge.make_preview_item(_recipe, core_id, coat_id, temper_id, q, core_traits)

func preview_owned_item(item: ForgedItem) -> void:
	_inspected_item = item
	refresh()

func toggle_hide_helmet() -> void:
	if player and player.inventory:
		player.inventory.set_hide_helmet(not player.inventory.hide_helmet)
		refresh()

# ---------------------------------------------------------------- atualização da UI

func refresh() -> void:
	if player == null:
		return
	for box in [_recipes_box, _derivations_box, _slots_box, _preview, _items_box]:
		for c in box.get_children():
			c.queue_free()
	_refresh_filter_bars()

	# Fundição (GDD-12 §8) no topo da lista quando não há filtro restrito
	if slot_filter < 0 and family_filter == &"":
		for out_id in Forge.SMELT:
			var rec: Dictionary = Forge.SMELT[out_id]
			var sb := _button("🔥  Fundir %s\n%d %s + %d %s" % [MaterialData.of(out_id).display_name, rec.ore_n, MaterialData.of(rec.ore).display_name, rec.fuel_n, MaterialData.of(rec.fuel).display_name], false)
			sb.custom_minimum_size = Vector2(240, 44)
			sb.pressed.connect(func():
				var err := Forge.smelt(player.inventory, out_id)
				if err.is_empty():
					player.mastery.add_xp(&"forja", 6.0)
					_status.text = "🔥 Fundiu 1 %s" % MaterialData.of(out_id).display_name
				else:
					_status.text = "❌ " + err
				refresh())
			_recipes_box.add_child(sb)

	var recipes := filtered_recipes()
	if recipes.is_empty():
		_recipes_box.add_child(_label("Nenhuma receita para este filtro.", 12, TEXT_DIM, 230.0))
	var last_slot := -1
	for id in recipes:
		var r: Dictionary = Forge.RECIPES[id]
		if r.slot != last_slot:
			last_slot = r.slot
			_recipes_box.add_child(_label(ForgedItem.SLOT_NAMES[r.slot], 12, TEXT_DIM))
		var fams := Forge.recipe_families(id)
		var kind: String = "/".join(fams.map(func(f): return ForgedItem.FAMILY[f].name)) if not fams.is_empty() else ("duas mãos" if r.get("two_hand", false) else "uma mão")
		var b := _button("%s  %s · %s" % [r.icon, r.name, kind], id == _recipe and _inspected_item == null)
		b.custom_minimum_size = Vector2(240, 30)
		b.pressed.connect(func(): select_recipe(id))
		_recipes_box.add_child(b)

	_build_derivations()
	for i in 3:
		_slots_box.add_child(_slot_row(i))
	_build_preview()
	_build_items()
	_refresh_character_preview()

func _refresh_filter_bars() -> void:
	if _slot_filter_bar == null or _family_filter_bar == null:
		return
	for b in _slot_filter_bar.get_children():
		if b is Button:
			var s: int = b.get_meta("slot", -1)
			_style_filter_pill(b, s == slot_filter)
	for b in _family_filter_bar.get_children():
		if b is Button:
			var f: StringName = b.get_meta("family", &"")
			_style_filter_pill(b, f == family_filter)

func _build_derivations() -> void:
	var r: Dictionary = Forge.RECIPES.get(_recipe, {})
	if r.is_empty():
		return
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	title_row.add_child(_label("%s  %s" % [r.icon, r.name], 18, TEXT))
	_derivations_box.add_child(title_row)

	# Seletor rápido de derivações de revestimento (família/material) e núcleo (quando há mais de um)
	var base_fam: StringName = r.get("family", &"")
	if r.coat.size() > 1 or not Forge.recipe_families(_recipe).is_empty():
		var coat_row := HBoxContainer.new()
		coat_row.add_theme_constant_override("separation", 6)
		coat_row.add_child(_label("Derivação (Revest.):", 12, TEXT_DIM))
		for i in r.coat.size():
			var o: Dictionary = r.coat[i]
			var fam: StringName = o.get("family", base_fam)
			var fam_tag: String = ("%s · " % ForgedItem.FAMILY[fam].name) if ForgedItem.FAMILY.has(fam) else ""
			var mat_name: String = MaterialData.of(o.id).display_name
			var has_mat: bool = player != null and player.inventory.get_material_count(o.id) >= int(o.n)
			var btn := _button("%s%s%s" % [fam_tag, mat_name, "" if has_mat else " (prévia)"], _opt_pick[1] == i and _inspected_item == null)
			btn.pressed.connect(func(): select_slot_option(1, i))
			coat_row.add_child(btn)
		_derivations_box.add_child(coat_row)

	if r.core.size() > 1:
		var core_row := HBoxContainer.new()
		core_row.add_theme_constant_override("separation", 6)
		core_row.add_child(_label("Derivação (Núcleo):", 12, TEXT_DIM))
		for i in r.core.size():
			var o: Dictionary = r.core[i]
			var note := ""
			if o.has("power") and o.power < 1.0:
				note = " (−%d%% dano)" % roundi((1.0 - o.power) * 100.0)
			elif o.has("durability") and o.durability > 1.0:
				note = " (+%d%% dur.)" % roundi((o.durability - 1.0) * 100.0)
			var btn := _button("%s%s" % [MaterialData.of(o.id).display_name, note], _opt_pick[0] == i and _inspected_item == null)
			btn.pressed.connect(func(): select_slot_option(0, i))
			core_row.add_child(btn)
		_derivations_box.add_child(core_row)

func _slot_row(i: int) -> Control:
	var key := SLOT_KEYS[i]
	var r: Dictionary = Forge.RECIPES[_recipe]
	var col := VBoxContainer.new()
	var need: Array[String] = []
	for o in r[key]:
		var note := ""
		if o.has("trait"):
			note = " → %s" % Forge.TRAIT_NAMES.get(o.trait, "")
		elif o.has("family"):
			note = " (%s)" % ForgedItem.FAMILY[o.family].name
		elif o.has("power") and o.power < 1.0:
			note = " (−%d%% dano)" % roundi((1.0 - o.power) * 100.0)
		need.append("%d %s" % [o.n, MaterialData.of(o.id).display_name] + note)
	if r[key].is_empty():
		need.append("—")
	col.add_child(_label("%s%s: %s" % [SLOT_TITLES[i], " (opcional)" if i == 2 else "", " ou ".join(need)], 12, TEXT_DIM))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var list := candidates(key)
	var locked := i == 2 and (_forge_level() < Forge.TEMPER_LEVEL or not _temper_ok())
	var prev := _button("◀", false)
	var next := _button("▶", false)
	var s := _chosen(i)
	var text := "—"
	if locked:
		text = "🔒 Tempero libera na forja %d (você: %d)" % [Forge.TEMPER_LEVEL, _forge_level()] if _forge_level() < Forge.TEMPER_LEVEL else "🔒 Tempero: aprenda Mão de Tempero com a Mestra Bigorna Velha" 
	elif s.is_empty():
		text = "nenhum" if i == 2 else "❌ Falta material (veja a prévia no boneco)"
	else:
		var d := MaterialData.of(s.id)
		text = "%s %s  %s  ×%d%s" % [d.icon, d.display_name, "★".repeat(s.quality), s.amount, ("  ✦ " + ", ".join(s.traits.map(func(t): return Forge.TRAIT_NAMES.get(t, String(t))))) if not s.traits.is_empty() else ""]
	prev.disabled = locked or list.size() <= (0 if i == 2 else 1)
	next.disabled = prev.disabled
	prev.pressed.connect(func(): _cycle(i, -1))
	next.pressed.connect(func(): _cycle(i, 1))
	row.add_child(prev)
	var lab := _label(text, 14, TEXT)
	lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lab)
	row.add_child(next)
	col.add_child(row)
	return col

func _cycle(i: int, step: int) -> void:
	_inspected_item = null
	var list := candidates(SLOT_KEYS[i])
	var n := list.size()
	if i == 2:
		# Tempero: -1 (nenhum), 0..n-1
		_pick[i] = posmod(_pick[i] + 1 + step, n + 1) - 1
		if _pick[i] < 0:
			_opt_pick[2] = -1
		else:
			var s := _chosen(2)
			var opts: Array = Forge.RECIPES[_recipe].temper
			for k in opts.size():
				if opts[k].id == s.id:
					_opt_pick[2] = k
					break
	elif n > 0:
		_pick[i] = posmod(_pick[i] + step, n)
		var s := _chosen(i)
		var opts: Array = Forge.RECIPES[_recipe][SLOT_KEYS[i]]
		for k in opts.size():
			if opts[k].id == s.id:
				_opt_pick[i] = k
				break
	refresh()

func _build_preview() -> void:
	var p := Forge.preview(_recipe, _chosen(0), _chosen(1), _chosen(2), _forge_level(), public_forge, _temper_ok(), _crit_bonus())
	var demo := current_preview_item()
	_preview.add_child(HSeparator.new())
	if demo != null:
		var traits: Array = demo.traits.map(func(t): return Forge.TRAIT_NAMES.get(t, String(t)))
		var title_prefix := "Resultado" if p.ok and _inspected_item == null else "Prévia da peça"
		_preview.add_child(_label("%s: %s  %s%s" % [title_prefix, "★".repeat(demo.quality), demo.display_name, ("  ✦ " + ", ".join(traits)) if not traits.is_empty() else ""], 16, MaterialData.rarity_color(demo.quality)))
		_preview.add_child(_label(_effects_text(demo), 13, TEXT, 420.0))
	if not p.ok:
		_preview.add_child(_label("❌ Para forjar: " + p.reason, 14, Color(0.9, 0.45, 0.4)))
		return
	_preview.add_child(_label("Chance de crítico (+1★): %d%%%s" % [roundi(p.crit * 100.0), " · Forja Pública +10%" if public_forge else ""], 12, TEXT_DIM))
	var forge_btn := _button("🔨  Forjar", true)
	forge_btn.pressed.connect(_do_forge)
	_preview.add_child(forge_btn)

func _do_forge() -> void:
	var item := Forge.forge(player.inventory, _recipe, _chosen(0), _chosen(1), _chosen(2), _forge_level(), public_forge, _rng, _temper_ok(), _crit_bonus())
	if item == null:
		_status.text = "Não deu para forjar"
		return
	player.inventory.add_item(item)
	player.mastery.add_xp(&"forja", 20.0 + item.quality * 8.0)
	_status.text = "✨ Forjou %s %s" % [item.display_name, "★".repeat(item.quality)]
	_inspected_item = item
	_sync_picks_to_recipe()
	refresh()

func _build_items() -> void:
	_items_box.add_child(_label("Suas peças", 16, TEXT))
	var items := filtered_items()
	if items.is_empty():
		var msg := "Nenhuma ainda. Forje algo ao lado." if player.inventory.items.is_empty() else "Nenhuma peça neste filtro."
		_items_box.add_child(_label(msg, 13, TEXT_DIM, 280.0))
	for item in items:
		var equipped := player.inventory.equipped_in(item.slot) == item
		var box := VBoxContainer.new()
		box.add_child(_label("%s %s  %s%s" % ["🟢" if equipped else "⚪", item.display_name, "★".repeat(item.quality), "  (quebrado)" if item.is_broken() else ""], 14, MaterialData.rarity_color(item.quality), 280.0))
		box.add_child(_label("%s · Durabilidade %d/%d%s" % [ForgedItem.SLOT_NAMES[item.slot], roundi(item.durability), roundi(item.max_durability), ("  ✦ " + ", ".join(item.trait_names())) if not item.traits.is_empty() else ""], 11, TEXT_DIM, 280.0))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var try_btn := _button("👁", _inspected_item == item)
		try_btn.tooltip_text = "Visualizar esta peça no personagem ao lado"
		try_btn.pressed.connect(func(): preview_owned_item(item))
		row.add_child(try_btn)
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
			if _inspected_item == item:
				_inspected_item = null
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
	if item.family != &"":
		parts.append("Família %s" % item.family_name())
	if item.slot == ForgedItem.Slot.MAIN_HAND:
		parts.append("Dano ×%.2f%s" % [item.weapon_power(), " · duas mãos" if item.is_two_handed() else ""])
	var ab := item.ability_id()
	if ab != &"":
		var info := ArmorAbilities.info(ab)
		parts.append("[%s] %s %s: %s" % [ArmorAbilities.KEY_NAMES[item.slot], info.icon, info.name, info.desc])
	var passive: StringName = item.recipe().get("passive", &"")
	if passive != &"":
		parts.append("Passiva: %s" % Forge.PASSIVE_NAMES.get(passive, String(passive)))
	var fx := item.effects()
	for stat in fx:
		var v: float = fx[stat]
		var stat_label: String = STAT_NAMES.get(stat, String(stat))
		if is_zero_approx(v):
			continue
		if String(stat).begins_with("resist_") or stat == &"poise_resist":
			parts.append("%s %+d%%" % [stat_label, roundi(v * 100.0)])
		else:
			parts.append("%s %+.1f" % [stat_label, v])
	return " · ".join(parts)

# ---------------------------------------------------------------- prévia 3D do personagem

func _refresh_character_preview() -> void:
	if player == null or preview == null or _gear == null:
		return
	var dna: CharacterDNA = player.character_visual.dna if player.character_visual else null
	if dna and preview.dna != dna:
		preview.rebuild(dna)
		preview.play(&"Idle")
	_gear.inventory = player.inventory
	var demo := current_preview_item()
	_gear.preview_item = demo
	_dress_preview_weapons(demo)
	_gear.refresh()
	if _preview_caption:
		_preview_caption.text = ("👁 %s" % demo.display_name) if demo else "🧍 Personagem"
	if _helmet_toggle:
		var hidden := player.inventory != null and player.inventory.hide_helmet
		_helmet_toggle.text = "🙈 Capacete: oculto" if hidden else "🪖 Esconder capacete"

func _dress_preview_weapons(demo: ForgedItem) -> void:
	if preview == null or preview.skeleton == null or player == null:
		return
	var main: ForgedItem = player.inventory.equipped_in(ForgedItem.Slot.MAIN_HAND) if player.inventory else null
	var off: ForgedItem = player.inventory.equipped_in(ForgedItem.Slot.OFF_HAND) if player.inventory else null
	if demo != null:
		if demo.slot == ForgedItem.Slot.MAIN_HAND:
			main = demo
			if main.is_two_handed():
				off = null
		elif demo.slot == ForgedItem.Slot.OFF_HAND:
			off = demo
			if main == null or main.is_two_handed():
				preview.set_equipment(Player.STYLE_SWORD_SHIELD.pieces)
				return
	var style: WeaponStyle = player.weapon_style if player.weapon_style else Player.STYLE_UNARMED
	if main != null:
		match main.recipe().get("style", &""):
			&"sword":
				style = Player.STYLE_SWORD_SHIELD if off and off.recipe().get("shield", false) and not off.is_broken() else Player.STYLE_SWORD
			&"heavy":
				style = Player.STYLE_HEAVY
			&"staff":
				style = Player.STYLE_STAFF
			&"hunting_horn":
				style = Player.STYLE_HORN
	elif off != null and off.recipe().get("shield", false):
		style = Player.STYLE_SWORD_SHIELD
	if style:
		preview.set_equipment(style.pieces)

func _build_character_preview_column() -> Control:
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(245, 0)
	col.add_theme_constant_override("separation", 6)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 6)
	_preview_caption = _label("🧍 Personagem", 13, EMBER)
	_preview_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview_caption.clip_text = true
	_preview_caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	top_row.add_child(_preview_caption)
	col.add_child(top_row)

	var container := SubViewportContainer.new()
	container.stretch = true
	container.custom_minimum_size = Vector2(240, 360)
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.gui_input.connect(_on_preview_input)
	col.add_child(container)

	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	container.add_child(viewport)

	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#1b1714")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#9c8f84")
	environment.ambient_light_energy = 0.65
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.environment = environment
	viewport.add_child(world)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35.0, 25.0, 0.0)
	key.light_energy = 1.35
	viewport.add_child(key)

	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-20.0, 200.0, 0.0)
	rim.light_energy = 0.55
	rim.light_color = Color(1.0, 0.72, 0.45)
	viewport.add_child(rim)

	var stand := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.62
	disc.bottom_radius = 0.62
	disc.height = 0.04
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color("#3a322c")
	disc.material = floor_material
	stand.mesh = disc
	stand.position.y = -0.02
	viewport.add_child(stand)

	preview = CharacterVisual.new()
	preview.weapon_scene = null
	preview.dna = CharacterDNA.new()
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

	_helmet_toggle = _button("🪖 Esconder capacete", false)
	_helmet_toggle.tooltip_text = "Esconde ou mostra o capacete/capuz no personagem"
	_helmet_toggle.pressed.connect(toggle_hide_helmet)
	col.add_child(_helmet_toggle)

	return col

func _frame_camera() -> void:
	if _camera == null:
		return
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
	panel.custom_minimum_size = Vector2(1380, 660)
	panel.add_theme_stylebox_override("panel", _box(Color(0.09, 0.07, 0.06, 0.96), Color(EMBER.r, EMBER.g, EMBER.b, 0.35), 14, 1, Vector2(20, 16)))
	center.add_child(panel)
	var root_box := VBoxContainer.new()
	root_box.add_theme_constant_override("separation", 8)
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

	root_box.add_child(_build_filter_toolbar())

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	root_box.add_child(body)
	var recipes_scroll := ScrollContainer.new()
	recipes_scroll.custom_minimum_size = Vector2(255, 0)
	recipes_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(recipes_scroll)
	_recipes_box = VBoxContainer.new()
	_recipes_box.add_theme_constant_override("separation", 4)
	recipes_scroll.add_child(_recipes_box)

	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 10)
	body.add_child(mid)
	_derivations_box = VBoxContainer.new()
	_derivations_box.add_theme_constant_override("separation", 6)
	mid.add_child(_derivations_box)
	_slots_box = VBoxContainer.new()
	_slots_box.add_theme_constant_override("separation", 10)
	mid.add_child(_slots_box)
	_preview = VBoxContainer.new()
	_preview.add_theme_constant_override("separation", 6)
	mid.add_child(_preview)

	body.add_child(_build_character_preview_column())

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(305, 0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	_items_box = VBoxContainer.new()
	_items_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_items_box.add_theme_constant_override("separation", 6)
	scroll.add_child(_items_box)

func _build_filter_toolbar() -> Control:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 12)

	_slot_filter_bar = HBoxContainer.new()
	_slot_filter_bar.add_theme_constant_override("separation", 4)
	_slot_filter_bar.add_child(_label("Equipamento:", 12, TEXT_DIM))
	var all_slot_btn := _button("Todos", true)
	all_slot_btn.set_meta("slot", -1)
	all_slot_btn.pressed.connect(func(): set_slot_filter(-1))
	_slot_filter_bar.add_child(all_slot_btn)
	for s in ForgedItem.SLOT_NAMES.size():
		var b := _button("%s %s" % [SLOT_FILTER_ICONS[s], SLOT_SHORT_NAMES[s]], false)
		b.set_meta("slot", s)
		b.pressed.connect(func(): set_slot_filter(s))
		_slot_filter_bar.add_child(b)
	bar.add_child(_slot_filter_bar)

	var sep := VSeparator.new()
	bar.add_child(sep)

	_family_filter_bar = HBoxContainer.new()
	_family_filter_bar.add_theme_constant_override("separation", 4)
	_family_filter_bar.add_child(_label("Derivação:", 12, TEXT_DIM))
	for entry in FAMILY_FILTERS:
		var fam: StringName = entry.id
		var b := _button(entry.label, fam == &"")
		b.set_meta("family", fam)
		b.pressed.connect(func(): set_family_filter(fam))
		_family_filter_bar.add_child(b)
	bar.add_child(_family_filter_bar)
	return bar

func _style_filter_pill(b: Button, active: bool) -> void:
	var fg := Color(0.12, 0.08, 0.04) if active else TEXT
	for c in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(c, fg)
	var bg := EMBER if active else Color(EMBER.r, EMBER.g, EMBER.b, 0.08)
	b.add_theme_stylebox_override("normal", _box(bg, EMBER, 10, 1, Vector2(9, 4)))
	b.add_theme_stylebox_override("hover", _box(bg.lightened(0.12), EMBER, 10, 1, Vector2(9, 4)))
	b.add_theme_stylebox_override("pressed", _box(bg.darkened(0.1), EMBER, 10, 1, Vector2(9, 4)))

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
	b.add_theme_font_size_override("font_size", 12)
	var fg := Color(0.12, 0.08, 0.04) if filled else TEXT
	for c in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(c, fg)
	b.add_theme_color_override("font_disabled_color", Color(0.42, 0.4, 0.38))
	var bg := EMBER if filled else Color(EMBER.r, EMBER.g, EMBER.b, 0.1)
	b.add_theme_stylebox_override("normal", _box(bg, EMBER, 10, 1, Vector2(10, 5)))
	b.add_theme_stylebox_override("hover", _box(bg.lightened(0.12), EMBER, 10, 1, Vector2(10, 5)))
	b.add_theme_stylebox_override("pressed", _box(bg.darkened(0.1), EMBER, 10, 1, Vector2(10, 5)))
	b.add_theme_stylebox_override("disabled", _box(Color(1, 1, 1, 0.03), Color(1, 1, 1, 0.08), 10, 1, Vector2(10, 5)))
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
