class_name WildChest
extends Node3D

## Baú de Tesouro do Ermo (GDD-05 §3 e GDD-03 §8).
## Localizado em ruínas e zonas perigosas de caça.
## Ao ser aberto, recompensa o jogador com:
## 1. Equipamento forjado orgânico vindo diretamente do fluxo do Mercado Negro.
## 2. Moeda em Dólares de Sucata ($S).
## 3. Materiais de caça nobres / solventes biológicos.
## 4. Carta colecionável 3D para o álbum do jogador (GDD-07).

const _BlackMarketSystem = preload("res://scripts/systems/black_market_system.gd")
const _ForgedItem = preload("res://scripts/data/forged_item.gd")
const _InventoryComponent = preload("res://scripts/components/inventory_component.gd")
const _WalletComponent = preload("res://scripts/components/wallet_component.gd")
const _CardCollectionComponent = preload("res://scripts/components/card_collection_component.gd")

signal chest_opened(chest: WildChest, player: Node, rewards: Dictionary)

@export var chest_id: StringName = &"wild_chest_1"
@export var reward_money: int = 35
@export var guaranteed_card_id: StringName = &"trenchcoat_mushrooms"
## Nome no aviso ao abrir (as ilhas voadoras têm baús próprios, GDD-18 §9)
@export var chest_title: String = "Baú do Ermo"
## Material raro que vem junto (quantidade e qualidade)
@export var reward_material: StringName = &"oleo_peixe"
@export var reward_material_qty: int = 2
@export var reward_material_quality: int = 3
## Assenta no terreno do vale ao nascer; desligado nas ilhas voadoras
@export var snap_to_ground: bool = true

var is_opened: bool = false
var _lid: Node3D
var _prompt: Label3D
var _rune_light: OmniLight3D

func _ready() -> void:
	add_to_group("talkable")
	add_to_group("wild_chests")
	_build_visuals()
	if snap_to_ground:
		_snap_to_ground.call_deferred()

func _snap_to_ground() -> void:
	var landscape := get_tree().current_scene.get_node_or_null("Landscape") if (is_inside_tree() and get_tree().current_scene) else null
	if landscape and landscape.has_method("get_height_at"):
		global_position.y = landscape.get_height_at(global_position.x, global_position.z)

func _build_visuals() -> void:
	var dark_iron := StandardMaterial3D.new()
	dark_iron.albedo_color = Color(0.18, 0.18, 0.22)
	dark_iron.metallic = 0.8
	dark_iron.roughness = 0.5

	var dark_wood := StandardMaterial3D.new()
	dark_wood.albedo_color = Color(0.25, 0.16, 0.12)
	dark_wood.roughness = 0.85

	var bronze_trim := StandardMaterial3D.new()
	bronze_trim.albedo_color = Color(0.65, 0.45, 0.2)
	bronze_trim.metallic = 0.85
	bronze_trim.roughness = 0.35

	# Base do baú
	var base := MeshInstance3D.new()
	var base_mesh := BoxMesh.new()
	base_mesh.size = Vector3(1.2, 0.6, 0.8)
	base.mesh = base_mesh
	base.material_override = dark_wood
	base.position.y = 0.3
	add_child(base)

	# Cantoneiras de ferro
	for x_side in [-0.58, 0.58]:
		var trim := MeshInstance3D.new()
		var trim_mesh := BoxMesh.new()
		trim_mesh.size = Vector3(0.08, 0.62, 0.82)
		trim.mesh = trim_mesh
		trim.material_override = dark_iron
		trim.position = Vector3(x_side, 0.3, 0)
		add_child(trim)

	# Pivô da tampa (articulada)
	_lid = Node3D.new()
	_lid.position = Vector3(0, 0.6, -0.4)
	add_child(_lid)

	var lid_mesh_inst := MeshInstance3D.new()
	var lid_mesh := BoxMesh.new()
	lid_mesh.size = Vector3(1.24, 0.22, 0.84)
	lid_mesh_inst.mesh = lid_mesh
	lid_mesh_inst.material_override = bronze_trim
	lid_mesh_inst.position = Vector3(0, 0.11, 0.4)
	_lid.add_child(lid_mesh_inst)

	# Fechadura rúnica brilhante
	_rune_light = OmniLight3D.new()
	_rune_light.light_color = Color(0.75, 0.25, 0.95)
	_rune_light.light_energy = 0.85
	_rune_light.omni_range = 2.5
	_rune_light.position = Vector3(0, 0.4, 0.45)
	add_child(_rune_light)

	# Prompt flutuante
	_prompt = Label3D.new()
	_prompt.text = "📦 [E] Abrir %s" % chest_title
	_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt.font_size = 14
	_prompt.outline_size = 4
	_prompt.modulate = Color(0.9, 0.7, 1.0)
	_prompt.position.y = 1.0
	_prompt.visible = false
	add_child(_prompt)

func _process(_delta: float) -> void:
	if not is_inside_tree() or _prompt == null:
		return
	var p := get_tree().get_first_node_in_group("player") as Node3D
	_prompt.visible = p != null and p.global_position.distance_to(global_position) < 3.2 and not is_opened

func talk_to(player: Node) -> void:
	if is_opened:
		if player and player.has_signal("posture_changed"):
			player.posture_changed.emit("📦 %s: Este baú já foi saqueado." % chest_title)
		return
	
	open_chest(player)

func open_chest(player: Node) -> Dictionary:
	if is_opened:
		return {}

	is_opened = true
	if _prompt:
		_prompt.visible = false
	if _rune_light:
		_rune_light.light_energy = 0.2

	# Animação suave de abertura da tampa
	if _lid:
		var tw := create_tween()
		tw.tween_property(_lid, "rotation:x", deg_to_rad(-75.0), 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	var inv: _InventoryComponent = _get_inventory(player)
	var wallet: _WalletComponent = _get_wallet(player)
	var card_col: _CardCollectionComponent = _get_card_collection(player)

	var rewards := {
		"gear": null,
		"money": reward_money,
		"material": reward_material,
		"material_qty": reward_material_qty,
		"card_unlocked": false
	}

	# 1. Equipamento Orgânico vindo do Mercado Negro
	var bm_sys := _BlackMarketSystem.get_instance(get_tree() if is_inside_tree() else null)
	var gear: _ForgedItem = null
	if bm_sys:
		gear = bm_sys.take_organic_loot()
	else:
		# Fallback direto se sistema não estiver na árvore
		gear = _ForgedItem.new()
		gear.recipe_id = &"espada_ferro"
		gear.display_name = "Espada de Ferro dos Ermos"
		gear.slot = _ForgedItem.Slot.MAIN_HAND
		gear.family = &"ferro"
		gear.quality = 2
	
	if gear and inv:
		inv.add_item(gear)
		rewards["gear"] = gear

	# 2. Dólares de Sucata
	if wallet and reward_money > 0:
		wallet.add(reward_money)

	# 3. Materiais raros de caça
	if inv:
		inv.add_material(rewards.material, rewards.material_qty, reward_material_quality, [&"puro"])

	# 4. Carta Colecionável 3D (GDD-07)
	if card_col and not guaranteed_card_id.is_empty():
		rewards["card_unlocked"] = card_col.unlock_card(guaranteed_card_id, true)

	# Feedback ao jogador
	if player and player.has_signal("posture_changed"):
		var gear_name: String = gear.display_name if gear else "Equipamento"
		player.posture_changed.emit("✨ %s aberto! Encontrado: %s + %d $S!" % [chest_title, gear_name, reward_money])

	chest_opened.emit(self, player, rewards)
	return rewards

func to_dict() -> Dictionary:
	return {
		"id": String(chest_id),
		"opened": is_opened,
		"money": reward_money
	}

func from_dict(d: Dictionary) -> void:
	chest_id = StringName(d.get("id", chest_id))
	is_opened = bool(d.get("opened", false))
	reward_money = int(d.get("money", reward_money))
	if is_opened and _lid:
		_lid.rotation.x = deg_to_rad(-75.0)
		if _rune_light:
			_rune_light.light_energy = 0.2

func _get_inventory(node: Node) -> _InventoryComponent:
	if node == null:
		return null
	if "inventory" in node and node.inventory is _InventoryComponent:
		return node.inventory as _InventoryComponent
	if node.has_node("InventoryComponent"):
		return node.get_node("InventoryComponent") as _InventoryComponent
	for child in node.get_children():
		if child is _InventoryComponent:
			return child as _InventoryComponent
	return null

func _get_wallet(node: Node) -> _WalletComponent:
	if node == null:
		return null
	if "wallet" in node and node.wallet is _WalletComponent:
		return node.wallet as _WalletComponent
	if node.has_node("WalletComponent"):
		return node.get_node("WalletComponent") as _WalletComponent
	for child in node.get_children():
		if child is _WalletComponent:
			return child as _WalletComponent
	return null

func _get_card_collection(node: Node) -> _CardCollectionComponent:
	if node == null:
		return null
	if "card_collection" in node and node.card_collection is _CardCollectionComponent:
		return node.card_collection as _CardCollectionComponent
	if node.has_node("CardCollectionComponent"):
		return node.get_node("CardCollectionComponent") as _CardCollectionComponent
	for child in node.get_children():
		if child is _CardCollectionComponent:
			return child as _CardCollectionComponent
	return null
