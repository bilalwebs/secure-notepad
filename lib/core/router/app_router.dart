import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:secure_notepad/presentation/providers/auth_provider.dart';
import 'package:secure_notepad/data/models/note_model.dart';
import 'package:secure_notepad/presentation/screens/auth/splash_screen.dart';
import 'package:secure_notepad/presentation/screens/auth/onboarding_screen.dart';
import 'package:secure_notepad/presentation/screens/auth/login_screen.dart';
import 'package:secure_notepad/presentation/screens/auth/register_screen.dart';
import 'package:secure_notepad/presentation/screens/auth/forgot_password_screen.dart';
import 'package:secure_notepad/presentation/screens/auth/email_verify_screen.dart';
import 'package:secure_notepad/presentation/screens/home/home_screen.dart';
import 'package:secure_notepad/presentation/screens/editor/note_editor_screen.dart';
import 'package:secure_notepad/presentation/screens/search/search_screen.dart';
import 'package:secure_notepad/presentation/screens/calendar/calendar_screen.dart';
import 'package:secure_notepad/presentation/screens/pricing/pricing_screen.dart';
import 'package:secure_notepad/presentation/screens/profile/profile_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/splash',
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final isLoggedIn = authState.whenOrNull(
        data: (user) => user != null,
      );
      final isGoingTo = state.matchedLocation;

      // Splash always allowed
      if (isGoingTo == '/splash') return null;

      // If not logged in → force to /login (except public routes)
      if (isLoggedIn != true) {
        const publicRoutes = [
          '/login',
          '/register',
          '/forgot-password',
          '/onboarding',
        ];
        if (publicRoutes.contains(isGoingTo)) return null;
        return '/login';
      }

      // If logged in → block auth screens
      const authRoutes = [
        '/login',
        '/register',
        '/forgot-password',
        '/onboarding',
      ];
      if (authRoutes.contains(isGoingTo)) {
        // If email verified go home, otherwise verify screen
        final user = authState.valueOrNull;
        if (user != null && !user.emailVerified) return '/verify-email';
        return '/home';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/verify-email',
        builder: (context, state) => const EmailVerifyScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/editor',
        builder: (context, state) {
          final note = state.extra as NoteModel?;
          return NoteEditorScreen(note: note);
        },
      ),
      GoRoute(
        path: '/search',
        builder: (context, state) => const SearchScreen(),
      ),
      GoRoute(
        path: '/calendar',
        builder: (context, state) => const CalendarScreen(),
      ),
      GoRoute(
        path: '/pricing',
        builder: (context, state) => const PricingScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
    ],
  );
});
