//
//  GlobeConfiguration.swift
//  Globes
//
//  Created by Bernhard Jenny on 14/3/2024.
//

import SwiftUI

/// Configuration information for globe entities.
struct GlobeConfiguration: Equatable, Identifiable, Codable  {
    
    var id: UUID { globeId }
    
    let globeId: Globe.ID
    
    let globe: Globe
    
    /// True while the globe is loading.
    var isLoading = false
    
    /// True if the globe is visible.
    var isVisible = false
    
    /// If true, a view is attached to the globe
    var showAttachment = false
    
    // MARK: - Size
    
    /// Maximum diameter of globe when scaled up in meter
    static let maxDiameter: Float = 5
    
    /// Minimum diameter of globe when scaled down in meter
    static let minDiameter: Float = 0.05
        
    // MARK: - Position
    
    /// Position the globe relative to the camera location such that the closest point on the globe is at distanceToGlobe.
    /// The direction between the camera and the globe is 30 degrees below the horizon.
    /// - Parameter distanceToGlobe: Distance to globe
    func positionRelativeToCamera(distanceToGlobe: Float) -> SIMD3<Float> {
        guard let cameraViewDirection = CameraTracker.shared.viewDirection,
              let cameraPosition = CameraTracker.shared.position else {
            return SIMD3(0, 1, 0)
        }
        
        // oblique distance between camera and globe center
        let d = (globe.radius + distanceToGlobe)
        
        // position relative to camera position
        var position = cameraViewDirection * d + cameraPosition

        // vertically shift the globe down
        // the center of the globe is at this angle below the horizon
        let alpha: Float = 30 / 180 * .pi
        position.y -= sin(alpha) * d
        
        return position
    }
    
    func positionRelativeToPlane(distanceToGlobe: Float, model: ViewModel) -> SIMD3<Float> {
        // Get the plane's position and its normal vector from the planeEntity
        let planeEntity = model.planeEntity  // Correct reference to the planeEntity
        let planePosition = planeEntity.position
        
        // Oblique distance between the plane and the globe center
        let d = model.globe.radius + distanceToGlobe
        
        // Set the initial position based on the plane's position
        var position = planePosition

        // Adjust the position along the plane's normal direction (Z-axis) by the distance to the globe
        position.z -= d  // Move the globe away from the plane along the Z-axis

        // Optionally apply any vertical or custom adjustments (e.g., tilt)
        let alpha: Float = 30 / 180 * .pi
        position.y -= sin(alpha) * d
        
        // Move the globe 1 meter up
        position.y += 1.0  // Adding 1 meter to the Y coordinate

        return position
    }


    
    // MARK: - Scale
            
    /// Minimum scale factor
    var minScale: Float {
        let d = 2 * globe.radius
        return Self.minDiameter / d
    }
    
    /// Maximum scale factor
    var maxScale: Float {
        let d = 2 * globe.radius
        return max(1, Self.maxDiameter / d)
    }
    
    // MARK: - Rotation
    
    /// Speed of rotation used
    var rotationSpeed: Float
    
    /// Duration in seconds for full rotation of a spinning globe with a radius of 1 meter.
    static private let rotationDuration: Float = 120
    
    /// Angular speed in radians per second for a spinning globe with a radius of 1 meter.
    /// Globes with a smaller radius rotate faster, and globes with a larger radius rotate slower.
    /// Globes with a scale factor greater than 1 rotate slower, and globes with a scale factor smaller than 1 rotate faster.
    static let defaultRotationSpeed: Float = 2 * .pi / rotationDuration
    
    /// Angular speed in radians per second for a small preview globe.
    static let defaultRotationSpeedForPreviewGlobes: Float = 2 * .pi / 24
    
    /// Pause rotation by RotationSystem
    var isRotationPaused: Bool
    
    /// Current speed of rotation taking isRotationPaused flag into account.
    var currentRotationSpeed: Float {
        isRotationPaused ? 0 : rotationSpeed
    }
    
    
    // MARK: - Initializer
    
    init(
        globe: Globe,
        speed: Float = 0,
        isRotationPaused: Bool = false
    ) {
        self.globeId = globe.id
        self.globe = globe
        self.rotationSpeed = speed
        self.isRotationPaused = isRotationPaused
    }
    
    // MARK: Codable
   
    enum CodingKeys: String, CodingKey {
            case globeId
            case isLoading
            case showAttachment
            case selection
            case globe
            case rotationSpeed
            case isRotationPaused
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(globeId, forKey: .globeId)
            try container.encode(isLoading, forKey: .isLoading)
            try container.encode(showAttachment, forKey: .showAttachment)
            try container.encode(globe, forKey: .globe)
            try container.encode(rotationSpeed, forKey: .rotationSpeed)
            try container.encode(isRotationPaused, forKey: .isRotationPaused)
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            globeId = try container.decode(Globe.ID.self, forKey: .globeId)
            isLoading = try container.decode(Bool.self, forKey: .isLoading)
            showAttachment = try container.decode(Bool.self, forKey: .showAttachment)
            globe = try container.decode(Globe.self, forKey: .globe)
            rotationSpeed = try container.decode(Float.self, forKey: .rotationSpeed)
            isRotationPaused = try container.decode(Bool.self, forKey: .isRotationPaused)
        }
}
