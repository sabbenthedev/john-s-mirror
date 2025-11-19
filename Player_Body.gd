extends CharacterBody3D


# ---- <[ Variables ]>
@export var MaxStepHeight = 0.25	# In Meters (1 - 1)
@export var RunSpeed = 20
@export var WalkSpeed = 10
@export var CrouchWalkSpeed = 5
@export var Jump_Speed = 10
@export var gravity = 27
@export var Friction = 15
@export var AirFriction = 3.0
@export var Sensitivity = 0.15


# States
var Sliding: bool
var Running: bool
var Crouching: bool


# Slide Vars
var SlideVector: Vector2

# Misc
var CurrentSpeed = 10
var direction: Vector3


# ---- <[ References ]>
@onready var head = $Head
@onready var camera_3d = $Head/Camera3D
@onready var collision_standing = $CollisionStanding
@onready var collision_crouching = $CollisionCrouching

# RayCasts
@onready var safe_to_crouch = $SafeToCrouch
@onready var safe_to_step = $SafeToStep


# ---- <[ Code ]>
func _ready():
	# Hiding mouse at the start of the game
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _input(event):
	# Rotate Camera
	if event is InputEventMouseMotion:
		rotate_y(deg_to_rad(-event.relative.x * Sensitivity))
		head.rotate_x(deg_to_rad(-event.relative.y * Sensitivity))
		head.rotation.x = clamp(head.rotation.x,deg_to_rad( -90),deg_to_rad( 98))


func _physics_process(delta):
	#Input mapping is in Project>Project Settings>Input Map
	var input_dir = Input.get_vector("Left", "Right", "Forwards", "Backwards")
	
	# Add the gravity.
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	# Handle Crouching/Sliding
	if Input.is_action_pressed("Crouch"):
		# Set Crouching collision and set camera height
		collision_standing.disabled = true
		collision_crouching.disabled = false
		head.position.y = lerp(head.position.y ,1.3 ,15*delta)
		
		if input_dir != Vector2.ZERO and !Crouching:
			# If moving then start sliding
			Sliding = true
			SlideVector = input_dir
		else:
			# if not moving then crouch
			Crouching = true
			CurrentSpeed = CrouchWalkSpeed
		
	elif !safe_to_crouch.is_colliding():
		head.position.y = lerp(head.position.y ,1.8 ,15*delta)
		Crouching = false
		Sliding = false
		collision_standing.disabled = false
		collision_crouching.disabled = true
		# Check if running
		if Input.is_action_pressed("Sprint"):
			# if running then set speed to run speed instead of walk speed
			Running = true
			CurrentSpeed = RunSpeed
		else:
			# if not running then set speed to walk speed instead of run speed
			Running = false
			CurrentSpeed = WalkSpeed
	
	# Handle jump.
	if Input.is_action_just_pressed("Jump") and is_on_floor():
		if Crouching and !Sliding:
			velocity.y = Jump_Speed * 1.25
		elif Crouching and Sliding:
			velocity.y = Jump_Speed * 1.5
		else:
			velocity.y = Jump_Speed
	
	# Handel Steps
	if safe_to_step.is_colliding() and safe_to_step.get_collision_normal().y == 1:
		var Point = safe_to_step.get_collision_point()
		# Check to see next step is within steping range
		if (Point.y - position.y) < MaxStepHeight and (Point.y - position.y) > 0 and (input_dir != Vector2.ZERO or Sliding):
			position.y = position.y + 0.2
	
	# Handel Velocity
	if (is_on_floor() or input_dir != Vector2.ZERO) and !Sliding:
		# Lerps Movement Direction to Input Direction with a Friction Delay
		direction = lerp(direction, (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized(),delta*Friction)
	if Sliding:
		# Lerps Movement Direction to last keys pressed before crouching (With Friction Delay)
		direction = lerp(direction, (transform.basis * Vector3(SlideVector.x, 0, SlideVector.y)).normalized(),delta*Friction)
	
	# Sets Velocity from Input
	if direction and !Sliding:
		velocity.x = direction.x * CurrentSpeed
		velocity.z = direction.z * CurrentSpeed
	elif Sliding:
		velocity.x = (direction.x * (RunSpeed * 1.25))
		velocity.z = (direction.z * (RunSpeed * 1.25))
	elif is_on_floor():
		velocity.x = move_toward(velocity.x, 0, CurrentSpeed)
		velocity.z = move_toward(velocity.z, 0, CurrentSpeed)
	else:
		velocity.x  = lerpf(velocity.x, 0, AirFriction * delta)
		velocity.z  = lerpf(velocity.x, 0, AirFriction * delta)
	
	move_and_slide()
