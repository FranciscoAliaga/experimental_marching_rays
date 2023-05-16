extends Node2D

@onready var shader_material : ShaderMaterial = $LOOK_MY_MATERIAL.material

func set_camera_pos(pos : Vector3):
	shader_material.set_shader_parameter("camera_pos",pos)

# sets YXZ camera angle
func set_camera_angle(T : Transform3D):
	shader_material.set_shader_parameter("camera_rotation",T)
