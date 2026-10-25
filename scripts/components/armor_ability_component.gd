class_name ArmorAbilityComponent
extends Node

## Habilidades de armadura do jogador (GDD-12 §6.3): cabeça [4], peito [5] e botas [R]. A habilidade
## de cada tecla vem da peça equipada (família ou parte de criatura). Cada uma tem custo e recarga;
## os efeitos que duram são modificadores do StatsComponent com fonte própria ou estados lidos pelo
## Player (Véu, Esquivo, Firmeza). Também cuida das passivas da capa (queda lenta, abrigo).
## Nada aqui mexe no tempo do mundo (ADR-0006).

signal ability_used(slot: int, id: StringName)
signal cooldowns_changed()

const VEIL_ABSORB: float = 40.0
const DASH_DISTANCE: float = 6.0
const DASH_TIME: float = 0.16
const TAUNT_RANGE: float = 10.0
const STEADFAST_DAMAGE_MULT: float = 0.7
const FREE_DODGE_IFRAMES: float = 0.45
const SHELTER_VIGOR_REGEN: float = 2.0

var player: Player
## Recarga restante por habilidade (s)
var cooldowns: Dictionary = {}
## Escudo de Éter que ainda absorve (Véu)
var veil_hp: float = 0.0
var _veil_time: float = 0.0
var _veil_mesh: MeshInstance3D
var _free_dodge_time: float = 0.0
var _steadfast_time: float = 0.0
## Fontes dos buffs temporários: id -> {source, time}
var _buffs: Dictionary = {}
var _shelter_source := RefCounted.new()
var _shelter_on: bool = false
var _dash_tween: Tween

static var _investida: StyleAttack
static var _pisao: StyleAttack

func _ready() -> void:
	if player == null:
		player = get_parent() as Player

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	for slot in ArmorAbilities.SLOT_KEYS:
		if (event as InputEventKey).keycode == ArmorAbilities.SLOT_KEYS[slot]:
			if _blocked_by_ui():
				return
			use_slot(slot)
			get_viewport().set_input_as_handled()
			return

func _blocked_by_ui() -> bool:
	var tree := get_tree()
	if tree == null:
		return false
	if not tree.get_nodes_in_group("open_menus").is_empty():
		return true
	var bs := tree.get_first_node_in_group("building_system")
	return bs != null and bool(bs.get("is_building"))

## Habilidade que a peça do encaixe dá agora (vazio = sem peça ou peça quebrada)
func ability_in(slot: int) -> StringName:
	if player == null or player.inventory == null:
		return &""
	var it: ForgedItem = player.inventory.equipped_in(slot)
	if it == null or it.is_broken():
		return &""
	return it.ability_id()

func cooldown_left(id: StringName) -> float:
	return float(cooldowns.get(id, 0.0))

## Usa a habilidade do encaixe. Devolve "" se usou, ou o motivo.
func use_slot(slot: int) -> String:
	var id := ability_in(slot)
	if id == &"":
		return _fail("Sem peça com habilidade em %s" % ForgedItem.SLOT_NAMES[slot])
	if cooldown_left(id) > 0.0:
		return _fail("%s recarregando (%.0f s)" % [ArmorAbilities.info(id).name, ceilf(cooldown_left(id))])
	if player.is_downed or player.is_stunned() or player.is_sitting or player.is_swimming or player.mounted_on:
		return _fail("Agora não dá")
	var info := ArmorAbilities.info(id)
	if not _can_pay(info):
		return _fail("Falta %s para %s" % ["Éter" if info.pool == &"ether" else "Vigor", info.name])
	if not _activate(id):
		return _fail("Agora não dá")
	_pay(info)
	cooldowns[id] = float(info.cooldown)
	ability_used.emit(slot, id)
	cooldowns_changed.emit()
	player.posture_changed.emit("%s %s" % [info.icon, info.name])
	return ""

func _fail(msg: String) -> String:
	if player:
		player.posture_changed.emit("❌ " + msg)
	return msg

func _can_pay(info: Dictionary) -> bool:
	var pools := player.pools
	if pools == null or info.pool == &"":
		return true
	return (pools.current_ether if info.pool == &"ether" else pools.current_vigor) >= float(info.cost)

func _pay(info: Dictionary) -> void:
	if player.pools == null or info.pool == &"":
		return
	if info.pool == &"ether":
		player.pools.consume_ether(float(info.cost))
	else:
		player.pools.consume_vigor(float(info.cost))

func _activate(id: StringName) -> bool:
	match id:
		&"foco":
			_buff(id, 5.0, [ModifierData.new(&"ether_regen", ModifierData.Op.PCT_ADD, 1.0)])
		&"faro":
			_buff(id, 8.0, [ModifierData.new(&"damage_bonus", ModifierData.Op.FLAT, 0.2)])
		&"brado":
			_buff(id, 6.0, [ModifierData.new(&"poise_resist", ModifierData.Op.FLAT, 0.3)])
			for m in get_tree().get_nodes_in_group("monsters"):
				if m is Node3D and (m as Node3D).global_position.distance_to(player.global_position) <= TAUNT_RANGE and m.has_method("taunt"):
					m.taunt(player)
		&"investida":
			return player.cast_attack(_investida_attack())
		&"veu":
			veil_hp = VEIL_ABSORB
			_veil_time = 6.0
			_show_veil(true)
		&"esquivo":
			_free_dodge_time = 6.0
		&"firmeza":
			_steadfast_time = 3.0
		&"rajada":
			return _dash()
		&"disparada":
			_buff(id, 4.0, [ModifierData.new(&"move_speed_bonus", ModifierData.Op.FLAT, 0.4)])
		&"pisao":
			return player.cast_attack(_pisao_attack())
		_:
			return false
	return true

func _buff(id: StringName, time: float, mods: Array) -> void:
	_clear_buff(id)
	var src := RefCounted.new()
	for m in mods:
		(m as ModifierData).source = src
		player.stats.add_modifier(m)
	_buffs[id] = {"source": src, "time": time}

func _clear_buff(id: StringName) -> void:
	if _buffs.has(id):
		player.stats.remove_modifiers_from_source(_buffs[id].source)
		_buffs.erase(id)

func has_buff(id: StringName) -> bool:
	return _buffs.has(id)

func _process(delta: float) -> void:
	if player == null:
		return
	var changed := false
	for id in cooldowns.keys():
		cooldowns[id] = maxf(0.0, cooldowns[id] - delta)
		if cooldowns[id] <= 0.0:
			cooldowns.erase(id)
			changed = true
	if changed:
		cooldowns_changed.emit()
	for id in _buffs.keys():
		_buffs[id].time -= delta
		if _buffs[id].time <= 0.0:
			_clear_buff(id)
	if _veil_time > 0.0:
		_veil_time -= delta
		if _veil_time <= 0.0 or veil_hp <= 0.0:
			_end_veil()
	_free_dodge_time = maxf(0.0, _free_dodge_time - delta)
	_steadfast_time = maxf(0.0, _steadfast_time - delta)
	if player.is_downed:
		_end_all()
	_update_shelter()

func _end_all() -> void:
	for id in _buffs.keys():
		_clear_buff(id)
	_end_veil()
	_free_dodge_time = 0.0
	_steadfast_time = 0.0

# ---------------------------------------------------------------- ganchos lidos pelo Player

## Antes da mitigação: Véu absorve, Firmeza segura Postura e corta 30% do dano
func filter_hit(hit: HitEvent) -> void:
	if _steadfast_time > 0.0:
		hit.raw_damage *= STEADFAST_DAMAGE_MULT
		hit.poise_damage = 0.0
	if veil_hp > 0.0 and hit.raw_damage > 0.0:
		var taken := minf(veil_hp, hit.raw_damage)
		veil_hp -= taken
		hit.raw_damage -= taken
		if veil_hp <= 0.0:
			_end_veil()

## Super armor (Firmeza): golpe não faz o personagem recuar
func is_steadfast() -> bool:
	return _steadfast_time > 0.0

## Esquivo: gasta a esquiva grátis se houver. Devolve os i-frames dela (0 = esquiva normal)
func take_free_dodge() -> float:
	if _free_dodge_time <= 0.0:
		return 0.0
	_free_dodge_time = 0.0
	return FREE_DODGE_IFRAMES

## Passiva da capa equipada (&"queda_lenta", &"abrigo" ou vazio)
func cape_passive() -> StringName:
	if player == null or player.inventory == null:
		return &""
	var cape: ForgedItem = player.inventory.equipped_in(ForgedItem.Slot.CAPE)
	if cape == null or cape.is_broken():
		return &""
	return cape.recipe().get("passive", &"")

## Abrigo: +2 regen. de Vigor à noite (18h30–6h) ou com chuva
func _update_shelter() -> void:
	var want := false
	if cape_passive() == &"abrigo":
		var sun := DayNightCycle.instance
		var night: bool = sun != null and (sun.current_time_hours >= 18.5 or sun.current_time_hours < 6.0)
		var weather := get_tree().get_first_node_in_group("weather") if get_tree() else null
		var raining: bool = weather != null and float(weather.get("rain")) > 0.2
		want = night or raining
	if want == _shelter_on:
		return
	_shelter_on = want
	player.stats.remove_modifiers_from_source(_shelter_source)
	if want:
		player.stats.add_modifier(ModifierData.new(&"vigor_regen", ModifierData.Op.FLAT, SHELTER_VIGOR_REGEN, _shelter_source))

# ---------------------------------------------------------------- efeitos com corpo

func _show_veil(on: bool) -> void:
	if on and _veil_mesh == null:
		_veil_mesh = MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.85
		sphere.height = 2.0
		_veil_mesh.mesh = sphere
		var mat := StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(0.45, 0.75, 1.0, 0.18)
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_veil_mesh.material_override = mat
		_veil_mesh.position.y = 0.95
		player.add_child(_veil_mesh)
	if _veil_mesh:
		_veil_mesh.visible = on

func _end_veil() -> void:
	veil_hp = 0.0
	_veil_time = 0.0
	_show_veil(false)

## Rajada: avança 6 m para onde a câmera olha, atravessando monstros (só o terreno segura)
func _dash() -> bool:
	if not player.is_inside_tree():
		return false
	var dir: Vector3 = -player.visual_mesh.global_basis.z
	if player.camera_rig and not player.is_first_person:
		dir = -player.camera_rig.global_basis.z
	dir.y = 0.0
	if dir.length_squared() < 0.001:
		return false
	dir = dir.normalized()
	var target: Vector3 = player.global_position + dir * DASH_DISTANCE
	var ground: float = player._ground_at(target.x, target.z)
	if ground < 999.0:
		target.y = maxf(target.y, ground + 0.1)
	if not WorldBounds.inside(target.x, target.z, 2.0):
		return false
	var old_mask := player.collision_mask
	player.collision_mask = 1 # só o terreno
	if _dash_tween and _dash_tween.is_valid():
		_dash_tween.kill()
	_dash_tween = player.create_tween()
	_dash_tween.tween_property(player, "global_position", target, DASH_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_dash_tween.tween_callback(func(): player.collision_mask = old_mask)
	return true

static func _investida_attack() -> StyleAttack:
	if _investida == null:
		_investida = StyleAttack.new()
		_investida.kind = StyleAttack.Kind.LUNGE
		_investida.display_name = "Investida"
		_investida.anims = [&"Shield_Dash"]
		_investida.duration = 0.75
		_investida.hit_delay = 0.18
		_investida.active_time = 0.35
		_investida.damage = 30.0
		_investida.damage_type = DamageType.Type.IMPACT
		_investida.poise_damage = 35.0
		_investida.break_mult = 1.8
		_investida.cost = 0.0
		_investida.move_mult = 0.0
		_investida.lunge_speed = 13.0
	return _investida

static func _pisao_attack() -> StyleAttack:
	if _pisao == null:
		_pisao = StyleAttack.new()
		_pisao.kind = StyleAttack.Kind.AREA
		_pisao.display_name = "Pisão"
		_pisao.anims = [&"NinjaJump_Land"]
		_pisao.duration = 0.6
		_pisao.hit_delay = 0.22
		_pisao.active_time = 0.2
		_pisao.damage = 18.0
		_pisao.damage_type = DamageType.Type.IMPACT
		_pisao.poise_damage = 40.0
		_pisao.break_mult = 1.4
		_pisao.reach = 3.5
		_pisao.cost = 0.0
		_pisao.move_mult = 0.0
	return _pisao
