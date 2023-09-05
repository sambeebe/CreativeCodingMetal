import QuartzCore
import Metal
import simd

typealias float2 = SIMD2<Float>
typealias float3 = SIMD3<Float>
typealias float4 = SIMD4<Float>

extension SIMD4 {
    var xyz: SIMD3<Scalar> {
        SIMD3(x, y, z)
    }
    
    init(_ v: SIMD3<Scalar>, _ w: Scalar) {
        self.init(v.x, v.y, v.z, w)
    }
}

struct packed_float3 {
    var x, y, z: Float

    init() {
        x = 0.0
        y = 0.0
        z = 0.0
    }
    
    init(_ x: Float, _ y: Float, _ z: Float) {
        self.x = x
        self.y = y
        self.z = z
    }
    
    init(_ v: float3) {
        self.x = v.x
        self.y = v.y
        self.z = v.z
    }
}

extension float3 {
    init(_ v: packed_float3) {
        self.init(v.x, v.y, v.z)
    }
}

extension float4x4 {
    init(upperLeft: float3x3) {
        self.init(float4(upperLeft[0],  0.0),
                  float4(upperLeft[1],  0.0),
                  float4(upperLeft[2],  0.0),
                  float4(0.0, 0.0, 0.0, 1.0))
    }

    init(translation t: float3) {
        self.init(float4(1, 0, 0, 0),
                  float4(0, 1, 0, 0),
                  float4(0, 0, 1, 0),
                  float4(t.x, t.y, t.z, 1))
    }

    var upperLeft: float3x3 {
        return float3x3(self[0].xyz, self[1].xyz, self[2].xyz)
    }

    init(perspectiveProjectionFOV fov: Float, aspectRatio: Float, near: Float, far: Float) {
        let s = 1 / tanf(fov * 0.5)
        let q = -far / (far - near)

        self.init(float4(s/aspectRatio, 0, 0, 0),
                  float4(0, s, 0, 0),
                  float4(0, 0, q, -1),
                  float4(0, 0, q * near, 0))
    }
}

func look(along toward: float3, up: float3, from eye: float3) -> float4x4 {
    var u = up
    var f = toward
    let s = normalize(cross(f, u))
    u = normalize(cross(s, f))
    f = -f
    let t = eye
    let view = float4x4(float4(s.x, s.y, s.z, 0),
                        float4(u.x, u.y, u.z, 0),
                        float4(f.x, f.y, f.z, 0),
                        float4(t.x, t.y, t.z, 1.0))
    return view
}

func look(at: float3, up: float3, from eye: float3) -> float4x4 {
    return look(along: normalize(at - eye), up: up, from: eye)
}

extension MTLOrigin {
    static var zero: MTLOrigin {
        return MTLOrigin(x: 0, y: 0, z: 0)
    }
}

func interpolate(_ a: packed_float3, _ b: packed_float3, _ t: Float) -> float3 {
    let av = float3(a), bv = float3(b)
    return av + t * (bv - av)
}

func interpolate(_ a: simd_quatf, _ b: simd_quatf, _ t: Float) -> simd_quatf {
    return simd_slerp(a, b, t)
}

func interpolate(_ a: Any, _ b: Any, _ t: Float) -> Any {
    if let af = a as? packed_float3, let bf = b as? packed_float3 {
        return interpolate(af, bf, t)
    }
    if let aq = a as? simd_quatf, let bq = b as? simd_quatf {
        return interpolate(aq, bq, t)
    }
    fatalError("Unsupported or incompatible types for interpolation")
}
