class_name Boids extends Node3D

static var UPDATE_SHADER: RDShaderFile = preload("res://resources/update.glsl")

@export var boid_count: int   = 100
@export var view_radius: float = 5.0
@export var avoid_radius: float = 2.0
@export var min_speed: float = 1.0
@export var max_speed: float = 5.0
@export var align_weight: float = 1.0
@export var cohesion_weight: float = 1.0
@export var separate_weight: float = 1.5

var _device: RenderingDevice = null
var _boid_buffer: RID
var _shader: RID
var _pipeline: RID
var _uniform_set: RID

func _ready() -> void:
	_device = RenderingServer.get_rendering_device()
	var boid_data: PackedFloat32Array = PackedFloat32Array()
	boid_data.resize(boid_count * 28)
	boid_data.fill(0.0)
	for i in range(boid_count):
		var base: int = i * 28
		boid_data[base + 0] = global_position.x
		boid_data[base + 1] = global_position.y
		boid_data[base + 2] = global_position.z
		boid_data[base + 3] = 0.0
		boid_data[base + 4] = 0.0
		boid_data[base + 5] = 0.0
		boid_data[base + 6] = 1.0
		boid_data[base + 7] = 1.0
	_boid_buffer = _device.storage_buffer_create(boid_data.size() * 4, boid_data.to_byte_array())
	_shader = _device.shader_create_from_spirv(UPDATE_SHADER.get_spirv())
	_pipeline = _device.compute_pipeline_create(_shader)
	var uniform: RDUniform = RDUniform.new()
	uniform.uniform_type  = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	uniform.binding = 0
	uniform.add_id(_boid_buffer)
	_uniform_set = _device.uniform_set_create([uniform], _shader, 0)
	var effect: BoidsEffect = BoidsEffect.new()
	effect.boids = self
	var compositor: Compositor = Compositor.new()
	compositor.compositor_effects = [effect]
	var camera: Camera3D = get_viewport().get_camera_3d()
	camera.compositor = compositor

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		for rid in [_boid_buffer, _pipeline, _shader, _uniform_set]:
			if rid.is_valid(): _device.free_rid(rid)

func _process(delta: float) -> void:
	var push: PackedFloat32Array = PackedFloat32Array()
	push.resize(12)
	push[0] = float(boid_count)
	push[1] = view_radius
	push[2] = avoid_radius
	push[3] = min_speed
	push[4] = max_speed
	push[5] = align_weight
	push[6] = cohesion_weight
	push[7] = separate_weight
	push[8] = delta
	push[9] = 0.0
	push[10] = 0.0
	push[11] = 0.0
	var compute_list: int = _device.compute_list_begin()
	_device.compute_list_bind_compute_pipeline(compute_list, _pipeline)
	_device.compute_list_bind_uniform_set(compute_list, _uniform_set, 0)
	_device.compute_list_set_push_constant(compute_list, push.to_byte_array(), push.size() * 4)
	@warning_ignore("integer_division")
	_device.compute_list_dispatch(compute_list, (boid_count + 1023) / 1024, 1, 1)
	_device.compute_list_end()
