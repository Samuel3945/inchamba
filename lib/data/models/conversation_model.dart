import '../../domain/entities/conversation.dart';

class ConversationModel extends Conversation {
  const ConversationModel({
    required super.id,
    required super.employerId,
    required super.workerId,
    super.jobPostId,
    super.lastMessage,
    super.lastMessageAt,
    super.unreadCount,
    required super.createdAt,
    super.otherParticipantName,
    super.otherParticipantAvatar,
  });

  factory ConversationModel.fromJson(Map<String, dynamic> json, String currentUserId) {
    final isEmployer = json['employer_id'] == currentUserId;
    final otherProfile = isEmployer
        ? json['worker'] as Map<String, dynamic>?
        : json['employer'] as Map<String, dynamic>?;
    final unread = isEmployer
        ? (json['employer_unread'] as int? ?? 0)
        : (json['worker_unread'] as int? ?? 0);

    return ConversationModel(
      id: json['id'] as String,
      employerId: json['employer_id'] as String,
      workerId: json['worker_id'] as String,
      jobPostId: json['job_post_id'] as String?,
      lastMessage: json['last_message'] as String?,
      lastMessageAt: json['last_message_at'] != null
          ? DateTime.parse(json['last_message_at'] as String)
          : null,
      unreadCount: unread,
      createdAt: DateTime.parse(json['created_at'] as String),
      otherParticipantName: otherProfile?['full_name'] as String?,
      otherParticipantAvatar: otherProfile?['avatar_url'] as String?,
    );
  }
}

class MessageModel extends Message {
  const MessageModel({
    required super.id,
    required super.conversationId,
    required super.senderId,
    required super.content,
    super.fileUrl,
    super.messageType,
    super.isRead,
    required super.createdAt,
    super.senderName,
    super.senderAvatar,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    final sender = json['profiles'] as Map<String, dynamic>?;
    return MessageModel(
      id: json['id'] as String,
      conversationId: json['conversation_id'] as String,
      senderId: json['sender_id'] as String,
      content: json['content'] as String? ?? '',
      fileUrl: json['file_url'] as String?,
      messageType: json['message_type'] as String? ?? 'text',
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      senderName: sender?['full_name'] as String?,
      senderAvatar: sender?['avatar_url'] as String?,
    );
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'conversation_id': conversationId,
      'sender_id': senderId,
      'content': content,
      'file_url': fileUrl,
      'message_type': messageType,
    };
  }
}
