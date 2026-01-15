import SwiftUI
import RealityKit
import RealityKitContent
import Combine

struct GameView: View {
    // --- STATO DEL GIOCO ---
    @State private var rootEntity: Entity?
    @State private var currentBlock: Entity?
    @State private var lastBlockX: Float = 0.0
    @State private var towerHeight: Int = 0
    
    // --- MOVIMENTO ---
    @State private var direction: Float = 1.0
    @State private var speed: Float = 0.015
    @State private var isMoving: Bool = false
    
    // --- DIMENSIONI ---
    @State private var currentWidth: Float = 0.4
    let blockHeight: Float = 0.05
    let blockDepth: Float = 0.4
    
    // --- TESTO PUNTEGGIO ---
    @State private var scoreEntity: Entity?
    
    // --- TIMER ---
    let timer = Timer.publish(every: 0.016, on: .main, in: .common).autoconnect()

    var body: some View {
        RealityView { content in
            // 1. ANCORA PRINCIPALE
            let anchor = Entity()
            anchor.position = [0, -0.2, -0.8]
            
            // 2. SCATOLA GIGANTE INVISIBILE (CLICK ANYWHERE)
            let triggerMesh = MeshResource.generateBox(size: 10.0)
            let triggerMaterial = SimpleMaterial(color: .white.withAlphaComponent(0.01), isMetallic: false)
            let triggerEntity = ModelEntity(mesh: triggerMesh, materials: [triggerMaterial])
            triggerEntity.generateCollisionShapes(recursive: false)
            triggerEntity.components.set(InputTargetComponent())
            anchor.addChild(triggerEntity)
            
            // 3. TESTO PUNTEGGIO
            let textMesh = MeshResource.generateText("Score: 0", extrusionDepth: 0.01, font: .systemFont(ofSize: 0.1))
            let textMaterial = SimpleMaterial(color: .white, isMetallic: false)
            let textEntity = ModelEntity(mesh: textMesh, materials: [textMaterial])
            textEntity.position = [-0.2, 0.5, -0.5]
            anchor.addChild(textEntity)
            self.scoreEntity = textEntity
            
            // 4. BASE INIZIALE
            createBase(on: anchor)
            
            content.add(anchor)
            self.rootEntity = anchor
            
            // AVVIO GIOCO
            spawnNewBlock()
        }
        .gesture(
            SpatialTapGesture().onEnded { _ in
                if isMoving {
                    placeBlock()
                } else {
                    restartGame()
                }
            }
        )
        .onReceive(timer) { _ in
            guard isMoving, let block = currentBlock else { return }
            
            var currentPos = block.position
            currentPos.x += speed * direction
            
            if currentPos.x > 0.5 {
                direction = -1.0
            } else if currentPos.x < -0.5 {
                direction = 1.0
            }
            
            block.position = currentPos
        }
    }
    
    // --- LOGICA DI GIOCO ---
    
    func createBase(on anchor: Entity) {
        let baseMesh = MeshResource.generateBox(size: [0.4, blockHeight, blockDepth])
        let baseMaterial = SimpleMaterial(color: .gray, isMetallic: false)
        let baseBlock = ModelEntity(mesh: baseMesh, materials: [baseMaterial])
        baseBlock.position = [0, 0, 0]
        anchor.addChild(baseBlock)
        
        self.lastBlockX = 0.0
        self.currentWidth = 0.4
    }
    
    func spawnNewBlock() {
        guard let root = rootEntity else { return }
        
        towerHeight += 1
        updateScore()
        
        let newY = Float(towerHeight) * blockHeight
        
        let mesh = MeshResource.generateBox(size: [currentWidth, blockHeight, blockDepth])
        let material = SimpleMaterial(color: randomColor(), isMetallic: false)
        let newBlock = ModelEntity(mesh: mesh, materials: [material])
        
        newBlock.position = [-0.4, newY, 0]
        
        root.addChild(newBlock)
        
        self.currentBlock = newBlock
        self.isMoving = true
    }
    
    func placeBlock() {
        // Qui facciamo il cast: trattiamo 'block' come 'ModelEntity' per accedere a .model
        guard let block = currentBlock as? ModelEntity else { return }
        isMoving = false
        
        let currentX = block.position.x
        let diff = currentX - lastBlockX
        let absDiff = abs(diff)
        
        // GAME OVER - MANCATO
        if absDiff > currentWidth {
            print("GAME OVER - Mancato!")
            gameOverVisuals()
            return
        }
        
        // CALCOLO TAGLIO
        let newWidth = currentWidth - absDiff
        
        // GAME OVER - TROPPO PICCOLO
        if newWidth < 0.02 {
            print("GAME OVER - Troppo piccolo!")
            gameOverVisuals()
            return
        }
        
        // AGGIORNAMENTO BLOCCO
        let newCenter = lastBlockX + (diff / 2)
        
        // Ora funziona perché 'block' è un ModelEntity
        block.model?.mesh = MeshResource.generateBox(size: [newWidth, blockHeight, blockDepth])
        block.position.x = newCenter
        
        self.currentWidth = newWidth
        self.lastBlockX = newCenter
        
        spawnNewBlock()
    }
    
    func gameOverVisuals() {
        // Castiamo a ModelEntity per cambiare colore
        if let block = currentBlock as? ModelEntity {
            let material = SimpleMaterial(color: .black, isMetallic: true)
            block.model?.materials = [material]
        }
        
        // Castiamo a ModelEntity per cambiare il testo
        if let textEntity = scoreEntity as? ModelEntity {
            let mesh = MeshResource.generateText("GAME OVER\nTap to Restart", extrusionDepth: 0.01, font: .systemFont(ofSize: 0.08))
            textEntity.model?.mesh = mesh
            textEntity.model?.materials = [SimpleMaterial(color: .red, isMetallic: false)]
        }
    }
    
    func restartGame() {
        guard let root = rootEntity else { return }
        
        root.children.removeAll()
        
        // Ricrea Trigger
        let triggerMesh = MeshResource.generateBox(size: 10.0)
        let triggerMaterial = SimpleMaterial(color: .white.withAlphaComponent(0.01), isMetallic: false)
        let triggerEntity = ModelEntity(mesh: triggerMesh, materials: [triggerMaterial])
        triggerEntity.generateCollisionShapes(recursive: false)
        triggerEntity.components.set(InputTargetComponent())
        root.addChild(triggerEntity)
        
        // Ricrea Score
        let textMesh = MeshResource.generateText("Score: 0", extrusionDepth: 0.01, font: .systemFont(ofSize: 0.1))
        let textMaterial = SimpleMaterial(color: .white, isMetallic: false)
        let textEntity = ModelEntity(mesh: textMesh, materials: [textMaterial])
        textEntity.position = [-0.2, 0.5, -0.5]
        root.addChild(textEntity)
        self.scoreEntity = textEntity
        
        createBase(on: root)
        
        towerHeight = 0
        currentWidth = 0.4
        lastBlockX = 0.0
        
        spawnNewBlock()
    }
    
    func updateScore() {
        // Cast sicuro
        guard let textEntity = scoreEntity as? ModelEntity else { return }
        
        let mesh = MeshResource.generateText("Score: \(towerHeight)", extrusionDepth: 0.01, font: .systemFont(ofSize: 0.1))
        textEntity.model?.mesh = mesh
    }
    
    func randomColor() -> UIColor {
        return [UIColor.red, .blue, .green, .orange, .cyan, .purple, .magenta, .yellow].randomElement()!
    }
}

#Preview {
    GameView()
}
