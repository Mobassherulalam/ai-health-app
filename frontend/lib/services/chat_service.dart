import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chat_message.dart';
import 'auth_service.dart';

class ChatService {
  static final _db = FirebaseFirestore.instance;

  static CollectionReference _threadCollection(
    String doctorId,
    String patientId,
  ) => _db
      .collection('chat_threads')
      .doc('${doctorId}_${patientId}')
      .collection('messages');

  static Stream<List<ChatMessage>> streamMessages(
    String doctorId,
    String patientId,
  ) {
    return _threadCollection(doctorId, patientId)
        .orderBy('timestamp', descending: true)
        .limit(200)
        .snapshots()
        .map((snap) => snap.docs.map((d) => ChatMessage.fromDoc(d)).toList());
  }

  static Future<void> sendMessage({
    required String doctorId,
    required String patientId,
    required String text,
    required String senderRole,
  }) async {
    final senderId = await AuthService.getCurrentUserId();
    if (senderId == null) throw Exception('Not authenticated');
    if (text.trim().isEmpty) return;

    final threadId = '${doctorId}_${patientId}';
    final threadMetaRef = _db.collection('chat_threads').doc(threadId);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(threadMetaRef);
      if (!snap.exists) {
        tx.set(threadMetaRef, {
          'doctorId': doctorId,
          'patientId': patientId,
          'lastMessage': text.trim(),
          'lastSenderRole': senderRole,
          'updatedAt': FieldValue.serverTimestamp(),
          'unreadForDoctor': senderRole == 'patient' ? 1 : 0,
          'unreadForPatient': senderRole == 'doctor' ? 1 : 0,
        });
      } else {
        final unreadForDoctorInc = senderRole == 'patient' ? 1 : 0;
        final unreadForPatientInc = senderRole == 'doctor' ? 1 : 0;
        tx.update(threadMetaRef, {
          'lastMessage': text.trim(),
          'lastSenderRole': senderRole,
          'updatedAt': FieldValue.serverTimestamp(),
          'unreadForDoctor': FieldValue.increment(unreadForDoctorInc),
          'unreadForPatient': FieldValue.increment(unreadForPatientInc),
        });
      }
    });

    final msg = ChatMessage(
      id: '',
      doctorId: doctorId,
      patientId: patientId,
      senderId: senderId,
      senderRole: senderRole,
      text: text.trim(),
      timestamp: DateTime.now(),
      read: false,
    );

    await _threadCollection(doctorId, patientId).add(msg.toMap());
  }

  static Future<void> createThreadIfAbsent({
    required String doctorId,
    required String patientId,
  }) async {
    final threadMetaRef = _db
        .collection('chat_threads')
        .doc('${doctorId}_${patientId}');
    final snap = await threadMetaRef.get();
    if (!snap.exists) {
      await threadMetaRef.set({
        'doctorId': doctorId,
        'patientId': patientId,
        'lastMessage': '',
        'lastSenderRole': '',
        'updatedAt': FieldValue.serverTimestamp(),
        'unreadForDoctor': 0,
        'unreadForPatient': 0,
      });
    }
  }

  static Future<void> markThreadRead(
    String doctorId,
    String patientId,
    String role,
  ) async {
    final threadMetaRef = _db
        .collection('chat_threads')
        .doc('${doctorId}_${patientId}');
    await threadMetaRef
        .update({
          role == 'doctor' ? 'unreadForDoctor' : 'unreadForPatient': 0,
          'updatedAt': FieldValue.serverTimestamp(),
        })
        .catchError((_) async {
          await threadMetaRef.set({
            'doctorId': doctorId,
            'patientId': patientId,
            'lastMessage': '',
            'lastSenderRole': role,
            'updatedAt': FieldValue.serverTimestamp(),
            'unreadForDoctor': 0,
            'unreadForPatient': 0,
          });
        });
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> streamDoctorThreads(
    String doctorId,
  ) {
    return _db
        .collection('chat_threads')
        .where('doctorId', isEqualTo: doctorId)
        .snapshots();
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> streamPatientThreads(
    String patientId,
  ) {
    return _db
        .collection('chat_threads')
        .where('patientId', isEqualTo: patientId)
        .snapshots();
  }
}
