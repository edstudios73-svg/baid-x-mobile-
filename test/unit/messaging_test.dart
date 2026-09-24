import 'package:flutter_test/flutter_test.dart';

import 'package:baid_x_mobile/features/messaging/domain/message_rules.dart';

void main() {
  test('blank and oversized messages are rejected', () {
    expect(validateMessageBody('   '), 'Write a message first.');
    expect(validateMessageBody('a' * 2001), 'Keep the message under 2000 characters.');
    expect(validateMessageBody(' On site '), isNull);
  });

  test('unread follows the current user read time', () {
    final sent = DateTime.utc(2026, 1, 2);
    expect(isConversationUnread(latestSenderId: 'other', latestAt: sent, lastReadAt: null, userId: 'me'), isTrue);
    expect(isConversationUnread(latestSenderId: 'me', latestAt: sent, lastReadAt: null, userId: 'me'), isFalse);
    expect(isConversationUnread(latestSenderId: 'other', latestAt: sent, lastReadAt: sent, userId: 'me'), isFalse);
  });

  test('opening a conversation uses the secure function for that context', () {
    expect(openConversationCall('job_application')?.rpc, 'open_job_application_conversation');
    expect(openConversationCall('project')?.parameter, 'project_id');
    expect(openConversationCall('company')?.rpc, 'open_company_conversation');
    expect(openConversationCall('business'), isNull);
  });

  test('a conversation title stays plain when the related name is missing', () {
    expect(conversationTitle('project', null), 'Project');
    expect(conversationTitle('job_application', 'Site works'), 'Site works');
  });
}
