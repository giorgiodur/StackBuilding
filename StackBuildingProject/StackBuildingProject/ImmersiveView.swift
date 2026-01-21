import SwiftUI
import RealityKit

struct ImmersiveView: View {
    // Inizializziamo il manager qui
    @State private var arManager = ARManager()
    
    var body: some View {
        ZStack {
            // 1. IL MONDO AR (Scansione + Cursore)
            // Visibile sempre per mantenere il tracking, ma il cursore sparisce quando piazzato
            RealityView { content in
                content.add(arManager.rootEntity)
            }
            .task {
                await arManager.startSession()
            }
            .task {
                await arManager.updatePlanes()
            }
            .task {
                await arManager.updateCursor()
            }
            // Gestore Tap per PIAZZARE il gioco
            .gesture(SpatialTapGesture().onEnded { _ in
                if !arManager.isGamePlaced {
                    arManager.placeGame()
                }
            })
            
            // 2. IL GIOCO (Appare solo dopo il piazzamento)
            if arManager.isGamePlaced {
                GameView(startingPosition: arManager.gamePosition)
            }
        }
    }
}
