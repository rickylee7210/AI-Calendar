import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;
import '../models/calendar_item.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const _alarmChannel = MethodChannel('com.example.ai_calendar/alarm');

  /// 启动原生闹钟铃声（持续响铃+振动）
  Future<void> startAlarmSound() async {
    try {
      await _alarmChannel.invokeMethod('startAlarm');
    } catch (e) {
      debugPrint('[Alarm] 启动铃声失败: $e');
    }
  }

  /// 停止原生闹钟铃声
  Future<void> stopAlarmSound() async {
    try {
      await _alarmChannel.invokeMethod('stopAlarm');
    } catch (e) {
      debugPrint('[Alarm] 停止铃声失败: $e');
    }
  }

  Future<void> init() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Shanghai'));

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    // 点击通知时停止铃声并打开 app
    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) async {
        await stopAlarmSound();
      },
    );

    if (Platform.isAndroid) {
      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        // 清理旧通道
        await androidPlugin.deleteNotificationChannel('calendar_reminder');
        await androidPlugin.deleteNotificationChannel('calendar_alarm');
        // 创建新通道 — 静音通道，声音由原生 Service 播放
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            'calendar_alarm_v2',
            '日程闹钟',
            description: '日历事项到期闹钟提醒',
            importance: Importance.max,
            playSound: false,
            enableVibration: false,
          ),
        );
        await androidPlugin.requestNotificationsPermission();
        await androidPlugin.requestExactAlarmsPermission();
      }
    }

    // iOS 通知权限
    await _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    // Android: 请求忽略电池优化
    if (Platform.isAndroid) {
      final batteryStatus = await Permission.ignoreBatteryOptimizations.status;
      if (!batteryStatus.isGranted) {
        await Permission.ignoreBatteryOptimizations.request();
      }
    }

    _initialized = true;
  }

  /// 立即显示通知 + 播放闹钟铃声（用于测试和即时提醒）
  Future<void> showAlarmNow({
    required int id,
    required String title,
    required String body,
  }) async {
    if (!_initialized) await init();

    // 先取消旧通知，防止自动分组抑制
    await _plugin.cancelAll();

    const androidDetails = AndroidNotificationDetails(
      'calendar_alarm_v2',
      '日程闹钟',
      channelDescription: '日历事项到期闹钟提醒',
      importance: Importance.max,
      priority: Priority.max,
      ongoing: true,
      autoCancel: true,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _plugin.show(id, title, body, details);

    // 用原生 Service 播放持续闹钟铃声
    await startAlarmSound();
  }

  /// 为事项注册提醒通知
  Future<void> scheduleReminder(CalendarItem item) async {
    if (item.id == null || item.dateTime == null) return;
    if (item.type == ItemType.todo) return;

    if (!_initialized) await init();

    final reminderTime = item.dateTime!.subtract(
      Duration(minutes: item.reminderMinutes),
    );

    if (reminderTime.isBefore(DateTime.now())) return;

    final scheduledDate = tz.TZDateTime.from(reminderTime, tz.local);

    const androidDetails = AndroidNotificationDetails(
      'calendar_alarm_v2',
      '日程闹钟',
      channelDescription: '日历事项到期闹钟提醒',
      importance: Importance.max,
      priority: Priority.max,
      ongoing: true,
      autoCancel: true,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    final timeStr = '${item.dateTime!.hour.toString().padLeft(2, '0')}:'
        '${item.dateTime!.minute.toString().padLeft(2, '0')}';
    final body = item.reminderMinutes > 0
        ? '$timeStr 的「${item.title}」将在 ${item.reminderMinutes} 分钟后开始'
        : '「${item.title}」现在开始';

    try {
      await _plugin.zonedSchedule(
        item.id!,
        'AI日历提醒',
        body,
        scheduledDate,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      debugPrint('[Notification] 已注册提醒: id=${item.id}, time=$scheduledDate');
    } catch (e) {
      debugPrint('[Notification] 注册失败($e)，降级到非精确模式');
      await _plugin.zonedSchedule(
        item.id!,
        'AI日历提醒',
        body,
        scheduledDate,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  Future<void> cancelReminder(int itemId) async {
    await _plugin.cancel(itemId);
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}
