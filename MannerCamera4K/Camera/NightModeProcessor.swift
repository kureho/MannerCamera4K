import AVFoundation
import CoreImage
import ImageIO
import UIKit

final class NightModeProcessor {

    private let context = CIContext()

    func configureDevice(_ device: AVCaptureDevice) {
        do {
            try device.lockForConfiguration()

            if device.isLowLightBoostSupported {
                device.automaticallyEnablesLowLightBoostWhenAvailable = true
            }

            let maxExposure = min(
                CMTimeMakeWithSeconds(1.0 / 3.0, preferredTimescale: 1000),
                device.activeFormat.maxExposureDuration
            )
            let targetISO = min(device.activeFormat.maxISO, 1600)

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

    func processImage(_ imageData: Data) -> Data? {
        guard let ciImage = CIImage(data: imageData) else { return nil }

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

        guard let cgImage = context.createCGImage(processed, from: processed.extent) else {
            return nil
        }
        let uiImage = UIImage(cgImage: cgImage)
        return uiImage.heicData() ?? uiImage.jpegData(compressionQuality: 0.95)
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
