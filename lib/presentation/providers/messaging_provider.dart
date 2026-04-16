import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/datasources/supabase_datasource.dart';
import '../../data/models/conversation_model.dart';
import 'core_providers.dart';

final conversationsProvider = FutureProvider<List<ConversationModel>>((ref) async {
  final ds = ref.watch(supabaseDatasourceProvider);
  final userId = ds.currentUserId;
  if (userId == null) return [];
  final data = await ds.getConversations(userId);
  return data.map((c) => ConversationModel.fromJson(c, userId)).toList();
});

class ChatState {
  final List<MessageModel> messages;
  final bool isLoading;
  final bool isSending;

  const ChatState({
    this.messages = const [],
    this.isLoading = false,
    this.isSending = false,
  });

  ChatState copyWith({
    List<MessageModel>? messages,
    bool? isLoading,
    bool? isSending,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
    );
  }
}

class ChatNotifier extends StateNotifier<ChatState> {
  final SupabaseDatasource _datasource;
  final String conversationId;
  RealtimeChannel? _channel;

  ChatNotifier(this._datasource, this.conversationId) : super(const ChatState()) {
    _loadMessages();
    _subscribe();
  }

  Future<void> _loadMessages() async {
    state = state.copyWith(isLoading: true);
    try {
      final data = await _datasource.getMessages(conversationId);
      final messages = data.map((m) => MessageModel.fromJson(m)).toList();
      state = ChatState(messages: messages);

      final userId = _datasource.currentUserId;
      if (userId != null) {
        await _datasource.markMessagesAsRead(conversationId, userId);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }

  void _subscribe() {
    _channel = _datasource.subscribeToMessages(conversationId, (data) {
      final message = MessageModel.fromJson(data);
      // Add to front (messages are newest-first)
      state = state.copyWith(messages: [message, ...state.messages]);
      // Mark as read
      final userId = _datasource.currentUserId;
      if (userId != null && message.senderId != userId) {
        _datasource.markMessagesAsRead(conversationId, userId);
      }
    });
  }

  Future<void> sendMessage(String content, {String? fileUrl, String messageType = 'text'}) async {
    state = state.copyWith(isSending: true);
    final userId = _datasource.currentUserId!;
    try {
      await _datasource.sendMessage({
        'conversation_id': conversationId,
        'sender_id': userId,
        'content': content,
        'file_url': fileUrl,
        'message_type': messageType,
      });
    } finally {
      state = state.copyWith(isSending: false);
    }
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }
}

final chatProvider = StateNotifierProvider.family<ChatNotifier, ChatState, String>((ref, conversationId) {
  return ChatNotifier(ref.watch(supabaseDatasourceProvider), conversationId);
});
