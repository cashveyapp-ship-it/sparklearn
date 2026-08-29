import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_card.dart';
import '../../providers/ai_tutor_provider.dart';
import '../../providers/user_profile_provider.dart';
import '../../providers/student_provider.dart';
import '../../services/ai_tutor_service.dart';
import '../../services/tts_service.dart';
import '../../services/stt_service.dart';

class AiTutorScreen extends ConsumerStatefulWidget {
  const AiTutorScreen({super.key});

  @override
  ConsumerState<AiTutorScreen> createState() => _AiTutorScreenState();
}

class _AiTutorScreenState extends ConsumerState<AiTutorScreen> {
  final _ctrl = TextEditingController();
  bool _voiceMode = true;
  bool _sending = false;

  late final TtsService _tts;
  late final SttService _stt;

  @override
  void initState() {
    super.initState();
    _tts = TtsService()..init();
    _stt = SttService()..init();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _tts.dispose();
    _stt.dispose();
    super.dispose();
  }

  Future<void> _send(AiTutorService svc, String studentId, double readingLevel,
      int lastAccuracyPct) async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    _ctrl.clear();

    try {
      final ctx = svc.buildContext(
        readingLevel: readingLevel,
        lastAccuracyPct: lastAccuracyPct,
        inputMode: _voiceMode ? 'voice' : 'text',
      );
      await svc.sendMessage(studentId: studentId, text: text, context: ctx);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not reach AI Tutor. Check your connection.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      // Always reset spinner
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider).asData?.value;
    if (profile == null)
      return const Center(child: CircularProgressIndicator());
    final studentId = profile.uid;

    final student = ref.watch(studentDocProvider(studentId)).asData?.value;
    final readingLevel = student?.readingLevel ?? 3.9;
    final lastAcc = 72;

    final svc = ref.watch(aiTutorServiceProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 6, 18, 0),
          child: AppCard(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.indigo.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.smart_toy_rounded,
                      color: AppColors.indigo),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('AI Tutor',
                          style: TextStyle(fontWeight: FontWeight.w900)),
                      SizedBox(height: 2),
                      Text('Online',
                          style: TextStyle(
                              color: AppColors.green,
                              fontSize: 12,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: _voiceMode ? 'Voice mode' : 'Typing mode',
                  onPressed: () => setState(() => _voiceMode = !_voiceMode),
                  icon: Icon(
                      _voiceMode ? Icons.mic_rounded : Icons.keyboard_rounded,
                      color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: svc.messageStream(studentId),
            builder: (context, snap) {
              final docs = snap.data?.docs ?? [];
              return ListView.builder(
                reverse: true,
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
                itemCount: docs.length + 1,
                itemBuilder: (context, i) {
                  if (i == docs.length) {
                    return AppCard(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: const [
                          Icon(Icons.lightbulb_outline, color: AppColors.coral),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Let\'s work on reading together. What would you like to learn about today?',
                              style: TextStyle(color: AppColors.textMuted),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final m = docs[i].data();
                  final role = (m['role'] ?? 'user') as String;
                  final text = (m['text'] ?? '') as String;

                  return _ChatBubble(
                    isUser: role == 'user',
                    text: text,
                    onSpeak:
                        role == 'assistant' ? () => _tts.speak(text) : null,
                  );
                },
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
            child: Row(
              children: [
                if (_voiceMode)
                  _MicButton(
                      stt: _stt,
                      onResult: (heard) {
                        _ctrl.text = heard;
                        setState(() {});
                      })
                else
                  const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    minLines: 1,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: 'Ask me anything…',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                FloatingActionButton(
                  backgroundColor: AppColors.indigo,
                  onPressed: _sending
                      ? null
                      : () => _send(svc, studentId, readingLevel, lastAcc),
                  child: _sending
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send_rounded, color: Colors.white),
                ),
              ],
            ),
          ),
        )
      ],
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.isUser, required this.text, this.onSpeak});

  final bool isUser;
  final String text;
  final VoidCallback? onSpeak;

  @override
  Widget build(BuildContext context) {
    final bg = isUser ? AppColors.indigo : Colors.white;
    final fg = isUser ? Colors.white : AppColors.text;
    final align = isUser ? Alignment.centerRight : Alignment.centerLeft;
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(18),
      topRight: const Radius.circular(18),
      bottomLeft: Radius.circular(isUser ? 18 : 6),
      bottomRight: Radius.circular(isUser ? 6 : 18),
    );

    return Align(
      alignment: align,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: radius,
          border: isUser ? null : Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
                child: Text(text, style: TextStyle(color: fg, height: 1.25))),
            if (onSpeak != null) ...[
              const SizedBox(width: 8),
              InkWell(
                onTap: onSpeak,
                child: const Icon(Icons.volume_up_rounded,
                    size: 18, color: AppColors.textMuted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Mic button with listening state ──────────────────────────────────────────

class _MicButton extends StatefulWidget {
  const _MicButton({required this.stt, required this.onResult});
  final SttService stt;
  final void Function(String) onResult;

  @override
  State<_MicButton> createState() => _MicButtonState();
}

class _MicButtonState extends State<_MicButton> {
  bool _listening = false;

  Future<void> _listen() async {
    if (_listening) {
      await widget.stt.stop();
      setState(() => _listening = false);
      return;
    }
    setState(() => _listening = true);
    try {
      final heard = await widget.stt.listenOnce();
      if (heard != null && heard.trim().isNotEmpty && mounted) {
        widget.onResult(heard.trim());
      }
    } finally {
      if (mounted) setState(() => _listening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color:
            _listening ? AppColors.coral.withOpacity(0.15) : Colors.transparent,
      ),
      child: IconButton(
        tooltip: _listening ? 'Listening… tap to stop' : 'Tap to speak',
        icon: Icon(
          _listening ? Icons.mic_rounded : Icons.mic_none_rounded,
          color: _listening ? AppColors.coral : AppColors.indigo,
        ),
        onPressed: _listen,
      ),
    );
  }
}
