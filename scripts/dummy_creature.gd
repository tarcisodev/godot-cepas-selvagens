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

# Esfola do corpo (GDD-03 §8)
const CORPSE_LIFETIME: float = 300.0
var harvest_queue: Array[Dictionary] = []
var corpse_time_left: float = 0.0

# Besta de treino: renasce depois que o corpo é esfolado ou se decompõe
const RESPAWN_DELAY: float = 40.0
var respawn_timer: float = -1.0

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

	# O chifre acompanha a cabeça da besta animada
	if visual_body is CharacterVisual and visual_horn:
		var cv := visual_body as CharacterVisual
		if cv.skeleton:
			var head_rest: Transform3D = cv.skeleton.get_bone_global_rest(cv.skeleton.find_bone(&"Head"))
			visual_horn.global_position = cv.skeleton.to_global(head_rest.origin) + Vector3.UP * 0.32
			cv.attach_to_bone(visual_horn, &"Head")

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
		_register_parts()
		if not anatomy.part_broken.is_connected(_on_part_broken):
			anatomy.part_broken.connect(_on_part_broken)
	
	if pools:
		if not pools.poise_broken.is_connected(_on_poise_broken):
			pools.poise_broken.connect(_on_poise_broken)
		if not pools.poise_recovered.is_connected(_on_poise_recovered):
			pools.poise_recovered.connect(_on_poise_recovered)
		if not pools.health_depleted.is_connected(_on_health_depleted):
			pools.health_depleted.connect(_on_health_depleted)

func _register_parts() -> void:
	anatomy.register_part(&"horn", 50.0, false)
	anatomy.register_part(&"carapace", 120.0, false)
	anatomy.register_part(&"tail", 60.0, true)

## Volta inteira: vida, postura, partes, chifre e sem as penalidades da quebra.
func respawn() -> void:
	respawn_timer = -1.0
	corpse_time_left = 0.0
	harvest_queue.clear()
	remove_from_group("harvestable")
	_is_stunned = false
	if stats:
		stats.remove_modifiers_from_source(self)
	if anatomy:
		_register_parts()
	if pools:
		pools.reset_all()
	if visual_horn:
		visual_horn.visible = true
	if visual_body is CharacterVisual:
		(visual_body as CharacterVisual).play(&"Idle")
	_update_label()

func _start_respawn_countdown() -> void:
	respawn_timer = RESPAWN_DELAY

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
	# Corpo se decompõe: o que não foi esfolado se perde
	if corpse_time_left > 0.0:
		corpse_time_left -= delta
		if corpse_time_left <= 0.0 and not harvest_queue.is_empty():
			harvest_queue.clear()
			remove_from_group("harvestable")
			_start_respawn_countdown()
			_update_label("🍂 O corpo se decompôs.")

	if respawn_timer > 0.0:
		respawn_timer -= delta
		if respawn_timer <= 0.0:
			respawn()

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

	# Volta ao idle quando a reação de golpe termina (morta, fica no chão)
	if visual_body is CharacterVisual:
		var cv := visual_body as CharacterVisual
		if cv.current() != &"Death01" and not cv.is_playing():
			cv.play(&"Idle")

func on_hit_feedback(_hit: HitEvent, result: Dictionary) -> void:
	# Flash visual de impacto
	_flash_timer = 0.1
	var flash_mat := StandardMaterial3D.new()
	flash_mat.albedo_color = Color(1.0, 0.9, 0.6, 1.0) # Brilho quente de impacto
	flash_mat.emission_enabled = true
	flash_mat.emission = Color(1.0, 0.4, 0.1, 1.0)
	_set_body_material_override(flash_mat)
	if visual_body is CharacterVisual and pools and pools.current_health > 0.0:
		(visual_body as CharacterVisual).play(&"Hit_Chest", 1.3, true)

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

func _award_loot_to_player(mat_id: StringName, amount: int = 1, quality: int = 2, traits: Array = []) -> void:
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
			inv.add_material(mat_id, amount, quality, traits)

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
		_award_loot_to_player(&"chifre_rinolito", 1) # fragmento de luta = qualidade base (2★)
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
	if visual_body is CharacterVisual:
		(visual_body as CharacterVisual).play(&"Death01")
	# Loot condicional (GDD-03 §4 e B07): o que der para esfolar depende de como foi a caça.
	# Esfola manual (GDD-03 §8): cada parte vira um passo de ~3 s no corpo, que dura 5 min.
	# Cada material: [id, quantidade, qualidade, traits]. Íntegro = +1★ e trait (GDD-06 §1).
	harvest_queue.clear()
	if anatomy and anatomy.is_part_intact(&"horn"):
		harvest_queue.append({"label": "Chifre Íntegro", "materials": [[&"chifre_rinolito", 1, 3, [&"integro"]]], "cards": [&"polinization"]})
	harvest_queue.append({"label": "2x Placas de Carapaça", "materials": [[&"placa_carapaca", 2, 2, []]], "cards": [&"element_earth"]})
	corpse_time_left = CORPSE_LIFETIME
	add_to_group("harvestable")
	_update_label("💀 DERROTADO!\nSegure [E] perto do corpo para esfolar (%d partes)" % harvest_queue.size())

## true enquanto o corpo ainda tem partes para esfolar.
func is_harvestable() -> bool:
	return not harvest_queue.is_empty() and corpse_time_left > 0.0

## Nome da próxima parte a esfolar (para o HUD do player).
func next_harvest_label() -> String:
	return harvest_queue[0].label if is_harvestable() else ""

## Conclui um passo de esfola: entrega os materiais e cartas da próxima parte.
func harvest_next(harvester: Node = null) -> String:
	if not is_harvestable():
		return ""
	var entry: Dictionary = harvest_queue.pop_front()
	for m in entry.materials:
		_award_loot_to_player(m[0], m[1], m[2], m[3])
	for card_id in entry.cards:
		_unlock_card_for_player(card_id)
	if harvester and "mastery" in harvester and harvester.mastery:
		harvester.mastery.add_xp(&"esfola", 25.0)
	if harvest_queue.is_empty():
		remove_from_group("harvestable")
		_start_respawn_countdown()
		_update_label("🔪 Esfolado: %s\nCorpo vazio. Outra besta chega em %.0f s." % [entry.label, RESPAWN_DELAY])
	else:
		_update_label("🔪 Esfolado: %s\nFaltam %d partes [E]" % [entry.label, harvest_queue.size()])
	return entry.label

func _update_label(custom_msg: String = "") -> void:
	if status_label == null:
		return
	
	if not custom_msg.is_empty():
		status_label.text = custom_msg
		return

	# Morta, a etiqueta mostra o que resta no corpo
	if pools and pools.current_health <= 0.0:
		if is_harvestable():
			status_label.text = "💀 Besta de Sucata\nSegure [E] para esfolar: %s (%d)" % [next_harvest_label(), harvest_queue.size()]
		else:
			status_label.text = "💀 Besta de Sucata\nCorpo vazio."
		return

	var horn_str: String = "Íntegro" if not anatomy.is_part_broken(&"horn") else "Quebrado"
	status_label.text = "Besta de Sucata\nVida: %.0f / %.0f\nPostura: %.0f / %.0f\nChifre: %s (%.0f)" % [
		pools.current_health, stats.get_stat(&"max_health"),
		pools.current_poise, stats.get_stat(&"max_poise"),
		horn_str, anatomy.get_part_hp(&"horn")
	]
