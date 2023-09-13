
#import <simd/simd.h>

typedef struct {
    simd_float4 color;
    simd_float2 center;
    float size;
    float age;
    float rotation;
    simd_float2 velocity;
    simd_float2 force;
    
} Particle;

typedef struct {
    simd_float4 position;
    float timeStep;
    float separation;
    float alignment;
    float cohesion;
    float max_velocity;
    float max_force;
    float neighbordist;
    float desiredseparation;
} ParticleSystem;

struct Uniforms {
    simd_float4x4 modelMatrix;
    simd_float4x4 viewMatrix;
    simd_float4x4 projectionMatrix;
};

struct ProjectionParameters {
    float left;
    float right;
    float top;
    float bottom;
    float near;
    float far;
};
