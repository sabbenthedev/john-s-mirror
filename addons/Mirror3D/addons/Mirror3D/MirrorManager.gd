extends Node
class_name MirrorManager

static var all_mirrors: Array = []

static func register_mirror(mirror: Mirror3D) -> void:
	if not all_mirrors.has(mirror):
		all_mirrors.append(mirror)

static func unregister_mirror(mirror: Mirror3D) -> void:
	if all_mirrors.has(mirror):
		all_mirrors.erase(mirror)

static func get_all_mirrors() -> Array:
	return all_mirrors.duplicate()
