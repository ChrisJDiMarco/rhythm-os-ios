import SwiftUI

@main
struct RhythmApp: App {
    @StateObject private var store = RhythmStore()

    var body: some Scene {
        WindowGroup {
            ZStack {
                RhythmColor.bgDeep
                    .ignoresSafeArea()

                ContentView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
                .environmentObject(store)
                .preferredColorScheme(.dark)
        }
    }
}
