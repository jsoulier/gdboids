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

vec3 steer_towards(vec3 direction, vec3 velocity) {
    float _length = length(direction);
    if (_length < 0.0001) {
        return vec3(0.0);
    }
    velocity = normalize(direction) * params.max_speed - velocity;
    if (length(velocity) < 0.0001) {
        return vec3(0.0);
    }
    _length = length(velocity);
    if (_length > params.max_steer_force) {
        velocity = velocity / _length * params.max_steer_force;
    }
    return velocity;
}

void main() {
    int id = int(gl_GlobalInvocationID.x);
    if (id >= int(params.num_boids)) {
        return;
    }
    vec3 position = boids[id].position.xyz;
    vec3 forward = boids[id].forward.xyz;
    vec3 velocity = boids[id].velocity.xyz;
    vec3 flock_heading = vec3(0.0);
    vec3 flock_center  = vec3(0.0);
    vec3 avoidance = vec3(0.0);
    int num_mates = 0;
    for (int b = 0; b < int(params.num_boids); b++) {
        if (b == id) {
            continue;
        }
        vec3 offset = boids[b].position.xyz - position;
        float sqr_dst = dot(offset, offset);
        if (sqr_dst < params.view_radius * params.view_radius) {
            num_mates++;
            flock_heading += boids[b].forward.xyz;
            flock_center += boids[b].position.xyz;
            if (sqr_dst < params.avoid_radius * params.avoid_radius) {
                avoidance -= offset / max(sqr_dst, 0.0001);
            }
        }
    }
    vec3 acceleration = vec3(0.0);
    acceleration += steer_towards(forward, velocity) * params.forward_weight;
    if (num_mates > 0) {
        flock_center /= float(num_mates);
        vec3 offset_to_center = flock_center - position;
        acceleration += steer_towards(flock_heading, velocity) * params.align_weight;
        acceleration += steer_towards(offset_to_center, velocity) * params.cohesion_weight;
        acceleration += steer_towards(avoidance, velocity) * params.separate_weight;
    }
    velocity += acceleration * params.delta_time;
    float speed = length(velocity);
    vec3 direction;
    if (speed > 0.0001) {
        direction = velocity / speed;
    } else {
        direction = forward;
    }
    speed = clamp(speed, params.min_speed, params.max_speed);
    velocity = direction * speed;
    boids[id].next_forward = vec4(direction, 0.0);
    boids[id].velocity = vec4(velocity, 0.0);
    boids[id].acceleration = vec4(acceleration, 0.0);
}
