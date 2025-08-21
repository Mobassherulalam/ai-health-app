import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/chat_service.dart';
import '../models/chat_message.dart';

class ChatThreadScreen extends StatefulWidget {
  final String doctorId;
  final String patientId;
  final String patientName;
  final String doctorName;
  final String currentUserRole; // 'doctor' or 'patient'

  const ChatThreadScreen({
    super.key,
    required this.doctorId,
    required this.patientId,
    required this.patientName,
    required this.doctorName,
    required this.currentUserRole,
  });

  @override
  State<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends State<ChatThreadScreen> {
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Mark thread as read when opened
    ChatService.markThreadRead(widget.doctorId, widget.patientId, widget.currentUserRole);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    await ChatService.sendMessage(
      doctorId: widget.doctorId,
      patientId: widget.patientId,
      text: text,
      senderRole: widget.currentUserRole,
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.currentUserRole == 'doctor' ? widget.patientName : widget.doctorName;
    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: GoogleFonts.poppins()),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: ChatService.streamMessages(widget.doctorId, widget.patientId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final msgs = snapshot.data!;
                if (msgs.isEmpty) {
                  return Center(
                    child: Text('No messages yet', style: GoogleFonts.poppins(color: Colors.grey)),
                  );
                }
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(12),
                  itemCount: msgs.length,
                  itemBuilder: (context, i) {
                    final m = msgs[i];
                    final isMine = m.senderRole == widget.currentUserRole;
                    return Align(
                      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
                        decoration: BoxDecoration(
                          color: isMine ? Colors.blue : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(16).copyWith(
                            bottomLeft: Radius.circular(isMine ? 16 : 2),
                            bottomRight: Radius.circular(isMine ? 2 : 16),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              m.text,
                              style: GoogleFonts.poppins(
                                color: isMine ? Colors.white : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _fmtTime(m.timestamp),
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                color: isMine ? Colors.white70 : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          _buildInput(),
        ],
      ),
    );
  }

  Widget _buildInput() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: GoogleFonts.poppins(color: Colors.grey),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: (_) => _send(),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: Colors.blue,
              child: IconButton(
                icon: const Icon(Icons.send, color: Colors.white, size: 20),
                onPressed: _send,
              ),
            )
          ],
        ),
      ),
    );
  }

  String _fmtTime(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $ampm';
  }
}
