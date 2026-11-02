import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool? _notificationsAllowed;
  int _nextNotificationId = 1000;

  Future<void> init() async {
    if (_initialized) return;

    try {
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const InitializationSettings initializationSettings =
          InitializationSettings(android: initializationSettingsAndroid);

      await _notificationsPlugin.initialize(initializationSettings);
    } catch (_) {}
    _initialized = true;
  }

  Future<bool> requestPermission() async {
    if (!_initialized) await init();
    if (_notificationsAllowed != null) return _notificationsAllowed!;

    final android = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final granted = await android?.requestNotificationsPermission();
    _notificationsAllowed = granted ?? true;
    return _notificationsAllowed!;
  }

  Future<void> showTaskCompleteNotification(String title, String body) async {
    if (!_initialized) await init();
    if (!await requestPermission()) return;

    final AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'task_completion_channel',
          'Task Completions',
          channelDescription: 'Notifications for when a task completes',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          category: AndroidNotificationCategory.status,
          styleInformation: BigTextStyleInformation(body),
        );

    final NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await _notificationsPlugin.show(
      _nextNotificationId++,
      title,
      body,
      platformChannelSpecifics,
    );
  }
}
