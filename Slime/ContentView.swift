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
    
    @State var startSimulation = false
    
    @State var showColours = false
    
    //if adding more CHANGE VALUE IN BRIDGING HEADER
    @State var species: Array<SIMD3<Float>> = [[0, 0, 1],
                                               [0, 1, 0],
                                               [1, 0, 0]]
    
    var body: some View {

        VStack {

            if startSimulation {
                
                GeometryReader {geo in
                    
                    let agentData: AgentData = AgentData(numberSpecies: Int32(species.count), maxTurn: maxTurn, sensorAngle: sensorAngle, sensorDistance: sensorDistance, width: Int32(geo.size.width * scaleFactor), height: Int32(geo.size.height * scaleFactor))

                    MetalView(agentData: agentData, species: species)
                        .onAppear {
                            w = geo.size.width
                            h = geo.size.height
                        }
                    //.frame(width: w, height: h)
                }
            } else {
                
                Spacer()
                Button(action: {startSimulation = true}) {
                    Text("Start Simulation")
                        .disabled(!startSimulation)
                }
            }
            
            HStack {
                VStack {
                    Slider(value: $sensorAngle, in: 0...(.pi / 2))
                    Text("Field of view \((sensorAngle * 2) * 180 / .pi)")
                }
                
                Button(action: {
                    showColours.toggle()
                }) {
                    Text("Select colours")
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

struct MetalView: NSViewRepresentable {
    
    let agentData: AgentData
    let species: [simd_float3]
    
    func makeCoordinator() -> Renderer {
        Renderer(self, agentData: agentData, species: species)
    }
    
    func makeNSView(context: Context) -> MTKView {
        let mtkView = MTKView()
        mtkView.delegate = context.coordinator
        mtkView.preferredFramesPerSecond = 60
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
        context.coordinator.species = species
    }
}


#Preview {
    ContentView()
}
