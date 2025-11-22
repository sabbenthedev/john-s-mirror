extends Node
class_name MirrorManager

static var all_mirrors: Array = []
static var player_camera: Camera3D
static var frozen_camera_transform: Transform3D
static var frozen_camera_position: Vector3

static func register_mirror(mirror: Mirror3D) -> void:
	if not all_mirrors.has(mirror):
		all_mirrors.append(mirror)

static func unregister_mirror(mirror: Mirror3D) -> void:
	if all_mirrors.has(mirror):
		all_mirrors.erase(mirror)

static func set_player_camera(camera: Camera3D) -> void:
	player_camera = camera

static func freeze_camera_state() -> void:
	if player_camera:
		frozen_camera_transform = player_camera.global_transform
		frozen_camera_position = player_camera.global_position

static func update_all_mirrors() -> void:
	if not player_camera or all_mirrors.is_empty():
		return
	
	# Freeze the camera state for ALL mirrors
	freeze_camera_state()
	
	# Update ALL mirrors with the same frozen camera state
	for mirror in all_mirrors:
		if is_instance_valid(mirror) and mirror.is_visible_in_tree():
			mirror.force_static_update()
