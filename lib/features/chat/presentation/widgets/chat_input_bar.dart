import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:chat_app/core/theme/app_colors.dart';
import 'package:chat_app/core/utils/date_formatter.dart';
import 'package:chat_app/features/chat/presentation/widgets/audio_player_widget.dart';
import 'package:flutter_animate/flutter_animate.dart';

class ChatInputBar extends StatefulWidget {
  final Function(String) onSendText;
  final Function(File) onSendImage;
  final Function(File audioFile, int durationSeconds) onSendAudio;
  final Function(String) onTypingChanged;

  const ChatInputBar({
    super.key,
    required this.onSendText,
    required this.onSendImage,
    required this.onSendAudio,
    required this.onTypingChanged,
  });

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar>
    with TickerProviderStateMixin {
  final _textController = TextEditingController();
  final _focusNode = FocusNode();
  bool _hasText = false;
  bool _isRecording = false;
  bool _showEmojiPicker = false;
  String? _voicePath;
  bool _isVoicePreviewMode = false;
  int _voiceDuration = 0;

  final AudioRecorder _recorder = AudioRecorder();
  Timer? _recordTimer;
  int _recordSeconds = 0;

  @override
  void initState() {
    super.initState();
    _textController.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final hasText = _textController.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }
    widget.onTypingChanged(_textController.text);
  }

  Future<void> _pickImage() async {
    _showAttachmentOptions();
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Send Attachment',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildAttachmentItem(
                  icon: Icons.camera_alt_rounded,
                  label: 'Camera',
                  color: Colors.blue,
                  onTap: () {
                    Navigator.pop(context);
                    _pickImageFromSource(ImageSource.camera);
                  },
                ),
                _buildAttachmentItem(
                  icon: Icons.image_rounded,
                  label: 'Gallery',
                  color: Colors.purple,
                  onTap: () {
                    Navigator.pop(context);
                    _pickImageFromSource(ImageSource.gallery);
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ).animate().slideY(begin: 1, end: 0, duration: 200.ms, curve: Curves.easeOut),
    );
  }

  Widget _buildAttachmentItem({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Future<void> _pickImageFromSource(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
    );
    if (picked != null) {
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: picked.path,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Image',
            toolbarColor: AppColors.primary,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
          ),
          IOSUiSettings(
            title: 'Crop Image',
          ),
        ],
      );
      if (croppedFile != null) {
        widget.onSendImage(File(croppedFile.path));
      }
    }
  }

  Future<void> _startRecording() async {
    if (await _recorder.hasPermission()) {
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path,
      );

      setState(() {
        _isRecording = true;
        _recordSeconds = 0;
      });

      _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() => _recordSeconds++);
      });
    }
  }

  Future<void> _stopRecording() async {
    _recordTimer?.cancel();
    final path = await _recorder.stop();
    setState(() {
      _isRecording = false;
    });

    if (path != null && _recordSeconds > 0) {
      setState(() {
        _voicePath = path;
        _voiceDuration = _recordSeconds;
        _isVoicePreviewMode = true;
      });
    }
  }

  void _deleteVoicePreview() {
    if (_voicePath != null) {
      File(_voicePath!).delete().catchError((_) => File(_voicePath!));
    }
    setState(() {
      _voicePath = null;
      _isVoicePreviewMode = false;
      _voiceDuration = 0;
      _recordSeconds = 0;
    });
  }

  void _sendVoicePreview() {
    if (_voicePath != null) {
      widget.onSendAudio(File(_voicePath!), _voiceDuration);
      setState(() {
        _voicePath = null;
        _isVoicePreviewMode = false;
        _voiceDuration = 0;
        _recordSeconds = 0;
      });
    }
  }

  Future<void> _cancelRecording() async {
    _recordTimer?.cancel();
    final path = await _recorder.stop();
    if (path != null) {
      File(path).delete().catchError((_) => File(path));
    }
    setState(() {
      _isRecording = false;
      _recordSeconds = 0;
    });
  }

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isNotEmpty) {
      widget.onSendText(text);
      _textController.clear();
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    _recorder.dispose();
    _recordTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: !_showEmojiPicker,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _showEmojiPicker) {
          setState(() => _showEmojiPicker = false);
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.only(
              left: 12,
              right: 12,
              top: 8,
              bottom: MediaQuery.of(context).padding.bottom + 12,
            ),
            decoration: BoxDecoration(
              color: Colors.transparent, // Floating feel
            ),
            child: _isRecording
                ? _buildRecordingBar(isDark)
                : _isVoicePreviewMode
                    ? _buildVoicePreviewBar(isDark)
                    : _buildInputBar(isDark),
          ),
          if (_showEmojiPicker)
            Container(
              height: 280,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: EmojiPicker(
                onEmojiSelected: (category, emoji) {
                  _textController.text += emoji.emoji;
                  _onTextChanged();
                },
                config: Config(
                  height: 256,
                  emojiViewConfig: EmojiViewConfig(
                    backgroundColor:
                        isDark ? AppColors.darkSurface : AppColors.lightSurface,
                  ),
                ),
              ),
            ).animate().slideY(begin: 1, end: 0, duration: 250.ms),
        ],
      ),
    );
  }

  Widget _buildRecordingBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: _cancelRecording,
            icon: const Icon(Icons.delete_outline, color: AppColors.error),
          ).animate().shake(),
          const SizedBox(width: 8),
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              color: AppColors.error,
              shape: BoxShape.circle,
            ),
          ).animate(onPlay: (controller) => controller.repeat(reverse: true))
           .scale(begin: const Offset(0.8, 0.8), end: const Offset(1.2, 1.2), duration: 600.ms),
          const SizedBox(width: 8),
          Text(
            DateFormatter.formatDuration(Duration(seconds: _recordSeconds)),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Text(
            'Recording...',
            style: TextStyle(
              color: AppColors.error.withValues(alpha: 0.8),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ).animate(onPlay: (controller) => controller.repeat(reverse: true))
           .fadeIn(duration: 1.seconds),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _stopRecording,
            child: Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                gradient: AppColors.primaryGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
          ).animate().scale(duration: 200.ms),
        ],
      ),
    ).animate().slideY(begin: 0.5, end: 0, duration: 200.ms);
  }

  Widget _buildVoicePreviewBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: _deleteVoicePreview,
            icon: const Icon(Icons.delete_outline, color: AppColors.error),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.mic, color: AppColors.primary, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: AudioPlayerWidget(
              audioUrl: _voicePath!,
              durationInSeconds: _voiceDuration,
              isMe: true,
              isLocal: true,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _sendVoicePreview,
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                gradient: AppColors.primaryGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.send_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
    ).animate().slideX(begin: 0.2, end: 0, duration: 200.ms);
  }

  Widget _buildInputBar(bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Attachment Button
        Container(
          margin: const EdgeInsets.only(bottom: 2),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.lightSurface,
            shape: BoxShape.circle,
            border: !isDark 
              ? Border.all(color: AppColors.lightBorder, width: 0.5)
              : null,
            boxShadow: isDark ? [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ] : null,
          ),
          child: IconButton(
            onPressed: _pickImage,
            icon: Icon(
              Icons.add_rounded,
              color: AppColors.primary,
              size: 28,
            ),
          ),
        ).animate().scale(duration: 200.ms),
        const SizedBox(width: 8),
        
        // Input Field
        Expanded(
          child: Container(
            constraints: const BoxConstraints(maxHeight: 120),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.lightSurface,
              borderRadius: BorderRadius.circular(28),
              border: !isDark 
                ? Border.all(color: AppColors.lightBorder, width: 0.5)
                : null,
              boxShadow: isDark ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ] : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _showEmojiPicker = !_showEmojiPicker;
                        if (_showEmojiPicker) {
                          _focusNode.unfocus();
                        }
                      });
                    },
                    icon: Icon(
                      _showEmojiPicker
                          ? Icons.keyboard_rounded
                          : Icons.emoji_emotions_outlined,
                      color: Colors.grey[600],
                      size: 24,
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      focusNode: _focusNode,
                      maxLines: null,
                      textCapitalization: TextCapitalization.sentences,
                      onTap: () {
                        if (_showEmojiPicker) {
                          setState(() => _showEmojiPicker = false);
                        }
                      },
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 12,
                        ),
                        hintStyle: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 16,
                        ),
                      ),
                      style: TextStyle(
                        fontSize: 16,
                        color: isDark ? AppColors.darkText : AppColors.lightText,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        
        // Send/Record Button
        GestureDetector(
          onTap: _hasText ? _sendMessage : null,
          onLongPressStart: (_) => !_hasText ? _startRecording() : null,
          onLongPressEnd: (_) => !_hasText ? _stopRecording() : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: _hasText ? AppColors.primaryGradient : null,
              color: !_hasText
                  ? (isDark ? AppColors.darkCard : AppColors.lightSurface)
                  : null,
              shape: BoxShape.circle,
              border: !_hasText && !isDark
                  ? Border.all(color: AppColors.lightBorder, width: 0.5)
                  : null,
              boxShadow: [
                BoxShadow(
                  color: _hasText 
                    ? AppColors.primary.withValues(alpha: 0.3)
                    : (isDark ? Colors.black.withValues(alpha: 0.05) : Colors.transparent),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              _hasText ? Icons.send_rounded : Icons.mic_rounded,
              color: _hasText ? Colors.white : AppColors.primary,
              size: 24,
            ),
          ),
        ).animate(target: _hasText ? 1 : 0)
         .scale(begin: const Offset(1, 1), end: const Offset(1.1, 1.1), duration: 150.ms),
      ],
    );
  }
}
