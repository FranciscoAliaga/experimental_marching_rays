extends Node2D

@onready var shader_material : ShaderMaterial = $LOOK_MY_MATERIAL.material

func set_camera_pos(pos : Vector3):
	shader_material.set_shader_parameter("camera_pos",pos)

# sets YXZ camera angle
func set_camera_angle(T : Transform3D, sc: float):
	var Q = T
	Q.basis.x.x *= sc
	Q.basis.y.y *= sc
#	Q.basis.z.z *= sc
	shader_material.set_shader_parameter("camera_rotation",Q)
