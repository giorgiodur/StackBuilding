import SwiftUI
import RealityKit
import RealityKitContent
import Combine

struct GameView: View {
    // --- STATO DEL GIOCO ---
    @State private var rootEntity: Entity?
    @State private var currentBlock: Entity?
    
    @State private var lastBlockPosition: SIMD3<Float> = [0, 0, 0]
    @State private var towerHeight: Int = 0
    
    // --- DIMENSIONI ATTUALI ---
    @State private var currentSize: SIMD2<Float> = [0.4, 0.4]
    let blockHeight: Float = 0.05
    
    // --- MOVIMENTO E VELOCITÀ ---
    // Partiamo più lenti (0.010 invece di 0.015)
    @State private var speed: Float = 0.010
    @State private var isMoving: Bool = false
    @State private var moveOnXAxis: Bool = true
    @State private var moveDirection: Float = 1.0
    
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
            
            // LOGICA DI MOVIMENTO
            var currentPos = block.position
            
            if moveOnXAxis {
                currentPos.x += speed * moveDirection
            } else {
                currentPos.z += speed * moveDirection
            }
            
            block.position = currentPos
            
            // Rimbalzo ai bordi (0.6m)
            if abs(currentPos.x) > 0.6 || abs(currentPos.z) > 0.6 {
                moveDirection *= -1.0
            }
        }
    }
    
    // --- FUNZIONI ---
    
    func createBase(on anchor: Entity) {
        let baseMesh = MeshResource.generateBox(size: [0.4, blockHeight, 0.4])
        let baseMaterial = SimpleMaterial(color: .gray, isMetallic: false)
        let baseBlock = ModelEntity(mesh: baseMesh, materials: [baseMaterial])
        baseBlock.position = [0, 0, 0]
        anchor.addChild(baseBlock)
        
        // Reset variabili stato
        self.lastBlockPosition = [0, 0, 0]
        self.currentSize = [0.4, 0.4]
    }
    
    func spawnNewBlock() {
        guard let root = rootEntity else { return }
        
        towerHeight += 1
        updateScore()
        
        let newY = Float(towerHeight) * blockHeight
        
        // DIREZIONI A ROTAZIONE (Nord -> Est -> Sud -> Ovest)
        let directionIndex = towerHeight % 4
        var startPos: SIMD3<Float> = [lastBlockPosition.x, newY, lastBlockPosition.z]
        
        switch directionIndex {
        case 0: // NORD
            moveOnXAxis = false
            moveDirection = 1.0
            startPos.z = -0.5
        case 1: // EST
            moveOnXAxis = true
            moveDirection = -1.0
            startPos.x = 0.5
        case 2: // SUD
            moveOnXAxis = false
            moveDirection = -1.0
            startPos.z = 0.5
        case 3: // OVEST
            moveOnXAxis = true
            moveDirection = 1.0
            startPos.x = -0.5
        default: break
        }
        
        let mesh = MeshResource.generateBox(size: [currentSize.x, blockHeight, currentSize.y])
        let material = SimpleMaterial(color: randomColor(), isMetallic: false)
        let newBlock = ModelEntity(mesh: mesh, materials: [material])
        
        newBlock.position = startPos
        root.addChild(newBlock)
        
        self.currentBlock = newBlock
        self.isMoving = true
    }
    
    func placeBlock() {
        guard let block = currentBlock as? ModelEntity else { return }
        isMoving = false
        
        let currentPos = block.position
        
        // Calcolo differenze
        let diffX = currentPos.x - lastBlockPosition.x
        let diffZ = currentPos.z - lastBlockPosition.z
        
        var newWidth = currentSize.x
        var newDepth = currentSize.y
        var newCenterX = lastBlockPosition.x
        var newCenterZ = lastBlockPosition.z
        
        // Logica Taglio
        if moveOnXAxis {
            let overlap = currentSize.x - abs(diffX)
            if overlap <= 0 { gameOverVisuals(); return }
            newWidth = overlap
            newCenterX = lastBlockPosition.x + (diffX / 2)
        } else {
            let overlap = currentSize.y - abs(diffZ)
            if overlap <= 0 { gameOverVisuals(); return }
            newDepth = overlap
            newCenterZ = lastBlockPosition.z + (diffZ / 2)
        }
        
        // Check dimensione minima
        if newWidth < 0.02 || newDepth < 0.02 {
            gameOverVisuals()
            return
        }
        
        // Aggiorna Blocco Visivo
        block.model?.mesh = MeshResource.generateBox(size: [newWidth, blockHeight, newDepth])
        block.position = [newCenterX, currentPos.y, newCenterZ]
        
        // Salva stato
        self.currentSize = [newWidth, newDepth]
        self.lastBlockPosition = [newCenterX, 0, newCenterZ]
        
        // --- LOGICA AUMENTO VELOCITÀ ---
        // Ogni 10 cubi (10, 20, 30...), acceleriamo
        if towerHeight % 10 == 0 {
            speed += 0.002
            print("Level Up! Nuova velocità: \(speed)")
        }
        
        spawnNewBlock()
    }
    
    func gameOverVisuals() {
        if let block = currentBlock as? ModelEntity {
            let material = SimpleMaterial(color: .black, isMetallic: true)
            block.model?.materials = [material]
        }
        
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
        
        // RESET COMPLETO
        towerHeight = 0
        speed = 0.010 // Torniamo alla velocità lenta iniziale
        spawnNewBlock()
    }
    
    func updateScore() {
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
