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
        
        // Cursore Gigante (1.2m) - Step 9
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
        // Se siamo sul simulatore, non avviare ARKit (andrebbe in crash o darebbe errore)
        #if targetEnvironment(simulator)
        print("Siamo sul Simulatore: ARKit Session ignorata.")
        return
        #endif
        
        guard PlaneDetectionProvider.isSupported else { return }
        try? await session.run([worldTracking, planeDetection])
    }
    
    func updatePlanes() async {
        // Sul simulatore non ci sono piani da aggiornare
        #if targetEnvironment(simulator)
        return
        #endif
        
        for await update in planeDetection.anchorUpdates {
            await planeHandler?.process(update)
        }
    }
    
    func updateCursor() async {
        while true {
            // Se il gioco è già piazzato, nascondi il cursore e aspetta
            if isGamePlaced {
                placementCursor.isEnabled = false
                try? await Task.sleep(nanoseconds: 100_000_000)
                continue
            }
            
            // --- MODIFICA PER SIMULATORE XCODE ---
            #if targetEnvironment(simulator)
            // Se siamo nel simulatore, FORZIAMO il cursore ad apparire
            // Lo mettiamo fisso a: X=0 (Centro), Y=1.0 (Altezza occhi), Z=-3.0 (3 metri davanti)
            placementCursor.isEnabled = true
            placementCursor.position = [0, 1.0, -3.0]
            placementCursor.orientation = simd_quatf(angle: 0, axis: [0, 1, 0])
            
            // Rallentiamo il loop per non consumare CPU inutilmente
            try? await Task.sleep(nanoseconds: 16_000_000)
            continue // Saltiamo il resto della logica reale (Raycast)
            #endif
            // -------------------------------------
            
            // --- LOGICA REALE (DISPOSITIVO) ---
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
