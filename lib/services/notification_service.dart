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

    await _plugin.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: (response) async {
        await stopAlarmSound();
      },
    );

    if (Platform.isAndroid) {
      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.requestNotificationsPermission();
        await androidPlugin.requestExactAlarmsPermission();
      }
      final batteryStatus = await Permission.ignoreBatteryOptimizations.status;
      if (!batteryStatus.isGranted) {
        await Permission.ignoreBatteryOptimizations.request();
      }
    }

    await _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    _initialized = true;
  }

  /// 注册提醒：用原生 AlarmManager 时间由 AlarmReceiver 弹通知+响铃
  Future<void> scheduleReminder(CalendarItem item) async {
    if (item.id == null || item.dateTime == null) return;
    if (item.type == ItemType.todo) return;

    if (!_initialized) await init();

    final reminderTime = item.dateTime!.subtract(
      Duration(minutes: item.reminderMinutes),
    );

    if (reminderTime.isBefore(DateTime.now())) return;

    final timeStr = '${item.dateTime!.hour.toString().padLeft(2, '0')}:'
        '${item.dateTime!.minute.toString().padLeft(2, '0')}';
    final body = item.reminderMinutes > 0
        ? '$timeStr 的「${item.title}」将在 ${item.reminderMinutes} 分钟后开始'
        : '「${item.title}」现在开始';

    try {
      await _alarmChannel.invokeMethod('scheduleNativeAlarm', {
        'id': item.id!,
        'triggerAtMillis': reminderTime.millisecondsSinceEpoch,
        'title': 'AI日历提醒',
        'body': body,
      });
      debugPrint('[Notification] 已注册原生闹钟: id=${item.id}, time=$reminderTime');
    } catch (e) {
      debugPrint('[Notification] 注册原生闹钟失败: $e');
    }
  }

  /// 取消提醒
  Future<void> cancelReminder(int itemId) async {
    try {
      await _alarmChannel.invokeMethod('cancelNativeAlarm', {'id': itemId});
    } catch (e) {
      debugPrint('[Notification] 取消闹钟失败: $e');
    }
  }

  /// 取消所有
  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}
