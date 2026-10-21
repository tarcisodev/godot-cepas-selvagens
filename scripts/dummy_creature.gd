class_name DummyCreature
extends CharacterBody3D

## Besta de Treino / Dummy de Caça (GDD-01 e GDD-03).
## Possui partes anatômicas quebráveis (Chifre e Corpo), postura vulnerável e feedback visual.

@onready var stats: StatsComponent = $StatsComponent
@onready var pools: PoolsComponent = $PoolsComponent
@onready var anatomy: AnatomyComponent = $AnatomyComponent
@onready var visual_body: MeshInstance3D = $VisualMesh/Body
@onready var visual_horn: MeshInstance3D = $VisualMesh/Horn
@onready var status_label: Label3D = $StatusLabel

var _original_body_mat: StandardMaterial3D
var _flash_timer: float = 0.0
var _wobble_angle: float = 0.0
var _is_stunned: bool = false

func _ready() -> void:
	if visual_body and visual_body.material_override:
		_original_body_mat = visual_body.material_override.duplicate()
	elif visual_body and visual_body.mesh and visual_body.mesh.material:
		_original_body_mat = visual_body.mesh.material.duplicate()
	else:
		_original_body_mat = StandardMaterial3D.new()
		_original_body_mat.albedo_color = Color(0.42, 0.32, 0.22, 1.0)
	
	visual_body.material_override = _original_body_mat
	
	pools.poise_broken.connect(_on_poise_broken)
	pools.poise_recovered.connect(_on_poise_recovered)
	pools.health_depleted.connect(_on_health_depleted)
	anatomy.part_broken.connect(_on_part_broken)
	
	_update_label()

func _process(delta: float) -> void:
	# Feedback de flash de dano
	if _flash_timer > 0.0:
		_flash_timer -= delta
		if _flash_timer <= 0.0 and _original_body_mat:
			visual_body.material_override = _original_body_mat
	
	# Oscilação / cambaleio quando atordoado por postura
	if _is_stunned:
		_wobble_angle = sin(Time.get_ticks_msec() * 0.012) * 0.25
		visual_body.rotation.z = _wobble_angle
		visual_body.rotation.x = 0.35 # Inclinado para trás
	else:
		visual_body.rotation.z = lerp(visual_body.rotation.z, 0.0, 10.0 * delta)
		visual_body.rotation.x = lerp(visual_body.rotation.x, 0.0, 10.0 * delta)

func on_hit_feedback(_hit: HitEvent, result: Dictionary) -> void:
	# Flash visual de impacto
	_flash_timer = 0.1
	var flash_mat := StandardMaterial3D.new()
	flash_mat.albedo_color = Color(1.0, 0.9, 0.6, 1.0) # Brilho quente de impacto
	flash_mat.emission_enabled = true
	flash_mat.emission = Color(1.0, 0.4, 0.1, 1.0)
	visual_body.material_override = flash_mat
	
	_update_label()

func _on_poise_broken() -> void:
	_is_stunned = true
	_update_label("⚠️ POSTURA QUEBRADA! (Vulnerável)")

func _on_poise_recovered() -> void:
	_is_stunned = false
	_update_label()

func _on_part_broken(part_id: StringName) -> void:
	if part_id == &"horn" and visual_horn:
		# Efeito de quebra do chifre: desprende visualmente
		visual_horn.visible = false
		_update_label("💥 CHIFRE QUEBRADO!\nDrop: Chifre Lascado (Raro)")
	else:
		_update_label("💥 PARTE QUEBRADA: " + String(part_id))

func _on_health_depleted() -> void:
	_update_label("💀 DERROTADO")

func _update_label(custom_msg: String = "") -> void:
	if status_label == null:
		return
	
	if not custom_msg.is_empty():
		status_label.text = custom_msg
		return
	
	var horn_str: String = "Íntegro" if not anatomy.is_part_broken(&"horn") else "Quebrado"
	status_label.text = "Besta de Sucata\nVida: %.0f / %.0f\nPostura: %.0f / %.0f\nChifre: %s (%.0f)" % [
		pools.current_health, stats.get_stat(&"max_health"),
		pools.current_poise, stats.get_stat(&"max_poise"),
		horn_str, anatomy.get_part_hp(&"horn")
	]
