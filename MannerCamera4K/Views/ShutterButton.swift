import SwiftUI

struct ShutterButton: View {
    let mode: CameraMode
    let captureState: CaptureState
    let onTap: () -> Void

    var body: some View {
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
                // 条件分岐でView構造を変えず、同一Viewのプロパティで切り替え
                // これによりSwiftUIがview identityを維持し、タップが安定する
                RoundedRectangle(cornerRadius: captureState == .recording ? 8 : 30)
                    .fill(.red)
                    .frame(
                        width: captureState == .recording ? 30 : 60,
                        height: captureState == .recording ? 30 : 60
                    )
                    .animation(.easeInOut(duration: 0.15), value: captureState)
            }
        }
        .frame(width: 72, height: 72)
        .contentShape(Circle())
        .onTapGesture(perform: onTap)
    }
}
