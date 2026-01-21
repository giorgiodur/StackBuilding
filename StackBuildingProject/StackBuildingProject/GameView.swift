import SwiftUI
import RealityKit
import RealityKitContent
import Combine

struct GameView: View {
    var startingPosition: SIMD3<Float>
    
    // --- STATI GIOCO ---
    @State private var rootEntity: Entity?
    @State private var currentBlock: Entity?
    @State private var lastBlockPosition: SIMD3<Float> = [0, 0, 0]
    @State private var towerHeight: Int = 0
    @State private var currentSize: SIMD2<Float> = [0.4, 0.4]
    let blockHeight: Float = 0.05
    
    // Velocità iniziale
    @State private var speed: Float = 0.005
    
    @State private var isMoving: Bool = false
    @State private var moveOnXAxis: Bool = true
    @State private var moveDirection: Float = 1.0
    
    // --- TESTI UI ---
    @State private var scoreEntity: Entity?
    @State private var levelEntity: Entity? // Nuovo
    @State private var speedEntity: Entity? // Nuovo
    
    let timer = Timer.publish(every: 0.016, on: .main, in: .common).autoconnect()

    var body: some View {
        RealityView { content in
            let anchor = Entity()
            anchor.position = startingPosition
            
            // SCATOLA INVISIBILE (Tap Trigger)
            let triggerMesh = MeshResource.generateBox(width: 5.0, height: 5.0, depth: 5.0)
            let triggerMat = SimpleMaterial(color: .white.withAlphaComponent(0.0), isMetallic: false)
            let triggerEntity = ModelEntity(mesh: triggerMesh, materials: [triggerMat])
            triggerEntity.position.y = 2.5
            triggerEntity.generateCollisionShapes(recursive: false)
            triggerEntity.components.set(InputTargetComponent())
            anchor.addChild(triggerEntity)
            
            // CREAZIONE INTERFACCIA (Score, Livello, Velocità)
            setupUI(on: anchor)
            
            // Base
            createBase(on: anchor)
            
            content.add(anchor)
            self.rootEntity = anchor
            
            spawnNewBlock()
        }
        .gesture(SpatialTapGesture().targetedToAnyEntity().onEnded { _ in
            handleTap()
        })
        .onReceive(timer) { _ in
            gameLoop()
        }
    }
    
    // --- LOGICA GIOCO ---
    
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
        baseBlock.position = [0, 0, 0]
        anchor.addChild(baseBlock)
        self.lastBlockPosition = [0, 0, 0]
        self.currentSize = [0.4, 0.4]
    }
    
    func spawnNewBlock() {
        guard let root = rootEntity else { return }
        towerHeight += 1
        
        // Aggiorniamo tutte le scritte (Score, Livello, Velocità)
        updateUI()
        
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
        
        // INCREMENTO VELOCITÀ OGNI 10 BLOCCHI
        if towerHeight % 10 == 0 {
            speed += 0.005
        }
        
        spawnNewBlock()
    }
    
    func gameOverVisuals() {
        if let block = currentBlock as? ModelEntity {
            block.model?.materials = [SimpleMaterial(color: .black, isMetallic: true)]
        }
        
        // Cambia testo Score in Game Over
        if let textEntity = scoreEntity as? ModelEntity {
            let mesh = MeshResource.generateText("GAME OVER", extrusionDepth: 0.01, font: .systemFont(ofSize: 0.08))
            textEntity.model?.mesh = mesh
            textEntity.model?.materials = [SimpleMaterial(color: .red, isMetallic: false)]
        }
    }
    
    func restartGame() {
        guard let root = rootEntity else { return }
        root.children.removeAll()
        
        // Ricrea Trigger Invisibile
        let triggerMesh = MeshResource.generateBox(width: 5.0, height: 5.0, depth: 5.0)
        let triggerMat = SimpleMaterial(color: .white.withAlphaComponent(0.0), isMetallic: false)
        let triggerEntity = ModelEntity(mesh: triggerMesh, materials: [triggerMat])
        triggerEntity.position.y = 2.5
        triggerEntity.generateCollisionShapes(recursive: false)
        triggerEntity.components.set(InputTargetComponent())
        root.addChild(triggerEntity)
        
        // Ricrea tutta la UI (Score, Livello, Velocità)
        setupUI(on: root)
        
        createBase(on: root)
        towerHeight = 0
        speed = 0.005 // Reset velocità
        spawnNewBlock()
    }
    
    // --- GESTIONE GRAFICA UI ---
    
    func setupUI(on anchor: Entity) {
        // 1. LIVELLO (In alto, Giallo)
        let levelMesh = MeshResource.generateText("Level: 1", extrusionDepth: 0.01, font: .systemFont(ofSize: 0.08))
        let levelMat = SimpleMaterial(color: .yellow, isMetallic: false)
        let levelEnt = ModelEntity(mesh: levelMesh, materials: [levelMat])
        levelEnt.position = [-0.3, 0.70, -0.5] // Più in alto
        anchor.addChild(levelEnt)
        self.levelEntity = levelEnt
        
        // 2. SCORE (Al centro, Bianco, Più grande)
        let scoreMesh = MeshResource.generateText("Score: 0", extrusionDepth: 0.01, font: .systemFont(ofSize: 0.1))
        let scoreMat = SimpleMaterial(color: .white, isMetallic: false)
        let scoreEnt = ModelEntity(mesh: scoreMesh, materials: [scoreMat])
        scoreEnt.position = [-0.3, 0.55, -0.5]
        anchor.addChild(scoreEnt)
        self.scoreEntity = scoreEnt
        
        // 3. VELOCITÀ (In basso, Ciano, Più piccolo)
        let speedString = String(format: "Speed: %.3f", speed)
        let speedMesh = MeshResource.generateText(speedString, extrusionDepth: 0.01, font: .systemFont(ofSize: 0.06))
        let speedMat = SimpleMaterial(color: .cyan, isMetallic: false)
        let speedEnt = ModelEntity(mesh: speedMesh, materials: [speedMat])
        speedEnt.position = [-0.3, 0.45, -0.5] // Più in basso
        anchor.addChild(speedEnt)
        self.speedEntity = speedEnt
    }
    
    func updateUI() {
        // Aggiorna Score
        if let scoreEnt = scoreEntity as? ModelEntity {
            let mesh = MeshResource.generateText("Score: \(towerHeight)", extrusionDepth: 0.01, font: .systemFont(ofSize: 0.1))
            scoreEnt.model?.mesh = mesh
            // Resetta colore se era rosso per game over
            scoreEnt.model?.materials = [SimpleMaterial(color: .white, isMetallic: false)]
        }
        
        // Aggiorna Livello (Logica: 0-10 = Lv1, 11-20 = Lv2, ecc.)
        if let levelEnt = levelEntity as? ModelEntity {
            // Se towerHeight è 0, è livello 1. Se è 10, è livello 1. Se è 11, è livello 2.
            // Formula: ((towerHeight - 1) / 10) + 1. Usiamo max(0) per gestire l'inizio.
            let currentLevel = (towerHeight == 0) ? 1 : ((towerHeight - 1) / 10) + 1
            let mesh = MeshResource.generateText("Level: \(currentLevel)", extrusionDepth: 0.01, font: .systemFont(ofSize: 0.08))
            levelEnt.model?.mesh = mesh
        }
        
        // Aggiorna Velocità
        if let speedEnt = speedEntity as? ModelEntity {
            let speedString = String(format: "Speed: %.3f", speed)
            let mesh = MeshResource.generateText(speedString, extrusionDepth: 0.01, font: .systemFont(ofSize: 0.06))
            speedEnt.model?.mesh = mesh
        }
    }
    
    func randomColor() -> UIColor {
        [UIColor.red, .blue, .green, .orange, .purple].randomElement()!
    }
}
