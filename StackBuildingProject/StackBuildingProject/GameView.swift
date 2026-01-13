import SwiftUI
import RealityKit

struct GameView: View {
    var body: some View {
        RealityView { content in
            // Cerca un tavolo o pavimento orizzontale
            let anchor = AnchorEntity(.plane(.horizontal, classification: .any, minimumBounds: [0.2, 0.2]))
            
            // Materiale e Mesh per il cubo
            let material = SimpleMaterial(color: .gray, isMetallic: false)
            let mesh = MeshResource.generateBox(width: 0.3, height: 0.05, depth: 0.3)
            
            let baseBlock = ModelEntity(mesh: mesh, materials: [material])
            
            // Posiziona il cubo
            baseBlock.position = [0, 0.025, 0]
            baseBlock.name = "BaseBlock"
            
            anchor.addChild(baseBlock)
            content.add(anchor)
            
        } placeholder: {
            ProgressView()
        }
    }
}
