class_name WorldTradePack
extends StaticBody3D

## Prop Físico no Mundo 3D de um Fardo Comercial derrubado ou descarregado (GDD-05 §2).
## Permite ao jogador ou transeuntes recolherem o fardo do chão com [E].

const _TradePackData = preload("res://scripts/data/trade_pack_data.gd")

var pack_data: _TradePackData = null

var label_prompt: Label3D

func _ready() -> void:
	add_to_group("trade_packs")
	add_to_group("talkable")
	_build_visual()
	_build_label()

func set_pack(data: _TradePackData) -> void:
	pack_data = data
	_update_label()

func _build_visual() -> void:
	# Colisão de caixa
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.9, 0.65, 0.7)
	col.shape = box
	col.position.y = 0.35
	add_child(col)
	
	# Caixa de madeira reforçada
	var crate := MeshInstance3D.new()
	var cube := BoxMesh.new()
	cube.size = Vector3(0.9, 0.65, 0.7)
	crate.mesh = cube
	crate.position.y = 0.35
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.48, 0.32, 0.18)
	mat.roughness = 0.85
	crate.material_override = mat
	add_child(crate)
	
	# Cintas de amarração / Cordas
	var strap := MeshInstance3D.new()
	var strap_cube := BoxMesh.new()
	strap_cube.size = Vector3(0.94, 0.67, 0.15)
	strap.mesh = strap_cube
	strap.position.y = 0.35
	var strap_mat := StandardMaterial3D.new()
	strap_mat.albedo_color = Color(0.85, 0.75, 0.40) # Fita de cânhamo dourada
	strap.material_override = strap_mat
	add_child(strap)

func _build_label() -> void:
	label_prompt = Label3D.new()
	label_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label_prompt.font_size = 20
	label_prompt.outline_size = 5
	label_prompt.outline_modulate = Color(0, 0, 0, 0.9)
	label_prompt.modulate = Color(0.95, 0.85, 0.45)
	label_prompt.visibility_range_end = 8.0
	label_prompt.position.y = 0.95
	add_child(label_prompt)
	_update_label()

func _update_label() -> void:
	if label_prompt:
		var p_name := pack_data.pack_name if pack_data else "Fardo Comercial"
		var stars := "★".repeat(pack_data.quality) if pack_data else "★"
		label_prompt.text = "📦 %s (%s)\n[E] Carregar Fardo" % [p_name, stars]

## Interação ao apertar [E]
func talk_to(player: Node) -> void:
	if player == null or pack_data == null:
		return
	
	# Se o jogador já estiver carregando outro fardo, não pode carregar dois
	if player.has_meta("carrying_trade_pack") and player.get_meta("carrying_trade_pack") != null:
		if player.has_signal("posture_changed"):
			player.posture_changed.emit("⚠️ Você já está carregando um Fardo Comercial nas costas!")
		return
	
	# Entrega o fardo ao jogador
	player.set_meta("carrying_trade_pack", pack_data)
	if player.has_signal("posture_changed"):
		player.posture_changed.emit("📦 Fardo carregado nas costas! Viagem Rápida bloqueada. Siga pela estrada.")
	
	queue_free()
