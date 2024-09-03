//
//  GlobeButton.swift
//  Globes
//
//  Created by Bernhard Jenny on 5/5/2024.
//

import SwiftUI

struct GlobeButton: View {
    @Environment(ViewModel.self) private var model
    @Environment(\.openImmersiveSpace) var openImmersiveSpaceAction
    
    let globe: Globe
    
    @MainActor
    private var globeBinding: Binding<Bool> { Binding (
        get: { model.configuration.isVisible || model.configuration.isLoading },
        set: { showOrHideGlobe($0) }
    )}
    
    var body: some View {
        VStack {
            Toggle(isOn: globeBinding, label: {
                Label("Show Globe", systemImage: "globe")
            })
            .fixedSize(horizontal: true, vertical: false)
            
            ProgressView()
                .opacity(model.configuration.isLoading ? 1 : 0)
                .padding()
        }
    }
    
    @MainActor
    private func showOrHideGlobe(_ show: Bool) {
        Task { @MainActor in
            if model.configuration.isVisible {
                model.hideGlobe()
            } else {
                model.load(globe: globe, openImmersiveSpaceAction: openImmersiveSpaceAction)
            }
        }
    }
}

#Preview(windowStyle: .automatic) {
    GlobeButton(globe: Globe.preview)
        .environment(ViewModel.preview)
}
