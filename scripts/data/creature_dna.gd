class_name CreatureDNA
extends Resource

## DNA de criatura (GDD-09 §2): espécie + alelos do GDD-04 + cores. Determinístico pela seed,
## pequeno e serializável (mesmo bicho no cliente e no servidor, ADR-0002).
## O corpo é montado por CreatureBody a partir deste DNA.

enum Plan { QUADRUPED, BIRD, FISH }
enum Species { TROTADOR, PLANADOR, RAIA, SALTARELO, LAMBARI, TRAIRA, DOURADO }

## Tabela das espécies do slice: plano de corpo, tamanho máximo (m), cores e proporções
const SPECIES: Dictionary = {
	Species.TROTADOR: {
		"name": "Trotador", "plan": Plan.QUADRUPED, "size": 1.7,
		"color": Color(0.55, 0.38, 0.24), "belly": Color(0.86, 0.78, 0.64),
		"leg": 0.95, "neck": 0.7, "body": Vector3(0.62, 0.62, 1.55), "tail": 0.55, "ears": 0.22,
	},
	Species.SALTARELO: {
		"name": "Saltarelo", "plan": Plan.QUADRUPED, "size": 0.45,
		"color": Color(0.62, 0.55, 0.47), "belly": Color(0.92, 0.9, 0.85),
		"leg": 0.35, "neck": 0.1, "body": Vector3(0.55, 0.55, 0.85), "tail": 0.18, "ears": 0.55,
	},
	Species.PLANADOR: {
		"name": "Planador-de-Penacho", "plan": Plan.BIRD, "size": 2.2,
		"color": Color(0.26, 0.42, 0.62), "belly": Color(0.9, 0.84, 0.66),
		"wing": 4.2, "neck": 0.6, "body": Vector3(0.95, 0.85, 1.9), "tail": 1.0,
	},
	Species.RAIA: {
		"name": "Raia-do-Rio", "plan": Plan.FISH, "size": 1.8,
		"color": Color(0.25, 0.45, 0.48), "belly": Color(0.85, 0.88, 0.86),
		"body": Vector3(1.8, 0.28, 1.4), "tail": 1.2, "wide": true,
	},
	Species.LAMBARI: {
		"name": "Lambari-Brilho", "plan": Plan.FISH, "size": 0.32,
		"color": Color(0.7, 0.75, 0.82), "belly": Color(0.95, 0.95, 0.9),
		"body": Vector3(0.3, 0.42, 1.0), "tail": 0.35, "wide": false,
		"fin": Color(0.9, 0.42, 0.22), "stripe": Color(0.85, 0.95, 1.0),
	},
	# Peixes de pesca (GDD-10 §8): Traíra fica no fundo dos remansos, Dourado no poço da cachoeira
	Species.TRAIRA: {
		"name": "Traíra-do-Remanso", "plan": Plan.FISH, "size": 0.62,
		"color": Color(0.32, 0.36, 0.22), "belly": Color(0.78, 0.74, 0.55),
		"body": Vector3(0.22, 0.24, 1.0), "tail": 0.28, "wide": false,
		"fin": Color(0.25, 0.28, 0.16), "stripe": Color(0.18, 0.2, 0.12),
	},
	Species.DOURADO: {
		"name": "Dourado-da-Cachoeira", "plan": Plan.FISH, "size": 0.95,
		"color": Color(0.93, 0.66, 0.18), "belly": Color(0.98, 0.9, 0.6),
		"body": Vector3(0.26, 0.36, 1.0), "tail": 0.32, "wide": false,
		"fin": Color(0.95, 0.4, 0.12),
	},
}

@export var species: Species = Species.TROTADOR
@export var dna_seed: int = 0
## Alelos (GDD-04 §1): "porte" (T/t, incompleta), "chifre" (C/c, dominante), "padrao" (P/p, dominante).
## "*" = mutação (3% por alelo): cor iridescente e pintas.
@export var alleles: Dictionary = {"porte": ["T", "t"], "chifre": ["c", "c"], "padrao": ["p", "p"]}
@export var base_color: Color = Color(0.55, 0.38, 0.24)
@export var belly_color: Color = Color(0.86, 0.78, 0.64)

static func randomized(p_species: Species, p_seed: int) -> CreatureDNA:
	var rng := RandomNumberGenerator.new()
	rng.seed = p_seed
	var d := CreatureDNA.new()
	d.species = p_species
	d.dna_seed = p_seed
	d.alleles = {
		"porte": [_allele(rng, "T", "t", 0.55), _allele(rng, "T", "t", 0.55)],
		"chifre": [_allele(rng, "C", "c", 0.45), _allele(rng, "C", "c", 0.45)],
		"padrao": [_allele(rng, "P", "p", 0.4), _allele(rng, "P", "p", 0.4)],
	}
	var info: Dictionary = SPECIES[p_species]
	d.base_color = _jitter(rng, info["color"], 0.08)
	d.belly_color = _jitter(rng, info["belly"], 0.04)
	return d

## Cruza dois DNAs (GDD-04): cada filho herda um alelo de cada pai, com 3% de mutação
static func cross(a: CreatureDNA, b: CreatureDNA, p_seed: int) -> CreatureDNA:
	var rng := RandomNumberGenerator.new()
	rng.seed = p_seed
	var child := CreatureDNA.new()
	child.species = a.species
	child.dna_seed = p_seed
	for gene in a.alleles:
		var pick: Array = [a.alleles[gene][rng.randi() % 2], b.alleles[gene][rng.randi() % 2]]
		for i in 2:
			if rng.randf() < 0.03:
				pick[i] = "*"
		child.alleles[gene] = pick
	child.base_color = a.base_color.lerp(b.base_color, rng.randf())
	child.belly_color = a.belly_color.lerp(b.belly_color, 0.5)
	return child

func to_dict() -> Dictionary:
	return {"species": int(species), "seed": dna_seed, "alleles": alleles.duplicate(true),
		"base": base_color.to_html(), "belly": belly_color.to_html()}

static func from_dict(d: Dictionary) -> CreatureDNA:
	var out := CreatureDNA.new()
	out.species = int(d.get("species", 0)) as Species
	out.dna_seed = int(d.get("seed", 0))
	var al: Dictionary = d.get("alleles", {})
	for gene in al:
		out.alleles[gene] = Array(al[gene]).map(func(x): return str(x))
	out.base_color = Color.html(str(d.get("base", "8c613d")))
	out.belly_color = Color.html(str(d.get("belly", "dbc7a3")))
	return out

## Montaria: velocidade pelo gene porte (GDD-03 §9.3): TT 100% · Tt 92% · tt 85%
func mount_speed_factor() -> float:
	return {1.0: 1.0, 0.75: 0.92, 0.5: 0.85}.get(size_factor(), 1.0)

func info() -> Dictionary:
	return SPECIES[species]

func plan() -> Plan:
	return info()["plan"]

func species_name() -> String:
	return info()["name"]

## Fração do tamanho máximo: TT 100% · Tt 75% · tt 50% (dominância incompleta)
func size_factor() -> float:
	var big := 0
	for a in alleles.get("porte", []):
		if a == "T" or a == "*":
			big += 1
	return [0.5, 0.75, 1.0][big]

## Tamanho em metros (comprimento do corpo)
func body_size() -> float:
	return float(info()["size"]) * size_factor()

func has_horns() -> bool:
	return _dominant("chifre", "C")

func is_striped() -> bool:
	return _dominant("padrao", "P")

func is_mutant() -> bool:
	for gene in alleles:
		if alleles[gene].has("*"):
			return true
	return false

## Cor final: mutante ganha brilho iridescente
func coat_color() -> Color:
	return base_color.lerp(Color(0.55, 0.85, 0.95), 0.45) if is_mutant() else base_color

func _dominant(gene: String, upper: String) -> bool:
	for a in alleles.get(gene, []):
		if a == upper:
			return true
	return false

static func _allele(rng: RandomNumberGenerator, upper: String, lower: String, p_upper: float) -> String:
	return upper if rng.randf() < p_upper else lower

static func _jitter(rng: RandomNumberGenerator, c: Color, amount: float) -> Color:
	return Color(clampf(c.r + rng.randf_range(-amount, amount), 0, 1), clampf(c.g + rng.randf_range(-amount, amount), 0, 1), clampf(c.b + rng.randf_range(-amount, amount), 0, 1))
