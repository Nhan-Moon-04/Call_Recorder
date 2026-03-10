import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/firebase_config.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<User?> signInWithEmail(String email, String password) async {
    final result = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    return result.user;
  }

  Future<User?> registerWithEmail(String email, String password) async {
    final result = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    // Save user data to Firestore
    if (result.user != null) {
      await _firestore
          .collection(FirebaseConfig.usersCollection)
          .doc(result.user!.uid)
          .set({
            'uid': result.user!.uid,
            'email': email.trim(),
            'createdAt': FieldValue.serverTimestamp(),
            'settings': {
              'autoRecord': false,
              'autoRecordVideo': false,
              'recordingQuality': 'medium',
            },
          });
    }

    return result.user;
  }

  Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}
