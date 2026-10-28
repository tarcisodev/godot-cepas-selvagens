class_name ForgeStation
extends Node3D

## Bigorna do acampamento (GDD-06 §6): [E] abre a tela de forja. Com a Forja Pública da vila
## pronta, o crítico de forja ganha +10%.

const _WorldLabel = preload("res://scripts/ui/world_label.gd")
const USE_RANGE: float = 3.0

var city: Node
var _screen: ForgeScreen
var _prompt: _WorldLabel

func _ready() -> void:
	add_to_group("talkable")
	add_to_group("forge_station")
	var layer := CanvasLayer.new()
	layer.layer = 12
	add_child(layer)
	_screen = ForgeScreen.new()
	layer.add_child(_screen)
	var title := _WorldLabel.make(_WorldLabel.Kind.NAME, "Bigorna", "⚒️")
	title.position.y = 1.6
	add_child(title)
	_prompt = _WorldLabel.make(_WorldLabel.Kind.PROMPT, "[E] Forjar")
	_prompt.use_range = USE_RANGE
	_prompt.position.y = 1.4
	add_child(_prompt)

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
