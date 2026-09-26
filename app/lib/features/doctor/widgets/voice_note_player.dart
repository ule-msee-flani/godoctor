import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/providers/repository_providers.dart';

/// Plays the voice note a patient recorded with their symptoms.
class VoiceNotePlayer extends ConsumerStatefulWidget {
  const VoiceNotePlayer({super.key, required this.path});

  /// Path in the private `voice-notes` bucket.
  final String path;

  @override
  ConsumerState<VoiceNotePlayer> createState() => _VoiceNotePlayerState();
}

class _VoiceNotePlayerState extends ConsumerState<VoiceNotePlayer> {
  final _player = AudioPlayer();
  final _subs = <StreamSubscription<dynamic>>[];
  PlayerState _state = PlayerState.stopped;
  Duration _position = Duration.zero;
  Duration? _duration;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _subs
      ..add(
        _player.onPlayerStateChanged.listen((s) {
          if (mounted) setState(() => _state = s);
        }),
      )
      ..add(
        _player.onPositionChanged.listen((p) {
          if (mounted) setState(() => _position = p);
        }),
      )
      ..add(
        _player.onDurationChanged.listen((d) {
          if (mounted) setState(() => _duration = d);
        }),
      );
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_state == PlayerState.playing) {
      await _player.pause();
      return;
    }
    if (_state == PlayerState.paused) {
      await _player.resume();
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final url = await ref
          .read(consultationRepositoryProvider)
          .voiceNoteUrl(widget.path);
      await _player.play(UrlSource(url));
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not play the voice note.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _fmt(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final total = _duration ?? Duration.zero;
    final progress = total.inMilliseconds == 0
        ? 0.0
        : (_position.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
      decoration: BoxDecoration(
        color: AppColors.primarySofter,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          IconButton.filled(
            tooltip: _state == PlayerState.playing ? 'Pause' : 'Play',
            onPressed: _loading ? null : _toggle,
            icon: Icon(
              _state == PlayerState.playing
                  ? LucideIcons.pause
                  : LucideIcons.play,
              size: 18,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _error ?? 'Voice note from the patient',
                  style: theme.labelMedium?.copyWith(
                    color: _error == null ? AppColors.ink : AppColors.danger,
                  ),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 4,
                    backgroundColor: AppColors.border,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            _duration == null ? '' : _fmt(total - _position),
            style: theme.bodySmall,
          ),
        ],
      ),
    );
  }
}
