import AVFoundation

/// Plays the app's short UI sounds. Ambient category so background music wins,
/// and everything respects the Settings sound toggle.
@MainActor
enum SoundPlayer {
    enum Effect: String, CaseIterable {
        case success, miss, complete
    }

    private static var players: [Effect: AVAudioPlayer] = [:]
    private static var configured = false

    private static var enabled: Bool {
        UserDefaults.standard.object(forKey: "settings.sound") as? Bool ?? true
    }

    static func play(_ effect: Effect) {
        guard enabled else { return }
        if !configured {
            configured = true
            try? AVAudioSession.sharedInstance().setCategory(.ambient, options: .mixWithOthers)
            for effect in Effect.allCases {
                guard let url = Bundle.main.url(forResource: effect.rawValue, withExtension: "wav") else { continue }
                let player = try? AVAudioPlayer(contentsOf: url)
                player?.prepareToPlay()
                players[effect] = player
            }
        }
        guard let player = players[effect] else { return }
        player.currentTime = 0
        player.play()
    }
}
