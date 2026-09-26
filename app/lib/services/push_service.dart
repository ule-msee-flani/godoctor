import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/config/firebase_options.dart';
import '../core/router/app_router.dart';
import '../data/models/enums.dart';
import '../data/providers/auth_providers.dart';
import '../data/providers/repository_providers.dart';
import '../data/repositories/notification_repository.dart';
import 'notification_routes.dart';

/// Push categories, matching the `push` Edge Function. Each is an Android
/// notification channel (so people can also tune them in phone settings)
/// and a switch in Notification settings. Urgent can't be switched off.
class PushCategory {
  const PushCategory(this.id, this.name, this.description, this.importance);

  final String id;
  final String name;
  final String description;
  final Importance importance;
}

const kPushCategories = <PushCategory>[
  PushCategory(
    'urgent',
    'Urgent consultation alerts',
    'A patient chose you, your doctor is ready, a new order arrived',
    Importance.max,
  ),
  PushCategory(
    'consultations',
    'Consultations and appointments',
    'Bookings, reminders, cancellations, reviews',
    Importance.high,
  ),
  PushCategory(
    'chat',
    'Messages from your doctor or patient',
    'The free chat after a consultation',
    Importance.high,
  ),
  PushCategory(
    'reminders',
    'Medicine reminders',
    'Time to take your medicine',
    Importance.high,
  ),
  PushCategory(
    'orders',
    'Prescriptions, orders and payments',
    'New prescriptions, order updates, receipts',
    Importance.high,
  ),
  PushCategory(
    'family',
    'Family',
    'Family invitations',
    Importance.defaultImportance,
  ),
  PushCategory(
    'support',
    'Support',
    'Replies from GoDoctor support',
    Importance.defaultImportance,
  ),
  PushCategory(
    'account',
    'Account and announcements',
    'Verification, news from GoDoctor',
    Importance.defaultImportance,
  ),
];

/// Firebase is set up in main(); false on platforms without push (desktop)
/// or if it failed to start. Everything push-related checks this first.
bool firebaseReady = false;

/// Starts Firebase for push notifications (never blocks the app on failure).
Future<void> initFirebase() async {
  final options = DefaultFirebaseOptions.currentPlatform;
  if (options == null) return;
  try {
    await Firebase.initializeApp(options: options);
    firebaseReady = true;
  } catch (e) {
    debugPrint('Push notifications unavailable: $e');
  }
}

/// Snackbars for pushes that arrive while the web app is open.
final pushMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// Push notifications: registers this device for the signed-in user,
/// shows alerts while the app is open, and opens the right screen when a
/// notification is tapped.
final pushServiceProvider = Provider<PushService>((ref) {
  final service = PushService(
    repo: ref.read(notificationRepositoryProvider),
    router: () => ref.read(appRouterProvider),
    role: () async => (await ref.read(currentAppUserProvider.future))?.role,
  );
  ref.listen<String?>(currentUserIdProvider, (_, userId) {
    if (userId != null) service.registerDevice();
  }, fireImmediately: true);
  ref.onDispose(service.dispose);
  service.start();
  return service;
});

class PushService {
  PushService({required this.repo, required this.router, required this.role});

  final NotificationRepository repo;
  final GoRouter Function() router;
  final Future<UserRole?> Function() role;

  /// The running service, so sign-out can unregister this device.
  static PushService? current;

  final _local = FlutterLocalNotificationsPlugin();
  final _subs = <StreamSubscription<dynamic>>[];
  String? _token;
  bool _started = false;

  String get _platform => kIsWeb ? 'web' : 'android';

  Future<void> start() async {
    if (_started || !firebaseReady) return;
    _started = true;
    current = this;

    if (!kIsWeb) {
      await _local.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_stat_godoctor'),
        ),
        onDidReceiveNotificationResponse: (r) {
          if (r.payload == null) return;
          _open(Map<String, dynamic>.from(jsonDecode(r.payload!) as Map));
        },
      );
      final android = _local
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      for (final c in kPushCategories) {
        await android?.createNotificationChannel(
          AndroidNotificationChannel(
            c.id,
            c.name,
            description: c.description,
            importance: c.importance,
          ),
        );
      }
    }

    _subs
      ..add(FirebaseMessaging.onMessage.listen(_showWhileOpen))
      ..add(FirebaseMessaging.onMessageOpenedApp.listen((m) => _open(m.data)))
      ..add(
        FirebaseMessaging.instance.onTokenRefresh.listen((t) {
          _token = t;
          repo.registerDevice(t, _platform).catchError((_) {});
        }),
      );

    // Opened by tapping a notification while the app was closed.
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) {
      // Let sign-in and the first screen settle before navigating.
      Future.delayed(const Duration(seconds: 2), () => _open(initial.data));
    }
  }

  /// Asks permission (first time) and links this device to the user.
  Future<void> registerDevice() async {
    if (!firebaseReady) return;
    try {
      final settings = await FirebaseMessaging.instance.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      _token = token;
      await repo.registerDevice(token, _platform);
    } catch (e) {
      debugPrint('Could not register for push: $e');
    }
  }

  /// Before signing out: stop sending this user's alerts to this device.
  Future<void> unregisterDevice() async {
    final token = _token;
    if (token == null) return;
    try {
      await repo.unregisterDevice(token);
    } catch (_) {}
  }

  /// Whether the person allowed notifications on this device.
  Future<bool> get permitted async {
    if (!firebaseReady) return false;
    final s = await FirebaseMessaging.instance.getNotificationSettings();
    return s.authorizationStatus == AuthorizationStatus.authorized ||
        s.authorizationStatus == AuthorizationStatus.provisional;
  }

  /// Firebase doesn't display notifications while the app is in front:
  /// show them ourselves (system notification on Android, a snackbar on web).
  Future<void> _showWhileOpen(RemoteMessage m) async {
    final title = m.notification?.title ?? '';
    final body = m.notification?.body ?? '';
    if (kIsWeb) {
      pushMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text(body.isEmpty ? title : '$title: $body'),
          action: SnackBarAction(label: 'View', onPressed: () => _open(m.data)),
        ),
      );
      return;
    }
    final category = kPushCategories.firstWhere(
      (c) => c.id == m.data['category'],
      orElse: () => kPushCategories.last,
    );
    await _local.show(
      id: m.messageId.hashCode,
      title: title,
      body: body,
      payload: jsonEncode(m.data),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          category.id,
          category.name,
          channelDescription: category.description,
          importance: category.importance,
          priority: category.id == 'urgent' ? Priority.max : Priority.high,
          icon: 'ic_stat_godoctor',
          color: const Color(0xFF1B63F2),
          styleInformation: BigTextStyleInformation(body),
        ),
      ),
    );
  }

  Future<void> _open(Map<String, dynamic> data) async {
    final id = data['notification_id'];
    if (id is String) repo.markRead(id).catchError((_) {});
    final route = routeForNotification(
      kind: '${data['kind'] ?? ''}',
      data: data,
      role: await role(),
    );
    final target = route ?? _inboxFor(await role());
    // Bottom-nav tabs and admin pages are switched to; anything else opens
    // on top of the current screen so Back returns there.
    if (_tabRoots.contains(target) || target.startsWith('/admin')) {
      router().go(target);
    } else {
      router().push(target);
    }
  }

  static const _tabRoots = {
    '/patient',
    '/patient/chats',
    '/patient/health',
    '/patient/profile',
    '/doctor',
    '/doctor/chats',
    '/doctor/profile',
    '/chemist',
    '/chemist/account',
  };

  static String _inboxFor(UserRole? role) => switch (role) {
    UserRole.doctor => '/doctor/notifications',
    UserRole.chemist => '/chemist/notifications',
    UserRole.admin => '/admin/notifications',
    _ => '/patient/notifications',
  };

  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    if (current == this) current = null;
  }
}
