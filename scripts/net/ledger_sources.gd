class_name LedgerSources
extends RefCounted

const _GatherableResource = preload("res://scripts/gatherable_resource.gd")
const _GatherableSpawner = preload("res://scripts/gatherable_spawner.gd")
const _ForgedItem = preload("res://scripts/data/forged_item.gd")

## Catálogo de fontes do livro-razão (ADR-0009, B41 fase 3). Todo ganho no cliente online roda dentro
## de um bloco `gain(kind, source, corpo)`: o corpo roda aqui como previsão e o que ele deu e gastou vai
## ao servidor num pedido só. O servidor refaz os gastos no livro, confere os ganhos contra o catálogo
## (itens permitidos, teto de quantidade e qualidade, recarga por fonte, teto por hora, distância do
## jogador, valor dado em troca) e só então entrega. O que não cabe é recusado e vai para a auditoria.
##
## Campos de uma fonte (todos opcionais):
## - items: Array de ids, "*" (qualquer material) ou "gather" (o material do tipo de recurso)
## - max_n / max_q / max_items: teto por item, qualidade máxima e quantas pilhas num pedido
## - money / gear: teto de $S e de peças forjadas por pedido
## - per_hour / money_hour: pedidos e $S por hora (por personagem)
## - per_source: [vezes, segundos] por fonte (o mesmo recurso, o mesmo bicho)
## - once: uma vez por personagem por fonte (guardado no save)
## - near: o cliente manda onde está a fonte; precisa estar a essa distância do jogador no servidor
## - seeded: a fonte tem de existir na lista da semente do GatherableSpawner
## - max_total: id -> quanto o jogador pode ter depois do ganho (baú que só completa o kit)
## - ratio / free / needs_give: troca; valor ganho <= ratio × valor dado + free
## - escrow_in / escrow_out: guarda valor num cofre (ordem do mercado, aposta, fardo) e retira depois

const GATHER_SLACK: float = 0.8
const DEFAULT_FREE: int = 50

const KINDS: Dictionary = {
	# Coleta e caça
	&"gather": {"items": "gather", "seeded": true, "near": 12.0, "per_hour": 900},
	&"gather_wild": {"items": "gather", "near": 12.0, "per_hour": 300, "per_source": [6, 20.0]},
	&"pinha": {"items": [&"pinhao_lume"], "max_n": 5, "max_q": 3, "per_hour": 120, "per_source": [1, 60.0]},
	&"skin": {"items": "*", "max_n": 12, "max_q": 5, "per_hour": 600},
	&"part_break": {"items": "*", "max_n": 6, "max_q": 5, "per_hour": 120},
	&"dummy": {"items": "*", "max_n": 6, "max_q": 5, "per_hour": 120},
	&"fishing": {"items": [&"peixe_lambari", &"peixe_traira", &"peixe_dourado"], "max_n": 1, "max_q": 4, "per_hour": 240},
	&"breeding": {"items": "*", "max_n": 4, "max_q": 3, "max_items": 6, "per_hour": 60},
	&"trap_pickup": {"items": [&"armadilha_mola"], "max_n": 1, "max_q": 3, "per_hour": 120},
	&"bait_pickup": {"items": [&"isca_feromonio"], "max_n": 1, "max_q": 3, "per_hour": 120},
	&"nest_steal": {"items": [&"carne_crua"], "max_n": 1, "max_q": 3, "per_hour": 30},
	&"loot_pickup": {"items": "*", "max_n": 1, "max_q": 3, "per_hour": 30},
	# Baús, presentes e marcos
	&"chest": {"items": "*", "max_n": 3, "max_q": 3, "money": 300, "gear": 1, "once": true, "near": 12.0, "per_hour": 30},
	&"supply": {"items": "*", "max_n": 10, "max_q": 1, "max_items": 8, "near": 12.0, "per_hour": 60,
		"max_total": {&"erva": 10, &"pocao": 5, &"mega_pocao": 2, &"carne_mal_passada": 5, &"carne_bem_passada": 5,
			&"carne_torrada": 5, &"cannabis_sativa": 5, &"cannabis_indica": 5}},
	&"npc_gift": {"items": [&"vara_pesca", &"carne_bem_passada", &"laco_captura", &"sedativo_erva", &"mega_pocao"], "max_n": 3, "max_q": 1, "once": true, "per_hour": 10},
	&"marriage": {"items": [&"alianca_votos"], "max_n": 1, "max_q": 3, "max_total": {&"alianca_votos": 1}, "per_hour": 5},
	# Trocas com NPC (dá algo, recebe algo de valor parecido)
	&"compost": {"items": [&"adubo_organico"], "max_n": 1, "max_q": 3, "ratio": 4.0, "needs_give": true, "per_hour": 240},
	&"fish_tank": {"items": [&"oleo_peixe"], "max_n": 2, "max_q": 3, "ratio": 4.0, "needs_give": true, "per_hour": 240},
	&"shop": {"items": "*", "max_n": 1, "max_q": 1, "ratio": 3.0, "needs_give": true, "per_hour": 600},
	&"sale": {"money": 2000, "ratio": 2.5, "needs_give": true, "per_hour": 900},
	&"contract": {"money": 2000, "ratio": 3.5, "needs_give": true, "per_hour": 120},
	&"mission": {"money": 400, "per_hour": 30, "money_hour": 3000},
	&"caravan": {"money": 200, "per_hour": 10},
	# Cofres: entra valor (gasto) e sai depois, nunca mais que ratio × o que entrou
	&"market_place": {"escrow_in": &"market", "needs_give": true, "per_hour": 120},
	&"market_collect": {"items": "*", "max_n": 9999, "max_q": 5, "max_items": 16, "money": 100000, "escrow_out": &"market", "ratio": 3.0, "per_hour": 120},
	&"totem_deposit": {"escrow_in": &"totem", "needs_give": true, "per_hour": 120},
	&"totem_withdraw": {"money": 100000, "escrow_out": &"totem", "ratio": 1.0, "free": 0, "per_hour": 120},
	&"tavern_bet": {"escrow_in": &"tavern", "needs_give": true, "per_hour": 120},
	&"tavern": {"money": 100000, "escrow_out": &"tavern", "ratio": 2.0, "free": 0, "per_hour": 120},
	&"trade_pack": {"escrow_in": &"trade_pack", "needs_give": true, "per_hour": 30},
	&"trade_route": {"money": 600, "escrow_out": &"trade_pack", "ratio": 12.0, "free": 0, "per_hour": 30},
}

## Lista da semente: tipo -> {chave da célula -> [Vector2 posição]}; null = ainda não montada
static var _gather_spots: Variant = null

# ---------------------------------------------------------------- cliente

## Roda `body` como fonte de ganho. No cliente online o que ele der e gastar vira um pedido só ao
## servidor; no host e offline só roda. `at` é onde a fonte está (recurso, baú), para a checagem de distância.
static func gain(kind: StringName, source: String, body: Callable, at: Vector3 = Vector3.INF) -> Variant:
	var ledger := _service()
	if ledger == null:
		return body.call()
	return ledger.gain(kind, source, body, at)

## Chave estável de um objeto do mundo pela posição (décimos de metro no chão)
static func spot_key(pos: Vector3) -> String:
	return "%d:%d" % [roundi(pos.x * 10.0), roundi(pos.z * 10.0)]

static func _service() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("LedgerService") if tree else null

# ---------------------------------------------------------------- servidor

static func is_known(kind: StringName) -> bool:
	return KINDS.has(kind)

static func rule(kind: StringName) -> Dictionary:
	return KINDS.get(kind, {})

## Valor de um material no livro (valor-base × quantidade)
static func material_value(id: StringName, n: int) -> int:
	return maxi(0, MaterialData.of(id).base_value) * maxi(0, n)

## Valor de uma peça forjada (a mesma conta que o Mercado Negro paga)
static func gear_value(item: ForgedItem) -> int:
	if item == null:
		return 0
	var base := 25
	var r: Dictionary = item.recipe()
	if not r.is_empty():
		base = 20 + int(r.get("load", 0.0) * 1.5)
		if item.is_weapon():
			base += 15
	var q_mult: float = _ForgedItem.QUALITY_MULT[clampi(item.quality, 1, 5)]
	return maxi(15, int(float(base) * q_mult + float(item.traits.size() * 5)))

## Valor total do livro: $S + materiais + peças
static func book_value(inv: InventoryComponent, wallet: WalletComponent) -> int:
	var v := wallet.money
	for s in inv.stacks:
		v += material_value(s.id, int(s.amount))
	for it in inv.items:
		v += gear_value(it)
	return v

## Confere o que o pedido quer ganhar contra a regra da fonte. Devolve "" se cabe, senão o motivo.
## `gains` = {"items": [{id, n, q, traits}], "money": int, "gear": [ForgedItem]}
static func check_gains(kind: StringName, gains: Dictionary, given: int, inv: InventoryComponent, escrow: int = -1) -> String:
	var r := rule(kind)
	var items: Array = gains.get("items", [])
	var money := int(gains.get("money", 0))
	var gear: Array = gains.get("gear", [])
	if money < 0:
		return "dinheiro_negativo"
	if money > int(r.get("money", 0)):
		return "dinheiro_acima_do_teto"
	if gear.size() > int(r.get("gear", 0)):
		return "peca_nao_permitida"
	for it in gear:
		if not (it is ForgedItem) or it.quality < 1 or it.quality > 5:
			return "peca_invalida"
	if items.size() > int(r.get("max_items", 4)):
		return "itens_demais"
	var allowed: Variant = r.get("items", [])
	var totals: Dictionary = {}
	for e in items:
		var id := StringName(str(e.get("id", "")))
		var n := int(e.get("n", 0))
		var q := int(e.get("q", 1))
		if id.is_empty() or n <= 0:
			return "item_invalido"
		if allowed is String and allowed == "gather":
			var cfg := gather_config(id)
			if cfg.is_empty():
				return "item_fora_da_fonte"
			if n > int(cfg.get("max", 1)) or q > MaterialData.of(id).max_gather_quality:
				return "acima_do_teto"
		else:
			if not (allowed is String and allowed == "*") and not (allowed is Array and allowed.has(id)):
				return "item_fora_da_fonte"
			if n > int(r.get("max_n", 1)) or q > int(r.get("max_q", 1)):
				return "acima_do_teto"
		if q < 1:
			return "item_invalido"
		var traits: Variant = e.get("traits", [])
		if not (traits is Array) or traits.size() > 6:
			return "item_invalido"
		totals[id] = int(totals.get(id, 0)) + n
	var max_total: Dictionary = r.get("max_total", {})
	for id in totals:
		if max_total.has(id) and inv.get_material_count(id) + int(totals[id]) > int(max_total[id]):
			return "acima_do_total"
	# Troca e cofre: o valor ganho não passa do que foi dado (ou guardado)
	var gained := money
	for e in items:
		gained += material_value(StringName(str(e.id)), int(e.n))
	for it in gear:
		gained += gear_value(it)
	if bool(r.get("needs_give", false)) and given <= 0:
		return "troca_sem_pagamento"
	if r.has("escrow_out"):
		if gained > 0 and float(gained) > float(r.get("ratio", 1.0)) * float(maxi(0, escrow)) + float(r.get("free", 0)):
			return "acima_do_cofre"
	elif r.has("ratio"):
		if float(gained) > float(r.ratio) * float(given) + float(r.get("free", DEFAULT_FREE)):
			return "valor_acima_da_troca"
	return ""

## Quanto o ganho tira do cofre (valor / ratio)
static func escrow_cost(kind: StringName, gains: Dictionary) -> int:
	var r := rule(kind)
	var gained := int(gains.get("money", 0))
	for e in gains.get("items", []):
		gained += material_value(StringName(str(e.id)), int(e.n))
	for it in gains.get("gear", []):
		gained += gear_value(it)
	return ceili(float(gained) / maxf(0.01, float(r.get("ratio", 1.0))))

# ---------------------------------------------------------------- recursos coletáveis

## Config do tipo de recurso que dá o material `id` ({} se nenhum dá)
static func gather_config(id: StringName) -> Dictionary:
	for t in _GatherableResource.TYPE_CONFIG:
		if _GatherableResource.TYPE_CONFIG[t].id == id:
			return _GatherableResource.TYPE_CONFIG[t]
	return {}

## Quantas coletas o mesmo recurso aguenta e em quanto tempo volta (com folga para o relógio)
static func gather_limit(id: StringName) -> Array:
	var cfg := gather_config(id)
	var respawn := float(cfg.get("respawn", 30.0))
	if respawn <= 0.0:
		respawn = 3600.0
	return [int(cfg.get("hits", 1)), respawn * GATHER_SLACK]

## Monta a lista da semente rodando o GatherableSpawner sem criar nós, com o relevo do servidor
static func build_gather_spots(landscape: Node) -> void:
	var sp = _GatherableSpawner.new()
	sp.landscape = landscape
	sp.dry_run = true
	sp.spawn_all_resources_seeded()
	var spots := {}
	for s in sp.spots:
		var id: StringName = _GatherableResource.TYPE_CONFIG[s.type].id
		var cell := _cell(s.pos)
		if not spots.has(id):
			spots[id] = {}
		if not spots[id].has(cell):
			spots[id][cell] = []
		spots[id][cell].append(Vector2(s.pos.x, s.pos.z))
	sp.free()
	_gather_spots = spots

static func clear_gather_spots() -> void:
	_gather_spots = null

static func has_gather_spots() -> bool:
	return _gather_spots != null

## O material `id` nasce pela semente perto de `at`? (meio metro de folga)
static func is_seeded_spot(id: StringName, at: Vector3) -> bool:
	if _gather_spots == null:
		return true
	var by_cell: Dictionary = _gather_spots.get(id, {})
	var p := Vector2(at.x, at.z)
	var c := _cell(at)
	for dx in [-1, 0, 1]:
		for dz in [-1, 0, 1]:
			for q in by_cell.get(Vector2i(c.x + dx, c.y + dz), []):
				if (q as Vector2).distance_to(p) <= 0.5:
					return true
	return false

static func _cell(pos: Vector3) -> Vector2i:
	return Vector2i(floori(pos.x / 4.0), floori(pos.z / 4.0))
