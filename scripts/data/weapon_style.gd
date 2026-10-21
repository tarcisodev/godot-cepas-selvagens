class_name WeaponStyle
extends Resource

## Estilo de batalha: arma + os 2 básicos que ela dá + o que aparece no corpo (B10).
## "A classe sai do equipamento" (GDD-01 §4): trocar de estilo troca a barra e o peso.

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
## Peso na Carga do jogador (stat `load`).
@export var weight: float = 10.0
@export var primary: StyleAttack
@export var secondary: StyleAttack
## Golpe executado ao clicar com botão esquerdo durante o modo de mira (armas com AIM)
@export var aim_attack: StyleAttack
## Golpe executado ao clicar com botão esquerdo durante o bloqueio (armas com BLOCK)
@export var block_counter: StyleAttack
## Arma, escudo e armadura que aparecem no personagem.
@export var pieces: Array[EquipmentPiece] = []
