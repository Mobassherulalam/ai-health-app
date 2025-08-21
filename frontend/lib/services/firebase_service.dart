import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../firebase_options.dart';

class FirebaseService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static bool _initialized = false;
  static bool _hasError = false;
  static String? _errorMessage;

  static String? get errorMessage => _errorMessage;
  static bool get hasError => _hasError;

  static Future<bool> initialize() async {
    if (_initialized) return !_hasError;

    try {
      _hasError = false;
      _errorMessage = null;

      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      await FirebaseFirestore.instance
          .runTransaction((transaction) async {
            return true;
          })
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () =>
                throw TimeoutException('Firebase connection timeout'),
          );

      if (kIsWeb) {
        FirebaseFirestore.instance.settings = const Settings(
          persistenceEnabled: true,
          cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
        );
      } else {
        _db.settings = const Settings(
          persistenceEnabled: true,
          cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
        );
      }

      _initialized = true;
      debugPrint('Firebase initialized successfully');
      return true;
    } catch (e) {
      _hasError = true;
      _errorMessage = _getReadableErrorMessage(e);
      debugPrint('Failed to initialize Firebase: $_errorMessage');
      return false;
    }
  }

  static String _getReadableErrorMessage(dynamic error) {
    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return 'Permission denied. Please check your Firebase rules.';
        case 'unavailable':
          return 'Firebase service is currently unavailable. Please check your internet connection.';
        case 'not-found':
          return 'Requested resource was not found.';
        case 'already-exists':
          return 'Document already exists.';
        default:
          return 'Firebase error: ${error.message}';
      }
    } else if (error is TimeoutException) {
      return 'Connection timeout. Please check your internet connection.';
    }
    return error.toString();
  }

  static final CollectionReference usersCollection = _db.collection('users');
  static final CollectionReference patientsCollection = _db.collection(
    'patients',
  );
  static final CollectionReference doctorsCollection = _db.collection(
    'doctors',
  );
  static final CollectionReference healthDataCollection = _db.collection(
    'health_data',
  );
  static final CollectionReference alertsCollection = _db.collection('alerts');

  static Future<List<Map<String, dynamic>>> fetchDoctors() async {
    try {
      debugPrint('Starting fetchDoctors...');

      if (!_initialized) {
        debugPrint('Firebase not initialized, attempting to initialize...');
        final success = await initialize();
        if (!success)
          throw Exception(_errorMessage ?? 'Firebase not initialized');
        debugPrint('Firebase initialization successful');
      }

      final currentUser = FirebaseAuth.instance.currentUser;
      debugPrint('Current user: ${currentUser?.uid ?? 'Not authenticated'}');

      if (currentUser == null) {
        throw Exception('User must be authenticated to fetch doctors');
      }

      debugPrint('Attempting to fetch doctors from collection...');
      debugPrint('Collection path: ${doctorsCollection.path}');

      final collectionCheck = await doctorsCollection.limit(1).get();
      debugPrint('Collection exists: ${collectionCheck.size > 0}');
      debugPrint('Number of documents found in check: ${collectionCheck.size}');

      final QuerySnapshot snapshot = await doctorsCollection.get();
      debugPrint(
        'Successfully fetched doctors. Count: ${snapshot.docs.length}',
      );

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        debugPrint('Doctor found - ID: ${doc.id}');
        return {'id': doc.id, ...data};
      }).toList();
    } catch (e) {
      debugPrint('Error fetching doctors: ${_getReadableErrorMessage(e)}');
      throw Exception(_getReadableErrorMessage(e));
    }
  }

  static Future<void> createDocument(
    String collection,
    String? id,
    Map<String, dynamic> data,
  ) async {
    try {
      if (!_initialized) {
        final success = await initialize();
        if (!success)
          throw Exception(_errorMessage ?? 'Firebase not initialized');
      }

      final CollectionReference collectionRef = _db.collection(collection);
      if (id != null) {
        await collectionRef.doc(id).set(data, SetOptions(merge: true));
      } else {
        await collectionRef.add(data);
      }
    } catch (e) {
      throw Exception(_getReadableErrorMessage(e));
    }
  }

  static Future<Map<String, dynamic>?> readDocument(
    String collection,
    String id,
  ) async {
    try {
      if (!_initialized) {
        final success = await initialize();
        if (!success)
          throw Exception(_errorMessage ?? 'Firebase not initialized');
      }

      final docSnapshot = await _db.collection(collection).doc(id).get();
      return docSnapshot.data();
    } catch (e) {
      throw Exception(_getReadableErrorMessage(e));
    }
  }

  static Future<void> updateDocument(
    String collection,
    String id,
    Map<String, dynamic> data,
  ) async {
    try {
      if (!_initialized) {
        final success = await initialize();
        if (!success)
          throw Exception(_errorMessage ?? 'Firebase not initialized');
      }

      await _db.collection(collection).doc(id).update(data);
    } catch (e) {
      throw Exception(_getReadableErrorMessage(e));
    }
  }

  static Future<void> deleteDocument(String collection, String id) async {
    try {
      if (!_initialized) {
        final success = await initialize();
        if (!success)
          throw Exception(_errorMessage ?? 'Firebase not initialized');
      }

      await _db.collection(collection).doc(id).delete();
    } catch (e) {
      throw Exception(_getReadableErrorMessage(e));
    }
  }

  static Stream<QuerySnapshot> streamCollection(String collection) {
    if (!_initialized) {
      throw Exception(_errorMessage ?? 'Firebase not initialized');
    }
    return _db.collection(collection).limit(50).snapshots();
  }

  static Stream<DocumentSnapshot> streamDocument(String collection, String id) {
    if (!_initialized) {
      throw Exception(_errorMessage ?? 'Firebase not initialized');
    }
    return _db
        .collection(collection)
        .doc(id)
        .snapshots(includeMetadataChanges: false);
  }

  static Future<List<Map<String, dynamic>>> getCollection(
    String collection,
  ) async {
    try {
      if (!_initialized) {
        final success = await initialize();
        if (!success)
          throw Exception(_errorMessage ?? 'Firebase not initialized');
      }

      final querySnapshot = await _db.collection(collection).get();
      return querySnapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      throw Exception(_getReadableErrorMessage(e));
    }
  }
}
