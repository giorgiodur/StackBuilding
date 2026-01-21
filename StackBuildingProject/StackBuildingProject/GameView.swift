import SwiftUI
import RealityKit
import RealityKitContent
import Combine

struct GameView: View {
    var startingPosition: SIMD3<Float>
    
    // --- VARIABILI STEP 5 ---
    @State private var rootEntity: Entity?
    @State private var currentBlock: Entity?
    @State private var lastBlockPosition: SIMD3<Float> = [0, 0, 0]
    @State private var towerHeight: Int = 0
    @State private var currentSize: SIMD2<Float> = [0.4, 0.4] // Dimensioni Originali
    let blockHeight: Float = 0.05
    @State private var speed: Float = 0.010
    @State private var isMoving: Bool = false
    @State private var moveOnXAxis: Bool = true
    @State private var moveDirection: Float = 1.0
    @State private var scoreEntity: Entity?
    
    let timer = Timer.publish(every: 0.016, on: .main, in: .common).autoconnect()

    var body: some View {
        RealityView { content in
            let anchor = Entity()
            anchor.position = startingPosition
            
            // --- IL SEGRETO DEL TAP IN AR ---
            // Creiamo una scatola invisibile enorme attorno al gioco.
            // Qualsiasi tap in quest'area verrà catturato.
            let triggerMesh = MeshResource.generateBox(width: 2.0, height: 2.0, depth: 2.0)
            let triggerMat = SimpleMaterial(color: .white.withAlphaComponent(0.001), isMetallic: false)
            let triggerEntity = ModelEntity(mesh: triggerMesh, materials: [triggerMat])
            triggerEntity.position.y = 1.0 // Centro della scatola a 1m di altezza
            triggerEntity.generateCollisionShapes(recursive: false)
            triggerEntity.components.set(InputTargetComponent()) // Rende cliccabile
            anchor.addChild(triggerEntity)
            
            // Score
            let textMesh = MeshResource.generateText("Score: 0", extrusionDepth: 0.01, font: .systemFont(ofSize: 0.1))
            let textMaterial = SimpleMaterial(color: .white, isMetallic: false)
            let textEntity = ModelEntity(mesh: textMesh, materials: [textMaterial])
            textEntity.position = [-0.2, 0.5, -0.5]
            anchor.addChild(textEntity)
            self.scoreEntity = textEntity
            
            // Base
            createBase(on: anchor)
            
            content.add(anchor)
            self.rootEntity = anchor
            
            spawnNewBlock()
        }
        // Gesto Tap Generico (funziona grazie alla scatola invisibile)
        .gesture(SpatialTapGesture().targetedToAnyEntity().onEnded { _ in
            handleTap()
        })
        .onReceive(timer) { _ in
            gameLoop()
        }
    }
    
    // --- LOGICA DI GIOCO STEP 5 ---
    
    func handleTap() {
        if isMoving { placeBlock() } else { restartGame() }
    }
    
    func gameLoop() {
        guard isMoving, let block = currentBlock else { return }
        var currentPos = block.position
        if moveOnXAxis { currentPos.x += speed * moveDirection }
        else { currentPos.z += speed * moveDirection }
        block.position = currentPos
        if abs(currentPos.x) > 0.6 || abs(currentPos.z) > 0.6 { moveDirection *= -1.0 }
    }
    
    func createBase(on anchor: Entity) {
        let baseMesh = MeshResource.generateBox(size: [0.4, blockHeight, 0.4])
        let baseMaterial = SimpleMaterial(color: .gray, isMetallic: false)
        let baseBlock = ModelEntity(mesh: baseMesh, materials: [baseMaterial])
        baseBlock.position = [0, 0, 0] // Relativo all'ancora (quindi sul tavolo)
        anchor.addChild(baseBlock)
        self.lastBlockPosition = [0, 0, 0]
        self.currentSize = [0.4, 0.4]
    }
    
    func spawnNewBlock() {
        guard let root = rootEntity else { return }
        towerHeight += 1
        updateScore()
        let newY = Float(towerHeight) * blockHeight
        let directionIndex = towerHeight % 4
        var startPos: SIMD3<Float> = [lastBlockPosition.x, newY, lastBlockPosition.z]
        
        switch directionIndex {
        case 0: moveOnXAxis = false; moveDirection = 1.0; startPos.z = -0.5
        case 1: moveOnXAxis = true; moveDirection = -1.0; startPos.x = 0.5
        case 2: moveOnXAxis = false; moveDirection = -1.0; startPos.z = 0.5
        case 3: moveOnXAxis = true; moveDirection = 1.0; startPos.x = -0.5
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
        let diffX = currentPos.x - lastBlockPosition.x
        let diffZ = currentPos.z - lastBlockPosition.z
        var newWidth = currentSize.x
        var newDepth = currentSize.y
        var newCenterX = lastBlockPosition.x
        var newCenterZ = lastBlockPosition.z
        
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
        
        if newWidth < 0.02 || newDepth < 0.02 { gameOverVisuals(); return }
        
        block.model?.mesh = MeshResource.generateBox(size: [newWidth, blockHeight, newDepth])
        block.position = [newCenterX, currentPos.y, newCenterZ]
        self.currentSize = [newWidth, newDepth]
        self.lastBlockPosition = [newCenterX, 0, newCenterZ]
        if towerHeight % 10 == 0 { speed += 0.002 }
        spawnNewBlock()
    }
    
    func gameOverVisuals() {
        if let block = currentBlock as? ModelEntity {
            block.model?.materials = [SimpleMaterial(color: .black, isMetallic: true)]
        }
        if let text = scoreEntity as? ModelEntity {
            text.model?.mesh = MeshResource.generateText("GAME OVER", extrusionDepth: 0.01, font: .systemFont(ofSize: 0.08))
            text.model?.materials = [SimpleMaterial(color: .red, isMetallic: false)]
        }
    }
    
    func restartGame() {
        guard let root = rootEntity else { return }
        // Rimuoviamo tutto TRANNE la scatola trigger (che è il primo figlio aggiunto)
        // Per sicurezza, puliamo e ricreiamo il trigger
        root.children.removeAll()
        
        let triggerMesh = MeshResource.generateBox(width: 2.0, height: 2.0, depth: 2.0)
        let triggerMat = SimpleMaterial(color: .white.withAlphaComponent(0.001), isMetallic: false)
        let triggerEntity = ModelEntity(mesh: triggerMesh, materials: [triggerMat])
        triggerEntity.position.y = 1.0
        triggerEntity.generateCollisionShapes(recursive: false)
        triggerEntity.components.set(InputTargetComponent())
        root.addChild(triggerEntity)
        
        let textMesh = MeshResource.generateText("Score: 0", extrusionDepth: 0.01, font: .systemFont(ofSize: 0.1))
        let textMaterial = SimpleMaterial(color: .white, isMetallic: false)
        let textEntity = ModelEntity(mesh: textMesh, materials: [textMaterial])
        textEntity.position = [-0.2, 0.5, -0.5]
        root.addChild(textEntity)
        self.scoreEntity = textEntity
        
        createBase(on: root)
        towerHeight = 0
        speed = 0.010
        spawnNewBlock()
    }
    
    func updateScore() {
        guard let text = scoreEntity as? ModelEntity else { return }
        text.model?.mesh = MeshResource.generateText("Score: \(towerHeight)", extrusionDepth: 0.01, font: .systemFont(ofSize: 0.1))
    }
    
    func randomColor() -> UIColor {
        [UIColor.red, .blue, .green, .orange, .purple].randomElement()!
    }
}
