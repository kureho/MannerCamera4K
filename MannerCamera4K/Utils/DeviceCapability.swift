import AVFoundation

struct DeviceCapability {

    static func availableLenses(for position: AVCaptureDevice.Position = .back) -> [LensType] {
        LensType.allCases.filter { lens in
            AVCaptureDevice.default(lens.deviceType, for: .video, position: position) != nil
        }
    }

    static func device(for lens: LensType, position: AVCaptureDevice.Position = .back) -> AVCaptureDevice? {
        AVCaptureDevice.default(lens.deviceType, for: .video, position: position)
    }

    static func supports48MP() -> Bool {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            return false
        }
        return device.formats.contains { format in
            format.supportedMaxPhotoDimensions.contains { dim in
                dim.width >= 8064
            }
        }
    }

    static func maxPhotoDimensions(for device: AVCaptureDevice) -> CMVideoDimensions {
        var maxDim = CMVideoDimensions(width: 4032, height: 3024)
        for format in device.formats {
            for dim in format.supportedMaxPhotoDimensions {
                if Int(dim.width) * Int(dim.height) > Int(maxDim.width) * Int(maxDim.height) {
                    maxDim = dim
                }
            }
        }
        return maxDim
    }

    static func supportsShutterSuppression() -> Bool {
        if #available(iOS 18.0, *) {
            let output = AVCapturePhotoOutput()
            return output.isShutterSoundSuppressionSupported
        }
        return false
    }

    static func hasFrontCamera() -> Bool {
        AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) != nil
    }
}
