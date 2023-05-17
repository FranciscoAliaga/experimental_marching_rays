extends Node2D

@onready var shader_material : ShaderMaterial = $LOOK_MY_MATERIAL.material

func set_camera_pos(pos : Vector3):
	shader_material.set_shader_parameter("camera_pos",pos)

# sets YXZ camera angle
func set_camera_angle(T : Transform3D, sc: float):
	var Q = T
	Q.basis.x.x *= sc
	Q.basis.y.y *= sc
	shader_material.set_shader_parameter("camera_rotation",Q)

func _on_sky_color_picker_color_changed(color: Color) -> void:
	shader_material.set_shader_parameter("sky_color",color)


func _on_floor_color_picker_color_changed(color: Color) -> void:
	shader_material.set_shader_parameter("floor_color",color)


func _on_objects_color_picker_color_changed(color: Color) -> void:
	shader_material.set_shader_parameter("object_color",color)


func _on_fogs_color_picker_color_changed(color: Color) -> void:
	shader_material.set_shader_parameter("fog_color",color)


func _on_pixels_x_value_changed(value: float) -> void:
	var x : int = int(value)
	shader_material.set_shader_parameter("x_pixels",x)


func _on_pixels_y_value_changed(value: float) -> void:
	var y : int = int(value)
	shader_material.set_shader_parameter("y_pixels",y)


func _on_fog_slider_value_changed(value: float) -> void:
	shader_material.set_shader_parameter("foggyness",value)

func _on_fog_decay_slider_value_changed(value: float) -> void:
	shader_material.set_shader_parameter("fog_decay",value)


func _on_reflection_slider_value_changed(value: float) -> void:
	shader_material.set_shader_parameter("reflection_index",value)

