import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

private let accent = Color(red: 0.976, green: 0.451, blue: 0.086)
private let surface = Color(red: 0.078, green: 0.078, blue: 0.078)

struct SiftProgressLine: View {
    let state: SiftActivityAttributes.ContentState

    var progress: Double {
        guard state.totalSeconds > 0 else { return 0 }
        let elapsed = Double(state.totalSeconds - state.remainingSeconds)
        return min(max(elapsed / Double(state.totalSeconds), 0), 1.0)
    }

    var phaseTimeRange: ClosedRange<Date> {
        let duration = TimeInterval(max(state.totalSeconds, 1))
        return state.phaseEndTime.addingTimeInterval(-duration)...state.phaseEndTime
    }

    var body: some View {
        if state.isPaused || state.alarmPlaying {
            ProgressView(value: progress)
                .progressViewStyle(LinearProgressViewStyle(tint: accent))
        } else {
            ProgressView(timerInterval: phaseTimeRange, countsDown: false)
                .progressViewStyle(LinearProgressViewStyle(tint: accent))
        }
    }
}

struct SiftLockScreenView: View {
    let context: ActivityViewContext<SiftActivityAttributes>

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 16) {
                Image(systemName: context.state.isBreak ? "cup.and.saucer.fill" : "laptopcomputer")
                    .font(.title2)
                    .foregroundColor(accent)

                VStack(alignment: .leading, spacing: 4) {
                    Text(context.state.phaseName)
                        .font(.headline)
                        .foregroundColor(.white)

                    if context.state.isPaused {
                        Text("Paused")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    } else {
                        Text(timerInterval: Date.now...context.state.phaseEndTime, countsDown: true)
                            .font(.subheadline)
                            .monospacedDigit()
                            .foregroundColor(accent)
                    }
                }

                Spacer()
            }

            SiftProgressLine(state: context.state)
                .tint(accent)

            HStack(spacing: 12) {
                if context.state.alarmPlaying {
                    Button(intent: SilenceAlarmIntent()) {
                        Label("Silence", systemImage: "bell.slash.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.orange.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }

                Button(intent: StopTimerIntent()) {
                    Label("Stop", systemImage: "stop.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.red.opacity(0.25), in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(surface)
    }
}

@available(iOSApplicationExtension 16.2, *)
struct SiftWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SiftActivityAttributes.self) { context in
            SiftLockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 8) {
                        Image(systemName: context.state.isBreak ? "cup.and.saucer.fill" : "laptopcomputer")
                            .foregroundColor(accent)
                        Text(context.state.phaseName)
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if context.state.isPaused {
                        Text("Paused")
                            .foregroundColor(.gray)
                            .padding(.trailing, 4)
                    } else {
                        Text(timerInterval: Date.now...context.state.phaseEndTime, countsDown: true)
                            .monospacedDigit()
                            .foregroundColor(accent)
                            .padding(.trailing, 4)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 8) {
                        SiftProgressLine(state: context.state)
                            .tint(accent)
                            .padding(.horizontal, 4)

                        HStack(spacing: 10) {
                            if context.state.alarmPlaying {
                                Button(intent: SilenceAlarmIntent()) {
                                    Image(systemName: "bell.slash.fill")
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 6)
                                        .background(Color.orange.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
                                }
                                .buttonStyle(.plain)
                            }

                            Button(intent: StopTimerIntent()) {
                                Image(systemName: "stop.fill")
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 6)
                                    .background(Color.red.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 4)
                    }
                }
            } compactLeading: {
                Image(systemName: context.state.isBreak ? "cup.and.saucer.fill" : "laptopcomputer")
                    .foregroundColor(context.state.alarmPlaying ? .orange : accent)
            } compactTrailing: {
                if context.state.alarmPlaying {
                    Image(systemName: "bell.fill")
                        .foregroundColor(.orange)
                } else if context.state.isPaused {
                    Image(systemName: "pause.fill")
                        .foregroundColor(.gray)
                } else {
                    Text(timerInterval: Date.now...context.state.phaseEndTime, countsDown: true)
                        .monospacedDigit()
                        .foregroundColor(accent)
                        .frame(width: 60)
                }
            } minimal: {
                Image(systemName: context.state.alarmPlaying ? "bell.fill" : (context.state.isBreak ? "cup.and.saucer.fill" : "laptopcomputer"))
                    .foregroundColor(context.state.alarmPlaying ? .orange : accent)
            }
        }
    }
}
