import SwiftUI

@main
struct SoundcorePullApp: App {
    @State private var syncer = Syncer(library: .iCloud)

    var body: some Scene {
        WindowGroup {
            ContentView(syncer: syncer)
                .frame(minWidth: 480, minHeight: 360)
        }
        .windowResizability(.contentSize)
    }
}
