## Copyright (c) 2023 Anders Reggestad
##
## Licensed under the MIT license, see LICENSE.txt
## in the project root folder for more information.
@tool
extends EditorPlugin
##
## A plugin that convert scenes to a mesh instance. Since there are multiple
## ways meshes are repesented, this plugin use the GLTF from scene to access
## all meshes in one uniform way.
##

## Referense to the button in the Spatial editor menu
var plugin_button : SceneToMeshConverterButton


## Connect the plugin to the editor when the plugin entering the tree.
func _enter_tree():
	plugin_button = preload("res://addons/scenetomeshconverter/plugin_button.tscn").instantiate()
	plugin_button.undo_redo = get_undo_redo()
	add_control_to_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, plugin_button)
	
	# By default hide the button
	plugin_button.hide()
	
	add_tool_menu_item("Convert scene to mesh", plugin_button.convert_node_to_meshinstance )
	
	# Monitor when objects selected in tree changes
	get_editor_interface().get_selection().selection_changed.connect(self.selection_changed)


## Disconnect the plugin elements when the plugin exit the tree.
func _exit_tree():
	
	remove_tool_menu_item("Convert scene to mesh")
	
	remove_control_from_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, plugin_button)
	
	if plugin_button:
		plugin_button.free()


## Montor the selection changed, and display the button if the type is a node
## that can be converted to a mesh.
func selection_changed() -> void:
	var selection = get_editor_interface().get_selection().get_selected_nodes()
	
	var can_convert = selection.size() == 1 and selection[0] is Node3D
	
	# If selected object in tree is csg
	if can_convert:
		var root : Node = get_tree().get_edited_scene_root()
		var node : Node3D = selection[0]
		plugin_button.show_button(root, node)
	else:
		plugin_button.hide_button()


