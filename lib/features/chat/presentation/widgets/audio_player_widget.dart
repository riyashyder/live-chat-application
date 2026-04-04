import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:chat_app/core/theme/app_colors.dart';
import 'package:chat_app/core/utils/date_formatter.dart';

class AudioPlayerWidget extends StatefulWidget {
  final String audioUrl;
  final int? durationInSeconds;
  final bool isMe;
  final bool isLocal;

  const AudioPlayerWidget({
    super.key,
    required this.audioUrl,
    this.durationInSeconds,
    this.isMe = false,
    this.isLocal = false,
  });

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    if (widget.durationInSeconds != null) {
      _duration = Duration(seconds: widget.durationInSeconds!);
    }

    _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });

    _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });

    _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
        });
      }
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await _player.pause();
    } else {
      final Source source =
          widget.isLocal ? DeviceFileSource(widget.audioUrl) : UrlSource(widget.audioUrl);
      await _player.play(source);
    }
    setState(() => _isPlaying = !_isPlaying);
  }

  @override
  Widget build(BuildContext context) {
    final iconColor = widget.isMe ? Colors.white : AppColors.primary;
    final trackColor = widget.isMe
        ? Colors.white.withValues(alpha: 0.3)
        : AppColors.primary.withValues(alpha: 0.2);
    final activeColor = widget.isMe ? Colors.white : AppColors.primary;
    final textColor = widget.isMe
        ? Colors.white.withValues(alpha: 0.8)
        : Theme.of(context).textTheme.bodyMedium?.color;

    final progress = _duration.inMilliseconds > 0
        ? _position.inMilliseconds / _duration.inMilliseconds
        : 0.0;

    return SizedBox(
      width: 200,
      child: Row(
        children: [
          GestureDetector(
            onTap: _togglePlay,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: iconColor,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Waveform / Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: trackColor,
                    valueColor: AlwaysStoppedAnimation(activeColor),
                    minHeight: 4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isPlaying
                      ? DateFormatter.formatDuration(_position)
                      : DateFormatter.formatDuration(_duration),
                  style: TextStyle(
                    color: textColor,
                    fontSize: 11,
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
