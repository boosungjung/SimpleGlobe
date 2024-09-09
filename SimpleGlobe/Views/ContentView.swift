//
//  ContentView.swift
//  SimpleGlobe
//
//  Created by Bernhard Jenny on 14/8/2024.
//

import SwiftUI
import RealityKit
import RealityKitContent

struct ContentView: View {
    
    @Environment(ViewModel.self) var model
    
    var planeEntity: Entity {
        // create an anchor entity of minimum bound size of 60 cm by 60cm
        let floorAnchor = AnchorEntity(.plane(.vertical,
                                              classification: .wall,
                                              minimumBounds: SIMD2<Float>(0.6, 0.6)))

//        let floorAnchor = AnchorEntity(.image(group: "AR Resources",
//                                                  name: "image.png"))
        
        let planeMesh = MeshResource.generatePlane(width: 1, depth:1, cornerRadius: 0.1)
        let material = SimpleMaterial(color: .green, isMetallic: false)
        let planeEntity = ModelEntity(mesh: planeMesh, materials: [material])
        planeEntity.name = "canvas"
        floorAnchor.addChild(planeEntity)
        
        return floorAnchor
    }
    
    

    var body: some View {
        VStack {
            GlobeButton(globe: model.globe)
                .padding()
            SharePlayView()
        }
        .padding(50)
        
    }
}

#Preview(windowStyle: .automatic) {
    ContentView()
        .environment(ViewModel.preview)
}
