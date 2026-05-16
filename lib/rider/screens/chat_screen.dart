import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../core/models/chat_models.dart';

class ChatScreen extends StatefulWidget {
  final String rideId;
  final bool isDriver;
  final io.Socket? socket;
  final List<ChatMessage> initialMessages;

  const ChatScreen({
    super.key,
    required this.rideId,
    required this.isDriver,
    required this.socket,
    required this.initialMessages,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  static const _navy = Color(0xFF1A1A2E);

  late final List<ChatMessage> _messages;
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  // Stored once so on() and off() use the identical function reference.
  late final void Function(dynamic) _msgListener;

  @override
  void initState() {
    super.initState();
    _messages = List.of(widget.initialMessages);
    _msgListener = _onMsg;
    widget.socket?.on('chat:message', _msgListener);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  void dispose() {
    widget.socket?.off('chat:message', _msgListener);
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onMsg(dynamic data) {
    if (!mounted) return;
    try {
      final map = Map<String, dynamic>.from(data as Map);
      if (map['rideId'] != widget.rideId) return;
      setState(() {
        _messages.add(ChatMessage(
          text: map['text'] as String,
          senderRole: map['senderRole'] as String? ??
              (widget.isDriver ? 'RIDER' : 'DRIVER'),
          time: DateTime.now(),
        ));
      });
      _scrollToBottom();
    } catch (_) {}
  }

  void _send() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    widget.socket?.emit('chat:send', {
      'rideId': widget.rideId,
      'text': text,
    });
    setState(() {
      _messages.add(ChatMessage(
        text: text,
        senderRole: widget.isDriver ? 'DRIVER' : 'RIDER',
        time: DateTime.now(),
      ));
    });
    _input.clear();
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (_, _) {},
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F8FA),
        appBar: AppBar(
          backgroundColor: _navy,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context, List.of(_messages)),
          ),
          title: Text(
            widget.isDriver ? 'Chat with rider' : 'Chat with driver',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  SizedBox(
                    width: 8,
                    height: 8,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Color(0xFF4CAF50),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  SizedBox(width: 6),
                  Text('Live',
                      style: TextStyle(
                          color: Color(0xFF4CAF50),
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: _messages.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.chat_bubble_outline_rounded,
                              size: 56, color: Colors.grey[300]),
                          const SizedBox(height: 16),
                          Text(
                            widget.isDriver
                                ? 'Send a message to your rider'
                                : 'Say hi to your driver!',
                            style: const TextStyle(
                                color: Color(0xFF999999), fontSize: 15),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      itemCount: _messages.length,
                      itemBuilder: (_, i) {
                        final msg = _messages[i];
                        final isMine = widget.isDriver
                            ? msg.senderRole == 'DRIVER'
                            : msg.senderRole == 'RIDER';
                        return _Bubble(
                            text: msg.text, isMine: isMine, time: msg.time);
                      },
                    ),
            ),
            _buildInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildInput() {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 10, 16, MediaQuery.of(context).padding.bottom + 10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _input,
              textCapitalization: TextCapitalization.sentences,
              maxLines: null,
              onSubmitted: (_) => _send(),
              decoration: InputDecoration(
                hintText: 'Type a message…',
                hintStyle:
                    const TextStyle(color: Color(0xFFAAAAAA), fontSize: 14),
                filled: true,
                fillColor: const Color(0xFFF5F5F5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18, vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _send,
            child: Container(
              width: 46,
              height: 46,
              decoration: const BoxDecoration(
                color: _navy,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send_rounded,
                  color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Bubble ─────────────────────────────────────────────────────────────────────

class _Bubble extends StatelessWidget {
  final String text;
  final bool isMine;
  final DateTime time;

  const _Bubble(
      {required this.text, required this.isMine, required this.time});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment:
            isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 2),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.72,
            ),
            decoration: BoxDecoration(
              color:
                  isMine ? const Color(0xFF1A1A2E) : Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(isMine ? 18 : 4),
                bottomRight: Radius.circular(isMine ? 4 : 18),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              text,
              style: TextStyle(
                color: isMine ? Colors.white : const Color(0xFF1C1C1E),
                fontSize: 14,
              ),
            ),
          ),
          Padding(
            padding:
                const EdgeInsets.only(bottom: 12, left: 4, right: 4),
            child: Text(
              _fmt(time),
              style: const TextStyle(
                  color: Color(0xFFAAAAAA), fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  static String _fmt(DateTime dt) {
    final h = dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final period = h >= 12 ? 'PM' : 'AM';
    final hour = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '$hour:$m $period';
  }
}
