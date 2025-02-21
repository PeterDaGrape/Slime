//
//  ContentView.swift
//  Slime
//
//  Created by Peter Vine on 13/06/2024.
//

import SwiftUI
import MetalKit


func getScale () -> CGFloat {
    
    let screenObject = UIScreen.main
    
    return screenObject.scale
    
}
struct ContentView: View {
    
    @State var sensorDistance: Float = 60
    @State var sensorAngle: Float = .pi / 6
    @State var maxTurn: Float = .pi / 12
    let scaleFactor:CGFloat = 3
    @State var w: Float = 1000
    @State var h: Float = 1000
    
    @State var paused = 0
    
    @State var showColours = false
    
    //if adding more CHANGE VALUE IN BRIDGING HEADER
    @State var species: Array<SIMD3<Float>> = [[0, 0, 1],
                                               [0, 1, 0],
                                               [1, 0, 0]]
    
    var body: some View {
        

        VStack {
            
            GeometryReader {geo in
                
            
                
                let agentData: AgentData = AgentData(numberSpecies: 3, maxTurn: maxTurn, sensorAngle: sensorAngle, sensorDistance: sensorDistance, width: Int32(geo.size.width * scaleFactor), height: Int32(geo.size.height * scaleFactor), paused: Int32(paused))

                MetalView(agentData: agentData, species: species)
                    .onAppear {
                        
                        w = Float(geo.size.width)
                        h = Float(geo.size.height)
                    }
                
            }

            
            HStack {
                VStack {
                    Slider(value: $sensorAngle, in: 0...(.pi / 2))
                    Text("Field of view \((sensorAngle * 2) * 180 / .pi)")
                }
                
            
                
                VStack {
                    Button(action: {
                        showColours.toggle()
                    }) {
                        Text("Select colours")
                    }
                    
                    Button(action: {
                        if (paused == 0) {
                            paused = 1
                        } else {
                            paused = 0
                        }
                    }) {
                        if (paused == 0) {
                            Text("Pause")
                        } else {
                            Text("Play")
                        }
                    }
                    
                }
                
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
                
                VStack {
                    Slider(value: $sensorDistance, in: 1...500)
                    Text("View distance \(sensorDistance)")
                    
                    
                }
            }
        }
            
    }
}



struct MetalView: UIViewRepresentable {
    

    let agentData: AgentData
    let species: [simd_float3]

    func makeCoordinator() -> Renderer {
        Renderer(self, agentData: agentData, species: species)
    }
    
    func makeUIView(context: Context) -> MTKView {
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
    
    func updateUIView(_ uiView: MTKView, context: Context) {
        context.coordinator.agentData = agentData
        context.coordinator.species = species

    }
}


#Preview {
    ContentView()
}
