import AppKit

/// The soft sound for a completed task.
enum CompletionSound {
    private static let sound: NSSound? = {
        let s = NSSound(named: "Tink")
        s?.volume = 0.35
        return s
    }()

    static func play() {
        guard Settings.soundEnabled, let sound else { return }
        if sound.isPlaying { sound.stop() }
        sound.play()
    }
}
