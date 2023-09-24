
#include <metal_stdlib>
using namespace metal;

struct VertexIn {
    float3 position  [[attribute(0)]];
    float2 texCoords [[attribute(1)]];

    float4 color     [[attribute(2)]];
    float2 center    [[attribute(3)]];
    float size       [[attribute(4)]];
    float age        [[attribute(5)]];
    float rotation   [[attribute(6)]];
    float2 velocity  [[attribute(7)]];
    float2 force     [[attribute(8)]];
    float ID         [[attribute(9)]];
};

struct Particle {
    float4 color;
    float2 center;
    float size;
    float age;
    float rotation;
    float2 velocity;
    float2 force;
    float gridID;
    
};

struct ParticleSystem {
    float4 position;
    float timeStep;
    float separation;
    float alignment;
    float cohesion;
    float max_velocity;
    float max_force;
    float neighbordist;
    float desiredseparation;
    uint32_t gridWidth;
    uint32_t gridHeight;
};

struct Uniforms {
    float4x4 modelMatrix;
    float4x4 viewMatrix;
    float4x4 projectionMatrix;
};

struct VertexOut {
    float4 position [[position]];
    float2 texCoords;
    float4 color;
};

struct ProjectionParameters {
    float left;
    float right;
    float top;
    float bottom;
    float near;
    float far;
};

float inOutExponential(float t) {
    if (t == 0.0) return 0.0;
    if (t == 1.0) return 1.0;
    
    t = t * 2.0;
    if (t < 1.0) {
        return 0.5 * pow(2.0, 10.0 * (t - 1.0));
    } else {
        return 0.5 * (-pow(2.0, -10.0 * (t - 1.0)) + 2.0);
    }
}


constant float M_PI = 3.14159265358979323846;
inline float g2r(float degrees) {return degrees * (M_PI / 180.0);}
inline float r2g(float radians) {return radians * (180.0 / M_PI);}

float remap(float value, float inMin, float inMax, float outMin, float outMax) {
    return outMin + (value - inMin) * (outMax - outMin) / (inMax - inMin);
}

// Function to convert HSV to RGB
float3 hsv2rgb(float3 c) {
    float4 K = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    float3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

float4 mapToColor(float h, float s, float v) {
    float3 colorRGB = hsv2rgb(float3(h, s, v));
    return float4(colorRGB, 1.0); // returning RGBA
}

float3 palette(float t, float3 a, float3 b, float3 c, float3 d) {
    return a + b * cos(6.28318 * (c * t + d));
}

float3 getColor(float t){
    float3 a = float3(0.5, 0.5, 0.5);
    float3 b = float3(0.5, 0.5, 0.5);
    float3 c = float3(1.0, 1.0, 1.0);
    float3 d = float3(0.0, 0.33, 0.67);
//    0.5, 0.5, 0.5        0.5, 0.5, 0.5    1.0, 1.0, 1.0    0.00, 0.10, 0.20
//    float3 a = float3(0.5, 0.5, 0.5);
//    float3 b = float3(0.5, 0.5, 0.5);
//    float3 c = float3(1.0, 1.0, 1.0);
//    float3 d = float3(0.0, 0.1, 0.2);

    return a + b * cos(6.28318 * (c * t + d));
}

[[vertex]]
VertexOut vertex_main(VertexIn in [[stage_in]],
                      constant Uniforms &uniforms [[buffer(2)]])
{
    float4x4 MVP = uniforms.projectionMatrix * uniforms.viewMatrix * uniforms.modelMatrix;

    // Rotation around Z-axis.
    float s = sin(in.rotation);
    float c = cos(in.rotation);
    float2x2 rotationMatrix = float2x2(c, -s,
                                       s,  c);
    
    // Apply the rotation to the particle position
    float2 rotatedPosition = rotationMatrix * in.position.xy;
    
    float3 particlePosition = float3(rotatedPosition, 0.0f) * float3(in.size) + float3(in.center, 0.0f);

    VertexOut out;
    out.position = MVP * float4(particlePosition, 1.0f);
    out.texCoords = in.texCoords;
//    out.color = mapToColor(remap(in.rotation, 0., M_PI * 2., 0., 1.),
//                           inOutExponential(remap(length(in.velocity), -1., 1., .06, .98)),
//                           .5);
    out.color = in.color;
    return out;
}

[[fragment]]
float4 fragment_main(VertexOut in [[stage_in]])
{
    return in.color;//float4(.5, 0, 0, .05);
}

constant float PHI = 1.61803398874989484820459;

float gold_noise(float2 xy, float seed) {
       return fract(tan(distance(xy * PHI, xy) * seed) * xy.x);
}

float2 limit(float2 v, float maxMagnitude) {
    if (length(v) > maxMagnitude) {
        return normalize(v) * maxMagnitude;
    }
    return v;
}


void emit(constant ParticleSystem &system, device Particle &particle, uint idx, uint t) {
    float randSeed = float(idx);
    float r[] = {
        gold_noise(float2(3.0, 5.0), randSeed),
        gold_noise(float2(7.0, 9.0), randSeed),
        gold_noise(float2(9.0, 11.0), randSeed),
        gold_noise(float2(11.0, 13.0), randSeed),
        gold_noise(float2(13.0, 15.0), randSeed)
    };

    particle.center = float2(
                             remap(r[0], 0., 1., -1., 1.),
                             remap(r[1], 0., 1., -1., 1.)
                                   );
    
    particle.size = remap(r[4], 0., 1., 0.0006, 0.006);
    particle.color = float4(1,0,0,0);
    particle.velocity = float2(remap(r[2], 0., 1., -1., 1.),
                               remap(r[3], 0., 1., -1., 1.)
                               );
    particle.size = .025;
    particle.age = 1.;

}




float2 separate(constant ParticleSystem &system,  device Particle const* particlesIn, uint idx, int t){
    float2 steer = float2(0.,0.);
    int count = 0;
    int i = idx;
    
    for (int j = 0; j < t; j++) {
        float d = distance(particlesIn[i].center, particlesIn[j].center);
        //TODO: check squared distances
        if((d>0) && d < system.desiredseparation){
            float2 diff = particlesIn[j].center - particlesIn[i].center;
            diff = normalize(diff);
            diff /= d;
            steer += diff;
            count++;
        }
    }
    if(count > 0){ steer /= count; }
    if(length(steer) > 0.) {
        steer = normalize(steer);
        steer *= system.max_velocity;
        steer -= particlesIn[i].velocity;
        steer = limit(steer, system.max_force);
    }
    return steer;
}

float2 align(constant ParticleSystem &system,  device Particle const* particlesIn, uint idx, int t){
    float2 sum = float2(0.,0.);
    int i = idx;
    
    int count = 0;
    for (int j = 0; j < t; j++) {
        float d = distance(particlesIn[i].center, particlesIn[j].center);
        if((d>0) && d < system.neighbordist){
            sum += particlesIn[i].velocity;
            count++;
        }
    }
    if(count>0){
        sum /= count;
        sum = normalize(sum);
        sum *= system.max_velocity;
        float2 steer = sum - particlesIn[i].velocity;
        steer = limit(steer, system.max_force);
        return steer;
    }
    else{return float2(0.,0.);}
}

float2 seek(float2 target, float2 position, float2 velocity, constant ParticleSystem &system){
    float2 desired = target - position;
    desired = normalize(desired);
    desired *= system.max_velocity;
    float2 steer = desired - velocity;
    steer = limit(steer, system.max_force);
    return steer;
}

float2 cohesion(constant ParticleSystem &system,  device Particle const* particlesIn, uint idx, int t){
    float2 sum = float2(0.,0.);
    int i = idx;
    
    int count = 0;
    for (int j = 0; j < t; j++) {
        float d = distance(particlesIn[i].center, particlesIn[j].center);
        if((d>0) && d < system.neighbordist){
            sum += particlesIn[i].center;
            count++;
        }
    }
    if(count>0){
        sum /= count;
        return seek(sum, particlesIn[i].center, particlesIn[i].velocity, system);
    }
    else {return float2(0.,0.);}
    
}

float2 wanted(constant ParticleSystem &system,  device Particle const* particlesIn, uint idx, float2 wantedPos, float radius){
    int i = idx;
    float2 toWanted = wantedPos - particlesIn[i].center;
    float d = length(toWanted);
    if (d < radius && d > 0.0) {
        toWanted = normalize(toWanted);
        float2 desiredVelocity = toWanted * system.max_velocity;
        float2 steer = desiredVelocity - particlesIn[i].velocity;
        steer = limit(steer, system.max_force);
        return steer;
    } else {return float2(0.0, 0.0); }
}


void update(constant ParticleSystem &system, constant ProjectionParameters &projectionParams, device Particle &particle, float timestep, float2 force) {
    float x_max = projectionParams.right;
    float x_min = projectionParams.left;
    float y_max = projectionParams.top;
    float y_min = projectionParams.bottom;
    particle.velocity += timestep * force;
    particle.velocity = limit(particle.velocity, system.max_velocity);
    particle.rotation = atan2(particle.velocity.x, particle.velocity.y);
    particle.center += particle.velocity * timestep;

    if(particle.center.x > x_max){
        particle.center.x = x_min;
    }
    if(particle.center.x < x_min){
       particle.center.x = x_max;
    }
    if(particle.center.y > y_max){
        particle.center.y = y_min;
    }
    if(particle.center.y < y_min){
        particle.center.y = y_max;
    }
    particle.force = 0.0;
    

}


[[kernel]]
void update_particle(
    constant ParticleSystem &system [[buffer(0)]],
    device Particle const* particlesIn [[ buffer(1) ]],
    device Particle* particlesOut [[ buffer(2) ]],
    constant ProjectionParameters &projectionParams [[buffer(3)]],
    device atomic_uint* histogram [[buffer(4)]],
    uint idx [[ thread_position_in_grid ]],
    uint threadsPerThreadgroup [[threads_per_threadgroup]],
    uint threadgroupsPerGrid [[threadgroups_per_grid]])
  {
    
    particlesOut[idx] = particlesIn[idx];
    device Particle& particle = particlesOut[idx];
    uint t = threadsPerThreadgroup * threadsPerThreadgroup;
    const float timestep = system.timeStep;

    float2 force = float2(0.,0.);
    force += separate(system, particlesIn, idx, t) * system.separation;
    force += align(system, particlesIn, idx, t) * system.alignment;
    force += cohesion(system, particlesIn, idx, t) * system.cohesion;
   // force += wanted(system, particlesIn, idx, float2(0.,0.), 0.45) * -1.5;

    if (particlesOut[idx].age != 1.) {
        emit(system, particlesOut[idx], idx, t);
        
    } else {
        update(system, projectionParams, particlesOut[idx], timestep, force);
        
        float cellSizeX = 1.0 / system.gridWidth;
        float cellSizeY = 1.0 / system.gridHeight;
        //
        int cellX = int((particle.center.x ) / cellSizeX);
        int cellY = int((particle.center.y ) / cellSizeY);
        int cellIndex = cellY * system.gridWidth + cellX;
        
        particle.color = float4(getColor((float)cellIndex / 100.0), 1.0);
        //each grid cell now has a value representing how many particles it contains
        atomic_fetch_add_explicit(histogram + cellIndex, 1, memory_order_relaxed);
    }
}
