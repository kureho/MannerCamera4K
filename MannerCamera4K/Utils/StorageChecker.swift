import Foundation

struct StorageChecker {
    private static let minimumRequired: Int64 = 100 * 1024 * 1024 // 100MB

    static func hasEnoughStorage() -> Bool {
        guard let attrs = try? FileManager.default.attributesOfFileSystem(
            forPath: NSHomeDirectory()
        ),
        let freeSize = attrs[.systemFreeSize] as? Int64 else {
            return true
        }
        return freeSize >= minimumRequired
    }
}
