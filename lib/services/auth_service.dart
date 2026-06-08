import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Get current user ───────────────────────────────────
  User? get currentUser => _auth.currentUser;

  // ── Auth state stream ──────────────────────────────────
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ── Sign up with email ─────────────────────────────────
  Future<Map<String, dynamic>> signUpWithEmail({
    required String fullName,
    required String email,
    required String password,
    required String phone,
    required String dob,
    required String state,
    required String qualification,
  }) async {
    try {
      UserCredential result =
      await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      User? user = result.user;
      if (user != null) {
        await user.updateDisplayName(fullName);

        // ── Send verification email ──────────────────────
        await user.sendEmailVerification();

        // Save user data to Firestore
        await _db.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'fullName': fullName,
          'email': email.trim(),
          'phone': phone,
          'dob': dob,
          'state': state,
          'qualification': qualification,
          'category': 'General',
          'gender': 'Male',
          'savedJobs': [],
          'appliedJobs': [],
          'preferredCategories': [],
          'emailVerified': false,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Sign out immediately — force verification first
        await _auth.signOut();
      }

      return {'success': true, 'requiresVerification': true};
    } on FirebaseAuthException catch (e) {
      return {'success': false, 'error': e.code};
    } catch (e) {
      return {'success': false, 'error': 'unknown'};
    }
  }

  // ── Login with email ───────────────────────────────────
  Future<Map<String, dynamic>> loginWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      UserCredential result =
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      // ── Check if email is verified ───────────────────
      if (result.user != null && !result.user!.emailVerified) {
        await _auth.signOut();
        return {'success': false, 'error': 'email-not-verified',
          'email': email.trim()};
      }

      return {'success': true, 'user': result.user};
    } on FirebaseAuthException catch (e) {
      return {'success': false, 'error': e.code};
    } catch (e) {
      return {'success': false, 'error': 'unknown'};
    }
  }

  // ── Resend verification email ──────────────────────────
  Future<Map<String, dynamic>> resendVerificationEmail({
    required String email,
    required String password,
  }) async {
    try {
      UserCredential result =
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await result.user?.sendEmailVerification();
      await _auth.signOut();
      return {'success': true};
    } on FirebaseAuthException catch (e) {
      return {'success': false, 'error': e.code};
    } catch (e) {
      return {'success': false, 'error': 'unknown'};
    }
  }

  // ── Forgot password ────────────────────────────────────
  Future<Map<String, dynamic>> forgotPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return {'success': true};
    } on FirebaseAuthException catch (e) {
      return {'success': false, 'error': e.code};
    } catch (e) {
      return {'success': false, 'error': 'unknown'};
    }
  }

  // ── Sign out ───────────────────────────────────────────
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // ── Get user data from Firestore ───────────────────────
  Future<Map<String, dynamic>?> getUserData(String uid) async {
    try {
      DocumentSnapshot doc =
      await _db.collection('users').doc(uid).get();
      if (doc.exists) {
        return doc.data() as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ── Update user profile ────────────────────────────────
  Future<bool> updateUserProfile(
      String uid, Map<String, dynamic> data) async {
    try {
      await _db.collection('users').doc(uid).update(data);
      return true;
    } catch (e) {
      return false;
    }
  }
}