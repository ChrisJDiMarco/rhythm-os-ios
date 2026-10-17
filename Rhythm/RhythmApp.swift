import SwiftUI

@main
struct RhythmApp: App {
    @StateObject private var store = RhythmStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .preferredColorScheme(.dark)
        }
    }
}
