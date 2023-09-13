import Cocoa
import Metal
import MetalKit

class Renderer {
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    var viewportSize = CGSize.zero
    
    var vertexDescriptor = MTLVertexDescriptor()
    var renderPipelineState: MTLRenderPipelineState!
    var computePipelineState: MTLComputePipelineState!
    var vertexBuffer: MTLBuffer!
    var indexBuffer: MTLBuffer!

    var texture: MTLTexture!
    var textures = [MTLTexture]()
    var width = 128
    var height = 128
    var depth = 128
    var bufferIndex = 0
    var cubeBuffer: MTLBuffer!
    var time: Float = 0.0
    var depthStencilState: MTLDepthStencilState!
    
    init(device: MTLDevice, commandQueue: MTLCommandQueue) {
        self.device = device
        self.commandQueue = commandQueue
        makeResources()
        makePipelines()
    }

    func makeResources() {
        let vertexData: [Float] = [
            // Front face
            -0.5,  0.5,  0.5,  0.0, 0.0,  0.0,  0.0,  1.0, // Upper left
            -0.5, -0.5,  0.5,  0.0, 1.0,  0.0,  0.0,  1.0, // Lower left
             0.5,  0.5,  0.5,  1.0, 0.0,  0.0,  0.0,  1.0, // Upper right
             0.5, -0.5,  0.5,  1.0, 1.0,  0.0,  0.0,  1.0, // Lower right

            // Back face
            -0.5,  0.5, -0.5,  1.0, 0.0,  0.0,  0.0, -1.0, // Upper left
            -0.5, -0.5, -0.5,  1.0, 1.0,  0.0,  0.0, -1.0, // Lower left
             0.5,  0.5, -0.5,  0.0, 0.0,  0.0,  0.0, -1.0, // Upper right
             0.5, -0.5, -0.5,  0.0, 1.0,  0.0,  0.0, -1.0, // Lower right

            // Top face
            -0.5,  0.5,  0.5,  0.0, 0.0,  0.0,  1.0,  0.0, // Front left
            -0.5,  0.5, -0.5,  0.0, 1.0,  0.0,  1.0,  0.0, // Back left
             0.5,  0.5,  0.5,  1.0, 0.0,  0.0,  1.0,  0.0, // Front right
             0.5,  0.5, -0.5,  1.0, 1.0,  0.0,  1.0,  0.0, // Back right

            // Bottom face
            -0.5, -0.5,  0.5,  0.0, 1.0,  0.0, -1.0,  0.0, // Front left
            -0.5, -0.5, -0.5,  0.0, 0.0,  0.0, -1.0,  0.0, // Back left
             0.5, -0.5,  0.5,  1.0, 1.0,  0.0, -1.0,  0.0, // Front right
             0.5, -0.5, -0.5,  1.0, 0.0,  0.0, -1.0,  0.0, // Back right

            // Left face
            -0.5,  0.5, -0.5,  1.0, 0.0, -1.0,  0.0,  0.0, // Upper back
            -0.5, -0.5, -0.5,  1.0, 1.0, -1.0,  0.0,  0.0, // Lower back
            -0.5,  0.5,  0.5,  0.0, 0.0, -1.0,  0.0,  0.0, // Upper front
            -0.5, -0.5,  0.5,  0.0, 1.0, -1.0,  0.0,  0.0, // Lower front

            // Right face
             0.5,  0.5, -0.5,  0.0, 0.0,  1.0,  0.0,  0.0, // Upper back
             0.5, -0.5, -0.5,  0.0, 1.0,  1.0,  0.0,  0.0, // Lower back
             0.5,  0.5,  0.5,  1.0, 0.0,  1.0,  0.0,  0.0, // Upper front
             0.5, -0.5,  0.5,  1.0, 1.0,  1.0,  0.0,  0.0  // Lower front
        ]

        
        let indices: [UInt16] = [
            0, 1, 2,
            2, 1, 3,
            6, 5, 4,
            7, 5, 6,
            10, 9, 8,
            11, 9, 10,
            12, 13, 14,
            14, 13, 15,
            16, 17, 18,
            18, 17, 19,
            22, 21, 20,
            23, 21, 22
        ]

        vertexDescriptor.attributes[0].format = .float3 //position
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].bufferIndex = 0

        vertexDescriptor.attributes[1].format = .float2 //uv
        vertexDescriptor.attributes[1].offset = MemoryLayout<Float>.stride * 3
        vertexDescriptor.attributes[1].bufferIndex = 0
        
        vertexDescriptor.attributes[2].format = .float3 //normals
        vertexDescriptor.attributes[2].offset = MemoryLayout<Float>.stride * 5
        vertexDescriptor.attributes[2].bufferIndex = 0

        vertexDescriptor.layouts[0].stride = MemoryLayout<Float>.stride * 8
        
        vertexDescriptor.attributes[3].format = .float4 // color
        vertexDescriptor.attributes[3].offset = 0
        vertexDescriptor.attributes[3].bufferIndex = 1

        vertexDescriptor.attributes[4].format = .float3// center
        vertexDescriptor.attributes[4].offset = MemoryLayout<Float>.stride * 4
        vertexDescriptor.attributes[4].bufferIndex = 1

        vertexDescriptor.attributes[5].format = .float // alive
        vertexDescriptor.attributes[5].offset = MemoryLayout<Float>.stride * 8
        vertexDescriptor.attributes[5].bufferIndex = 1
        
        vertexDescriptor.attributes[6].format = .float // size
        vertexDescriptor.attributes[6].offset = MemoryLayout<Float>.stride * 9
        vertexDescriptor.attributes[6].bufferIndex = 1

        vertexDescriptor.layouts[1].stride = MemoryLayout<Cube>.stride
        vertexDescriptor.layouts[1].stepFunction = .perInstance
        vertexDescriptor.layouts[1].stepRate = 1

        vertexBuffer = device.makeBuffer(bytes: vertexData,
                                         length: MemoryLayout<Float>.stride * vertexData.count,
                                         options: [.storageModeShared])!
        
        cubeBuffer = device.makeBuffer(length: MemoryLayout<Cube>.stride * width*height*depth,
                                               options: [.storageModeShared])!
        
        // Create index buffer
        indexBuffer = device.makeBuffer(
            bytes: indices,
            length: MemoryLayout<UInt16>.stride * indices.count,
            options: [.storageModeShared])!

        // Create a texture descriptor for a 3D texture.
        let textureDescriptor = MTLTextureDescriptor()
        textureDescriptor.textureType = .type3D
        textureDescriptor.width = width
        textureDescriptor.height = height
        textureDescriptor.depth = depth
        textureDescriptor.pixelFormat = .r8Uint
        textureDescriptor.usage = [.shaderRead, .shaderWrite]
        textureDescriptor.storageMode = .private

        for _ in 0..<3 {
            let texture = device.makeTexture(descriptor: textureDescriptor)!
            textures.append(texture)
        }


        bufferIndex = 1
        

        let stagingBuffer = device.makeBuffer(length: width*height * depth)!
        let stagingInput = stagingBuffer.contents().assumingMemoryBound(to: UInt8.self)

        let centerX = width / 2
        let centerY = height / 2
        let centerZ = depth / 2
        let halfWidth = width / 4
        let halfHeight = height / 4
        let halfDepth = depth / 4
        var rng = SystemRandomNumberGenerator()
        for z in (centerZ - halfDepth)..<(centerZ + halfDepth) {
            for y in (centerY - halfHeight)..<(centerY + halfHeight) {
                for x in (centerX - halfWidth)..<(centerX + halfWidth) {
                    let i = z * width * height + y * width + x
                    let r = UInt8.random(in: 0...1, using: &rng)
                    stagingInput[i] = r;
                }
            }
        }
        
        let commandBuffer = commandQueue.makeCommandBuffer()!
        let blitCommandEncoder = commandBuffer.makeBlitCommandEncoder()!
        blitCommandEncoder.copy(
            from: stagingBuffer,
            sourceOffset: 0,
            sourceBytesPerRow:  width,
            sourceBytesPerImage: width * height ,
            sourceSize: MTLSize(width: width, height: height, depth: depth),
            to: textures[0],
            destinationSlice: 0,
            destinationLevel: 0,
            destinationOrigin: MTLOrigin(x: 0, y: 0, z:0))
        
        blitCommandEncoder.endEncoding()
        commandBuffer.commit()
    }

    func makePipelines() {
        guard let library = device.makeDefaultLibrary() else {
            fatalError("Could not find default Metal library in the app bundle; does the target contain any Metal source files?")
        }

        let vertexFunction = library.makeFunction(name: "vertex_main")!
        let fragmentFunction = library.makeFunction(name: "fragment_main")!
        
        let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
        renderPipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm_srgb
        renderPipelineDescriptor.depthAttachmentPixelFormat = .depth32Float

        renderPipelineDescriptor.vertexDescriptor = vertexDescriptor
        renderPipelineDescriptor.vertexFunction = vertexFunction
        renderPipelineDescriptor.fragmentFunction = fragmentFunction
        
        renderPipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm_srgb
        renderPipelineDescriptor.colorAttachments[0].isBlendingEnabled = false
        
        renderPipelineDescriptor.rasterSampleCount = 4
        
        let depthStencilDescriptor = MTLDepthStencilDescriptor()
        depthStencilDescriptor.isDepthWriteEnabled = true
        depthStencilDescriptor.depthCompareFunction = .less
        depthStencilState = device.makeDepthStencilState(descriptor: depthStencilDescriptor)

        do {
            renderPipelineState = try device.makeRenderPipelineState(descriptor: renderPipelineDescriptor)
        } catch {
            fatalError("Could not create render pipeline state: \(error)")
        }
        
        let kernelFunction = library.makeFunction(name: "stepLife")!
        computePipelineState = try!device.makeComputePipelineState(function: kernelFunction)
        
    }

    func draw(_ renderCommandEncoder: MTLRenderCommandEncoder) {
        time += 0.01
        let aspectRatio = Float(viewportSize.width / viewportSize.height)
        let modelMatrix = simd_float4x4(rotationAbout: float3(0, 1, 0), by: Float(time)) *
                          simd_float4x4(diagonal: SIMD4<Float>(2.0, 2.0, 2.0, 1.0))
        let viewMatrix = simd_float4x4(translationBy: float3(0, 0, -2.5))
        let projectionMatrix = simd_float4x4(perspectiveProjectionFov: 60.0 * (.pi / 180),
                                             aspectRatio: aspectRatio,
                                             nearZ: 0.1,
                                             farZ: 5.0)
        var uniforms = Uniforms(modelMatrix: modelMatrix, viewMatrix: viewMatrix, projectionMatrix: projectionMatrix)
        renderCommandEncoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 2)
        
        renderCommandEncoder.setFrontFacing(.counterClockwise)
        renderCommandEncoder.setCullMode(.back)
        renderCommandEncoder.setRenderPipelineState(renderPipelineState)

        renderCommandEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        renderCommandEncoder.setVertexBuffer(cubeBuffer, offset: 0, index: 1)

        renderCommandEncoder.setDepthStencilState(depthStencilState)
	
        
        renderCommandEncoder.drawIndexedPrimitives(
            type: .triangle,
            indexCount: 36,//indices.count,
            indexType: .uint16,
            indexBuffer: indexBuffer,
            indexBufferOffset: 0,
            instanceCount: width*height*depth
        )
    }
    

    var textureIndex = 0

    func update(_ commandBuffer: MTLCommandBuffer) {
        let threadgroupSize = MTLSize(width: 8, height: 8, depth: 8)  // Or other values smaller or equal to 32
        let threadgroupsPerGrid = MTLSize(width: (width + threadgroupSize.width - 1) / threadgroupSize.width,
                                          height: (height + threadgroupSize.height - 1) / threadgroupSize.height,
                                          depth: (depth + threadgroupSize.depth - 1) / threadgroupSize.depth)
        
        let stateTexture = textures[textureIndex]
        textureIndex = (textureIndex + 1) % 3
        let outputTexture = textures[textureIndex]

        let computeCommandEncoder = commandBuffer.makeComputeCommandEncoder()!
        computeCommandEncoder.setComputePipelineState(computePipelineState)
        computeCommandEncoder.setTexture(stateTexture, index: 0)
        computeCommandEncoder.setTexture(outputTexture, index: 1)
        computeCommandEncoder.setBuffer(cubeBuffer, offset:0, index: 1)
        computeCommandEncoder.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadgroupSize)
        computeCommandEncoder.endEncoding()
    }
}

class ViewController: NSViewController, MTKViewDelegate {
    private var device: MTLDevice!
    private var commandQueue: MTLCommandQueue!
    private var renderer: Renderer!
    private var metalView: MTKView!
    
    var count = 0;
    var N = 5

    override func viewDidLoad() {
        super.viewDidLoad()

        device = MTLCreateSystemDefaultDevice()
        commandQueue = device.makeCommandQueue()!

        renderer = Renderer(device: device, commandQueue: commandQueue)

        let mtkView = MTKView(frame: view.bounds, device: device)
        mtkView.autoresizingMask = [.width, .height]
        mtkView.depthStencilPixelFormat = .depth32Float
        view.addSubview(mtkView)

        metalView = mtkView
        mtkView.sampleCount = 4
        metalView.delegate = self
        metalView.colorPixelFormat = .bgra8Unorm_srgb
//        metalView.clearColor = MTLClearColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        metalView.clearColor = MTLClearColor(red: 0.01, green: 0.01, blue: 0.01, alpha: 0.01)
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        renderer.viewportSize = size
    }

    func draw(in view: MTKView) {
        let commandBuffer = commandQueue.makeCommandBuffer()!

        guard let renderPassDescriptor = view.currentRenderPassDescriptor else { return }

       if(count%2==0)
       {
            renderer.update(commandBuffer)
       }
     //   renderer.update(commandBuffer)
        let renderCommandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
        renderer.draw(renderCommandEncoder)
        renderCommandEncoder.endEncoding()

        commandBuffer.present(view.currentDrawable!)
        commandBuffer.commit()
        count+=1
    }
}

