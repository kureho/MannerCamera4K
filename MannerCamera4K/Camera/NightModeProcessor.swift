import AVFoundation
import CoreImage
import ImageIO
import UIKit

final class NightModeProcessor {

    func configureDevice(_ device: AVCaptureDevice) {
        do {
            try device.lockForConfiguration()

            if device.isLowLightBoostSupported {
                device.automaticallyEnablesLowLightBoostWhenAvailable = true
            }

            // 1/15秒で15fps維持（1/3秒だと3fpsでカクつく）
            let maxExposure = min(
                CMTimeMakeWithSeconds(1.0 / 15.0, preferredTimescale: 1000),
                device.activeFormat.maxExposureDuration
            )
            // 露出時間を短くした分、ISOを上げて明るさを補う
            let targetISO = min(device.activeFormat.maxISO, 3200)

            device.setExposureModeCustom(
                duration: maxExposure,
                iso: targetISO
            )

            device.unlockForConfiguration()
        } catch {
            print("Night mode device config error: \(error)")
        }
    }

    func resetDevice(_ device: AVCaptureDevice) {
        do {
            try device.lockForConfiguration()
            device.exposureMode = .continuousAutoExposure
            device.unlockForConfiguration()
        } catch {
            print("Night mode reset error: \(error)")
        }
    }

    /// CIImage を直接受け取ってフィルタ適用（エンコード/デコードの往復を省略）
    func processCIImage(_ ciImage: CIImage) -> CIImage {
        var processed = ciImage

        if let noiseReduction = CIFilter(name: "CINoiseReduction") {
            noiseReduction.setValue(processed, forKey: kCIInputImageKey)
            noiseReduction.setValue(0.02, forKey: "inputNoiseLevel")
            noiseReduction.setValue(0.40, forKey: "inputSharpness")
            if let output = noiseReduction.outputImage {
                processed = output
            }
        }

        if let exposureAdjust = CIFilter(name: "CIExposureAdjust") {
            exposureAdjust.setValue(processed, forKey: kCIInputImageKey)
            exposureAdjust.setValue(0.5, forKey: kCIInputEVKey)
            if let output = exposureAdjust.outputImage {
                processed = output
            }
        }

        if let colorControls = CIFilter(name: "CIColorControls") {
            colorControls.setValue(processed, forKey: kCIInputImageKey)
            colorControls.setValue(1.1, forKey: kCIInputContrastKey)
            colorControls.setValue(1.05, forKey: kCIInputSaturationKey)
            if let output = colorControls.outputImage {
                processed = output
            }
        }

        return processed
    }
}

extension UIImage {
    func heicData(compressionQuality: CGFloat = 0.9) -> Data? {
        guard let cgImage = self.cgImage else { return nil }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, "public.heic" as CFString, 1, nil) else {
            return nil
        }
        let options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: compressionQuality
        ]
        CGImageDestinationAddImage(destination, cgImage, options as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }
}
