import Foundation
import ARKit
import RealityKit

// --- PLANE ANCHOR HANDLER ---
// Gestisce la creazione fisica dei tavoli (Mesh + Collisioni)
class PlaneAnchorHandler {
    var rootEntity: Entity
    private var planeEntities: [UUID: Entity] = [:]
    
    init(rootEntity: Entity) {
        self.rootEntity = rootEntity
    }
    
    @MainActor
    func process(_ anchorUpdate: AnchorUpdate<PlaneAnchor>) async {
        let anchor = anchorUpdate.anchor
        
        if anchorUpdate.event == .removed {
            planeEntities[anchor.id]?.removeFromParent()
            planeEntities.removeValue(forKey: anchor.id)
            return
        }
        
        let entity = planeEntities[anchor.id] ?? Entity()
        if planeEntities[anchor.id] == nil {
            planeEntities[anchor.id] = entity
            rootEntity.addChild(entity)
            
            // 1. Genera la Mesh visiva (con materiale Occlusion per nascondere oggetti sotto il tavolo)
            if let meshResource = try? MeshResource.generate(from: MeshResource.Contents(planeGeometry: anchor.geometry)) {
                entity.components.set(ModelComponent(mesh: meshResource, materials: [OcclusionMaterial()]))
            }
            
            // 2. Genera la Collisione (Fondamentale per il Raycast!)
            if let shape = try? await ShapeResource.generateStaticMesh(positions: anchor.geometry.meshVertices.asSIMD3(ofType: Float.self),
                                                                       faceIndices: anchor.geometry.meshFaces.asUInt16Array()) {
                entity.components.set(CollisionComponent(shapes: [shape], isStatic: true,
                                                         filter: CollisionFilter(group: PlaneAnchor.horizontalCollisionGroup, mask: .all)))
                // Fisica statica
                entity.components.set(PhysicsBodyComponent(shapes: [shape], mass: 0.0, mode: .static))
            }
        }
        
        // Aggiorna posizione
        entity.setTransformMatrix(anchor.originFromAnchorTransform, relativeTo: nil)
    }
}

// --- ESTENSIONI UTILI ---

extension PlaneAnchor {
    @MainActor static let horizontalCollisionGroup = CollisionGroup(rawValue: 1 << 31)
}

extension GeometrySource {
    func asSIMD3<T>(ofType: T.Type) -> [SIMD3<T>] {
        return (0..<count).map {
            buffer.contents().advanced(by: offset + stride * Int($0)).assumingMemoryBound(to: (T, T, T).self).pointee
        }.map { .init($0.0, $0.1, $0.2) }
    }
}

extension GeometryElement {
    func asUInt16Array() -> [UInt16] {
        var data = [UInt16]()
        let total = count * primitive.indexCount
        data.reserveCapacity(total)
        for i in 0 ..< total {
            // FIX: Leggiamo il valore come Int32 e lo convertiamo esplicitamente in UInt16 prima di appenderlo
            let rawValue = buffer.contents().advanced(by: i * MemoryLayout<Int32>.size).assumingMemoryBound(to: Int32.self).pointee
            data.append(UInt16(rawValue))
        }
        return data
    }
}

extension MeshResource.Contents {
    init(planeGeometry: PlaneAnchor.Geometry) {
        self.init()
        self.instances = [MeshResource.Instance(id: "main", model: "model")]
        var part = MeshResource.Part(id: "part", materialIndex: 0)
        part.positions = MeshBuffers.Positions(planeGeometry.meshVertices.asSIMD3(ofType: Float.self))
        // Convertiamo UInt16 in UInt32 per RealityKit
        part.triangleIndices = MeshBuffer(planeGeometry.meshFaces.asUInt16Array().map { UInt32($0) })
        self.models = [MeshResource.Model(id: "model", parts: [part])]
    }
}

extension SIMD4 {
    var xyz: SIMD3<Scalar> { self[SIMD3(0, 1, 2)] }
}

extension simd_float4x4 {
    var gravityAligned: simd_float4x4 {
        let zAxis = columns.2.xyz
        let projectedZAxis: SIMD3<Float> = [zAxis.x, 0.0, zAxis.z]
        let normalizedZAxis = normalize(projectedZAxis)
        let yAxis: SIMD3<Float> = [0, 1, 0]
        let xAxis = normalize(cross(yAxis, normalizedZAxis))
        return simd_matrix(
            SIMD4(xAxis.x, xAxis.y, xAxis.z, 0),
            SIMD4(yAxis.x, yAxis.y, yAxis.z, 0),
            SIMD4(normalizedZAxis.x, normalizedZAxis.y, normalizedZAxis.z, 0),
            columns.3
        )
    }
}
