import SwiftUI
import RealityKit
import RealityKitContent
import Combine

struct GameView: View {
    @State private var currentBlock: Entity?
    @State private var direction: Float = 1.0
    @State private var speed: Float = 0.005
    
    // Timer per il movimento (60 fps)
    let timer = Timer.publish(every: 0.016, on: .main, in: .common).autoconnect()

    var body: some View {
        RealityView { content in
            // --- POSIZIONAMENTO ---
            // Creiamo un contenitore invisibile (Anchor) per spostare tutto il gioco insieme
            let anchor = Entity()
            
            // X = 0 (Centro orizzontale)
            // Y = -0.1 (Un po' più alto di prima, quasi al centro verticale)
            // Z = -0.8 (Molto più lontano, 80cm dentro lo schermo)
            anchor.position = [0, -0.1, -0.8]
            
            // --- 1. BASE GRIGIA ---
            let baseMesh = MeshResource.generateBox(size: [0.5, 0.05, 0.5])
            let baseMaterial = SimpleMaterial(color: .gray, isMetallic: false)
            let baseBlock = ModelEntity(mesh: baseMesh, materials: [baseMaterial])
            
            // La base sta a 0,0,0 rispetto all'ancora
            baseBlock.position = [0, 0, 0]
            
            anchor.addChild(baseBlock)
            
            // --- 2. PRIMO BLOCCO ROSSO ---
            let blockMesh = MeshResource.generateBox(size: [0.2, 0.05, 0.2])
            let blockMaterial = SimpleMaterial(color: .red, isMetallic: false)
            let movingBlock = ModelEntity(mesh: blockMesh, materials: [blockMaterial])
            
            // Lo mettiamo appena sopra la base
            movingBlock.position = [0, 0.05, 0]
            
            anchor.addChild(movingBlock)
            
            // Aggiungiamo tutto alla scena
            content.add(anchor)
            
            // Salviamo il riferimento per l'animazione
            DispatchQueue.main.async {
                self.currentBlock = movingBlock
            }
            
            print("Gioco posizionato lontano (Z = -0.8)")
        }
        .onReceive(timer) { _ in
            guard let block = currentBlock else { return }
            
            // Logica movimento destra/sinistra
            var currentPos = block.position
            currentPos.x += speed * direction
            
            // Limiti del movimento
            if currentPos.x > 0.25 {
                direction = -1.0
            } else if currentPos.x < -0.25 {
                direction = 1.0
            }
            
            block.position = currentPos
        }
    }
}

#Preview {
    GameView()
}
