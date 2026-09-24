const messageBodyLimit = 2000;

const conversationContexts = ['job_application', 'project', 'company'];

String? validateMessageBody(String body) {
  final text = body.trim();
  if (text.isEmpty) return 'Write a message first.';
  if (text.length > messageBodyLimit) return 'Keep the message under 2000 characters.';
  return null;
}

bool isConversationUnread({
  required String? latestSenderId,
  required DateTime? latestAt,
  required DateTime? lastReadAt,
  required String userId,
}) {
  if (latestAt == null || latestSenderId == null || latestSenderId == userId) return false;
  if (lastReadAt == null) return true;
  return latestAt.isAfter(lastReadAt);
}

String conversationTitle(String contextType, String? name) {
  final label = switch (contextType) {
    'job_application' => 'Job application',
    'project' => 'Project',
    'company' => 'Company',
    _ => 'Conversation',
  };
  if (name == null || name.trim().isEmpty) return label;
  return name.trim();
}

({String rpc, String parameter})? openConversationCall(String contextType) {
  return switch (contextType) {
    'job_application' => (rpc: 'open_job_application_conversation', parameter: 'application_id'),
    'project' => (rpc: 'open_project_conversation', parameter: 'project_id'),
    'company' => (rpc: 'open_company_conversation', parameter: 'company_id'),
    _ => null,
  };
}

class ConversationSummary {
  const ConversationSummary({
    required this.id,
    required this.contextType,
    required this.contextId,
    required this.createdAt,
    required this.title,
    required this.latestBody,
    required this.unread,
    this.latestAt,
  });

  final String id;
  final String contextType;
  final String contextId;
  final DateTime createdAt;
  final String title;
  final String latestBody;
  final DateTime? latestAt;
  final bool unread;
}

class MessageRecord {
  const MessageRecord({
    required this.id,
    required this.conversationId,
    required this.senderProfileId,
    required this.body,
    required this.createdAt,
    this.senderName = '',
  });

  final String id;
  final String conversationId;
  final String senderProfileId;
  final String body;
  final DateTime createdAt;
  final String senderName;

  MessageRecord named(String name) => MessageRecord(
    id: id,
    conversationId: conversationId,
    senderProfileId: senderProfileId,
    body: body,
    createdAt: createdAt,
    senderName: name,
  );
}

class NotificationRecord {
  const NotificationRecord({
    required this.id,
    required this.recipientProfileId,
    required this.kind,
    required this.title,
    required this.body,
    required this.contextType,
    required this.contextId,
    required this.createdAt,
    this.readAt,
  });

  final String id;
  final String recipientProfileId;
  final String kind;
  final String title;
  final String body;
  final String contextType;
  final String contextId;
  final DateTime createdAt;
  final DateTime? readAt;

  bool get isUnread => readAt == null;
}

String formatMessageTime(DateTime time) {
  final local = time.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.day}/${local.month} $hour:$minute';
}
