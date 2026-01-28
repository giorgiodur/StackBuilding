import SwiftUI
import RealityKit

@main
struct StackBuildingProjectApp: App {
    // 1. Inizializziamo il "Cervello" AR
    // Usiamo @State perché ARManager è una classe @Observable (sintassi moderna)
    @State private var arManager = ARManager()
    
    // 2. Stato per sapere se siamo in modalità AR o no
    @State private var immersiveSpaceIsShown = false
    
    // 3. Comandi di sistema
    @Environment(\.openImmersiveSpace) var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) var dismissImmersiveSpace

    // Specifichiamo SwiftUI.Scene per evitare conflitti con altri tipi di "Scene"
    var body: some SwiftUI.Scene {
        
        // --- FINESTRA 2D (MENU PRINCIPALE) ---
        WindowGroup {
            VStack(spacing: 25) {
                // MODIFICA: Titolo aggiornato a "Spatial Stack"
                Text("Spatial Stack")
                    .font(.extraLargeTitle)
                    .fontWeight(.bold)
                
                if !immersiveSpaceIsShown {
                    // MODO MENU
                    VStack(spacing: 10) {
                        Text("Welcome!")
                            .font(.title2)
                        Text("Please scan a table to start playing.")
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
                        Text("Start Table Scan")
                            .font(.title)
                            .padding()
                            .frame(minWidth: 200)
                    }
                    .glassBackgroundEffect()
                    
                } else {
                    // MODO GIOCO ATTIVO
                    Text("Game in progress...")
                        .font(.title2)
                        .foregroundStyle(.green)
                    
                    Button(action: {
                        Task {
                            // CHIUDE LO SPAZIO IMMERSIVO
                            await dismissImmersiveSpace()
                            immersiveSpaceIsShown = false
                            
                            // Resetta lo stato del gioco quando esci
                            // (Funziona perché abbiamo importato RealityKit)
                            arManager.isGamePlaced = false
                            arManager.placementCursor.isEnabled = false
                        }
                    }) {
                        Text("Exit Game")
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
