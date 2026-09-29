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
import '../../medications/dose_reminder_sheet.dart';
import '../../prescription/digital_prescription.dart';
import '../../prescription/suggested_chemist_card.dart';
import '../family/family_providers.dart';
import '../family/family_session_panel.dart';
import '../widgets/doctor_widgets.dart';
import 'doctor_profile_screen.dart' show publicDoctorProvider;
import '../widgets/review_sheet.dart';
import '../../../data/providers/repository_providers.dart';

/// The patient's side of the consultation. Until the doctor opens the call
/// the patient waits in a calm waiting room (with a camera / data choice);
/// when the doctor joins there's a small moment (a tap of haptics and a
/// "joined" pill) and the (mock) video call takes over. Below it, any
/// prescription the doctor sends appears live with a suggested chemist.
class PatientCallScreen extends ConsumerStatefulWidget {
  const PatientCallScreen({super.key, required this.consultationId});

  final String consultationId;

  @override
  ConsumerState<PatientCallScreen> createState() => _PatientCallScreenState();
}

class _PatientCallScreenState extends ConsumerState<PatientCallScreen> {
  late bool _myCameraOff = ref.read(dataSaverProvider);
  bool _justJoined = false;
  Timer? _joinedTimer;

  String get _id => widget.consultationId;

  @override
  void dispose() {
    _joinedTimer?.cancel();
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

  void _visitEnded() {
    if (!mounted) return;
    final router = GoRouter.of(context);
    final doctorId = ref.read(appointmentProvider(_id)).valueOrNull?.doctorId;
    final doctor = doctorId == null
        ? null
        : ref.read(publicDoctorProvider(doctorId)).valueOrNull?.name;
    HapticFeedback.lightImpact();
    router.go('/patient');
    // On Home, ask how it went while it's fresh; the summary is one tap
    // away (and stays on Home under "Your visits").
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final home = router.routerDelegate.navigatorKey.currentContext;
      if (home == null || !home.mounted) return;
      final rated = await showReviewSheet(
        home,
        consultationId: _id,
        doctorName: doctor ?? 'your doctor',
        extra: (
          label: 'Not now — see the visit summary',
          onTap: () => router.push('/patient/visit/$_id'),
        ),
      );
      if (rated && home.mounted) {
        ScaffoldMessenger.of(home).showSnackBar(
          SnackBar(
            content: const Text('Thanks for your review. Get well soon!'),
            action: SnackBarAction(
              label: 'Summary',
              onPressed: () => router.push('/patient/visit/$_id'),
            ),
          ),
        );
      }
    });
  }

  Future<void> _leave(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave the call?'),
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
    if (ok == true && context.mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
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
    final consultation = ref.watch(appointmentProvider(_id)).value;
    final doctor = consultation?.doctorId == null
        ? null
        : ref.watch(publicDoctorProvider(consultation!.doctorId!)).value;
    final prescriptions =
        ref.watch(consultationPrescriptionsProvider(_id)).value ??
        const <Prescription>[];
    final patient = ref.watch(currentPatientProfileProvider).value;

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

    final Widget top;
    if (ended) {
      top = _EndedBanner(
        key: const ValueKey('ended'),
        doctorName: doctorName,
        chatOpen: consultation?.chatOpen ?? false,
        onSummary: () => context.pushReplacement('/patient/visit/$_id'),
        onMessage: () => context.pushReplacement('/patient/chat/$_id'),
      );
    } else if (consultation == null) {
      top = const SizedBox(
        key: ValueKey('loading'),
        height: 240,
        child: Center(child: DelayedHeartbeat()),
      );
    } else if (!joined) {
      top = _WaitingRoom(
        key: const ValueKey('waiting'),
        doctorName: doctorName,
        doctorAvatar: doctor?.avatarPath,
        doctorVideo: doctorVideo,
        myCameraOff: _myCameraOff,
        onCameraChanged: (off) => setState(() => _myCameraOff = off),
        onLeave: () => _leave(context),
      );
    } else {
      top = Column(
        key: const ValueKey('call'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            child: _justJoined
                ? Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _JoinedPill(doctorName: doctorName),
                  )
                : const SizedBox(width: double.infinity),
          ),
          VideoCallPanel(
            otherPartyName: doctorName,
            otherPartyRole: consultation.specialtyRequested,
            startedAt: consultation.startedAt,
            height: (MediaQuery.sizeOf(context).height * 0.52).clamp(
              260.0,
              470.0,
            ),
            listeners: listeners,
            remoteCameraOff: !doctorVideo,
            otherPhotoUrl: ref
                .watch(doctorDirectoryRepositoryProvider)
                .avatarUrl(doctor?.avatarPath),
            // Same avatars bucket; the directory repository is the one faked
            // in tests.
            selfPhotoUrl: ref
                .watch(doctorDirectoryRepositoryProvider)
                .avatarUrl(
                  ref.watch(currentAppUserProvider).valueOrNull?.avatarUrl,
                ),
            startWithCameraOff: _myCameraOff,
            onEndCall: () => _leave(context),
          ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          ended
              ? 'Consultation ended'
              : joined || consultation == null
              ? 'Consultation'
              : 'Waiting room',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 420),
            switchInCurve: Curves.easeOutCubic,
            transitionBuilder: (child, a) => FadeTransition(
              opacity: a,
              child: ScaleTransition(
                scale: Tween(begin: 0.96, end: 1.0).animate(a),
                child: child,
              ),
            ),
            child: top,
          ),
          if (!ended) ...[
            const SizedBox(height: 16),
            FamilySessionPanel(consultationId: _id),
          ],
          if (joined || ended) ...[
            const SizedBox(height: 20),
            if (prescriptions.isEmpty)
              _NoPrescriptionYet(ended: ended)
            else ...[
              Row(
                children: [
                  const Icon(
                    LucideIcons.fileCheck,
                    size: 18,
                    color: AppColors.success,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      prescriptions.length == 1
                          ? 'Your prescription'
                          : 'Your prescriptions (${prescriptions.length})',
                      style: theme.titleMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
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
                    onPressed: () =>
                        showDoseReminderSheet(context, items: p.items),
                    icon: const Icon(LucideIcons.alarmClock, size: 18),
                    label: const Text('Remind me to take these'),
                  ),
                ),
                const SizedBox(height: 4),
                SuggestedChemistCard(prescription: p),
                const SizedBox(height: 24),
              ],
            ],
          ],
        ],
      ),
    );
  }
}

/// Before the doctor opens the call: who you're waiting for, a breathing
/// circle (no spinner), a short "while you wait" list, and the camera /
/// data choice.
class _WaitingRoom extends StatefulWidget {
  const _WaitingRoom({
    super.key,
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
    super.key,
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
