
import Cocoa
import Metal
import MetalKit
import SwiftUI


class Renderer {
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    var viewportSize = CGSize.zero

    let particleCount = 30000

    var vertexDescriptor = MTLVertexDescriptor()
    var renderPipelineState: MTLRenderPipelineState!
    var particleComputePipelineState: MTLComputePipelineState!
    var vertexBuffer: MTLBuffer!
    var particleBuffers = [MTLBuffer]()
    var texture: MTLTexture!
    var bufferIndex = 0
    var projectionParams = ProjectionParameters(left: -1, right: 1, top: 1, bottom: -1, near: -1, far: 1)
    let projectionMatrix = simd_float4x4(orthographicProjectionWithLeft: -1, top: 1 , right: 1, bottom: -1 , near: -1, far: 1)
//    var projectionParams = ProjectionParameters(left: 0, right: 1.92, top: 1.08, bottom: 0.0, near: -1, far: 1)
//    let projectionMatrix = simd_float4x4(orthographicProjectionWithLeft: 0, top: 1.08 , right: 1.92, bottom: 0 , near: -1, far: 1)
    var uniforms = Uniforms()
    
    init(device: MTLDevice, commandQueue: MTLCommandQueue) {
        self.device = device
        self.commandQueue = commandQueue

        makeResources()
        makePipelines()
        
        uniforms = Uniforms(modelMatrix: matrix_identity_float4x4,
                                viewMatrix: matrix_identity_float4x4,
                                projectionMatrix: projectionMatrix)
        
    }

    func makeResources() {

        let vertexData: [Float] = [
        //    x     y    z    u    v
            -0.5,  0.5, 0.0, 0.0, 0.0, // upper left
            -0.5, -0.5, 0.0, 0.0, 1.0, // lower left
             0.5,  0.5, 0.0, 1.0, 0.0, // upper right
             0.5, -0.5, 0.0, 1.0, 1.0, // lower right
        ]

        vertexDescriptor.attributes[0].format = .float3
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].bufferIndex = 0

        vertexDescriptor.attributes[1].format = .float2
        vertexDescriptor.attributes[1].offset = MemoryLayout<Float>.stride * 3
        vertexDescriptor.attributes[1].bufferIndex = 0

        vertexDescriptor.layouts[0].stride = MemoryLayout<Float>.stride * 5

        vertexDescriptor.attributes[2].format = .float4 // color
        vertexDescriptor.attributes[2].offset = 0
        vertexDescriptor.attributes[2].bufferIndex = 1

        vertexDescriptor.attributes[3].format = .float2 // center
        vertexDescriptor.attributes[3].offset = MemoryLayout<Float>.stride * 4
        vertexDescriptor.attributes[3].bufferIndex = 1

        vertexDescriptor.attributes[4].format = .float // size
        vertexDescriptor.attributes[4].offset = MemoryLayout<Float>.stride * 6
        vertexDescriptor.attributes[4].bufferIndex = 1

        vertexDescriptor.attributes[5].format = .float // age
        vertexDescriptor.attributes[5].offset = MemoryLayout<Float>.stride * 7
        vertexDescriptor.attributes[5].bufferIndex = 1
        
        vertexDescriptor.attributes[6].format = .float2 // velocity
        vertexDescriptor.attributes[6].offset = MemoryLayout<Float>.stride * 9
        vertexDescriptor.attributes[6].bufferIndex = 1
        
        vertexDescriptor.attributes[7].format = .float; // stuck
        vertexDescriptor.attributes[7].offset = MemoryLayout<Float>.stride * 11
        vertexDescriptor.attributes[7].bufferIndex = 1;

        vertexDescriptor.layouts[1].stride = MemoryLayout<Particle>.stride
        vertexDescriptor.layouts[1].stepFunction = .perInstance
        vertexDescriptor.layouts[1].stepRate = 1

        vertexBuffer = device.makeBuffer(bytes: vertexData,
                                         length: MemoryLayout<Float>.stride * vertexData.count,
                                         options: [.storageModeShared])!

        for _ in 0..<3 {
            let particleBuffer = device.makeBuffer(length: MemoryLayout<Particle>.stride * particleCount,
                                                   options: [.storageModeShared])!
            particleBuffers.append(particleBuffer)
        }
        bufferIndex = 0

    }

    func makePipelines() {
        guard let library = device.makeDefaultLibrary() else {
            fatalError("Could not find default Metal library in the app bundle; does the target contain any Metal source files?")
        }

        let vertexFunction = library.makeFunction(name: "vertex_main")!
        let fragmentFunction = library.makeFunction(name: "fragment_main")!

        let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
        renderPipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm_srgb
        renderPipelineDescriptor.vertexDescriptor = vertexDescriptor
        renderPipelineDescriptor.vertexFunction = vertexFunction
        renderPipelineDescriptor.fragmentFunction = fragmentFunction
        renderPipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm_srgb

        renderPipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .one
        renderPipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        renderPipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        renderPipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
        renderPipelineDescriptor.colorAttachments[0].rgbBlendOperation = .add
        renderPipelineDescriptor.colorAttachments[0].alphaBlendOperation = .add
        
        renderPipelineDescriptor.rasterSampleCount = 4

        do {
            renderPipelineState = try device.makeRenderPipelineState(descriptor: renderPipelineDescriptor)
        } catch {
            fatalError("Could not create render pipeline state: \(error)")
        }

        let particleFunction = library.makeFunction(name: "update_particle")!
        do {
            particleComputePipelineState = try device.makeComputePipelineState(function: particleFunction)
        } catch {
            fatalError("Could not create compute pipeline state: \(error)")
        }
    }

    func update(_ commandBuffer: MTLCommandBuffer) {

        var particleSystem = ParticleSystem(position: simd_float4(0.5, 0.5, 0, 1),
                                            timeStep: 0.003,
                                            stickiness: 0.5
        )


        let computeCommandEncoder = commandBuffer.makeComputeCommandEncoder()!
        computeCommandEncoder.setComputePipelineState(particleComputePipelineState)
        computeCommandEncoder.setBytes(&particleSystem, length: MemoryLayout<ParticleSystem>.stride, index: 0)
        computeCommandEncoder.setBuffer(particleBuffers[bufferIndex], offset: 0, index: 1)
        bufferIndex = (bufferIndex + 1) % particleBuffers.count
        
        computeCommandEncoder.setBuffer(particleBuffers[bufferIndex], offset: 0, index: 2)
        
        computeCommandEncoder.setBytes(&projectionParams, length: MemoryLayout<ProjectionParameters>.stride, index: 3)
        
    //    let threadgroupsPerGrid  = MTLSize(width: particleCount, height: 1, depth: 1);
    //    let  threadgroupSize = MTLSize(width: 32, height: 1, depth: 1);
     //   computeCommandEncoder.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadgroupSize)

       computeCommandEncoder.dispatchThreads(MTLSize(width: particleCount, height: 1, depth: 1),
                                              threadsPerThreadgroup: MTLSize(width: 32, height: 1, depth: 1))
        computeCommandEncoder.endEncoding()
    }

    func draw(_ renderCommandEncoder: MTLRenderCommandEncoder) {
        renderCommandEncoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 2)

        renderCommandEncoder.setFrontFacing(.counterClockwise)
        renderCommandEncoder.setCullMode(.back)
        renderCommandEncoder.setRenderPipelineState(renderPipelineState)
        renderCommandEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        renderCommandEncoder.setVertexBuffer(particleBuffers[bufferIndex], offset: 0, index: 1)
        renderCommandEncoder.setFragmentTexture(texture, index: 0)
        renderCommandEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4, instanceCount: particleCount)
    }
}


class ViewController: NSViewController, MTKViewDelegate {
    private var device: MTLDevice!
    private var commandQueue: MTLCommandQueue!
    private var renderer: Renderer!
    private var metalView: MTKView!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        device = MTLCreateSystemDefaultDevice()
        commandQueue = device.makeCommandQueue()!

        renderer = Renderer(device: device, commandQueue: commandQueue)

        let mtkView = MTKView(frame: view.bounds, device: device)
        mtkView.autoresizingMask = [.width, .height]
        mtkView.sampleCount = 4

        view.addSubview(mtkView)

        metalView = mtkView
        metalView.delegate = self
        metalView.colorPixelFormat = .bgra8Unorm_srgb
        metalView.clearColor = MTLClearColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.0)


    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        renderer.viewportSize = size
    }

    func draw(in view: MTKView) {
        let commandBuffer = commandQueue.makeCommandBuffer()!

        guard let renderPassDescriptor = view.currentRenderPassDescriptor else { return }

        renderer.update(commandBuffer)

        let renderCommandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
        renderer.draw(renderCommandEncoder)
        renderCommandEncoder.endEncoding()

        commandBuffer.present(view.currentDrawable!)
        commandBuffer.commit()
    }
}

