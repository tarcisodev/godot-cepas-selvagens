class_name WorldBounds
extends RefCounted

## Tamanho do mundo num lugar só: o terreno vai de -HALF a +HALF em X e Z.
## Spawners usam frações de HALF em vez de números soltos (o mapa cresceu de 180 para 360 m).

const HALF: float = 180.0

## true se (x, z) está dentro do mapa com a margem dada
static func inside(x: float, z: float, margin: float = 0.0) -> bool:
	return absf(x) <= HALF - margin and absf(z) <= HALF - margin
