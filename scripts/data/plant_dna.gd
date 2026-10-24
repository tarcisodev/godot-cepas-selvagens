class_name PlantDNA
extends Resource

## DNA de planta (GDD-09 §3): tipo + genes visíveis (porte, galhos, cores, pétalas).
## Determinístico pela seed; o corpo é montado por PlantBody.

enum Kind { ARVORE, ARBUSTO, CEPA, COGUMELO, PINHEIRA }

const KIND_NAMES: Dictionary = {
	Kind.ARVORE: "Árvore-de-Cepa", Kind.ARBUSTO: "Arbusto Florido",
	Kind.CEPA: "Cepa Selvagem", Kind.COGUMELO: "Cogumelo-Lume", Kind.PINHEIRA: "Pinheira-Lume",
}

## Copa da Pinheira-Lume (GDD-10 §9): T taça > C cone > H chorona; `*` espiral só por mutação
enum Copa { TACA, CONE, CHORONA, ESPIRAL }
const COPA_NAMES: Array[String] = ["taça", "cone", "chorona", "espiral"]
## Escamas da pinha Fibonacci
const FIB_SCALES: Array[int] = [21, 34, 55]
const GOLDEN_ANGLE: float = 2.39996323 # 137,5°

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

@export_group("Pinheira-Lume")
@export var copa: Array = ["T", "C"]
## Brilho: dominância incompleta (BB forte, Bb médio, bb fraco)
@export var brilho: Array = ["B", "b"]
## Matiz da luz (0–1)
@export var lume: float = 0.55
## F_ pinha Fibonacci, ff pinha mandala
@export var forma: Array = ["F", "f"]
## Escamas por anel da pinha mandala (5–12)
@export var simetria: int = 8
## Escamas da pinha Fibonacci (21, 34 ou 55)
@export var escamas: int = 34

## Cores raras das plantas mutantes
const MUTANT_HUES: Array[Color] = [Color(0.25, 0.55, 1.0), Color(1.0, 0.85, 0.15), Color(0.95, 0.25, 0.85), Color(0.3, 1.0, 0.85)]

## Semente: herda da mãe (autopolinização), com mutação na chance dada (3% a 12%, GDD-10 §4)
static func seed_of(parent: PlantDNA, p_seed: int, mutation_chance: float) -> PlantDNA:
	if parent.kind == Kind.PINHEIRA:
		return cross(parent, parent, p_seed, mutation_chance)
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

## Pinheira-Lume (GDD-10 §9): semente de mãe × pai (pólen pelo vento). Cada gene de alelos
## leva um alelo de cada; o `lume` mistura os dois; mutação na chance dada.
static func cross(mother: PlantDNA, father: PlantDNA, p_seed: int, mutation_chance: float = 0.0) -> PlantDNA:
	var rng := RandomNumberGenerator.new()
	rng.seed = p_seed
	var d: PlantDNA = mother.duplicate()
	d.porte = [mother.porte[rng.randi() % 2], father.porte[rng.randi() % 2]]
	d.copa = [mother.copa[rng.randi() % 2], father.copa[rng.randi() % 2]]
	d.brilho = [mother.brilho[rng.randi() % 2], father.brilho[rng.randi() % 2]]
	d.forma = [mother.forma[rng.randi() % 2], father.forma[rng.randi() % 2]]
	d.lume = fposmod(_mix_hue(mother.lume, father.lume, rng.randf()) + rng.randf_range(-0.03, 0.03), 1.0)
	d.simetria = clampi((mother.simetria if rng.randf() < 0.5 else father.simetria) + rng.randi_range(-1, 1), 5, 12)
	d.escamas = mother.escamas if rng.randf() < 0.5 else father.escamas
	d.branches = clampi((mother.branches if rng.randf() < 0.5 else father.branches) + rng.randi_range(-1, 1), 3, 7)
	if rng.randf() < mutation_chance:
		mutate(d, rng)
	d.refresh_pinheira()
	return d

## Só a mutação, sem recombinar (pinhão que já tem genoma e brota num solo rico)
static func sprout(seed_dna: PlantDNA, p_seed: int, mutation_chance: float) -> PlantDNA:
	var rng := RandomNumberGenerator.new()
	rng.seed = p_seed
	var d: PlantDNA = seed_dna.duplicate()
	d.porte = seed_dna.porte.duplicate() # o duplicate do Resource divide os Arrays
	d.copa = seed_dna.copa.duplicate()
	if rng.randf() < mutation_chance:
		mutate(d, rng)
	d.refresh_pinheira()
	return d

static func mutate(d: PlantDNA, rng: RandomNumberGenerator) -> void:
	d.lume = rng.randf()
	if rng.randf() < 0.5:
		d.copa[rng.randi() % 2] = "*"
	else:
		d.porte[rng.randi() % 2] = "*"

## Matiz médio pelo caminho mais curto do círculo de cores
static func _mix_hue(a: float, b: float, t: float) -> float:
	var diff := fposmod(b - a + 0.5, 1.0) - 0.5
	return a + diff * t

## Cores, mutante e seed de forma saem só dos genes (o código do genoma basta para refazer a árvore)
func refresh_pinheira() -> void:
	if kind != Kind.PINHEIRA:
		return
	mutant = copa.has("*") or porte.has("*")
	flower_color = lume_color()
	leaf_color = Color(0.12, 0.3, 0.16).lerp(flower_color, 0.12)
	trunk_color = Color(0.36, 0.3, 0.27)
	dna_seed = hash(genome_code())

func copa_type() -> Copa:
	if copa.has("*"):
		return Copa.ESPIRAL
	if copa.has("T"):
		return Copa.TACA
	if copa.has("C"):
		return Copa.CONE
	return Copa.CHORONA

## 0,35 / 0,65 / 1,0 conforme quantos B
func glow_strength() -> float:
	return [0.35, 0.65, 1.0][brilho.count("B")]

func is_fibonacci() -> bool:
	return forma.has("F")

func lume_color() -> Color:
	return Color.from_hsv(lume, 0.78, 1.0)

static func hue_name(h: float) -> String:
	var names := [[0.04, "vermelho"], [0.1, "laranja"], [0.16, "âmbar"], [0.24, "lima"], [0.42, "verde"],
		[0.5, "turquesa"], [0.56, "ciano"], [0.7, "azul"], [0.79, "violeta"], [0.9, "magenta"], [0.96, "rosa"]]
	for n in names:
		if h < n[0]:
			return n[1]
	return "vermelho"

## Código curto do genoma para o trait do pinhão (ADR-0005: pinhões iguais empilham):
## "gen_Tt-TC-Bb-Ff-62-8-34-5" = porte, copa, brilho, forma, lume, simetria, escamas, verticilos
func genome_code() -> String:
	return "gen_%s-%s-%s-%s-%02d-%d-%d-%d" % ["".join(porte), "".join(copa), "".join(brilho), "".join(forma),
		clampi(roundi(lume * 100.0), 0, 99), simetria, escamas, branches]

static func from_genome_code(code: String) -> PlantDNA:
	var d := PlantDNA.new()
	d.kind = Kind.PINHEIRA
	var parts := code.trim_prefix("gen_").split("-")
	if parts.size() >= 8:
		d.porte = [parts[0][0], parts[0][1]]
		d.copa = [parts[1][0], parts[1][1]]
		d.brilho = [parts[2][0], parts[2][1]]
		d.forma = [parts[3][0], parts[3][1]]
		d.lume = int(parts[4]) / 100.0
		d.simetria = int(parts[5])
		d.escamas = int(parts[6])
		d.branches = int(parts[7])
	d.refresh_pinheira()
	return d

## "Copa taça · Lume azul · Pinha Fibonacci 34 · Brilho forte · Porte Tt"
func describe() -> String:
	var pinha := ("Pinha Fibonacci %d" % escamas) if is_fibonacci() else ("Pinha mandala %d" % simetria)
	var forca: String = ["fraco", "médio", "forte"][brilho.count("B")]
	return "Copa %s · Lume %s · %s · Brilho %s · Porte %s" % [COPA_NAMES[copa_type()], hue_name(lume), pinha, forca, "".join(porte)]

func is_tree() -> bool:
	return kind == Kind.ARVORE or kind == Kind.PINHEIRA

func to_dict() -> Dictionary:
	var d := {
		"kind": kind, "seed": dna_seed, "porte": porte, "branches": branches, "petals": petals,
		"leaf": leaf_color.to_html(), "flower": flower_color.to_html(), "trunk": trunk_color.to_html(), "mutant": mutant,
	}
	if kind == Kind.PINHEIRA:
		d["gen"] = genome_code()
	return d

static func from_dict(d: Dictionary) -> PlantDNA:
	if d.has("gen"):
		return from_genome_code(str(d.gen))
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
	if p_kind == Kind.PINHEIRA:
		var copas := ["T", "T", "C", "H"]
		d.copa = [copas[rng.randi() % 4], copas[rng.randi() % 4]]
		d.brilho = ["B" if rng.randf() < 0.55 else "b", "B" if rng.randf() < 0.55 else "b"]
		d.forma = ["F" if rng.randf() < 0.5 else "f", "F" if rng.randf() < 0.5 else "f"]
		d.lume = rng.randf()
		d.simetria = rng.randi_range(5, 12)
		d.escamas = FIB_SCALES[rng.randi() % 3]
		d.branches = rng.randi_range(4, 6)
		d.refresh_pinheira()
	return d

func size_factor() -> float:
	var big := 0
	for a in porte:
		if a == "T" or a == "*":
			big += 1
	return [0.5, 0.75, 1.0][big] * (1.15 if mutant else 1.0)

func display_name() -> String:
	return KIND_NAMES[kind]
