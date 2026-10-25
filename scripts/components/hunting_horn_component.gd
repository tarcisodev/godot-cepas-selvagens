class_name HuntingHornComponent
extends Node

## Sistema de Notas, Partitura e Melodias do Berrante de Caça (inspirado na Hunting Horn de Monster Hunter).
## Cada golpe do combo no clique esquerdo acrescenta uma Nota (1=🎵, 2=🎶, 3=🎼) na partitura (até 3 notas).
## O botão direito dispara o Recital Ressonante: onda de choque concussiva em área ao redor do personagem
## que consome as notas da partitura e ativa a Melodia correspondente (Movimento, Ataque/Postura,
## Defesa/Vigor ou Cura/Bis).

signal notes_changed(current_notes: Array[int])
signal melody_played(melody_id: StringName)
signal buffs_changed()

const MAX_NOTES: int = 3

const NOTE_ICONS: Dictionary = {
	1: "🎵",
	2: "🎶",
	3: "🎼",
}
const NOTE_NAMES: Dictionary = {
	1: "Sol",
	2: "Brisa",
	3: "Lume",
}
const NOTE_COLORS: Dictionary = {
	1: Color(1.0, 0.78, 0.28),
	2: Color(0.35, 0.92, 0.55),
	3: Color(0.32, 0.88, 0.98),
}

const MELODIES: Dictionary = {
	&"marcha_vento": {
		"name": "Marcha do Vento",
		"icon": "🌬️",
		"score": "🎵",
		"duration": 45.0,
		"color": Color(0.55, 0.95, 0.75),
		"desc": "+25% velocidade e −8 de Carga",
		"mods": {&"move_speed_bonus": 0.25, &"load": -8.0},
	},
	&"hino_furia": {
		"name": "Hino da Fúria",
		"icon": "🔥",
		"score": "🎵🎶",
		"duration": 45.0,
		"color": Color(1.0, 0.52, 0.22),
		"desc": "+25% dano e +30% quebra de Postura/partes",
		"mods": {&"damage_bonus": 0.25},
		"poise_mult": 1.3,
	},
	&"baluarte_sonoro": {
		"name": "Baluarte Ressonante",
		"icon": "🛡️",
		"score": "🎵🎶🎼",
		"duration": 45.0,
		"color": Color(0.95, 0.78, 0.30),
		"desc": "+6 regen. Vigor, −6 custo esquiva, +15% defesa e +20% Postura",
		"mods": {
			&"vigor_regen": 6.0,
			&"dodge_cost": -6.0,
			&"resist_slash": 0.15,
			&"resist_impact": 0.15,
			&"resist_pierce": 0.15,
			&"poise_resist": 0.20,
		},
	},
	&"acorde_vital": {
		"name": "Acorde Vital",
		"icon": "💚",
		"score": "🎼 / Bis",
		"duration": 30.0,
		"color": Color(0.32, 0.95, 0.82),
		"desc": "Cura +35 Vida, +3 Vida/s, +4 Éter/s e renova as melodias ativas",
		"mods": {&"ether_regen": 4.0},
		"heal": 35.0,
		"hp_regen": 3.0,
		"refresh_all": true,
	},
}

const MELODY_ORDER: Array[StringName] = [&"marcha_vento", &"hino_furia", &"baluarte_sonoro", &"acorde_vital"]

var player: Player
## Notas acumuladas na partitura (valores 1, 2 ou 3; máximo 3)
var notes: Array[int] = []
## Melodias ativas no momento: melody_id -> segundos restantes
var active_buffs: Dictionary = {}
## Fontes de modificadores no StatsComponent por melodia
var _buff_sources: Dictionary = {}

func _process(delta: float) -> void:
	if active_buffs.is_empty():
		return
	if active_buffs.has(&"acorde_vital") and player and player.pools and not player.is_downed:
		var regen_hp: float = float(MELODIES[&"acorde_vital"].get("hp_regen", 3.0))
		player.pools.heal(regen_hp * delta)
	var expired: Array[StringName] = []
	for id in active_buffs:
		active_buffs[id] = float(active_buffs[id]) - delta
		if active_buffs[id] <= 0.0:
			expired.append(id)
	for id in expired:
		_remove_melody(id)
	if not expired.is_empty():
		buffs_changed.emit()

## Registra uma nota de ataque primário (Mouse 1) na partitura (1=🎵 no 1º golpe, 2=🎶 no 2º, 3=🎼 no 3º ou agachado)
func on_primary_attack(combo_step: int, special_lume: bool = false) -> int:
	var note: int = 3 if special_lume else (posmod(combo_step, 3) + 1)
	push_note(note)
	_spawn_sonic_ring(NOTE_COLORS.get(note, Color.WHITE), 1.65, 0.32)
	return note

## Registra uma nota de ataque secundário (Mouse 2) na partitura (2=🎶 Brisa, ou 3=🎼 Lume após Brisa/agachado)
func on_secondary_attack(_combo_step: int, special_lume: bool = false) -> int:
	var note: int = 3 if (special_lume or (not notes.is_empty() and notes[-1] == 2)) else 2
	push_note(note)
	_spawn_sonic_ring(NOTE_COLORS.get(note, Color.WHITE), 2.1, 0.36)
	return note

func push_note(note: int) -> void:
	var n := clampi(note, 1, 3)
	if notes.size() >= MAX_NOTES:
		notes.pop_front()
	notes.append(n)
	notes_changed.emit(notes)

func pop_last_note() -> void:
	if not notes.is_empty():
		notes.pop_back()
		notes_changed.emit(notes)

func clear_notes() -> void:
	notes.clear()
	notes_changed.emit(notes)

## Qual melodia será tocada se o jogador acionar o Recital agora (&"" se a partitura estiver vazia)
func next_melody_id() -> StringName:
	if notes.is_empty():
		return &""
	if notes[0] == 3 or notes.count(3) >= 2:
		return &"acorde_vital"
	if notes.size() == 1:
		return &"marcha_vento"
	if notes.size() == 2:
		return &"hino_furia"
	if active_buffs.has(&"baluarte_sonoro"):
		return &"acorde_vital"
	return &"baluarte_sonoro"

## Executa o Recital Ressonante (botão direito): se houver notas, consome-as e toca a Melodia;
## se a partitura estiver vazia, entoa a Nota Lume (🎼) para preparar o Acorde Vital.
func perform_recital() -> StringName:
	if notes.is_empty():
		push_note(3)
		_spawn_sonic_ring(NOTE_COLORS[3], 3.2, 0.48)
		if player:
			player.posture_changed.emit("📯 Sopro de Lume: 🎼 na partitura (Dir. de novo toca Acorde Vital!)")
		return &"nota_lume"
	var melody := next_melody_id()
	notes.clear()
	notes_changed.emit(notes)
	activate_melody(melody)
	var col: Color = MELODIES[melody].get("color", Color(1.0, 0.8, 0.35))
	_spawn_sonic_ring(col, 4.2, 0.55)
	_spawn_sonic_ring(col.lightened(0.25), 2.8, 0.42)
	melody_played.emit(melody)
	if player:
		var info: Dictionary = MELODIES[melody]
		player.posture_changed.emit("📯 Recital — %s %s: %s" % [info.icon, info.name, info.desc])
	return melody

## Ativa (ou renova) uma melodia diretamente e aplica seus efeitos ao jogador
func activate_melody(melody_id: StringName) -> void:
	if not MELODIES.has(melody_id):
		return
	var info: Dictionary = MELODIES[melody_id]
	if bool(info.get("refresh_all", false)):
		for other_id in active_buffs.keys():
			if MELODIES.has(other_id):
				active_buffs[other_id] = float(MELODIES[other_id].duration)
	if info.has("heal") and player and player.pools:
		player.pools.heal(float(info.heal))
	active_buffs[melody_id] = float(info.duration)
	_apply_melody_modifiers(melody_id)
	buffs_changed.emit()

func is_active(melody_id: StringName) -> bool:
	return active_buffs.has(melody_id)

func time_left(melody_id: StringName) -> float:
	return float(active_buffs.get(melody_id, 0.0))

func poise_mult() -> float:
	return float(MELODIES[&"hino_furia"].get("poise_mult", 1.3)) if active_buffs.has(&"hino_furia") else 1.0

func clear_all_buffs() -> void:
	for id in active_buffs.keys():
		_remove_melody(id)
	active_buffs.clear()
	buffs_changed.emit()

func _apply_melody_modifiers(melody_id: StringName) -> void:
	if player == null or player.stats == null:
		return
	if not _buff_sources.has(melody_id):
		_buff_sources[melody_id] = RefCounted.new()
	var src: RefCounted = _buff_sources[melody_id]
	player.stats.remove_modifiers_from_source(src)
	var mods: Dictionary = MELODIES[melody_id].get("mods", {})
	for stat in mods:
		player.stats.add_modifier(ModifierData.new(stat, ModifierData.Op.FLAT, float(mods[stat]), src))

func _remove_melody(melody_id: StringName) -> void:
	active_buffs.erase(melody_id)
	if _buff_sources.has(melody_id) and player and player.stats:
		player.stats.remove_modifiers_from_source(_buff_sources[melody_id])

## Texto da pauta musical para o HUD
func notes_text() -> String:
	var slots: Array[String] = []
	for i in MAX_NOTES:
		if i < notes.size():
			slots.append(NOTE_ICONS.get(notes[i], "🎵"))
		else:
			slots.append("·")
	var next_id := next_melody_id()
	var next_str := "Sopro de Lume (🎼)" if next_id == &"" else "%s %s" % [MELODIES[next_id].icon, MELODIES[next_id].name]
	return "📯 Partitura: [ %s ]  →  [Esq.+Dir.] %s" % ["  ".join(slots), next_str]

## Texto resumido das melodias ativas e seus tempos
func active_buffs_text() -> String:
	var parts: Array[String] = []
	for id in MELODY_ORDER:
		if active_buffs.has(id):
			var info: Dictionary = MELODIES[id]
			parts.append("%s %s %ds" % [info.icon, info.name, ceilf(float(active_buffs[id]))])
	return "  ·  ".join(parts)

## Onda sonora 3D expansiva no chão ao redor do personagem
func _spawn_sonic_ring(color: Color, max_radius: float, duration: float) -> void:
	if player == null or not player.is_inside_tree() or player.get_parent() == null:
		return
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.35
	tm.outer_radius = 0.50
	tm.rings = 24
	tm.ring_segments = 8
	ring.mesh = tm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(color.r, color.g, color.b, 0.82)
	ring.material_override = mat
	player.get_parent().add_child(ring)
	ring.global_position = player.global_position + Vector3(0.0, 0.9, 0.0)
	var scale_end := max_radius / 0.45
	var tw := ring.create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring, "scale", Vector3(scale_end, 1.0, scale_end), duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, duration)
	tw.chain().tween_callback(ring.queue_free)
