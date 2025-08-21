import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_service.dart';

class AuthService {
  static const String _userTypeKey = 'user_type';
  static const String _isLoggedInKey = 'is_logged_in';
  static const String _userIdKey = 'user_id';
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static Future<UserCredential> createUserWithEmailAndPassword(
    String email,
    String password,
    String userType,
  ) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    await saveUserData(credential.user!.uid, userType);
    return credential;
  }

  static Future<bool> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        final doctorData = await FirebaseService.readDocument(
          'doctors',
          credential.user!.uid,
        );
        if (doctorData != null) {
          await saveUserData(credential.user!.uid, 'doctor');
          return true;
        }

        final patientData = await FirebaseService.readDocument(
          'patients',
          credential.user!.uid,
        );
        if (patientData != null) {
          await saveUserData(credential.user!.uid, 'patient');
          return true;
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  static Future<void> saveUserData(String userId, String userType) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userIdKey, userId);
    await prefs.setString(_userTypeKey, userType);
    await prefs.setBool(_isLoggedInKey, true);
  }

  static Future<String?> getCurrentUserType() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userTypeKey);
  }

  static Future<String?> getCurrentUserId() async {
    final user = _auth.currentUser;
    if (user != null) return user.uid;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userIdKey);
  }

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isLoggedInKey) ?? false;
  }

  static Future<void> signOut() async {
    await _auth.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
