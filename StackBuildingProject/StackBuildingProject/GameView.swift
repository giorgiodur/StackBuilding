import SwiftUI
import RealityKit
import RealityKitContent
import Combine

struct GameView: View {
    // --- VARIABILI DI STATO ---
    @State private var rootEntity: Entity?
    @State private var currentBlock: Entity?
    @State private var lastBlockPosition: SIMD3<Float> = [0, 0, 0]
    @State private var towerHeight: Int = 0
    
    // --- VARIABILI MOVIMENTO ---
    @State private var direction: Float = 1.0
    @State private var speed: Float = 0.01
    @State private var isMoving: Bool = false
    
    // --- DIMENSIONI ---
    @State private var currentWidth: Float = 0.4
    let blockHeight: Float = 0.05
    let blockDepth: Float = 0.4
    
    // --- TIMER ---
    let timer = Timer.publish(every: 0.016, on: .main, in: .common).autoconnect()

    // --- CORPO DELLA VISTA (BODY) ---
    var body: some View {
        RealityView { content in
            // 1. ANCORA PRINCIPALE (Spostata per visibilità)
            let anchor = Entity()
            anchor.position = [0, -0.2, -0.8]
            
            // ---------------------------------------------------------
            // SCATOLA GIGANTE PER I CLICK ("Lastra di vetro")
            // ---------------------------------------------------------
            // Usiamo 10 metri e trasparenza 99% (alpha 0.01) così il sistema la "vede"
            let triggerMesh = MeshResource.generateBox(size: 10.0)
            let triggerMaterial = SimpleMaterial(color: .white.withAlphaComponent(0.01), isMetallic: false)
            let triggerEntity = ModelEntity(mesh: triggerMesh, materials: [triggerMaterial])
            
            // Fondamentale: deve avere le collisioni
            triggerEntity.generateCollisionShapes(recursive: false)
            triggerEntity.components.set(InputTargetComponent())
            
            // Aggiungiamo la scatola gigante all'ancora
            anchor.addChild(triggerEntity)
            
            // 2. BASE DEL GIOCO (Pavimento della torre)
            let baseMesh = MeshResource.generateBox(size: [currentWidth, blockHeight, blockDepth])
            let baseMaterial = SimpleMaterial(color: .gray, isMetallic: false)
            let baseBlock = ModelEntity(mesh: baseMesh, materials: [baseMaterial])
            baseBlock.position = [0, 0, 0]
            
            // Base solida
            baseBlock.generateCollisionShapes(recursive: false)
            baseBlock.components.set(InputTargetComponent())
            
            anchor.addChild(baseBlock)
            content.add(anchor)
            
            // Salviamo i riferimenti
            self.rootEntity = anchor
            self.lastBlockPosition = baseBlock.position
            
            // Avviamo il primo blocco
            spawnNewBlock()
        }
        // GESTURE: Click ovunque (grazie alla scatola gigante)
        .gesture(
            SpatialTapGesture()
                .onEnded { _ in
                    // Se il blocco si sta muovendo, lo fermiamo
                    if isMoving {
                        placeBlock()
                    }
                }
        )
        // ANIMAZIONE (60 volte al secondo)
        .onReceive(timer) { _ in
            guard isMoving, let block = currentBlock else { return }
            
            var currentPos = block.position
            currentPos.x += speed * direction
            
            // Rimbalzo destra/sinistra
            if currentPos.x > 0.4 {
                direction = -1.0
            } else if currentPos.x < -0.4 {
                direction = 1.0
            }
            
            block.position = currentPos
        }
    } // <--- QUESTA CHIUDE IL "BODY". LE FUNZIONI VANNO SOTTO QUI.
    
    // --- FUNZIONI DI GIOCO ---
    
    func spawnNewBlock() {
        guard let root = rootEntity else { return }
        
        towerHeight += 1
        let newY = Float(towerHeight) * blockHeight
        
        // Creiamo il nuovo blocco
        let mesh = MeshResource.generateBox(size: [currentWidth, blockHeight, blockDepth])
        let material = SimpleMaterial(color: randomColor(), isMetallic: false)
        let newBlock = ModelEntity(mesh: mesh, materials: [material])
        
        // Posizione di partenza (laterale)
        newBlock.position = [-0.35, newY, 0]
        
        // Collisioni necessarie anche per i blocchi
        newBlock.generateCollisionShapes(recursive: false)
        newBlock.components.set(InputTargetComponent())
        
        root.addChild(newBlock)
        
        // Aggiorniamo lo stato
        self.currentBlock = newBlock
        self.isMoving = true
    }
    
    func placeBlock() {
        isMoving = false
        
        if let block = currentBlock {
            lastBlockPosition = block.position
            print("Blocco fermato a X: \(block.position.x)")
        }
        
        // Ne facciamo partire subito un altro
        spawnNewBlock()
    }
    
    func randomColor() -> UIColor {
        return [UIColor.red, .blue, .green, .orange, .purple, .cyan, .magenta].randomElement()!
    }
    
} // <--- QUESTA CHIUDE LA STRUCT "GameView". FINE DEL FILE.

#Preview {
    GameView()
}
