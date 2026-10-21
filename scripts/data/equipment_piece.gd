class_name EquipmentPiece
extends Resource

## Peça visível presa a um osso do rig UAL (arma, escudo, ombreira, cinto).
## O transform é relativo ao osso.

@export var scene: PackedScene
@export var bone: StringName = &"hand_r"
@export var transform: Transform3D = Transform3D.IDENTITY
