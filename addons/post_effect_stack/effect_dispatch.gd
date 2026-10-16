@tool
class_name PostEffectDispatch
extends RefCounted

## Shared dispatch machinery for `EffectStackRunner` and `PostEffectRunner`.
##
## Both runners used to carry their own copy of the single-dispatch path:
## pipeline cache, binding order, push constant, compute list. Keeping two
## copies in step has already failed once — `PostEffectRunner` was missing the
## multi-pass branch until 893605f added it after the fact. Source-snapshot
## support would have been the second such duplication, so the path lives here
## instead and each runner is a thin wrapper over it.

const SNAPSHOT_SHADER_PATH := "res://addons/post_effect_stack/shaders/snapshot_copy.glsl"

var rd: RenderingDevice
var nearest_sampler: RID
var linear_sampler: RID

## shader resource path -> { "shader": RID, "pipeline": RID }
var pipeline_cache: Dictionary

var _snapshot: RID
var _snapshot_size := Vector2i.ZERO
var _snapshot_format: int = -1
var _snapshot_shader: RID
var _snapshot_pipeline: RID
## Set once the snapshot pipeline fails to build, so a broken install does not
## retry the compile on every frame.
var _snapshot_unavailable: bool = false

var _mutex := Mutex.new()


func _init(p_rd: RenderingDevice) -> void:
	rd = p_rd
	if not rd:
		return
	var nearest_state := RDSamplerState.new()
	nearest_state.min_filter = RenderingDevice.SAMPLER_FILTER_NEAREST
	nearest_state.mag_filter = RenderingDevice.SAMPLER_FILTER_NEAREST
	nearest_sampler = rd.sampler_create(nearest_state)

	# The snapshot is bound as a `sampler2D`, not a storage image, precisely so
	# that effects can take filtered samples at fractional offsets. That is the
	# half of this feature `imageLoad()` cannot provide.
	var linear_state := RDSamplerState.new()
	linear_state.min_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	linear_state.mag_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	linear_state.repeat_u = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	linear_state.repeat_v = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	linear_sampler = rd.sampler_create(linear_state)


## Call from the owning runner's `NOTIFICATION_PREDELETE`. `RefCounted` has no
## predelete hook that is guaranteed to run while `rd` is still alive.
func free_resources() -> void:
	if not is_instance_valid(rd):
		return
	_mutex.lock()
	for key in pipeline_cache:
		var entry: Dictionary = pipeline_cache[key]
		if entry.has("pipeline") and entry["pipeline"].is_valid():
			rd.free_rid(entry["pipeline"])
		if entry.has("shader") and entry["shader"].is_valid():
			rd.free_rid(entry["shader"])
	pipeline_cache.clear()
	if _snapshot_pipeline.is_valid():
		rd.free_rid(_snapshot_pipeline)
		_snapshot_pipeline = RID()
	if _snapshot_shader.is_valid():
		rd.free_rid(_snapshot_shader)
		_snapshot_shader = RID()
	if _snapshot.is_valid():
		rd.free_rid(_snapshot)
		_snapshot = RID()
	if nearest_sampler.is_valid():
		rd.free_rid(nearest_sampler)
		nearest_sampler = RID()
	if linear_sampler.is_valid():
		rd.free_rid(linear_sampler)
		linear_sampler = RID()
	_mutex.unlock()


# ------------------------------------------------------------------ pipelines

func get_pipeline(effect: PostEffect) -> RID:
	if not effect or not effect.shader_file:
		return RID()

	var path := effect.shader_file.resource_path
	if pipeline_cache.has(path):
		var entry: Dictionary = pipeline_cache[path]
		if entry["pipeline"].is_valid():
			return entry["pipeline"]

	_mutex.lock()
	if pipeline_cache.has(path):
		var old: Dictionary = pipeline_cache[path]
		if old["pipeline"].is_valid():
			rd.free_rid(old["pipeline"])
		if old["shader"].is_valid():
			rd.free_rid(old["shader"])

	var spirv := effect.shader_file.get_spirv()
	var shader := rd.shader_create_from_spirv(spirv)
	var pipeline := rd.compute_pipeline_create(shader)
	pipeline_cache[path] = { "shader": shader, "pipeline": pipeline }
	_mutex.unlock()
	return pipeline


func get_shader(effect: PostEffect) -> RID:
	if not effect or not effect.shader_file:
		return RID()
	var path := effect.shader_file.resource_path
	if not pipeline_cache.has(path):
		return RID()
	return pipeline_cache[path]["shader"]


# ------------------------------------------------------------------- snapshot

func _ensure_snapshot_pipeline() -> bool:
	if _snapshot_pipeline.is_valid():
		return true
	if _snapshot_unavailable:
		return false

	var shader_file := load(SNAPSHOT_SHADER_PATH) as RDShaderFile
	if not shader_file:
		push_error("PostEffectDispatch: missing %s" % SNAPSHOT_SHADER_PATH)
		_snapshot_unavailable = true
		return false

	_mutex.lock()
	_snapshot_shader = rd.shader_create_from_spirv(shader_file.get_spirv())
	if _snapshot_shader.is_valid():
		_snapshot_pipeline = rd.compute_pipeline_create(_snapshot_shader)
	_mutex.unlock()

	if not _snapshot_pipeline.is_valid():
		push_error("PostEffectDispatch: could not build the source-snapshot pipeline")
		_snapshot_unavailable = true
		return false
	return true


## Allocate (or reallocate) the snapshot texture to match the colour buffer.
##
## The format is read back off the colour buffer rather than hardcoded, and
## this IS load-bearing. Forcing the snapshot to R8G8B8A8_UNORM makes CA at
## strength 0 stop being the identity: 276,975 of 518,400 pixels (53.4%) differ,
## and every pixel above linear 1.0 is among them (measured with
## capture/m4/m4_ca_snapshot.gd). An 8-bit snapshot does NOT round-trip values
## above 1.0 -- do not "simplify" this back to a hardcoded 8-bit format.
##
## The format is part of the reallocation guard below for the same reason: a
## size-only guard would silently keep a stale texture of the wrong format.
func _ensure_snapshot_texture(p_size: Vector2i, p_color_image: RID) -> bool:
	var format: int = rd.texture_get_format(p_color_image).format
	if _snapshot.is_valid() and _snapshot_size == p_size and _snapshot_format == format:
		return true

	if _snapshot.is_valid():
		rd.free_rid(_snapshot)
		_snapshot = RID()

	var fmt := RDTextureFormat.new()
	fmt.width = p_size.x
	fmt.height = p_size.y
	fmt.format = format
	# STORAGE for the copy pass to write it, SAMPLING for effects to read it
	# through `linear_sampler`.
	fmt.usage_bits = RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT
	_snapshot = rd.texture_create(fmt, RDTextureView.new())
	_snapshot_size = p_size
	_snapshot_format = format
	return _snapshot.is_valid()


## Copy the colour buffer into the snapshot texture and return it, or an
## invalid RID if the snapshot could not be produced.
##
## One texture is shared by every effect that asks for a snapshot. Each
## snapshot is consumed by the dispatch immediately after it, and the
## `compute_list_end()` between the two is what makes that ordering real, so
## the next effect may overwrite it. A snapshot cannot be reused across effects
## for the same reason: whatever ran in between has already changed the colour
## buffer.
func take_snapshot(p_size: Vector2i, p_color_image: RID, p_view: int, p_x_groups: int, p_y_groups: int) -> RID:
	if not _ensure_snapshot_pipeline():
		return RID()
	if not _ensure_snapshot_texture(p_size, p_color_image):
		return RID()

	var color_uniform := RDUniform.new()
	color_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	color_uniform.binding = 0
	color_uniform.add_id(p_color_image)
	var snapshot_uniform := RDUniform.new()
	snapshot_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	snapshot_uniform.binding = 1
	snapshot_uniform.add_id(_snapshot)
	var uniform_set := UniformSetCacheRD.get_cache(_snapshot_shader, 0, [color_uniform, snapshot_uniform])

	var push_constant := PackedFloat32Array([
		float(p_size.x),
		float(p_size.y),
		float(p_view),
		0.0,
	])

	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, _snapshot_pipeline)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	rd.compute_list_set_push_constant(compute_list, push_constant.to_byte_array(), push_constant.size() * 4)
	rd.compute_list_dispatch(compute_list, p_x_groups, p_y_groups, 1)
	rd.compute_list_end()
	return _snapshot


# ------------------------------------------------------------------- bindings

## Binding order. `needs_depth` was already a conditional binding, so
## `needs_source_snapshot` is the same shape one slot earlier:
##
##   flags set          | 0     | 1        | 2     | 3+
##   -------------------|-------|----------|-------|------
##   (none)             | color | user     | user  | user
##   needs_depth        | color | depth    | user  | user
##   snapshot           | color | snapshot | user  | user
##   snapshot + depth   | color | snapshot | depth | user
##
## An effect that sets neither flag therefore sees exactly what it saw before
## this existed.
func build_uniforms(effect: PostEffect, p_render_scene_buffers: RenderSceneBuffers,
		p_view: int, p_color_image: RID, p_snapshot: RID) -> Array:
	var color_uniform := RDUniform.new()
	color_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	color_uniform.binding = 0
	color_uniform.add_id(p_color_image)
	var uniforms: Array = [color_uniform]

	var next_binding := 1
	if effect.needs_source_snapshot and p_snapshot.is_valid():
		var snapshot_uniform := RDUniform.new()
		snapshot_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
		snapshot_uniform.binding = next_binding
		snapshot_uniform.add_id(linear_sampler)
		snapshot_uniform.add_id(p_snapshot)
		uniforms.append(snapshot_uniform)
		next_binding += 1

	if effect.needs_depth:
		var depth_image: RID = p_render_scene_buffers.get_depth_layer(p_view)
		if depth_image.is_valid():
			var depth_uniform := RDUniform.new()
			depth_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
			depth_uniform.binding = next_binding
			depth_uniform.add_id(nearest_sampler)
			depth_uniform.add_id(depth_image)
			uniforms.append(depth_uniform)

	for u in effect._get_additional_uniforms():
		uniforms.append(u)
	return uniforms


# ------------------------------------------------------------------- dispatch

## Record one effect into an already-open compute list. The caller is
## responsible for having taken the snapshot (see `take_snapshot()`) before
## opening that list — the snapshot needs a list of its own so that the barrier
## at `compute_list_end()` orders it before this dispatch.
func record(effect: PostEffect, p_compute_list: int, p_pipeline: RID, p_uniforms: Array,
		p_size: Vector2i, p_view: int, p_x_groups: int, p_y_groups: int) -> void:
	var uniform_set := UniformSetCacheRD.get_cache(get_shader(effect), 0, p_uniforms)
	var push_constant := effect._build_push_constant(p_size, p_view)
	rd.compute_list_bind_compute_pipeline(p_compute_list, p_pipeline)
	rd.compute_list_bind_uniform_set(p_compute_list, uniform_set, 0)
	rd.compute_list_set_push_constant(p_compute_list, push_constant.to_byte_array(), push_constant.size() * 4)
	rd.compute_list_dispatch(p_compute_list, p_x_groups, p_y_groups, 1)


## Run one effect end to end for one view: multi-pass hand-off, snapshot pass if
## asked for, then the single dispatch in its own compute list. Both runners
## call only this.
func render(effect: PostEffect, p_runner: Object, p_render_scene_buffers: RenderSceneBuffers,
		p_view: int, p_size: Vector2i, p_color_image: RID, p_x_groups: int, p_y_groups: int) -> void:
	if not effect._is_ready():
		return

	if effect._is_multi_pass:
		effect._render_multi_pass(rd, p_runner, p_render_scene_buffers, p_view, p_size, p_color_image)
		return

	var pipeline := get_pipeline(effect)
	if not pipeline.is_valid():
		return

	var snapshot := RID()
	if effect.needs_source_snapshot:
		snapshot = take_snapshot(p_size, p_color_image, p_view, p_x_groups, p_y_groups)
		if not snapshot.is_valid():
			# The shader declares binding 1 as the snapshot. Dispatching without
			# it would bind the depth buffer or a user texture there instead, so
			# skipping the effect is the only safe fallback.
			return

	var uniforms := build_uniforms(effect, p_render_scene_buffers, p_view, p_color_image, snapshot)

	var compute_list := rd.compute_list_begin()
	record(effect, compute_list, pipeline, uniforms, p_size, p_view, p_x_groups, p_y_groups)
	rd.compute_list_end()
