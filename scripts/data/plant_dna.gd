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
	return [0.5, 0.75, 1.0][big]

func display_name() -> String:
	return KIND_NAMES[kind]
