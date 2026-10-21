class_name CharacterDNA
extends Resource

## DNA de um humanoide procedural (B09 / ADR-0004).
## Tudo o que o ProceduralCharacterBuilder precisa para gerar o mesmo personagem em qualquer máquina:
## o mesmo DNA (ou a mesma seed em `randomized`) dá sempre o mesmo corpo, rosto e roupa.

## Novos estilos entram sempre no fim: o .tres e o save guardam o número.
enum HairStyle { BALD, BUZZ, SHORT, PONYTAIL, LONG, MOHAWK, TOPKNOT, MANE }
enum Beard { NONE, MUSTACHE, GOATEE, FULL }

const SKIN_TONES: Array[Color] = [
	Color("#f6d7c3"), Color("#eac0a0"), Color("#d9a77f"), Color("#c68a62"),
	Color("#a86f4c"), Color("#8a5a3c"), Color("#6b432c"), Color("#4a2f20"),
]
const HAIR_COLORS: Array[Color] = [
	Color("#1d1612"), Color("#3b2a1f"), Color("#5a3b26"), Color("#8a5a33"),
	Color("#b98a4e"), Color("#d8b878"), Color("#a33b1f"), Color("#7a7a78"), Color("#d9d6cf"),
]
const EYE_COLORS: Array[Color] = [
	Color("#3d2a1c"), Color("#5b3b20"), Color("#4a6b3a"), Color("#3f5f7a"), Color("#6b6b5a"),
]
## Tecidos rústicos (linho, lã tingida) para camisa e calça.
const CLOTH_COLORS: Array[Color] = [
	Color("#6b4f2e"), Color("#4f5d2f"), Color("#7a2e22"), Color("#2f4a5a"), Color("#8a7a5a"),
	Color("#3f3a35"), Color("#a0763a"), Color("#5a3f5f"), Color("#c9b48a"), Color("#2e3f2a"),
]
## Couros para bota e cinto.
const LEATHER_COLORS: Array[Color] = [
	Color("#4a3020"), Color("#5e3d24"), Color("#3a2a1e"), Color("#2a2420"), Color("#6e4a2c"),
]

@export var dna_seed: int = 0

@export_group("Corpo")
## Escala geral (1.0 = manequim UAL, ~1,8 m).
@export_range(0.85, 1.12) var stature: float = 1.0
## 0 = traços masculinos (ombro largo), 1 = femininos (quadril largo, cintura fina, busto).
@export_range(0.0, 1.0) var femininity: float = 0.0
@export_range(0.0, 1.0) var mass: float = 0.35
@export_range(0.0, 1.0) var muscle: float = 0.4
@export_range(0.88, 1.12) var leg_length: float = 1.0
@export_range(0.88, 1.12) var torso_length: float = 1.0
@export_range(0.9, 1.1) var arm_length: float = 1.0
@export_range(0.8, 1.25) var neck_length: float = 1.0

@export_group("Cabeça")
@export_range(0.88, 1.15) var head_size: float = 1.0
@export_range(0.0, 1.0) var jaw_width: float = 0.5
@export_range(0.0, 1.0) var nose_size: float = 0.5
@export var skin_color: Color = SKIN_TONES[2]
@export var eye_color: Color = EYE_COLORS[0]
@export var hair_style: HairStyle = HairStyle.SHORT
@export var hair_color: Color = HAIR_COLORS[1]
## Rabo de cavalo, cabelo longo e juba: 0 = no ombro, 1 = no meio das costas.
@export_range(0.0, 1.0) var hair_length: float = 0.4
@export var beard: Beard = Beard.NONE
## Barba cheia e cavanhaque: 0 = rente ao queixo, 1 = descendo até o peito.
@export_range(0.0, 1.0) var beard_length: float = 0.0

@export_group("Roupa")
@export var shirt_color: Color = CLOTH_COLORS[0]
@export var pants_color: Color = CLOTH_COLORS[5]
@export var boots_color: Color = LEATHER_COLORS[0]
@export var belt_color: Color = LEATHER_COLORS[2]
## 0 = sem manga, 0.5 = até o cotovelo, 1 = até o punho.
@export_range(0.0, 1.0) var sleeve_length: float = 0.8
## 0 = bermuda acima do joelho, 1 = até o tornozelo.
@export_range(0.0, 1.0) var pants_length: float = 1.0
## 0 = sapato baixo, 1 = bota até perto do joelho.
@export_range(0.0, 1.0) var boot_height: float = 0.4
@export var gloves: bool = false

## Sorteia um personagem completo e coerente a partir da seed.
static func randomized(p_seed: int) -> CharacterDNA:
	var rng := RandomNumberGenerator.new()
	rng.seed = p_seed
	var dna := CharacterDNA.new()
	dna.dna_seed = p_seed

	var feminine := rng.randf() < 0.5
	dna.femininity = clampf((0.85 if feminine else 0.1) + rng.randfn(0.0, 0.1), 0.0, 1.0)
	dna.stature = clampf(rng.randfn(1.0 - 0.05 * dna.femininity, 0.04), 0.86, 1.11)
	dna.mass = clampf(rng.randfn(0.35, 0.22), 0.0, 1.0)
	dna.muscle = clampf(rng.randfn(0.45 - 0.2 * dna.femininity, 0.2), 0.0, 1.0)
	dna.leg_length = clampf(rng.randfn(1.0, 0.04), 0.89, 1.11)
	dna.torso_length = clampf(rng.randfn(1.0, 0.035), 0.9, 1.1)
	dna.arm_length = clampf(rng.randfn(1.0, 0.03), 0.92, 1.08)
	dna.neck_length = clampf(rng.randfn(1.0 + 0.05 * dna.femininity, 0.08), 0.82, 1.22)

	dna.head_size = clampf(rng.randfn(1.0, 0.04), 0.9, 1.12)
	dna.jaw_width = clampf(rng.randfn(0.6 - 0.35 * dna.femininity, 0.15), 0.0, 1.0)
	dna.nose_size = rng.randf()
	dna.skin_color = _pick_blend(rng, SKIN_TONES)
	dna.eye_color = EYE_COLORS[rng.randi_range(0, EYE_COLORS.size() - 1)]
	# Cabelo grisalho/branco é mais raro.
	var hair_index := rng.randi_range(0, HAIR_COLORS.size() - 3) if rng.randf() < 0.85 else rng.randi_range(HAIR_COLORS.size() - 2, HAIR_COLORS.size() - 1)
	dna.hair_color = HAIR_COLORS[hair_index].lerp(Color.BLACK, rng.randf_range(0.0, 0.15))

	var styles: Array[HairStyle] = [HairStyle.BALD, HairStyle.BUZZ, HairStyle.SHORT, HairStyle.PONYTAIL, HairStyle.LONG, HairStyle.MOHAWK, HairStyle.TOPKNOT, HairStyle.MANE]
	var style_weights: PackedFloat32Array = [0.9, 1.4, 2.2, 1.0, 0.8, 0.3, 0.6, 0.4] if not feminine else [0.05, 0.3, 1.2, 2.0, 2.4, 0.2, 1.0, 0.6]
	dna.hair_style = styles[rng.rand_weighted(style_weights)]
	dna.beard = Beard.NONE
	if dna.femininity < 0.4 and rng.randf() < 0.55:
		dna.beard = [Beard.MUSTACHE, Beard.GOATEE, Beard.FULL, Beard.FULL][rng.randi_range(0, 3)]

	dna.shirt_color = _jitter(rng, CLOTH_COLORS[rng.randi_range(0, CLOTH_COLORS.size() - 1)])
	dna.pants_color = _jitter(rng, CLOTH_COLORS[rng.randi_range(0, CLOTH_COLORS.size() - 1)].darkened(0.25))
	dna.boots_color = _jitter(rng, LEATHER_COLORS[rng.randi_range(0, LEATHER_COLORS.size() - 1)])
	dna.belt_color = _jitter(rng, LEATHER_COLORS[rng.randi_range(0, LEATHER_COLORS.size() - 1)].darkened(0.15))
	dna.sleeve_length = [0.0, 0.45, 0.95, 1.0][rng.randi_range(0, 3)]
	dna.pants_length = 1.0 if rng.randf() < 0.8 else 0.0
	dna.boot_height = rng.randf()
	dna.gloves = rng.randf() < 0.25
	# Sorteados por último para não mudar o resto do personagem das seeds antigas.
	dna.hair_length = rng.randf()
	dna.beard_length = rng.randf() * 0.7 if dna.beard == Beard.FULL or dna.beard == Beard.GOATEE else 0.0
	return dna

## Dicionário compacto (cores em hex) para rede e save.
func to_dict() -> Dictionary:
	var data := {}
	for prop in _stored_properties():
		var value: Variant = get(prop)
		data[prop] = value.to_html(false) if value is Color else value
	return data

static func from_dict(data: Dictionary) -> CharacterDNA:
	var dna := CharacterDNA.new()
	for prop in dna._stored_properties():
		if not data.has(prop):
			continue
		# JSON devolve todo número como float; enums, seed e bools voltam ao tipo original.
		var value: Variant = data[prop]
		var current: Variant = dna.get(prop)
		if current is Color:
			value = Color.html(value)
		elif current is int:
			value = int(value)
		elif current is bool:
			value = bool(value)
		dna.set(prop, value)
	return dna

func _stored_properties() -> Array[String]:
	var names: Array[String] = []
	for info in get_property_list():
		if info.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and info.usage & PROPERTY_USAGE_STORAGE:
			names.append(info.name)
	return names

## Tom entre dois vizinhos da paleta (pele contínua, sem degraus).
static func _pick_blend(rng: RandomNumberGenerator, palette: Array[Color]) -> Color:
	var i := rng.randi_range(0, palette.size() - 2)
	return palette[i].lerp(palette[i + 1], rng.randf())

static func _jitter(rng: RandomNumberGenerator, color: Color) -> Color:
	return Color.from_hsv(
		fposmod(color.h + rng.randf_range(-0.03, 0.03), 1.0),
		clampf(color.s * rng.randf_range(0.85, 1.15), 0.0, 1.0),
		clampf(color.v * rng.randf_range(0.85, 1.12), 0.0, 1.0))
