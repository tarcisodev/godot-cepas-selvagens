class_name PinhaFruit
extends Node3D

## Pinha-Lume caída no chão (GDD-10 §9). Carrega o genoma dos pinhões (gêmeos da mesma pinha).
## O jogador abre com [E] e ganha 3–5 Pinhões-Lume; bicho come e leva a semente na barriga;
## esquecida por GERMINATE_DAYS, planta um pinhão ali mesmo e o resto vira nutriente.

const GERMINATE_DAYS: float = 1.5
const SIZE: float = 0.45

@export var dna: PlantDNA
var age_days: float = 0.0
## Mesmo nome do GatherableResource: o bicho não mira pinha já aberta
var is_collected: bool = false

func _ready() -> void:
	add_to_group("fallen_fruit")
	add_to_group("harvestable")
	add_to_group("pinhas")
	if dna == null:
		dna = PlantDNA.randomized(PlantDNA.Kind.PINHEIRA, 1)
	var glow := MeshBatch.new()
	var base := MeshBatch.new()
	# Caída meio de lado
	var tilt := Basis(Vector3.RIGHT, 1.1).rotated(Vector3.UP, randf() * TAU)
	PinhaShape.append(glow, base, dna, Transform3D(tilt.scaled(Vector3.ONE * SIZE), Vector3(0, SIZE * 0.32, 0)))
	var mi := MeshInstance3D.new()
	mi.mesh = base.commit()
	mi.material_override = PlantBody._shared_material()
	add_child(mi)
	var gi := MeshInstance3D.new()
	gi.mesh = glow.commit()
	gi.material_override = PinhaShape.glow_material()
	gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(gi)

func _process(delta: float) -> void:
	var eco := _ecology()
	age_days += delta / (eco.day_length() if eco else 300.0)
	if age_days >= GERMINATE_DAYS:
		germinate()

## Ninguém pegou: um pinhão brota aqui (se o solo deixar) e o resto apodrece
func germinate() -> void:
	if is_collected:
		return
	is_collected = true
	var eco := _ecology()
	if eco:
		eco.sow(dna, global_position, true)
		eco.deposit(global_position, 0.06)
	queue_free()

## Traits do pinhão: o genoma (e `mutante`, se for)
func seed_traits() -> Array:
	return [StringName(dna.genome_code()), &"mutante"] if dna.mutant else [StringName(dna.genome_code())]

# ---------------------------------------------------------------- contrato 'harvestable'

func is_harvestable() -> bool:
	return not is_collected

func next_harvest_label() -> String:
	return "Pinha-Lume"

func get_harvest_verb() -> String:
	return "Abrindo"

func get_gather_time(mastery: MasteryComponent = null) -> float:
	var lvl: int = mastery.get_level(&"coleta") if mastery else 1
	return 1.0 * clampf(1.0 - (lvl - 1) / 200.0, 0.5, 1.0)

func harvest_next(harvester: Node = null) -> String:
	if is_collected:
		return ""
	is_collected = true
	var amount := randi_range(3, 5)
	if harvester:
		var inv: InventoryComponent = harvester.get("inventory")
		if inv:
			inv.add_material(&"pinhao_lume", amount, 3 if dna.mutant else 1, seed_traits())
		var mst: MasteryComponent = harvester.get("mastery")
		if mst:
			mst.add_xp(&"coleta", 10.0)
	queue_free()
	return "%d Pinhões-Lume (%s)" % [amount, dna.describe()]

func _ecology() -> Ecology:
	return get_tree().get_first_node_in_group("ecology") as Ecology if is_inside_tree() else null
