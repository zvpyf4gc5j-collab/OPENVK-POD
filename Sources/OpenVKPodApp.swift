import SwiftUI

@main
struct OpenVKPodApp: App {
    @StateObject private var player: Player
    @StateObject private var pod: Pod

    init() {
        let p = Player()
        _player = StateObject(wrappedValue: p)
        _pod = StateObject(wrappedValue: Pod(player: p))
    }

    var body: some Scene {
        WindowGroup {
            PodView()
                .environmentObject(player)
                .environmentObject(pod)
                .preferredColorScheme(.dark)
        }
    }
}
