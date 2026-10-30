extends SceneTree

## Prints de revisão visual da tela do Diário do Caçador (B40 fase 4): capa, um capítulo,
## Páginas e Marcos, com um Diário de exemplo.
# Uso: godot --path . -s res://tools/diary_shots.gd -- <pasta_saida>

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const _DiaryScreen = preload("res://scripts/ui/diary_screen.gd")
const _ForgedItem = preload("res://scripts/data/forged_item.gd")
const SHOTS: Array[StringName] = [&"capa", &"forja", &"paginas", &"marcos"]

var _out: String = "user://"
var _screen: _DiaryScreen
var _frame: int = 0
var _shot: int = 0
var _ana: Node
var _bruno: Node

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	root.size = Vector2i(1280, 720)
	var ana := _player("Ana", Vector3.ZERO, 3)
	var bruno := _player("Bruno", Vector3(3, 0, 0), 2)
	_ana = ana
	_bruno = bruno
	var bg := ColorRect.new()
	bg.color = Color(0.18, 0.24, 0.2)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var layer := CanvasLayer.new()
	root.add_child(layer)
	layer.add_child(bg)
	_screen = _DiaryScreen.new()
	_screen.player = ana
	layer.add_child(_screen)

func _player(p_name: String, pos: Vector3, quality: int) -> Node:
	var p = PlayerScene.instantiate()
	p.set_meta("player_name", p_name)
	root.add_child(p)
	p._setup_components()
	p.set_physics_process(false)
	p.global_position = pos
	var item := _ForgedItem.new()
	item.display_name = "Lâmina de Osso"
	item.family = &"couro"
	item.quality = quality
	p.inventory.equipped_items[_ForgedItem.Slot.MAIN_HAND] = item
	return p

func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == 3 and _shot == 0:
		_fill()
	if _frame == 5 and not _screen.visible:
		_screen.open()
	if _frame == 10:
		_screen.select_tab(SHOTS[_shot])
	elif _frame == 25:
		var img := root.get_texture().get_image()
		var path := _out.path_join("diario_%s.png" % SHOTS[_shot])
		img.save_png(path)
		print("salvo: ", path)
		_shot += 1
		_frame = 0
		if _shot >= SHOTS.size():
			quit(0)
	return false

## Depois do _ready: o Diário só escuta o EventBus quando já está na árvore
func _fill() -> void:
	for i in 6:
		EventBusAutoload.report(_ana, &"forja", {"item": ["Lâmina de Osso", "Gibão de Couro", "Elmo de Ferro"][i % 3], "family": ["couro", "pano", "ferro"][i % 3], "quality": 2 + i % 3})
	for i in 4:
		EventBusAutoload.report(_ana, &"cozinha", {"result": "ensopado_campeiro", "quality": 3})
	EventBusAutoload.report(_ana, &"coleta", {"material": "minerio_ferro", "amount": 30, "quality": 2})
	EventBusAutoload.report(_ana, &"venda", {"money": 120, "item": "Lâmina de Osso"})
	CombatResolver.resolve_hit(HitEvent.new(_ana, _bruno, 5000.0, DamageType.Type.SLASH, 0.0))
	_ana.diary.ledger.set_title("Aprendiz de Bigorna")
	_ana.play_time = 3.0 * 3600.0 + 25.0 * 60.0
