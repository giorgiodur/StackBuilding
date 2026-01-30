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
    
    // --- DATI SALVATI (PERSISTENZA) ---
    @State private var highScore: Int = UserDefaults.standard.integer(forKey: "HighScore")
    @State private var bestCombo: Int = UserDefaults.standard.integer(forKey: "BestCombo") // Nuovo Record Combo
    // ----------------------------------
    
    // Grandezza blocchi (1.2m)
    @State private var currentSize: SIMD2<Float> = [1.2, 1.2]
    let blockHeight: Float = 0.05
    
    @State private var speed: Float = 0.005
    
    @State private var isMoving: Bool = false
    @State private var moveOnXAxis: Bool = true
    @State private var moveDirection: Float = 1.0
    
    // Combo Attuale
    @State private var perfectStreak: Int = 0
    
    // UI Entità
    @State private var scoreEntity: Entity?
    @State private var highScoreEntity: Entity?
    @State private var bestComboEntity: Entity? // Nuova Scritta UI
    @State private var levelEntity: Entity?
    @State private var comboEntity: Entity?
    
    let timer = Timer.publish(every: 0.016, on: .main, in: .common).autoconnect()

    var body: some View {
        RealityView { content in
            
            // Audio
            await AudioManager.shared.loadSounds()
            
            let anchor = Entity()
            anchor.position = startingPosition
            
            // Trigger 3x5x3
            let triggerMesh = MeshResource.generateBox(width: 3.0, height: 5.0, depth: 3.0)
            let triggerMat = SimpleMaterial(color: .white.withAlphaComponent(0.0), isMetallic: false)
            let triggerEntity = ModelEntity(mesh: triggerMesh, materials: [triggerMat])
            triggerEntity.position.y = 2.5
            triggerEntity.generateCollisionShapes(recursive: false)
            triggerEntity.components.set(InputTargetComponent())
            anchor.addChild(triggerEntity)
            
            setupUI(on: anchor)
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
        
        if abs(currentPos.x) > 1.8 || abs(currentPos.z) > 1.8 {
            moveDirection *= -1.0
        }
    }
    
    func createBase(on anchor: Entity) {
        let baseMesh = MeshResource.generateBox(size: [currentSize.x, blockHeight, currentSize.y])
        let baseMaterial = SimpleMaterial(color: .gray, isMetallic: false)
        let baseBlock = ModelEntity(mesh: baseMesh, materials: [baseMaterial])
        baseBlock.position = [0, 0, 0]
        baseBlock.generateCollisionShapes(recursive: false)
        baseBlock.components.set(PhysicsBodyComponent(mode: .static))
        anchor.addChild(baseBlock)
        
        self.lastBlockPosition = [0, 0, 0]
        self.currentSize = [1.2, 1.2]
        self.perfectStreak = 0
    }
    
    func spawnNewBlock() {
        guard let root = rootEntity else { return }
        towerHeight += 1
        
        // Logica High Score (Altezza)
        if towerHeight > highScore {
            highScore = towerHeight
            UserDefaults.standard.set(highScore, forKey: "HighScore")
            showComboText(text: "NEW RECORD! 🏆")
        }
        
        updateUI()
        
        let newY = Float(towerHeight) * blockHeight
        let directionIndex = towerHeight % 4
        var startPos: SIMD3<Float> = [lastBlockPosition.x, newY, lastBlockPosition.z]
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
        
        var finalMaterial = block.model?.materials.first ?? SimpleMaterial(color: .red, isMetallic: false)
        
        // Logica Perfetto (Tolleranza 5cm)
        let isPerfectX = moveOnXAxis && abs(diffX) < 0.05
        let isPerfectZ = !moveOnXAxis && abs(diffZ) < 0.05
        let isPerfect = isPerfectX || isPerfectZ
        
        if isPerfect {
            perfectStreak += 1
            
            // --- NUOVA LOGICA: RECORD COMBO ---
            if perfectStreak > bestCombo {
                bestCombo = perfectStreak
                UserDefaults.standard.set(bestCombo, forKey: "BestCombo")
                // Feedback speciale se batti il record combo
                showComboText(text: "MAX COMBO! 🔥")
            } else {
                // Feedback standard
                showComboText(text: "PERFECT! x\(perfectStreak)")
            }
            // ----------------------------------
            
            if moveOnXAxis { newCenterX = lastBlockPosition.x }
            else { newCenterZ = lastBlockPosition.z }
            
            let goldMat = SimpleMaterial(color: .yellow, isMetallic: true)
            finalMaterial = goldMat
            
            if perfectStreak >= 3 {
                let doubledX = min(currentSize.x * 2.0, 1.2)
                let doubledY = min(currentSize.y * 2.0, 1.2)
                self.currentSize = [doubledX, doubledY]
                newWidth = currentSize.x
                newDepth = currentSize.y
                showComboText(text: "SIZE UP! 🚀")
                // Nota: Non resettiamo perfectStreak qui per permettere di battere il record combo!
                // Ma resettiamo il bonus 'size up' internamente se volessimo,
                // oppure lasciamo che continui a ingrandire (ma c'è il limite min(..., 1.2)).
                // Per semplicità, lasciamo la streak intatta.
            }
            
        } else {
            perfectStreak = 0 // Reset Combo se sbagli
            
            if moveOnXAxis {
                let overlap = currentSize.x - abs(diffX)
                if overlap <= 0 { gameOverVisuals(); return }
                newWidth = overlap
                newCenterX = lastBlockPosition.x + (diffX / 2)
                
                let debrisWidth = abs(diffX)
                let debrisX = (diffX > 0) ? (newCenterX + (newWidth / 2) + (debrisWidth / 2)) : (newCenterX - (newWidth / 2) - (debrisWidth / 2))
                spawnDebris(position: [debrisX, currentPos.y, currentPos.z], size: [debrisWidth, blockHeight, currentSize.y], material: finalMaterial)
                
            } else {
                let overlap = currentSize.y - abs(diffZ)
                if overlap <= 0 { gameOverVisuals(); return }
                newDepth = overlap
                newCenterZ = lastBlockPosition.z + (diffZ / 2)
                
                let debrisDepth = abs(diffZ)
                let debrisZ = (diffZ > 0) ? (newCenterZ + (newDepth / 2) + (debrisDepth / 2)) : (newCenterZ - (newDepth / 2) - (debrisDepth / 2))
                spawnDebris(position: [currentPos.x, currentPos.y, debrisZ], size: [currentSize.x, blockHeight, debrisDepth], material: finalMaterial)
            }
            
            self.currentSize = [newWidth, newDepth]
        }
        
        if newWidth < 0.02 || newDepth < 0.02 { gameOverVisuals(); return }
        
        block.model?.mesh = MeshResource.generateBox(size: [newWidth, blockHeight, newDepth])
        block.model?.materials = [finalMaterial]
        block.position = [newCenterX, currentPos.y, newCenterZ]
        
        self.lastBlockPosition = [newCenterX, 0, newCenterZ]
        
        AudioManager.shared.play("hit", from: block)
        
        if towerHeight % 5 == 0 { speed += 0.002 }
        
        spawnNewBlock()
    }
    
    // --- UI COMBO ANIMATA ---
    func showComboText(text: String) {
        guard let anchor = rootEntity else { return }
        comboEntity?.removeFromParent()
        
        let mesh = MeshResource.generateText(text, extrusionDepth: 0.02, font: .systemFont(ofSize: 0.1, weight: .bold))
        let mat = SimpleMaterial(color: .green, isMetallic: false)
        let entity = ModelEntity(mesh: mesh, materials: [mat])
        
        let textY = Float(towerHeight) * blockHeight + 0.5
        entity.position = [0, textY, -0.5]
        entity.components.set(BillboardComponent())
        
        anchor.addChild(entity)
        self.comboEntity = entity
        
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            entity.removeFromParent()
        }
    }
    
    // --- FISICA DETRITI ---
    func spawnDebris(position: SIMD3<Float>, size: SIMD3<Float>, material: RealityKit.Material) {
        guard let root = rootEntity else { return }
        
        let debrisMesh = MeshResource.generateBox(size: size)
        let debris = ModelEntity(mesh: debrisMesh, materials: [material])
        debris.position = position
        
        var physics = PhysicsBodyComponent(massProperties: .default, material: .default, mode: .dynamic)
        physics.isAffectedByGravity = true
        debris.components.set(physics)
        
        let shape = ShapeResource.generateBox(size: size)
        debris.components.set(CollisionComponent(shapes: [shape]))
        
        root.addChild(debris)
        
        Task {
            try? await Task.sleep(for: .seconds(5))
            debris.removeFromParent()
        }
    }
    
    func gameOverVisuals() {
        if let block = currentBlock as? ModelEntity {
            block.model?.materials = [SimpleMaterial(color: .black, isMetallic: true)]
            AudioManager.shared.play("gameover", from: block)
        }
        if let textEntity = scoreEntity as? ModelEntity {
            let mesh = MeshResource.generateText("GAME OVER", extrusionDepth: 0.01, font: .systemFont(ofSize: 0.08))
            textEntity.model?.mesh = mesh
            textEntity.model?.materials = [SimpleMaterial(color: .red, isMetallic: false)]
        }
    }
    
    func restartGame() {
        guard let root = rootEntity else { return }
        root.children.removeAll()
        
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
    
    // --- UI SETUP (Layout Aggiornato per 4 righe) ---
    func setupUI(on anchor: Entity) {
        // Ho alzato tutto verso l'alto per fare spazio
        
        // 1. Level (Y=0.95)
        let levelMesh = MeshResource.generateText("Level: 1", extrusionDepth: 0.01, font: .systemFont(ofSize: 0.08))
        let levelMat = SimpleMaterial(color: .yellow, isMetallic: false)
        let levelEnt = ModelEntity(mesh: levelMesh, materials: [levelMat])
        levelEnt.position = [-1.0, 0.95, 0.0]
        levelEnt.components.set(BillboardComponent())
        anchor.addChild(levelEnt)
        self.levelEntity = levelEnt
        
        // 2. Score (Y=0.80)
        let scoreMesh = MeshResource.generateText("Score: 0", extrusionDepth: 0.01, font: .systemFont(ofSize: 0.1))
        let scoreMat = SimpleMaterial(color: .white, isMetallic: false)
        let scoreEnt = ModelEntity(mesh: scoreMesh, materials: [scoreMat])
        scoreEnt.position = [-1.0, 0.80, 0.0]
        scoreEnt.components.set(BillboardComponent())
        anchor.addChild(scoreEnt)
        self.scoreEntity = scoreEnt
        
        // 3. High Score (Y=0.65)
        let bestScoreText = "Best: \(highScore)"
        let bestMesh = MeshResource.generateText(bestScoreText, extrusionDepth: 0.01, font: .systemFont(ofSize: 0.06))
        let bestMat = SimpleMaterial(color: .gray, isMetallic: false)
        let bestEnt = ModelEntity(mesh: bestMesh, materials: [bestMat])
        bestEnt.position = [-1.0, 0.65, 0.0]
        bestEnt.components.set(BillboardComponent())
        anchor.addChild(bestEnt)
        self.highScoreEntity = bestEnt
        
        // 4. MAX COMBO (Y=0.55) - NUOVO!
        let maxComboText = "Max Combo: \(bestCombo)"
        let comboMesh = MeshResource.generateText(maxComboText, extrusionDepth: 0.01, font: .systemFont(ofSize: 0.06))
        let comboMat = SimpleMaterial(color: .orange, isMetallic: false) // Arancione per distinguersi
        let comboEnt = ModelEntity(mesh: comboMesh, materials: [comboMat])
        comboEnt.position = [-1.0, 0.55, 0.0]
        comboEnt.components.set(BillboardComponent())
        anchor.addChild(comboEnt)
        self.bestComboEntity = comboEnt
    }
    
    func updateUI() {
        // Aggiorna Score
        if let scoreEnt = scoreEntity as? ModelEntity {
            let mesh = MeshResource.generateText("Score: \(towerHeight)", extrusionDepth: 0.01, font: .systemFont(ofSize: 0.1))
            scoreEnt.model?.mesh = mesh
            scoreEnt.model?.materials = [SimpleMaterial(color: .white, isMetallic: false)]
        }
        
        // Aggiorna Best Score
        if let bestEnt = highScoreEntity as? ModelEntity {
            let mesh = MeshResource.generateText("Best: \(highScore)", extrusionDepth: 0.01, font: .systemFont(ofSize: 0.06))
            bestEnt.model?.mesh = mesh
            if towerHeight >= highScore && highScore > 0 {
                bestEnt.model?.materials = [SimpleMaterial(color: .yellow, isMetallic: true)]
            } else {
                bestEnt.model?.materials = [SimpleMaterial(color: .gray, isMetallic: false)]
            }
        }
        
        // Aggiorna Max Combo - NUOVO!
        if let comboEnt = bestComboEntity as? ModelEntity {
            let mesh = MeshResource.generateText("Max Combo: \(bestCombo)", extrusionDepth: 0.01, font: .systemFont(ofSize: 0.06))
            comboEnt.model?.mesh = mesh
            // Se stiamo battendo il record combo, diventa Arancione Acceso
            if perfectStreak >= bestCombo && bestCombo > 0 {
                comboEnt.model?.materials = [SimpleMaterial(color: .orange, isMetallic: true)]
            } else {
                comboEnt.model?.materials = [SimpleMaterial(color: .gray, isMetallic: false)]
            }
        }
        
        // Aggiorna Level
        if let levelEnt = levelEntity as? ModelEntity {
            let currentLevel = (towerHeight == 0) ? 1 : ((towerHeight - 1) / 5) + 1
            let mesh = MeshResource.generateText("Level: \(currentLevel)", extrusionDepth: 0.01, font: .systemFont(ofSize: 0.08))
            levelEnt.model?.mesh = mesh
        }
    }
    
    func randomColor() -> UIColor {
        [UIColor.red, .blue, .green, .orange, .purple].randomElement()!
    }
}
