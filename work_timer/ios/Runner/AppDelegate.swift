import Flutter
import UIKit
import ActivityKit
import UniformTypeIdentifiers
import AVFoundation

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

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate, UIDocumentPickerDelegate {

  private var liveActivityID: String?
  private var filePickResult: FlutterResult?
  private var timerActionChannel: FlutterMethodChannel?

  // Silent keep-alive loop — keeps app alive in background while timer runs
  private let audioEngine = AVAudioEngine()
  private let silentNode = AVAudioPlayerNode()
  private var timerAudioActive = false

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // .playback category bypasses the silent switch so alarms always make noise
    try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
    try? AVAudioSession.sharedInstance().setActive(true)
    // Copy alarm.mp3 from flutter_assets into Library/Sounds so local notifications
    // can reference it by name ("alarm.mp3") regardless of flutter asset bundling path.
    copyAlarmSoundToLibrary()
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleAudioInterruption(_:)),
      name: AVAudioSession.interruptionNotification,
      object: AVAudioSession.sharedInstance()
    )
    // Restart engine when audio route changes (AirPods disconnect, headphones pulled, etc.)
    // Without this, AVAudioEngine silently stops and the timer keeps no background execution.
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleAudioRouteChange(_:)),
      name: AVAudioSession.routeChangeNotification,
      object: AVAudioSession.sharedInstance()
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleEngineConfigChange),
      name: .AVAudioEngineConfigurationChange,
      object: audioEngine
    )
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Restart silent keep-alive loop after phone calls / Siri / other audio interruptions
  @objc private func handleAudioInterruption(_ notification: Notification) {
    guard let userInfo = notification.userInfo,
          let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
          let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }
    if type == .ended {
      restartAudioEngineIfNeeded()
    }
  }

  // Restart engine after route changes — pulling headphones out triggers a route change that
  // stops AVAudioEngine. Without this, the silent keep-alive loop dies and iOS suspends the app.
  @objc private func handleAudioRouteChange(_ notification: Notification) {
    guard let userInfo = notification.userInfo,
          let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
          let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else { return }
    switch reason {
    case .oldDeviceUnavailable, .newDeviceAvailable, .categoryChange:
      restartAudioEngineIfNeeded()
    default:
      break
    }
  }

  // AVAudioEngineConfigurationChange fires when the hardware graph changes (e.g. sample rate
  // changes, output device removed). The engine must be restarted; it does not auto-recover.
  @objc private func handleEngineConfigChange() {
    restartAudioEngineIfNeeded()
  }

  private func restartAudioEngineIfNeeded() {
    guard timerAudioActive else { return }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
      guard let self = self else { return }
      try? AVAudioSession.sharedInstance().setActive(true)
      if !self.audioEngine.isRunning {
        try? self.audioEngine.start()
      }
      self.silentNode.play()
    }
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    setupChannel(registry: engineBridge.pluginRegistry)
    registerDarwinObservers()
  }

  private func topViewController() -> UIViewController? {
    let scene = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .first { $0.activationState == .foregroundActive }
    let window = scene?.windows.first { $0.isKeyWindow } ?? scene?.windows.first
    var top = window?.rootViewController
    while let presented = top?.presentedViewController {
      top = presented
    }
    return top
  }

  private func registerDarwinObservers() {
    let notifications = ["com.sift.timer.stop", "com.sift.timer.silence"]
    for notifName in notifications {
      CFNotificationCenterAddObserver(
        CFNotificationCenterGetDarwinNotifyCenter(),
        Unmanaged.passUnretained(self).toOpaque(),
        { (_, observer, name, _, _) in
          guard let observer = observer, let name = name else { return }
          let selfRef = Unmanaged<AppDelegate>.fromOpaque(observer).takeUnretainedValue()
          let action = (name.rawValue as String).components(separatedBy: ".").last ?? ""
          DispatchQueue.main.async {
            selfRef.timerActionChannel?.invokeMethod("onTimerAction", arguments: action)
          }
        },
        notifName as CFString,
        nil,
        .deliverImmediately
      )
    }
  }

  private func setupChannel(registry: FlutterPluginRegistry) {
    guard let registrar = registry.registrar(forPlugin: "SiftChannel") else { return }
    let messenger = registrar.messenger()
    timerActionChannel = FlutterMethodChannel(
      name: "com.sift.timer_action",
      binaryMessenger: messenger
    )
    let channel = FlutterMethodChannel(
      name: "com.sift.live_activity",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { return }
      switch call.method {
      case "pickAudioFile":
        self.pickAudioFile(result: result)
      case "startTimerAudio":
        self.startTimerAudio()
        result(nil)
      case "stopTimerAudio":
        self.stopTimerAudio()
        result(nil)
      default:
        if #available(iOS 16.2, *) {
          switch call.method {
          case "startLiveActivity":
            self.startLiveActivity(args: call.arguments, result: result)
          case "updateLiveActivity":
            self.updateLiveActivity(args: call.arguments, result: result)
          case "endLiveActivity":
            self.endLiveActivity(result: result)
          default:
            result(FlutterMethodNotImplemented)
          }
        } else {
          result(nil)
        }
      }
    }
  }

  // MARK: - Alarm Sound Setup

  private func copyAlarmSoundToLibrary() {
    let fm = FileManager.default
    // Flutter bundles assets at flutter_assets/<path> inside the main bundle
    guard let srcURL = Bundle.main.url(
      forResource: "alarm", withExtension: "caf",
      subdirectory: "flutter_assets/assets"
    ) else { return }
    guard let libURL = fm.urls(for: .libraryDirectory, in: .userDomainMask).first else { return }
    let soundsURL = libURL.appendingPathComponent("Sounds")
    try? fm.createDirectory(at: soundsURL, withIntermediateDirectories: true, attributes: nil)
    let destURL = soundsURL.appendingPathComponent("alarm.caf")
    // Overwrite if source is newer (handles app updates with changed sound file)
    let srcDate = (try? fm.attributesOfItem(atPath: srcURL.path))?[.modificationDate] as? Date
    let destDate = (try? fm.attributesOfItem(atPath: destURL.path))?[.modificationDate] as? Date
    if destDate == nil || srcDate.map({ $0 > destDate! }) == true {
      try? fm.removeItem(at: destURL)
      try? fm.copyItem(at: srcURL, to: destURL)
    }
  }

  private func startTimerAudio() {
    timerAudioActive = true
    guard !audioEngine.isRunning else { return }
    // Build a 0.5s silent buffer and loop it — keeps app alive in background
    // so Timer.periodic keeps firing and the alarm can play even on silent
    let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
    audioEngine.attach(silentNode)
    audioEngine.connect(silentNode, to: audioEngine.mainMixerNode, format: format)
    audioEngine.mainMixerNode.outputVolume = 1.0
    let frameCount: AVAudioFrameCount = 22050 // 0.5 seconds
    guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }
    buffer.frameLength = frameCount
    // Buffer is zero-initialised — perfectly silent
    silentNode.scheduleBuffer(buffer, at: nil, options: .loops)
    try? AVAudioSession.sharedInstance().setActive(true)
    try? audioEngine.start()
    silentNode.play()
  }

  private func stopTimerAudio() {
    timerAudioActive = false
    silentNode.stop()
    audioEngine.stop()
  }

  private func pickAudioFile(result: @escaping FlutterResult) {
    filePickResult = result
    if #available(iOS 14.0, *) {
      let types: [UTType] = [.audio, .mp3, .wav,
                             UTType("public.aiff-audio"),
                             UTType("public.mpeg-4-audio"),
                             UTType("public.aac-audio")].compactMap { $0 }
      let picker = UIDocumentPickerViewController(forOpeningContentTypes: types)
      picker.delegate = self
      picker.allowsMultipleSelection = false
      topViewController()?.present(picker, animated: true)
    } else {
      result(nil)
      filePickResult = nil
    }
  }

  // MARK: - UIDocumentPickerDelegate

  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    guard let url = urls.first else {
      filePickResult?(nil)
      filePickResult = nil
      return
    }
    // Copy to app's Documents directory so the path persists across launches
    let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    let dest = docs.appendingPathComponent("custom_ringtone_\(url.lastPathComponent)")
    try? FileManager.default.removeItem(at: dest)
    do {
      // Request access for security-scoped resource
      let accessing = url.startAccessingSecurityScopedResource()
      defer { if accessing { url.stopAccessingSecurityScopedResource() } }
      try FileManager.default.copyItem(at: url, to: dest)
      filePickResult?(dest.path)
    } catch {
      filePickResult?(FlutterError(code: "COPY_FAILED", message: error.localizedDescription, details: nil))
    }
    filePickResult = nil
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    filePickResult?(nil)
    filePickResult = nil
  }

  // MARK: - Live Activity

  @available(iOS 16.2, *)
  private func startLiveActivity(args: Any?, result: @escaping FlutterResult) {
    let authInfo = ActivityAuthorizationInfo()
    guard authInfo.areActivitiesEnabled else {
      result(FlutterError(code: "NOT_AUTHORIZED",
                          message: "Live Activities disabled — go to Settings → Sift → Live Activities and turn it on.",
                          details: nil))
      return
    }

    guard let map = args as? [String: Any],
          let phaseName = map["phaseName"] as? String,
          let phaseEndMs = map["phaseEndMs"] as? Double,
          let remainingSeconds = map["remainingSeconds"] as? Int,
          let totalSeconds = map["totalSeconds"] as? Int,
          let isBreak = map["isBreak"] as? Bool else {
      result(FlutterError(code: "INVALID_ARGS", message: "Missing args", details: nil))
      return
    }

    // End existing activities synchronously before starting new one
    Task {
      for activity in Activity<SiftActivityAttributes>.activities {
        await activity.end(nil, dismissalPolicy: .immediate)
      }

      let phaseEndTime = Date(timeIntervalSince1970: phaseEndMs / 1000.0)
      let state = SiftActivityAttributes.ContentState(
        phaseName: phaseName,
        phaseEndTime: phaseEndTime,
        isPaused: false,
        remainingSeconds: remainingSeconds,
        totalSeconds: totalSeconds,
        isBreak: isBreak,
        alarmPlaying: false
      )
      let attributes = SiftActivityAttributes()
      do {
        let activity = try Activity.request(
          attributes: attributes,
          content: .init(state: state, staleDate: nil)
        )
        self.liveActivityID = activity.id
        result(nil)
      } catch {
        result(FlutterError(code: "START_FAILED", message: error.localizedDescription, details: nil))
      }
    }
  }

  @available(iOS 16.2, *)
  private func updateLiveActivity(args: Any?, result: FlutterResult) {
    guard let map = args as? [String: Any],
          let phaseName = map["phaseName"] as? String,
          let phaseEndMs = map["phaseEndMs"] as? Double,
          let remainingSeconds = map["remainingSeconds"] as? Int,
          let totalSeconds = map["totalSeconds"] as? Int,
          let isBreak = map["isBreak"] as? Bool,
          let isPaused = map["isPaused"] as? Bool,
          let id = liveActivityID else {
      result(nil)
      return
    }
    let alarmPlaying = map["alarmPlaying"] as? Bool ?? false

    let phaseEndTime = Date(timeIntervalSince1970: phaseEndMs / 1000.0)
    let state = SiftActivityAttributes.ContentState(
      phaseName: phaseName,
      phaseEndTime: phaseEndTime,
      isPaused: isPaused,
      remainingSeconds: remainingSeconds,
      totalSeconds: totalSeconds,
      isBreak: isBreak,
      alarmPlaying: alarmPlaying
    )

    Task {
      for activity in Activity<SiftActivityAttributes>.activities where activity.id == id {
        await activity.update(.init(state: state, staleDate: nil))
      }
    }
    result(nil)
  }

  @available(iOS 16.2, *)
  private func endLiveActivity(result: FlutterResult) {
    endAllActivities()
    liveActivityID = nil
    result(nil)
  }

  @available(iOS 16.2, *)
  private func endAllActivities() {
    Task {
      for activity in Activity<SiftActivityAttributes>.activities {
        await activity.end(nil, dismissalPolicy: .immediate)
      }
    }
  }
}
