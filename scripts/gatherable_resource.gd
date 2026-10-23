class_name GatherableResource
extends Node3D

## Recurso Coletável no Mundo (Fase 1: Coleta dos 10 Recursos).
## Representa nós físicos de coleta espalhados pelo mapa com modelo 3D,
## indicador visual [E], tempo ajustado por maestria e respawn automático.
## Compatível com o contrato 'harvestable' do Player.

enum Type {
	MADEIRA,
	GALHO,
	FOLHA,
	FIBRA,
	PEDRA,
	FRUTINHA,
	BESOURO,
	OSSOS,
	ERVA,
	MEL
}

const TYPE_CONFIG: Dictionary = {
	Type.MADEIRA: {
		"id": &"madeira",
		"name": "Tronco de Madeira",
		"action": "Cortar",
		"verb": "Cortando",
		"tag": &"coleta",
		"xp": 18.0,
		"time": 1.4,
		"min": 2,
		"max": 3,
		"respawn": 45.0,
		"color": Color(0.42, 0.28, 0.16)
	},
	Type.GALHO: {
		"id": &"galho",
		"name": "Galho Seco",
		"action": "Apanhar",
		"verb": "Apanhando",
		"tag": &"coleta",
		"xp": 8.0,
		"time": 0.35,
		"min": 1,
		"max": 2,
		"respawn": 25.0,
		"color": Color(0.55, 0.40, 0.24)
	},
	Type.FOLHA: {
		"id": &"folha",
		"name": "Folhas Frescas",
		"action": "Podar",
		"verb": "Podando",
		"tag": &"coleta",
		"xp": 8.0,
		"time": 0.4,
		"min": 2,
		"max": 4,
		"respawn": 30.0,
		"color": Color(0.24, 0.58, 0.22)
	},
	Type.FIBRA: {
		"id": &"fibra",
		"name": "Fibras Vegetais",
		"action": "Arrancar",
		"verb": "Arrancando",
		"tag": &"coleta",
		"xp": 10.0,
		"time": 0.45,
		"min": 1,
		"max": 3,
		"respawn": 30.0,
		"color": Color(0.68, 0.72, 0.32)
	},
	Type.PEDRA: {
		"id": &"pedra",
		"name": "Pedra Solta",
		"action": "Recolher",
		"verb": "Recolhendo",
		"tag": &"mineracao",
		"xp": 12.0,
		"time": 0.4,
		"min": 1,
		"max": 2,
		"respawn": 35.0,
		"color": Color(0.52, 0.52, 0.54)
	},
	Type.FRUTINHA: {
		"id": &"frutinha",
		"name": "Frutas Silvestres",
		"action": "Colher",
		"verb": "Colhendo",
		"tag": &"coleta",
		"xp": 10.0,
		"time": 0.4,
		"min": 2,
		"max": 3,
		"respawn": 35.0,
		"color": Color(0.85, 0.22, 0.35)
	},
	Type.BESOURO: {
		"id": &"besouro",
		"name": "Besouro Casca-Dura",
		"action": "Capturar",
		"verb": "Capturando",
		"tag": &"coleta",
		"xp": 15.0,
		"time": 0.3,
		"min": 1,
		"max": 1,
		"respawn": 40.0,
		"color": Color(0.18, 0.65, 0.68)
	},
	Type.OSSOS: {
		"id": &"ossos",
		"name": "Restos Ósseos",
		"action": "Recolher",
		"verb": "Recolhendo",
		"tag": &"coleta",
		"xp": 14.0,
		"time": 0.6,
		"min": 1,
		"max": 2,
		"respawn": 50.0,
		"color": Color(0.92, 0.90, 0.82)
	},
	Type.ERVA: {
		"id": &"erva",
		"name": "Erva Silvestre",
		"action": "Colher",
		"verb": "Colhendo",
		"tag": &"coleta",
		"xp": 12.0,
		"time": 0.5,
		"min": 1,
		"max": 2,
		"respawn": 35.0,
		"color": Color(0.35, 0.75, 0.45)
	},
	Type.MEL: {
		"id": &"mel",
		"name": "Favo de Mel Selvagem",
		"action": "Extrair",
		"verb": "Extraindo",
		"tag": &"coleta",
		"xp": 25.0,
		"time": 1.5,
		"min": 1,
		"max": 1,
		"respawn": 60.0,
		"color": Color(0.95, 0.72, 0.15)
	}
}

# Assets existentes
const PEBBLE_SCENE = preload("res://assets/models/nature/Pebble_Round_1.gltf")
const PLANT_SCENE = preload("res://assets/models/nature/Plant_1.gltf")
const FERN_SCENE = preload("res://assets/models/nature/Fern_1.gltf")
const CLOVER_SCENE = preload("res://assets/models/nature/Clover_1.gltf")
const BUSH_FLOWERS_SCENE = preload("res://assets/models/nature/Bush_Common_Flowers.gltf")
const BEEHIVE_SCENE = preload("res://assets/cards_3d/card_kit/glTF/10_Beehive.gltf")

@export var type: Type = Type.GALHO:
	set(v):
		type = v
		_apply_config()
		if visual_container != null:
			_rebuild_visual()
			_build_prompt()

@export var respawn_enabled: bool = true
@export var custom_amount_min: int = 0
@export var custom_amount_max: int = 0

var material_id: StringName = &"galho"
var display_name: String = "Galho Seco"
var action_name: String = "Apanhar"
var harvest_verb: String = "Apanhando"
var mastery_tag: StringName = &"coleta"
var mastery_xp: float = 8.0
var base_gather_time: float = 0.35
var min_amount: int = 1
var max_amount: int = 2
var respawn_time: float = 25.0

var is_collected: bool = false
var _respawn_timer: float = 0.0

var prompt_label: Label3D
var visual_container: Node3D

func _ready() -> void:
	add_to_group("harvestable")
	add_to_group("gatherable")
	_apply_config()
	_rebuild_visual()
	_build_prompt()

func _apply_config() -> void:
	var cfg: Dictionary = TYPE_CONFIG.get(type, TYPE_CONFIG[Type.GALHO])
	material_id = cfg["id"]
	display_name = cfg["name"]
	action_name = cfg["action"]
	harvest_verb = cfg["verb"]
	mastery_tag = cfg["tag"]
	mastery_xp = cfg["xp"]
	base_gather_time = cfg["time"]
	min_amount = custom_amount_min if custom_amount_min > 0 else cfg["min"]
	max_amount = custom_amount_max if custom_amount_max > 0 else cfg["max"]
	respawn_time = cfg["respawn"]

func _build_prompt() -> void:
	if prompt_label == null:
		prompt_label = Label3D.new()
		prompt_label.name = "PromptLabel"
		prompt_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		prompt_label.font_size = 20
		prompt_label.outline_size = 4
		prompt_label.outline_modulate = Color(0, 0, 0, 0.85)
		prompt_label.modulate = Color(1.0, 0.95, 0.7)
		prompt_label.visibility_range_end = 3.6
		add_child(prompt_label)
	
	prompt_label.text = "[E] %s %s" % [action_name, display_name]
	prompt_label.position.y = _get_label_height()

func _get_label_height() -> float:
	match type:
		Type.MEL:
			return 1.4
		Type.MADEIRA, Type.FRUTINHA:
			return 0.85
		Type.ERVA, Type.FIBRA, Type.OSSOS:
			return 0.6
		_:
			return 0.45

func _rebuild_visual() -> void:
	if visual_container:
		visual_container.queue_free()
	
	visual_container = Node3D.new()
	visual_container.name = "VisualContainer"
	add_child(visual_container)
	
	match type:
		Type.MADEIRA:
			# Tronco caído estilizado
			var mesh_inst := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.22
			cyl.bottom_radius = 0.25
			cyl.height = 1.6
			mesh_inst.mesh = cyl
			mesh_inst.rotation.z = deg_to_rad(90.0)
			mesh_inst.position.y = 0.22
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(0.38, 0.24, 0.14)
			mat.roughness = 0.9
			mesh_inst.material_override = mat
			visual_container.add_child(mesh_inst)

		Type.GALHO:
			# Graveto caído no chão
			var mesh_inst := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.035
			cyl.bottom_radius = 0.045
			cyl.height = 0.75
			mesh_inst.mesh = cyl
			mesh_inst.rotation.z = deg_to_rad(85.0)
			mesh_inst.rotation.y = deg_to_rad(randf_range(-45.0, 45.0))
			mesh_inst.position.y = 0.04
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(0.48, 0.33, 0.18)
			mesh_inst.material_override = mat
			visual_container.add_child(mesh_inst)

		Type.FOLHA:
			if CLOVER_SCENE:
				var m := CLOVER_SCENE.instantiate() as Node3D
				m.scale = Vector3.ONE * 0.9
				visual_container.add_child(m)

		Type.FIBRA:
			if FERN_SCENE:
				var m := FERN_SCENE.instantiate() as Node3D
				m.scale = Vector3.ONE * 0.65
				visual_container.add_child(m)

		Type.PEDRA:
			if PEBBLE_SCENE:
				var m := PEBBLE_SCENE.instantiate() as Node3D
				m.scale = Vector3.ONE * 0.8
				visual_container.add_child(m)

		Type.FRUTINHA:
			if BUSH_FLOWERS_SCENE:
				var m := BUSH_FLOWERS_SCENE.instantiate() as Node3D
				m.scale = Vector3.ONE * 0.35
				visual_container.add_child(m)

		Type.BESOURO:
			# Besouro com carapaça metálica brilhante
			var body_mesh := MeshInstance3D.new()
			var sphere := SphereMesh.new()
			sphere.radius = 0.09
			sphere.height = 0.16
			body_mesh.mesh = sphere
			body_mesh.scale = Vector3(1.0, 0.45, 1.4)
			body_mesh.position.y = 0.06
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(0.12, 0.62, 0.58)
			mat.metallic = 0.85
			mat.roughness = 0.25
			mat.emission_enabled = true
			mat.emission = Color(0.05, 0.3, 0.25)
			mat.emission_energy_multiplier = 0.6
			body_mesh.material_override = mat
			visual_container.add_child(body_mesh)

		Type.OSSOS:
			# Pilha de ossos clara
			var bones_group := Node3D.new()
			for i in 3:
				var bone := MeshInstance3D.new()
				var cyl := CylinderMesh.new()
				cyl.top_radius = 0.035
				cyl.bottom_radius = 0.035
				cyl.height = 0.55
				bone.mesh = cyl
				bone.rotation.z = deg_to_rad(75.0 + i * 15.0)
				bone.rotation.y = deg_to_rad(i * 40.0)
				bone.position = Vector3(i * 0.06, 0.04 + i * 0.02, 0)
				var mat := StandardMaterial3D.new()
				mat.albedo_color = Color(0.92, 0.89, 0.80)
				mat.roughness = 0.8
				bone.material_override = mat
				bones_group.add_child(bone)
			visual_container.add_child(bones_group)

		Type.ERVA:
			if PLANT_SCENE:
				var m := PLANT_SCENE.instantiate() as Node3D
				m.scale = Vector3.ONE * 0.6
				visual_container.add_child(m)

		Type.MEL:
			if BEEHIVE_SCENE:
				var m := BEEHIVE_SCENE.instantiate() as Node3D
				m.scale = Vector3.ONE * 0.4
				m.position.y = 0.65
				visual_container.add_child(m)

func _process(delta: float) -> void:
	if is_collected and respawn_enabled:
		_respawn_timer -= delta
		if _respawn_timer <= 0.0:
			respawn()

## Interface 'harvestable' duck typing para o Player:
func is_harvestable() -> bool:
	return not is_collected

func next_harvest_label() -> String:
	return display_name

func get_harvest_verb() -> String:
	return harvest_verb

func get_gather_time(mastery: MasteryComponent = null) -> float:
	var mult: float = 1.0
	if mastery:
		var lvl: int = mastery.get_level(mastery_tag)
		mult = clampf(1.0 - (float(lvl - 1) / 100.0) * 0.5, 0.45, 1.0)
	return base_gather_time * mult

func harvest_next(harvester: Node = null) -> String:
	if not is_harvestable():
		return ""
	
	var amount: int = randi_range(min_amount, max_amount)
	var quality: int = 1

	if harvester != null:
		var mst: MasteryComponent = harvester.get_node_or_null("MasteryComponent") as MasteryComponent
		if mst == null and "mastery" in harvester:
			mst = harvester.mastery
		var level: int = mst.get_level(mastery_tag) if mst != null else 1
		quality = roll_quality(level, MaterialData.of(material_id).max_gather_quality)

		var inv: InventoryComponent = harvester.get_node_or_null("InventoryComponent") as InventoryComponent
		if inv == null and "inventory" in harvester:
			inv = harvester.inventory
		if inv != null:
			inv.add_material(material_id, amount, quality)

		if mst != null:
			mst.add_xp(mastery_tag, mastery_xp)
		
		# Efeito especial de Mel (abelhas picam se coletar sem tocha/proteção)
		if type == Type.MEL:
			_handle_bee_hazard(harvester)
	
	is_collected = true
	_set_visual_visible(false)
	
	if respawn_enabled and respawn_time > 0.0:
		_respawn_timer = respawn_time
	
	return "%dx %s%s" % [amount, display_name, " ★★" if quality >= 2 else ""]

## Qualidade da coleta comum (GDD-08 §8): 1★; a partir do nível 25 da maestria,
## chance de 2★ = 10% + 0,4% por nível acima de 25. Nunca passa de `max_quality`.
static func roll_quality(mastery_level: int, max_quality: int = 2, rng: RandomNumberGenerator = null) -> int:
	if mastery_level < 25 or max_quality < 2:
		return 1
	var chance := 0.10 + 0.004 * float(mastery_level - 25)
	var roll := rng.randf() if rng else randf()
	return 2 if roll < chance else 1

func _handle_bee_hazard(harvester: Node) -> void:
	# Fumaça da tocha acesa acalma as abelhas
	if TorchComponent.is_lit_on(harvester):
		if harvester.has_signal("posture_changed"):
			harvester.posture_changed.emit("🔥 A fumaça da tocha acalmou as abelhas")
		return
	if harvester and "pools" in harvester and harvester.pools != null:
		# Zumbido e dano leve de abelhas
		harvester.pools.take_damage(4.0)
		harvester.pools.consume_vigor(8.0)
		if harvester.has_signal("posture_changed"):
			harvester.posture_changed.emit("🐝 Zumbido de Abelhas! (-4 Vida, -8 Vigor)")

func _set_visual_visible(vis: bool) -> void:
	if visual_container:
		visual_container.visible = vis
	if prompt_label:
		prompt_label.visible = vis

func respawn() -> void:
	is_collected = false
	_respawn_timer = 0.0
	_set_visual_visible(true)
	
	# Animação suave de surgimento
	if visual_container:
		visual_container.scale = Vector3.ZERO
		var tw := create_tween()
		tw.tween_property(visual_container, "scale", Vector3.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
