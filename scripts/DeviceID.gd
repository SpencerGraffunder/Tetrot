extends Node

var device_id: String = ""


func _ready():
	# Try to load device ID from disk
	var save_path = "user://device_id.txt"
	var base_id := ""
	if FileAccess.file_exists(save_path):
		var f = FileAccess.open(save_path, FileAccess.READ)
		base_id = f.get_line().strip_edges()
		f.close()
	else:
		base_id = _generate_device_id()
		var f = FileAccess.open(save_path, FileAccess.WRITE)
		f.store_line(base_id)
		f.close()

	# Check for --instance_id CLI arg
	var instance_id := ""
	for arg in OS.get_cmdline_args():
		if arg.begins_with("--instance_id="):
			instance_id = arg.get_slice("=", 1)
			break
	if instance_id != "":
		device_id = base_id + "-instance" + instance_id
	else:
		device_id = base_id

func _generate_device_id() -> String:
	return str(OS.get_unique_id()) + "-" + str(randi())

func get_device_id() -> String:
	return device_id
