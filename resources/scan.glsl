#[compute]
#version 450

#define FORWARD_COLLISION 1

struct Boid {
    vec3 position;
    int flags;
    vec3 forward;
    float padding1;
    vec3 next_forward;
    float padding2;
    vec3 velocity;
    float padding3;
    vec3 acceleration;
    float padding4;
};

layout(local_size_x = 1024, local_size_y = 1, local_size_z = 1) in;
layout(set = 0, binding = 0, std430) restrict buffer BoidBuffer {
    Boid boids[];
};
layout(set = 0, binding = 1, std430) readonly buffer SvoBuffer {
    int nodes[];
} svo;
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
    float svo_min_x;
    float svo_min_y;
    float svo_min_z;
    float svo_size;
    float svo_max_depth;
    float sensor_length;
    float padding1;
    float padding2;
    float padding3;
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

bool is_occluded(vec3 position) {
    vec3 node_min = vec3(params.svo_min_x, params.svo_min_y, params.svo_min_z);
    float size = params.svo_size;
    vec3 local = position - node_min;
    if (any(lessThan(local, vec3(0.0))) || any(greaterThanEqual(local, vec3(size)))) {
        return true;
    }
    int node_index = 0;
    for (int depth = 0; depth < int(params.svo_max_depth); depth++) {
        float half_size = size * 0.5;
        vec3 center = node_min + vec3(half_size);
        int slot = 0;
        if (position.x >= center.x) slot |= 1;
        if (position.y >= center.y) slot |= 2;
        if (position.z >= center.z) slot |= 4;
        node_min += vec3(
            (slot & 1) != 0 ? half_size : 0.0,
            (slot & 2) != 0 ? half_size : 0.0,
            (slot & 4) != 0 ? half_size : 0.0
        );
        size = half_size;
        int child = svo.nodes[node_index * 8 + slot];
        if (child == -2) {
            return true;
        } else if (child < 0) {
            return false;
        } else {
            node_index = child;
        }
    }
    return true;
}

void main() {
    int id = int(gl_GlobalInvocationID.x);
    if (id >= int(params.num_boids)) {
        return;
    }
    boids[id].flags = 0;
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
    if (is_occluded(position + forward * params.sensor_length)) {
        boids[id].flags |= FORWARD_COLLISION;

        // TODO: here
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
    boids[id].next_forward = direction;
    boids[id].velocity = velocity;
    boids[id].acceleration = acceleration;
}
