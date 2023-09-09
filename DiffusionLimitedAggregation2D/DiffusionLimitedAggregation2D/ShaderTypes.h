
#import <simd/simd.h>

typedef struct {
    simd_float4 color;
    simd_float2 center;
    float size;
    float age;
    float stuck;
} Particle;

typedef struct {
    simd_float4 position;
    float timeStep;
    float stickiness;
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
