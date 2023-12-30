## Copyright (c) 2023 Anders Reggestad
##
## Licensed under the MIT license, see LICENSE.txt
## in the project root folder for more information.
@tool
class_name SceneToMeshConverterButton
extends Button
##
## Class used by the Scene to Mesh Converter plugin to convert scenes to meshes.
##

var root :Node
var node :Node3D
var undo_redo : EditorUndoRedoManager


## Show button in UI, untoggled
func show_button(root: Node, node :Node3D):
	self.root = root
	self.node = node
	show()


## Hide button in UI, untoggled
func hide_button():
	hide()


## Callback from the button in the CONTAINER_SPATIAL_EDITOR_MENU
func _on_convert_scene_to_mesh_button_pressed():
	convert_node_to_meshinstance()

## Perform the conversion of the scene to a mesh instance.
func convert_node_to_meshinstance():
	var mesh_instance = MeshInstance3D.new()
	var mesh = ArrayMesh.new()
	
	mesh_instance.mesh = mesh
	
	# Since there are so many different ways meshes can be stored ArrayMesh, CSGShape3D, ...
	# we first export to GLTF and then extracte the surfaces from that
	var gltf_document := GLTFDocument.new()
	var gltf_state := GLTFState.new()
	gltf_document.append_from_scene(node, gltf_state)
	
	var xform : Transform3D = Transform3D()
	extract_meshes(mesh, gltf_state, gltf_state.root_nodes, xform)
	
	# Replace the scene with the mesh instance node.
	var node_transform = node.global_transform
	var node_name = node.name
	var parent = node.get_parent()
	var idx = node.get_index()
	
	undo_redo.create_action("Convert scene to mesh")
	undo_redo.add_do_method(parent, "add_child", mesh_instance)
	undo_redo.add_do_method(self, "set_undo_owner", mesh_instance, root)
	undo_redo.add_undo_method(parent, "remove_child", mesh_instance)
	
	undo_redo.add_do_method(parent, "remove_child", node)
	undo_redo.add_do_method(mesh_instance, "set_name", node_name)
	undo_redo.add_undo_method(parent, "add_child", node)
	undo_redo.add_undo_method(self, "set_undo_owner", node, root)
	undo_redo.commit_action()
	
#	node.get_parent().add_child(mesh_instance)
#	node.get_parent().remove_child(node)
	
	mesh_instance.owner = root
	mesh_instance.global_transform = node_transform
	mesh_instance.name = node_name


## Function used to set owner of a tree in undo actions, to include into scene again
func set_undo_owner(node, root):
	node.set_owner(root)
	for child in node.get_children():
		set_undo_owner(child, root)


## Locate and extract meshes recursive
func extract_meshes(mesh : ArrayMesh, gltf_state : GLTFState, node_idxes : PackedInt32Array, parent_xform : Transform3D):
	for idx in range (0, node_idxes.size()):
		var node_idx = node_idxes[idx]
		var gltf_node := gltf_state.get_nodes()[node_idx]
		
		var node_xfrom = Transform3D(Basis(gltf_node.rotation), gltf_node.position)
		var xform = parent_xform*node_xfrom
		
		if gltf_node.mesh != -1:
			add_mesh(mesh, gltf_state, gltf_node.mesh, xform)
	
		extract_meshes(mesh, gltf_state, gltf_node.children, xform)


## Add meshe from the GLTF to the mesh
func add_mesh(mesh : ArrayMesh, gltf_state : GLTFState, mesh_idx : int, xform : Transform3D):
	var gltf_mesh = gltf_state.get_meshes()[mesh_idx]
	
	for idx in range (0,gltf_mesh.mesh.get_surface_count()):
		var add_idx = mesh.get_surface_count()
		var arrays = gltf_mesh.mesh.get_surface_arrays(idx)
		
		# Transform vertexes
		for vertex_idx in range (0, arrays[Mesh.ARRAY_VERTEX].size()):
			var vec = xform*arrays[Mesh.ARRAY_VERTEX][vertex_idx]
			arrays[Mesh.ARRAY_VERTEX][vertex_idx] = vec
			
		mesh.add_surface_from_arrays(
			gltf_mesh.mesh.get_surface_primitive_type(idx),
			arrays,
			)
		mesh.surface_set_material(add_idx, gltf_mesh.mesh.get_surface_material(idx))
		mesh.surface_set_name(add_idx, gltf_mesh.mesh.get_surface_name(idx))
		#TODO blend shapes, lods, lightmap_size_hint,++?
