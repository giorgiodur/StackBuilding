import SwiftUI
import RealityKit

struct ContentView: View {
    @Binding var immersiveSpaceIsShown: Bool
    @Environment(\.openImmersiveSpace) var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) var dismissImmersiveSpace

    var body: some View {
        VStack(spacing: 20) {
            Text("Stack Vision Pro")
                .font(.extraLargeTitle2)
                .fontWeight(.bold)
            
            Text("Trova un tavolo o il pavimento per giocare")
                .font(.body)
                .foregroundStyle(.secondary)
            
            Button(immersiveSpaceIsShown ? "Esci dal Gioco" : "Inizia Gioco") {
                Task {
                    if !immersiveSpaceIsShown {
                        await openImmersiveSpace(id: "StackGameSpace")
                        immersiveSpaceIsShown = true
                    } else {
                        await dismissImmersiveSpace()
                        immersiveSpaceIsShown = false
                    }
                }
            }
            .padding()
            .glassBackgroundEffect()
        }
        .padding()
    }
}
