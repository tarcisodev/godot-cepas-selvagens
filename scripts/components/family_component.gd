class_name FamilyComponent
extends Node

## Sistema de Família, Casamento e Ciclo de Vida do Jogador (GDD-14).
## Gerencia laço matrimonial, anel de votos (buff Laço de Votos),
## gestação de 9 meses e registro genealógico de filhos.

const _CharacterDNA = preload("res://scripts/data/character_dna.gd")
const _ModifierData = preload("res://scripts/data/modifier_data.gd")
const _StatsComponent = preload("res://scripts/components/stats_component.gd")
const _InventoryComponent = preload("res://scripts/components/inventory_component.gd")

signal married(spouse_name: String)
signal divorced(previous_spouse: String)
signal pregnancy_started(partner_name: String)
signal pregnancy_progressed(days: float, max_days: float)
signal labor_ready()
signal child_born(child_info: Dictionary)

## Gestação canônica: 9 lunações/meses (27 dias de jogo, GDD-14 §4.2)
const GESTATION_DAYS: float = 27.0

@export var spouse_name: String = ""
@export var spouse_id: int = 0
@export var spouse_dna: _CharacterDNA
@export var is_pregnant: bool = false
@export var pregnancy_days: float = 0.0
@export var partner_dna: _CharacterDNA
@export var partner_name: String = ""
@export var children: Array[Dictionary] = []

var _spouse_near: bool = false
var _stats: _StatsComponent
var _inv: _InventoryComponent
var _dna: _CharacterDNA

func _ready() -> void:
	var p := get_parent()
	if p:
		_stats = p.get_node_or_null("StatsComponent") as _StatsComponent
		_inv = p.get_node_or_null("InventoryComponent") as _InventoryComponent
		_dna = p.get("dna") as _CharacterDNA

func set_dna(new_dna: _CharacterDNA) -> void:
	_dna = new_dna

func is_married() -> bool:
	return not spouse_name.is_empty()

func is_spouse_near() -> bool:
	return _spouse_near

## Realiza o matrimônio e entrega a Aliança de Votos
func marry(p_spouse_name: String, p_spouse_dna: _CharacterDNA = null, p_spouse_id: int = 0) -> bool:
	if is_married():
		return false
	spouse_name = p_spouse_name
	spouse_dna = p_spouse_dna
	spouse_id = p_spouse_id
	if _inv and _inv.get_material_count(&"alianca_votos") == 0:
		_inv.add_material(&"alianca_votos", 1, 3, [&"laco_de_votos"])
	married.emit(spouse_name)
	return true

## Desfaz o casamento civil/religioso
func divorce() -> void:
	if not is_married():
		return
	var prev := spouse_name
	spouse_name = ""
	spouse_dna = null
	spouse_id = 0
	set_spouse_near(false)
	divorced.emit(prev)

## Concebe um filho com o parceiro
func conceive(p_partner_dna: _CharacterDNA, p_partner_name: String = "") -> bool:
	if is_pregnant:
		return false
	if not is_married():
		return false
	if _dna and not _dna.is_female():
		return false
	is_pregnant = true
	pregnancy_days = 0.0
	partner_dna = p_partner_dna
	partner_name = p_partner_name if not p_partner_name.is_empty() else spouse_name
	pregnancy_started.emit(partner_name)
	return true

## Avança a gestação no tempo do ciclo natural (GDD-10)
func advance_pregnancy(days: float) -> void:
	if not is_pregnant:
		return
	var was_ready := is_labor_ready()
	pregnancy_days = minf(GESTATION_DAYS, pregnancy_days + days)
	pregnancy_progressed.emit(pregnancy_days, GESTATION_DAYS)
	if not was_ready and is_labor_ready():
		labor_ready.emit()

func is_labor_ready() -> bool:
	return is_pregnant and pregnancy_days >= GESTATION_DAYS

## Realiza o parto no Berçário / Casa da Parteira (GDD-14 §4.3)
func give_birth(child_name: String, p_seed: int = 0) -> Dictionary:
	if not is_labor_ready():
		return {}
	var c_seed := p_seed if p_seed != 0 else randi()
	var f_dna := partner_dna if partner_dna else (spouse_dna if spouse_dna else _CharacterDNA.randomized(c_seed + 1))
	var m_dna := _dna if _dna else _CharacterDNA.randomized(c_seed + 2)
	var child_dna := _CharacterDNA.cross(f_dna, m_dna, c_seed)
	
	var child_dict: Dictionary = {
		"name": child_name,
		"dna": child_dna.to_dict(),
		"gender": int(child_dna.gender),
		"stage": int(child_dna.stage),
		"stage_name": "Criança",
		"mother": get_parent().name if _dna and _dna.is_female() else partner_name,
		"father": partner_name if _dna and _dna.is_female() else get_parent().name,
		"age_days": 0.0
	}
	children.append(child_dict)
	is_pregnant = false
	pregnancy_days = 0.0
	partner_dna = null
	partner_name = ""
	child_born.emit(child_dict)
	return child_dict

## Define proximidade física do cônjuge e atualiza o buff Laço de Votos
func set_spouse_near(near: bool) -> void:
	if _spouse_near == near:
		return
	_spouse_near = near
	_update_vow_buff()

func _update_vow_buff() -> void:
	if not _stats:
		return
	_stats.remove_modifiers_from_source(self)
	if _spouse_near and is_married() and _has_vow_ring():
		_stats.add_modifier(_ModifierData.new(&"health_regen", _ModifierData.Op.PCT_ADD, 0.10, self))
		_stats.add_modifier(_ModifierData.new(&"vigor_regen", _ModifierData.Op.PCT_ADD, 0.10, self))

func _has_vow_ring() -> bool:
	if not _inv:
		return true
	return _inv.get_material_count(&"alianca_votos") > 0

func to_dict() -> Dictionary:
	return {
		"spouse_name": spouse_name,
		"spouse_id": spouse_id,
		"spouse_dna": spouse_dna.to_dict() if spouse_dna else {},
		"is_pregnant": is_pregnant,
		"pregnancy_days": pregnancy_days,
		"partner_dna": partner_dna.to_dict() if partner_dna else {},
		"partner_name": partner_name,
		"children": children.duplicate(true)
	}

func from_dict(d: Dictionary) -> void:
	spouse_name = str(d.get("spouse_name", ""))
	spouse_id = int(d.get("spouse_id", 0))
	var s_dna_dict: Dictionary = d.get("spouse_dna", {})
	spouse_dna = _CharacterDNA.from_dict(s_dna_dict) if not s_dna_dict.is_empty() else null
	is_pregnant = bool(d.get("is_pregnant", false))
	pregnancy_days = float(d.get("pregnancy_days", 0.0))
	var p_dna_dict: Dictionary = d.get("partner_dna", {})
	partner_dna = _CharacterDNA.from_dict(p_dna_dict) if not p_dna_dict.is_empty() else null
	partner_name = str(d.get("partner_name", ""))
	children = Array(d.get("children", [])).duplicate(true)
