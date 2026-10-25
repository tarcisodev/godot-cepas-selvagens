class_name DroppedLoot
extends Node3D

## Trouxa de itens jogados no chão pelo jogador (materiais em pilha ou equipamento forjado).
## Possui modelo 3D de saco de couro com cristal brilhante na cor da raridade, animação de
## queda suave (arco parabólico) e coleta imediata com [E].

var stack: Dictionary = {}
var forged_item: ForgedItem = null
var talk_radius: float = 0.8
var is_collected: bool = false

var _visual: Node3D
var _prompt: Label3D
var _bob_time: float = 0.0

static func spawn_for_stack(parent: Node, origin_pos: Vector3, drop_pos: Vector3, stack_data: Dictionary) -> DroppedLoot:
	if parent == null or stack_data.is_empty():
		return null
	var loot := DroppedLoot.new()
	loot.name = "DroppedLoot_%s" % String(stack_data.get("id", &"item"))
	loot.stack = {
		"id": StringName(stack_data.get("id", &"")),
		"quality": int(stack_data.get("quality", 1)),
		"traits": stack_data.get("traits", []).duplicate(),
		"amount": int(stack_data.get("amount", 1)),
	}
	parent.add_child(loot)
	loot.global_position = drop_pos
	loot._play_drop_arc(origin_pos, drop_pos)
	return loot

static func spawn_for_item(parent: Node, origin_pos: Vector3, drop_pos: Vector3, item: ForgedItem) -> DroppedLoot:
	if parent == null or item == null:
		return null
	var loot := DroppedLoot.new()
	loot.name = "DroppedGear_%s" % String(item.recipe_id)
	loot.forged_item = item
	parent.add_child(loot)
	loot.global_position = drop_pos
	loot._play_drop_arc(origin_pos, drop_pos)
	return loot

func _ready() -> void:
	add_to_group("talkable")
	add_to_group("harvestable")
	add_to_group("dropped_loot")
	_build_visual()
	_build_prompt()

func _process(delta: float) -> void:
	if is_collected:
		return
	_bob_time += delta * 2.4
	if _visual:
		_visual.rotation.y += delta * 0.85

## Chamado pelo Player ao apertar [E] perto da trouxa (grupo "talkable": coleta instantânea)
func talk_to(collector: Node) -> void:
	if is_collected or collector == null:
		return
	var label := _collect_into(collector)
	if not label.is_empty() and collector.has_signal("posture_changed"):
		collector.posture_changed.emit("🎒 Recolheu do chão: " + label)

## Compatibilidade com o contrato "harvestable"
func is_harvestable() -> bool:
	return not is_collected

func next_harvest_label() -> String:
	return _item_title()

func get_harvest_verb() -> String:
	return "Recolhendo"

func get_gather_time(_mastery: MasteryComponent = null) -> float:
	return 0.15

func harvest_next(harvester: Node = null) -> String:
	return _collect_into(harvester)

func _collect_into(collector: Node) -> String:
	if is_collected:
		return ""
	var inv: InventoryComponent = null
	if collector != null:
		inv = collector.get_node_or_null("InventoryComponent") as InventoryComponent
		if inv == null and "inventory" in collector:
			inv = collector.inventory
	if inv == null:
		return ""

	var summary := _item_title()
	if forged_item != null:
		inv.add_item(forged_item)
	elif not stack.is_empty():
		inv.add_material(
			StringName(stack.get("id", &"")),
			int(stack.get("amount", 1)),
			int(stack.get("quality", 1)),
			stack.get("traits", [])
		)
	is_collected = true
	if is_inside_tree():
		var tw := create_tween()
		tw.tween_property(self, "scale", Vector3.ONE * 0.05, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tw.tween_callback(queue_free)
	else:
		queue_free()
	return summary

func _item_title() -> String:
	if forged_item != null:
		return "%s %s" % [forged_item.display_name, "★".repeat(forged_item.quality)]
	if not stack.is_empty():
		var data := MaterialData.of(StringName(stack.get("id", &"")))
		var q: int = int(stack.get("quality", 1))
		var amt: int = int(stack.get("amount", 1))
		return "%s %s ×%d %s" % [data.icon, data.display_name, amt, "★".repeat(q)]
	return "Trouxa"

func _rarity_color() -> Color:
	var q: int = 1
	if forged_item != null:
		q = forged_item.quality
	elif not stack.is_empty():
		q = int(stack.get("quality", 1))
	return MaterialData.rarity_color(q)

func _build_visual() -> void:
	if _visual:
		_visual.queue_free()
	_visual = Node3D.new()
	_visual.name = "PouchVisual"
	add_child(_visual)

	var accent := _rarity_color()
	var pouch_mat := StandardMaterial3D.new()
	pouch_mat.albedo_color = Color(0.46, 0.32, 0.19)
	pouch_mat.roughness = 0.88

	# Corpo da trouxa de couro
	var bag := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.20
	sphere.height = 0.32
	bag.mesh = sphere
	bag.position.y = 0.15
	bag.scale = Vector3(1.1, 0.88, 1.05)
	bag.material_override = pouch_mat
	_visual.add_child(bag)

	# Gargalo amarrado com cordão na cor da raridade
	var rope := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.09
	cyl.bottom_radius = 0.07
	cyl.height = 0.05
	rope.mesh = cyl
	rope.position.y = 0.29
	var rope_mat := StandardMaterial3D.new()
	rope_mat.albedo_color = accent
	rope_mat.emission_enabled = true
	rope_mat.emission = accent * 0.45
	rope_mat.roughness = 0.4
	rope.material_override = rope_mat
	_visual.add_child(rope)

	# Aba superior do saco
	var crest := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.12
	cone.bottom_radius = 0.06
	cone.height = 0.08
	crest.mesh = cone
	crest.position.y = 0.34
	crest.material_override = pouch_mat
	_visual.add_child(crest)

	# Cristal flutuante indicando raridade
	var gem := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(0.10, 0.14, 0.10)
	gem.mesh = prism
	gem.position.y = 0.48
	gem.material_override = rope_mat
	_visual.add_child(gem)

	var light := OmniLight3D.new()
	light.light_color = accent
	light.light_energy = 0.45
	light.omni_range = 1.8
	light.position.y = 0.42
	_visual.add_child(light)

func _build_prompt() -> void:
	if _prompt == null:
		_prompt = Label3D.new()
		_prompt.name = "PromptLabel"
		_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_prompt.font_size = 20
		_prompt.outline_size = 5
		_prompt.outline_modulate = Color(0, 0, 0, 0.9)
		_prompt.visibility_range_end = 5.5
		add_child(_prompt)
	_prompt.modulate = _rarity_color().lightened(0.25)
	_prompt.text = "[E] Pegar %s" % _item_title()
	_prompt.position.y = 0.72

func _play_drop_arc(origin_pos: Vector3, drop_pos: Vector3) -> void:
	if not is_inside_tree() or _visual == null:
		return
	var local_start: Vector3 = origin_pos - drop_pos
	_visual.position = local_start
	_visual.scale = Vector3.ONE * 0.45
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_visual, "position:x", 0.0, 0.26).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(_visual, "position:z", 0.0, 0.26).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(_visual, "position:y", 0.0, 0.26).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_property(_visual, "scale", Vector3.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
