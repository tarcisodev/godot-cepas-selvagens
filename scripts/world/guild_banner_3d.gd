class_name GuildBanner3D
extends Node3D

const _GuildData = preload("res://scripts/data/guild_data.gd")

## Estandarte Heráldico 3D da Guilda (GDD-15 §3).
## Exibe as cores primária e secundária da guilda e o brasão heráldico.
## Possui animação procedural suave simulando o tremular do tecido ao vento.

@export var guild_data: _GuildData

var _flag_mesh: MeshInstance3D
var _emblem_label: Label3D
var _pole_mesh: MeshInstance3D
var _t: float = 0.0

func _ready() -> void:
	_build_banner()

func set_guild(p_guild: _GuildData) -> void:
	guild_data = p_guild
	_update_visuals()

func _build_banner() -> void:
	# Mastro de ferro escuro
	var pole_mat := StandardMaterial3D.new()
	pole_mat.albedo_color = Color(0.25, 0.23, 0.22)
	pole_mat.metallic = 0.6
	pole_mat.roughness = 0.4

	_pole_mesh = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.04
	cyl.bottom_radius = 0.05
	cyl.height = 3.6
	_pole_mesh.mesh = cyl
	_pole_mesh.material_override = pole_mat
	_pole_mesh.position.y = 1.8
	add_child(_pole_mesh)

	# Travessa horizontal superior para pendurar a flâmula
	var bar := MeshInstance3D.new()
	var bar_cyl := CylinderMesh.new()
	bar_cyl.top_radius = 0.03
	bar_cyl.bottom_radius = 0.03
	bar_cyl.height = 1.1
	bar.mesh = bar_cyl
	bar.material_override = pole_mat
	bar.position = Vector3(0.5, 3.4, 0)
	bar.rotation.z = PI * 0.5
	add_child(bar)

	# Tecido da flâmula
	_flag_mesh = MeshInstance3D.new()
	var flag_box := BoxMesh.new()
	flag_box.size = Vector3(0.9, 2.0, 0.02)
	_flag_mesh.mesh = flag_box
	_flag_mesh.position = Vector3(0.5, 2.3, 0)
	add_child(_flag_mesh)

	# Brasão heráldico no centro da bandeira
	_emblem_label = Label3D.new()
	_emblem_label.font_size = 32
	_emblem_label.position = Vector3(0.5, 2.5, 0.02)
	_emblem_label.outline_size = 4
	_emblem_label.outline_modulate = Color(0, 0, 0, 0.8)
	add_child(_emblem_label)

	_update_visuals()

func _update_visuals() -> void:
	if _flag_mesh == null:
		return

	var prim: Color = guild_data.primary_color if guild_data else Color(0.55, 0.12, 0.14)
	var flag_mat := StandardMaterial3D.new()
	flag_mat.albedo_color = prim
	flag_mat.roughness = 0.8
	_flag_mesh.material_override = flag_mat

	if _emblem_label:
		_emblem_label.text = guild_data.get_emblem_icon() if guild_data else "⚔️"
		if guild_data:
			_emblem_label.modulate = guild_data.secondary_color

func _process(delta: float) -> void:
	_t += delta
	if _flag_mesh:
		# Tremular suave ao vento
		var sway: float = sin(_t * 3.5) * 0.05 + sin(_t * 7.0) * 0.02
		_flag_mesh.rotation.y = sway
		if _emblem_label:
			_emblem_label.rotation.y = sway
