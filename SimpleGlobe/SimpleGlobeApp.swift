//
//  SimpleGlobeApp.swift
//  SimpleGlobe
//
//  Created by Bernhard Jenny on 14/8/2024.
//

import os
import SwiftUI

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        
        // register custom components and systems
        RotationComponent.registerComponent()
        RotationSystem.registerSystem()
        GlobeBillboardComponent.registerComponent()
        GlobeBillboardSystem.registerSystem()
        
        // start camera tracking
        CameraTracker.start()
        
        return true
    }
}

@main
struct SimpleGlobeApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.openURL) private var openURL
    
    /// View model injected in environment.
    @State private var model = ViewModel.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(model)
        }
        .windowResizability(.contentSize) // window resizability is derived from window content

        WindowGroup(id: "info", for: UUID.self) { $globeId in
            if let infoURL = model.globe.infoURL {
                WebViewDecorated(url: infoURL)
                    .ornament(attachmentAnchor: .scene(.bottom)) {
                        Button("Open in Safari") { openURL(infoURL) }
                        .padding()
                        .glassBackgroundEffect()
                    }
                    .frame(minWidth: 500)
            }
        }
        .windowResizability(.contentSize) // window resizability is derived from window content
        
        ImmersiveSpace(id: "ImmersiveGlobeSpace") {
            ImmersiveView()
                .environment(model)
        }
    }
}
