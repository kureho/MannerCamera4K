import XCTest
@testable import MannerCamera4K

final class CameraModeTests: XCTestCase {
    func testDisplayNames() {
        XCTAssertEqual(CameraMode.photo.displayName, "写真")
        XCTAssertEqual(CameraMode.video.displayName, "ビデオ")
    }

    func testAllCases() {
        XCTAssertEqual(CameraMode.allCases.count, 2)
    }
}
