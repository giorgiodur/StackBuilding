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
    
    // Grandezza blocchi (1.2m)
    @State private var currentSize: SIMD2<Float> = [1.2, 1.2]
    let blockHeight: Float = 0.05
    
    @State private var speed: Float = 0.005
    
    @State private var isMoving: Bool = false
    @State private var moveOnXAxis: Bool = true
    @State private var moveDirection: Float = 1.0
    
    // UI
    @State private var scoreEntity: Entity?
    @State private var levelEntity: Entity?
    
    let timer = Timer.publish(every: 0.016, on: .main, in: .common).autoconnect()

    var body: some View {
        RealityView { content in
            let anchor = Entity()
            anchor.position = startingPosition
            
            // Trigger 3x5x3 (Tap Volume)
            let triggerMesh = MeshResource.generateBox(width: 3.0, height: 5.0, depth: 3.0)
            let triggerMat = SimpleMaterial(color: .white.withAlphaComponent(0.0), isMetallic: false)
            let triggerEntity = ModelEntity(mesh: triggerMesh, materials: [triggerMat])
            
            // Centro a 2.5m
            triggerEntity.position.y = 2.5
            
            triggerEntity.generateCollisionShapes(recursive: false)
            triggerEntity.components.set(InputTargetComponent())
            anchor.addChild(triggerEntity)
            
            // Setup UI (Laterale + Billboard)
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
        
        // Limite movimento (1.8m per lato)
        if abs(currentPos.x) > 1.8 || abs(currentPos.z) > 1.8 {
            moveDirection *= -1.0
        }
    }
    
    func createBase(on anchor: Entity) {
        let baseMesh = MeshResource.generateBox(size: [currentSize.x, blockHeight, currentSize.y])
        let baseMaterial = SimpleMaterial(color: .gray, isMetallic: false)
        let baseBlock = ModelEntity(mesh: baseMesh, materials: [baseMaterial])
        baseBlock.position = [0, 0, 0]
        anchor.addChild(baseBlock)
        
        self.lastBlockPosition = [0, 0, 0]
        self.currentSize = [1.2, 1.2]
    }
    
    func spawnNewBlock() {
        guard let root = rootEntity else { return }
        towerHeight += 1
        
        updateUI()
        
        let newY = Float(towerHeight) * blockHeight
        let directionIndex = towerHeight % 4
        var startPos: SIMD3<Float> = [lastBlockPosition.x, newY, lastBlockPosition.z]
        
        // Distanza Spawn
        let spawnDist: Float = 1.5
        
        switch directionIndex {
        case 0: moveOnXAxis = false; moveDirection = 1.0; startPos.z = -spawnDist
        case 1: moveOnXAxis = true; moveDirection = -1.0; startPos.x = spawnDist
        case 2: moveOnXAxis = false; moveDirection = -1.0; startPos.z = spawnDist
        case 3: moveOnXAxis = true; moveDirection = 1.0; startPos.x = -spawnDist
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
        
        // Aumento VELOCITÀ ogni 5 blocchi (+0.002)
        if towerHeight % 5 == 0 {
            speed += 0.002
        }
        
        spawnNewBlock()
    }
    
    func gameOverVisuals() {
        if let block = currentBlock as? ModelEntity {
            block.model?.materials = [SimpleMaterial(color: .black, isMetallic: true)]
        }
        if let textEntity = scoreEntity as? ModelEntity {
            // Testo in INGLESE
            let mesh = MeshResource.generateText("GAME OVER", extrusionDepth: 0.01, font: .systemFont(ofSize: 0.08))
            textEntity.model?.mesh = mesh
            textEntity.model?.materials = [SimpleMaterial(color: .red, isMetallic: false)]
        }
    }
    
    func restartGame() {
        guard let root = rootEntity else { return }
        root.children.removeAll()
        
        // Trigger 3x5x3
        let triggerMesh = MeshResource.generateBox(width: 3.0, height: 5.0, depth: 3.0)
        let triggerMat = SimpleMaterial(color: .white.withAlphaComponent(0.0), isMetallic: false)
        let triggerEntity = ModelEntity(mesh: triggerMesh, materials: [triggerMat])
        triggerEntity.position.y = 2.5
        triggerEntity.generateCollisionShapes(recursive: false)
        triggerEntity.components.set(InputTargetComponent())
        root.addChild(triggerEntity)
        
        setupUI(on: root)
        createBase(on: root)
        
        towerHeight = 0
        speed = 0.005
        spawnNewBlock()
    }
    
    // --- GESTIONE UI (LATERALE + BILLBOARD) ---
    
    func setupUI(on anchor: Entity) {
        // Posizione: Spostato a sinistra (-1.0)
        
        // 1. LIVELLO (Testo INGLESE)
        let levelMesh = MeshResource.generateText("Level: 1", extrusionDepth: 0.01, font: .systemFont(ofSize: 0.08))
        let levelMat = SimpleMaterial(color: .yellow, isMetallic: false)
        let levelEnt = ModelEntity(mesh: levelMesh, materials: [levelMat])
        
        levelEnt.position = [-1.0, 0.65, 0.0]
        levelEnt.components.set(BillboardComponent()) // Guarda sempre l'utente
        
        anchor.addChild(levelEnt)
        self.levelEntity = levelEnt
        
        // 2. SCORE (Testo INGLESE)
        let scoreMesh = MeshResource.generateText("Score: 0", extrusionDepth: 0.01, font: .systemFont(ofSize: 0.1))
        let scoreMat = SimpleMaterial(color: .white, isMetallic: false)
        let scoreEnt = ModelEntity(mesh: scoreMesh, materials: [scoreMat])
        
        scoreEnt.position = [-1.0, 0.50, 0.0]
        scoreEnt.components.set(BillboardComponent()) // Guarda sempre l'utente
        
        anchor.addChild(scoreEnt)
        self.scoreEntity = scoreEnt
    }
    
    func updateUI() {
        if let scoreEnt = scoreEntity as? ModelEntity {
            // Testo INGLESE
            let mesh = MeshResource.generateText("Score: \(towerHeight)", extrusionDepth: 0.01, font: .systemFont(ofSize: 0.1))
            scoreEnt.model?.mesh = mesh
            scoreEnt.model?.materials = [SimpleMaterial(color: .white, isMetallic: false)]
        }
        
        if let levelEnt = levelEntity as? ModelEntity {
            // Logica livello visivo: ogni 5 blocchi
            let currentLevel = (towerHeight == 0) ? 1 : ((towerHeight - 1) / 5) + 1
            // Testo INGLESE
            let mesh = MeshResource.generateText("Level: \(currentLevel)", extrusionDepth: 0.01, font: .systemFont(ofSize: 0.08))
            levelEnt.model?.mesh = mesh
        }
    }
    
    func randomColor() -> UIColor {
        [UIColor.red, .blue, .green, .orange, .purple].randomElement()!
    }
}
