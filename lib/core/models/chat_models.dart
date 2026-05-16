class ChatMessage {
  final String text;
  final String senderRole; // 'RIDER' or 'DRIVER'
  final DateTime time;

  const ChatMessage({
    required this.text,
    required this.senderRole,
    required this.time,
  });
}
