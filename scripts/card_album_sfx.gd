class_name CardAlbumSfx
extends Node

## Efeitos sonoros do Álbum de Cartas e do anúncio de carta nova (B08).
## Um player por som, com polifonia, no barramento de Efeitos.

const SFX_DIR := "res://assets/audio/Small_Sound_Kit/Small Sound Kit/"

# nome: [arquivo, volume_db, pitch base]
const SOUNDS: Dictionary = {
	&"open": ["Doors/Drs_Open_Box_01.wav", -6.0, 1.05],
	&"close": ["Doors/Drs_Close_Box_01.wav", -9.0, 1.1],
	&"hover": ["Clothes/Leather_002.wav", -22.0, 1.45],
	&"select": ["Clothes/Leather_001.wav", -8.0, 1.15],
	&"filter": ["Clothes/Backpack_NRM_01.wav", -16.0, 1.3],
	&"flip": ["Clothes/Shirt_RUN_01.wav", -7.0, 1.25],
	&"locked": ["Doors/Drs_Close_Drawer_01.wav", -16.0, 1.4],
	&"unlock_whoosh": ["Magic/Mgc_Ice_Arrow_Cast_01.wav", -8.0, 1.1],
	&"unlock_reveal": ["Magic/Mgc_Glacier_Cast_01.wav", -5.0, 1.0],
	&"unlock_legendary": ["Magic/Mgc_Electric_Impact_01.wav", -8.0, 0.8],
}

var _players: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for id in SOUNDS:
		var entry: Array = SOUNDS[id]
		var stream := load(SFX_DIR + entry[0]) as AudioStream
		if stream == null:
			continue
		var p := AudioStreamPlayer.new()
		p.name = "Sfx_%s" % id
		p.stream = stream
		p.volume_db = entry[1]
		p.bus = &"Efeitos"
		p.max_polyphony = 3
		add_child(p)
		_players[id] = p

## Toca um som com leve variação de pitch para não soar repetitivo
func play(id: StringName, pitch_jitter: float = 0.06) -> void:
	var p: AudioStreamPlayer = _players.get(id)
	if p == null or not p.is_inside_tree():
		return
	p.pitch_scale = SOUNDS[id][2] * randf_range(1.0 - pitch_jitter, 1.0 + pitch_jitter)
	p.play()
