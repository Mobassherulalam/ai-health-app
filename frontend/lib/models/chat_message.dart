import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  final String id;
  final String doctorId;
  final String patientId;
  final String senderId;
  final String senderRole;
  final String text;
  final DateTime timestamp;
  final bool read;

  ChatMessage({
    required this.id,
    required this.doctorId,
    required this.patientId,
    required this.senderId,
    required this.senderRole,
    required this.text,
    required this.timestamp,
    required this.read,
  });

  Map<String, dynamic> toMap() => {
    'doctorId': doctorId,
    'patientId': patientId,
    'senderId': senderId,
    'senderRole': senderRole,
    'text': text,
    'timestamp': Timestamp.fromDate(timestamp),
    'read': read,
  };

  factory ChatMessage.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatMessage(
      id: doc.id,
      doctorId: data['doctorId'] ?? '',
      patientId: data['patientId'] ?? '',
      senderId: data['senderId'] ?? '',
      senderRole: data['senderRole'] ?? '',
      text: data['text'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      read: data['read'] ?? false,
    );
  }
}
