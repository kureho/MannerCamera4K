import XCTest
import AVFoundation
@testable import MannerCamera4K

final class LensTypeTests: XCTestCase {
    func testDisplayNames() {
        XCTAssertEqual(LensType.ultraWide.displayName, "0.5x")
        XCTAssertEqual(LensType.wide.displayName, "1x")
        XCTAssertEqual(LensType.telephoto.displayName, "3x")
    }

    func testDeviceTypes() {
        XCTAssertEqual(LensType.ultraWide.deviceType, .builtInUltraWideCamera)
        XCTAssertEqual(LensType.wide.deviceType, .builtInWideAngleCamera)
        XCTAssertEqual(LensType.telephoto.deviceType, .builtInTelephotoCamera)
    }
}
