import WidgetKit
import SwiftUI

struct SiftWidget: Widget {
    let kind: String = "SiftWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SiftTimelineProvider()) { _ in
            EmptyView()
        }
        .configurationDisplayName("Sift")
        .description("Work session timer.")
        .supportedFamilies([])
    }
}

struct SiftTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> SiftEntry { SiftEntry(date: Date()) }
    func getSnapshot(in context: Context, completion: @escaping (SiftEntry) -> Void) { completion(SiftEntry(date: Date())) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<SiftEntry>) -> Void) {
        completion(Timeline(entries: [SiftEntry(date: Date())], policy: .never))
    }
}

struct SiftEntry: TimelineEntry { let date: Date }
