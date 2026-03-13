import SwiftUI

struct ShutterButton: View {
    let mode: CameraMode
    let captureState: CaptureState
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                Circle()
                    .stroke(.white, lineWidth: 4)
                    .frame(width: 72, height: 72)

                switch mode {
                case .photo:
                    Circle()
                        .fill(.white)
                        .frame(width: 60, height: 60)
                        .scaleEffect(captureState == .capturing ? 0.85 : 1.0)
                        .animation(.easeInOut(duration: 0.1), value: captureState)

                case .video:
                    if captureState == .recording {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.red)
                            .frame(width: 30, height: 30)
                    } else {
                        Circle()
                            .fill(.red)
                            .frame(width: 60, height: 60)
                    }
                }
            }
            .frame(width: 72, height: 72)
        }
        .frame(width: 72, height: 72)
    }
}
