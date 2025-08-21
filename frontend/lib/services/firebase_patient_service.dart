import 'package:cloud_firestore/cloud_firestore.dart';

class FirebasePatientService {
  static Future<List<Map<String, dynamic>>> fetchPatientsForDoctor(
    String doctorId,
  ) async {
    final querySnapshot = await FirebaseFirestore.instance
        .collection('patients')
        .where('assignedDoctorId', isEqualTo: doctorId)
        .get();
    return querySnapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      if (data['image'] == null ||
          data['image'] is! String ||
          (data['image'] as String).isEmpty) {
        data['image'] = null;
      }
      return data;
    }).toList();
  }
}
