class_name DummyCreature
extends CharacterBody3D

## Besta de Treino / Dummy de Caça (GDD-01 e GDD-03).
## Possui partes anatômicas quebráveis (Chifre e Corpo), postura vulnerável e feedback visual.

@onready var stats: StatsComponent = $StatsComponent
@onready var pools: PoolsComponent = $PoolsComponent
@onready var anatomy: AnatomyComponent = $AnatomyComponent
@onready var visual_body: Node3D = $VisualMesh/Body
@onready var visual_horn: MeshInstance3D = $VisualMesh/Horn
@onready var status_label: Label3D = $StatusLabel

var _original_body_mat: StandardMaterial3D
var _flash_timer: float = 0.0
var _wobble_angle: float = 0.0
var _is_stunned: bool = false

var hit_audio_player: AudioStreamPlayer3D
var hit_sounds: Array[AudioStream] = []
var bone_break_player: AudioStreamPlayer3D
var poise_break_player: AudioStreamPlayer3D

func _ready() -> void:
	_setup_components()
	_setup_audio()
	
	var first_mesh: MeshInstance3D = null
	if visual_body is MeshInstance3D:
		first_mesh = visual_body as MeshInstance3D
	elif visual_body != null:
		var meshes = visual_body.find_children("*", "MeshInstance3D", true)
		if not meshes.is_empty():
			first_mesh = meshes[0] as MeshInstance3D

	if first_mesh and first_mesh.material_override:
		_original_body_mat = first_mesh.material_override.duplicate()
	elif first_mesh and first_mesh.get_surface_override_material_count() > 0 and first_mesh.get_surface_override_material(0):
		_original_body_mat = first_mesh.get_surface_override_material(0).duplicate()
	elif first_mesh and first_mesh.mesh and first_mesh.mesh.get_surface_count() > 0 and first_mesh.mesh.surface_get_material(0):
		_original_body_mat = first_mesh.mesh.surface_get_material(0).duplicate()
	else:
		_original_body_mat = null
	
	_update_label()

func _setup_components() -> void:
	if stats == null:
		stats = get_node_or_null("StatsComponent") as StatsComponent
	if pools == null:
		pools = get_node_or_null("PoolsComponent") as PoolsComponent
	if anatomy == null:
		anatomy = get_node_or_null("AnatomyComponent") as AnatomyComponent
	if visual_body == null:
		visual_body = get_node_or_null("VisualMesh/Body") as Node3D
	if visual_horn == null:
		visual_horn = get_node_or_null("VisualMesh/Horn") as MeshInstance3D
	if status_label == null:
		status_label = get_node_or_null("StatusLabel") as Label3D
	
	# Garante 3 partes anatômicas no componente (GDD-03 e B07)
	if anatomy:
		anatomy.register_part(&"horn", 50.0, false)
		anatomy.register_part(&"carapace", 120.0, false)
		anatomy.register_part(&"tail", 60.0, true)
		if not anatomy.part_broken.is_connected(_on_part_broken):
			anatomy.part_broken.connect(_on_part_broken)
	
	if pools:
		if not pools.poise_broken.is_connected(_on_poise_broken):
			pools.poise_broken.connect(_on_poise_broken)
		if not pools.poise_recovered.is_connected(_on_poise_recovered):
			pools.poise_recovered.connect(_on_poise_recovered)
		if not pools.health_depleted.is_connected(_on_health_depleted):
			pools.health_depleted.connect(_on_health_depleted)

func _setup_audio() -> void:
	if hit_audio_player != null:
		return

	# Áudio de impacto / acerto
	hit_audio_player = AudioStreamPlayer3D.new()
	hit_audio_player.name = "HitAudioPlayer"
	hit_audio_player.bus = &"Efeitos"
	hit_audio_player.volume_db = -3.0
	hit_audio_player.max_distance = 25.0
	add_child(hit_audio_player)
	
	var s1 = load("res://assets/audio/Small_Sound_Kit/Small Sound Kit/Dark/Impact_Guts_Gore_01.wav")
	var s2 = load("res://assets/audio/Small_Sound_Kit/Small Sound Kit/Dark/Blood_Bone_Smash_01.wav")
	if s1: hit_sounds.append(s1)
	if s2: hit_sounds.append(s2)
	
	# Áudio de quebra de osso / chifre partindo
	bone_break_player = AudioStreamPlayer3D.new()
	bone_break_player.name = "BoneBreakAudioPlayer"
	bone_break_player.bus = &"Efeitos"
	var break_stream = load("res://assets/audio/Small_Sound_Kit/Small Sound Kit/Dark/Breaking_Bones_01.wav")
	if break_stream:
		bone_break_player.stream = break_stream
		bone_break_player.volume_db = 0.0
		bone_break_player.max_distance = 30.0
		add_child(bone_break_player)
	
	# Áudio de quebra de postura / desmoronamento
	poise_break_player = AudioStreamPlayer3D.new()
	poise_break_player.name = "PoiseBreakAudioPlayer"
	poise_break_player.bus = &"Efeitos"
	var poise_stream = load("res://assets/audio/Small_Sound_Kit/Small Sound Kit/Ambience/Amb_Drop_Debris_01.wav")
	if poise_stream:
		poise_break_player.stream = poise_stream
		poise_break_player.volume_db = -2.0
		poise_break_player.max_distance = 30.0
		add_child(poise_break_player)

func _set_body_material_override(mat: Material) -> void:
	if visual_body is MeshInstance3D:
		(visual_body as MeshInstance3D).material_override = mat
	elif visual_body != null:
		for child in visual_body.find_children("*", "MeshInstance3D", true):
			(child as MeshInstance3D).material_override = mat

func _process(delta: float) -> void:
	# Feedback de flash de dano
	if _flash_timer > 0.0:
		_flash_timer -= delta
		if _flash_timer <= 0.0:
			_set_body_material_override(_original_body_mat)
	
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
	_set_body_material_override(flash_mat)
	
	# Áudio de impacto de carne / sucata
	if hit_audio_player and is_inside_tree() and hit_audio_player.is_inside_tree() and not hit_sounds.is_empty():
		hit_audio_player.stream = hit_sounds.pick_random()
		hit_audio_player.pitch_scale = randf_range(0.92, 1.08)
		hit_audio_player.play()
	
	_update_label()

func _on_poise_broken() -> void:
	_is_stunned = true
	if poise_break_player and is_inside_tree() and poise_break_player.is_inside_tree():
		poise_break_player.pitch_scale = randf_range(0.95, 1.05)
		poise_break_player.play()
	_update_label("⚠️ POSTURA QUEBRADA! (Vulnerável)")

func _on_poise_recovered() -> void:
	_is_stunned = false
	_update_label()

func _award_loot_to_player(mat_id: StringName, amount: int = 1) -> void:
	var player_node: Node = null
	if is_inside_tree() and get_tree() != null:
		player_node = get_tree().get_first_node_in_group("player")
	if player_node == null and get_parent() != null:
		player_node = get_parent().get_node_or_null("Player")
		if player_node == null:
			for child in get_parent().get_children():
				if child.is_in_group("player") or child is Player:
					player_node = child
					break
	if player_node != null:
		var inv: InventoryComponent = player_node.get_node_or_null("InventoryComponent") as InventoryComponent
		if inv == null and "inventory" in player_node:
			inv = player_node.inventory
		if inv != null:
			inv.add_material(mat_id, amount)

func _unlock_card_for_player(card_id: StringName) -> void:
	var player_node: Node = null
	if is_inside_tree() and get_tree() != null:
		player_node = get_tree().get_first_node_in_group("player")
	if player_node == null and get_parent() != null:
		player_node = get_parent().get_node_or_null("Player")
		if player_node == null:
			for child in get_parent().get_children():
				if child.is_in_group("player") or child is Player:
					player_node = child
					break
	if player_node != null:
		var cards: CardCollectionComponent = player_node.get_node_or_null("CardCollectionComponent") as CardCollectionComponent
		if cards == null and "card_collection" in player_node:
			cards = player_node.card_collection
		if cards != null:
			cards.unlock_card(card_id)

func _on_part_broken(part_id: StringName) -> void:
	# Toca som de osso estalando / partindo
	if bone_break_player and is_inside_tree() and bone_break_player.is_inside_tree():
		bone_break_player.pitch_scale = randf_range(0.96, 1.08)
		bone_break_player.play()

	if part_id == &"horn":
		if visual_horn:
			visual_horn.visible = false
		# Mudança de comportamento: ao perder o chifre, perde postura e defesa
		if stats:
			stats.add_modifier(ModifierData.new(&"poise_resist", ModifierData.Op.FLAT, -0.25, self))
		_award_loot_to_player(&"chifre_lascado", 1)
		_unlock_card_for_player(&"beast_horn")
		_update_label("💥 CHIFRE QUEBRADO!\nDrop: Chifre Lascado • Carta 3D Desbloqueada!")
	elif part_id == &"tail":
		_award_loot_to_player(&"tendao_elastico", 1)
		_unlock_card_for_player(&"mimic")
		_update_label("💥 CAUDA DECEPADA!\nDrop: Tendão Elástico • Carta: Mímico!")
	else:
		_award_loot_to_player(&"placa_carapaca", 1)
		_unlock_card_for_player(&"beehive")
		_update_label("💥 CARAPAÇA RACHADA: Placa coletada • Carta: Colmeia!")

func _on_health_depleted() -> void:
	# Loot condicional (GDD-03 §4 e B07): se o chifre estava intacto no momento da morte
	if anatomy and anatomy.is_part_intact(&"horn"):
		_award_loot_to_player(&"chifre_integro", 1)
		_award_loot_to_player(&"placa_carapaca", 2)
		_unlock_card_for_player(&"polinization")
		_unlock_card_for_player(&"element_earth")
		_update_label("💀 DERROTADO COM CHIFRE INTACTO!\nLoot: Chifre Íntegro • Carta: Polinização Arcana!")
	else:
		_award_loot_to_player(&"placa_carapaca", 2)
		_unlock_card_for_player(&"element_earth")
		_update_label("💀 DERROTADO!\nLoot: 2x Placas • Carta: Elemento Terra")

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
