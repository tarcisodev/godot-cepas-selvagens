extends SceneTree

## Captura da tela de inventário isolada, com um estoque de exemplo, para revisão visual.
# Uso: godot --path . -s res://tools/inventory_screenshot.gd -- <saida.png> [ordem] [borda] [grupo]
# ordem: 0 raridade · 1 quantidade · 2 peso · 3 cor · 4 nome | borda: 0 raridade · 1 grupo | grupo: -1 todos, 0..4

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")

var _out_path: String = "user://inventory.png"
var _frames_left: int = 40

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out_path = args[0]
	if args.size() > 1:
		InventoryScreen.sort_mode = int(args[1]) as InventoryScreen.SortMode
	if args.size() > 2:
		InventoryScreen.border_mode = int(args[2]) as InventoryScreen.BorderMode
	if args.size() > 3:
		InventoryScreen.group_filter = int(args[3])

	var bg := ColorRect.new()
	bg.color = Color(0.16, 0.22, 0.18)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var layer := CanvasLayer.new()
	root.add_child(layer)
	layer.add_child(bg)

	var player: Player = PlayerScene.instantiate() as Player
	root.add_child(player)
	player._setup_components()
	var inv := player.inventory
	inv.add_material(&"madeira", 14)
	inv.add_material(&"madeira", 3, 2)
	inv.add_material(&"galho", 22)
	inv.add_material(&"folha", 9)
	inv.add_material(&"fibra", 12, 2)
	inv.add_material(&"pedra", 7)
	inv.add_material(&"frutinha", 5)
	inv.add_material(&"besouro", 3)
	inv.add_material(&"ossos", 4)
	inv.add_material(&"erva", 8, 2)
	inv.add_material(&"mel", 2)
	inv.add_material(&"chifre_rinolito", 1, 2)
	inv.add_material(&"chifre_rinolito", 1, 3, [&"integro"])
	inv.add_material(&"tendao_elastico", 1, 4)
	inv.add_material(&"placa_carapaca", 1, 5, [&"cicatrizado"])

	# Peças forjadas equipadas (GDD-12), para a coluna de equipamento com o boneco
	var rng := RandomNumberGenerator.new()
	for spec in [[&"cota_ferro", &"barra_ferro", 3, &"placa_carapaca", 2], [&"elmo_chifre_de_pedra", &"chifre_rinolito", 1, &"barra_ferro", 2],
			[&"botas_saltarelo", &"pele_saltarelo", 2, &"couro_trotador", 1], [&"capa_penas", &"pena_penacho", 4, &"fibra", 2],
			[&"mochila", &"couro_trotador", 2, &"tendao_elastico", 1], [&"espada_ferro", &"barra_ferro", 2, &"couro_trotador", 1],
			[&"escudo", &"barra_ferro", 2, &"placa_carapaca", 1], [&"gibao_andarilho", &"couro_trotador", 3, &"fibra", 4]]:
		inv.add_material(spec[1], spec[2], 3)
		inv.add_material(spec[3], spec[4], 3)
		var core: Dictionary = inv.get_stacks(spec[1]).filter(func(st): return st.amount >= spec[2])[0]
		var coat: Dictionary = inv.get_stacks(spec[3]).filter(func(st): return st.amount >= spec[4])[0]
		var item := Forge.forge(inv, spec[0], core, coat, {}, 1, false, rng)
		if item:
			inv.add_item(item)
			if spec[0] != &"gibao_andarilho":
				inv.equip(item)

	_screen = InventoryScreen.new()
	_screen.player = player
	layer.add_child(_screen)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

var _screen: InventoryScreen

func _process(_delta: float) -> bool:
	# Abre só no primeiro frame: no _initialize o _ready dos nós ainda não rodou
	if not _screen.visible:
		_screen.open()
	_frames_left -= 1
	if _frames_left == 0:
		var img := root.get_texture().get_image()
		img.save_png(_out_path)
		print("Inventário salvo em ", ProjectSettings.globalize_path(_out_path) if _out_path.begins_with("user://") else _out_path)
		quit(0)
	return false
