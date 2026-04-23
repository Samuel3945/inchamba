import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../providers/core_providers.dart';

class _ChatMessage {
  final String content;
  final bool isUser;
  final DateTime timestamp;

  _ChatMessage({
    required this.content,
    required this.isUser,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

const _welcomeMessage =
    '¡Hola! Soy tu asesor de Cédula de Ciudadanía 🪪\n\n'
    'Puedo ayudarte en casos como:\n'
    '• Primera vez sacando la cédula\n'
    '• Cédula perdida o robada\n'
    '• Cédula dañada o deteriorada\n'
    '• Trámites desde el exterior\n'
    '• Rectificación de datos\n\n'
    'Cuéntame tu situación y te guío paso a paso.';

class CedulaAdvisorScreen extends HookConsumerWidget {
  const CedulaAdvisorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messages = useState<List<_ChatMessage>>([
      _ChatMessage(content: _welcomeMessage, isUser: false),
    ]);
    final textCtrl = useTextEditingController();
    final scrollCtrl = useScrollController();
    final isLoading = useState(false);
    final sessionId = useMemoized(() => const Uuid().v4());
    final conversationHistory = useState<List<Map<String, String>>>([]);

    void scrollToBottom() {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (scrollCtrl.hasClients) {
          scrollCtrl.animateTo(
            scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }

    Future<void> sendMessage(String text) async {
      final trimmed = text.trim();
      if (trimmed.isEmpty || isLoading.value) return;

      textCtrl.clear();

      messages.value = [
        ...messages.value,
        _ChatMessage(content: trimmed, isUser: true),
      ];

      final newHistory = [
        ...conversationHistory.value,
        {'role': 'user', 'content': trimmed},
      ];
      conversationHistory.value = newHistory;
      scrollToBottom();

      isLoading.value = true;
      try {
        final dio = ref.read(dioProvider);
        final url =
            '${AppConstants.n8nBaseUrl}${AppConstants.n8nCedulaAdvisorWebhook}';

        final response = await dio.post<dynamic>(
          url,
          data: {
            'session_id': sessionId,
            'message': trimmed,
            'conversation_history': newHistory,
          },
          options: Options(
            sendTimeout: const Duration(seconds: 30),
            receiveTimeout: const Duration(seconds: 60),
          ),
        );

        String reply = '';
        final data = response.data;
        if (data is Map) {
          reply = (data['reply'] ?? data['message'] ?? data['output'] ?? '')
              .toString();
        } else if (data is String) {
          reply = data;
        }

        if (reply.isEmpty) reply = 'Entendido. ¿Hay algo más en lo que pueda ayudarte?';

        conversationHistory.value = [
          ...newHistory,
          {'role': 'assistant', 'content': reply},
        ];

        messages.value = [
          ...messages.value,
          _ChatMessage(content: reply, isUser: false),
        ];
      } catch (e) {
        messages.value = [
          ...messages.value,
          _ChatMessage(
            content:
                'Lo siento, tuve un problema para responderte. Por favor intenta de nuevo.',
            isUser: false,
          ),
        ];
      } finally {
        isLoading.value = false;
        scrollToBottom();
      }
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.surfaceLow,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.badge_rounded, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Asesor de Cédula',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: isDark ? AppColors.textWhite : AppColors.textDark,
                  ),
                ),
                Text(
                  'IA especializada • Registraduría Colombia',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Info banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: AppColors.primary.withValues(alpha: 0.06),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 14, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Información basada en los procesos de la Registraduría Nacional de Colombia.',
                    style: GoogleFonts.poppins(fontSize: 11, color: AppColors.primary),
                  ),
                ),
              ],
            ),
          ),

          // Messages list
          Expanded(
            child: ListView.builder(
              controller: scrollCtrl,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: messages.value.length + (isLoading.value ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == messages.value.length) {
                  return _TypingBubble(isDark: isDark);
                }
                final msg = messages.value[index];
                return _MessageBubble(message: msg, isDark: isDark);
              },
            ),
          ),

          // Input bar
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            padding: EdgeInsets.only(
              left: 16,
              right: 12,
              top: 10,
              bottom: MediaQuery.of(context).viewInsets.bottom + 12,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: textCtrl,
                    textCapitalization: TextCapitalization.sentences,
                    maxLines: 4,
                    minLines: 1,
                    style: GoogleFonts.poppins(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Escribe tu consulta...',
                      hintStyle: GoogleFonts.poppins(
                          fontSize: 14, color: AppColors.textMuted),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: isDark
                          ? AppColors.darkCard
                          : AppColors.surfaceLow,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                    ),
                    onSubmitted: sendMessage,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: isLoading.value
                      ? null
                      : () => sendMessage(textCtrl.text),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isLoading.value
                          ? AppColors.textMuted
                          : AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.send_rounded,
                        color: Colors.white, size: 18),
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

class _MessageBubble extends StatelessWidget {
  final _ChatMessage message;
  final bool isDark;

  const _MessageBubble({required this.message, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.support_agent_rounded,
                  size: 16, color: AppColors.primary),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser
                    ? AppColors.primary
                    : isDark
                        ? AppColors.darkCard
                        : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: isUser
                      ? const Radius.circular(18)
                      : const Radius.circular(4),
                  bottomRight: isUser
                      ? const Radius.circular(4)
                      : const Radius.circular(18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Text(
                message.content,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: isUser
                      ? Colors.white
                      : isDark
                          ? AppColors.textWhite
                          : AppColors.textDark,
                  height: 1.5,
                ),
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 4),
        ],
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  final bool isDark;
  const _TypingBubble({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.support_agent_rounded,
                size: 16, color: AppColors.primary),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomRight: Radius.circular(18),
                bottomLeft: Radius.circular(4),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Dot(delay: 0),
                const SizedBox(width: 4),
                _Dot(delay: 200),
                const SizedBox(width: 4),
                _Dot(delay: 400),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Dot extends HookWidget {
  final int delay;
  const _Dot({required this.delay});

  @override
  Widget build(BuildContext context) {
    final ctrl = useAnimationController(
      duration: const Duration(milliseconds: 600),
    );
    useEffect(() {
      Future.delayed(Duration(milliseconds: delay), () {
        if (ctrl.isAnimating == false) {
          ctrl.repeat(reverse: true);
        }
      });
      return null;
    }, []);

    return AnimatedBuilder(
      animation: ctrl,
      builder: (context, _) => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(
              alpha: 0.3 + (ctrl.value * 0.7)),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
