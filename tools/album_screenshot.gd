extends SceneTree

## Captura do Álbum de Cartas isolado, para revisão visual.
# Uso: godot --path . -s res://tools/album_screenshot.gd -- <saida.png> [card_id] [frames] [flip]

const AlbumScene: PackedScene = preload("res://scenes/card_album.tscn")

var _out_path: String = "user://album.png"
var _card_id: StringName = &""
var _frames_left: int = 90
var _flip: bool = false
var _album: CardAlbum

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out_path = args[0]
	if args.size() > 1:
		_card_id = StringName(args[1])
	if args.size() > 2:
		_frames_left = int(args[2])
	if args.size() > 3:
		_flip = args[3] == "flip"

	var collection := CardCollectionComponent.new()
	root.add_child(collection)
	collection.unlock_card(&"beast_horn")
	collection.unlock_card(&"fireball")
	_album = AlbumScene.instantiate() as CardAlbum
	_album.collection_component = collection
	root.add_child.call_deferred(_album)

func _open() -> void:
	_album.open_album()
	if not _card_id.is_empty():
		var card := CardDatabase.get_card(_card_id)
		if _album.collection_component.is_card_unlocked(_card_id):
			_album.select_card(card)
		else:
			_album._show_locked_details(card)
	if _flip:
		_album.card_3d_stage.toggle_flip()

func _process(_delta: float) -> bool:
	if _album.is_inside_tree() and not _album.visible and _frames_left > 0:
		_open()
	_frames_left -= 1
	if _frames_left > 0:
		return false
	var image := root.get_texture().get_image()
	image.save_png(_out_path)
	print("Screenshot salvo em: ", _out_path)
	return true
