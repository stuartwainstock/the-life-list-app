import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/xeno_canto_recording.dart';
import '../theme/app_spacing.dart';

/// Songs & Calls block for species detail — one Song and/or Call row.
///
/// Hidden entirely when neither recording resolved
/// (`docs/tickets/xeno-canto-audio.md`).
class SongsAndCallsSection extends StatefulWidget {
  final XenoCantoRecording? song;
  final XenoCantoRecording? call;

  const SongsAndCallsSection({
    super.key,
    this.song,
    this.call,
  });

  @override
  State<SongsAndCallsSection> createState() => _SongsAndCallsSectionState();
}

class _SongsAndCallsSectionState extends State<SongsAndCallsSection> {
  final _player = AudioPlayer();
  StreamSubscription<PlayerState>? _stateSub;
  String? _activeUrl;
  bool _playing = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _stateSub = _player.playerStateStream.listen((state) {
      if (!mounted) return;
      if (state.processingState == ProcessingState.completed) {
        setState(() {
          _playing = false;
          _activeUrl = null;
        });
        return;
      }
      setState(() => _playing = state.playing);
    });
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle(XenoCantoRecording recording) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (_activeUrl == recording.fileUrl && _playing) {
        await _player.pause();
        return;
      }

      if (_activeUrl != recording.fileUrl) {
        await _player.setUrl(recording.fileUrl);
        _activeUrl = recording.fileUrl;
      }
      await _player.play();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Couldn’t play that recording')),
      );
      setState(() {
        _playing = false;
        _activeUrl = null;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final song = widget.song;
    final call = widget.call;
    if (song == null && call == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Songs & Calls',
          style: theme.textTheme.titleSmall?.copyWith(
            color: scheme.primary,
            letterSpacing: 0.3,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (song != null)
          _RecordingRow(
            label: 'Song',
            recording: song,
            isPlaying: _playing && _activeUrl == song.fileUrl,
            onPlayPause: () => _toggle(song),
          ),
        if (call != null)
          _RecordingRow(
            label: 'Call',
            recording: call,
            isPlaying: _playing && _activeUrl == call.fileUrl,
            onPlayPause: () => _toggle(call),
          ),
      ],
    );
  }
}

class _RecordingRow extends StatelessWidget {
  final String label;
  final XenoCantoRecording recording;
  final bool isPlaying;
  final VoidCallback onPlayPause;

  const _RecordingRow({
    required this.label,
    required this.recording,
    required this.isPlaying,
    required this.onPlayPause,
  });

  Future<void> _openLicense() async {
    final uri = Uri.tryParse(recording.licenseUrl);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            onPressed: onPlayPause,
            tooltip: isPlaying ? 'Pause $label' : 'Play $label',
            icon: Icon(isPlaying ? Icons.pause_circle : Icons.play_circle),
            color: scheme.primary,
            iconSize: 36,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                // Same muted credit treatment as the hero photo attribution.
                GestureDetector(
                  onTap: _openLicense,
                  child: Text(
                    '${recording.attributionText} · Xeno-canto',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.25,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
