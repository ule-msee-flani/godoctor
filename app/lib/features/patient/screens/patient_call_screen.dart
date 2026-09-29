import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/local_touch.dart';
import '../../../core/widgets/heartbeat_loader.dart';
import '../../../core/widgets/video_call_panel.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/prescription.dart';
import '../../../data/providers/appointment_providers.dart';
import '../../../data/providers/auth_providers.dart';
import '../../../data/providers/prescription_providers.dart';
import '../../../services/data_saver.dart';
import '../../call/active_call.dart';
import '../../call/call_stage.dart';
import '../../medications/dose_reminder_sheet.dart';
import '../../prescription/digital_prescription.dart';
import '../../prescription/suggested_chemist_card.dart';
import '../family/family_providers.dart';
import '../family/family_session_panel.dart';
import '../widgets/doctor_widgets.dart';
import 'doctor_profile_screen.dart' show publicDoctorProvider;
import '../widgets/review_sheet.dart';
import '../../../data/providers/repository_providers.dart';

/// The doctor ended the visit: back to Home, and there ask how it went
/// while it's fresh (the summary is one tap away, and stays on Home under
/// "Your visits"). Used by the call screen and, when the call was
/// minimized, by the floating call window.
void showVisitEnded(
  GoRouter router, {
  required String consultationId,
  required String doctorName,
}) {
  HapticFeedback.lightImpact();
  router.go('/patient');
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    final home = router.routerDelegate.navigatorKey.currentContext;
    if (home == null || !home.mounted) return;
    final rated = await showReviewSheet(
      home,
      consultationId: consultationId,
      doctorName: doctorName,
      extra: (
        label: 'Not now — see the visit summary',
        onTap: () => router.push('/patient/visit/$consultationId'),
      ),
    );
    if (rated && home.mounted) {
      ScaffoldMessenger.of(home).showSnackBar(
        SnackBar(
          content: const Text('Thanks for your review. Get well soon!'),
          action: SnackBarAction(
            label: 'Summary',
            onPressed: () => router.push('/patient/visit/$consultationId'),
          ),
        ),
      );
    }
  });
}

/// The patient's side of the consultation. Until the doctor opens the call
/// the patient waits in a calm waiting room (with a camera / data choice);
/// when the doctor joins there's a small moment (a tap of haptics and a
/// "joined" pill) and the (mock) video call takes over the whole screen.
/// The prescription and details sit in a panel pulled up from the bottom.
/// Back doesn't end anything: the call shrinks into a floating window and
/// carries on while the patient uses the rest of the app.
class PatientCallScreen extends ConsumerStatefulWidget {
  const PatientCallScreen({super.key, required this.consultationId});

  final String consultationId;

  @override
  ConsumerState<PatientCallScreen> createState() => _PatientCallScreenState();
}

class _PatientCallScreenState extends ConsumerState<PatientCallScreen> {
  late bool _myCameraOff = ref.read(dataSaverProvider);
  late final ActiveCallController _calls;
  final _stage = GlobalKey<CallStageState>();
  bool _justJoined = false;
  Timer? _joinedTimer;

  /// Prescriptions the patient has seen (the panel was open).
  int _seen = 0;
  bool _panelOpen = false;
  bool _rxNotice = false;
  Timer? _rxTimer;

  /// Leaving on purpose (left, or the visit ended): don't keep the call
  /// floating. Minimized: don't pull it back full screen.
  bool _leaving = false;
  bool _minimized = false;

  String get _id => widget.consultationId;

  @override
  void initState() {
    super.initState();
    _calls = ref.read(activeCallProvider.notifier);
  }

  @override
  void dispose() {
    _joinedTimer?.cancel();
    _rxTimer?.cancel();
    if (!_leaving) {
      final calls = _calls;
      final id = _id;
      Future.microtask(() => calls.screenClosed(id));
    }
    super.dispose();
  }

  void _doctorJoined() {
    HapticFeedback.mediumImpact();
    setState(() => _justJoined = true);
    _joinedTimer?.cancel();
    _joinedTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _justJoined = false);
    });
  }

  void _newPrescription() {
    HapticFeedback.mediumImpact();
    setState(() => _rxNotice = true);
    _rxTimer?.cancel();
    _rxTimer = Timer(const Duration(seconds: 8), () {
      if (mounted) setState(() => _rxNotice = false);
    });
  }

  void _visitEnded() {
    if (!mounted || _leaving) return;
    _leaving = true;
    final doctorId = ref.read(appointmentProvider(_id)).valueOrNull?.doctorId;
    final doctor = doctorId == null
        ? null
        : ref.read(publicDoctorProvider(doctorId)).valueOrNull?.name;
    _calls.end(_id);
    showVisitEnded(
      GoRouter.of(context),
      consultationId: _id,
      doctorName: doctor ?? 'your doctor',
    );
  }

  void _close() {
    final router = GoRouter.of(context);
    if (router.canPop()) {
      router.pop();
    } else {
      router.go('/patient');
    }
  }

  /// Back (or "<"): the call carries on in a floating window.
  void _minimize() {
    if (_minimized) return;
    HapticFeedback.selectionClick();
    _minimized = true;
    _calls.minimize();
    _close();
  }

  Future<void> _leave(BuildContext context, {required bool waiting}) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(waiting ? 'Leave the waiting room?' : 'Leave the call?'),
        content: const Text(
          'You can come back to it from Home while the doctor is still on.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Stay'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    _leaving = true;
    _calls.end(_id);
    _close();
  }

  /// Keep the floating window's copy of the call up to date.
  void _sync(ActiveCall info) {
    if (_leaving || _minimized) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_leaving && !_minimized) _calls.showing(info);
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(appointmentProvider(_id), (prev, next) {
      final was = prev?.valueOrNull?.doctorJoinedAt;
      final now = next.valueOrNull?.doctorJoinedAt;
      if (prev?.hasValue == true && was == null && now != null) _doctorJoined();
      // The doctor just ended the visit: back to Home, with the summary a
      // tap away (it's also the first card under "Your visits").
      final ended = next.valueOrNull?.status == ConsultationStatus.completed;
      final wasEnded =
          prev?.valueOrNull?.status == ConsultationStatus.completed;
      if (prev?.hasValue == true && ended && !wasEnded) _visitEnded();
    });
    ref.listen(consultationPrescriptionsProvider(_id), (prev, next) {
      final before = prev?.valueOrNull?.length;
      final after = next.valueOrNull?.length ?? 0;
      if (before != null && after > before && !_panelOpen) _newPrescription();
    });
    final consultation = ref.watch(appointmentProvider(_id)).value;
    final doctor = consultation?.doctorId == null
        ? null
        : ref.watch(publicDoctorProvider(consultation!.doctorId!)).value;
    final prescriptions =
        ref.watch(consultationPrescriptionsProvider(_id)).value ??
        const <Prescription>[];
    final patient = ref.watch(currentPatientProfileProvider).value;
    final call = ref.watch(activeCallProvider);
    final mine = call?.consultationId == _id ? call : null;

    final ended = consultation?.status == ConsultationStatus.completed;
    // A prescription means the doctor is clearly there, even if the
    // "joined" mark was missed (older app on the doctor's side).
    final joined =
        consultation?.doctorJoinedAt != null || prescriptions.isNotEmpty;
    final doctorVideo = consultation?.doctorVideoPreferred ?? true;
    final listeners = <String>[
      for (final p
          in ref.watch(sessionPeopleProvider(_id)).valueOrNull ?? const [])
        if (p.isFamily && p.isJoined) p.name,
    ];
    final doctorName = doctor?.name ?? 'Your doctor';
    final patientName = (patient?.name.isNotEmpty ?? false)
        ? patient!.name
        : 'You';
    // Same avatars bucket; the directory repository is the one faked in
    // tests.
    final avatars = ref.watch(doctorDirectoryRepositoryProvider);
    final doctorPhoto = avatars.avatarUrl(doctor?.avatarPath);
    final myPhoto = avatars.avatarUrl(
      ref.watch(currentAppUserProvider).valueOrNull?.avatarUrl,
    );
    final cameraOff = mine?.cameraOff ?? _myCameraOff;

    if (consultation != null && !ended) {
      _sync(
        ActiveCall(
          consultationId: _id,
          isDoctor: false,
          otherName: doctorName,
          otherRole: consultation.specialtyRequested,
          otherPhotoUrl: doctorPhoto,
          selfPhotoUrl: myPhoto,
          startedAt: consultation.startedAt,
          joined: joined,
          remoteCameraOff: !doctorVideo,
          cameraOff: _myCameraOff,
        ),
      );
    }

    List<Widget> prescriptionList() => [
      if (prescriptions.isEmpty)
        _NoPrescriptionYet(ended: ended)
      else
        for (final p in prescriptions.reversed) ...[
          DigitalPrescription(
            doctorName: doctorName,
            doctorDetail: consultation?.specialtyRequested,
            patientName: patientName,
            patientAge: patient?.ageOn(p.issuedAt),
            patientGender: patient?.genderLabel,
            items: p.items,
            issuedAt: p.issuedAt.toLocal(),
            validUntil: p.validUntil,
            reference: p.id,
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => showDoseReminderSheet(context, items: p.items),
              icon: const Icon(LucideIcons.alarmClock, size: 18),
              label: const Text('Remind me to take these'),
            ),
          ),
          const SizedBox(height: 4),
          SuggestedChemistCard(prescription: p),
          const SizedBox(height: 24),
        ],
    ];

    if (ended) {
      return Scaffold(
        appBar: AppBar(title: const Text('Consultation ended')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _EndedBanner(
              doctorName: doctorName,
              chatOpen: consultation?.chatOpen ?? false,
              onSummary: () => context.pushReplacement('/patient/visit/$_id'),
              onMessage: () => context.pushReplacement('/patient/chat/$_id'),
            ),
            const SizedBox(height: 20),
            ...prescriptionList(),
          ],
        ),
      );
    }

    if (consultation == null || !joined) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          consultation == null ? _close() : _minimize();
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text(consultation == null ? 'Consultation' : 'Waiting room'),
          ),
          body: consultation == null
              ? const Center(child: DelayedHeartbeat())
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  children: [
                    _WaitingRoom(
                      doctorName: doctorName,
                      doctorAvatar: doctor?.avatarPath,
                      doctorVideo: doctorVideo,
                      myCameraOff: cameraOff,
                      onCameraChanged: (off) {
                        setState(() => _myCameraOff = off);
                        _calls.setCameraOff(off);
                      },
                      onLeave: () => _leave(context, waiting: true),
                    ),
                    const SizedBox(height: 16),
                    FamilySessionPanel(consultationId: _id),
                  ],
                ),
        ),
      );
    }

    final unseen = prescriptions.length - _seen;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _minimize();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: AppColors.ink,
          body: CallStage(
            key: _stage,
            panelTitle: prescriptions.isEmpty
                ? 'Prescription & details'
                : prescriptions.length == 1
                ? 'Your prescription'
                : 'Your prescriptions (${prescriptions.length})',
            panelIcon: prescriptions.isEmpty
                ? LucideIcons.clipboardList
                : LucideIcons.fileCheck,
            panelBadge: unseen > 0 ? '$unseen new' : null,
            onOpenChanged: (open) => setState(() {
              _panelOpen = open;
              if (open) {
                _seen = prescriptions.length;
                _rxNotice = false;
              }
            }),
            video:
                (
                  context, {
                  required panelOpen,
                  required togglePanel,
                  required topInset,
                }) => VideoCallPanel(
                  otherPartyName: doctorName,
                  otherPartyRole: consultation.specialtyRequested,
                  startedAt: consultation.startedAt,
                  listeners: listeners,
                  remoteCameraOff: !doctorVideo,
                  otherPhotoUrl: doctorPhoto,
                  selfPhotoUrl: myPhoto,
                  startWithCameraOff: cameraOff,
                  radius: 0,
                  topInset: topInset,
                  onBack: _minimize,
                  muted: mine?.muted,
                  onToggleMute: mine == null ? null : _calls.toggleMute,
                  cameraOff: mine?.cameraOff,
                  onCameraChanged: mine == null
                      ? null
                      : (off) {
                          setState(() => _myCameraOff = off);
                          _calls.setCameraOff(off);
                        },
                  speakerOn: mine?.speakerOn,
                  onToggleSpeaker: mine == null ? null : _calls.toggleSpeaker,
                  onPanel: togglePanel,
                  panelOpen: panelOpen,
                  panelBadge: unseen > 0,
                  notice: _justJoined
                      ? _JoinedPill(doctorName: doctorName)
                      : _rxNotice
                      ? _PrescriptionNotice(
                          doctorName: doctorName,
                          onView: () => _stage.currentState?.open(),
                        )
                      : null,
                  onEndCall: () => _leave(context, waiting: false),
                ),
            panel: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                ...prescriptionList(),
                const SizedBox(height: 4),
                FamilySessionPanel(consultationId: _id),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Dr X sent you a prescription · View", over the video.
class _PrescriptionNotice extends StatelessWidget {
  const _PrescriptionNotice({required this.doctorName, required this.onView});

  final String doctorName;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutBack,
      builder: (context, t, child) => Transform.scale(
        scale: 0.85 + 0.15 * t,
        child: Opacity(opacity: t.clamp(0, 1), child: child),
      ),
      child: Material(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(30),
        child: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: onView,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  LucideIcons.fileCheck,
                  size: 16,
                  color: AppColors.success,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    '$doctorName sent you a prescription',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'View',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Before the doctor opens the call: who you're waiting for, a breathing
/// circle (no spinner), a short "while you wait" list, and the camera /
/// data choice.
class _WaitingRoom extends StatefulWidget {
  const _WaitingRoom({
    required this.doctorName,
    required this.doctorAvatar,
    required this.doctorVideo,
    required this.myCameraOff,
    required this.onCameraChanged,
    required this.onLeave,
  });

  final String doctorName;
  final String? doctorAvatar;
  final bool doctorVideo;
  final bool myCameraOff;
  final ValueChanged<bool> onCameraChanged;
  final VoidCallback onLeave;

  @override
  State<_WaitingRoom> createState() => _WaitingRoomState();
}

class _WaitingRoomState extends State<_WaitingRoom>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: AnimatedBuilder(
              animation: _breath,
              builder: (context, child) {
                final t = Curves.easeInOut.transform(_breath.value);
                return Container(
                  padding: EdgeInsets.all(8 + 10 * t),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary.withValues(alpha: 0.05 + 0.07 * t),
                  ),
                  child: child,
                );
              },
              child: DoctorAvatar(
                name: widget.doctorName,
                avatarPath: widget.doctorAvatar,
                radius: 42,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '${widget.doctorName} will be with you shortly',
            textAlign: TextAlign.center,
            style: theme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'They know you\'re here. This usually takes a minute or two.',
            textAlign: TextAlign.center,
            style: theme.bodySmall,
          ),
          const SizedBox(height: 18),
          Text('While you wait', style: theme.labelLarge),
          const SizedBox(height: 6),
          const _Tip(
            icon: LucideIcons.sun,
            text: 'Sit somewhere with good light, facing it.',
          ),
          const _Tip(
            icon: LucideIcons.pill,
            text: 'Keep any medicines you\'re taking nearby.',
          ),
          const _Tip(
            icon: LucideIcons.headphones,
            text: 'Earphones help you hear, and keep it private.',
          ),
          const Divider(height: 24),
          Row(
            children: [
              Icon(
                widget.myCameraOff ? LucideIcons.videoOff : LucideIcons.video,
                size: 18,
                color: AppColors.ink,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Your camera', style: theme.titleSmall),
                    Text(
                      estimateCallData(
                        myVideo: !widget.myCameraOff,
                        theirVideo: widget.doctorVideo,
                      ),
                      style: theme.bodySmall,
                    ),
                  ],
                ),
              ),
              Switch(
                value: !widget.myCameraOff,
                onChanged: (on) => widget.onCameraChanged(!on),
              ),
            ],
          ),
          if (!widget.doctorVideo)
            Padding(
              padding: const EdgeInsets.only(top: 2, left: 28),
              child: Text(
                'The doctor\'s camera stays off, as you asked, to save data.',
                style: theme.bodySmall,
              ),
            ),
          const SizedBox(height: 6),
          Align(
            child: TextButton(
              onPressed: widget.onLeave,
              style: TextButton.styleFrom(foregroundColor: AppColors.inkSoft),
              child: const Text('Leave waiting room'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tip extends StatelessWidget {
  const _Tip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.inkSoft),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

class _JoinedPill extends StatelessWidget {
  const _JoinedPill({required this.doctorName});

  final String doctorName;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutBack,
      builder: (context, t, child) =>
          Transform.scale(scale: 0.8 + 0.2 * t, child: child),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.successSoft,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                LucideIcons.circleCheck,
                size: 16,
                color: AppColors.success,
              ),
              const SizedBox(width: 8),
              Text(
                '$doctorName joined',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoPrescriptionYet extends StatelessWidget {
  const _NoPrescriptionYet({required this.ended});

  final bool ended;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.primarySofter,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(shape: BoxShape.circle),
            child: const Icon(
              LucideIcons.fileText,
              color: AppColors.ink,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              ended
                  ? 'Your doctor did not send a prescription for this consultation.'
                  : 'If your doctor prescribes medicine, the prescription appears here '
                        'during the call, and you can order it straight away.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _EndedBanner extends StatelessWidget {
  const _EndedBanner({
    required this.doctorName,
    required this.chatOpen,
    required this.onSummary,
    required this.onMessage,
  });

  final String doctorName;
  final bool chatOpen;
  final VoidCallback onSummary;
  final VoidCallback onMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.successSoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.circleCheck, color: AppColors.success),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${LocalTouch.getWell}. Your consultation is done.',
                  style: theme.titleSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onSummary,
            icon: const Icon(LucideIcons.clipboardList, size: 18),
            label: const Text('See your visit summary'),
          ),
          if (chatOpen) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: onMessage,
              icon: const Icon(LucideIcons.messageCircle, size: 18),
              label: Text('Message $doctorName (free for 24 h)'),
            ),
          ],
        ],
      ),
    );
  }
}
