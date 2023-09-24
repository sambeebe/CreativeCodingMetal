
#include <metal_stdlib>
using namespace metal;

struct Cube {
    float4 color;
    float3 center;
    float alive;
    float size;
};

struct Uniforms {
    float4x4 modelMatrix;
    float4x4 viewMatrix;
    float4x4 projectionMatrix;
};

struct VertexIn {
    float3 position  [[attribute(0)]];
    float2 texCoords [[attribute(1)]];
    float3 normal    [[attribute(2)]];
    float4 color     [[attribute(3)]];
    float3 center    [[attribute(4)]];
    float alive      [[attribute(5)]];
    float size       [[attribute(6)]];
};

struct VertexOut {
    float4 position [[position]];
    float3 viewPosition;
    float2 texCoords;
    float3 normal;
    float4 color;
};

[[vertex]]
VertexOut vertex_main(VertexIn in [[stage_in]],
                      constant Uniforms &uniforms [[buffer(2)]])
{
    float4x4 MVP = uniforms.projectionMatrix * uniforms.viewMatrix * uniforms.modelMatrix;
    float4 viewPosition = uniforms.viewMatrix * uniforms.modelMatrix * float4(in.position, 1.0);
    float3 cubePosition = in.position * in.size + in.center;

    VertexOut out;
    out.position = MVP * float4(cubePosition, in.alive ? 1 : 0);
    out.viewPosition = viewPosition.xyz;
    out.texCoords = in.texCoords;
    out.normal = (uniforms.viewMatrix * uniforms.modelMatrix * float4(in.normal, 0.0)).xyz;
    out.color = in.color;
    return out;
}

[[fragment]]
float4 fragment_main(VertexOut in [[stage_in]])
{
    float3 viewPosition = in.viewPosition;
    float4 baseColor = in.color;
    float specularExponent = 1.0;

    float3 N = normalize(in.normal);
    float3 V = normalize(float3(0) - viewPosition);

    float3 litColor { 0 };

    float ambientFactor = .50;
    float diffuseFactor = .75;
    float specularFactor = .0;
    float intensity = 0.9;
    
    float3 lightDirection =  float3(0,0,1);
    float3 L = normalize(lightDirection);
    float3 H = normalize(L + V);
    diffuseFactor = saturate(dot(N, L)); //gives you the cosine(angle)
    specularFactor = powr(saturate(dot(N, H)), specularExponent);
    
    litColor += (ambientFactor + diffuseFactor + specularFactor) * intensity * baseColor.rgb;
    return float4(litColor * baseColor.a, baseColor.a);
}

uint3 getIdx(int3 pos, int3 t) {
    return uint3((pos.x + t.x) % t.x, (pos.y + t.y) % t.y, (pos.z + t.z) % t.z);
}

kernel void stepLife(const device uint8_t* init [[buffer(0)]],
                       device Cube* cubes [[buffer(1)]],
                       texture3d<uint, access::read> state[[texture(0)]],
                       texture3d<uint, access::write> output[[texture(1)]],
                       uint3 threadPositionInGrid [[thread_position_in_grid]],
                       uint3 threadsPerThreadgroup [[threads_per_threadgroup]],
                       uint3 threadgroupsPerGrid [[threadgroups_per_grid]])
{
    int3 pos = (int3)threadPositionInGrid;
    int3 t = (int3)threadsPerThreadgroup * (int3)threadgroupsPerGrid;
    uint index = (pos.z * t.x * t.y) + (pos.y * t.x) + pos.x;
    uint C = state.read(getIdx(pos, t)).r;
    device Cube &cube = cubes[index];
    cube.size = 1.0 / (float)t.x;
    uint total = 0;

    bool isVonNeumann = false;  // Set this to true for Von Neumann, false for Moore

    for (int z = -1; z <= 1; z++) {
        for (int y = -1; y <= 1; y++) {
            for (int x = -1; x <= 1; x++) {
                if (!(x == 0 && y == 0 && z == 0)) { // exclude center
                    if (isVonNeumann && (abs(x) + abs(y) + abs(z)) > 1) {
                        continue;  // Skip diagonal neighbors in Von Neumann
                    }
                    if (state.read(getIdx(pos + int3(x, y, z), t)).r == 1) {
                        total += 1;
                    }
                }
            }
        }
    }


    float3 normalizedPos = float3(float(pos.x) / float(t.x),
                                  float(pos.y) / float(t.y),
                                  float(pos.z) / float(t.z));
		
    cube.center = normalizedPos - .5;

    int nextState = C;
    if (C == 0) {
        if (total == 4) {
            nextState = 1;
        }
    } else if (C == 1) {
        if (total != 4) {
            nextState = 2;
        }
    } else {
        nextState = (C + 1) % 5;
    }
    
    cube.color = float4(normalize(cube.center + 0.5),1);
    cube.alive = (int)nextState;

    uint o = (int)cube.alive;
    output.write(o, threadPositionInGrid);
}
