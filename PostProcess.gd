@tool
class_name PostProcess
extends CompositorEffect

@export var shader_path : String:
	set(value):
		mutex.lock()
		shader_path = value
		shader_is_dirty = true
		mutex.unlock()


var rd : RenderingDevice
var shader : RID
var pipeline : RID

var mutex: Mutex = Mutex.new()
var shader_is_dirty: bool = true

func _init() -> void:
	rd = RenderingServer.get_rendering_device()
	access_resolved_color = true

func _notification(what : int) -> void:
	if what == NOTIFICATION_PREDELETE and shader.is_valid():
		RenderingServer.free_rid(shader)

func _check_shader():
	if not rd: return false

	var glsl_file : RDShaderFile

	mutex.lock()
	if shader_is_dirty:
		glsl_file = load(shader_path)
		shader_is_dirty = false
	mutex.unlock()

	if !glsl_file: return pipeline.is_valid()
	shader = rd.shader_create_from_spirv(glsl_file.get_spirv())
	pipeline = rd.compute_pipeline_create(shader)
	return pipeline.is_valid()


func _render_callback(_effect_callback_type: int, render_data: RenderData) -> void:
	if not rd or not _check_shader(): return

	var scene_buffers : RenderSceneBuffersRD = render_data.get_render_scene_buffers()
	if not scene_buffers: return

	var size : Vector2i = scene_buffers.get_internal_size()
	if size.x == 0 or size.y == 0: return

	var x_groups = (size.x-1) / 8 + 1
	var y_groups = (size.y-1) / 8 + 1
	var z_groups = 1

	var push_constants : PackedFloat32Array = PackedFloat32Array()
	push_constants.append(size.x)
	push_constants.append(size.y)
	push_constants.append(.0)
	push_constants.append(.0)

	for view in range(scene_buffers.get_view_count()):
		var screen_texture : RID = scene_buffers.get_color_layer(view)

		var uniform:RDUniform = RDUniform.new()
		uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
		uniform.binding = 0
		uniform.add_id(screen_texture)

		var image_uniform_set: RID = UniformSetCacheRD.get_cache(shader, 0, [uniform])

		var byte_push_constants = push_constants.to_byte_array()

		var compute_list : int = rd.compute_list_begin()
		rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
		rd.compute_list_bind_uniform_set(compute_list, image_uniform_set, 0)
		rd.compute_list_set_push_constant(compute_list, byte_push_constants, byte_push_constants.size())
		rd.compute_list_dispatch(compute_list, x_groups, y_groups, z_groups)
		rd.compute_list_end()
