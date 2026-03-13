import XCTest
import AVFoundation
@testable import MannerCamera4K

final class DeviceCapabilityTests: XCTestCase {
    func testAvailableLensesDoesNotCrash() {
        let lenses = DeviceCapability.availableLenses()
        XCTAssertNotNil(lenses)
    }

    func testSupports48MPDoesNotCrash() {
        let result = DeviceCapability.supports48MP()
        XCTAssertFalse(result)
    }

    func testHasFrontCameraDoesNotCrash() {
        _ = DeviceCapability.hasFrontCamera()
    }
}
