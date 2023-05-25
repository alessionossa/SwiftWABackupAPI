
import Foundation

public struct WABackupAPI {
    public static let defaultBackupPath = "~/Library/Application Support/MobileSync/Backup/"

    public static func hasLocalBackup() -> Bool {
        let fileManager = FileManager.default
        let backupPath = NSString(string: defaultBackupPath).expandingTildeInPath
        return fileManager.fileExists(atPath: backupPath)
    }

    public init() {}
}
