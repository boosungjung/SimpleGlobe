//
//  ImmersiveView.swift
//  SimpleGlobe
//
//  Created by Bernhard Jenny on 14/8/2024.
//

import SwiftUI
import RealityKit
import RealityKitContent
import Combine

struct ImmersiveView: View {
    @Environment(ViewModel.self) private var model
    @State private var subscriptions = [EventSubscription]()
    var body: some View {
        RealityView { content, attachments in // async on MainActor
            // Important: Any @State properties initialized in this closure are not available
            // on the first call of the update closure (optionals will still be nil).
            // Therefore do not defer initialization of entities to the update closure.
            
            let root = Entity()
            root.name = "Globes"
            content.add(root)
            content.add(model.planeEntity)
           
            
            // subscribe to any anchor changes and update the anchor state
            let anchoredSubscription = content.subscribe(to: SceneEvents.AnchoredStateChanged.self) { event in
                if let anchoredEntity = event.anchor as? AnchorEntity {
                    if event.isAnchored {
                        model.isAnchorPlaced = true
                    } else {
                        model.isAnchorPlaced = false
                    }
                }
            }
            
            // Store the subscription
            subscriptions.append(anchoredSubscription)
            
            
            // initialize the globes
            updateGlobeEntity(to: content, attachments: attachments)
            
            _ = content.subscribe(to: SceneEvents.DidAddEntity.self, handleDidAddEntity(_:))
        } update: { content, attachments in // synchronous on MainActor
            updateGlobeEntity(to: content, attachments: attachments)
        } attachments: { // synchronous on MainActor
            Attachment(id: model.globe.id) {
                GlobeAttachmentView(globe: model.globe)
            }
        }
        .globeGestures(model: model)
    }
    
    @MainActor
    /// Subscribe to entity-add events to setup entities.
    ///
    /// Starting the animation and setting up IBL are only possible after the immersive space has been created and all required entities have been added.
    /// - Parameter event: The event.
    private func handleDidAddEntity(_ event: SceneEvents.DidAddEntity) {
        if let globeEntity = event.entity as? GlobeEntity {
            animateMoveIn(of: globeEntity)
        }
    }
    
    @MainActor
    /// Move-in animation that changes the position and the scale of a globe.
    /// - Parameter entity: The globe entity.
    private func animateMoveIn(of entity: Entity) {
        if let globeEntity = entity as? GlobeEntity {
            let targetPosition = model.configuration.positionRelativeToCamera(distanceToGlobe: 0.5)
            globeEntity.animateTransform(scale: 1, position: targetPosition)
        }
    }
    
    @MainActor
    /// Add a new globe entity or remove an globe entity, and update the attachment view.
    /// - Parameters:
    ///   - content: Root of scene content.
    ///   - attachments: The attachments views.
    private func updateGlobeEntity(
        to content: RealityViewContent,
        attachments: RealityViewAttachments
    ) {
        guard let root = content.entities.first?.findEntity(named: "Globes") else { return }
        let addedGlobeEntity = root.children.first(where: { ($0 is GlobeEntity) })
        
        if let addedGlobeEntity, model.globeEntity == nil{
            root.removeChild(addedGlobeEntity)
        } else {
            if let globeEntity = model.globeEntity {
                root.addChild(globeEntity)
            }
        }
        
        
        
        // update attachments
        addAttachments(attachments)
        
        // update globe rotation
        model.globeEntity?.updateRotation(configuration: model.configuration)
    }
    
    @MainActor
    private func addAttachments(_ attachments: RealityViewAttachments) {
        guard let globeEntity = model.globeEntity else { return }
        if model.configuration.showAttachment,
           let attachmentEntity = attachments.entity(for: model.globe.id) {
            attachmentEntity.position = [0, 0, model.globe.radius + 0.01]
            attachmentEntity.components.set(GlobeBillboardComponent(radius: model.globe.radius))
            globeEntity.addChild(attachmentEntity)
        } else {
            for viewAttachmentEntity in globeEntity.children where viewAttachmentEntity is ViewAttachmentEntity {
                globeEntity.removeChild(viewAttachmentEntity)
            }
        }
    }
}

#Preview(immersionStyle: .mixed) {
    ImmersiveView()
        .environment(ViewModel.preview)
}
