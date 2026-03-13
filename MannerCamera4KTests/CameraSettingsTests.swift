import XCTest
@testable import MannerCamera4K

final class CameraSettingsTests: XCTestCase {
    var settings: CameraSettings!

    override func setUp() {
        super.setUp()
        settings = CameraSettings()
        // テスト前にUserDefaultsをクリア
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "photoFormat")
        defaults.removeObject(forKey: "videoResolution")
        defaults.removeObject(forKey: "photoResolution")
        defaults.removeObject(forKey: "recordAudio")
        defaults.removeObject(forKey: "hasShownMuteTip")
    }

    func testDefaults() {
        XCTAssertEqual(settings.photoFormat, .heif)
        XCTAssertEqual(settings.videoResolution, .fourK)
        XCTAssertEqual(settings.photoResolution, .high)
        XCTAssertEqual(settings.recordAudio, true)
        XCTAssertEqual(settings.hasShownMuteTip, false)
    }

    func testSetAndGet() {
        settings.photoFormat = .jpeg
        XCTAssertEqual(settings.photoFormat, .jpeg)

        settings.videoResolution = .fullHD
        XCTAssertEqual(settings.videoResolution, .fullHD)

        settings.recordAudio = false
        XCTAssertEqual(settings.recordAudio, false)
    }
}
