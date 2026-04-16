import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/formatters.dart';
import '../../../providers/notification_provider.dart';
import '../../../widgets/common_widgets.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notificationProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.notifications, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        actions: [
          if (state.unreadCount > 0)
            TextButton(
              onPressed: () => ref.read(notificationProvider.notifier).markAllAsRead(),
              child: const Text(AppStrings.markAllRead),
            ),
        ],
      ),
      body: state.isLoading
          ? ListView.builder(itemCount: 6, itemBuilder: (_, i) => const ShimmerListTile())
          : state.notifications.isEmpty
              ? const EmptyState(
                  icon: Icons.notifications_off_outlined,
                  title: AppStrings.noNotifications,
                )
              : RefreshIndicator(
                  onRefresh: () => ref.read(notificationProvider.notifier).load(),
                  color: AppColors.primary,
                  child: ListView.builder(
                    itemCount: state.notifications.length,
                    itemBuilder: (context, index) {
                      final notif = state.notifications[index];
                      return ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: _iconColor(notif.type).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(_icon(notif.type), color: _iconColor(notif.type), size: 20),
                        ),
                        title: Text(
                          notif.title,
                          style: GoogleFonts.poppins(
                            fontWeight: notif.isRead ? FontWeight.w400 : FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(notif.body, maxLines: 2, overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textMuted)),
                            Text(Formatters.timeAgo(notif.createdAt),
                                style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textMuted)),
                          ],
                        ),
                        trailing: notif.isRead
                            ? null
                            : Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                              ),
                        onTap: () {
                          if (!notif.isRead) {
                            ref.read(notificationProvider.notifier).markAsRead(notif.id);
                          }
                          _navigateToNotification(context, notif.type, notif.data);
                        },
                      );
                    },
                  ),
                ),
    );
  }

  IconData _icon(String type) {
    switch (type) {
      case 'application_received': return Icons.person_add_rounded;
      case 'application_accepted': return Icons.check_circle_rounded;
      case 'application_rejected': return Icons.cancel_rounded;
      case 'work_completed': return Icons.task_alt_rounded;
      case 'payment_released': return Icons.payments_rounded;
      case 'message': return Icons.chat_bubble_rounded;
      case 'dispute_update': return Icons.gavel_rounded;
      default: return Icons.notifications_rounded;
    }
  }

  Color _iconColor(String type) {
    switch (type) {
      case 'application_received': return AppColors.info;
      case 'application_accepted': return AppColors.success;
      case 'application_rejected': return AppColors.error;
      case 'work_completed': return AppColors.success;
      case 'payment_released': return AppColors.escrow;
      case 'message': return AppColors.primary;
      case 'dispute_update': return AppColors.warning;
      default: return AppColors.textMuted;
    }
  }

  void _navigateToNotification(BuildContext context, String type, Map<String, dynamic>? data) {
    if (data == null) return;
    final jobPostId = data['job_post_id'] as String?;
    final conversationId = data['conversation_id'] as String?;

    switch (type) {
      case 'application_received':
        if (jobPostId != null) context.push('/employer/offer/$jobPostId');
        break;
      case 'application_accepted':
      case 'application_rejected':
        if (jobPostId != null) context.push('/job/$jobPostId');
        break;
      case 'message':
        if (conversationId != null) context.push('/chat/$conversationId?name=Chat');
        break;
      default:
        if (jobPostId != null) context.push('/job/$jobPostId');
    }
  }
}
