import Foundation
import ActivityKit

/// Manages the sleep-session Live Activity (lock screen / Dynamic Island).
///
/// Deliberately NOT main-actor isolated: ActivityKit's `Activity` isn't treated
/// as `Sendable` by this toolchain, so every call to it must stay in a single
/// nonisolated context — otherwise awaiting it from the main actor trips
/// "sending risks data races". The one `activity` handle is only touched here,
/// and the view model issues these calls serially.
final class SessionLiveActivity: @unchecked Sendable {

    nonisolated(unsafe) private var activity: Activity<SoundStageSessionAttributes>?

    func start(state: BinauralState, startDate: Date, endDate: Date?, isPlaying: Bool) {
        guard activity == nil else { return }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let content = ActivityContent(
            state: makeState(state, startDate: startDate, endDate: endDate, isPlaying: isPlaying),
            staleDate: endDate
        )
        activity = try? Activity.request(
            attributes: SoundStageSessionAttributes(title: "Sleep session"),
            content: content
        )
    }

    func update(state: BinauralState, startDate: Date, endDate: Date?, isPlaying: Bool) async {
        guard let activity else { return }
        let content = ActivityContent(
            state: makeState(state, startDate: startDate, endDate: endDate, isPlaying: isPlaying),
            staleDate: endDate
        )
        await activity.update(content)
    }

    func end() async {
        guard let activity else { return }
        self.activity = nil
        await activity.end(ActivityContent(state: activity.content.state, staleDate: nil), dismissalPolicy: .immediate)
    }

    private func makeState(_ state: BinauralState, startDate: Date, endDate: Date?, isPlaying: Bool) -> SoundStageSessionAttributes.ContentState {
        let hz = state.beatHz.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(state.beatHz))" : String(format: "%.1f", state.beatHz)
        return .init(
            stateName: state.name,
            bandHz: "\(state.band.uppercased()) · \(hz) Hz",
            fromHex: state.fromHex,
            toHex: state.toHex,
            startDate: startDate,
            endDate: endDate,
            isPlaying: isPlaying
        )
    }
}
