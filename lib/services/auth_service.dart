import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dart:math';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ── Check if email already registered ─────────────────
  Future<bool> isEmailRegistered(String email) async {
    try {
      final methods = await _auth.fetchSignInMethodsForEmail(email.trim());
      return methods.isNotEmpty;
    } catch (e) { return false; }
  }

  // ── Sign up with email (no verification email) ─────────
  Future<Map<String, dynamic>> signUpWithEmail({
    required String fullName,
    required String email,
    required String password,
    required String phone,
    required String dob,
    required String state,
    required String qualification,
    required String gender,
  }) async {
    try {
      // Check duplicate email
      final emailExists = await isEmailRegistered(email);
      if (emailExists) {
        return {'success': false, 'error': 'email-already-in-use'};
      }

      final result = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = result.user;
      if (user != null) {
        await user.updateDisplayName(fullName);
        // No verification email sent
        await _db.collection('users').doc(user.uid).set({
          'uid':           user.uid,
          'fullName':      fullName,
          'email':         email.trim(),
          'phone':         phone,
          'dob':           dob,
          'state':         state,
          'qualification': qualification,
          'gender':        gender,
          'category':      'General',
          'savedJobs':     [],
          'appliedJobs':   [],
          'preferredCategories': [],
          'signInMethod':  'email',
          'profileComplete': true,
          'createdAt':     FieldValue.serverTimestamp(),
        });
      }
      return {'success': true};
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
      final result = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return {'success': true, 'user': result.user};
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

  // ── Sign in with Google ────────────────────────────────
  Future<Map<String, dynamic>> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn(clientId: "631082617337-l40lumnjbbrm8a4i1hkj2cj8b8ehblnu.apps.googleusercontent.com").signIn();
      if (googleUser == null) return {'success': false, 'error': 'cancelled'};

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final result = await _auth.signInWithCredential(credential);
      final user = result.user;
      if (user == null) return {'success': false, 'error': 'unknown'};

      final doc = await _db.collection('users').doc(user.uid).get();
      if (!doc.exists) {
        await _db.collection('users').doc(user.uid).set({
          'uid':           user.uid,
          'fullName':      user.displayName ?? '',
          'email':         user.email ?? '',
          'phone':         '',
          'dob':           '',
          'state':         '',
          'qualification': '',
          'category':      'General',
          'gender':        'Male',
          'savedJobs':     [],
          'appliedJobs':   [],
          'preferredCategories': [],
          'emailVerified': true,
          'signInMethod':  'google',
          'profileComplete': false,
          'createdAt':     FieldValue.serverTimestamp(),
        });
        return {'success': true, 'profileComplete': false, 'user': user};
      }

      final profileComplete = doc.data()?['profileComplete'] == true;
      return {'success': true, 'profileComplete': profileComplete, 'user': user};
    } on FirebaseAuthException catch (e) {
      return {'success': false, 'error': e.code};
    } catch (e) {
      return {'success': false, 'error': 'unknown'};
    }
  }

  // ── Generates a cryptographically secure random nonce, to be
  //    included in a credential request — required by Apple's
  //    Sign in with Apple security model to prevent replay attacks ──
  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)])
        .join();
  }

  // Returns the SHA256 hash of a given input string, used to pass the
  // raw nonce's hash to Apple while keeping the raw nonce for Firebase.
  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // ── Sign in with Apple ──────────────────────────────────
  // Mirrors signInWithGoogle() exactly: same return shape, same
  // Firestore document fields, so downstream screens (login_screen,
  // signup_screen) don't need any special-casing for Apple vs Google.
  Future<Map<String, dynamic>> signInWithApple() async {
    try {
      final rawNonce = _generateNonce();
      final nonce = _sha256ofString(rawNonce);

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );

      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        rawNonce: rawNonce,
        accessToken: appleCredential.authorizationCode,
      );

      final result = await _auth.signInWithCredential(oauthCredential);
      final user = result.user;
      if (user == null) return {'success': false, 'error': 'unknown'};

      // Apple only returns the user's name on the VERY FIRST sign-in ever.
      // On every later sign-in, givenName/familyName come back null, so we
      // capture it now if available and fall back to Firebase's user
      // record (or empty string) otherwise.
      final appleFullName = [
        appleCredential.givenName,
        appleCredential.familyName,
      ].where((s) => s != null && s.isNotEmpty).join(' ').trim();

      final doc = await _db.collection('users').doc(user.uid).get();
      if (!doc.exists) {
        await _db.collection('users').doc(user.uid).set({
          'uid':           user.uid,
          'fullName':      appleFullName.isNotEmpty ? appleFullName : (user.displayName ?? ''),
          'email':         appleCredential.email ?? user.email ?? '',
          'phone':         '',
          'dob':           '',
          'state':         '',
          'qualification': '',
          'category':      'General',
          'gender':        'Male',
          'savedJobs':     [],
          'appliedJobs':   [],
          'preferredCategories': [],
          'emailVerified': true,
          'signInMethod':  'apple',
          'profileComplete': false,
          'createdAt':     FieldValue.serverTimestamp(),
        });
        return {'success': true, 'profileComplete': false, 'user': user};
      }

      final profileComplete = doc.data()?['profileComplete'] == true;
      return {'success': true, 'profileComplete': profileComplete, 'user': user};
    } on SignInWithAppleAuthorizationException catch (e) {
      // Covers the user tapping "Cancel" on the native Apple sign-in sheet,
      // matching the same 'cancelled' error shape signInWithGoogle() uses.
      if (e.code == AuthorizationErrorCode.canceled) {
        return {'success': false, 'error': 'cancelled'};
      }
      return {'success': false, 'error': 'unknown'};
    } on FirebaseAuthException catch (e) {
      return {'success': false, 'error': e.code};
    } catch (e) {
      return {'success': false, 'error': 'unknown'};
    }
  }

  // ── Sign out ───────────────────────────────────────────
  Future<void> signOut() async {
    await GoogleSignIn().signOut();
    // Apple has no SDK-level signOut call (unlike Google) — signing out of
    // Firebase below is sufficient to end the app session.
    await _auth.signOut();
  }

  // ── Get user data ──────────────────────────────────────
  Future<Map<String, dynamic>?> getUserData(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (doc.exists) return doc.data() as Map<String, dynamic>;
      return null;
    } catch (e) { return null; }
  }

  // ── Update user profile ────────────────────────────────
  Future<bool> updateUserProfile(String uid, Map<String, dynamic> data) async {
    try {
      await _db.collection('users').doc(uid).update(data);
      return true;
    } catch (e) { return false; }
  }
}