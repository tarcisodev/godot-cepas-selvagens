extends StaticBody3D

## Placa física do Quadro de Obras na praça: [E] abre a tela de doação do CityHub.

const _WorldLabel = preload("res://scripts/ui/world_label.gd")

var city: Node

var _prompt: _WorldLabel

func _ready() -> void:
	add_to_group("talkable")
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.42, 0.28, 0.16)
	wood.roughness = 0.9
	for x in [-0.7, 0.7]:
		var post := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.06
		cyl.bottom_radius = 0.07
		cyl.height = 2.0
		post.mesh = cyl
		post.position = Vector3(x, 1.0, 0)
		post.material_override = wood
		add_child(post)
	var plank := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.6, 1.0, 0.08)
	plank.mesh = bm
	plank.position.y = 1.45
	plank.material_override = wood
	add_child(plank)
	# Folhas de papel pregadas
	var paper := StandardMaterial3D.new()
	paper.albedo_color = Color(0.92, 0.86, 0.7)
	for i in 3:
		var sheet := MeshInstance3D.new()
		var sm := BoxMesh.new()
		sm.size = Vector3(0.38, 0.5, 0.01)
		sheet.mesh = sm
		sheet.position = Vector3(-0.5 + i * 0.5, 1.45 + (0.05 if i == 1 else -0.03), 0.05)
		sheet.rotation.z = (i - 1) * 0.06
		sheet.material_override = paper
		add_child(sheet)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.6, 2.0, 0.2)
	col.shape = shape
	col.position.y = 1.0
	add_child(col)

	var title := _WorldLabel.make(_WorldLabel.Kind.NAME, "Obras da Vila", "📜")
	title.position.y = 2.3
	add_child(title)
	_prompt = _WorldLabel.make(_WorldLabel.Kind.PROMPT, "[E] Doar materiais")
	_prompt.position.y = 2.1
	add_child(_prompt)

func talk_to(player: Node) -> void:
	if city:
		city.open_board(player)
