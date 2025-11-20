extends CharacterBody3D

@onready var animation_tree = $AnimationTree
var state_machine
@onready var spring_arm_pivot = $JohnGoodfixed/SpringArmPivot
@onready var spring_arm = $JohnGoodfixed/SpringArmPivot/SpringArm3D
@onready var cam: Camera3D = $JohnGoodfixed/SpringArmPivot/SpringArm3D/Camera3D

const SPEED = 2.0
const SENSITIVITY = 0.05
const SPRINT_MULTIPLIER = 2.5

@export_group("headbob")
@export var headbob_frequency := 2.0
@export var headbob_amplitude := 0.04
var headbob_time := 0.0

var smoothed_input := Vector2.ZERO
var strafe_acceleration := 6.0

var current_state := ""

var body_yaw := 0.0
var body_turn_speed := 6.0

func _ready() -> void:
	# Hiding mouse at the start of the game
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	state_machine = animation_tree.get("parameters/playback")
	
func _input(event: InputEvent) -> void:
	# Rotate Camera
	if event is InputEventMouseMotion:
		rotate_y(deg_to_rad(-event.relative.x * SENSITIVITY))
		spring_arm.rotate_x(deg_to_rad(event.relative.y * SENSITIVITY))
		spring_arm.rotation.x = clamp(spring_arm.rotation.x,deg_to_rad(-80),deg_to_rad(80))

func _physics_process(delta: float) -> void:
	if CharacterBody3D == null:
		return
		
	# Gravity
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Movement Input
	var input_dir := Input.get_vector("left", "right", "up", "down")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	var is_sprinting = Input.is_action_pressed("sprint")
	
	var forward_input = -input_dir.y
	
	var can_sprint = false
	if forward_input > 0.0:
		can_sprint = true
	elif forward_input == 0.0 and input_dir.x != 0.0:
		can_sprint = true
		
	var speed = SPEED
	if is_sprinting and can_sprint:
		speed *= SPRINT_MULTIPLIER
	
	# Movement
	if direction != Vector3.ZERO:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()
	
	# Headbob 
	headbob_time += delta * velocity.length() * float(is_on_floor())
	spring_arm.transform.origin = headbob(headbob_time)
	
	# ----------------
	# ANIMATION SYSTEM 
	# ----------------
	
	# smooth acceleration for animation
	var target_state = "Walk"
	if is_sprinting and can_sprint:
		target_state = "Run"
		
	var target_input = input_dir
	if target_state == "Run":
		target_input *= 2.0
	else:
		target_input *= 1.0
		
	smoothed_input = smoothed_input.move_toward(target_input, strafe_acceleration * delta)
	var animvec := Vector2(smoothed_input.x, -smoothed_input.y)
	
	var blend_path :=""
	if target_state == "Walk":
		blend_path = "parameters/Walk/JohnGoodWalk/blend_position"
	elif target_state == "Run":
		blend_path = "parameters/Run/JohnGoodRun/blend_position"
		
	animation_tree.set(blend_path, animvec)
		
	if current_state != target_state:
		state_machine.travel(target_state)
		current_state = target_state
pass

func headbob(headbob_time):
	var headbob_position = Vector3.ZERO
	headbob_position.y = sin(headbob_time * headbob_frequency) * headbob_amplitude
	headbob_position.x = cos(headbob_time * headbob_frequency / 2) * headbob_amplitude
	return headbob_position
