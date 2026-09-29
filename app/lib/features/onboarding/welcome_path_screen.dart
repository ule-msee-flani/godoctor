import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/heartbeat_loader.dart';
import '../../data/models/enums.dart';
import '../../data/providers/auth_providers.dart';
import '../../data/providers/repository_providers.dart';
import '../../data/repositories/repository_errors.dart';
import 'path_animation.dart';
import 'path_steps.dart';

enum _Phase { loading, question, travel, saving, done }

/// The welcome path after sign-up: a few questions, one or two at a time,
/// with a short walk along a path between them and a send-off at the end.
/// Nothing on screen but the question.
class WelcomePathScreen extends ConsumerStatefulWidget {
  const WelcomePathScreen({super.key});

  @override
  ConsumerState<WelcomePathScreen> createState() => _WelcomePathScreenState();
}

class _WelcomePathScreenState extends ConsumerState<WelcomePathScreen> {
  _Phase _phase = _Phase.loading;
  UserRole _role = UserRole.patient;
  List<PathStep> _steps = const [];
  Answers _a = {};
  Answers _initial = {};
  int _i = 0;
  bool _forward = true;
  final _pick = math.Random().nextInt(3);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final user = await ref.read(currentAppUserProvider.future);
    final role = user?.role ?? UserRole.patient;
    Answers a;
    List<PathStep> steps;
    switch (role) {
      case UserRole.doctor:
        a = prefillDoctor(await ref.read(currentDoctorProfileProvider.future));
        steps = doctorSteps(pickPhoto: pickPhotoInto);
      case UserRole.chemist:
        a = prefillChemist(
          await ref.read(currentChemistProfileProvider.future),
          phone: user?.contactPhone,
        );
        steps = chemistSteps();
      default:
        a = prefillPatient(
          await ref.read(currentPatientProfileProvider.future),
        );
        steps = patientSteps();
    }
    if (!mounted) return;
    setState(() {
      _role = role;
      _a = a;
      _initial = Map.of(a);
      _steps = steps;
      _phase = _Phase.question;
    });
  }

  PathStep get _step => _steps[_i];

  void _set(String key, Object? value) => setState(() => _a[key] = value);

  void _next() {
    FocusScope.of(context).unfocus();
    HapticFeedback.lightImpact();
    if (_i == _steps.length - 1) {
      _finish();
      return;
    }
    setState(() {
      _forward = true;
      _phase = _Phase.travel;
    });
  }

  void _skip() {
    // Leave these answers as they were.
    setState(() {
      for (final k in _step.keys) {
        if (_initial.containsKey(k)) {
          _a[k] = _initial[k];
        } else {
          _a.remove(k);
        }
      }
    });
    _next();
  }

  void _arrived() => setState(() {
    _i++;
    _phase = _Phase.question;
  });

  void _back() {
    if (_phase != _Phase.question || _i == 0) return;
    setState(() {
      _forward = false;
      _i--;
    });
  }

  Future<void> _finish() async {
    setState(() {
      _forward = true;
      _phase = _Phase.saving;
    });
    final profiles = ref.read(profileRepositoryProvider);
    try {
      await Future.wait([
        () async {
          if (_a['_photo'] is Uint8List) {
            final me = ref.read(currentUserIdProvider);
            if (me != null) {
              await profiles.changeAvatar(
                userId: me,
                bytes: _a['_photo'] as Uint8List,
                fileExt: (_a['_photo_ext'] as String?) ?? 'jpg',
              );
            }
          }
          await profiles.completeOnboarding(answersForServer(_a));
        }(),
        // Let the walk to the finish play out.
        Future<void>.delayed(const Duration(milliseconds: 1200)),
      ]);
      if (mounted) setState(() => _phase = _Phase.done);
    } catch (e) {
      if (!mounted) return;
      setState(() => _phase = _Phase.question);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  void _go() {
    ref
      ..invalidate(currentAppUserProvider)
      ..invalidate(currentPatientProfileProvider)
      ..invalidate(currentDoctorProfileProvider)
      ..invalidate(currentChemistProfileProvider);
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: AppColors.white,
        body: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 420),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween(
                  begin: Offset(_forward ? 0.08 : -0.08, 0),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            ),
            child: _body(),
          ),
        ),
      ),
    );
  }

  Widget _body() {
    // One more stop than questions: the finish.
    final stops = _steps.length + 1;
    return switch (_phase) {
      _Phase.loading => const Center(
        key: ValueKey('loading'),
        child: DelayedHeartbeat(),
      ),
      _Phase.question => _QuestionPage(
        key: ValueKey('q$_i'),
        step: _step,
        answers: _a,
        set: _set,
        last: _i == _steps.length - 1,
        onContinue: _next,
        onSkip: _skip,
      ),
      _Phase.travel => Padding(
        key: ValueKey('t$_i'),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: PathTravel(
          stops: stops,
          from: _i,
          to: _i + 1,
          message: encouragement(_i + 1, _steps.length),
          onDone: _arrived,
        ),
      ),
      _Phase.saving => Padding(
        key: const ValueKey('saving'),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: PathTravel(
          stops: stops,
          from: _steps.length - 1,
          to: _steps.length,
          message: 'Setting things up for you…',
          onDone: () {},
        ),
      ),
      _Phase.done => KeyedSubtree(
        key: const ValueKey('done'),
        child: _finishScreen(),
      ),
    };
  }

  Widget _finishScreen() {
    switch (_role) {
      case UserRole.doctor:
        final d = ref.read(currentDoctorProfileProvider).valueOrNull;
        final submitted = (d?.licenseNumber ?? '').isNotEmpty;
        final verified = d?.licenseVerified ?? false;
        return PathFinish(
          headline: 'Go on and save lives.',
          line: const [
            'Healing starts with you.',
            'Your stethoscope just went digital.',
            'Patients across Kenya are a tap away.',
          ][_pick],
          note: !submitted
              ? 'One last step: verify your licence so patients can find you.'
              : verified
              ? null
              : 'We\'re checking your licence. We\'ll let you know the moment '
                    'you\'re approved.',
          button: !submitted
              ? 'Verify my licence'
              : verified
              ? 'Open my portal'
              : 'Continue',
          onGo: _go,
        );
      case UserRole.chemist:
        final c = ref.read(currentChemistProfileProvider).valueOrNull;
        final submitted = (c?.registrationNumber ?? '').isNotEmpty;
        final verified = c?.verified ?? false;
        return PathFinish(
          headline: 'Open for healing.',
          line: const [
            'Keep Kenya well, one prescription at a time.',
            'The right medicine, right when it\'s needed.',
            'Healing, one prescription at a time.',
          ][_pick],
          note: !submitted
              ? 'One last step: verify your pharmacy so patients can order '
                    'from you.'
              : verified
              ? null
              : 'We\'re checking your registration. We\'ll let you know the '
                    'moment you\'re approved.',
          button: !submitted
              ? 'Verify my pharmacy'
              : verified
              ? 'Open my portal'
              : 'Continue',
          onGo: _go,
        );
      default:
        final first = ((_a['name'] as String?) ?? '').trim().split(' ').first;
        return PathFinish(
          headline: first.isEmpty
              ? 'You\'re all set!'
              : 'You\'re all set, $first!',
          line:
              '${const ['Your doctor is just a tap away.', 'Care at your fingertips, whenever you need it.', 'Feel better, sooner.'][_pick]} '
              'Enjoy GoDoctor.',
          button: 'Let\'s go',
          onGo: _go,
        );
    }
  }
}

/// One stop: the question, its answer, Continue, and Skip when optional.
class _QuestionPage extends StatelessWidget {
  const _QuestionPage({
    super.key,
    required this.step,
    required this.answers,
    required this.set,
    required this.last,
    required this.onContinue,
    required this.onSkip,
  });

  final PathStep step;
  final Answers answers;
  final SetAnswer set;
  final bool last;
  final VoidCallback onContinue;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final ready = step.isReady?.call(answers) ?? true;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            step.title,
            style: text.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
          if (step.subtitle != null) ...[
            const SizedBox(height: 10),
            Text(
              step.subtitle!,
              style: text.bodyLarge?.copyWith(color: AppColors.inkSoft),
            ),
          ],
          const SizedBox(height: 28),
          Expanded(
            child: SingleChildScrollView(
              child: step.build(context, answers, set),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
            ),
            onPressed: ready ? onContinue : null,
            child: Text(last ? 'Finish' : 'Continue'),
          ),
          SizedBox(
            height: 48,
            child: step.optional
                ? TextButton(
                    onPressed: onSkip,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.inkSoft,
                    ),
                    child: const Text('Skip for now'),
                  )
                : null,
          ),
        ],
      ),
    );
  }
}
