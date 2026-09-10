import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/models.dart';

class NotificationService {
  final List<AppNotification> items = [];
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const String _channelId = 'smart_procurement_messages';

  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(settings);

    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        'Messages',
        description: 'Smart Procurement messages and procurement updates.',
        importance: Importance.max,
      ),
    );
    await android?.requestNotificationsPermission();
    _initialized = true;
  }

  Future<void> showSystemNotification({
    required String title,
    required String message,
    String details = '',
    int id = 1001,
  }) async {
    await initialize();

    final body = details.isEmpty ? message : '$message\n$details';
    final androidDetails = AndroidNotificationDetails(
      _channelId,
      'Messages',
      channelDescription: 'Smart Procurement messages and procurement updates.',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'Smart Procurement',
      category: AndroidNotificationCategory.message,
      styleInformation: BigTextStyleInformation(
        body,
        contentTitle: title,
        summaryText: 'Smart Procurement',
      ),
      autoCancel: true,
    );

    await _plugin.show(
      id,
      title,
      message,
      NotificationDetails(android: androidDetails),
      payload: details,
    );
  }

  void add(
    String title,
    String message, {
    String details = '',
    bool critical = false,
    NotificationKind kind = NotificationKind.general,
  }) {
    items.insert(
      0,
      AppNotification(
        title,
        message,
        DateTime.now(),
        details: details,
        critical: critical,
        kind: kind,
      ),
    );
  }
}
