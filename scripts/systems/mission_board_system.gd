class_name MissionBoardSystem
extends Resource

## Sistema Central de Contratos Dinâmicos e Quadro de Missões da Vila (GDD-05 §5, GDD-03, GDD-04, GDD-13).
## Gerencia 4 categorias ricas de contratos:
## 1. Caça Anatômica (partes específicas íntegras)
## 2. Mineração & Forja (reforço e obras)
## 3. Culinária & Taverna (pratos e assados no ponto)
## 4. Reconhecimento & Modo Foto (fotografar espécimes e mutações no vale)

const _MaterialData = preload("res://scripts/data/material_data.gd")
const _WalletComponent = preload("res://scripts/components/wallet_component.gd")
const _MasteryComponent = preload("res://scripts/components/mastery_component.gd")
const _InventoryComponent = preload("res://scripts/components/inventory_component.gd")

enum Category { HUNT, FORGE, COOK, PHOTO }

const CATEGORY_NAMES: Dictionary = {
	Category.HUNT: "Caça Anatômica",
	Category.FORGE: "Mineração & Forja",
	Category.COOK: "Culinária & Taverna",
	Category.PHOTO: "Reconhecimento (Foto)"
}

const CATEGORY_ICONS: Dictionary = {
	Category.HUNT: "🏹",
	Category.FORGE: "⚒️",
	Category.COOK: "🍲",
	Category.PHOTO: "📷"
}

## Catálogo canônico de contratos por categoria
const CONTRACT_TEMPLATES: Dictionary = {
	Category.HUNT: [
		{
			"id_base": "hunt_trotador", "title": "Chifres para o Bastião",
			"client": "Vigias da Muralha", "desc": "Precisamos de chifres galhados intactos para reforçar as paliçadas norte.",
			"target_id": &"chifre_galhado", "target_name": "Chifre Galhado",
			"species": "trotador", "min_amount": 2, "max_amount": 4,
			"reward_base": 45, "rep": 15, "mastery": &"esfola", "xp": 35.0
		},
		{
			"id_base": "hunt_tatu", "title": "Carapaças Couraçadas",
			"client": "Mestre da Forja", "desc": "A armaria necessita de placas rígidas de tatu para forjar escudos de proteção.",
			"target_id": &"placa_carapaca", "target_name": "Carapaça de Tatu",
			"species": "tatu", "min_amount": 2, "max_amount": 3,
			"reward_base": 50, "rep": 15, "mastery": &"esfola", "xp": 30.0
		},
		{
			"id_base": "hunt_planador", "title": "Penachos dos Ventos",
			"client": "Guilda dos Arqueiros", "desc": "Penas aerodinâmicas de planador para estabilização de virotes de caça.",
			"target_id": &"pena_penacho", "target_name": "Pena de Penacho",
			"species": "planador", "min_amount": 3, "max_amount": 5,
			"reward_base": 40, "rep": 12, "mastery": &"esfola", "xp": 25.0
		},
		{
			"id_base": "hunt_lobo", "title": "Presas do Predador",
			"client": "Caçador Veterano", "desc": "Presas pontiagudas de lobo guará para adornos de armas de combate.",
			"target_id": &"presa_lobo", "target_name": "Presa de Lobo",
			"species": "lobo", "min_amount": 2, "max_amount": 4,
			"reward_base": 55, "rep": 20, "mastery": &"esfola", "xp": 40.0
		},
		{
			"id_base": "hunt_rinolito", "title": "Chifre de Titã",
			"client": "Guardiões da Praça", "desc": "O temível Rinolito Ancião ameaça as rotas; traga um chifre pesado como troféu.",
			"target_id": &"chifre_rinolito", "target_name": "Chifre de Rinolito",
			"species": "rinolito", "min_amount": 1, "max_amount": 2,
			"reward_base": 75, "rep": 25, "mastery": &"esfola", "xp": 50.0
		}
	],
	Category.FORGE: [
		{
			"id_base": "forge_ferro", "title": "Lingotes para a Vila",
			"client": "Mestre da Forja", "desc": "Barras de ferro de boa pureza para reforçar os pilares e ferramentas públicas.",
			"target_id": &"barra_ferro", "target_name": "Barra de Ferro",
			"species": "", "min_amount": 3, "max_amount": 6,
			"reward_base": 55, "rep": 18, "mastery": &"forja", "xp": 35.0
		},
		{
			"id_base": "forge_minerio", "title": "Minério dos Morros",
			"client": "Fundição Municipal", "desc": "Remessa de minério de ferro extraído dos veios da serra para a fornalha.",
			"target_id": &"minerio_ferro", "target_name": "Minério de Ferro",
			"species": "", "min_amount": 4, "max_amount": 8,
			"reward_base": 35, "rep": 12, "mastery": &"mineracao", "xp": 25.0
		},
		{
			"id_base": "forge_quartzo", "title": "Luz do Quartzo",
			"client": "Alquimista Botânica", "desc": "Cristais de quartzo-lume para abastecer as lamparinas noturnas da praça.",
			"target_id": &"quartzo_lume", "target_name": "Quartzo-Lume",
			"species": "", "min_amount": 2, "max_amount": 4,
			"reward_base": 50, "rep": 16, "mastery": &"mineracao", "xp": 30.0
		}
	],
	Category.COOK: [
		{
			"id_base": "cook_espeto", "title": "Assado para os Sentinelas",
			"client": "Taverna da Vila", "desc": "Carnes bem passadas no ponto perfeito do espeto para a vigília noturna.",
			"target_id": &"carne_bem_passada", "target_name": "Carne Bem Passada 3★",
			"species": "", "min_amount": 2, "max_amount": 4,
			"reward_base": 40, "rep": 12, "mastery": &"culinaria", "xp": 30.0
		},
		{
			"id_base": "cook_gisado", "title": "Caldeirada dos Caçadores",
			"client": "Estalagem da Colina", "desc": "Porções de Gisado do Caçador com raízes nutritivas para os viajantes.",
			"target_id": &"gisado_cacador", "target_name": "Gisado do Caçador",
			"species": "", "min_amount": 1, "max_amount": 3,
			"reward_base": 65, "rep": 20, "mastery": &"culinaria", "xp": 45.0
		},
		{
			"id_base": "cook_peixe", "title": "Peixe ao Mel da Serra",
			"client": "Chef da Taverna", "desc": "Prato especial de peixe dourado grelhado ao favo de mel silvestre.",
			"target_id": &"peixe_ao_mel", "target_name": "Peixe ao Mel",
			"species": "", "min_amount": 1, "max_amount": 2,
			"reward_base": 60, "rep": 18, "mastery": &"culinaria", "xp": 40.0
		}
	],
	Category.PHOTO: [
		{
			"id_base": "photo_trotador", "title": "Registro do Trotador",
			"client": "Naturalistas do Vale", "desc": "Fotografe um Trotador selvagem em seu habitat com a Câmera [P].",
			"target_id": &"", "target_name": "Foto de Trotador Selvagem",
			"species": "trotador", "min_amount": 1, "max_amount": 1,
			"reward_base": 45, "rep": 15, "mastery": &"", "xp": 20.0
		},
		{
			"id_base": "photo_lobo", "title": "Estudo do Lobo Guará",
			"client": "Academia de Ecologia", "desc": "Fotografe um Lobo Guará patrulhando as encostas da floresta.",
			"target_id": &"", "target_name": "Foto de Lobo Guará",
			"species": "lobo", "min_amount": 1, "max_amount": 1,
			"reward_base": 55, "rep": 20, "mastery": &"", "xp": 25.0
		},
		{
			"id_base": "photo_pinheira", "title": "Pinheira-Lume e Mutação",
			"client": "Herboristas da Vila", "desc": "Fotografe uma árvore Pinheira-Lume exibindo suas pinhas luminescentes.",
			"target_id": &"", "target_name": "Foto de Pinheira-Lume",
			"species": "pinheira", "min_amount": 1, "max_amount": 1,
			"reward_base": 50, "rep": 16, "mastery": &"", "xp": 25.0
		},
		{
			"id_base": "photo_peixe", "title": "Vida Aquática no Rio",
			"client": "Pescadores da Vila", "desc": "Fotografe um peixe ou cardume nadando nas águas cristalinas do rio.",
			"target_id": &"", "target_name": "Foto de Peixe no Rio",
			"species": "peixe", "min_amount": 1, "max_amount": 1,
			"reward_base": 40, "rep": 12, "mastery": &"", "xp": 20.0
		}
	]
}

const MAX_ACTIVE_CONTRACTS: int = 6
## Contrato de Mestre (GDD-19 §6): o dobro do pedido e da paga, só para quem cravou o Marco
## de Trilha do capítulo no Diário do Caçador
const MASTER_CHAPTER: Dictionary = {
	Category.HUNT: &"caca",
	Category.FORGE: &"forja",
	Category.COOK: &"fogao",
	Category.PHOTO: &"andancas",
}
const MASTER_REWARD_MULT: float = 2.5

@export var active_contracts: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()

func _init() -> void:
	_rng.randomize()
	ensure_contracts_filled()

## Preenche os contratos ativos garantindo variedade nas 4 categorias
func ensure_contracts_filled(p_seed: int = 0) -> void:
	if p_seed != 0:
		_rng.seed = p_seed
	while active_contracts.size() < MAX_ACTIVE_CONTRACTS:
		var cat_idx: int = int(active_contracts.size() % Category.size())
		var cat: Category = cat_idx as Category
		# A última vaga do Quadro é sempre um Contrato de Mestre
		var contract := generate_contract(cat, active_contracts.size() == MAX_ACTIVE_CONTRACTS - 1)
		if contract != null and not contract.is_empty():
			active_contracts.append(contract)

## Gera um contrato dinâmico único baseado na categoria
func generate_contract(p_category: Category = Category.HUNT, master: bool = false) -> Dictionary:
	var templates: Array = CONTRACT_TEMPLATES.get(p_category, [])
	if templates.is_empty():
		return {}
	var tmpl: Dictionary = templates[_rng.randi() % templates.size()]
	var amount := _rng.randi_range(tmpl.min_amount, tmpl.max_amount)
	var is_photo: bool = p_category == Category.PHOTO
	if master:
		amount = int(tmpl.max_amount) * 2
	var reward_money: int = int(tmpl.reward_base * (1.0 + 0.35 * (amount - 1)) * (MASTER_REWARD_MULT if master else 1.0))
	var rep_val: int = int(tmpl.rep) * (2 if master else 1)
	var uid := "%s_%d" % [tmpl.id_base, _rng.randi() % 99999]

	return {
		"uid": uid,
		"category": int(p_category),
		"category_name": CATEGORY_NAMES[p_category],
		"category_icon": CATEGORY_ICONS[p_category],
		"title": ("Contrato de Mestre: " if master else "") + tmpl.title,
		"is_master": master,
		"requires_access": String(MASTER_CHAPTER.get(p_category, &"")) if master else "",
		"client": tmpl.client,
		"desc": tmpl.desc,
		"target_id": tmpl.target_id,
		"target_name": tmpl.target_name,
		"species": tmpl.species,
		"amount_needed": amount,
		"amount_current": 0,
		"reward_money": reward_money,
		"reward_rep": rep_val,
		"reward_mastery": tmpl.mastery,
		"reward_xp": tmpl.xp * (2.0 if master else 1.0),
		"is_photo": is_photo,
		"is_completed": false
	}

func _get_inv(p: Node) -> _InventoryComponent:
	if p == null:
		return null
	if "inventory" in p and p.get("inventory") != null:
		return p.get("inventory") as _InventoryComponent
	return p.get_node_or_null("InventoryComponent") as _InventoryComponent

func _get_wallet(p: Node) -> _WalletComponent:
	if p == null:
		return null
	if "wallet" in p and p.get("wallet") != null:
		return p.get("wallet") as _WalletComponent
	return p.get_node_or_null("WalletComponent") as _WalletComponent

func _get_mastery(p: Node) -> _MasteryComponent:
	if p == null:
		return null
	if "mastery" in p and p.get("mastery") != null:
		return p.get("mastery") as _MasteryComponent
	return p.get_node_or_null("MasteryComponent") as _MasteryComponent

## Contrato de Mestre só para quem tem o Marco de Trilha do capítulo (Diário do Caçador)
func has_access(contract: Dictionary, player: Node) -> bool:
	var chapter: String = contract.get("requires_access", "")
	if chapter.is_empty():
		return true
	var diary = player.get_node_or_null("DiaryComponent") if player else null
	return diary != null and diary.has_board_access(StringName(chapter))

## Verifica se o jogador pode cumprir o contrato
func can_deliver(contract: Dictionary, player: Node) -> bool:
	if contract.get("is_completed", false):
		return false
	if not has_access(contract, player):
		return false
	if contract.get("is_photo", false):
		return contract.get("amount_current", 0) >= contract.get("amount_needed", 1)
	
	# Entrega de materiais / comida / minério
	var inv: _InventoryComponent = _get_inv(player)
	if inv == null:
		return false
	var target_id: StringName = contract.get("target_id", &"")
	var needed: int = int(contract.get("amount_needed", 1))
	return inv.get_material_count(target_id) >= needed

## Entrega e cumpre o contrato, pagando dinheiro, reputação e maestria
func deliver_contract(contract: Dictionary, player: Node, city_node: Node = null) -> bool:
	if not can_deliver(contract, player):
		return false

	var needed: int = int(contract.get("amount_needed", 1))
	var is_photo: bool = bool(contract.get("is_photo", false))
	var target_id: StringName = contract.get("target_id", &"")

	# Consome materiais se for entrega física
	if not is_photo and not target_id.is_empty():
		var inv: _InventoryComponent = _get_inv(player)
		if inv:
			if not inv.consume_materials({target_id: needed}):
				return false

	# Paga recompensa em $S
	var money: int = int(contract.get("reward_money", 0))
	var wallet: _WalletComponent = _get_wallet(player)
	if wallet and money > 0:
		wallet.add(money)

	# Adiciona Reputação da Vila
	var rep: int = int(contract.get("reward_rep", 0))
	if city_node and city_node.has_method("add_reputation"):
		city_node.add_reputation(rep)
	elif city_node and "reputation" in city_node:
		city_node.reputation += rep
	elif city_node and city_node.has_meta("reputation"):
		city_node.set_meta("reputation", int(city_node.get_meta("reputation")) + rep)

	# Adiciona XP de Maestria
	var mastery_id: StringName = contract.get("reward_mastery", &"")
	var xp: float = float(contract.get("reward_xp", 0.0))
	var mastery: _MasteryComponent = _get_mastery(player)
	if mastery and not mastery_id.is_empty() and xp > 0.0:
		mastery.add_xp(mastery_id, xp)

	# Notifica player se tiver sinal
	EventBusAutoload.report(player, &"missao", {"title": String(contract.get("title", "")), "money": money})
	if player and player.has_signal("posture_changed"):
		player.posture_changed.emit("📜 Missão Cumprida: %s (+%s)" % [contract.title, _WalletComponent.format(money)])

	# Remove o contrato cumprido e gera um novo
	var idx := active_contracts.find(contract)
	if idx != -1:
		active_contracts.remove_at(idx)
	ensure_contracts_filled()
	return true

## Registra fotografia tirada no Modo Foto e avança contratos de reconhecimento
func record_photo(subject_species: String, _metadata: Dictionary = {}) -> Array[Dictionary]:
	var completed: Array[Dictionary] = []
	for contract in active_contracts:
		if not contract.get("is_photo", false):
			continue
		var target_sp: String = str(contract.get("species", "")).to_lower()
		var photographed_sp: String = subject_species.to_lower()
		
		var match_found := false
		if target_sp == photographed_sp:
			match_found = true
		elif target_sp == "peixe" and (photographed_sp.contains("peixe") or photographed_sp.contains("lambari") or photographed_sp.contains("traira") or photographed_sp.contains("dourado")):
			match_found = true

		if match_found:
			contract["amount_current"] = int(contract.get("amount_current", 0)) + 1
			if contract["amount_current"] >= int(contract.get("amount_needed", 1)):
				contract["is_completed"] = true
				completed.append(contract)
	return completed

func to_array() -> Array:
	return active_contracts.duplicate(true)

func load_from_array(arr: Array) -> void:
	active_contracts.clear()
	for c in arr:
		if c is Dictionary:
			active_contracts.append(c.duplicate(true))
	ensure_contracts_filled()
