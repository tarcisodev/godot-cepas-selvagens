class_name TorchComponent
extends Node

## Tocha (GDD-03 §9): luz na mão esquerda para atravessar a noite. [T] acende ou apaga a qualquer
## hora (também pela roda rápida, [G]); sem tocha na mochila mas com material, [T] já faz uma na
## hora e acende. Cada tocha queima BURN_TIME segundos acesa (apagar guarda o que sobrou); quando
## acaba, a próxima da mochila pega sozinha. Água apaga. Fumaça acalma as abelhas do mel.
## Nada desacelera o tempo: acender é instantâneo, mas a luz só vale enquanto houver tocha.
## A tocha acesa ocupa a mão secundária (GDD-12 §3): o escudo não vale enquanto ela queima, e
## com arma de duas mãos não sobra mão para ela.

signal lit_changed(lit: bool)

const KEY_TORCH: Key = KEY_T
const ITEM: StringName = &"tocha"
## Segundos de luz por tocha: um pouco mais que uma noite inteira do ciclo padrão (300 s/dia)
const BURN_TIME: float = 150.0
const LIGHT_RANGE: float = 12.0
const LIGHT_ENERGY: float = 2.4
const LIGHT_COLOR := Color(1.0, 0.64, 0.32)
## Hora em que o aviso do anoitecer aparece (uma vez por noite)
const DUSK_HOUR: float = 18.3
## Peça na mão, nos eixos do osso em pose de descanso (mesma convenção do escudo em hand_l)
const HAND_BONE: StringName = &"hand_l"
const MODEL_TRANSFORM := Transform3D(Vector3(0, 0, -0.6), Vector3(-0.6, 0, 0), Vector3(0, 0.6, 0), Vector3(0, 0.06, 0))
## Ponta da chama no espaço do modelo da tocha
const FLAME_TIP := Vector3(0, 0.88, 0)

var player: Player
var is_lit: bool = false
## Segundos que restam na tocha da mão (0 = a próxima acesa é nova)
var burn_left: float = 0.0

## Onde a tocha está presa: o osso da mão (BoneAttachment3D) ou, sem esqueleto, um nó no peito
var _socket: Node3D
var _model: Node3D
var _light: OmniLight3D
var _flame: CPUParticles3D
var _flicker_t: float = 0.0
var _warned_tonight: bool = false

## true se `who` carrega uma tocha acesa (abelhas, bichos que temem fogo)
static func is_lit_on(who: Node) -> bool:
	var t: TorchComponent = who.get_node_or_null("TorchComponent") as TorchComponent if who else null
	return t != null and t.is_lit

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo or event.keycode != KEY_TORCH:
		return
	if not get_tree().get_nodes_in_group("open_menus").is_empty():
		return
	toggle()
	get_viewport().set_input_as_handled()

## Acende ou apaga. Acender sem tocha faz uma se houver material. false se não deu.
func toggle() -> bool:
	if is_lit:
		set_lit(false)
		_say("🔥 Tocha apagada (guarda %d s de chama)" % ceili(burn_left))
		return true
	if player == null or player.inventory == null or player.is_downed:
		return false
	if player.is_swimming:
		_say("💧 Não dá para acender dentro d'água")
		return false
	var main: ForgedItem = player.inventory.equipped_in(ForgedItem.Slot.MAIN_HAND)
	if main and main.is_two_handed():
		_say("🔥 Com %s nas duas mãos não sobra mão para a tocha" % main.display_name)
		return false
	var inv := player.inventory
	if inv.get_material_count(ITEM) <= 0:
		if not inv.craft(ITEM):
			_say("🔥 Sem tocha: faça uma com %s" % recipe_text())
			return false
		_say("🔥 Fez uma Tocha e acendeu")
	else:
		_say("🔥 Tocha acesa · [T] apaga")
	if burn_left <= 0.0:
		burn_left = BURN_TIME
	set_lit(true)
	return true

func set_lit(on: bool) -> void:
	if on == is_lit:
		return
	is_lit = on
	if on:
		_ensure_visual()
	_apply_visibility()
	lit_changed.emit(on)
	# A mão secundária mudou: o escudo volta ou sai do estilo
	if player and player.has_method("refresh_weapon_style"):
		player.refresh_weapon_style()

func _process(delta: float) -> void:
	if player == null:
		return
	_dusk_hint()
	if not is_lit:
		return
	if player.is_swimming:
		set_lit(false)
		_say("💧 A água apagou a tocha")
		return
	# O esqueleto pode ser refeito (troca de visual): prende a tocha de novo
	if _socket == null or not is_instance_valid(_socket) or not _socket.is_inside_tree():
		_socket = null
		_ensure_visual()
		_apply_visibility()
	burn_left -= delta
	if burn_left <= 0.0:
		_burn_out()
		return
	_flicker(delta)

## A tocha da mão acabou: gasta uma da mochila e pega a próxima, se houver
func _burn_out() -> void:
	var inv := player.inventory
	inv.consume_materials({ITEM: 1})
	if inv.get_material_count(ITEM) > 0:
		burn_left = BURN_TIME
		_say("🔥 A tocha acabou; acendeu outra (restam %d)" % inv.get_material_count(ITEM))
	else:
		burn_left = 0.0
		set_lit(false)
		_say("🔥 A tocha queimou até o fim")

## Aviso uma vez por noite, só para quem está no escuro
func _dusk_hint() -> void:
	var sun := get_tree().current_scene.get_node_or_null("Sun") if get_tree().current_scene else null
	if sun == null or not "current_time_hours" in sun:
		return
	var h: float = sun.current_time_hours
	var night := h >= DUSK_HOUR or h < 5.0
	if not night:
		_warned_tonight = false
		return
	if _warned_tonight or is_lit:
		return
	_warned_tonight = true
	var inv := player.inventory
	if inv and inv.get_material_count(ITEM) > 0:
		_say("🌆 Escurecendo · [T] acende a tocha (tem %d)" % inv.get_material_count(ITEM))
	elif inv and inv.has_materials(InventoryComponent.RECIPES[ITEM]):
		_say("🌆 Escurecendo · [T] faz e acende uma tocha")
	else:
		_say("🌆 Escurecendo · junte %s para uma tocha" % recipe_text())

static func recipe_text() -> String:
	var parts: Array[String] = []
	for mat in InventoryComponent.RECIPES[ITEM]:
		parts.append("%d %s" % [InventoryComponent.RECIPES[ITEM][mat], MaterialData.of(mat).display_name])
	return " + ".join(parts)

func _say(msg: String) -> void:
	if player:
		player.posture_changed.emit(msg)

# ---------------------------------------------------------------- visual

func _flicker(delta: float) -> void:
	if _light == null:
		return
	_flicker_t += delta
	var n := sin(_flicker_t * 13.0) * 0.5 + sin(_flicker_t * 7.3 + 1.7) * 0.3 + sin(_flicker_t * 23.0) * 0.2
	_light.light_energy = LIGHT_ENERGY * (0.88 + 0.12 * n)
	_light.omni_range = LIGHT_RANGE * (0.96 + 0.04 * n)

func _apply_visibility() -> void:
	if _model:
		_model.visible = is_lit
	if _light:
		_light.visible = is_lit
	if _flame:
		_flame.emitting = is_lit
		_flame.visible = is_lit
	_set_offhand_visible(not is_lit)

## O escudo (ou o que estiver na mão esquerda) some enquanto a tocha está na mão
func _set_offhand_visible(on: bool) -> void:
	var cv := player.character_visual if player else null
	if cv == null or cv.skeleton == null:
		return
	for s in cv.skeleton.get_children():
		if s is BoneAttachment3D and s != _socket and s.bone_name == HAND_BONE:
			s.visible = on

func _ensure_visual() -> void:
	if _socket != null and is_instance_valid(_socket):
		return
	var cv := player.character_visual if player else null
	var tip_xf: Transform3D
	if cv and cv.skeleton and cv.skeleton.find_bone(HAND_BONE) >= 0:
		_socket = BoneAttachment3D.new()
		_socket.name = "TorchSocket"
		_socket.bone_name = HAND_BONE
		cv.skeleton.add_child(_socket)
		var rest := cv.skeleton.get_bone_global_rest(cv.skeleton.find_bone(HAND_BONE)).basis.orthonormalized()
		tip_xf = Transform3D(rest.inverse(), Vector3.ZERO) * MODEL_TRANSFORM
	else:
		# Sem esqueleto (testes, bonecos): a luz fica à frente do peito
		var holder := Node3D.new()
		holder.name = "TorchSocket"
		player.add_child(holder)
		holder.position = Vector3(-0.35, 1.2, 0.3)
		_socket = holder
		_build_parts(holder, Transform3D.IDENTITY)
		return
	_build_parts(_socket, tip_xf)

func _build_parts(parent: Node3D, model_xf: Transform3D) -> void:
	var scene := load("res://assets/models/tools/torch.gltf") as PackedScene
	_model = scene.instantiate() as Node3D if scene else Node3D.new()
	_model.transform = model_xf
	parent.add_child(_model)
	for mi in _model.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var tip := model_xf * FLAME_TIP
	_light = OmniLight3D.new()
	_light.name = "TorchLight"
	_light.light_color = LIGHT_COLOR
	_light.light_energy = LIGHT_ENERGY
	_light.omni_range = LIGHT_RANGE
	_light.omni_attenuation = 1.3
	# Sem sombra: muitas tochas no online custariam caro e a luz da mão quase não sombreia
	_light.shadow_enabled = false
	_light.position = tip + Vector3(0, 0.15, 0)
	parent.add_child(_light)
	_flame = _make_flame()
	_flame.position = tip
	parent.add_child(_flame)

func _make_flame() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "TorchFlame"
	p.amount = 18
	p.lifetime = 0.45
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.04
	p.direction = Vector3.UP
	p.spread = 12.0
	p.gravity = Vector3(0, 1.6, 0)
	p.initial_velocity_min = 0.25
	p.initial_velocity_max = 0.5
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.1
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1.0))
	curve.add_point(Vector2(1, 0.15))
	p.scale_amount_curve = curve
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.85, 0.4, 1.0))
	ramp.set_color(1, Color(0.9, 0.25, 0.05, 0.0))
	p.color_ramp = ramp
	var quad := QuadMesh.new()
	quad.size = Vector2(0.12, 0.16)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	quad.material = m
	p.mesh = quad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p
