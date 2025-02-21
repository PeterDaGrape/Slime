//
//  Renderer.swift
//  MetalStart
//
//  Created by Peter Vine on 04/06/2024.
//

import MetalKit
import simd

class Renderer: NSObject, MTKViewDelegate {
    
    var species: [SIMD3<Float>]
    var agents: [Agent] = []
    var agentData: AgentData
    
    var options: Options
    
    let numberAgents: Int

    var parent: MetalView
    
    var width: Int
    var height: Int
    
    var prevFrameTexture: MTLTexture?
    let textureDescriptor: MTLTextureDescriptor
    var newFrameTexture: MTLTexture?
    var frameTexture: MTLTexture?

    var metalDevice: MTLDevice!
    var metalCommandQueue: MTLCommandQueue!
    let pipelineState: MTLRenderPipelineState
    
    let computePipelineState: MTLComputePipelineState!
    let blurPipelineState: MTLComputePipelineState!
    
    let vertexBuffer: MTLBuffer
    
    let agentsBuffer: MTLBuffer

    var vertices = [
        Vertex(position: [-1, -1], textureCoord: [0, 1]),
        Vertex(position: [1, -1], textureCoord: [1, 1]),
        Vertex(position: [-1, 1], textureCoord: [0, 0]),
        Vertex(position: [1, 1], textureCoord: [1, 0])
    ]

    
    
    init(_ parent: MetalView, agentData: AgentData, options: Options, species: [SIMD3<Float>]) {
        
        self.agentData = agentData
        self.species = species
        
        
        self.options = options
 
        self.numberAgents = Int(options.numberAgents)

        self.parent = parent
        if let metalDevice = MTLCreateSystemDefaultDevice() {
            self.metalDevice = metalDevice
        }
    
        self.metalCommandQueue = metalDevice.makeCommandQueue()

        self.width = Int(agentData.width)
        self.height = Int(agentData.height)
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()

        let library = metalDevice.makeDefaultLibrary()
        
        pipelineDescriptor.vertexFunction = library?.makeFunction(name: "vertexShader")
        pipelineDescriptor.fragmentFunction = library?.makeFunction(name: "fragmentShader")
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        
        do {
            try pipelineState = metalDevice.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            fatalError()
        }
        print(width, height)
        
        
        for i in 0...numberAgents - 1 {
            
            let radius: Float = Float(min(height, width) / 2)
        
            
            var randomCirclePos: [Float] = [Float.infinity, Float.infinity]
            
            while (sqrt(pow(randomCirclePos[0], 2) + pow(randomCirclePos[1], 2)) > radius){
                randomCirclePos = [Float.random(in: -radius...radius), Float.random(in: -radius...radius)]
            }
            
            let centeredPosition: [Float] = [Float(width / 2) + randomCirclePos[0], Float(height / 2) + randomCirclePos[1]]
            
            let angle: Float = atan2(centeredPosition[1] - Float(height) / 2, centeredPosition[0] - Float(width) / 2) - .pi / 2
            let agent: Agent = Agent(position: vector_float2(centeredPosition), angle: angle, index: Int32(i))
            //Float.random(in:0...2 * Float.pi)
            self.agents.append(agent)
    
        }
        
        agentsBuffer = metalDevice.makeBuffer(bytes: agents, length: agents.count * MemoryLayout<Agent>.stride, options: [])!
        
        vertexBuffer = metalDevice.makeBuffer(bytes: vertices, length: vertices.count * MemoryLayout<Vertex>.stride, options: [])!
        
        
        

        
        textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm,
                                                                         width: width,
                                                                         height: height,
                                                                         mipmapped: false)
        
        textureDescriptor.usage = [.shaderRead, .shaderWrite]
        
        prevFrameTexture = metalDevice.makeTexture(descriptor: textureDescriptor)

        newFrameTexture = metalDevice.makeTexture(descriptor: textureDescriptor)

        
        guard let computeFunction = library?.makeFunction(name: "calculateAgent") else {
            fatalError("Unable to find function 'calculateAgent' in the Metal library")
        }
        
        do {
            try computePipelineState = metalDevice.makeComputePipelineState(function: computeFunction)
        } catch {
            fatalError()
        }
        
        //blur stuff
        guard let blurComputeFunction = library?.makeFunction(name: "blurReduceBright") else {
            fatalError("Unable to find function 'blurReduceBright' in the Metal library")
        }
        
        do {
            try blurPipelineState = metalDevice.makeComputePipelineState(function: blurComputeFunction)
        } catch {
            fatalError()
        }
        
        
        super.init()
        
        
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        
    }
    

    
    
    func draw(in view: MTKView) {
        
        

        
        
        
        
        

        guard let drawable = view.currentDrawable else {
            return
        }
        
        
        

        if (self.options.paused == 0) {
            
            frameTexture = metalDevice.makeTexture(descriptor: textureDescriptor)
            //compute command stuff here
            let commandBufferCompute = metalCommandQueue.makeCommandBuffer()
            
            let commandEncoder = commandBufferCompute?.makeComputeCommandEncoder()
            
            commandEncoder?.setComputePipelineState(computePipelineState)
            
            commandEncoder?.setBuffer(agentsBuffer, offset: 0, index: 0)
            
            let speciesBuffer = metalDevice.makeBuffer(bytes: species, length: species.count * MemoryLayout<simd_float3>.stride, options: [])!
            
            let agentDataBuffer = metalDevice.makeBuffer(bytes: &self.agentData, length: MemoryLayout<AgentData>.stride, options: [])!
            commandEncoder?.setBuffer(agentDataBuffer, offset: 0, index: 1)
            commandEncoder?.setBuffer(speciesBuffer, offset: 0, index: 2)
            
            
            commandEncoder?.setBytes(&options.shaderOptions, length: MemoryLayout<ShaderOptions>.stride, index: 3)

            let threadsPerGrid = MTLSize(width: agents.count, height: 1, depth: 1)
            let maxThreadsPerThreadgroup = computePipelineState.maxTotalThreadsPerThreadgroup
            
            let threadsPerThreadgroup = MTLSize(width: maxThreadsPerThreadgroup, height: 1, depth: 1)
            
            //texture to read from
            commandEncoder?.setTexture(prevFrameTexture, index: 0)
            
            //texture to write to
            commandEncoder?.setTexture(frameTexture, index: 1)
            
            
            commandEncoder?.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
            commandEncoder?.endEncoding()
            commandBufferCompute?.commit()
            commandBufferCompute?.waitUntilCompleted()
            
            
            //reduce brightness and blur
            //newFrameTexture is for blurred and reduced brightness
            let commandBufferBlur = metalCommandQueue.makeCommandBuffer()
            
            let commandEncoderBlur = commandBufferBlur?.makeComputeCommandEncoder()
            
            commandEncoderBlur?.setComputePipelineState(blurPipelineState)
            
            let threadsPerGridBlur = MTLSize(width: width, height: height, depth: 1)
            
            let maxThreadsPerThreadgroupBlur = blurPipelineState.maxTotalThreadsPerThreadgroup
            let threadsPerThreadgroupBlur = MTLSize(width: maxThreadsPerThreadgroupBlur, height: 1, depth: 1)
            
            
            commandEncoderBlur?.setBytes(&options.shaderOptions, length: MemoryLayout<ShaderOptions>.stride, index: 0)
            
            commandEncoderBlur?.setTexture(prevFrameTexture, index: 0)
            commandEncoderBlur?.setTexture(frameTexture, index: 1)
            commandEncoderBlur?.setTexture(newFrameTexture, index: 2)
            
            
            commandEncoderBlur?.dispatchThreads(threadsPerGridBlur, threadsPerThreadgroup: threadsPerThreadgroupBlur)
            commandEncoderBlur?.endEncoding()
            commandBufferBlur?.commit()
            commandBufferBlur?.waitUntilCompleted()
            
        }
        //render shader stuff here
        let commandBuffer = metalCommandQueue.makeCommandBuffer()
        
        let renderPassDescriptor = view.currentRenderPassDescriptor
        
        renderPassDescriptor?.colorAttachments[0].clearColor = MTLClearColor(red:0, green:0.5, blue:0.5, alpha:1.0)
        renderPassDescriptor?.colorAttachments[0].loadAction = .clear
        renderPassDescriptor?.colorAttachments[0].storeAction = .store
        
        let renderEncoder = commandBuffer?.makeRenderCommandEncoder(descriptor: renderPassDescriptor!)

        renderEncoder?.setRenderPipelineState(pipelineState)
        renderEncoder?.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        
        
        if (options.drawTrails == 0) {
            renderEncoder?.setFragmentTexture(frameTexture, index: 0)
        } else {
            
            renderEncoder?.setFragmentTexture(newFrameTexture, index: 0)
            
        }
        renderEncoder?.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        
        renderEncoder?.endEncoding()
        commandBuffer?.present(drawable)
        commandBuffer?.commit()
        
        prevFrameTexture = newFrameTexture
    }
    
}
