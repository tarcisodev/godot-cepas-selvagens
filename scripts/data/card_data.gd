class_name CardData
extends Resource

## Dados e atributos de uma Carta 3D Colecionável (GDD-07 e B08).
## Contém metadados para catálogo, referências visuais e estatísticas para o futuro mini-game.

enum Rarity {
	COMMON = 1,    ## Comum (Bronze)
	UNCOMMON = 2,  ## Incomum (Prata)
	RARE = 3,      ## Raro (Ouro)
	LEGENDARY = 4  ## Lendário (Éter / Holográfico)
}

enum CardElement {
	EARTH,
	FIRE,
	WATER,
	AIR,
	LIGHTNING,
	DARK,
	NEUTRAL
}

@export var id: StringName = &""
@export var title: String = ""
@export var category: String = "Bestiário"
@export var rarity: Rarity = Rarity.COMMON
@export var description: String = ""
@export var flavor_lore: String = ""

# Atributos táticos do Mini-Game (GDD-07 §4)
@export var ether_cost: int = 1
@export var power: int = 3
@export var poise: int = 4
@export var element: CardElement = CardElement.EARTH
@export var trait_name: String = ""
@export var trait_description: String = ""

# Caminhos de Assets 3D e 2D
@export var model_path: String = ""
@export var render_path: String = ""

func _init(
	p_id: StringName = &"",
	p_title: String = "",
	p_category: String = "Bestiário",
	p_rarity: Rarity = Rarity.COMMON,
	p_element: CardElement = CardElement.EARTH,
	p_ether: int = 1,
	p_power: int = 3,
	p_poise: int = 4,
	p_trait_name: String = "",
	p_trait_desc: String = "",
	p_desc: String = "",
	p_lore: String = "",
	p_model: String = "",
	p_render: String = ""
) -> void:
	id = p_id
	title = p_title
	category = p_category
	rarity = p_rarity
	element = p_element
	ether_cost = p_ether
	power = p_power
	poise = p_poise
	trait_name = p_trait_name
	trait_description = p_trait_desc
	description = p_desc
	flavor_lore = p_lore
	model_path = p_model
	render_path = p_render

func get_rarity_name() -> String:
	match rarity:
		Rarity.COMMON:
			return "Comum"
		Rarity.UNCOMMON:
			return "Incomum"
		Rarity.RARE:
			return "Raro"
		Rarity.LEGENDARY:
			return "Lendário"
		_:
			return "Desconhecido"

func get_rarity_color() -> Color:
	match rarity:
		Rarity.COMMON:
			return Color(0.72, 0.72, 0.75, 1.0) # Cinza / Alumínio
		Rarity.UNCOMMON:
			return Color(0.35, 0.85, 0.55, 1.0) # Verde esmeralda / Prata
		Rarity.RARE:
			return Color(1.0, 0.82, 0.22, 1.0)  # Ouro vivo
		Rarity.LEGENDARY:
			return Color(0.95, 0.45, 1.0, 1.0)  # Holográfico / Violeta
		_:
			return Color.WHITE

func get_element_name() -> String:
	match element:
		CardElement.EARTH:
			return "Terra"
		CardElement.FIRE:
			return "Fogo"
		CardElement.WATER:
			return "Água"
		CardElement.AIR:
			return "Ar"
		CardElement.LIGHTNING:
			return "Raio"
		CardElement.DARK:
			return "Trevas"
		_:
			return "Neutro"

func get_element_color() -> Color:
	match element:
		CardElement.EARTH:
			return Color(0.75, 0.55, 0.32, 1.0) # Marrom terracota
		CardElement.FIRE:
			return Color(0.95, 0.38, 0.20, 1.0) # Laranja fogo
		CardElement.WATER:
			return Color(0.28, 0.65, 0.95, 1.0) # Azul marinho
		CardElement.AIR:
			return Color(0.65, 0.90, 0.95, 1.0) # Ciano vento
		CardElement.LIGHTNING:
			return Color(0.95, 0.90, 0.25, 1.0) # Amarelo elétrico
		CardElement.DARK:
			return Color(0.55, 0.30, 0.75, 1.0) # Roxo sombrio
		_:
			return Color(0.80, 0.80, 0.80, 1.0)

func to_dict() -> Dictionary:
	return {
		"id": id,
		"title": title,
		"category": category,
		"rarity": get_rarity_name(),
		"element": get_element_name(),
		"ether_cost": ether_cost,
		"power": power,
		"poise": poise,
		"trait": trait_name,
		"description": description,
		"lore": flavor_lore,
		"model_path": model_path,
		"render_path": render_path
	}
