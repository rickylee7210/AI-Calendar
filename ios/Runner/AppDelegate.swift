import Flutter
import UIKit
import UserNotifications
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  var audioPlayer: AVAudioPlayer?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // 设置通知代理，允许前台显示通知
    UNUserNotificationCenter.current().delegate = self

    // 注册 MethodChannel
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(name: "com.example.ai_calendar/alarm", binaryMessenger: controller.binaryMessenger)
      channel.setMethodCallHandler { [weak self] (call, result) in
        switch call.method {
        case "scheduleNativeAlarm":
          guard let args = call.arguments as? [String: Any],
                let id = args["id"] as? Int,
                let triggerAtMillis = args["triggerAtMillis"] as? Int64,
                let title = args["title"] as? String,
                let body = args["body"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "Missing arguments", details: nil))
            return
          }
          self?.scheduleNotification(id: id, triggerAtMillis: triggerAtMillis, title: title, body: body)
          result(true)
        case "cancelNativeAlarm":
          guard let args = call.arguments as? [String: Any],
                let id = args["id"] as? Int else {
            result(FlutterError(code: "INVALID_ARGS", message: "Missing id", details: nil))
            return
          }
          UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["\(id)"])
          result(true)
        case "startAlarm":
          self?.playAlarmSound()
          result(true)
        case "stopAlarm":
          self?.stopAlarmSound()
          result(true)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  // 调度本地通知
  func scheduleNotification(id: Int, triggerAtMillis: Int64, title: String, body: String) {
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    content.sound = UNNotificationSound.defaultCritical
    content.categoryIdentifier = "ALARM"

    let triggerDate = Date(timeIntervalSince1970: Double(triggerAtMillis) / 1000.0)
    let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: triggerDate)
    let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

    let request = UNNotificationRequest(identifier: "\(id)", content: content, trigger: trigger)
    UNUserNotificationCenter.current().add(request) { error in
      if let error = error {
        print("[iOS Notification] 注册失败: \(error)")
      } else {
        print("[iOS Notification] 已注册: id=\(id), time=\(triggerDate)")
      }
    }
  }

  // 前台也显示通知
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    playAlarmSound()
    completionHandler([.banner, .sound, .badge])
  }

  // 点击通知时停止铃声
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    stopAlarmSound()
    completionHandler()
  }

  // 播放系统闹钟铃声
  func playAlarmSound() {
    guard let url = Bundle.main.url(forResource: "alarm", withExtension: "caf")
            ?? URL(string: "/System/Library/Audio/UISounds/alarm.caf") else {
      // 用系统默认铃声
      AudioServicesPlayAlertSound(SystemSoundID(1005))
      return
    }
    do {
      try AVAudioSession.sharedInstance().setCategory(.playback, options: [.mixWithOthers])
      try AVAudioSession.sharedInstance().setActive(true)
      audioPlayer = try AVAudioPlayer(contentsOf: url)
      audioPlayer?.numberOfLoops = -1 // 循环播放
      audioPlayer?.play()
    } catch {
      AudioServicesPlayAlertSound(SystemSoundID(1005))
    }
  }

  // 停止铃声
  func stopAlarmSound() {
    audioPlayer?.stop()
    audioPlayer = nil
  }
}
