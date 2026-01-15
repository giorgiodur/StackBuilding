import SwiftUI
import RealityKit
import RealityKitContent
import Combine

struct GameView: View {
    // STATO DEL GIOCO
    @State private var rootEntity: Entity?
    @State private var currentBlock: Entity?
    @State private var lastBlockPosition: SIMD3<Float> = [0, 0, 0]
    @State private var towerHeight: Int = 0
    
    // VARIABILI MOVIMENTO
    @State private var direction: Float = 1.0
    @State private var speed: Float = 0.01
    @State private var isMoving: Bool = false
    
    // DIMENSIONI
    @State private var currentWidth: Float = 0.4
    let blockHeight: Float = 0.05
    let blockDepth: Float = 0.4
    
    // TIMER (60 FPS)
    let timer = Timer.publish(every: 0.016, on: .main, in: .common).autoconnect()

    var body: some View {
        RealityView { content in
            // ANCORA (Spostata per visibilità ottimale)
            let anchor = Entity()
            anchor.position = [0, -0.2, -0.8]
            
            // 1. BASE GRIGIA
            let baseMesh = MeshResource.generateBox(size: [currentWidth, blockHeight, blockDepth])
            let baseMaterial = SimpleMaterial(color: .gray, isMetallic: false)
            let baseBlock = ModelEntity(mesh: baseMesh, materials: [baseMaterial])
            baseBlock.position = [0, 0, 0]
            
            // RENDIAMO LA BASE SOLIDA E CLICCABILE
            baseBlock.generateCollisionShapes(recursive: false)
            baseBlock.components.set(InputTargetComponent())
            
            anchor.addChild(baseBlock)
            content.add(anchor)
            
            self.rootEntity = anchor
            self.lastBlockPosition = baseBlock.position
            
            // Avviamo il primo blocco
            spawnNewBlock()
        }
        // --- MODIFICA FONDAMENTALE: Usiamo un tap generico che funziona ovunque ---
        .onTapGesture {
            print("Click rilevato!") // Controllo per la console
            if isMoving {
                placeBlock()
            }
        }
        // ANIMAZIONE
        .onReceive(timer) { _ in
            guard isMoving, let block = currentBlock else { return }
            
            var currentPos = block.position
            currentPos.x += speed * direction
            
            // Limiti destra/sinistra
            if currentPos.x > 0.4 {
                direction = -1.0
            } else if currentPos.x < -0.4 {
                direction = 1.0
            }
            
            block.position = currentPos
        }
    }
    
    // Crea un nuovo blocco
    func spawnNewBlock() {
        guard let root = rootEntity else { return }
        
        towerHeight += 1
        let newY = Float(towerHeight) * blockHeight
        
        // Creiamo il blocco
        let mesh = MeshResource.generateBox(size: [currentWidth, blockHeight, blockDepth])
        let material = SimpleMaterial(color: randomColor(), isMetallic: false)
        let newBlock = ModelEntity(mesh: mesh, materials: [material])
        
        // Posizione di partenza (laterale)
        newBlock.position = [-0.35, newY, 0]
        
        // --- QUESTE SONO LE RIGHE CHE MANCAVANO PRIMA ---
        // Senza collisioni, il sistema non "sente" l'oggetto
        newBlock.generateCollisionShapes(recursive: false)
        newBlock.components.set(InputTargetComponent())
        // ------------------------------------------------
        
        root.addChild(newBlock)
        
        self.currentBlock = newBlock
        self.isMoving = true
    }
    
    // Ferma il blocco
    func placeBlock() {
        isMoving = false
        
        if let block = currentBlock {
            lastBlockPosition = block.position
            print("Blocco fermato a X: \(block.position.x)")
        }
        
        // Ne lancia subito un altro
        spawnNewBlock()
    }
    
    func randomColor() -> UIColor {
        return [UIColor.red, .blue, .green, .orange, .purple, .cyan, .magenta].randomElement()!
    }
}

#Preview {
    GameView()
}
