@tool
class_name Mirror3D
extends Node3D

## The size of the mirror quad mesh in units.
@export var size:Vector2 = Vector2(1, 1) :
	set(value):
		config_dirty = true
		size = value

## The number of pixels to render per unit.
@export var pixels_per_unit:int = 200 :
	set(value):
		config_dirty = true
		pixels_per_unit = value

## If true, uses a linear (anti-aliased) filter, otherwise, uses a nearest (aliased) filter.
@export var use_linear_filter:bool = true :
	set(value):
		config_dirty = true
		use_linear_filter = value

## The modulate applied to the mirror.
@export var color:Color = Color(0.9, 0.97, 0.94) :
	set(value):
		config_dirty = true
		color = value

## The amount to use the distortion texture.
@export_range(0, 100, 0.01) var distortion:float = 0.0 :
	set(value):
		config_dirty = true
		distortion = value

## The noise texture to distort the mirror with.
@export var distortion_texture:Texture2D = null :
	set(value):
		config_dirty = true
		distortion_texture = value

## The visibility layers rendered by the mirror.
@export_flags_3d_render var cull_mask:int = 0xFFFFF :
	set(value):
		config_dirty = true
		cull_mask = value

## The minimum distance of objects the mirror will render.
@export var cull_near:float = 0.05
## The maximum distance of objects the mirror will render.
@export var cull_far:float = 50.0
## The maximum distance of the player camera before the mirror is frozen.
@export var freeze_distance:float = 50.0
## The maximum number of mirror updates per second. If negative, unlimited.
@export var max_fps:float = -1.0

## If true, uses the global frozen camera system for perfect static reflections
@export var use_global_frozen_system: bool = true

## Maximum recursion depth for reflections
@export var max_recursion_depth: int = 2

## The viewport used to render the mirror.
@onready var mirror_viewport:SubViewport = $Viewport
## The viewport camera used to sample the mirror.
@onready var mirror_camera:Camera3D = $Viewport/Camera
## The quad mesh instance used to display the mirror.
@onready var mirror_quad:MeshInstance3D = $Quad

var config_dirty:bool = true
var time_since_update:float = 0.0
var time_update_dirty:bool = true
var current_recursion_depth: int = 0

func _ready() -> void:
	if not Engine.is_editor_hint() and use_global_frozen_system:
		MirrorManager.register_mirror(self)
	
	# Start with viewport disabled
	mirror_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	config_dirty = true

func _exit_tree() -> void:
	if not Engine.is_editor_hint() and use_global_frozen_system:
		MirrorManager.unregister_mirror(self)

func _process(delta:float) -> void:
	if !is_visible_in_tree():
		return
	
	# In global mode, we don't update the mirror in _process
	if use_global_frozen_system and not Engine.is_editor_hint():
		if config_dirty:
			configure_mirror()
		return
	
	# Editor mode uses the original logic
	handle_editor_update(delta)

func handle_editor_update(delta: float) -> void:
	var player_camera: Camera3D
	if Engine.is_editor_hint():
		player_camera = Engine.get_singleton("EditorInterface").get_editor_viewport_3d().get_camera_3d()
	else:
		player_camera = get_viewport().get_camera_3d()
	
	if !is_instance_valid(player_camera):
		return
	
	# Timing logic for FPS limiting
	if time_update_dirty:
		time_update_dirty = false
	else:
		if max_fps >= 0:
			time_since_update += delta
			if time_since_update < 1.0 / max_fps:
				mirror_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
				return
	
	mirror_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	time_since_update = 0
	
	if global_position.distance_to(player_camera.global_position) >= freeze_distance:
		mirror_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return
	
	if config_dirty:
		configure_mirror()
	
	update_mirror_camera(player_camera.global_transform, player_camera.global_position)

func configure_mirror() -> void:
	config_dirty = false
	var viewport_texture:ViewportTexture = mirror_viewport.get_texture()
	var quad_material:ShaderMaterial = mirror_quad.get_active_material(0)
	mirror_camera.cull_mask = cull_mask
	mirror_quad.mesh.size = size
	mirror_viewport.size = size * pixels_per_unit
	quad_material.set_shader_parameter(&"color", color)
	quad_material.set_shader_parameter(&"distortion_texture", distortion_texture)
	quad_material.set_shader_parameter(&"distortion_strength", distortion)
	quad_material.set_shader_parameter(&"mirror_texture_linear", viewport_texture if use_linear_filter else null)
	quad_material.set_shader_parameter(&"mirror_texture_nearest", viewport_texture if !use_linear_filter else null)
	quad_material.set_shader_parameter(&"use_mirror_texture_linear", use_linear_filter)

## Force a static update using the global frozen camera state
func force_static_update(recursion_depth: int = 0) -> void:
	if !is_visible_in_tree():
		return
	
	# Freeze mirror if player is far away
	if global_position.distance_to(MirrorManager.frozen_camera_position) >= freeze_distance:
		mirror_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return
	
	if config_dirty:
		configure_mirror()
	
	# Update the mirror camera with the frozen camera state
	update_mirror_camera(MirrorManager.frozen_camera_transform, MirrorManager.frozen_camera_position)
	
	# Trigger a single update
	mirror_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	
	# NEW: Handle recursive reflections
	current_recursion_depth = recursion_depth
	if recursion_depth < max_recursion_depth:
		update_recursive_reflections(recursion_depth + 1)

## NEW: Update mirrors that are visible in this mirror's reflection
func update_recursive_reflections(recursion_depth: int) -> void:
	if recursion_depth >= max_recursion_depth:
		return
	
	# Get all other mirrors
	var all_mirrors = MirrorManager.all_mirrors.duplicate()
	
	for other_mirror in all_mirrors:
		if other_mirror == self or !is_instance_valid(other_mirror) or !other_mirror.is_visible_in_tree():
			continue
		
		# Check if this other mirror is visible in our reflection
		if is_mirror_visible_in_reflection(other_mirror):
			# Update the other mirror using our mirror camera as the source
			other_mirror.force_recursive_update(mirror_camera.global_transform, mirror_camera.global_position, recursion_depth)

## NEW: Force update with a specific camera (for recursive reflections)
func force_recursive_update(source_transform: Transform3D, source_position: Vector3, recursion_depth: int) -> void:
	if !is_visible_in_tree():
		return
	
	if config_dirty:
		configure_mirror()
	
	# Update the mirror camera with the specified source
	update_mirror_camera(source_transform, source_position)
	
	# Trigger a single update
	mirror_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	
	# Continue recursion if needed
	if recursion_depth < max_recursion_depth:
		update_recursive_reflections(recursion_depth + 1)

## NEW: Check if another mirror is visible in this mirror's reflection
func is_mirror_visible_in_reflection(other_mirror: Mirror3D) -> bool:
	var other_pos = other_mirror.global_position
	var mirror_normal = mirror_quad.global_basis.z
	
	# Check if the other mirror is in front of this mirror
	var to_other = other_pos - global_position
	if to_other.dot(mirror_normal) <= 0:
		return false
	
	# Simple frustum check
	var camera_forward = -mirror_camera.global_basis.z
	var to_other_dir = (other_pos - mirror_camera.global_position).normalized()
	
	# Check if the other mirror is roughly in the reflection's view
	return camera_forward.dot(to_other_dir) > 0.3

func update_mirror_camera(source_transform: Transform3D, source_position: Vector3) -> void:
	var mirror_normal: Vector3 = mirror_quad.global_basis.z
	var mirror_transform: Transform3D = get_mirror_transform(mirror_normal, mirror_quad.global_position)
	mirror_camera.global_transform = mirror_transform * source_transform
	
	mirror_camera.global_transform = mirror_camera.global_transform.looking_at(
		(mirror_camera.global_position / 2.0) + (source_position / 2.0),
		mirror_quad.global_basis.y
	)
	var camera_to_mirror_offset: Vector3 = mirror_quad.global_position - mirror_camera.global_position
	
	var near: float = abs(camera_to_mirror_offset.dot(mirror_normal)) + cull_near
	var far: float = camera_to_mirror_offset.length() + cull_far
	
	var cam_to_mirror_offset_camera_local: Vector3 = mirror_camera.global_basis.inverse() * camera_to_mirror_offset
	var frustum_offset := Vector2(cam_to_mirror_offset_camera_local.x, cam_to_mirror_offset_camera_local.y)
	mirror_camera.set_frustum(size.x, frustum_offset, near, far)

static func get_mirror_transform(normal:Vector3, offset:Vector3) -> Transform3D:
	var basis_x:Vector3 = Vector3(1, 0, 0) - (2 * Vector3(normal.x * normal.x, normal.x * normal.y, normal.x * normal.z))
	var basis_y:Vector3 = Vector3(0, 1, 0) - (2 * Vector3(normal.y * normal.x, normal.y * normal.y, normal.y * normal.z))
	var basis_z:Vector3 = Vector3(0, 0, 1) - (2 * Vector3(normal.z * normal.x, normal.z * normal.y, normal.z * normal.z))
	var origin:Vector3 = 2 * normal.dot(offset) * normal
	return Transform3D(basis_x, basis_y, basis_z, origin)
