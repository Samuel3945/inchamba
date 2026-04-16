import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/datasources/supabase_datasource.dart';
import '../../data/models/notification_model.dart';
import 'core_providers.dart';

class NotificationState {
  final List<NotificationModel> notifications;
  final int unreadCount;
  final bool isLoading;

  const NotificationState({
    this.notifications = const [],
    this.unreadCount = 0,
    this.isLoading = false,
  });

  NotificationState copyWith({
    List<NotificationModel>? notifications,
    int? unreadCount,
    bool? isLoading,
  }) {
    return NotificationState(
      notifications: notifications ?? this.notifications,
      unreadCount: unreadCount ?? this.unreadCount,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class NotificationNotifier extends StateNotifier<NotificationState> {
  final SupabaseDatasource _datasource;
  RealtimeChannel? _channel;

  NotificationNotifier(this._datasource) : super(const NotificationState()) {
    load();
    _subscribe();
  }

  Future<void> load() async {
    final userId = _datasource.currentUserId;
    if (userId == null) return;
    state = state.copyWith(isLoading: true);
    try {
      final data = await _datasource.getNotifications(userId);
      final notifications = data.map((n) => NotificationModel.fromJson(n)).toList();
      final unread = await _datasource.getUnreadNotificationCount(userId);
      state = NotificationState(
        notifications: notifications,
        unreadCount: unread,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }

  void _subscribe() {
    final userId = _datasource.currentUserId;
    if (userId == null) return;
    _channel = _datasource.subscribeToNotifications(userId, (data) {
      final notification = NotificationModel.fromJson(data);
      state = state.copyWith(
        notifications: [notification, ...state.notifications],
        unreadCount: state.unreadCount + 1,
      );
    });
  }

  Future<void> markAsRead(String notificationId) async {
    await _datasource.markNotificationAsRead(notificationId);
    state = state.copyWith(
      notifications: state.notifications.map((n) {
        if (n.id == notificationId) {
          return NotificationModel(
            id: n.id,
            userId: n.userId,
            type: n.type,
            title: n.title,
            body: n.body,
            data: n.data,
            isRead: true,
            createdAt: n.createdAt,
          );
        }
        return n;
      }).toList(),
      unreadCount: (state.unreadCount - 1).clamp(0, 999),
    );
  }

  Future<void> markAllAsRead() async {
    final userId = _datasource.currentUserId;
    if (userId == null) return;
    await _datasource.markAllNotificationsAsRead(userId);
    state = state.copyWith(
      notifications: state.notifications.map((n) {
        return NotificationModel(
          id: n.id,
          userId: n.userId,
          type: n.type,
          title: n.title,
          body: n.body,
          data: n.data,
          isRead: true,
          createdAt: n.createdAt,
        );
      }).toList(),
      unreadCount: 0,
    );
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }
}

final notificationProvider = StateNotifierProvider<NotificationNotifier, NotificationState>((ref) {
  return NotificationNotifier(ref.watch(supabaseDatasourceProvider));
});

final unreadNotificationCountProvider = Provider<int>((ref) {
  return ref.watch(notificationProvider).unreadCount;
});
