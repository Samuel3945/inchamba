import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:file_picker/file_picker.dart';
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
    final conversationHistory = useState<List<Map<String, String>>>([]);
    final sessionId = useMemoized(() => const Uuid().v4());
    final proposal = useState<Map<String, dynamic>?>(null);

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

    Future<void> sendToAgent(String content, {String messageType = 'text', String? audioUrl}) async {
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
            'message_type': messageType,
            'content': content,
            'audio_url': audioUrl,
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
        if (e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout) {
          errorMsg = 'Tiempo de espera agotado. El agente tardó demasiado en responder.';
        } else if (e.type == DioExceptionType.connectionError) {
          errorMsg = 'No se pudo conectar con el agente. Verifica tu conexión a internet.';
        } else if (e.response != null) {
          errorMsg = 'Error del servidor (${e.response?.statusCode}). Intenta de nuevo.';
        } else {
          errorMsg = 'Error de conexión. Intenta de nuevo.';
        }
        messages.value = [
          ...messages.value,
          _ChatMessage(content: errorMsg, isUser: false),
        ];
      } catch (e) {
        messages.value = [
          ...messages.value,
          _ChatMessage(content: 'Error inesperado. Intenta de nuevo.', isUser: false),
        ];
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

    Future<void> pickAudioFile() async {
      final result = await FilePicker.platform.pickFiles(type: FileType.audio);
      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final filePath = file.path;
      if (filePath == null) return;

      messages.value = [
        ...messages.value,
        _ChatMessage(content: '🎤 Audio: ${file.name}', isUser: true),
      ];
      scrollToBottom();

      // Upload to Supabase
      final ds = ref.read(supabaseDatasourceProvider);
      try {
        final storagePath = '${const Uuid().v4()}_${file.name}';
        final audioUrl = await ds.uploadFile(
          AppConstants.audioProposalsBucket,
          storagePath,
          File(filePath),
        );
        await sendToAgent('Audio enviado', messageType: 'audio', audioUrl: audioUrl);
      } catch (e) {
        messages.value = [
          ...messages.value,
          _ChatMessage(content: 'Error al subir el audio. Intenta de nuevo.', isUser: false),
        ];
      }
    }

    Future<void> publishOffer() async {
      if (proposal.value == null) return;
      final ds = ref.read(supabaseDatasourceProvider);
      final profile = ref.read(currentProfileProvider);
      if (profile == null) return;

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
          if (categoryId != null) 'category_id': categoryId,
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

        // Save AI proposal snapshot for auditing
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      } finally {
        isLoading.value = false;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.smart_toy_rounded, size: 20, color: Colors.white),
            ),
            const SizedBox(width: 10),
            Text('Agente Inchamba', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
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
                if (index >= messages.value.length) {
                  return _TypingIndicator();
                }
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
                        hintText: 'Escribe tu mensaje...',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(color: AppColors.darkBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(color: AppColors.primary),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: pickAudioFile,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.darkSurface,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: const Icon(Icons.mic_rounded, color: AppColors.textLight),
                    ),
                  ),
                  const SizedBox(width: 8),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!message.isUser) ...[
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.smart_toy_rounded, size: 16, color: Colors.white),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: message.isUser ? AppColors.primary : AppColors.darkCard,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(message.isUser ? 16 : 4),
                  bottomRight: Radius.circular(message.isUser ? 4 : 16),
                ),
              ),
              child: Text(
                message.content,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: message.isUser ? Colors.white : AppColors.textWhite,
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.smart_toy_rounded, size: 16, color: Colors.white),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.darkCard,
              borderRadius: BorderRadius.circular(16),
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

class _Dot extends StatefulWidget {
  final int delay;
  const _Dot({required this.delay});

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _controller.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.textMuted.withValues(alpha: 0.4 + _controller.value * 0.6),
        ),
      ),
    );
  }
}

class _ProposalCard extends StatelessWidget {
  final Map<String, dynamic> proposal;
  final VoidCallback onPublish;
  final bool isLoading;

  const _ProposalCard({
    required this.proposal,
    required this.onPublish,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12, left: 36),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.1),
            AppColors.primary.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.description_outlined, color: AppColors.primary),
              const SizedBox(width: 8),
              Text('Resumen de tu oferta', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.primary)),
            ],
          ),
          const Divider(height: 24),
          _proposalRow('Título', proposal['title']),
          _proposalRow('Categoría', proposal['category']),
          _proposalRow('Ciudad', proposal['city']),
          _proposalRow('Paga', '\$${proposal['pay']} ${proposal['pay_type'] ?? ''}'),
          _proposalRow('Trabajadores', '${proposal['workers_needed'] ?? 1}'),
          if (proposal['duration'] != null) _proposalRow('Duración', proposal['duration']),
          if (proposal['schedule'] != null) _proposalRow('Horario', proposal['schedule']),
          if (proposal['description'] != null) ...[
            const SizedBox(height: 8),
            Text('Descripción:', style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textMuted)),
            const SizedBox(height: 4),
            Text(
              proposal['description'] as String? ?? '',
              style: GoogleFonts.poppins(fontSize: 13),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isLoading ? null : onPublish,
              icon: const Icon(Icons.publish_rounded),
              label: Text(
                'Publicar oferta',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _proposalRow(String label, dynamic value) {
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
            child: Text('$value', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
