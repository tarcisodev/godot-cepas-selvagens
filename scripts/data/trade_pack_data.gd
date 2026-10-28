class_name TradePackData
extends Resource

## Fardo Comercial Regional para Transporte de Carga e Rotas Comerciais (GDD-05 §2, §5; GDD-11; GDD-08 §6).
## Produzido nos entrepostos dos assentamentos e transportado fisicamente pelo jogador ou montaria
## pelas estradas do vale. Gera lucro proporcional à distância percorrida e risco da rota.

const DISPLAY_NAMES: Dictionary = {
	&"fardo_pescado": "Fardo de Pescado Salgado e Óleo Purificado",
	&"fardo_madeira_nobre": "Fardo de Madeira da Serra e Resina",
	&"fardo_astral": "Fardo de Quartzo-Lume e Essência Celeste",
	&"fardo_manufatura": "Fardo de Ferramentas de Forja e Refeições"
}

const NATIVE_ORIGINS: Dictionary = {
	&"fardo_pescado": &"porto_bruma",
	&"fardo_madeira_nobre": &"vigia_norte",
	&"fardo_astral": &"santuario_astral",
	&"fardo_manufatura": &"vila_esperanca"
}

const BASE_BUY_PRICES: Dictionary = {
	&"fardo_pescado": 25,
	&"fardo_madeira_nobre": 25,
	&"fardo_astral": 30,
	&"fardo_manufatura": 20
}

@export var id: StringName = &"fardo_pescado"
@export var pack_name: String = "Fardo Comercial"
@export var origin_settlement_id: StringName = &"porto_bruma"
@export var origin_pos: Vector3 = Vector3.ZERO
@export var base_buy_price: int = 25
@export var weight: float = 18.0 ## Peso que impõe -15% de velocidade e bloqueia Fast Travel
@export var quality: int = 1 ## 1★ a 3★ (qualidade superior derivada de insumos raros)
@export var traits: Array[StringName] = []
@export var created_at_msec: int = -1

func _init(p_id: StringName = &"fardo_pescado", p_origin_id: StringName = &"", p_pos: Vector3 = Vector3.ZERO, p_quality: int = 1) -> void:
	id = p_id
	origin_settlement_id = p_origin_id if not p_origin_id.is_empty() else NATIVE_ORIGINS.get(p_id, &"vila_esperanca")
	origin_pos = p_pos
	pack_name = DISPLAY_NAMES.get(p_id, "Fardo Comercial Regional")
	base_buy_price = BASE_BUY_PRICES.get(p_id, 25)
	quality = clampi(p_quality, 1, 3)
	created_at_msec = Time.get_ticks_msec()
	
	if quality >= 2:
		traits.append(&"selecionado")
	if quality >= 3:
		traits.append(&"fino")

## Calcula o valor de liquidação no assentamento de entrega com base na distância real percorrida
## e no multiplicador de oferta/demanda local.
func calculate_sale_value(destination_id: StringName, current_dest_pos: Vector3, demand_mult: float = 1.0) -> int:
	# Se for devolvido ao mesmo assentamento de origem: devolução com perda de taxa (80% do valor)
	if destination_id == origin_settlement_id:
		return maxi(1, int(float(base_buy_price) * 0.8))
	
	var dist := origin_pos.distance_to(current_dest_pos)
	# Fator de distância: ~0.25 $S por metro de distância percorrida no mapa de 360m
	var distance_bonus := dist * 0.25
	# Bônus de qualidade (1.0x para 1★, 1.25x para 2★, 1.5x para 3★)
	var q_mult: float = 1.0 + (float(quality - 1) * 0.25)
	
	var raw_value := (float(base_buy_price) + distance_bonus) * demand_mult * q_mult
	return maxi(base_buy_price + 5, int(roundf(raw_value)))

## Calcula o lucro líquido estimado dado um preço de venda
func calculate_profit(destination_id: StringName, current_dest_pos: Vector3, demand_mult: float = 1.0) -> int:
	var sale_val := calculate_sale_value(destination_id, current_dest_pos, demand_mult)
	return sale_val - base_buy_price

## Serialização para SaveGame
func to_dict() -> Dictionary:
	return {
		"id": String(id),
		"pack_name": pack_name,
		"origin_settlement_id": String(origin_settlement_id),
		"origin_pos": [origin_pos.x, origin_pos.y, origin_pos.z],
		"base_buy_price": base_buy_price,
		"weight": weight,
		"quality": quality,
		"traits": traits.duplicate(),
		"created_at_msec": created_at_msec
	}

static func from_dict(d: Dictionary) -> Resource:
	var script = load("res://scripts/data/trade_pack_data.gd")
	var pack = script.new(
		StringName(d.get("id", "fardo_pescado")),
		StringName(d.get("origin_settlement_id", "")),
		Vector3.ZERO,
		int(d.get("quality", 1))
	)
	pack.pack_name = str(d.get("pack_name", pack.pack_name))
	var p: Array = d.get("origin_pos", [0, 0, 0])
	if p.size() >= 3:
		pack.origin_pos = Vector3(float(p[0]), float(p[1]), float(p[2]))
	pack.base_buy_price = int(d.get("base_buy_price", pack.base_buy_price))
	pack.weight = float(d.get("weight", pack.weight))
	pack.created_at_msec = int(d.get("created_at_msec", pack.created_at_msec))
	if d.has("traits") and d["traits"] is Array:
		pack.traits.clear()
		for t in d["traits"]:
			pack.traits.append(StringName(t))
	return pack
