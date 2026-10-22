class_name ForgeStation
extends Node3D

## Bigorna do acampamento (GDD-06 §6): [E] abre a tela de forja. Com a Forja Pública da vila
## pronta, o crítico de forja ganha +10%.

const USE_RANGE: float = 3.0

var city: Node
var _screen: ForgeScreen
var _prompt: Label3D

func _ready() -> void:
	add_to_group("talkable")
	add_to_group("forge_station")
	var layer := CanvasLayer.new()
	layer.layer = 12
	add_child(layer)
	_screen = ForgeScreen.new()
	layer.add_child(_screen)
	_prompt = Label3D.new()
	_prompt.text = "⚒️ [E] Forjar"
	_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt.font_size = 14
	_prompt.outline_size = 4
	_prompt.modulate = Color(1.0, 0.75, 0.45)
	_prompt.position.y = 1.4
	_prompt.visible = false
	add_child(_prompt)

func _process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D if is_inside_tree() else null
	_prompt.visible = player != null and player.global_position.distance_to(global_position) < USE_RANGE

func talk_to(player: Node) -> void:
	open_for(player as Player)

func open_for(player: Player) -> void:
	var forja = city.get_project(&"forja") if city and city.has_method("get_project") else null
	_screen.open(player, forja != null and forja.is_complete())

## A bigorna mais próxima ao alcance, ou null (o botão de forja do [Tab] só funciona perto dela)
static func nearest_in_range(player: Node3D) -> ForgeStation:
	for n in player.get_tree().get_nodes_in_group("forge_station"):
		var st := n as ForgeStation
		if st and st.global_position.distance_to(player.global_position) < USE_RANGE + 1.0:
			return st
	return null
