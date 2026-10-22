class_name SupplyChest
extends Node3D

## Baú de suprimentos do acampamento (teste de combate): [E] completa a mochila com o kit
## de consumíveis — ervas e poções (Vida), carnes (Vigor) e cannabis (Éter).
## Só repõe o que falta até a quantidade do kit, então dá para voltar sempre que esvaziar.
## É ferramenta de teste; a economia real dos consumíveis (cozinha, alquimia) vem depois.

## id do material → quantidade que o baú garante na mochila
@export var kit: Dictionary = {
	&"erva": 10,
	&"pocao": 5,
	&"mega_pocao": 2,
	&"carne_mal_passada": 5,
	&"carne_bem_passada": 5,
	&"carne_torrada": 5,
	&"cannabis_sativa": 5,
	&"cannabis_indica": 5,
}

const SIZE := Vector3(1.0, 0.55, 0.65)
const WOOD := Color(0.45, 0.28, 0.14)
const METAL := Color(0.75, 0.62, 0.3)

var _lid: Node3D
var _prompt: Label3D
var _lid_tween: Tween

func _ready() -> void:
	add_to_group("talkable")
	_build()
	_snap_to_ground.call_deferred()

func _snap_to_ground() -> void:
	var landscape := get_tree().current_scene.get_node_or_null("Landscape") if get_tree().current_scene else null
	if landscape and landscape.has_method("get_height_at"):
		global_position.y = landscape.get_height_at(global_position.x, global_position.z)

func _process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	_prompt.visible = player != null and player.global_position.distance_to(global_position) < Player.TALK_RANGE

## Chamado pelo player ao apertar [E] perto do baú.
func talk_to(player: Node) -> void:
	var inv: InventoryComponent = player.get("inventory") as InventoryComponent
	if inv == null:
		return
	var given := refill(inv)
	_open_lid()
	if player.has_signal("posture_changed"):
		if given.is_empty():
			player.posture_changed.emit("📦 Baú: a mochila já está cheia de suprimentos")
		else:
			player.posture_changed.emit("📦 Baú: " + ", ".join(given))

## Completa o inventário até o kit; devolve "Nome ×n" do que entrou.
func refill(inv: InventoryComponent) -> Array[String]:
	var given: Array[String] = []
	for id in kit.keys():
		var missing: int = int(kit[id]) - inv.get_material_count(id)
		if missing > 0:
			inv.add_material(id, missing)
			given.append("%s ×%d" % [MaterialData.of(id).display_name, missing])
	return given

func _open_lid() -> void:
	if _lid_tween:
		_lid_tween.kill()
	_lid_tween = create_tween()
	_lid_tween.tween_property(_lid, "rotation:x", deg_to_rad(-75.0), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_lid_tween.tween_interval(1.2)
	_lid_tween.tween_property(_lid, "rotation:x", 0.0, 0.35).set_trans(Tween.TRANS_SINE)

func _build() -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = SIZE + Vector3(0, 0.12, 0)
	shape.shape = box_shape
	shape.position.y = box_shape.size.y * 0.5
	body.add_child(shape)
	add_child(body)

	add_child(_box(Vector3(SIZE.x, SIZE.y, SIZE.z), Vector3(0, SIZE.y * 0.5, 0), WOOD))
	# Faixas de metal na frente
	for x in [-0.32, 0.32]:
		add_child(_box(Vector3(0.07, SIZE.y + 0.01, SIZE.z + 0.02), Vector3(x, SIZE.y * 0.5, 0), METAL))

	# Tampa articulada na borda de trás
	_lid = Node3D.new()
	_lid.position = Vector3(0, SIZE.y, -SIZE.z * 0.5)
	add_child(_lid)
	_lid.add_child(_box(Vector3(SIZE.x + 0.04, 0.12, SIZE.z + 0.04), Vector3(0, 0.06, SIZE.z * 0.5), WOOD.lightened(0.1)))
	_lid.add_child(_box(Vector3(0.14, 0.14, 0.05), Vector3(0, 0.0, SIZE.z + 0.03), METAL))

	_prompt = Label3D.new()
	_prompt.text = "[E] Baú de Suprimentos"
	_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt.font_size = 22
	_prompt.outline_size = 6
	_prompt.outline_modulate = Color(0, 0, 0, 0.8)
	_prompt.modulate = Color(1, 0.9, 0.6)
	_prompt.position.y = SIZE.y + 0.8
	_prompt.visible = false
	add_child(_prompt)

func _box(size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	mesh.material = mat
	mi.mesh = mesh
	mi.position = pos
	return mi
