extends SkeletonModifier3D
class_name PelvisHeightModifier

## Corrige a posição animada da pelve quando o DNA muda o comprimento da perna (B09).
# As animações UAL só gravam posição na pelve, medida para a perna do manequim.
# Com perna mais longa o pé afundaria no chão, e com perna mais curta flutuaria.
# Escalar essa posição pela razão do quadril devolve o pé ao chão e ajusta a passada junto.

@export var bone_name: StringName = &"pelvis"
@export var factor: float = 1.0

var _last_written := Vector3.INF

func _process_modification_with_delta(_delta: float) -> void:
	var skeleton := get_skeleton()
	if skeleton == null or is_equal_approx(factor, 1.0):
		return
	var bone := skeleton.find_bone(bone_name)
	if bone < 0:
		return
	var pose := skeleton.get_bone_pose_position(bone)
	# Se a animação não reescreveu a pose desde o último frame, ela já está corrigida.
	if pose.is_equal_approx(_last_written):
		return
	_last_written = pose * factor
	skeleton.set_bone_pose_position(bone, _last_written)
