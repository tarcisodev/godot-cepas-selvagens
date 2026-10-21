extends SceneTree

## Captura do Álbum de Cartas isolado, para revisão visual.
# Uso: godot --path . -s res://tools/album_screenshot.gd -- <saida.png> [card_id] [espera_ms] [modo]
# modo: flip (vira a carta) | toast (álbum fechado, anuncia card_id como descoberta nova)
#       | rarityN (filtra pela raridade N, 1-4) | new (descobre card_id e abre o álbum: selo NOVA)

const AlbumScene: PackedScene = preload("res://scenes/card_album.tscn")

var _out_path: String = "user://album.png"
var _card_id: StringName = &""
var _wait_ms: int = 1500
var _start_ms: int = -1
var _mode: String = ""
var _album: CardAlbum
var _collection: CardCollectionComponent
var _started: bool = false

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out_path = args[0]
	if args.size() > 1:
		_card_id = StringName(args[1])
	if args.size() > 2:
		_wait_ms = int(args[2])
	if args.size() > 3:
		_mode = args[3]

	_collection = CardCollectionComponent.new()
	root.add_child(_collection)
	if _mode != "toast":
		_collection.unlock_card(&"beast_horn", false)
		_collection.unlock_card(&"fireball", false)
	_album = AlbumScene.instantiate() as CardAlbum
	_album.collection_component = _collection
	root.add_child.call_deferred(_album)

func _start() -> void:
	_started = true
	if _mode == "toast":
		# Espera o álbum ligar o sinal (deferred) antes de descobrir a carta
		await process_frame
		_collection.unlock_card(_card_id)
		return
	if _mode == "new":
		_collection.unlock_card(&"mimic")
		await process_frame
		_album.open_album()
		return
	_album.open_album()
	if _mode.begins_with("rarity"):
		_album._on_rarity_button_pressed(int(_mode.substr(6)))
	if not _card_id.is_empty():
		var card := CardDatabase.get_card(_card_id)
		if _collection.is_card_unlocked(_card_id):
			_album.select_card(card)
		else:
			_album._show_locked_details(card)
	if _mode == "flip":
		_album.card_3d_stage.toggle_flip()

func _process(_delta: float) -> bool:
	if _album.is_inside_tree() and not _started:
		_start_ms = Time.get_ticks_msec()
		_start()
	# Espera por tempo, não por frames: sem vsync os frames passam rápido demais para as animações
	if _start_ms < 0 or Time.get_ticks_msec() - _start_ms < _wait_ms:
		return false
	var image := root.get_texture().get_image()
	image.save_png(_out_path)
	print("Screenshot salvo em: ", _out_path)
	return true
