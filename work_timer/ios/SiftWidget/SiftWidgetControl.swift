import AppIntents
import SwiftUI
import WidgetKit

@available(iOSApplicationExtension 18.0, *)
struct SiftWidgetControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.example.workTimer.SiftWidgetControl") {
            ControlWidgetButton(action: SiftWidgetControlIntent()) {
                Label("Sift", systemImage: "laptopcomputer")
            }
        }
    }
}

@available(iOS 18.0, *)
struct SiftWidgetControlIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Sift"
    func perform() async throws -> some IntentResult { .result() }
}
