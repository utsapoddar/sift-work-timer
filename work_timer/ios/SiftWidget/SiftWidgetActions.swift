import AppIntents
import Foundation

struct StopTimerIntent: AppIntent {
    static let title: LocalizedStringResource = "Stop Timer"
    static let isDiscoverable: Bool = false

    func perform() async throws -> some IntentResult {
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName("com.sift.timer.stop" as CFString),
            nil, nil, true
        )
        return .result()
    }
}

struct SilenceAlarmIntent: AppIntent {
    static let title: LocalizedStringResource = "Silence Alarm"
    static let isDiscoverable: Bool = false

    func perform() async throws -> some IntentResult {
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName("com.sift.timer.silence" as CFString),
            nil, nil, true
        )
        return .result()
    }
}
