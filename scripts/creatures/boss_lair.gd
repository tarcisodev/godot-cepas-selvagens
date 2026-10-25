class_name BossLair
extends Node3D

## Clareira do Ancião (GDD-12 §9): procura um chão seco perto do ponto marcado, desenha o anel de
## pedras que marca a arena (o boss não sai dele) e põe o Rinolito Ancião no meio.

@export var landscape: Node3D
@export var lair_name: String = "Clareira do Ancião"

var boss: BeastFighter

func _ready() -> void:
	var spot := _find_dry_spot(global_position)
	global_position = spot
	var cfg := BeastFighter.rinolito_anciao()
	_build_ring(float(cfg.arena_radius))
	_build_sign()
	boss = BeastFighter.new()
	boss.name = "RinolitoAnciao"
	boss.config = cfg
	add_child(boss)
	boss.global_position = spot + Vector3.UP * 0.3
	boss.home = boss.global_position

func _ground_y(x: float, z: float) -> float:
	if landscape and landscape.has_method("get_height_at"):
		return landscape.get_height_at(x, z)
	return global_position.y

## Anda em espiral até achar chão fora do rio e fora da vila
func _find_dry_spot(from: Vector3) -> Vector3:
	for i in 60:
		var a := float(i) * 2.4
		var r := float(i) * 1.5
		var x := from.x + cos(a) * r
		var z := from.z + sin(a) * r
		if CityHub.in_village(x, z, 30.0):
			continue
		if RiverSystem.get_distance_to_river(x, z) < RiverSystem.get_water_half_width(z) + 26.0:
			continue
		return Vector3(x, _ground_y(x, z), z)
	return Vector3(from.x, _ground_y(from.x, from.z), from.z)

func _build_ring(radius: float) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.36, 0.34, 0.32)
	mat.roughness = 0.95
	var n := 18
	for i in n:
		var a := TAU * float(i) / float(n)
		var x := global_position.x + cos(a) * radius
		var z := global_position.z + sin(a) * radius
		var stone := MeshInstance3D.new()
		var box := BoxMesh.new()
		var h := 0.9 + fmod(float(i) * 0.37, 0.8)
		box.size = Vector3(0.6, h, 0.45)
		stone.mesh = box
		stone.material_override = mat
		add_child(stone)
		stone.global_position = Vector3(x, _ground_y(x, z) + h * 0.4, z)
		stone.rotation = Vector3(0.08 * sin(a * 3.0), -a, 0.1 * cos(a * 2.0))

func _build_sign() -> void:
	var label := Label3D.new()
	label.text = "%s\n⚠ Rinolito Ancião" % lair_name
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 30
	label.outline_size = 6
	label.outline_modulate = Color(0, 0, 0, 0.85)
	label.modulate = Color(1, 0.75, 0.5)
	label.visibility_range_end = 60.0
	add_child(label)
	var r := float(BeastFighter.rinolito_anciao().arena_radius) + 3.0
	var x := global_position.x + r
	var z := global_position.z
	label.global_position = Vector3(x, _ground_y(x, z) + 3.2, z)
