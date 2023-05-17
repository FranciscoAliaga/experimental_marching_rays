extends Node

@onready var ray_marcher = get_parent().find_child("RayMarcher")
@export var speed : float = 3.

var camera_lock : bool = false : set = camera_lock_set


func _ready():
	T.origin += 3.*Vector3.FORWARD + 1.*Vector3.UP
	camera_lock = false

var T : Transform3D = Transform3D()

func get_input_dir() -> Vector2:
	var ans : Vector2 = Vector2.ZERO
	if Input.is_action_pressed("up"): ans.y += 1
	if Input.is_action_pressed("down"): ans.y -= 1
	if Input.is_action_pressed("left"): ans.x -= 1
	if Input.is_action_pressed("right"): ans.x += 1
	return ans

func _process(delta: float) -> void:
	var dir : Vector2 = get_input_dir()
	var displacement : Vector2 = dir.normalized() * delta * speed

	T = T.translated_local(Vector3(displacement.x,0.,displacement.y))
	
	var position : Vector3 = T.origin
	ray_marcher.set_camera_pos(position)

var scale : float = 1.
func _input(event):
	if event is InputEventMouseMotion:
		# there is mouse motion
		# calculate new angle
		if(camera_lock):
			var relative_rotation : Vector2 = event.relative * 2 * PI / 1000.
			var euler     : Vector3 = T.basis.get_euler(EULER_ORDER_YXZ)
			euler.x += relative_rotation.y
			euler.y += relative_rotation.x
			T.basis = Basis.from_euler(euler,EULER_ORDER_YXZ)
			ray_marcher.set_camera_angle(T,scale)
		
	if event is InputEventMouseButton:
		var wheel_dir : float = 0.
		if event.button_index==MOUSE_BUTTON_WHEEL_DOWN:
			wheel_dir -=1
		if event.button_index==MOUSE_BUTTON_WHEEL_UP:
			wheel_dir +=1
		
		scale *= pow(1.1,wheel_dir)
		ray_marcher.set_camera_angle(T,scale)
	
	if event is InputEventKey:
		if event.keycode == KEY_ESCAPE:
			get_tree().quit()
		if event.keycode == KEY_R:
			get_tree().change_scene_to_file("res://main.tscn")


func camera_lock_set(val : bool):
	camera_lock = val
	var label = $"../UI/MarginContainer/Control/VBoxContainer/HBoxContainer/MouseLock2"
	if val:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		label.text = " UNLOCKED "
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CONFINED
		label.text = " LOCKED "


func _on_sub_viewport_container_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_LEFT:
			if event.is_pressed():
				camera_lock = !camera_lock


func _on_speed_slider_value_changed(value: float) -> void:
	speed = value
