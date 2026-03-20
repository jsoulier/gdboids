#[vertex]
#version 450

struct Boid {
	vec4 position;
	vec4 forward;
	vec4 velocity;
	vec4 acceleration;
	vec4 avg_flock_heading;
	vec4 avg_avoidance;
	vec4 center_of_flockmates;
};

layout(location = 0) in vec3 in_position;

layout(set = 0, binding = 0, std430) readonly buffer BoidBuffer {
	Boid boids[];
};

layout(push_constant, std430) uniform PushConstants{
	mat4 view_proj;
} push_constants;

mat3 basis_from_forward(vec3 forward) {
	forward = normalize(forward);
	vec3 up;
	if (abs(forward.y) < 0.999) {
		up = vec3(0.0, 1.0, 0.0);
	} else {
		up = vec3(1.0, 0.0, 0.0);
	}
	vec3 right = normalize(cross(up, forward));
	up = cross(forward, right);
	return mat3(right, forward, up);
}

void main() {
	vec3 position = boids[gl_InstanceIndex].position.xyz;
	vec3 forward = boids[gl_InstanceIndex].forward.xyz;
	mat3 basis = basis_from_forward(forward);
	gl_Position = push_constants.view_proj * vec4(position + basis * in_position, 1.0);
}

#[fragment]
#version 450

layout(location = 0) out vec4 out_color;

void main() {
	out_color = vec4(1.0, 1.0, 1.0, 1.0);
}
