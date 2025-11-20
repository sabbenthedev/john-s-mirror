extends CharacterBody3D

var player = null
var player_camera : Camera3D = null
var state_machine 

const SPEED = 5.0
var twitch_timer := 0.0

@export var camera_path : NodePath = "%Camera3D"
@export var player_path : NodePath
@export var animation_tree_path : NodePath = "AnimationTree"
@export var animation_speed := 1.6

@onready var visibility_notifier = $VisibleOnScreenNotifier3D
@onready var nav_agent = $NavigationAgent3D
@onready var animation_tree = get_node(animation_tree_path)
@onready var collisionshape = $CollisionShape3D
@onready var skeleton = $johnevil/Armature_001/Skeleton3D

func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")
	player_camera = get_viewport().get_camera_3d()
	
	state_machine = animation_tree.get("parameters/playback")
	
	if player == null:
		printerr("ERROR: Player not found:c")
	
func _physics_process(delta: float) -> void:
	if player == null:
		return
		
	match state_machine.get_current_node():
		"Run":
			# stop if player is looking at me
			if is_player_looking_at_me():
				animation_tree.active = false # freeze animation
				velocity = Vector3.ZERO # stop moving
				nav_agent.set_velocity_forced(Vector3.ZERO)
				nav_agent.set_target_position(global_position)
				move_and_slide()
				
				twitch_timer -= delta
				if twitch_timer <= 0.0:
					twitch_timer = randf_range(0.1, 0.25)
					var random_rotation = Vector3(
						deg_to_rad(randf_range(-0.5, 0.5)),
						deg_to_rad(randf_range(-1.5, 1.5)),
						deg_to_rad(randf_range(-1, 1))
					)
					
					var head_idx = skeleton.find_bone("mixamorig_Head")
					if head_idx != -1:
						var default = skeleton.get_bone_pose_rotation(head_idx)
						var quaternion_rotation = Quaternion.from_euler(random_rotation)
						skeleton.set_bone_pose_rotation(head_idx, default * quaternion_rotation)
				return
			else:
				animation_tree.active = true
				nav_agent.set_target_position(player.global_position) # chase player
				# velocity
				var next_velocity = nav_agent.get_next_path_position() - global_position
				velocity = next_velocity.normalized() * SPEED
				move_and_slide()

				# direction in local space for blend
				var local_direction = global_transform.basis.inverse() * next_velocity.normalized()

				# blend x/z on vector2
				var blend = Vector2(local_direction.x, -local_direction.z)
				
				# look at player
				look_at(Vector3(player.global_position.x, global_position.y, player.global_position.z), Vector3.UP)

				animation_tree.set("parameters/Run/JohnRun/blend_position", blend)
				animation_tree.set("parameters/Run/TimeScale/scale", animation_speed)

func is_player_looking_at_me() -> bool:
	if player_camera == null:
		return false
		
	if not visibility_notifier.is_on_screen():
		return false
	
	var space_state = get_world_3d().direct_space_state
	var exclude_list = [player] + get_all_colliders(self)
	
	var head_height = Vector3(0, 1.5, 0)
	var shoulder_offset = global_transform.basis.x * 0.5
	
	var points_to_check = [
		global_position + head_height,
		global_position + head_height + shoulder_offset,
		global_position + head_height - shoulder_offset
	]
	
	for point in points_to_check:
		var query = PhysicsRayQueryParameters3D.new()
		query.from = player_camera.global_position
		query.to = point
		query.exclude = exclude_list
		
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
