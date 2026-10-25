class_name WeaponStyle
extends Resource

const _StyleAttack = preload("res://scripts/data/style_attack.gd")
const _EquipmentPiece = preload("res://scripts/data/equipment_piece.gd")

## Estilo de batalha: arma + os 2 básicos que ela dá + o que aparece no corpo (B10).
## "A classe sai do equipamento" (GDD-01 §4): trocar de estilo troca a barra e o peso.

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
## Peso na Carga do jogador (stat `load`).
@export var weight: float = 10.0
@export var primary: StyleAttack
@export var secondary: StyleAttack
## Golpe especial da arma executado ao apertar os dois botões do mouse (Mouse 1 + Mouse 2) juntos
@export var special: StyleAttack
## Golpe executado ao clicar com botão esquerdo durante o modo de mira (armas com AIM)
@export var aim_attack: StyleAttack
## Golpe executado ao clicar com botão esquerdo durante o bloqueio (armas com BLOCK)
@export var block_counter: StyleAttack
## Arma, escudo e armadura que aparecem no personagem.
@export var pieces: Array[EquipmentPiece] = []
