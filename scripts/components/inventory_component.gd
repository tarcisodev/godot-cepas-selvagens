class_name InventoryComponent
extends Node

## Gerencia inventário de materiais de caça e forja de equipamentos (GDD-03, GDD-05 e GDD-06).
## Permite forjar o Elmo Chifre-de-Pedra aplicando modificadores ao StatsComponent do portador.

signal material_collected(material_id: StringName, amount: int)
signal item_crafted(item_name: StringName, quality: int, traits: Array[StringName])
signal equipment_changed(slot: StringName, item_name: StringName)

@export var stats: StatsComponent

# Dicionário: material_id -> quantidade
var materials: Dictionary = {
	&"placa_carapaca": 2 # Já inicia com 2 placas de carapaça para o slice
}

# Slots equipados
var equipped: Dictionary = {
	&"head": &"",
	&"body": &""
}

var _craft_source: RefCounted = RefCounted.new()

func _ready() -> void:
	if stats == null:
		stats = get_parent().get_node_or_null("StatsComponent") as StatsComponent

## Adiciona material ao inventário
func add_material(material_id: StringName, amount: int = 1) -> void:
	if amount <= 0:
		return
	var current: int = materials.get(material_id, 0)
	materials[material_id] = current + amount
	material_collected.emit(material_id, amount)

## Retorna a quantidade de um material
func get_material_count(material_id: StringName) -> int:
	return materials.get(material_id, 0)

## Verifica se possui os materiais requeridos
func has_materials(requirements: Dictionary) -> bool:
	for mat_id in requirements.keys():
		if get_material_count(mat_id) < requirements[mat_id]:
			return false
	return true

## Consome materiais
func consume_materials(requirements: Dictionary) -> bool:
	if not has_materials(requirements):
		return false
	for mat_id in requirements.keys():
		materials[mat_id] -= requirements[mat_id]
	return true

## Forja e equipa o Elmo Chifre-de-Pedra (GDD-06 §5)
func craft_and_equip_horn_helmet(use_horn_type: StringName) -> bool:
	var reqs: Dictionary = {
		use_horn_type: 1,
		&"placa_carapaca": 1
	}
	
	if not consume_materials(reqs):
		return false
	
	var is_integro: bool = (use_horn_type == &"chifre_integro")
	var quality: int = 4 if is_integro else 2
	var traits: Array[StringName] = []
	if is_integro:
		traits.append(&"Casca Rígida")
	else:
		traits.append(&"Reforçado")
	
	# Remove modificadores de capacete anteriores deste componente
	if stats != null:
		stats.remove_modifiers_from_source(_craft_source)
		
		# Modificadores de armadura e poise
		var poise_bonus: float = 0.25 if is_integro else 0.12
		var armor_bonus: float = 0.20 if is_integro else 0.10
		var load_weight: float = 18.0 if is_integro else 12.0
		
		stats.add_modifier(ModifierData.new(&"poise_resist", ModifierData.Op.FLAT, poise_bonus, _craft_source))
		stats.add_modifier(ModifierData.new(&"resist_slash", ModifierData.Op.FLAT, armor_bonus, _craft_source))
		stats.add_modifier(ModifierData.new(&"resist_impact", ModifierData.Op.FLAT, armor_bonus, _craft_source))
		stats.add_modifier(ModifierData.new(&"load", ModifierData.Op.FLAT, load_weight, _craft_source))
		
		# Aumento de peso reduz velocidade de cast e aumenta custo de esquiva
		var dodge_cost_inc: float = 8.0 if is_integro else 4.0
		stats.add_modifier(ModifierData.new(&"dodge_cost", ModifierData.Op.FLAT, dodge_cost_inc, _craft_source))
	
	var helmet_name: StringName = &"Elmo Chifre-de-Pedra (Íntegro)" if is_integro else &"Elmo Chifre-de-Pedra (Fragmentado)"
	equipped[&"head"] = helmet_name
	
	item_crafted.emit(helmet_name, quality, traits)
	equipment_changed.emit(&"head", helmet_name)
	
	# Concede XP de maestria de forja
	var parent: Node = get_parent()
	if parent != null:
		var mastery: MasteryComponent = parent.get_node_or_null("MasteryComponent") as MasteryComponent
		if mastery != null:
			mastery.add_xp(&"forja", 45.0 if is_integro else 25.0)
	
	return true
