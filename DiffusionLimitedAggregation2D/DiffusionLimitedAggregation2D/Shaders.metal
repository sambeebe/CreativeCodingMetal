
#include <metal_stdlib>
using namespace metal;

struct VertexIn {
    float3 position  [[attribute(0)]];
    float2 texCoords [[attribute(1)]];

    float4 color     [[attribute(2)]];
    float2 center    [[attribute(3)]];
    float size       [[attribute(4)]];
    float age        [[attribute(5)]];
    float2 velocity  [[attribute(6)]];
};

struct Particle {
    float4 color;
    float2 center;
    float size;
    float age;
    float2 velocity;
    float stuck;
};

struct ParticleSystem {
    float4 position;
    float timeStep;
    float stickiness;
};

struct Uniforms {
    float4x4 modelMatrix;
    float4x4 viewMatrix;
    float4x4 projectionMatrix;
};

struct VertexOut {
    float4 position [[position]];
    float2 texCoords;
    float2 center;
    float4 color;
    float size;

};

struct ProjectionParameters {
    float left;
    float right;
    float top;
    float bottom;
    float near;
    float far;
};

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

float easeInCirc(float x) {
    return 1.0 - sqrt(1.0 - (x * x));
}


[[vertex]]
VertexOut vertex_main(VertexIn in [[stage_in]],
                      constant Uniforms &uniforms [[buffer(2)]])
{
    float4x4 MVP = uniforms.projectionMatrix * uniforms.viewMatrix * uniforms.modelMatrix;

    float3 particlePosition = in.position * float3(in.size) + float3(in.center, 0.0f);

    VertexOut out;
    out.position = MVP * float4(particlePosition, 1.0f);
    out.texCoords = in.texCoords;
    out.center = in.center;
    out.color = in.color;
    out.size = in.size;

    return out;
}

float3 getColor(float t){
    float3 a = float3(0.5, 0.5, 0.5);
    float3 b = float3(0.5, 0.5, 0.5);
    float3 c = float3(1.0, 1.0, 1.0);
    float3 d = float3(0.0, 0.33, 0.67);
    return a + b * cos(6.28318 * (c * t + d));
}

[[fragment]]
float4 fragment_main(VertexOut in [[stage_in]],
                     texture2d<float, access::sample> colorMap [[texture(0)]])
{
    constexpr sampler blinearSampler(coord::normalized, filter::linear, mip_filter::linear);

//    float4 color = colorMap.sample(blinearSampler, in.texCoords) * in.color;
    float4 texcolor = colorMap.sample(blinearSampler, in.texCoords);
    float3 color = texcolor.rgb * in.color.rgb;
    return float4(color*texcolor.a,texcolor.a);//float4(1, 0, 0, 1);
}


constant float PHI = 1.61803398874989484820459;

float gold_noise(float2 xy, float seed) {
       return fract(tan(distance(xy * PHI, xy) * seed) * xy.x);
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
    
    float size =easeInCirc(r[4]);// r[4] * r[4] * r[4] * r[4] * r[4] ; //easing
    particle.color = float4(getColor(size),1);
    particle.size = remap(size, 0., 1., 0.002, 0.03);

    //particle.color = float4(1,0,0,0);

    particle.velocity = float2(remap(r[2], 0., 1., -1., 1.),
                               remap(r[3], 0., 1., -1., 1.)
                               );
    particle.age = 1.;
    particle.stuck = 0.;
   // center-based growth
    if(idx == 0){
        particle.stuck = 1.;
        particle.size = .05;
        particle.center = float2(0.,0.);
    }
}

bool stick(constant ParticleSystem &system, device Particle const* particlesIn, uint idx, int t) {
    int i = idx;
    //float r = gold_noise(float2(3.0, 5.0), float(idx));
    for (int j = 0; j < t; j++) {
        //instead of using distance(), compare squared distances to sqrt
        float dx = particlesIn[i].center.x - particlesIn[j].center.x;
        float dy = particlesIn[i].center.y - particlesIn[j].center.y;
        float squaredDist = (dx * dx) + (dy * dy);
        float squaredSize = (particlesIn[i].size + particlesIn[j].size) * (particlesIn[i].size + particlesIn[j].size);
        
        if (squaredDist > 0 && squaredDist < squaredSize && particlesIn[j].stuck
            && particlesIn[i].size < particlesIn[j].size
            ) {
            return true;
        }
    }
    return false;
}



void update(constant ParticleSystem &system, constant ProjectionParameters &projectionParams, device Particle &particle, float timestep) {
    float x_max = projectionParams.right;
    float x_min = projectionParams.left;
    float y_max = projectionParams.top;
    float y_min = projectionParams.bottom;

    if(particle.center.x > x_max){
   //     particle.center.x = x_min;
        particle.center.x -= .01;
        particle.stuck = 1.;
    }
    if(particle.center.x < x_min){
      //  particle.center.x = x_max ;
        particle.center.x += .01;
        particle.stuck = 1.;
    }
    if(particle.center.y > y_max){
        particle.center.y -= .01;
        particle.stuck = 1.;
     //   particle.center.y = y_min;
    }
    if(particle.center.y < y_min){
        particle.center.y += .01;
        particle.stuck = 1.;
       // particle.center.y = y_max;
    }
    
    if(particle.stuck){
        //particle.color = float4(0,0,1,1);

        particle.velocity = float2(0.,0.);
    }
    
    particle.center += particle.velocity * timestep;
}
    
[[kernel]]
void update_particle(
    constant ParticleSystem &system [[buffer(0)]],
    device Particle const* particlesIn [[ buffer(1) ]],
    device Particle* particlesOut [[ buffer(2) ]],
    constant ProjectionParameters &projectionParams [[buffer(3)]],
    uint idx [[ thread_position_in_grid ]],
    uint threadsPerThreadgroup [[threads_per_threadgroup]],
    uint threadgroupsPerGrid [[threadgroups_per_grid]])
 {
     
    uint t = threadsPerThreadgroup * threadgroupsPerGrid;
    particlesOut[idx] = particlesIn[idx];

    const float timestep = system.timeStep;

    if (particlesOut[idx].age != 1.) {
        emit(system, particlesOut[idx], idx, t);
        
    } else {
        if(particlesIn[idx].stuck != 1.) {
            particlesOut[idx].stuck = stick(system, particlesIn, idx, t);
        }
        update(system, projectionParams, particlesOut[idx], timestep);
    }
}
