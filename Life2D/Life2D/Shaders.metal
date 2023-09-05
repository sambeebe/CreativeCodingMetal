
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

uint2 getIdx(uint x, uint y, uint2 t) {
    uint2 i = uint2((x) % (t.x), (y) % (t.y));
    return i;
}


kernel void stepLife(const device uint8_t* init [[buffer(0)]],
                     texture2d<uint, access::read> state[[texture(0)]],
                     texture2d<uint, access::write> output[[texture(1)]],
                     uint2 gridSize [[thread_position_in_grid]],
                     uint2 threadsPerThreadgroup [[threads_per_threadgroup]],
                     uint2 threadgroupsPerGrid [[threadgroups_per_grid]])
{
    uint x = gridSize.x;
    uint y = gridSize.y;
    uint2 t = threadsPerThreadgroup * threadgroupsPerGrid;

    uint C = state.read(getIdx(x, y, t)).r;
    uint N = state.read(getIdx(x, y - 1, t)).r;
    uint NE = state.read(getIdx(x + 1, y - 1, t)).r;
    uint NW = state.read(getIdx(x - 1, y - 1, t)).r;
    uint E = state.read(getIdx(x + 1, y, t)).r;
    uint W = state.read(getIdx(x - 1, y, t)).r;
    uint S = state.read(getIdx(x, y + 1, t)).r;
    uint SE =state.read(getIdx(x + 1, y + 1, t)).r;
    uint SW =state.read(getIdx(x - 1, y + 1, t)).r;
    
    uint total = N + NE + NW + E + W + S + SE + SW;
    uint o = (C && total == 2) || total == 3;
    output.write(o, gridSize);
}
