import 'dart:async';

import 'package:flutter/foundation.dart';

/// Bridges a Stream (Supabase auth state changes) to a [Listenable] so
/// GoRouter's `refreshListenable` re-runs `redirect` whenever auth changes.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
