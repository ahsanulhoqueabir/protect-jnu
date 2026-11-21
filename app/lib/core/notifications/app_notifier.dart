import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/logger.dart';

/// What a notification is about. Each kind has its own Android channel, so users can tune them.
enum NoticeKind {
  sosAlert('sos_alerts', 'SOS alerts', 'New SOS alerts for the admin team'),
  message('messages', 'Messages', 'New chat messages about an alert'),
  alertStatus('alert_status', 'Alert status', 'Changes to the status of your alert');

  const NoticeKind(this.channelId, this.channelName, this.description);
  final String channelId;
  final String channelName;
  final String description;
}

class AppNotice {
  const AppNotice({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    this.route,
  });

  /// Same id replaces the earlier notification (one per alert or thread).
  final int id;
  final NoticeKind kind;
  final String title;
  final String body;

  /// In-app route opened when the notification is tapped.
  final String? route;
}

/// System notifications with sound and vibration (D-081). Raised by the app itself from its live
/// Realtime connection; there is no remote push server (FCM is pending, B-022). Never put OTPs,
/// tokens or other secrets in a notice.
abstract interface class AppNotifier {
  Future<void> init();

  /// Android 13+ runtime permission. Safe to call more than once.
  Future<void> requestPermission();

  Future<void> show(AppNotice notice);

  /// Routes of tapped notifications.
  Stream<String> get taps;

  /// In-app vibration for urgent events (works without the notification permission).
  Future<void> vibrate({bool urgent = false});
}

class LocalAppNotifier implements AppNotifier {
  LocalAppNotifier([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  final _taps = StreamController<String>.broadcast();
  var _ready = false;

  /// Long-short-long buzz for SOS so it stands out from ordinary messages.
  static final _sosVibration = Int64List.fromList([0, 600, 200, 600, 200, 900]);

  @override
  Stream<String> get taps => _taps.stream;

  @override
  Future<void> init() async {
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
        onDidReceiveNotificationResponse: (response) {
          final route = response.payload;
          if (route != null && route.startsWith('/')) _taps.add(route);
        },
      );
      final launch = await _plugin.getNotificationAppLaunchDetails();
      final route = launch?.notificationResponse?.payload;
      if ((launch?.didNotificationLaunchApp ?? false) && route != null && route.startsWith('/')) {
        // Delivered after the router exists (listeners subscribe during the first build).
        scheduleMicrotask(() => _taps.add(route));
      }
      _ready = true;
    } on Object catch (e) {
      // No plugin (tests, unsupported platform): the app works without system notifications.
      AppLogger.error('Notifications unavailable', e);
    }
  }

  @override
  Future<void> requestPermission() async {
    if (!_ready) return;
    try {
      await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    } on Object catch (e) {
      AppLogger.error('Notification permission request failed', e);
    }
  }

  @override
  Future<void> show(AppNotice notice) async {
    if (!_ready) return;
    final urgent = notice.kind == NoticeKind.sosAlert;
    try {
      await _plugin.show(
        id: notice.id,
        title: notice.title,
        body: notice.body,
        payload: notice.route,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            notice.kind.channelId,
            notice.kind.channelName,
            channelDescription: notice.kind.description,
            importance: urgent ? Importance.max : Importance.high,
            priority: urgent ? Priority.max : Priority.high,
            category: urgent
                ? AndroidNotificationCategory.alarm
                : AndroidNotificationCategory.message,
            vibrationPattern: urgent ? _sosVibration : null,
            ticker: notice.title,
          ),
        ),
      );
    } on Object catch (e) {
      AppLogger.error('Could not show a notification', e);
    }
  }

  @override
  Future<void> vibrate({bool urgent = false}) async {
    try {
      await HapticFeedback.vibrate();
      if (urgent) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
        await HapticFeedback.heavyImpact();
      }
    } on Object {
      // Haptics are best effort.
    }
  }
}

/// Initialised in `main.dart`. Tests override it with a recording fake.
final appNotifierProvider = Provider<AppNotifier>((ref) => LocalAppNotifier());
