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
	MEL,
	VEIO_FERRO,
	VEIO_QUARTZO
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
	},
	# Veios de minério (GDD-12 §8): aguentam várias batidas, encolhem a cada uma e voltam inteiros
	Type.VEIO_FERRO: {
		"id": &"minerio_ferro",
		"name": "Veio de Ferro",
		"action": "Minerar",
		"verb": "Minerando",
		"tag": &"mineracao",
		"xp": 16.0,
		"time": 1.1,
		"min": 1,
		"max": 2,
		"hits": 4,
		"respawn": 240.0,
		"color": Color(0.55, 0.32, 0.22)
	},
	Type.VEIO_QUARTZO: {
		"id": &"quartzo_lume",
		"name": "Veio de Quartzo-Lume",
		"action": "Minerar",
		"verb": "Minerando",
		"tag": &"mineracao",
		"xp": 24.0,
		"time": 1.4,
		"min": 1,
		"max": 1,
		"hits": 3,
		"respawn": 300.0,
		"color": Color(0.62, 0.86, 0.95)
	}
}

# Assets existentes
const _WorldLabel = preload("res://scripts/ui/world_label.gd")
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
## Batidas que o nó aguenta antes de sumir (veios de minério); 1 = some na primeira coleta
var max_hits: int = 1
var hits_left: int = 1

var is_collected: bool = false
var _respawn_timer: float = 0.0

var prompt_label: _WorldLabel
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
	max_hits = int(cfg.get("hits", 1))
	hits_left = max_hits

func _build_prompt() -> void:
	if prompt_label == null:
		prompt_label = _WorldLabel.make(_WorldLabel.Kind.PROMPT, "")
		prompt_label.name = "PromptLabel"
		prompt_label.use_range = Player.HARVEST_RANGE
		add_child(prompt_label)

	prompt_label.set_full_text("[E] %s %s" % [action_name, display_name])
	prompt_label.position.y = _get_label_height()

func _get_label_height() -> float:
	match type:
		Type.MEL:
			return 1.4
		Type.MADEIRA, Type.FRUTINHA:
			return 0.85
		Type.ERVA, Type.FIBRA, Type.OSSOS:
			return 0.6
		Type.VEIO_FERRO, Type.VEIO_QUARTZO:
			return 1.3
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

		Type.VEIO_FERRO, Type.VEIO_QUARTZO:
			_build_vein(type == Type.VEIO_QUARTZO)

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
	
	hits_left -= 1
	if hits_left > 0:
		# Veio: cada batida tira um pedaço; some só na última
		if visual_container:
			var s: float = 0.55 + 0.45 * float(hits_left) / float(max_hits)
			var tw := create_tween()
			tw.tween_property(visual_container, "scale", Vector3.ONE * s * 0.9, 0.06)
			tw.tween_property(visual_container, "scale", Vector3.ONE * s, 0.12)
		return "%dx %s%s" % [amount, MaterialData.of(material_id).display_name, " ★★" if quality >= 2 else ""]
	is_collected = true
	_set_visual_visible(false)
	
	if respawn_enabled and respawn_time > 0.0:
		_respawn_timer = respawn_time
	
	return "%dx %s%s" % [amount, MaterialData.of(material_id).display_name if max_hits > 1 else display_name, " ★★" if quality >= 2 else ""]

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
		prompt_label.active = vis

func respawn() -> void:
	is_collected = false
	hits_left = max_hits
	_respawn_timer = 0.0
	_set_visual_visible(true)
	
	# Animação suave de surgimento
	if visual_container:
		visual_container.scale = Vector3.ZERO
		var tw := create_tween()
		tw.tween_property(visual_container, "scale", Vector3.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## Rocha do veio: pedra escura com pedaços de minério à mostra (ferro enferrujado ou cristal)
func _build_vein(crystal: bool) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(int(global_position.x * 10.0), int(global_position.z * 10.0))) if is_inside_tree() else randi()
	var rock_mat := StandardMaterial3D.new()
	rock_mat.albedo_color = Color(0.3, 0.29, 0.28)
	rock_mat.roughness = 0.95
	var ore_mat := StandardMaterial3D.new()
	if crystal:
		ore_mat.albedo_color = Color(0.62, 0.86, 0.95, 0.9)
		ore_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ore_mat.roughness = 0.1
		ore_mat.emission_enabled = true
		ore_mat.emission = Color(0.35, 0.7, 0.95)
		ore_mat.emission_energy_multiplier = 0.9
	else:
		ore_mat.albedo_color = Color(0.58, 0.3, 0.16)
		ore_mat.metallic = 0.55
		ore_mat.roughness = 0.5
	var rock := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.55
	sphere.height = 0.85
	sphere.radial_segments = 7
	sphere.rings = 4
	rock.mesh = sphere
	rock.scale = Vector3(1.2, 0.85, 1.0)
	rock.position.y = 0.25
	rock.material_override = rock_mat
	visual_container.add_child(rock)
	for i in 5:
		var chunk := MeshInstance3D.new()
		var a: float = TAU * float(i) / 5.0 + rng.randf_range(-0.3, 0.3)
		if crystal:
			var prism := PrismMesh.new()
			prism.size = Vector3(0.16, rng.randf_range(0.35, 0.6), 0.16)
			chunk.mesh = prism
			chunk.rotation = Vector3(rng.randf_range(-0.4, 0.4), a, rng.randf_range(-0.5, 0.5))
		else:
			var box := BoxMesh.new()
			box.size = Vector3.ONE * rng.randf_range(0.14, 0.24)
			chunk.mesh = box
			chunk.rotation = Vector3(rng.randf(), rng.randf(), rng.randf()) * TAU
		chunk.position = Vector3(cos(a) * 0.5, 0.3 + rng.randf_range(0.0, 0.25), sin(a) * 0.42)
		chunk.material_override = ore_mat
		visual_container.add_child(chunk)
	if crystal:
		var glow := OmniLight3D.new()
		glow.light_color = Color(0.5, 0.8, 1.0)
		glow.light_energy = 0.35
		glow.omni_range = 2.5
		glow.position.y = 0.6
		visual_container.add_child(glow)
