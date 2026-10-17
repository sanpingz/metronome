import SwiftUI

@main
struct HoppyBeatApp: App {
    @State private var model = BeatModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .onChange(of: scenePhase) { _, phase in
                    model.scenePhaseChanged(phase)
                }
                #if DEBUG
                .task {
                    // Lets screenshots and UI checks start mid-song: `-autoplay YES`.
                    if UserDefaults.standard.bool(forKey: "autoplay") { model.start() }
                }
                #endif
        }
    }
}
