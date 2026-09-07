import 'dart:async';

/// Thin abstraction over "tell the user something happened right now".
///
/// Today this only drives an in-app banner/snackbar via [stream] -- enough to
/// cover doctor-offer / matched / prescription-ready / order-status-change
/// notifications while the tab is open, which is what's needed to demo the
/// realtime flows now.
///
/// Two things are deliberately NOT built yet, both flagged in the spec as
/// still needing a decision/later work:
///  - Real Web Push (service-worker push subscriptions, VAPID keys, and an
///    Edge Function to send them) -- needed so iOS/Android users get a
///    notification when the PWA isn't open. Swap this class's internals for
///    that once ready; nothing outside this file should need to change.
///  - SMS fallback for critical alerts on unreliable connections.
class NotificationsService {
  NotificationsService._();

  static final NotificationsService instance = NotificationsService._();

  final _controller = StreamController<AppNotification>.broadcast();

  /// In-app listeners (e.g. a top-level SnackBar host) subscribe here.
  Stream<AppNotification> get stream => _controller.stream;

  void notify(AppNotification notification) {
    _controller.add(notification);
  }
}

class AppNotification {
  const AppNotification({required this.title, required this.body});

  final String title;
  final String body;
}
