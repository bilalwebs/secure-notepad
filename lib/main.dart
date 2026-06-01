import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:secure_notepad/firebase_options.dart';
import 'package:secure_notepad/core/encryption/maze_card_cipher.dart';
import 'package:secure_notepad/core/router/app_router.dart';
import 'package:secure_notepad/core/theme/app_theme.dart';
import 'package:secure_notepad/core/services/notification_service.dart';
import 'package:secure_notepad/presentation/providers/theme_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await Hive.initFlutter();

  tz.initializeTimeZones();

  await NotificationService.init();

  // Verify cipher encrypt/decrypt round-trip on every app start
  MazeCardCipher.selfTest();

  runApp(
    const ProviderScope(
      child: SecureNotepadApp(),
    ),
  );
}

class SecureNotepadApp extends ConsumerWidget {
  const SecureNotepadApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Secure Notepad',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
      localizationsDelegates: const [
        FlutterQuillLocalizations.delegate,
        DefaultMaterialLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
    );
  }
}
