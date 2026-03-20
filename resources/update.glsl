#[compute]
#version 450

layout(local_size_x = 1024, local_size_y = 1, local_size_z = 1) in;

struct Boid {
    vec4 position;
    vec4 forward;
    vec4 velocity;
    vec4 acceleration;
    vec4 avg_flock_heading;
    vec4 avg_avoidance;
    vec4 center_of_flockmates;
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
    float align_weight;
    float cohesion_weight;
    float separate_weight;
    float delta_time;
    float _pad0;
    float _pad1;
    float _pad2;
} params;

vec3 steer_towards(vec3 target_dir, vec3 velocity, float max_speed) {
    vec3  v   = normalize(target_dir) * max_speed - velocity;
    float len = length(v);
    return len > max_speed ? v / len * max_speed : v;
}

void main() {
    int id = int(gl_GlobalInvocationID.x);
    if (id >= int(params.num_boids)) return;

    vec3 pos = boids[id].position.xyz;
    vec3 fwd = boids[id].forward.xyz;
    vec3 vel = boids[id].velocity.xyz;

	// Temporary: scatter initial directions by id
	if (length(vel) < 0.0001) {
		float angle_y = float(id) * 2.399963;  // golden angle in radians
		float angle_x = float(id) * 1.618034;
		fwd = normalize(vec3(sin(angle_y) * cos(angle_x), sin(angle_x), cos(angle_y) * cos(angle_x)));
		boids[id].forward = vec4(fwd, 0.0);
		vel = fwd * params.min_speed;

		vel *= 0.01;
		boids[id].position += vec4(vel, 0.0);
	}

/*
    // --- Perception ---
    vec3 flock_heading = vec3(0.0);
    vec3 flock_centre  = vec3(0.0);
    vec3 avoidance     = vec3(0.0);
    int  num_mates     = 0;

    for (int b = 0; b < int(params.num_boids); b++) {
        if (b == id) continue;
        vec3  offset  = boids[b].position.xyz - pos;
        float sqr_dst = dot(offset, offset);
        if (sqr_dst < params.view_radius * params.view_radius) {
            num_mates++;
            flock_heading += boids[b].forward.xyz;
            flock_centre  += boids[b].position.xyz;
            if (sqr_dst < params.avoid_radius * params.avoid_radius) {
                avoidance -= offset / sqr_dst;
            }
        }
    }

    boids[id].avg_flock_heading    = vec4(flock_heading, 0.0);
    boids[id].avg_avoidance        = vec4(avoidance,     0.0);
    boids[id].center_of_flockmates = vec4(flock_centre,  float(num_mates));

    // --- Steering ---
    vec3 acceleration = vec3(0.0);
    if (num_mates > 0) {
        flock_centre /= float(num_mates);
        vec3 to_centre = flock_centre - pos;
        acceleration += steer_towards(flock_heading, vel, params.max_speed) * params.align_weight;
        acceleration += steer_towards(to_centre,     vel, params.max_speed) * params.cohesion_weight;
        acceleration += steer_towards(avoidance,     vel, params.max_speed) * params.separate_weight;
    }

    // --- Integrate ---
    vel        += acceleration * params.delta_time;
    float speed = length(vel);
    vec3  dir   = speed > 0.0001 ? vel / speed : fwd;
    speed       = clamp(speed, params.min_speed, params.max_speed);
    vel         = dir * speed;
    pos        += vel * params.delta_time;

    boids[id].position     = vec4(pos, 0.0);
    boids[id].forward      = vec4(dir, 0.0);
    boids[id].velocity     = vec4(vel, 0.0);
    boids[id].acceleration = vec4(acceleration, 0.0);
	*/
}
