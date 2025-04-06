@tool
extends EditorPlugin

var countdown_packed_scene := preload("res://addons/gwj_countdown/scenes/countdown_ui.tscn")
var countdown_node


func _enter_tree():
	countdown_node = countdown_packed_scene.instantiate()
	add_control_to_container(CONTAINER_TOOLBAR, countdown_node)


func _exit_tree():
	remove_control_from_container(CONTAINER_TOOLBAR, countdown_node)
