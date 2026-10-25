class_name MaterialData
extends Resource

## Tipo de material (GDD-06 §1). Descreve o que o material É; o estado (qualidade, traits,
## quantidade) mora na pilha do InventoryComponent (ADR-0005).
## Um .tres por material em res://resources/materials/<id>.tres.

const DIR: String = "res://resources/materials/"

## Grupo do material: define a faixa colorida do slot e o filtro da tela de inventário.
enum Category { MADEIRA, PLANTA, MINERAL, ANIMAL, INSETO, CONSUMIVEL }

@export var id: StringName
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var category: Category = Category.PLANTA
## Ícone mostrado no slot (emoji, até haver arte)
@export var icon: String = "📦"
## Cor do material: tinge o fundo do ícone e serve para ordenar por cor
@export var color: Color = Color(0.7, 0.7, 0.7)
## Peso de uma unidade, em kg (base da Carga no futuro)
@export var unit_weight: float = 1.0
## Teto de qualidade de coleta comum (GDD-08 §8: 2★)
@export var max_gather_quality: int = 2
## Valor-base em Dólares de Sucata (GDD-05 §5): referência de contratos e do Mercado Negro
@export var base_value: int = 1
## Ferramenta usada pela roda rápida (GDD-03 §9): &"laco" prende, &"sedativo" captura; vazio = não é ferramenta
@export var tool_action: StringName = &""

func is_tool() -> bool:
	return not tool_action.is_empty()

@export_group("Consumo")
## Quanto repõe de cada recurso ao usar uma unidade; qualquer valor > 0 torna o item usável
@export var restore_health: float = 0.0
@export var restore_vigor: float = 0.0
@export var restore_ether: float = 0.0

@export_group("Culinária e Buffs")
## ID do buff gastronômico aplicado ao consumir (GDD-13); vazio = sem buff duradouro
@export var food_buff_id: StringName = &""
## Duração em segundos reais do buff (ex: 1200.0 = 20 min)
@export var food_buff_duration: float = 0.0
## Nome amigável do buff gastronômico (ex: "Vigor Inabalável")
@export var food_buff_name: String = ""

func is_consumable() -> bool:
	return restore_health > 0.0 or restore_vigor > 0.0 or restore_ether > 0.0 or not food_buff_id.is_empty()

## Resumo do efeito ("+40 Vida · +15 Éter · Vigor Inabalável (20 min)"); vazio se não for consumível
func effect_text() -> String:
	var parts: Array[String] = []
	if restore_health > 0.0:
		parts.append("+%d Vida" % roundi(restore_health))
	if restore_vigor > 0.0:
		parts.append("+%d Vigor" % roundi(restore_vigor))
	if restore_ether > 0.0:
		parts.append("+%d Éter" % roundi(restore_ether))
	if not food_buff_name.is_empty() or not food_buff_id.is_empty():
		var bname: String = food_buff_name if not food_buff_name.is_empty() else String(food_buff_id).capitalize()
		var mins: int = roundi(food_buff_duration / 60.0)
		parts.append("%s (%d min)" % [bname, mins] if mins > 0 else bname)
	return " · ".join(parts)

static var _cache: Dictionary = {}

## Dados do material `id`; se não houver .tres, devolve um genérico (nunca null).
static func of(material_id: StringName) -> MaterialData:
	if _cache.has(material_id):
		return _cache[material_id]
	var path := DIR + String(material_id) + ".tres"
	var data: MaterialData = load(path) as MaterialData if ResourceLoader.exists(path) else null
	if data == null:
		data = MaterialData.new()
		data.id = material_id
		data.display_name = String(material_id).capitalize()
	_cache[material_id] = data
	return data

static func rarity_name(quality: int) -> String:
	match clampi(quality, 1, 5):
		1: return "Comum"
		2: return "Incomum"
		3: return "Raro"
		4: return "Épico"
		_: return "Lendário"

## Mesma escala de cor das cartas (cinza → verde → azul → roxo → ouro)
static func rarity_color(quality: int) -> Color:
	match clampi(quality, 1, 5):
		1: return Color(0.72, 0.72, 0.75)
		2: return Color(0.35, 0.85, 0.55)
		3: return Color(0.35, 0.62, 1.0)
		4: return Color(0.74, 0.45, 1.0)
		_: return Color(1.0, 0.82, 0.22)

static func category_name(cat: int) -> String:
	match cat:
		Category.MADEIRA: return "Madeira"
		Category.PLANTA: return "Planta"
		Category.MINERAL: return "Mineral"
		Category.ANIMAL: return "Animal"
		Category.INSETO: return "Inseto"
		_: return "Consumível"

static func category_color(cat: int) -> Color:
	match cat:
		Category.MADEIRA: return Color(0.78, 0.52, 0.28)
		Category.PLANTA: return Color(0.45, 0.78, 0.35)
		Category.MINERAL: return Color(0.62, 0.68, 0.78)
		Category.ANIMAL: return Color(0.88, 0.42, 0.36)
		Category.INSETO: return Color(0.95, 0.7, 0.25)
		_: return Color(0.95, 0.45, 0.75)

## Nome de exibição de um trait (StringName em snake_case → "Snake Case")
static func trait_name(trait_id: StringName) -> String:
	# Genoma do pinhão (GDD-10 §9) aparece legível no lugar do código
	if String(trait_id).begins_with("gen_"):
		return PlantDNA.from_genome_code(String(trait_id)).describe()
	return String(trait_id).capitalize()
