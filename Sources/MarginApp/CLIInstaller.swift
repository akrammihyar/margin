import Foundation
import MarginCore

/// Puts a link to the `margin` command in the shell path.
enum CLIInstaller {
    struct InstallError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    /// The command inside the app bundle.
    static var helperURL: URL {
        Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/\(AppInfo.cliName)")
    }

    private static var candidates: [URL] {
        [URL(fileURLWithPath: "/usr/local/bin"),
         FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".local/bin")]
    }

    /// An existing link that points at the command in this app.
    static func installedLocation() -> URL? {
        for dir in candidates {
            let link = dir.appendingPathComponent(AppInfo.cliName)
            if let target = try? FileManager.default.destinationOfSymbolicLink(atPath: link.path), target == helperURL.path {
                return link
            }
        }
        return nil
    }

    /// Links into `/usr/local/bin` when it can be written, else into `~/.local/bin`.
    /// Replaces an old link. Never replaces a regular file.
    static func install() throws -> URL {
        let fm = FileManager.default
        guard fm.fileExists(atPath: helperURL.path) else {
            throw InstallError(message: "The command is not in this app bundle. Build the app with scripts/build-app.sh.")
        }
        var lastError = "No folder to install into."
        for dir in candidates {
            let isHome = dir.path.hasPrefix(fm.homeDirectoryForCurrentUser.path)
            if isHome { try? fm.createDirectory(at: dir, withIntermediateDirectories: true) }
            guard fm.isWritableFile(atPath: dir.path) else { continue }
            let link = dir.appendingPathComponent(AppInfo.cliName)
            if (try? fm.destinationOfSymbolicLink(atPath: link.path)) != nil {
                try fm.removeItem(at: link)
            } else if fm.fileExists(atPath: link.path) {
                lastError = "\(link.path) exists and is not a link. It was not changed."
                continue
            }
            try fm.createSymbolicLink(at: link, withDestinationURL: helperURL)
            return link
        }
        throw InstallError(message: lastError)
    }

    static func pathContains(_ dir: URL) -> Bool {
        (ProcessInfo.processInfo.environment["PATH"] ?? "").split(separator: ":").contains { $0 == dir.path }
    }
}
