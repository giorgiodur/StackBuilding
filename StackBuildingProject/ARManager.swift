import Foundation
import ARKit
import RealityKit
import SwiftUI

@MainActor
@Observable
class ARManager {
    private let session = ARKitSession()
    private let worldTracking = WorldTrackingProvider()
    private let planeDetection = PlaneDetectionProvider(alignments: [.horizontal])
    
    let rootEntity = Entity()
    let placementCursor = Entity()
    
    private var planeHandler: PlaneAnchorHandler?
    
    var isGamePlaced = false
    var gamePosition: SIMD3<Float> = [0, 0, 0]
    
    init() {
        self.planeHandler = PlaneAnchorHandler(rootEntity: rootEntity)
        rootEntity.addChild(placementCursor)
        
        // --- MODIFICA STEP 9: CURSORE GIGANTE (1.2m) ---
        // Adattato per corrispondere alla grandezza dei blocchi del gioco
        let mesh = MeshResource.generateBox(size: [1.2, 0.05, 1.2])
        let mat = SimpleMaterial(color: .green.withAlphaComponent(0.6), isMetallic: false)
        let visualCursor = ModelEntity(mesh: mesh, materials: [mat])
        
        visualCursor.position.y = 0.025
        
        // Input Target per il piazzamento
        visualCursor.generateCollisionShapes(recursive: false)
        visualCursor.components.set(InputTargetComponent())
        
        placementCursor.addChild(visualCursor)
        placementCursor.isEnabled = false
    }
    
    func startSession() async {
        guard PlaneDetectionProvider.isSupported else { return }
        try? await session.run([worldTracking, planeDetection])
    }
    
    func updatePlanes() async {
        for await update in planeDetection.anchorUpdates {
            await planeHandler?.process(update)
        }
    }
    
    func updateCursor() async {
        while true {
            if isGamePlaced {
                placementCursor.isEnabled = false
                try? await Task.sleep(nanoseconds: 100_000_000)
                continue
            }
            
            guard let deviceAnchor = worldTracking.queryDeviceAnchor(atTimestamp: CACurrentMediaTime()) else {
                try? await Task.sleep(nanoseconds: 16_000_000)
                continue
            }
            
            let transform = deviceAnchor.originFromAnchorTransform
            let origin = transform.columns.3.xyz
            let direction = -transform.columns.2.xyz
            
            let results = rootEntity.scene?.raycast(origin: origin, direction: direction, length: 3.0, query: .nearest, mask: PlaneAnchor.horizontalCollisionGroup)
            
            if let hit = results?.first {
                placementCursor.isEnabled = true
                placementCursor.position = hit.position
                placementCursor.orientation = simd_quatf(angle: 0, axis: [0, 1, 0])
            } else {
                placementCursor.isEnabled = false
            }
            
            try? await Task.sleep(nanoseconds: 16_000_000)
        }
    }
    
    func placeGame() {
        if placementCursor.isEnabled {
            gamePosition = placementCursor.position
            isGamePlaced = true
            placementCursor.isEnabled = false
        }
    }
}
