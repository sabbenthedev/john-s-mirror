extends CharacterBody3D

const SPEED = 8.0

# dependencies
var player = null
var player_camera : Camera3D = null
var state_machine: AnimationNodeStateMachinePlayback 

# internal logic vars
var twitch_timer := 0.0
var self_colliders := []

# configuration
@export var animation_tree_path : NodePath = "AnimationTree"
@export var animation_speed := 1.6

# nodes
@onready var visibility_notifier = $VisibleOnScreenNotifier3D
@onready var nav_agent = $NavigationAgent3D
@onready var animation_tree = get_node(animation_tree_path)
@onready var skeleton = $johnevil/Armature_001/Skeleton3D

func _ready() -> void:
	player = get_tree().get_first_node_in_group("player") # find player
	
	if player == null:
		printerr("player not found")
	else:
		print("john evil found the player successfully")
		
	player_camera = get_viewport().get_camera_3d() # find camera
	
	state_machine = animation_tree.get("parameters/playback") # setup animation
	
	self_colliders = [player] + get_all_colliders(self) # cache collider for optimization

func _physics_process(delta: float) -> void:
	if player == null: # prevent crash
		return
		
	match state_machine.get_current_node():
		"Run":
			if is_player_looking_at_me():
				_state_freeze(delta)
			else:
				_state_chase()

# state behaviors
func _state_freeze(delta: float) -> void:
	animation_tree.active = false # freeze animation
	velocity = Vector3.ZERO # stop moving
	nav_agent.set_velocity_forced(Vector3.ZERO)
	nav_agent.set_target_position(global_position)
	move_and_slide()
	
	_handle_twitching(delta)

func _state_chase() -> void:
	animation_tree.active = true
	
	# navigation
	nav_agent.set_target_position(player.global_position)
	var next_position = nav_agent.get_next_path_position()
	var direction = global_position.direction_to(next_position)
	
	velocity = direction * SPEED
	move_and_slide()
	
	# animation blending
	var local_direction = global_transform.basis.inverse() * direction
	var blend = Vector2(local_direction.x, -local_direction.z)
	
	animation_tree.set("parameters/Run/JohnRun/blend_position", blend)
	animation_tree.set("parameters/Run/TimeScale/scale", animation_speed)
	
	# look at player
	var look_target = Vector3(player.global_position.x, global_position.y, player.global_position.z)
	look_at(look_target, Vector3.UP)
	
func _handle_twitching(delta: float) -> void:
	twitch_timer -= delta
	if twitch_timer <= 0.0:
		twitch_timer = randf_range(0.1, 0.25)
		
		# calculate random twitch
		var random_rotation = Vector3(
						deg_to_rad(randf_range(-0.5, 0.5)),
						deg_to_rad(randf_range(-1.5, 1.5)),
						deg_to_rad(randf_range(-1, 1))
					)
					
		# apply to bone
		var head_idx = skeleton.find_bone("mixamorig_Head")
		if head_idx != -1:
			var default_pose = skeleton.get_bone_pose_rotation(head_idx)
			var quaternion_rotation = Quaternion.from_euler(random_rotation)
			skeleton.set_bone_pose_rotation(head_idx, default_pose * quaternion_rotation)

# vision logic
func is_player_looking_at_me() -> bool:
	if player_camera == null:
		return false
	if not visibility_notifier.is_on_screen():
		return false
	
	var space_state = get_world_3d().direct_space_state
	var head_height = Vector3(0, 1.5, 0)
	var shoulder_offset = global_transform.basis.x * 0.5

	# check 3 points - center, left, right
	var points_to_check = [
		global_position + head_height,
		global_position + head_height + shoulder_offset,
		global_position + head_height - shoulder_offset
	]
	
	for point in points_to_check:
		var query = PhysicsRayQueryParameters3D.new()
		query.from = player_camera.global_position
		query.to = point
		query.exclude = self_colliders
		
		var result = space_state.intersect_ray(query)
		
		if not result.has("collider"):
			return true
	return false

func get_all_colliders(node: Node) -> Array:
	var colliders: Array = []
	if node is CollisionShape3D or node is PhysicsBody3D:
		colliders.append(node)
	for child in node.get_children():
		colliders += get_all_colliders(child)
	return colliders
