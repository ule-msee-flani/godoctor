import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/supabase_client.dart';
import '../data/models/enums.dart';
import '../data/providers/auth_providers.dart';

/// Tables the app keeps live. Data providers `ref.watch(liveTick(...))` for
/// the tables they read, so they reload by themselves when a row changes.
abstract final class LiveTable {
  static const orders = 'orders';
  static const prescriptions = 'prescriptions';
  static const consultations = 'consultations';
  static const schedules = 'medication_schedules';
  static const doses = 'dose_logs';
  static const inventory = 'chemist_inventory';
  static const reviews = 'reviews';
  static const family = 'family_links';
  static const payments = 'payments';
  static const doctors = 'doctor_profiles';
  static const readings = 'health_readings';

  static const all = [
    readings,
    orders,
    prescriptions,
    consultations,
    schedules,
    doses,
    inventory,
    reviews,
    family,
    payments,
    doctors,
  ];
}

/// Goes up by one whenever [table] changes for the signed-in user (or when
/// they pull to refresh).
final liveTick = StateProvider.family<int, String>((ref, table) => 0);

/// Reload everything on screen (pull to refresh).
void refreshAllLive(WidgetRef ref) {
  for (final t in LiveTable.all) {
    ref.read(liveTick(t).notifier).state++;
  }
}

/// Listens to database changes for the signed-in user (Supabase Realtime;
/// row security decides what each person receives) and bumps [liveTick].
/// Watched once, at the top of the app.
final liveUpdatesProvider = Provider<void>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  final role = ref.watch(
    currentAppUserProvider.select((user) => user.valueOrNull?.role),
  );
  if (uid == null || role == null) return;

  final subscriptions = <(String, String?)>[
    ...switch (role) {
      UserRole.patient => [
        (LiveTable.orders, 'patient_id'),
        (LiveTable.prescriptions, 'patient_id'),
        (LiveTable.consultations, 'patient_id'),
        (LiveTable.schedules, 'patient_id'),
        (LiveTable.readings, 'patient_id'),
        (LiveTable.doses, null),
        (LiveTable.family, null),
        (LiveTable.payments, null),
      ],
      UserRole.doctor => [
        (LiveTable.consultations, 'doctor_id'),
        (LiveTable.prescriptions, 'doctor_id'),
        (LiveTable.reviews, null),
        (LiveTable.doctors, 'user_id'),
        (LiveTable.payments, null),
      ],
      UserRole.chemist => [
        (LiveTable.orders, 'chemist_id'),
        (LiveTable.inventory, 'chemist_id'),
        (LiveTable.reviews, null),
        (LiveTable.payments, null),
      ],
      UserRole.admin => const <(String, String?)>[],
    },
  ];
  if (subscriptions.isEmpty) return;

  final timers = <String, Timer>{};
  void bump(String table) {
    // Several rows often change together (an order and its items): reload
    // once, a moment later.
    timers[table]?.cancel();
    timers[table] = Timer(const Duration(milliseconds: 350), () {
      ref.read(liveTick(table).notifier).state++;
    });
  }

  final client = SupabaseService.client;
  var channel = client.channel('live-$uid');
  for (final (table, column) in subscriptions) {
    channel = channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: table,
      filter: column == null
          ? null
          : PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: column,
              value: uid,
            ),
      callback: (_) => bump(table),
    );
  }
  channel.subscribe();

  ref.onDispose(() {
    for (final t in timers.values) {
      t.cancel();
    }
    client.removeChannel(channel);
  });
});

/// Pull down to reload. Works on short lists too (the list can always be
/// pulled), and reloads every live table plus anything in [onRefresh].
class LiveRefresh extends ConsumerWidget {
  const LiveRefresh({super.key, required this.child, this.onRefresh});

  /// A scrolling list (ListView, CustomScrollView, ...).
  final Widget child;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () async {
        refreshAllLive(ref);
        await Future.wait([
          if (onRefresh != null) onRefresh!(),
          Future<void>.delayed(const Duration(milliseconds: 700)),
        ]);
      },
      child: ScrollConfiguration(
        behavior: const _PullableScroll(),
        child: child,
      ),
    );
  }
}

/// Lets the outermost vertical list be pulled even when it's shorter than
/// the screen. Lists and text fields nested inside it keep their normal
/// behaviour, so they don't swallow drags meant for the page.
class _PullableScroll extends MaterialScrollBehavior {
  const _PullableScroll();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    final base = super.getScrollPhysics(context);
    final outer = Scrollable.maybeOf(context);
    if (outer != null &&
        axisDirectionToAxis(outer.axisDirection) == Axis.vertical) {
      return base;
    }
    return AlwaysScrollableScrollPhysics(parent: base);
  }
}

/// Keeps a non-list view (an empty or error message) pullable inside
/// [LiveRefresh] by giving it a full-height list to sit in.
class PullableFill extends StatelessWidget {
  const PullableFill({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) => ListView(
      children: [SizedBox(height: c.maxHeight, child: child)],
    ),
  );
}
