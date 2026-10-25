class_name WorldBounds
extends RefCounted

## Tamanho do mundo num lugar só: o terreno vai de -HALF a +HALF em X e Z.
## Spawners usam frações de HALF em vez de números soltos (o mapa cresceu de 180 para 360 m).

const HALF: float = 180.0
const VALLEY_HALF: float = 180.0
## Escala estendida para mundo aberto (3 km de extensão total)
const EXTENDED_HALF: float = 1500.0

## Ativa limites estendidos de mundo aberto para travessias e montarias longas
static var open_world_enabled: bool = false

## Retorna o limite de meia-largura atual (vale original ou mundo aberto)
static func get_half() -> float:
	return EXTENDED_HALF if open_world_enabled else VALLEY_HALF

## true se (x, z) está dentro do mapa com a margem dada
static func inside(x: float, z: float, margin: float = 0.0) -> bool:
	var h: float = get_half()
	return absf(x) <= h - margin and absf(z) <= h - margin
