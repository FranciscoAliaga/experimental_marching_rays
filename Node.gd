extends Node

@onready var ray_marcher = get_parent().find_child("RayMarcher")
@export var speed : float = 3.

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	T.origin += 3.*Vector3.FORWARD + 1.*Vector3.UP

var T : Transform3D = Transform3D()

func get_input_dir() -> Vector2:
	var ans : Vector2 = Vector2.ZERO
	if Input.is_action_pressed("ui_up"): ans.y += 1
	if Input.is_action_pressed("ui_down"): ans.y -= 1
	if Input.is_action_pressed("ui_left"): ans.x -= 1
	if Input.is_action_pressed("ui_right"): ans.x += 1
	return ans

func _process(delta: float) -> void:
	var dir : Vector2 = get_input_dir()
	var displacement : Vector2 = dir.normalized() * delta * speed

	T = T.translated_local(Vector3(displacement.x,0.,displacement.y))
	
	var position : Vector3 = T.origin
	ray_marcher.set_camera_pos(position)

func _input(event):
	if event is InputEventMouseMotion:
		# there is mouse motion
		# calculate new angle
		var relative_rotation : Vector2 = event.relative * 2 * PI / 1000.
		var euler     : Vector3 = T.basis.get_euler(EULER_ORDER_YXZ)
		euler.x += relative_rotation.y
		euler.y += relative_rotation.x
		T.basis = Basis.from_euler(euler,EULER_ORDER_YXZ)
		
		ray_marcher.set_camera_angle(T)

	if event is InputEventKey:
		if event.keycode == KEY_ESCAPE:
			get_tree().quit()
