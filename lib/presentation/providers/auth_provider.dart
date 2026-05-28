import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:secure_notepad/data/repositories/auth_repository.dart';

// ───────────────────────── Providers ─────────────────────────────

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

/// Stream of auth state changes — drives the router redirect.
final authStateProvider = StreamProvider<User?>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return repo.authStateChanges;
});

/// Main auth state notifier.
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(authRepositoryProvider));
});

// ───────────────────────── AuthState ─────────────────────────────

enum AuthStatus { loading, authenticated, unauthenticated, error }

class AuthState {
  final AuthStatus status;
  final User? user;
  final String? errorMessage;

  const AuthState._({required this.status, this.user, this.errorMessage});

  const AuthState.loading() : this._(status: AuthStatus.loading);
  const AuthState.authenticated(User user)
      : this._(status: AuthStatus.authenticated, user: user);
  const AuthState.unauthenticated()
      : this._(status: AuthStatus.unauthenticated);
  const AuthState.error(String message)
      : this._(status: AuthStatus.error, errorMessage: message);

  bool get isLoading => status == AuthStatus.loading;
  bool get isAuthenticated => status == AuthStatus.authenticated;
}

// ───────────────────────── AuthNotifier ──────────────────────────

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repo;
  StreamSubscription<User?>? _sub;

  AuthNotifier(this._repo) : super(const AuthState.loading()) {
    _sub = _repo.idTokenChanges.listen((user) {
      if (user != null) {
        state = AuthState.authenticated(user);
      } else {
        state = const AuthState.unauthenticated();
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  // ── Register ──

  Future<bool> register({
    required String email,
    required String password,
    required String fullName,
    required String username,
  }) async {
    state = const AuthState.loading();
    try {
      await _repo.register(
        email: email,
        password: password,
        fullName: fullName,
        username: username,
      );
      // State will update via the stream listener.
      return true;
    } catch (e) {
      state = AuthState.error(e.toString());
      return false;
    }
  }

  // ── Login ──

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    state = const AuthState.loading();
    try {
      await _repo.login(email: email, password: password);
      return true;
    } catch (e) {
      state = AuthState.error(e.toString());
      return false;
    }
  }

  // ── Google Sign-In ──

  Future<bool> googleSignIn() async {
    state = const AuthState.loading();
    try {
      await _repo.googleSignIn();
      return true;
    } catch (e) {
      state = AuthState.error(e.toString());
      return false;
    }
  }

  // ── Logout ──

  Future<void> logout() async {
    state = const AuthState.loading();
    try {
      await _repo.logout();
    } catch (e) {
      state = AuthState.error(e.toString());
    }
  }

  // ── Password Reset ──

  Future<bool> sendPasswordReset(String email) async {
    try {
      await _repo.sendPasswordReset(email);
      return true;
    } catch (e) {
      state = AuthState.error(e.toString());
      return false;
    }
  }

  // ── Resend Verification ──

  Future<void> resendVerification() async {
    await _repo.resendVerification();
  }

  // ── Username Check ──

  Future<bool> checkUsernameAvailable(String username) {
    return _repo.checkUsernameAvailable(username);
  }

  // ── Reload user (for email verification check) ──

  Future<void> reloadUser() async {
    await _repo.reloadUser();
  }

  // ── Get user data from Firestore ──

  Future<Map<String, dynamic>?> getUserData(String uid) {
    return _repo.getUserData(uid);
  }

  // ── Clear error ──

  void clearError() {
    if (state.status == AuthStatus.error) {
      state = const AuthState.unauthenticated();
    }
  }
}
