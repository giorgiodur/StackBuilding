import SwiftUI
import RealityKit

@main
struct StackBuildingProjectApp: App {
    // 1. Inizializziamo il "Cervello" AR
    @State private var arManager = ARManager()
    
    // 2. Stato per sapere se siamo in modalità AR o no
    @State private var immersiveSpaceIsShown = false
    
    // 3. Comandi di sistema
    @Environment(\.openImmersiveSpace) var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) var dismissImmersiveSpace

    // *** CORREZIONE QUI SOTTO ***
    // Usiamo "SwiftUI.Scene" per evitare confusioni con altri file chiamati "Scene"
    var body: some SwiftUI.Scene {
        
        // --- FINESTRA 2D (MENU PRINCIPALE) ---
        WindowGroup {
            VStack(spacing: 25) {
                Text("Stack AR")
                    .font(.extraLargeTitle)
                    .fontWeight(.bold)
                
                if !immersiveSpaceIsShown {
                    // MODO MENU
                    VStack(spacing: 10) {
                        Text("Benvenuto!")
                            .font(.title2)
                        Text("Per giocare, dovrai scansionare un tavolo.")
                            .foregroundStyle(.secondary)
                    }
                    
                    Button(action: {
                        Task {
                            // APRE LO SPAZIO IMMERSIVO
                            let result = await openImmersiveSpace(id: "StackGameSpace")
                            if result == .opened {
                                immersiveSpaceIsShown = true
                            }
                        }
                    }) {
                        Text("Avvia Scansione Tavolo")
                            .font(.title)
                            .padding()
                            .frame(minWidth: 200)
                    }
                    .glassBackgroundEffect()
                    
                } else {
                    // MODO GIOCO ATTIVO
                    Text("Gioco in corso...")
                        .font(.title2)
                        .foregroundStyle(.green)
                    
                    Button(action: {
                        Task {
                            // CHIUDE LO SPAZIO IMMERSIVO
                            await dismissImmersiveSpace()
                            immersiveSpaceIsShown = false
                            
                            // Resetta lo stato del gioco quando esci
                            arManager.isGamePlaced = false
                            arManager.placementCursor.isEnabled = false
                        }
                    }) {
                        Text("Esci dal Gioco")
                            .font(.headline)
                            .padding()
                    }
                    .glassBackgroundEffect()
                }
            }
            .frame(width: 500, height: 400)
            .padding()
        }
        .windowStyle(.plain)

        // --- SPAZIO AR ---
        ImmersiveSpace(id: "StackGameSpace") {
            GameContainerView()
                .environment(arManager) // Passiamo il cervello
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
    }
}
