import SwiftUI
import RealityKit

struct GameContainerView: View {
    // CORREZIONE: Nuova sintassi per leggere oggetti @Observable dall'ambiente
    @Environment(ARManager.self) var arManager
    
    var body: some View {
        ZStack {
            // FASE 1: CERCA IL TAVOLO
            if !arManager.isGamePlaced {
                RealityView { content in
                    content.add(arManager.rootEntity)
                }
                .task { await arManager.startSession() }
                .task { await arManager.updatePlanes() }
                .task { await arManager.updateCursor() }
                
                .gesture(
                    SpatialTapGesture()
                        .targetedToAnyEntity()
                        .onEnded { _ in
                            arManager.placeGame()
                        }
                )
            }
            
            // FASE 2: GIOCA
            else {
                GameView(startingPosition: arManager.gamePosition)
            }
        }
    }
}
