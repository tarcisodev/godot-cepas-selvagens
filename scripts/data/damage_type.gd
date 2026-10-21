class_name DamageType
extends RefCounted

## Os 7 tipos de dano do jogo (conforme GDD-01 §8)
enum Type {
	SLASH,      ## Cortante (físico - bom contra partes macias)
	IMPACT,     ## Impacto (físico - dano em carapaça e quebra de postura)
	PIERCE,     ## Perfurante (físico - perfuração de couraça)
	FIRE,       ## Fogo (elemental - dano contínuo)
	ICE,        ## Gelo (elemental - lentidão e gasto de vigor)
	LIGHTNING,  ## Tempestade/Elétrico (elemental - dano em éter e interrupção)
	NATURE,     ## Natureza (elemental - veneno e corrosão)
	EARTH       ## Terra / Telúrico (magia telúrica)
}

static func to_string_name(type: Type) -> StringName:
	match type:
		Type.SLASH: return &"slash"
		Type.IMPACT: return &"impact"
		Type.PIERCE: return &"pierce"
		Type.FIRE: return &"fire"
		Type.ICE: return &"ice"
		Type.LIGHTNING: return &"lightning"
		Type.NATURE, Type.EARTH: return &"nature"
	return &"impact"
