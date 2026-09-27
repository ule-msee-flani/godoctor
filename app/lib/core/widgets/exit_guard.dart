import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The phone's back button on a top-level screen: first it goes "up" (e.g.
/// from another tab back to Home, via [onBack]); on Home it asks for a
/// second press within two seconds before leaving the app, so a stray tap
/// never closes GoDoctor.
class ExitGuard extends StatefulWidget {
  const ExitGuard({super.key, required this.child, this.onBack});

  final Widget child;

  /// Handle the back press (return true), e.g. switch to the Home tab.
  final bool Function()? onBack;

  @override
  State<ExitGuard> createState() => _ExitGuardState();
}

class _ExitGuardState extends State<ExitGuard> {
  DateTime? _lastPress;

  void _onBack() {
    if (widget.onBack?.call() ?? false) return;
    final now = DateTime.now();
    if (_lastPress != null &&
        now.difference(_lastPress!) < const Duration(seconds: 2)) {
      SystemNavigator.pop();
      return;
    }
    _lastPress = now;
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Press back again to exit'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBack();
      },
      child: widget.child,
    );
  }
}
