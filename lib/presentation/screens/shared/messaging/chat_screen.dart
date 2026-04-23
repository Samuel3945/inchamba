import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/formatters.dart';
import '../../../providers/messaging_provider.dart';
import '../../../providers/core_providers.dart';

class ChatScreen extends HookConsumerWidget {
  final String conversationId;
  final String otherUserName;

  const ChatScreen({super.key, required this.conversationId, required this.otherUserName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatState = ref.watch(chatProvider(conversationId));
    final textCtrl = useTextEditingController();
    final scrollCtrl = useScrollController();
    final ds = ref.watch(supabaseDatasourceProvider);
    final currentUserId = ds.currentUserId;

    void scrollToBottom() {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (scrollCtrl.hasClients) {
          scrollCtrl.animateTo(0, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
        }
      });
    }

    Future<void> sendMessage() async {
      final text = textCtrl.text.trim();
      if (text.isEmpty) return;
      textCtrl.clear();
      await ref.read(chatProvider(conversationId).notifier).sendMessage(text);
      scrollToBottom();
    }

    Future<void> sendImage() async {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1200);
      if (picked == null) return;

      try {
        final url = await ds.uploadFile(
          AppConstants.applicationAttachmentsBucket,
          picked.path,
          File(picked.path),
        );
        await ref.read(chatProvider(conversationId).notifier).sendMessage('Imagen', fileUrl: url, messageType: 'image');
        scrollToBottom();
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al enviar imagen: $e')));
        }
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: () {
            // Navigate to profile of the other participant
          },
          child: Text(otherUserName, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: chatState.isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : chatState.messages.isEmpty
                    ? Center(
                        child: Text(
                          'Envía el primer mensaje',
                          style: GoogleFonts.poppins(color: AppColors.textMuted),
                        ),
                      )
                    : ListView.builder(
                        controller: scrollCtrl,
                        reverse: true,
                        padding: const EdgeInsets.all(16),
                        itemCount: chatState.messages.length,
                        itemBuilder: (context, index) {
                          final msg = chatState.messages[index];
                          final isMe = msg.senderId == currentUserId;
                          return _MessageBubble(
                            content: msg.content,
                            imageUrl: msg.messageType == 'image' ? msg.fileUrl : null,
                            isMe: isMe,
                            time: msg.createdAt,
                          );
                        },
                      ),
          ),
          // Input bar
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, -2)),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  IconButton(
                    onPressed: sendImage,
                    icon: const Icon(Icons.image_outlined, color: AppColors.textMuted),
                  ),
                  Expanded(
                    child: TextField(
                      controller: textCtrl,
                      textCapitalization: TextCapitalization.sentences,
                      onSubmitted: (_) => sendMessage(),
                      decoration: InputDecoration(
                        hintText: 'Escribe un mensaje...',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
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
                    onTap: chatState.isSending ? null : sendMessage,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(22)),
                      child: chatState.isSending
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
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

class _MessageBubble extends StatelessWidget {
  final String content;
  final String? imageUrl;
  final bool isMe;
  final DateTime time;

  const _MessageBubble({
    required this.content,
    this.imageUrl,
    required this.isMe,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isMe
                    ? AppColors.primary
                    : (Theme.of(context).brightness == Brightness.dark
                        ? AppColors.darkCard
                        : AppColors.surfaceLow),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isMe ? 16 : 4),
                bottomRight: Radius.circular(isMe ? 4 : 16),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (imageUrl != null) ...[
                  GestureDetector(
                    onTap: () => _showFullImage(context, imageUrl!),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl: imageUrl!,
                        width: 200,
                        fit: BoxFit.cover,
                        placeholder: (_, _) => const SizedBox(
                          height: 100,
                          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                if (content.isNotEmpty && content != 'Imagen')
                  Text(
                    content,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: isMe ? Colors.white : AppColors.textWhite,
                    ),
                  ),
                const SizedBox(height: 2),
                Text(
                  Formatters.time(time),
                  style: TextStyle(
                    fontSize: 10,
                    color: isMe ? Colors.white70 : AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showFullImage(BuildContext context, String url) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(backgroundColor: Colors.black, iconTheme: const IconThemeData(color: Colors.white)),
        body: Center(child: InteractiveViewer(child: CachedNetworkImage(imageUrl: url))),
      ),
    ));
  }
}
