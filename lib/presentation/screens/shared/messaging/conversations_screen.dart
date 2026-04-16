import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/formatters.dart';
import '../../../providers/messaging_provider.dart';
import '../../../widgets/common_widgets.dart';

class ConversationsScreen extends ConsumerWidget {
  const ConversationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final convsAsync = ref.watch(conversationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.messages, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
      ),
      body: convsAsync.when(
        loading: () => ListView.builder(
          itemCount: 6,
          itemBuilder: (_, _i) => const ShimmerListTile(),
        ),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (conversations) {
          if (conversations.isEmpty) {
            return const EmptyState(
              icon: Icons.chat_bubble_outline,
              title: AppStrings.noMessages,
              subtitle: 'Las conversaciones aparecerán aquí cuando contactes a alguien.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(conversationsProvider),
            color: AppColors.primary,
            child: ListView.builder(
              itemCount: conversations.length,
              itemBuilder: (context, index) {
                final conv = conversations[index];
                return ListTile(
                  leading: InchambaAvatar(
                    imageUrl: conv.otherParticipantAvatar,
                    fallbackInitials: conv.otherParticipantName?.substring(0, 1).toUpperCase(),
                    radius: 24,
                  ),
                  title: Text(
                    conv.otherParticipantName ?? 'Usuario',
                    style: GoogleFonts.poppins(
                      fontWeight: conv.unreadCount > 0 ? FontWeight.w600 : FontWeight.w400,
                      fontSize: 15,
                    ),
                  ),
                  subtitle: Text(
                    conv.lastMessage ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: conv.unreadCount > 0 ? null : AppColors.textMuted,
                    ),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (conv.lastMessageAt != null)
                        Text(
                          Formatters.timeAgo(conv.lastMessageAt!),
                          style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textMuted),
                        ),
                      if (conv.unreadCount > 0) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${conv.unreadCount}',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ],
                  ),
                  onTap: () => context.push(
                    '/chat/${conv.id}?name=${Uri.encodeComponent(conv.otherParticipantName ?? 'Usuario')}',
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
