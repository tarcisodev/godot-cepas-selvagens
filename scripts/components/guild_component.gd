class_name GuildComponent
extends Node

const _GuildData = preload("res://scripts/data/guild_data.gd")
const _GuildSystem = preload("res://scripts/systems/guild_system.gd")

## Componente de Filiação a Guilda e Uniformes (GDD-15 §4 e §5).
## Gerencia a filiação do jogador à sua guilda e a ocasião do uniforme ativo
## (Equipamento Pessoal, Set de Gala ou Set de Guerra).

signal guild_joined(guild_id: StringName)
signal guild_left()
signal occasion_changed(new_occasion: _GuildData.Occasion)

@export var guild_id: StringName = &""
@export var active_occasion: _GuildData.Occasion = _GuildData.Occasion.PERSONAL

var player: Node3D

func get_guild_data() -> _GuildData:
	if guild_id.is_empty():
		return null
	return _GuildSystem.get_instance().get_guild(guild_id)

func set_occasion(occasion: _GuildData.Occasion) -> void:
	if active_occasion != occasion:
		active_occasion = occasion
		occasion_changed.emit(active_occasion)

func join_guild(p_guild_id: StringName) -> void:
	guild_id = p_guild_id
	guild_joined.emit(guild_id)

func leave_guild() -> void:
	guild_id = &""
	active_occasion = _GuildData.Occasion.PERSONAL
	guild_left.emit()

## Retorna a heráldica ativa caso o jogador esteja usando uniforme de clã
func get_heraldry_override() -> Dictionary:
	if active_occasion == _GuildData.Occasion.PERSONAL:
		return {}
	var g := get_guild_data()
	if g == null:
		return {}
	return {
		"occasion": active_occasion,
		"primary_color": g.primary_color,
		"secondary_color": g.secondary_color,
		"emblem_icon": g.get_emblem_icon(),
		"emblem_id": g.emblem_id
	}
