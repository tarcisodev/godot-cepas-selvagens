class_name ArmorAbilities
extends RefCounted

## Habilidades de armadura (GDD-12 §6.3): uma por família × encaixe, mais as que uma parte de
## criatura no núcleo dá (chifre de Rinolito → Investida). Teclas: 4 cabeça · 5 peito · R botas.
## `pool` paga `cost`; `duration` = quanto o efeito dura (0 = instantâneo).

const ABILITIES: Dictionary = {
	# Cabeça
	&"foco": {"name": "Foco", "icon": "🧘", "pool": &"", "cost": 0.0, "cooldown": 20.0, "duration": 5.0,
		"desc": "Éter regenera em dobro por 5 s"},
	&"faro": {"name": "Faro", "icon": "👃", "pool": &"vigor", "cost": 10.0, "cooldown": 24.0, "duration": 8.0,
		"desc": "+20% de dano por 8 s"},
	&"brado": {"name": "Brado", "icon": "📣", "pool": &"vigor", "cost": 15.0, "cooldown": 25.0, "duration": 6.0,
		"desc": "Atrai os monstros a 10 m e +30% Postura por 6 s"},
	&"investida": {"name": "Investida", "icon": "🦏", "pool": &"vigor", "cost": 15.0, "cooldown": 12.0, "duration": 0.0,
		"desc": "Avança 7 m de chifre baixo: 30 de impacto, 35 de Postura"},
	# Peito
	&"veu": {"name": "Véu", "icon": "🫧", "pool": &"ether", "cost": 30.0, "cooldown": 22.0, "duration": 6.0,
		"desc": "Escudo de Éter que absorve 40 de dano por 6 s"},
	&"esquivo": {"name": "Esquivo", "icon": "💨", "pool": &"", "cost": 0.0, "cooldown": 15.0, "duration": 6.0,
		"desc": "Por 6 s a próxima esquiva sai sem custo e com i-frames de 0,45 s"},
	&"firmeza": {"name": "Firmeza", "icon": "🗿", "pool": &"vigor", "cost": 20.0, "cooldown": 25.0, "duration": 3.0,
		"desc": "3 s de super armor e −30% de dano"},
	# Botas
	&"rajada": {"name": "Rajada", "icon": "🌬️", "pool": &"ether", "cost": 20.0, "cooldown": 10.0, "duration": 0.0,
		"desc": "Avanço de 6 m que atravessa inimigos"},
	&"disparada": {"name": "Disparada", "icon": "🏃", "pool": &"vigor", "cost": 15.0, "cooldown": 14.0, "duration": 4.0,
		"desc": "+40% de velocidade por 4 s"},
	&"pisao": {"name": "Pisão", "icon": "🦶", "pool": &"vigor", "cost": 20.0, "cooldown": 12.0, "duration": 0.0,
		"desc": "Golpe em área de 3,5 m: 18 de impacto, 40 de Postura"},
}

const BY_SLOT: Dictionary = {
	ForgedItem.Slot.HEAD: {&"pano": &"foco", &"couro": &"faro", &"ferro": &"brado"},
	ForgedItem.Slot.BODY: {&"pano": &"veu", &"couro": &"esquivo", &"ferro": &"firmeza"},
	ForgedItem.Slot.FEET: {&"pano": &"rajada", &"couro": &"disparada", &"ferro": &"pisao"},
}

## Tecla de cada encaixe
const SLOT_KEYS: Dictionary = {ForgedItem.Slot.HEAD: KEY_4, ForgedItem.Slot.BODY: KEY_5, ForgedItem.Slot.FEET: KEY_R}
const KEY_NAMES: Dictionary = {ForgedItem.Slot.HEAD: "4", ForgedItem.Slot.BODY: "5", ForgedItem.Slot.FEET: "R"}

static func for_slot(slot: int, family: StringName) -> StringName:
	return BY_SLOT.get(slot, {}).get(family, &"")

static func info(id: StringName) -> Dictionary:
	return ABILITIES.get(id, {})
