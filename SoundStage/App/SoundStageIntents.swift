import AppIntents

/// The mental states, exposed to Siri / Shortcuts as a pickable parameter.
enum StatePick: String, AppEnum {
    case sleep, relax, meditate, focus, flow, energy, sharp

    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Mental State" }
    static var caseDisplayRepresentations: [StatePick: DisplayRepresentation] {
        [
            .sleep: "Deep Sleep", .relax: "Relax", .meditate: "Meditate",
            .focus: "Focus", .flow: "Flow", .energy: "Energy", .sharp: "Sharp"
        ]
    }
}

/// "Hey Siri, start Deep Sleep in SoundStage." Opens the app and begins the
/// chosen state.
struct StartStateIntent: AppIntent {
    static var title: LocalizedStringResource { "Start a SoundStage Session" }
    static var description: IntentDescription { "Begin binaural playback for a chosen state." }
    static var openAppWhenRun: Bool { true }

    @Parameter(title: "State", default: .focus)
    var state: StatePick

    @MainActor
    func perform() async throws -> some IntentResult {
        let vm = BinauralViewModel.shared
        if let target = vm.states.first(where: { $0.id == state.rawValue }) {
            vm.select(target)
        }
        vm.setPlaying(true)
        return .result()
    }
}

/// Resumes playback with the current settings.
struct PlayIntent: AppIntent {
    static var title: LocalizedStringResource { "Play SoundStage" }
    static var openAppWhenRun: Bool { true }

    @MainActor
    func perform() async throws -> some IntentResult {
        BinauralViewModel.shared.setPlaying(true)
        return .result()
    }
}

/// Zero-setup Siri phrases (no Shortcuts app required).
struct SoundStageShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartStateIntent(),
            phrases: [
                "Start a session in \(.applicationName)",
                "Start \(\.$state) in \(.applicationName)",
                "Begin \(\.$state) with \(.applicationName)"
            ],
            shortTitle: "Start Session",
            systemImageName: "play.fill"
        )
        AppShortcut(
            intent: PlayIntent(),
            phrases: ["Play \(.applicationName)"],
            shortTitle: "Play",
            systemImageName: "play.circle.fill"
        )
    }
}
