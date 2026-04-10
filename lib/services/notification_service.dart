import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;
import '../models/calendar_item.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Shanghai'));

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(initSettings);

    // 请求通知权限 (Android 13+)
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    // 请求精确闹钟权限 (Android 12+)
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestExactAlarmsPermission();

    _initialized = true;
  }

  /// 为事项注册提醒通知
  Future<void> scheduleReminder(CalendarItem item) async {
    if (item.id == null || item.dateTime == null) return;
    if (item.type == ItemType.todo) return; // 待办不提醒

    final reminderTime = item.dateTime!.subtract(
      Duration(minutes: item.reminderMinutes),
    );

    // 已过期不注册
    if (reminderTime.isBefore(DateTime.now())) return;

    final scheduledDate = tz.TZDateTime.from(reminderTime, tz.local);

    final androidDetails = AndroidNotificationDetails(
      'calendar_reminder',
      '日程提醒',
      channelDescription: '日历事项到期提醒',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      ticker: item.title,
    );

    final details = NotificationDetails(android: androidDetails);

    final timeStr = '${item.dateTime!.hour.toString().padLeft(2, '0')}:'
        '${item.dateTime!.minute.toString().padLeft(2, '0')}';
    final body = item.reminderMinutes > 0
        ? '$timeStr 的「${item.title}」将在 ${item.reminderMinutes} 分钟后开始'
        : '「${item.title}」现在开始';

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

    debugPrint('[Notification] 已注册提醒: id=${item.id}, time=$scheduledDate, title=${item.title}');
  }

  /// 取消某个事项的提醒
  Future<void> cancelReminder(int itemId) async {
    await _plugin.cancel(itemId);
  }

  /// 取消所有提醒
  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}
