import 'package:equatable/equatable.dart';

class Conversation extends Equatable {
  final String id;
  final String employerId;
  final String workerId;
  final String? jobPostId;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final int unreadCount;
  final DateTime createdAt;

  // Joined
  final String? otherParticipantName;
  final String? otherParticipantAvatar;

  const Conversation({
    required this.id,
    required this.employerId,
    required this.workerId,
    this.jobPostId,
    this.lastMessage,
    this.lastMessageAt,
    this.unreadCount = 0,
    required this.createdAt,
    this.otherParticipantName,
    this.otherParticipantAvatar,
  });

  @override
  List<Object?> get props => [id, employerId, workerId, lastMessageAt];
}

class Message extends Equatable {
  final String id;
  final String conversationId;
  final String senderId;
  final String content;
  final String? fileUrl;
  final String messageType;
  final bool isRead;
  final DateTime createdAt;

  // Joined
  final String? senderName;
  final String? senderAvatar;

  const Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.content,
    this.fileUrl,
    this.messageType = 'text',
    this.isRead = false,
    required this.createdAt,
    this.senderName,
    this.senderAvatar,
  });

  @override
  List<Object?> get props => [id, conversationId, senderId, createdAt];
}
