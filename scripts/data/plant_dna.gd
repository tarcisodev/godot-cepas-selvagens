class_name PlantDNA
extends Resource

## DNA de planta (GDD-09 §3): tipo + genes visíveis (porte, galhos, cores, pétalas).
## Determinístico pela seed; o corpo é montado por PlantBody.

enum Kind { ARVORE, ARBUSTO, CEPA, COGUMELO }

const KIND_NAMES: Dictionary = {
	Kind.ARVORE: "Árvore-de-Cepa", Kind.ARBUSTO: "Arbusto Florido",
	Kind.CEPA: "Cepa Selvagem", Kind.COGUMELO: "Cogumelo-Lume",
}

@export var kind: Kind = Kind.ARVORE
@export var dna_seed: int = 0
## Porte (GDD-04): TT 100% · Tt 75% · tt 50% da altura máxima do tipo
@export var porte: Array = ["T", "t"]
@export var branches: int = 4
@export var leaf_color: Color = Color(0.3, 0.55, 0.25)
@export var flower_color: Color = Color(0.9, 0.4, 0.5)
@export var petals: int = 5
@export var trunk_color: Color = Color(0.4, 0.28, 0.18)
## Mutante (GDD-10 §4): cor rara e porte maior; nasce mais em solo rico
@export var mutant: bool = false

## Cores raras das plantas mutantes
const MUTANT_HUES: Array[Color] = [Color(0.25, 0.55, 1.0), Color(1.0, 0.85, 0.15), Color(0.95, 0.25, 0.85), Color(0.3, 1.0, 0.85)]

## Semente: herda da mãe (autopolinização), com mutação na chance dada (3% a 12%, GDD-10 §4)
static func seed_of(parent: PlantDNA, p_seed: int, mutation_chance: float) -> PlantDNA:
	var rng := RandomNumberGenerator.new()
	rng.seed = p_seed
	var d: PlantDNA = parent.duplicate()
	d.dna_seed = p_seed
	d.porte = [parent.porte[rng.randi() % 2], parent.porte[rng.randi() % 2]]
	d.branches = clampi(parent.branches + rng.randi_range(-1, 1), 2, 7)
	d.petals = clampi(parent.petals + rng.randi_range(-1, 1), 3, 8)
	d.leaf_color = parent.leaf_color.lerp(Color(rng.randf(), rng.randf(), rng.randf()), 0.04)
	d.mutant = parent.mutant and rng.randf() < 0.5
	if rng.randf() < mutation_chance:
		d.mutant = true
		d.porte[rng.randi() % 2] = "*"
		d.flower_color = MUTANT_HUES[rng.randi() % MUTANT_HUES.size()]
		if d.kind == Kind.CEPA:
			d.leaf_color = d.leaf_color.lerp(d.flower_color, 0.35)
	return d

func to_dict() -> Dictionary:
	return {
		"kind": kind, "seed": dna_seed, "porte": porte, "branches": branches, "petals": petals,
		"leaf": leaf_color.to_html(), "flower": flower_color.to_html(), "trunk": trunk_color.to_html(), "mutant": mutant,
	}

static func from_dict(d: Dictionary) -> PlantDNA:
	var p := PlantDNA.new()
	p.kind = int(d.get("kind", 0)) as Kind
	p.dna_seed = int(d.get("seed", 0))
	p.porte = Array(d.get("porte", ["T", "t"]))
	p.branches = int(d.get("branches", 4))
	p.petals = int(d.get("petals", 5))
	p.leaf_color = Color.html(str(d.get("leaf", "4d8c40")))
	p.flower_color = Color.html(str(d.get("flower", "e66680")))
	p.trunk_color = Color.html(str(d.get("trunk", "664729")))
	p.mutant = bool(d.get("mutant", false))
	return p

static func randomized(p_kind: Kind, p_seed: int) -> PlantDNA:
	var rng := RandomNumberGenerator.new()
	rng.seed = p_seed
	var d := PlantDNA.new()
	d.kind = p_kind
	d.dna_seed = p_seed
	d.porte = ["T" if rng.randf() < 0.6 else "t", "T" if rng.randf() < 0.6 else "t"]
	d.branches = rng.randi_range(3, 6)
	d.petals = rng.randi_range(4, 7)
	var leaf_hues := [Color(0.28, 0.55, 0.22), Color(0.4, 0.62, 0.2), Color(0.22, 0.45, 0.3), Color(0.55, 0.5, 0.2)]
	d.leaf_color = leaf_hues[rng.randi() % leaf_hues.size()].lerp(Color(rng.randf(), rng.randf(), rng.randf()), 0.08)
	var flower_hues := [Color(0.92, 0.35, 0.45), Color(0.95, 0.8, 0.3), Color(0.6, 0.4, 0.9), Color(0.95, 0.95, 0.9), Color(0.95, 0.55, 0.25)]
	d.flower_color = flower_hues[rng.randi() % flower_hues.size()]
	d.trunk_color = Color(0.4, 0.28, 0.18).lerp(Color(0.55, 0.45, 0.35), rng.randf())
	if p_kind == Kind.COGUMELO:
		d.flower_color = [Color(0.3, 0.9, 0.85), Color(0.6, 0.95, 0.4), Color(0.75, 0.5, 1.0)][rng.randi() % 3]
		d.leaf_color = Color(0.85, 0.8, 0.7)
	if p_kind == Kind.CEPA:
		d.leaf_color = [Color(0.25, 0.55, 0.25), Color(0.35, 0.5, 0.2), Color(0.4, 0.3, 0.55)][rng.randi() % 3]
	return d

func size_factor() -> float:
	var big := 0
	for a in porte:
		if a == "T" or a == "*":
			big += 1
	return [0.5, 0.75, 1.0][big] * (1.15 if mutant else 1.0)

func display_name() -> String:
	return KIND_NAMES[kind]
