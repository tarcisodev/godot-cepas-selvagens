class_name MonsterArena
extends Node3D

## Área de teste de combate (B10): espalha os monstros num círculo em volta do centro,
## cada um apoiado no terreno; eles patrulham e renascem sozinhos.

@export var landscape: Node3D
@export var spawns: Array[PackedScene] = []
@export var ring_radius: float = 4.5

func _ready() -> void:
	var sign_label := Label3D.new()
	sign_label.text = "Arena de Teste"
	sign_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign_label.font_size = 28
	sign_label.outline_size = 6
	sign_label.outline_modulate = Color(0, 0, 0, 0.8)
	sign_label.modulate = Color(1, 0.85, 0.6)
	sign_label.visibility_range_end = 40.0
	sign_label.position.y = _ground_y(global_position) - global_position.y + 3.0
	add_child(sign_label)

	for i in spawns.size():
		if spawns[i] == null:
			continue
		var monster := spawns[i].instantiate() as Node3D
		var a: float = TAU * float(i) / float(spawns.size())
		var offset := Vector3(cos(a), 0.0, sin(a)) * ring_radius
		var spot: Vector3 = global_position + offset
		offset.y = _ground_y(spot) - global_position.y + 0.1
		monster.position = offset
		monster.name = "%s_%d" % [monster.name, i]
		add_child(monster)

func _ground_y(p: Vector3) -> float:
	if landscape and landscape.has_method("get_height_at"):
		return landscape.get_height_at(p.x, p.z)
	return global_position.y
