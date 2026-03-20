#[compute]
#version 450
layout(local_size_x = 1024, local_size_y = 1, local_size_z = 1) in;

struct Boid {
    vec4 position;
    vec4 forward;
    vec4 next_forward;
    vec4 velocity;
    vec4 acceleration;
};

layout(set = 0, binding = 0, std430) restrict buffer BoidBuffer {
    Boid boids[];
};

layout(push_constant, std430) uniform Params {
    float num_boids;
    float view_radius;
    float avoid_radius;
    float min_speed;
    float max_speed;
    float max_steer_force;
    float align_weight;
    float cohesion_weight;
    float separate_weight;
    float delta_time;
    float forward_weight;
    float _pad0;
} params;

void main() {
    int id = int(gl_GlobalInvocationID.x);
    if (id >= int(params.num_boids))
    {
        return;
    }
    boids[id].position += boids[id].velocity * params.delta_time;
    boids[id].forward = boids[id].next_forward;
}
