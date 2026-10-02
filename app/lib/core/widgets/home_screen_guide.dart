import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/pwa_install_service.dart';
import '../../features/auth/widgets/auth_hero.dart' show AppIconMark;
import '../theme/app_colors.dart';

/// Where Android phones get the app.
const kDownloadPage = 'https://ule-msee-flani.github.io/godoctor/';

/// What the guide shows (and what to say on the banner that opens it).
enum _Guide { addToHomeScreen, getAndroidApp }

/// Opened in a browser on a phone, GoDoctor explains how to get it as an
/// app: on an iPhone or iPad, how to add it to the Home Screen (with the
/// steps for that browser); on an Android phone, where to get the app. It
/// pops up once a day until then, and the install banner opens it any time.
/// Opened from the Home Screen (or in the Android app) it never shows.
class HomeScreenGuide extends StatefulWidget {
  const HomeScreenGuide({super.key, required this.child});

  final Widget child;

  /// Opens the guide now (from the install banner).
  static void open() => _requests.value++;

  static final _requests = ValueNotifier<int>(0);

  @override
  State<HomeScreenGuide> createState() => _HomeScreenGuideState();
}

class _HomeScreenGuideState extends State<HomeScreenGuide> {
  static const _snoozeKey = 'home_screen_guide_until';

  final _service = PwaInstallService.instance;
  _Guide? _showing;

  /// The last one shown, kept on screen while it slides away.
  _Guide? _last;
  Timer? _timer;

  _Guide? get _kind {
    if (!kIsWeb || _service.isRunningStandalone) return null;
    if (_service.isIOS) return _Guide.addToHomeScreen;
    if (_service.isAndroid) return _Guide.getAndroidApp;
    return null;
  }

  @override
  void initState() {
    super.initState();
    HomeScreenGuide._requests.addListener(_openNow);
    if (_kind != null) {
      // After the launch animation, so it isn't the first thing in the way.
      _timer = Timer(const Duration(milliseconds: 4200), _maybeOpen);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    HomeScreenGuide._requests.removeListener(_openNow);
    super.dispose();
  }

  Future<void> _maybeOpen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final until = prefs.getInt(_snoozeKey) ?? 0;
      if (DateTime.now().millisecondsSinceEpoch < until) return;
    } catch (_) {}
    if (mounted) setState(() => _showing = _kind);
  }

  void _openNow() {
    final kind = _kind;
    if (kind != null && mounted) setState(() => _showing = kind);
  }

  /// Closes it, and keeps it away for [days].
  Future<void> _close({required int days}) async {
    setState(() => _showing = null);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        _snoozeKey,
        DateTime.now().add(Duration(days: days)).millisecondsSinceEpoch,
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final showing = _showing;
    if (showing != null) _last = showing;
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        IgnorePointer(
          ignoring: showing == null,
          child: AnimatedOpacity(
            opacity: showing == null ? 0 : 1,
            duration: const Duration(milliseconds: 250),
            child: GestureDetector(
              onTap: () => _close(days: 1),
              child: const ColoredBox(color: Color(0x880B1730)),
            ),
          ),
        ),
        AnimatedSlide(
          offset: showing == null ? const Offset(0, 1.1) : Offset.zero,
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeOutCubic,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: switch (_last) {
              _Guide.addToHomeScreen => HomeScreenSteps(
                browser: _service.browser,
                iPad: _service.isIPad,
                link: _service.currentUrl,
                onNotNow: () => _close(days: 1),
                onDone: () => _close(days: 30),
              ),
              _Guide.getAndroidApp => _AndroidAppSheet(
                onGet: () {
                  _close(days: 3);
                  _service.open(kDownloadPage);
                },
                onNotNow: () => _close(days: 3),
              ),
              null => const SizedBox.shrink(),
            },
          ),
        ),
      ],
    );
  }
}

/// The sheet's frame: white, rounded at the top, a handle, a close button.
class _Sheet extends StatelessWidget {
  const _Sheet({required this.onClose, required this.children});

  final VoidCallback onClose;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: 560, maxHeight: height * 0.88),
      child: Material(
        color: AppColors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 10, 22, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Spacer(),
                    Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Semantics(
                          button: true,
                          label: 'Close',
                          child: InkResponse(
                            onTap: onClose,
                            radius: 22,
                            child: const Padding(
                              padding: EdgeInsets.all(6),
                              child: Icon(
                                LucideIcons.x,
                                size: 20,
                                color: AppColors.inkSoft,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                ...children,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The GoDoctor icon, as it will look on the Home Screen.
class _AppIcon extends StatelessWidget {
  const _AppIcon();

  @override
  Widget build(BuildContext context) =>
      const Center(child: AppIconMark(size: 64));
}

/// One step: a number, the button to look for, and what to do.
class HomeScreenStep {
  const HomeScreenStep(this.icon, this.text, [this.bold]);

  final IconData? icon;
  final String text;

  /// The part of [text] to show in bold (the button's name).
  final String? bold;
}

List<HomeScreenStep> homeScreenSteps(
  HomeScreenBrowser browser, {
  bool iPad = false,
}) {
  final where = iPad ? 'at the top right' : 'at the bottom of the screen';
  return switch (browser) {
    HomeScreenBrowser.safariNew => [
      HomeScreenStep(LucideIcons.ellipsis, 'Tap ••• $where.', '•••'),
      const HomeScreenStep(LucideIcons.share, 'Tap Share.', 'Share'),
      const HomeScreenStep(
        LucideIcons.squarePlus,
        'Scroll down and tap Add to Home Screen.',
        'Add to Home Screen',
      ),
      const HomeScreenStep(
        null,
        'Keep "Open as Web App" on, then tap Add.',
        'Add',
      ),
    ],
    HomeScreenBrowser.safari || HomeScreenBrowser.other => [
      HomeScreenStep(
        LucideIcons.share,
        'Tap the Share button $where.',
        'Share',
      ),
      const HomeScreenStep(
        LucideIcons.squarePlus,
        'Scroll down and tap Add to Home Screen.',
        'Add to Home Screen',
      ),
      const HomeScreenStep(null, 'Tap Add at the top right.', 'Add'),
    ],
    HomeScreenBrowser.chrome => const [
      HomeScreenStep(
        LucideIcons.share,
        'Tap the Share button in the address bar, at the top right.',
        'Share',
      ),
      HomeScreenStep(
        LucideIcons.squarePlus,
        'Tap Add to Home Screen (scroll down, or tap More, if you don\'t '
            'see it).',
        'Add to Home Screen',
      ),
      HomeScreenStep(null, 'Tap Add.', 'Add'),
    ],
    HomeScreenBrowser.edge => [
      HomeScreenStep(LucideIcons.ellipsis, 'Tap ••• $where.', '•••'),
      const HomeScreenStep(LucideIcons.share, 'Tap Share.', 'Share'),
      const HomeScreenStep(
        LucideIcons.squarePlus,
        'Tap Add to Home Screen, then Add.',
        'Add to Home Screen',
      ),
    ],
    HomeScreenBrowser.firefox => [
      HomeScreenStep(LucideIcons.menu, 'Tap the menu ☰ $where.', '☰'),
      const HomeScreenStep(LucideIcons.share, 'Tap Share.', 'Share'),
      const HomeScreenStep(
        LucideIcons.squarePlus,
        'Tap Add to Home Screen, then Add.',
        'Add to Home Screen',
      ),
    ],
    HomeScreenBrowser.inApp => const [
      HomeScreenStep(
        LucideIcons.compass,
        'Tap ••• or the menu in this app, and choose Open in Safari (or '
            'Open in browser).',
        'Open in Safari',
      ),
      HomeScreenStep(
        LucideIcons.share,
        'In Safari, tap Share, then Add to Home Screen.',
        'Add to Home Screen',
      ),
    ],
  };
}

/// "Add GoDoctor to your Home Screen", with the steps for this browser.
class HomeScreenSteps extends StatefulWidget {
  const HomeScreenSteps({
    super.key,
    required this.browser,
    required this.onNotNow,
    required this.onDone,
    this.iPad = false,
    this.link = '',
  });

  final HomeScreenBrowser browser;
  final bool iPad;

  /// This page's address, to copy into Safari from inside another app.
  final String link;
  final VoidCallback onNotNow;
  final VoidCallback onDone;

  @override
  State<HomeScreenSteps> createState() => _HomeScreenStepsState();
}

class _HomeScreenStepsState extends State<HomeScreenSteps> {
  bool _copied = false;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final inApp = widget.browser == HomeScreenBrowser.inApp;
    final steps = homeScreenSteps(widget.browser, iPad: widget.iPad);
    return _Sheet(
      onClose: widget.onNotNow,
      children: [
        const SizedBox(height: 4),
        const _AppIcon(),
        const SizedBox(height: 14),
        Text(
          inApp
              ? 'Open GoDoctor in Safari'
              : 'Add GoDoctor to your Home Screen',
          textAlign: TextAlign.center,
          style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          inApp
              ? 'You\'re viewing GoDoctor inside another app. Open it in '
                    'Safari to add it to your Home Screen.'
              : 'It opens full screen with its own icon, just like any other '
                    'app. It only takes a few seconds.',
          textAlign: TextAlign.center,
          style: text.bodyMedium?.copyWith(color: AppColors.inkSoft),
        ),
        const SizedBox(height: 18),
        for (final (i, step) in steps.indexed)
          _StepRow(number: i + 1, step: step),
        if (inApp && widget.link.isNotEmpty) ...[
          const SizedBox(height: 6),
          OutlinedButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: widget.link));
              if (mounted) setState(() => _copied = true);
            },
            icon: Icon(
              _copied ? LucideIcons.check : LucideIcons.copy,
              size: 18,
            ),
            label: Text(
              _copied ? 'Link copied. Paste it in Safari' : 'Copy the link',
            ),
          ),
        ] else if (widget.browser != HomeScreenBrowser.safari &&
            widget.browser != HomeScreenBrowser.safariNew) ...[
          const SizedBox(height: 4),
          Text(
            'Don\'t see Add to Home Screen? Open this page in Safari and try '
            'again.',
            textAlign: TextAlign.center,
            style: text.bodySmall?.copyWith(color: AppColors.inkFaint),
          ),
        ],
        const SizedBox(height: 16),
        FilledButton(
          onPressed: widget.onDone,
          child: Text(inApp ? 'Got it' : 'I\'ve added it'),
        ),
        const SizedBox(height: 4),
        TextButton(onPressed: widget.onNotNow, child: const Text('Not now')),
        if (!inApp) _Pointer(browser: widget.browser, iPad: widget.iPad),
      ],
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.number, required this.step});

  final int number;
  final HomeScreenStep step;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme.bodyLarge;
    final bold = step.bold;
    final at = bold == null ? -1 : step.text.indexOf(bold);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.primarySoft,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$number',
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text.rich(
                at < 0
                    ? TextSpan(text: step.text)
                    : TextSpan(
                        children: [
                          TextSpan(text: step.text.substring(0, at)),
                          TextSpan(
                            text: bold,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          TextSpan(
                            text: step.text.substring(at + bold!.length),
                          ),
                        ],
                      ),
                style: text?.copyWith(color: AppColors.ink, height: 1.35),
              ),
            ),
          ),
          if (step.icon != null) ...[
            const SizedBox(width: 10),
            // What the button looks like.
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primarySofter,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Icon(step.icon, size: 19, color: AppColors.primary),
            ),
          ],
        ],
      ),
    );
  }
}

/// A gently bouncing arrow towards where the first button is (Safari's
/// toolbar below the page on a phone; the top for Chrome and iPads).
class _Pointer extends StatefulWidget {
  const _Pointer({required this.browser, required this.iPad});

  final HomeScreenBrowser browser;
  final bool iPad;

  @override
  State<_Pointer> createState() => _PointerState();
}

class _PointerState extends State<_Pointer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bounce;

  @override
  void initState() {
    super.initState();
    _bounce = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _bounce.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final up = widget.iPad || widget.browser == HomeScreenBrowser.chrome;
    if (up) {
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(
          'The button is at the top of your screen.',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(color: AppColors.primary),
        ),
      );
    }
    final right =
        widget.browser != HomeScreenBrowser.safari &&
        widget.browser != HomeScreenBrowser.other;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        mainAxisAlignment: right
            ? MainAxisAlignment.end
            : MainAxisAlignment.center,
        children: [
          Text(
            right ? 'Down here, bottom right' : 'Down here',
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: AppColors.primary),
          ),
          const SizedBox(width: 6),
          AnimatedBuilder(
            animation: _bounce,
            builder: (context, child) => Transform.translate(
              offset: Offset(0, 5 * Curves.easeInOut.transform(_bounce.value)),
              child: child,
            ),
            child: const Icon(
              LucideIcons.arrowDown,
              size: 20,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

/// On an Android phone's browser: where to get the app.
class _AndroidAppSheet extends StatelessWidget {
  const _AndroidAppSheet({required this.onGet, required this.onNotNow});

  final VoidCallback onGet;
  final VoidCallback onNotNow;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return _Sheet(
      onClose: onNotNow,
      children: [
        const SizedBox(height: 4),
        const _AppIcon(),
        const SizedBox(height: 14),
        Text(
          'Get GoDoctor for Android',
          textAlign: TextAlign.center,
          style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          'The GoDoctor app for your phone: notifications for your '
          'consultations and orders, and quicker to open.',
          textAlign: TextAlign.center,
          style: text.bodyMedium?.copyWith(color: AppColors.inkSoft),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: onGet,
          icon: const Icon(LucideIcons.download, size: 18),
          label: const Text('Get the app'),
        ),
        const SizedBox(height: 4),
        TextButton(onPressed: onNotNow, child: const Text('Continue here')),
      ],
    );
  }
}
