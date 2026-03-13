import SwiftUI

@main
struct MannerCamera4KApp: App {
    var body: some Scene {
        WindowGroup {
            CameraView()
                .preferredColorScheme(.dark)
                .persistentSystemOverlays(.hidden)
        }
    }
}
