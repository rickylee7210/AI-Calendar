import 'dart:io';
import 'package:flutter/foundation.dart';
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

    await _plugin.initialize(initSettings);

    // Android: 显式创建通知通道（不依赖插件自动创建）
    if (Platform.isAndroid) {
      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            'calendar_reminder',
            '日程提醒',
            description: '日历事项到期提醒',
            importance: Importance.high,
            playSound: true,
            enableVibration: true,
          ),
        );
        await androidPlugin.requestNotificationsPermission();
        await androidPlugin.requestExactAlarmsPermission();
      }
    }

    // 请求 iOS 通知权限
    await _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    // Android: 请求忽略电池优化（小米等国产 ROM 会杀后台闹钟）
    if (Platform.isAndroid) {
      final batteryStatus = await Permission.ignoreBatteryOptimizations.status;
      if (!batteryStatus.isGranted) {
        await Permission.ignoreBatteryOptimizations.request();
      }
    }

    _initialized = true;
  }

  /// 为事项注册提醒通知
  Future<void> scheduleReminder(CalendarItem item) async {
    if (item.id == null || item.dateTime == null) return;
    if (item.type == ItemType.todo) return; // 待办不提醒

    // 确保已初始化
    if (!_initialized) await init();

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

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    final timeStr = '${item.dateTime!.hour.toString().padLeft(2, '0')}:'
        '${item.dateTime!.minute.toString().padLeft(2, '0')}';
    final body = item.reminderMinutes > 0
        ? '$timeStr 的「${item.title}」将在 ${item.reminderMinutes} 分钟后开始'
        : '「${item.title}」现在开始';

    // 先尝试精确闹钟，失败则降级到非精确模式
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
      debugPrint('[Notification] 已注册精确提醒: id=${item.id}, time=$scheduledDate');
    } catch (e) {
      debugPrint('[Notification] 精确闹钟失败($e)，降级到非精确模式');
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
      debugPrint('[Notification] 已注册非精确提醒: id=${item.id}, time=$scheduledDate');
    }
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
