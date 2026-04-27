import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/core_providers.dart';

class _ChatMessage {
  final String content;
  final bool isUser;
  final bool isProposalCard;
  final Map<String, dynamic>? proposal;
  final DateTime timestamp;

  _ChatMessage({
    required this.content,
    required this.isUser,
    this.isProposalCard = false,
    this.proposal,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

class CreateOfferScreen extends HookConsumerWidget {
  const CreateOfferScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messages = useState<List<_ChatMessage>>([
      _ChatMessage(content: AppStrings.agentGreeting, isUser: false),
    ]);
    final textCtrl = useTextEditingController();
    final scrollCtrl = useScrollController();
    final isLoading = useState(false);
    final isRecording = useState(false);
    final conversationHistory = useState<List<Map<String, String>>>([]);
    final sessionId = useMemoized(() => const Uuid().v4());
    final proposal = useState<Map<String, dynamic>?>(null);
    final stt = useMemoized(() => SpeechToText());
    final sttAvailable = useState(false);

    useEffect(() {
      stt.initialize(onError: (_) => isRecording.value = false).then((ok) {
        sttAvailable.value = ok;
      });
      return () => stt.stop();
    }, []);

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

    Future<void> sendToAgent(String content) async {
      final profile = ref.read(currentProfileProvider);
      if (profile == null) return;

      isLoading.value = true;
      final newHistory = [
        ...conversationHistory.value,
        {'role': 'user', 'content': content},
      ];
      conversationHistory.value = newHistory;

      try {
        final dio = ref.read(dioProvider);
        final response = await dio.post(
          AppConstants.n8nJobProposalWebhook,
          data: {
            'employer_id': profile.id,
            'session_id': sessionId,
            'message_type': 'text',
            'content': content,
            'conversation_history': newHistory,
          },
        );

        final data = response.data as Map<String, dynamic>;
        final agentMessage = data['message'] as String? ?? '';
        final status = data['status'] as String?;

        conversationHistory.value = [
          ...conversationHistory.value,
          {'role': 'assistant', 'content': agentMessage},
        ];

        if (status == 'ready_for_review' && data['proposal'] != null) {
          proposal.value = data['proposal'] as Map<String, dynamic>;
          messages.value = [
            ...messages.value,
            _ChatMessage(content: agentMessage, isUser: false),
            _ChatMessage(
              content: '',
              isUser: false,
              isProposalCard: true,
              proposal: data['proposal'] as Map<String, dynamic>,
            ),
          ];
        } else {
          messages.value = [
            ...messages.value,
            _ChatMessage(content: agentMessage, isUser: false),
          ];
        }
      } on DioException catch (e) {
        String errorMsg;
        if (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.receiveTimeout) {
          errorMsg = 'Tiempo de espera agotado. El agente tardó demasiado.';
        } else if (e.type == DioExceptionType.connectionError) {
          errorMsg = 'No se pudo conectar con el agente. Verifica tu conexión.';
        } else {
          errorMsg = 'Error del servidor (${e.response?.statusCode}). Intenta de nuevo.';
        }
        messages.value = [...messages.value, _ChatMessage(content: errorMsg, isUser: false)];
      } catch (e) {
        messages.value = [...messages.value, _ChatMessage(content: 'Error inesperado. Intenta de nuevo.', isUser: false)];
      } finally {
        isLoading.value = false;
        scrollToBottom();
      }
    }

    Future<void> sendText() async {
      final text = textCtrl.text.trim();
      if (text.isEmpty) return;
      textCtrl.clear();
      messages.value = [...messages.value, _ChatMessage(content: text, isUser: true)];
      scrollToBottom();
      await sendToAgent(text);
    }

    Future<void> toggleRecording() async {
      if (isRecording.value) {
        await stt.stop();
        isRecording.value = false;
        return;
      }

      if (!sttAvailable.value) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Reconocimiento de voz no disponible en este dispositivo')),
          );
        }
        return;
      }

      textCtrl.clear();
      isRecording.value = true;

      await stt.listen(
        onResult: (result) {
          textCtrl.text = result.recognizedWords;
          if (result.finalResult) {
            isRecording.value = false;
          }
        },
        localeId: 'es_CO',
        listenFor: const Duration(minutes: 3),
        pauseFor: const Duration(seconds: 6),
        listenOptions: SpeechListenOptions(
          cancelOnError: true,
          partialResults: true,
        ),
      );

      isRecording.value = stt.isListening;
    }

    Future<void> publishOffer() async {
      if (proposal.value == null) return;
      final profile = ref.read(currentProfileProvider);
      if (profile == null) return;

      if (!profile.hasCedula || profile.avatarUrl == null || !profile.phoneVerified) {
        if (context.mounted) {
          await showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text('Perfil incompleto', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
              content: Text(
                'Para publicar una oferta necesitas:\n'
                '${!profile.hasCedula ? "• Agregar tu cédula de ciudadanía\n" : ""}'
                '${profile.avatarUrl == null ? "• Subir una foto de perfil\n" : ""}'
                '${!profile.phoneVerified ? "• Verificar tu teléfono\n" : ""}'
                '\nPuedes hacerlo desde tu perfil.',
                style: GoogleFonts.poppins(fontSize: 14),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
                ElevatedButton(
                  onPressed: () { Navigator.pop(ctx); context.push('/edit-profile'); },
                  child: const Text('Ir al perfil'),
                ),
              ],
            ),
          );
        }
        return;
      }


      final ds = ref.read(supabaseDatasourceProvider);
      isLoading.value = true;
      try {
        final p = proposal.value!;

        String? categoryId = p['category_id'] as String?;
        final categoryName = p['category'] as String?;
        if (categoryId == null && categoryName != null && categoryName.isNotEmpty) {
          categoryId = await ds.resolveCategoryId(categoryName);
        }

        final payAmount = (p['pay_amount'] ?? p['pay']) as num?;
        final workersNeeded = (p['workers_needed'] as int?) ?? 1;
        final totalEscrow = ((payAmount?.toDouble() ?? 0) * workersNeeded);

        final jobPost = await ds.createJobPost({
          'employer_id': profile.id,
          'title': p['title'] ?? '',
          'description': p['description'] ?? '',
          'category_id': ?categoryId,
          'city': p['city'] ?? profile.city,
          if (p['department'] != null) 'department': p['department'],
          if (p['address'] != null) 'address': p['address'],
          'pay_amount': payAmount?.toDouble() ?? 0,
          'pay_type': p['pay_type'] ?? 'por_trabajo',
          'workers_needed': workersNeeded,
          'requirements': p['requirements'] ?? [],
          if (p['start_date'] != null) 'start_date': p['start_date'],
          if (p['duration_days'] != null) 'duration_days': p['duration_days'],
          if (p['schedule'] != null) 'schedule': p['schedule'],
          'status': 'pending_payment',
          'total_escrow_required': totalEscrow,
        });

        await ds.saveAiProposal({
          'employer_id': profile.id,
          'n8n_session_id': sessionId,
          'conversation_history': conversationHistory.value,
          'extracted_data': proposal.value,
          'status': 'approved',
        });

        if (context.mounted) {
          context.pushReplacement('/payment/${jobPost['id']}');
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      } finally {
        isLoading.value = false;
      }
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.smart_toy_rounded, size: 20, color: Colors.white),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Agente Inchamba', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600)),
                Text('IA para crear ofertas', style: GoogleFonts.poppins(fontSize: 10, color: AppColors.textMuted)),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: scrollCtrl,
              padding: const EdgeInsets.all(16),
              itemCount: messages.value.length + (isLoading.value ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= messages.value.length) return _TypingIndicator();
                final msg = messages.value[index];
                if (msg.isProposalCard && msg.proposal != null) {
                  return _ProposalCard(
                    proposal: msg.proposal!,
                    onPublish: publishOffer,
                    isLoading: isLoading.value,
                  );
                }
                return _ChatBubble(message: msg);
              },
            ),
          ),
          // Barra de escucha activa
          if (isRecording.value)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
              color: AppColors.error.withValues(alpha: 0.1),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.graphic_eq_rounded, color: AppColors.error, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Escuchando... habla y el texto aparecerá abajo',
                    style: GoogleFonts.poppins(fontSize: 13, color: AppColors.error, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          // Input bar
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: textCtrl,
                      textCapitalization: TextCapitalization.sentences,
                      onSubmitted: (_) => sendText(),
                      decoration: InputDecoration(
                        hintText: 'Escribe o graba tu mensaje...',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(
                            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(color: AppColors.primary),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Botón micrófono
                  GestureDetector(
                    onTap: isLoading.value ? null : toggleRecording,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isRecording.value
                            ? AppColors.error
                            : (isDark ? AppColors.darkSurface : AppColors.lightBg),
                        borderRadius: BorderRadius.circular(22),
                        border: isRecording.value
                            ? null
                            : Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                      ),
                      child: Icon(
                        isRecording.value ? Icons.stop_rounded : Icons.mic_rounded,
                        color: isRecording.value ? Colors.white : AppColors.textMuted,
                        size: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Botón enviar
                  GestureDetector(
                    onTap: isLoading.value ? null : sendText,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final _ChatMessage message;
  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!message.isUser) ...[
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.smart_toy_rounded, size: 16, color: Colors.white),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: message.isUser
                    ? AppColors.primary
                    : (isDark ? AppColors.darkCard : AppColors.lightCard),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(message.isUser ? 16 : 4),
                  bottomRight: Radius.circular(message.isUser ? 4 : 16),
                ),
                boxShadow: message.isUser ? null : [
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
                  color: message.isUser
                      ? Colors.white
                      : (isDark ? AppColors.textWhite : AppColors.textDark),
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.smart_toy_rounded, size: 16, color: Colors.white),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.lightCard,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Dot(delay: 0), const SizedBox(width: 4),
                _Dot(delay: 200), const SizedBox(width: 4),
                _Dot(delay: 400),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatefulWidget {
  final int delay;
  const _Dot({required this.delay});

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(duration: const Duration(milliseconds: 600), vsync: this);
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, _) => Container(
        width: 8, height: 8,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.textMuted.withValues(alpha: 0.4 + _ctrl.value * 0.6),
        ),
      ),
    );
  }
}

class _ProposalCard extends StatelessWidget {
  final Map<String, dynamic> proposal;
  final VoidCallback onPublish;
  final bool isLoading;

  const _ProposalCard({required this.proposal, required this.onPublish, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 12, left: 36),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(color: AppColors.primary.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.description_outlined, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'Resumen de tu oferta',
                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _row('Título', proposal['title']),
          _row('Categoría', proposal['category']),
          _row('Ciudad', proposal['city']),
          _row('Paga', '\$${proposal['pay_amount'] ?? proposal['pay']} ${proposal['pay_type'] ?? ''}'),
          _row('Trabajadores', '${proposal['workers_needed'] ?? 1}'),
          if (proposal['duration'] != null) _row('Duración', proposal['duration']),
          if (proposal['schedule'] != null) _row('Horario', proposal['schedule']),
          if (proposal['description'] != null) ...[
            const SizedBox(height: 8),
            Text('Descripción:', style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textMuted)),
            const SizedBox(height: 4),
            Text(
              proposal['description'] as String? ?? '',
              style: GoogleFonts.poppins(fontSize: 13, height: 1.4),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isLoading ? null : onPublish,
              icon: const Icon(Icons.rocket_launch_rounded),
              label: Text('Publicar oferta', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textMuted)),
          ),
          Expanded(
            child: Text('${value ?? '—'}', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
