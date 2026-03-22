import ActivityKit
import Foundation

struct SiftActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var phaseName: String
        var phaseEndTime: Date
        var isPaused: Bool
        var remainingSeconds: Int
        var totalSeconds: Int
        var isBreak: Bool
        var alarmPlaying: Bool
    }
}
