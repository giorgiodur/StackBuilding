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
        
        // --- FIX DIMENSIONI STEP 5 ---
        // Base 0.4, Altezza 0.05, Profondità 0.4
        let mesh = MeshResource.generateBox(size: [0.4, 0.05, 0.4])
        let mat = SimpleMaterial(color: .green.withAlphaComponent(0.6), isMetallic: false)
        let visualCursor = ModelEntity(mesh: mesh, materials: [mat])
        
        // Alziamo di metà altezza (0.025) così poggia perfettamente sul piano
        visualCursor.position.y = 0.025
        
        // --- FIX TAP ---
        // Rendiamo il cursore un bersaglio valido per il Tap
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
            
            // Raycast contro i tavoli
            let results = rootEntity.scene?.raycast(origin: origin, direction: direction, length: 3.0, query: .nearest, mask: PlaneAnchor.horizontalCollisionGroup)
            
            if let hit = results?.first {
                placementCursor.isEnabled = true
                placementCursor.position = hit.position
                // Blocchiamo la rotazione per tenerlo allineato al mondo (più facile da giocare)
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
            // Nascondiamo i piani di debug per pulizia
            // (Opzionale: se vuoi vedere ancora il tavolo, rimuovi questa riga)
            // rootEntity.isEnabled = false
        }
    }
}
