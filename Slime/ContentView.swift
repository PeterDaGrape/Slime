//
//  ContentView.swift
//  Slime
//
//  Created by Peter Vine on 13/06/2024.
//

import SwiftUI
import MetalKit



func getScale () -> CGFloat {
    
    let screenObject = NSScreen.main
    
    guard let scale = screenObject?.backingScaleFactor else {
        
        return 1
        
    }
    return scale
    
}





struct ContentView: View {
    
    @State var w:CGFloat = 0
    @State var h:CGFloat = 0
    
    
    let scaleFactor: CGFloat = getScale()
    
    @State var sensorDistance: Float = 40
    @State var sensorAngle: Float = .pi / 6
    @State var maxTurn: Float = .pi / 12
    @State var velocity: Float = 1

    
    @State var startSimulation = false
    
    @State var showColours = false
    @State var showOptions = false

    
    //if adding more CHANGE VALUE IN BRIDGING HEADER
    @State var species: Array<SIMD3<Float>> = [[0, 0, 1],
                                               [0, 1, 0],
                                               [1, 0, 0]]
    
    
    @State var options: Options = Options(numberAgents: 1_000_000, drawTrails: 1, paused: 0, shaderOptions: ShaderOptions(reduceAmount: 0.01, diffusionAmount: 0.2, drawStrength: 0.1, maxBlurDistance: 1))
    
    var body: some View {

        HStack {
            
            VStack {
                
                Slider(value: $sensorDistance, in: 1...500)
                Text("View distance \(sensorDistance)")
                
                Slider(value: $sensorAngle, in: 0...(.pi))
                Text("Field of view \((sensorAngle * 2) * 180 / .pi)")
                
                Button(action: {
                    showColours.toggle()
                }) {
                    Text("Select colours")
                }
                                        
                Button(action: {
                    if (options.paused == 0) {
                        options.paused = 1
                    } else {
                        options.paused = 0
                    }
                }) {
                    if (options.paused == 0) {
                        Text("Pause")
                    } else {
                        Text("Play")
                    }
                }
                
                Button(action: {
                    if (options.drawTrails == 0) {
                        options.drawTrails = 1
                    } else {
                        options.drawTrails = 0
                    }
                }) {
                    Text("Toggle trails")
                }
                Text("Amount pixels are reduced per frame")
                Slider(value: $options.shaderOptions.reduceAmount, in: 0...1)
                Text("Diffusion amount")
                Slider(value: $options.shaderOptions.diffusionAmount, in: 0...1)
                Text("Pixel Draw Strength")
                Slider(value:  $options.shaderOptions.drawStrength, in: 0...1)
                Text("Agent Speed \(velocity)")
                Slider(value: $velocity, in: 0...5)

                TextField("Number of Agents", value:$options.numberAgents, format: .number)
                TextField("Kernel distance", value:$options.shaderOptions.maxBlurDistance, format: .number)
                          
                .popover(isPresented: $showColours, content: ({
                    
                    Form {
                        ForEach(0..<(species.count)) { index in
                            
                            VStack {
                                Text("Species \(index + 1)")
                                HStack {
                                    Text("R: ")
                                    Slider(value: $species[index][0], in: 0...1)
                                }
                                HStack {
                                    Text("G: ")
                                    Slider(value: $species[index][1], in: 0...1)
                                }
                                HStack {
                                    Text("B: ")
                                    Slider(value: $species[index][2], in: 0...1)
                                }
                                
                                
                            }.frame(minWidth: 200)
                        }
                    }
                    
                }))
                
            }
            .frame(maxWidth: 200)
            
            if startSimulation {
                
                GeometryReader {geo in
                    
                    
                    let agentData: AgentData = AgentData(numberSpecies: Int32(species.count), maxTurn: maxTurn, sensorAngle: sensorAngle, sensorDistance: sensorDistance, width: Int32(geo.size.width * scaleFactor), height: Int32(geo.size.height * scaleFactor), velocity: velocity)

                    MetalView(agentData: agentData, options: options, species: species)
                        .onAppear {
                            w = geo.size.width
                            h = geo.size.height
                        }
                        .frame(width: geo.size.width, height: geo.size.height) // Make it 80% of the horizontal space
                }
            } else {
                
                
                Button(action: {startSimulation = true}) {
                    Text("Start Simulation")
                        .disabled(!startSimulation)
                }
            }
            
            
        }
    }
}

struct MetalView: NSViewRepresentable {
    
    let agentData: AgentData
    let options: Options
    let species: [simd_float3]

    
    func makeCoordinator() -> Renderer {
        Renderer(self, agentData: agentData, options: options, species: species)
    }
    
    func makeNSView(context: Context) -> MTKView {
        let mtkView = MTKView()
        mtkView.delegate = context.coordinator
        mtkView.preferredFramesPerSecond = 120

        mtkView.enableSetNeedsDisplay = false
        
        if let metalDevice = MTLCreateSystemDefaultDevice() {
            mtkView.device = metalDevice
        }
        
        mtkView.framebufferOnly = false
        mtkView.drawableSize = mtkView.frame.size


      
        return mtkView
    }
    
    func updateNSView(_ nsView: MTKView, context: Context) {
        
        context.coordinator.agentData = agentData
        context.coordinator.options = options
        context.coordinator.species = species
    }
}


