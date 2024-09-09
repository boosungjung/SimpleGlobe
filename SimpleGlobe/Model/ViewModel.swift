//
//  ViewModel.swift
//  Globes
//
//  Created by Bernhard Jenny on 15/3/2024.
//

import os
import RealityKit
import SwiftUI
import Combine
import SharePlayMock
import GroupActivities
import ARKit

/// A singleton model that can be accessed via ViewModel.shared, for example, by the app delegate. For SwiftUI, use the new Observable framework instead of accessing the shared singleton.
///
/// The Globe struct is a static description of a globe containing all metadata and a texture name.
///
/// A Configuration stores dynamic properties of a globe, such as the rotation, the loading status, whether an attachment is visible, etc.
///
/// After a globe is loaded, a GlobeEntity is initialized. SwiftUI observes this object and synchronises the content of the ImmersiveView (a RealityView).
///
///
/// For the new Observable framework: https://developer.apple.com/documentation/swiftui/migrating-from-the-observable-object-protocol-to-the-observable-macro
@Observable class ViewModel: CustomDebugStringConvertible, ObservableObject {
    
    /// Shared singleton that can be accessed by the AppDelegate.
    @MainActor
    static let shared = ViewModel()
    
    /// Stores the immersive space so we can pass it to sharePlay's receive message function
    @MainActor
    var openImmersiveSpaceAction: OpenImmersiveSpaceAction?
    
    @MainActor
    let globe = Globe(
        name: "Bellerby World Globe",
        shortName: "World Globe",
        nameTranslated: nil,
        authorSurname: "Peter",
        authorFirstName: "Bellerby",
        date: "2023",
        description: "Peter Bellerby makes modern globes with old world craftsmanship. Many consider him the finest living globe maker.",
        infoURL: URL(string: "https://www.davidrumsey.com/luna/servlet/s/cd8p41"),
        radius: 0.325,
        texture: "Bellerby65cmSchminkeGagarin"
    )
    
    // MARK: - Visible Globes
    
    @MainActor
    /// A Configuration stores dynamic properties of a globe, such as the rotation, the loading status, whether an attachment is visible, etc.
    var configuration: GlobeConfiguration
   
    @MainActor
    /// After a globe is loaded, a GlobeEntity is initialized. SwiftUI observes this object and synchronises the content of the ImmersiveView (a RealityView).
    var globeEntity: GlobeEntity?
    
    @MainActor
    
    /// Boolean that indicates if globe is being dragged
    var isDragging = false
    
    
    // MARK: SharePlay Variables
    
    /// The message that we want to send to the group session
    var activityState = ActivityState()
    
  
    /// Boolean that indicates if share play is enabled
    var sharePlayEnabled = false
    
#if DEBUG

    var groupSession: GroupSessionMock<MyGroupActivity>?

    var messenger: GroupSessionMessengerMock?
#else

    var groupSession: GroupSession<MyGroupActivity>?
  
    var messenger: GroupSessionMessenger?
#endif
    
  
    /// Stores a set of subcriptions
    var subscriptions: Set<AnyCancellable> = []
    
    
    /// The tasks that are going to be performed. The tasks are set in ViewModel+SharePlay.swift
    var tasks: Set<Task<Void, Never>> = []
    
    @MainActor
    /// Cancellable variables, so we can delay the messages sent
    let subject = PassthroughSubject<ActivityState, Never>()
    
    @MainActor
    var cancellable: AnyCancellable?

    
    /// Interval in seconds for synchronizing the position of this entity with the camera position
    private let timerInterval: TimeInterval = 0.5
    
    @MainActor
    init() {
        self.configuration = GlobeConfiguration(
            globe: globe,
            speed: GlobeConfiguration.defaultRotationSpeed,
            isRotationPaused: true
        )
        Task { @MainActor in
            self.configureGroupSessions()
            Registration.registerGroupActivity()
        }
  
        // Timer to synchronize the position of this entity with the camera position
        _ = Timer.scheduledTimer(withTimeInterval: timerInterval, repeats: true) { timer in
  
            DispatchQueue.main.asyncAfter(deadline: .now()) {
                Task{ @MainActor in
                  
                    guard let globeEntity = self.globeEntity else { return }
                    if var activityStateChanges = self.activityState.changes[self.globe.id] {
                        activityStateChanges.scale = globeEntity.scale.x
                        activityStateChanges.orientation = globeEntity.orientation
                        activityStateChanges.position = globeEntity.position
                        activityStateChanges.duration = 0.2
                        self.activityState.changes[self.globe.id] = activityStateChanges
                    }
                    else{
                        // Initialize and add new activityState
                        self.activityState.changes[self.globe.id] = TempTransform(
                            scale: globeEntity.scale.x,
                            orientation: globeEntity.orientation,
                            position: globeEntity.position,
                            globeChange: GlobeChange.load
                        )
                        self.activityState.sharedGlobeConfiguration[self.globe.id] = self.configuration
                    }
                }
                self.sendMessage()
            }
        }
        
        cancellable = subject
            .debounce(for: .seconds(0.1), scheduler: RunLoop.main)
            .sink { activityState in
                Task {
                    try? await self.messenger?.send(activityState)
                }
            }
            
    }
    
    /// Boolean to check if anchor is placed in scene
    var isAnchorPlaced = false

//    /// https://gist.github.com/cth400/b3e9dff02d978b0ca9e18557fbc65bf1  image tracking
    var planeEntity: AnchorEntity {
        let floorAnchor = AnchorEntity(.plane(.horizontal,
                                              classification: .floor,
                                              minimumBounds: SIMD2<Float>(0.6, 0.6)))
        
        // https://developer.apple.com/documentation/realitykit/entity/synchronization
        floorAnchor.synchronization = SynchronizationComponent()
        
        
        //        let floorAnchor = AnchorEntity(.image(group: "AR Resources",
        //                                                  name: "image.png"))
        let planeMesh = MeshResource.generatePlane(width: 1, height: 1, cornerRadius: 0.1)
        let material = SimpleMaterial(color: .green, isMetallic: false)
        let planeEntity = ModelEntity(mesh: planeMesh, materials: [material])
        planeEntity.name = "canvas"
        floorAnchor.addChild(planeEntity)
        
        
        
        
        return floorAnchor
    }

  
    @MainActor
    /// Open an immersive space if there is none and show a globe. Once loaded, the globe fades in.
    /// - Parameters:
    ///   - globe: The globe to show.
    ///   - selection: When selection is not none, the texture is replaced periodically with a texture of one of the globes in the selection.
    ///   - openImmersiveSpaceAction: Action for opening an immersive space.
    func load(
        globe: Globe,
        openImmersiveSpaceAction: OpenImmersiveSpaceAction
    ) {
//        guard !hasConfiguration() else { return }
        
//        self.configuration = GlobeConfiguration(
//            globe: globe,
//            speed: GlobeConfiguration.defaultRotationSpeed,
//            isRotationPaused: true
//        )
        
        configuration.isLoading = true
        configuration.isVisible = false
        configuration.showAttachment = false
        
        Task {
            openImmersiveGlobeSpace(openImmersiveSpaceAction)
            let globeEntity = try await GlobeEntity(globe: globe)
            Task { @MainActor in
                ViewModel.shared.storeGlobeEntity(globeEntity)
            }
        }
    }
    
    @MainActor
    /// Called after a  globe entity has been loaded.
    /// - Parameter globeEntity: The globe entity to add.
    func storeGlobeEntity(_ globeEntity: GlobeEntity) {
      
        configuration.isLoading = false
        configuration.isVisible = true
        
        // Set the initial scale and position for a move-in animation.
        // The animation is started by a DidAddEntity event when the immersive space has been created and the globe has been added to the scene.
        globeEntity.scale = [0.01, 0.01, 0.01]
//        globeEntity.position = configuration.positionRelativeToCamera(distanceToGlobe: 2)
        globeEntity.position = configuration.positionRelativeToPlane(distanceToGlobe: 2, model: ViewModel.shared)
        // Rotate the central meridian to the camera, to avoid showing the empty hemisphere on the backside of some globes.
        // The central meridian is at [-1, 0, 0], because the texture u-coordinate with lon = -180° starts at the x-axis.
        if let viewDirection = CameraTracker.shared.viewDirection {
            var orientation = simd_quatf(from: [-1, 0, 0], to: -viewDirection)
            orientation = GlobeEntity.orientToNorth(orientation: globeEntity.orientation)
            globeEntity.orientation = orientation
        }
        
        // store the globe entity
        self.globeEntity = globeEntity
    }
    
    @MainActor
    /// A new globe entity could not be loaded.
    /// - Parameters:
    ///   - id: The id of the globe that could not be loaded.
    func loadingGlobeFailed(id: Globe.ID?) {
        errorToShowInAlert = error("There is not enough memory to show another globe.",
                                   secondaryMessage: "First hide a visible globe, then select this globe again.")
    }
    
    @MainActor
    /// Hide a globe. The globe shrinks down.
    /// - Parameter id: Globe ID
    func hideGlobe() {
        let duration = 0.666
        
        // shrink the globe
        globeEntity?.scaleAndAdjustDistanceToCamera(
                newScale: 0.001, // scaling to 0 spins the globe, so scale to a value slightly greater than 0
                radius: globe.radius,
                duration: duration
            )
//        guard var configuration = configuration else {
//            return
//        }
        configuration.isVisible = false
        configuration.showAttachment = false
        
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(duration))
//            assert(configuration.keys.contains(id), "No configuration for \(id)")
//            assert(globeEntities.keys.contains(id), "No globe entity for \(id)")
      
            
            // remove the globe from the shared model
//            activityState.sharedGlobeConfiguration[id] = nil
//            self.sendMessage()
        }
    }
    
    // MARK: - Immersive Space
    
    @MainActor
    var immersiveSpaceIsShown = false

    @MainActor
    func openImmersiveGlobeSpace(_ action: OpenImmersiveSpaceAction) {
        guard !immersiveSpaceIsShown else { return }
        Task {
            let result = await action(id: "ImmersiveGlobeSpace")
            switch result {
            case .opened:
                Task { @MainActor in
                    immersiveSpaceIsShown = true
                }
            case .error:
                Task { @MainActor in
                    errorToShowInAlert = error("A globe could not be shown.")
                }
                fallthrough
            case .userCancelled:
                fallthrough
            @unknown default:
                Task { @MainActor in
                    immersiveSpaceIsShown = false
                }
            }
        }
    }
    
    /// Error to show in an alert dialog.
    @MainActor
    var errorToShowInAlert: Error? = nil {
        didSet {
            if let errorToShowInAlert {
                let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "Globes Error")
                logger.error("Alert: \(errorToShowInAlert.localizedDescription) \(errorToShowInAlert.alertSecondaryMessage ?? "")")
            }
        }
    }
    
    // MARK: - Debug Description
    
    @MainActor
    var debugDescription: String {
        var description = "\(ViewModel.self)\n"
        
        // Memory
        let availableProcMemory = os_proc_available_memory()
        description += "Available memory: \(availableProcMemory / 1024 / 1024) MB\n"
        
        // Metal memory
        if let defaultDevice = MTLCreateSystemDefaultDevice () {
            let workingSet = defaultDevice.recommendedMaxWorkingSetSize
            if workingSet > 0 {
                let currentUse = defaultDevice.currentAllocatedSize
                description += "Allocated GPU memory: \(100 * UInt64(currentUse) / workingSet)%, \(currentUse / 1024 / 1024) MB of \(workingSet / 1024 / 1024) MB\n"
            }
        }
        
        description += "Immersive space is shown: \(immersiveSpaceIsShown)\n"
        
        // globes
        description += "Globe configuration: \(configuration.globe.name), rotating: \(!(configuration.isRotationPaused))\n"
        if let globeEntity {
            description += ", pos=\(globeEntity.position.x),\(globeEntity.position.y),\(globeEntity.position.z)"
            description += ", scale=\(globeEntity.scale.x),\(globeEntity.scale.y),\(globeEntity.scale.z)"
        }
        description += "\n"
        
        // error handling
        if let errorToShowInAlert {
            description += "Error to show: \(errorToShowInAlert.localizedDescription)\n"
        }
        
        return description
    }
}
