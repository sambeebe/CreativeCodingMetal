
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
    var texture: MTLTexture!
    var textures = [MTLTexture]()
    var width = 1920
    var height = 1080
    
    init(device: MTLDevice, commandQueue: MTLCommandQueue) {
        self.device = device
        self.commandQueue = commandQueue
        makeResources()
        makePipelines()
    }

    func makeResources() {

        let vertexData: [Float] = [
        //    x     y    z    u    v
            -1.0,  1.0, 0.0, 0.0, 0.0, // upper left
            -1.0, -1.0, 0.0, 0.0, 1.0, // lower left
             1.0,  1.0, 0.0, 1.0, 0.0, // upper right
             1.0, -1.0, 0.0, 1.0, 1.0, // lower right
        ]

        vertexDescriptor.attributes[0].format = .float3
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].bufferIndex = 0

        vertexDescriptor.attributes[1].format = .float2
        vertexDescriptor.attributes[1].offset = MemoryLayout<Float>.stride * 3
        vertexDescriptor.attributes[1].bufferIndex = 0

        vertexDescriptor.layouts[0].stride = MemoryLayout<Float>.stride * 5

        vertexBuffer = device.makeBuffer(bytes: vertexData,
                                         length: MemoryLayout<Float>.stride * vertexData.count,
                                         options: [.storageModeShared])!

        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .r8Uint, width: width, height: height, mipmapped: false)
        textureDescriptor.usage = [.shaderRead, .shaderWrite]
        textureDescriptor.storageMode = .private
        
        //triple buffer
        for _ in 0..<3 {
            let texture = device.makeTexture(descriptor: textureDescriptor)!
            textures.append(texture)
        }
        
        let stagingBuffer = device.makeBuffer(length: width*height)!
        let stagingInput = stagingBuffer.contents().assumingMemoryBound(to: UInt8.self)
        
//        init with glider
//        stagingInput[0] = 1;
//        stagingInput[width] = 1;
//        stagingInput[width + 2] = 1;
//        stagingInput[width * 2] = 1;
//        stagingInput[width * 2 + 1] = 1;

        //init with random
        var rng = SystemRandomNumberGenerator()
        for i in 0..<width*height {
            stagingInput[i] = UInt8.random(in: 0...1, using: &rng)
        }
        
        let commandBuffer = commandQueue.makeCommandBuffer()!
        let blitCommandEncoder = commandBuffer.makeBlitCommandEncoder()!
        blitCommandEncoder.copy(
            from: stagingBuffer,
            sourceOffset: 0,
            sourceBytesPerRow: width,
            sourceBytesPerImage: width * height,
            sourceSize: MTLSize(width: width, height: height, depth: 1),
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
        renderPipelineDescriptor.vertexDescriptor = vertexDescriptor
        renderPipelineDescriptor.vertexFunction = vertexFunction
        renderPipelineDescriptor.fragmentFunction = fragmentFunction

        do {
            renderPipelineState = try device.makeRenderPipelineState(descriptor: renderPipelineDescriptor)
        } catch {
            fatalError("Could not create render pipeline state: \(error)")
        }
        
        let kernelFunction = library.makeFunction(name: "stepLife")!
        computePipelineState = try!device.makeComputePipelineState(function: kernelFunction)
        
    }

    func draw(_ renderCommandEncoder: MTLRenderCommandEncoder) {
        renderCommandEncoder.setFrontFacing(.counterClockwise)
        renderCommandEncoder.setCullMode(.back)
        renderCommandEncoder.setRenderPipelineState(renderPipelineState)
        renderCommandEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        renderCommandEncoder.setFragmentTexture(textures[textureIndex], index: 0)
        renderCommandEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
    }
    
    var textureIndex = 0
    
    func update(_ commandBuffer: MTLCommandBuffer) {
        let threadgroupSize = MTLSize(width: 32, height: 32, depth: 1)
        let threadgroupsPerGrid = MTLSize(width: (width + threadgroupSize.width - 1) / threadgroupSize.width,
                                          height: (height + threadgroupSize.height - 1) / threadgroupSize.height,
                                          depth: 1)
        
        let stateTexture = textures[textureIndex]
        textureIndex = (textureIndex + 1) % 3
        let outputTexture = textures[textureIndex]

        let computeCommandEncoder = commandBuffer.makeComputeCommandEncoder()!
        computeCommandEncoder.setTexture(stateTexture, index: 0)
        computeCommandEncoder.setTexture(outputTexture, index: 1)
        computeCommandEncoder.setComputePipelineState(computePipelineState)
        computeCommandEncoder.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadgroupSize)
        computeCommandEncoder.endEncoding()
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
        view.addSubview(mtkView)

        metalView = mtkView
        metalView.delegate = self
        metalView.colorPixelFormat = .bgra8Unorm_srgb
        metalView.clearColor = MTLClearColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
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

