import SwiftUI

@main
struct StackBuildingProjectApp: App {
    @State private var immersiveSpaceIsShown = false

    var body: some Scene {
        WindowGroup {
            ContentView(immersiveSpaceIsShown: $immersiveSpaceIsShown)
        }
        .windowStyle(.plain)

        ImmersiveSpace(id: "StackGameSpace") {
            GameView()
        }
    }
}
