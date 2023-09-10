
#include <metal_stdlib>
using namespace metal;

struct VertexIn {
    float3 position  [[attribute(0)]];
    float2 texCoords [[attribute(1)]];
};

struct VertexOut {
    float4 position [[position]];
    float2 texCoords;
};

[[vertex]]
VertexOut vertex_main(VertexIn in [[stage_in]]) {
    VertexOut out;
    out.position = float4(in.position, 1.0f);
    out.texCoords = in.texCoords;
    return out;
}

[[fragment]]
float4 fragment_main(VertexOut in [[stage_in]],
                     texture2d<uint, access::sample> colorMap [[texture(0)]])
{
    constexpr sampler blinearSampler(coord::normalized, filter::linear, mip_filter::linear);
    uint4 color = colorMap.sample(blinearSampler, in.texCoords);
    return float4(color.r);
}

uint2 getIdx(uint2 pos, uint2 t) {
    return uint2((pos.x + t.x) % (t.x), (pos.y + t.y) % (t.y));
}

kernel void stepLife(const device uint8_t* init [[buffer(0)]],
                     texture2d<uint, access::read> state[[texture(0)]],
                     texture2d<uint, access::write> output[[texture(1)]],
                     uint2 threadPositionInGrid [[thread_position_in_grid]],
                     uint2 threadsPerThreadgroup [[threads_per_threadgroup]],
                     uint2 threadgroupsPerGrid [[threadgroups_per_grid]])
{

    uint2 t = threadsPerThreadgroup * threadgroupsPerGrid;
    uint C = state.read(getIdx(threadPositionInGrid, t)).r;
    uint total = 0;
    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            if (!(x == 0 && y == 0)) { // exclude center
                if (state.read(getIdx(threadPositionInGrid + uint2(x, y), t)).r == 1) {
                    total += 1;
                }
            }
        }
    }

    uint o = (C && total == 2) || total == 3;
    output.write(o, threadPositionInGrid);
}
