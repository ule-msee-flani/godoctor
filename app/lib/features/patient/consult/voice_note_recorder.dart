import 'dart:async';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:share_plus/share_plus.dart' show XFile;

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/motion.dart';

/// A finished recording, ready to upload.
class VoiceRecording {
  const VoiceRecording({
    required this.bytes,
    required this.fileExt,
    required this.contentType,
    required this.length,
  });

  final Uint8List bytes;
  final String fileExt;
  final String contentType;
  final Duration length;
}

/// "Prefer to say it? Record a voice note" -- up to 90 seconds, which the
/// doctor can play before the call. Optional.
class VoiceNoteRecorder extends StatefulWidget {
  const VoiceNoteRecorder({super.key, required this.onChanged});

  final ValueChanged<VoiceRecording?> onChanged;

  @override
  State<VoiceNoteRecorder> createState() => _VoiceNoteRecorderState();
}

enum _Stage { idle, recording, recorded }

class _VoiceNoteRecorderState extends State<VoiceNoteRecorder> {
  static const _max = Duration(seconds: 90);

  final _recorder = AudioRecorder();
  final _player = AudioPlayer();
  StreamSubscription<PlayerState>? _playerSub;
  _Stage _stage = _Stage.idle;
  Timer? _ticker;
  DateTime? _startedAt;
  Duration _elapsed = Duration.zero;
  String? _path;
  bool _playing = false;
  String? _error;

  /// Recent loudness (0..1) for the live waveform.
  final List<double> _levels = List.filled(22, 0.05, growable: true);
  StreamSubscription<Amplitude>? _ampSub;

  @override
  void initState() {
    super.initState();
    _playerSub = _player.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _playing = s == PlayerState.playing);
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _ampSub?.cancel();
    _playerSub?.cancel();
    _player.dispose();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() => _error = null);
    try {
      if (!await _recorder.hasPermission()) {
        setState(() => _error = 'Allow the microphone to record a voice note.');
        return;
      }
      final encoder = kIsWeb ? AudioEncoder.opus : AudioEncoder.aacLc;
      final path = kIsWeb
          ? ''
          : '${(await getTemporaryDirectory()).path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(
        RecordConfig(encoder: encoder, bitRate: 32000, numChannels: 1),
        path: path,
      );
      _startedAt = DateTime.now();
      _ampSub = _recorder
          .onAmplitudeChanged(const Duration(milliseconds: 110))
          .listen((a) {
            if (!mounted) return;
            // dBFS: about -50 is quiet room, 0 is as loud as it gets.
            final level = ((a.current + 50) / 50).clamp(0.05, 1.0);
            setState(() {
              _levels
                ..removeAt(0)
                ..add(level);
            });
          });
      _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
        final e = DateTime.now().difference(_startedAt!);
        if (e >= _max) {
          _stop();
        } else if (mounted) {
          setState(() => _elapsed = e);
        }
      });
      setState(() {
        _stage = _Stage.recording;
        _elapsed = Duration.zero;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Recording isn\'t available on this device.');
      }
    }
  }

  Future<void> _stop() async {
    _ticker?.cancel();
    await _ampSub?.cancel();
    _ampSub = null;
    try {
      final path = await _recorder.stop();
      if (path == null) throw StateError('no recording');
      final bytes = await XFile(path).readAsBytes();
      _path = path;
      setState(() => _stage = _Stage.recorded);
      widget.onChanged(
        VoiceRecording(
          bytes: bytes,
          fileExt: kIsWeb ? 'webm' : 'm4a',
          contentType: kIsWeb ? 'audio/webm' : 'audio/mp4',
          length: _elapsed,
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _stage = _Stage.idle;
          _error = 'Could not save the recording. Please try again.';
        });
      }
    }
  }

  Future<void> _discard() async {
    await _player.stop();
    setState(() {
      _stage = _Stage.idle;
      _path = null;
      _elapsed = Duration.zero;
    });
    widget.onChanged(null);
  }

  Future<void> _togglePlay() async {
    if (_playing) {
      await _player.pause();
    } else if (_path != null) {
      await _player.play(kIsWeb ? UrlSource(_path!) : DeviceFileSource(_path!));
    }
  }

  String _fmt(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final Widget body = switch (_stage) {
      _Stage.idle => OutlinedButton.icon(
        onPressed: _start,
        icon: const Icon(LucideIcons.mic, size: 18),
        label: const Text('Prefer to say it? Record a voice note'),
      ),
      _Stage.recording => Container(
        padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
        decoration: BoxDecoration(
          color: AppColors.dangerSoft,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          children: [
            const _RecDot(),
            const SizedBox(width: 10),
            Text(
              _fmt(_elapsed),
              style: theme.titleSmall?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ClipRect(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: VoiceWaveform(levels: List.of(_levels)),
                ),
              ),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.danger,
                minimumSize: const Size(0, 38),
              ),
              onPressed: _stop,
              icon: const Icon(LucideIcons.square, size: 14),
              label: const Text('Stop'),
            ),
          ],
        ),
      ),
      _Stage.recorded => Container(
        padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
        decoration: BoxDecoration(
          color: AppColors.primarySofter,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            IconButton.filled(
              tooltip: _playing ? 'Pause' : 'Play',
              onPressed: _togglePlay,
              icon: Icon(
                _playing ? LucideIcons.pause : LucideIcons.play,
                size: 18,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Voice note · ${_fmt(_elapsed)}',
                style: theme.titleSmall,
              ),
            ),
            IconButton(
              tooltip: 'Delete voice note',
              onPressed: _discard,
              icon: const Icon(LucideIcons.trash2, size: 18),
            ),
          ],
        ),
      ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: KeyedSubtree(key: ValueKey(_stage), child: body),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              _error!,
              style: theme.bodySmall?.copyWith(color: AppColors.danger),
            ),
          ),
      ],
    );
  }
}

class _RecDot extends StatefulWidget {
  const _RecDot();

  @override
  State<_RecDot> createState() => _RecDotState();
}

class _RecDotState extends State<_RecDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: Tween(begin: 0.35, end: 1.0).animate(_c),
    child: Container(
      width: 10,
      height: 10,
      decoration: const BoxDecoration(
        color: AppColors.danger,
        shape: BoxShape.circle,
      ),
    ),
  );
}
