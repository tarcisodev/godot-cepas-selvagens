class_name CookingSystem
extends RefCounted

const _InventoryComponent = preload("res://scripts/components/inventory_component.gd")
const _MaterialData = preload("res://scripts/data/material_data.gd")

## Sistema de Culinária e Gastronomia do Rancho (GDD-13 §4 e §5).
## Combina 1 Base (Carnes ou Peixes) + 1 a 3 Acompanhamentos (Vegetais, Ervas, Frutas, Mel, Pinhões, etc.)
## gerando refeições preparadas com qualidade derivada (1★ a 5★), traits herdados e buffs de longa duração.
## Permite tanto receitas gastronômicas consagradas quanto improvisações nutritivas.

const RECIPES: Array[Dictionary] = [
	{
		"id": &"gisado_cacador",
		"name": "Gisado do Caçador",
		"desc": "Ensopado espesso de carne, ervas e raízes da mata.",
		"result_id": &"gisado_cacador",
		"base_candidates": [&"carne_crua", &"carne_mal_passada", &"carne_bem_passada"],
		"required_ingredients": [&"erva", &"frutinha"],
		"buff_name": "Vigor Inabalável",
		"buff_desc": "+20 Vigor máx. e -15% de custo ao esquivar (20 min)",
	},
	{
		"id": &"peixe_ao_mel",
		"name": "Peixe Dourado ao Mel do Vale",
		"desc": "Posta de peixe fresco caramelizada ao mel silvestre e ervas.",
		"result_id": &"peixe_ao_mel",
		"base_candidates": [&"peixe_dourado", &"peixe_lambari", &"peixe_traira"],
		"required_ingredients": [&"mel", &"erva"],
		"buff_name": "Foco Místico",
		"buff_desc": "+30 Éter máx. e +25% de regeneração de Éter (20 min)",
	},
	{
		"id": &"assado_ermo",
		"name": "Assado do Ermo",
		"desc": "Carne tosquiada no fogo com pinhões-lume e folhas perfumadas.",
		"result_id": &"assado_ermo",
		"base_candidates": [&"carne_crua", &"carne_bem_passada"],
		"required_ingredients": [&"pinhao_lume", &"folha"],
		"buff_name": "Garras Afiadas",
		"buff_desc": "+10% de dano e +5% de velocidade de corrida (20 min)",
	},
	{
		"id": &"caldo_revigorante",
		"name": "Caldo Revigorante de Rinolito",
		"desc": "Caldo lento de tutano de ossos e carne com ervas.",
		"result_id": &"caldo_revigorante",
		"base_candidates": [&"carne_crua", &"ossos"],
		"required_ingredients": [&"ossos", &"erva"],
		"buff_name": "Postura de Pedra",
		"buff_desc": "+25 de Postura máx. e +15% de recuperação de postura (20 min)",
	},
	{
		"id": &"banquete_viagem",
		"name": "Banquete de Viagem com Pinhão",
		"desc": "Mistura energética de pinhões-lume, mel silvestre e frutinhas.",
		"result_id": &"banquete_viagem",
		"base_candidates": [&"pinhao_lume", &"carne_crua"],
		"required_ingredients": [&"mel", &"frutinha"],
		"buff_name": "Passo Leve",
		"buff_desc": "+15 kg de carga e +10% de velocidade de movimento (20 min)",
	},
]

## Lista de materiais que servem como Base (Carnes, Peixes e Sementes densas)
const VALID_BASES: Array[StringName] = [
	&"carne_crua", &"carne_mal_passada", &"carne_bem_passada",
	&"peixe_lambari", &"peixe_traira", &"peixe_dourado",
	&"pinhao_lume"
]

## Lista de materiais aceitos como Acompanhamentos
const VALID_SIDES: Array[StringName] = [
	&"erva", &"frutinha", &"folha", &"mel", &"pinhao_lume", &"ossos",
	&"cannabis_sativa", &"cannabis_indica"
]

## Avalia a combinação selecionada e retorna a receita correspondente
static func evaluate_recipe(base_id: StringName, ingredient_ids: Array[StringName]) -> Dictionary:
	if base_id.is_empty():
		return {}

	# Testa receitas canônicas
	for r in RECIPES:
		var base_match: bool = false
		for b in r.base_candidates:
			if b == base_id:
				base_match = true
				break
		if not base_match:
			continue

		# Verifica se todos os ingredientes requeridos estão presentes
		var reqs: Array = r.required_ingredients.duplicate()
		var available: Array = ingredient_ids.duplicate()
		var all_reqs_met := true

		for req in reqs:
			var idx := available.find(req)
			if idx != -1:
				available.remove_at(idx)
			else:
				all_reqs_met = false
				break

		if all_reqs_met:
			return r

	# Se a base for válida e houver pelo menos 1 acompanhamento válido, gera Ensopado Campeiro improvisado
	if VALID_BASES.has(base_id) and not ingredient_ids.is_empty():
		return {
			"id": &"ensopado_campeiro",
			"name": "Ensopado Campeiro",
			"desc": "Ensopado rústico preparado com o que havia na mochila.",
			"result_id": &"ensopado_campeiro",
			"buff_name": "Nutrição Básica",
			"buff_desc": "+10 Vigor máx. e +10% de regeneração de Vigor (15 min)"
		}

	return {}

## Calcula a qualidade resultante da refeição (1★ a 5★)
static func calculate_quality(base_stack: Dictionary, ingredient_stacks: Array) -> int:
	var base_q: float = float(base_stack.get("quality", 1))
	if ingredient_stacks.is_empty():
		return clampi(roundi(base_q), 1, 5)

	var ingr_sum: float = 0.0
	for s in ingredient_stacks:
		ingr_sum += float(s.get("quality", 1))
	var ingr_avg: float = ingr_sum / float(ingredient_stacks.size())

	# Base tem peso de 40%, acompanhamentos têm peso de 60%
	var final_q: float = (base_q * 0.4) + (ingr_avg * 0.6)
	return clampi(roundi(final_q), 1, 5)

## Extrai e consolida traits relevantes dos ingredientes
static func combine_traits(base_stack: Dictionary, ingredient_stacks: Array) -> Array[StringName]:
	var result_traits: Array[StringName] = []
	var all_traits: Array = base_stack.get("traits", []).duplicate()
	for s in ingredient_stacks:
		for t in s.get("traits", []):
			all_traits.append(t)

	for t in all_traits:
		var st := StringName(t)
		if not result_traits.has(st):
			result_traits.append(st)

	result_traits.sort()
	return result_traits

## Executa o cozimento consumindo os itens da mochila e entregando o prato
static func cook(inventory: _InventoryComponent, base_stack: Dictionary, ingredient_stacks: Array) -> Dictionary:
	if inventory == null or base_stack.is_empty() or ingredient_stacks.is_empty():
		return {"success": false, "reason": "Ingredientes insuficientes"}

	var base_id := StringName(base_stack.get("id", &""))
	var ingr_ids: Array[StringName] = []
	for s in ingredient_stacks:
		ingr_ids.append(StringName(s.get("id", &"")))

	var recipe := evaluate_recipe(base_id, ingr_ids)
	if recipe.is_empty():
		return {"success": false, "reason": "Combinação inválida de ingredientes"}

	# Valida disponibilidade
	if int(base_stack.get("amount", 0)) < 1:
		return {"success": false, "reason": "Base indisponível"}

	for s in ingredient_stacks:
		if int(s.get("amount", 0)) < 1:
			return {"success": false, "reason": "Ingrediente indisponível"}

	# Consome 1 unidade da base
	if not inventory.consume_stack(base_stack, 1):
		return {"success": false, "reason": "Erro ao consumir base"}

	# Consome 1 unidade de cada acompanhamento
	for s in ingredient_stacks:
		inventory.consume_stack(s, 1)

	var result_id: StringName = recipe.get("result_id", &"ensopado_campeiro")
	var final_quality: int = calculate_quality(base_stack, ingredient_stacks)
	var final_traits: Array[StringName] = combine_traits(base_stack, ingredient_stacks)

	inventory.add_material(result_id, 1, final_quality, final_traits)
	EventBusAutoload.report(inventory.get_parent(), &"cozinha", {"result": String(result_id), "quality": final_quality})

	return {
		"success": true,
		"result_id": result_id,
		"recipe_name": recipe.get("name", "Prato Preparado"),
		"quality": final_quality,
		"traits": final_traits,
		"buff_name": recipe.get("buff_name", ""),
		"buff_desc": recipe.get("buff_desc", "")
	}
