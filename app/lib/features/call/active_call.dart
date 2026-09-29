import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/prescription.dart';
import '../../data/providers/auth_providers.dart';

/// How the ongoing call is showing: its own full screen, a floating window
/// over the rest of the app, or tucked into a small tab at the screen edge.
enum CallView { full, floating, tucked }

/// The consultation call that's under way, kept above the screens so it
/// carries on while the patient (or doctor) moves around the app.
class ActiveCall {
  const ActiveCall({
    required this.consultationId,
    required this.isDoctor,
    required this.otherName,
    this.otherRole,
    this.otherPhotoUrl,
    this.selfPhotoUrl,
    this.startedAt,
    this.joined = true,
    this.remoteCameraOff = false,
    this.view = CallView.full,
    this.muted = false,
    this.cameraOff = false,
    this.speakerOn = true,
  });

  final String consultationId;
  final bool isDoctor;
  final String otherName;
  final String? otherRole;
  final String? otherPhotoUrl;
  final String? selfPhotoUrl;
  final DateTime? startedAt;

  /// False while the patient is still in the waiting room.
  final bool joined;
  final bool remoteCameraOff;
  final CallView view;
  final bool muted;
  final bool cameraOff;
  final bool speakerOn;

  String get route => isDoctor
      ? '/doctor/call/$consultationId'
      : '/patient/call/$consultationId';

  String get homeRoute => isDoctor ? '/doctor' : '/patient';

  ActiveCall copyWith({
    String? otherName,
    String? otherRole,
    String? otherPhotoUrl,
    String? selfPhotoUrl,
    DateTime? startedAt,
    bool? joined,
    bool? remoteCameraOff,
    CallView? view,
    bool? muted,
    bool? cameraOff,
    bool? speakerOn,
  }) => ActiveCall(
    consultationId: consultationId,
    isDoctor: isDoctor,
    otherName: otherName ?? this.otherName,
    otherRole: otherRole ?? this.otherRole,
    otherPhotoUrl: otherPhotoUrl ?? this.otherPhotoUrl,
    selfPhotoUrl: selfPhotoUrl ?? this.selfPhotoUrl,
    startedAt: startedAt ?? this.startedAt,
    joined: joined ?? this.joined,
    remoteCameraOff: remoteCameraOff ?? this.remoteCameraOff,
    view: view ?? this.view,
    muted: muted ?? this.muted,
    cameraOff: cameraOff ?? this.cameraOff,
    speakerOn: speakerOn ?? this.speakerOn,
  );

  /// Same people and moment (ignores the view and the buttons).
  bool sameInfo(ActiveCall o) =>
      consultationId == o.consultationId &&
      isDoctor == o.isDoctor &&
      otherName == o.otherName &&
      otherRole == o.otherRole &&
      otherPhotoUrl == o.otherPhotoUrl &&
      selfPhotoUrl == o.selfPhotoUrl &&
      startedAt == o.startedAt &&
      joined == o.joined &&
      remoteCameraOff == o.remoteCameraOff;
}

class ActiveCallController extends StateNotifier<ActiveCall?> {
  ActiveCallController() : super(null);

  /// The call screen is showing [info]: keep the buttons as they were
  /// (mute, camera) when it's the same call, and mark it full screen.
  void showing(ActiveCall info) {
    final now = state;
    if (now == null || now.consultationId != info.consultationId) {
      state = info.copyWith(view: CallView.full);
      return;
    }
    if (now.sameInfo(info) && now.view == CallView.full) return;
    state = now.copyWith(
      otherName: info.otherName,
      otherRole: info.otherRole,
      otherPhotoUrl: info.otherPhotoUrl,
      selfPhotoUrl: info.selfPhotoUrl,
      startedAt: info.startedAt,
      joined: info.joined,
      remoteCameraOff: info.remoteCameraOff,
      view: CallView.full,
    );
  }

  void _view(CallView v) {
    final now = state;
    if (now != null && now.view != v) state = now.copyWith(view: v);
  }

  /// Leave the call screen but keep the call going, in a floating window.
  void minimize() => _view(CallView.floating);

  /// Out of the way: a small tab at the edge of the screen.
  void tuck() => _view(CallView.tucked);

  /// Back on the call screen.
  void expand() => _view(CallView.full);

  /// The call screen closed some other way (e.g. a notification opened
  /// another page): the call goes on in the floating window.
  void screenClosed(String consultationId) {
    // Runs just after the screen goes; the app may have closed with it.
    if (!mounted) return;
    final now = state;
    if (now != null &&
        now.consultationId == consultationId &&
        now.view == CallView.full) {
      state = now.copyWith(view: CallView.floating);
    }
  }

  /// The doctor opened the call while the patient was in the waiting room.
  void markJoined() {
    final now = state;
    if (now != null && !now.joined) state = now.copyWith(joined: true);
  }

  void toggleMute() {
    final now = state;
    if (now != null) state = now.copyWith(muted: !now.muted);
  }

  void setCameraOff(bool off) {
    final now = state;
    if (now != null && now.cameraOff != off) {
      state = now.copyWith(cameraOff: off);
    }
  }

  void toggleSpeaker() {
    final now = state;
    if (now != null) state = now.copyWith(speakerOn: !now.speakerOn);
  }

  /// The call is over (or the patient left).
  void end([String? consultationId]) {
    if (consultationId == null || state?.consultationId == consultationId) {
      state = null;
    }
  }
}

final activeCallProvider =
    StateNotifierProvider<ActiveCallController, ActiveCall?>((ref) {
      final controller = ActiveCallController();
      // Signing out ends any call on this phone.
      ref.listen(currentUserIdProvider, (prev, next) {
        if (next == null) controller.end();
      });
      return controller;
    });

/// A doctor's unsent prescription, per consultation, kept while they step
/// away from the call screen (the call carries on in a floating window).
class PrescriptionDraftStore {
  PrescriptionDraftStore._();

  static final _drafts = <String, List<PrescriptionItem>>{};

  static List<PrescriptionItem> of(String consultationId) =>
      _drafts.putIfAbsent(consultationId, () => <PrescriptionItem>[]);

  static void clear(String consultationId) => _drafts.remove(consultationId);
}
