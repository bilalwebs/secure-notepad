import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:secure_notepad/core/exceptions/app_exception.dart';

class AuthRepository {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  GoogleSignIn? _googleSignIn;

  AuthRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    GoogleSignIn? googleSignIn,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _googleSignIn = googleSignIn;

  /// Lazy init — avoids the eager web assertion crash on startup.
  GoogleSignIn get _gsi {
    _googleSignIn ??= GoogleSignIn(
      // On web, clientId must be provided. On mobile it's auto-detected.
      // The user must set this in Google Cloud Console → OAuth 2.0 Client IDs.
      clientId: kIsWeb
          ? '543285176326-tm34aikaphp0d1586an4u37591a6oehn.apps.googleusercontent.com'
          : null,
    );
    return _googleSignIn!;
  }

  /// Current Firebase user (null if signed out).
  User? get currentUser => _auth.currentUser;

  /// Real-time auth state changes stream.
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Real-time id-token changes (handles email verification refresh).
  Stream<User?> get idTokenChanges => _auth.idTokenChanges();

  // ─────────────────────────── Register ───────────────────────────

  Future<UserCredential> register({
    required String email,
    required String password,
    required String fullName,
    required String username,
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Update display name
      await cred.user!.updateDisplayName(fullName);

      // Create Firestore user document
      await _firestore.collection('users').doc(cred.user!.uid).set({
        'uid': cred.user!.uid,
        'fullName': fullName,
        'username': username.toLowerCase().trim(),
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Send verification email
      await cred.user!.sendEmailVerification();

      return cred;
    } on FirebaseAuthException catch (e) {
      throw AppException.fromFirebaseAuth(e);
    } on FirebaseException catch (e) {
      throw AppException.fromFirestore(e);
    }
  }

  // ─────────────────────────── Login ──────────────────────────────

  Future<UserCredential> login({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw AppException.fromFirebaseAuth(e);
    }
  }

  // ─────────────────────────── Google Sign-In ─────────────────────

  Future<UserCredential> googleSignIn() async {
    try {
      UserCredential cred;

      if (kIsWeb) {
        // Web: use Firebase's built-in popup — no extra client ID needed.
        final provider = GoogleAuthProvider()
          ..addScope('email')
          ..setCustomParameters({'prompt': 'select_account'});
        cred = await _auth.signInWithPopup(provider);
      } else {
        // Mobile: use the native Google Sign-In SDK.
        final googleUser = await _gsi.signIn();
        if (googleUser == null) {
          throw const AppException('Sign-in cancelled.');
        }
        final googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        cred = await _auth.signInWithCredential(credential);
      }

      // Create Firestore doc if first time
      final docRef = _firestore.collection('users').doc(cred.user!.uid);
      final doc = await docRef.get();
      if (!doc.exists) {
        final name = cred.user!.displayName ?? '';
        final email = cred.user!.email ?? '';
        final username = email.split('@').first.toLowerCase().replaceAll(
              RegExp(r'[^a-z0-9]'),
              '',
            );
        await docRef.set({
          'uid': cred.user!.uid,
          'fullName': name,
          'username': username,
          'email': email,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      return cred;
    } on FirebaseAuthException catch (e) {
      throw AppException.fromFirebaseAuth(e);
    } on FirebaseException catch (e) {
      throw AppException.fromFirestore(e);
    }
  }

  // ─────────────────────────── Logout ─────────────────────────────

  Future<void> logout() async {
    try {
      if (kIsWeb) {
        await _auth.signOut();
      } else {
        await Future.wait([
          _auth.signOut(),
          _gsi.signOut(),
        ]);
      }
    } on FirebaseAuthException catch (e) {
      throw AppException.fromFirebaseAuth(e);
    }
  }

  // ─────────────────────────── Password Reset ─────────────────────

  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw AppException.fromFirebaseAuth(e);
    }
  }

  // ─────────────────────────── Resend Verification ────────────────

  Future<void> resendVerification() async {
    try {
      await _auth.currentUser?.sendEmailVerification();
    } on FirebaseAuthException catch (e) {
      throw AppException.fromFirebaseAuth(e);
    }
  }

  // ─────────────────────────── Reload User ───────────────────────

  Future<void> reloadUser() async {
    await _auth.currentUser?.reload();
  }

  // ─────────────────────────── Username Check ─────────────────────

  Future<bool> checkUsernameAvailable(String username) async {
    final query = await _firestore
        .collection('users')
        .where('username', isEqualTo: username.toLowerCase().trim())
        .limit(1)
        .get();
    return query.docs.isEmpty;
  }

  // ─────────────────────────── Get User Data ─────────────────────

  Future<Map<String, dynamic>?> getUserData(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.data();
  }
}
