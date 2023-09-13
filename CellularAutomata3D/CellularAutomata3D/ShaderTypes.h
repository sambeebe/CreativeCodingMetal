#import <simd/simd.h>

typedef struct {
    simd_float4 color;
    simd_float3 center;
    float alive;
    float size
} Cube;

typedef struct {
    simd_float4 position;
} Simulation;

struct Uniforms {
    simd_float4x4 modelMatrix;
    simd_float4x4 viewMatrix;
    simd_float4x4 projectionMatrix;

};

