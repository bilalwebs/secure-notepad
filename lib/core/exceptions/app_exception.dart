import 'package:firebase_auth/firebase_auth.dart';

class AppException implements Exception {
  final String message;
  final String? code;

  const AppException(this.message, {this.code});

  @override
  String toString() => message;

  /// Maps FirebaseAuthException codes to user-friendly Urdu/English messages.
  factory AppException.fromFirebaseAuth(FirebaseAuthException e) {
    switch (e.code) {
      // ── Registration ──
      case 'email-already-in-use':
        return const AppException(
          'Ye email pehle se registered hai. Login karein ya doosri email use karein.\n'
          'This email is already registered. Please login or use another email.',
          code: 'email-already-in-use',
        );
      case 'weak-password':
        return const AppException(
          'Password bohot kamzor hai. Kam se kam 8 characters, uppercase, number aur symbol use karein.\n'
          'Password is too weak. Use at least 8 characters with uppercase, number and symbol.',
          code: 'weak-password',
        );
      case 'invalid-email':
        return const AppException(
          'Email format galat hai. Sahih email darj karein.\n'
          'Invalid email format. Please enter a valid email.',
          code: 'invalid-email',
        );

      // ── Login ──
      case 'user-not-found':
        return const AppException(
          'Is email se koi account nahi mila. Register karein ya email check karein.\n'
          'No account found with this email. Please register or check your email.',
          code: 'user-not-found',
        );
      case 'wrong-password':
        return const AppException(
          'Galat password. Dobara try karein ya "Forgot Password" use karein.\n'
          'Wrong password. Try again or use "Forgot Password".',
          code: 'wrong-password',
        );
      case 'invalid-credential':
        return const AppException(
          'Email ya password galat hai. Dobara check karein.\n'
          'Email or password is incorrect. Please check and try again.',
          code: 'invalid-credential',
        );
      case 'user-disabled':
        return const AppException(
          'Ye account disable kar diya gaya hai. Support se raabta karein.\n'
          'This account has been disabled. Contact support.',
          code: 'user-disabled',
        );

      // ── Too many attempts ──
      case 'too-many-requests':
        return const AppException(
          'Bohot zyada koshishein. Kuch der baad try karein.\n'
          'Too many attempts. Please try again later.',
          code: 'too-many-requests',
        );

      // ── Network ──
      case 'network-request-failed':
        return const AppException(
          'Internet connection check karein.\n'
          'Please check your internet connection.',
          code: 'network-request-failed',
        );

      // ── Operation not allowed ──
      case 'operation-not-allowed':
        return const AppException(
          'Ye sign-in method enable nahi hai. Firebase Console mein check karein.\n'
          'This sign-in method is not enabled. Check Firebase Console.',
          code: 'operation-not-allowed',
        );

      // ── Fallback ──
      default:
        return AppException(
          'Kuch ghalat ho gaya: ${e.message}\n'
          'Something went wrong: ${e.message}',
          code: e.code,
        );
    }
  }

  /// Generic Firestore errors.
  factory AppException.fromFirestore(FirebaseException e) {
    switch (e.code) {
      case 'permission-denied':
        return const AppException(
          'Ijazat nahi hai. Dobara login karein.\n'
          'Permission denied. Please login again.',
          code: 'permission-denied',
        );
      case 'unavailable':
        return const AppException(
          'Service abhi uplabdh nahi hai. Baad mein try karein.\n'
          'Service unavailable. Please try again later.',
          code: 'unavailable',
        );
      default:
        return AppException(
          'Database error: ${e.message}',
          code: e.code,
        );
    }
  }
}
