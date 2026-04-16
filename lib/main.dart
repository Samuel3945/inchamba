import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'presentation/providers/router_provider.dart';
import 'presentation/providers/theme_provider.dart';

/// Whether Supabase initialized successfully.
bool supabaseReady = false;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    // ignore: avoid_print
    print('FLUTTER_ERROR: ${details.exception}\n${details.stack}');
  };

  // Initialize intl locale data for Spanish date formatting
  await initializeDateFormatting('es');

  // Set timeago locale (sync, no risk)
  timeago.setLocaleMessages('es', timeago.EsMessages());

  // Initialize Supabase with protection: validate env vars + timeout
  final url = AppConstants.supabaseUrl;
  final key = AppConstants.supabaseAnonKey;

  debugPrint('[MAIN] SUPABASE_URL=${url.isNotEmpty ? "${url.substring(0, 20)}..." : "EMPTY"}');
  debugPrint('[MAIN] SUPABASE_ANON_KEY=${key.isNotEmpty ? "${key.substring(0, 10)}..." : "EMPTY"}');

  if (url.isNotEmpty && key.isNotEmpty) {
    try {
      debugPrint('[MAIN] Calling Supabase.initialize()...');
      await Supabase.initialize(url: url, anonKey: key)
          .timeout(const Duration(seconds: 5));
      supabaseReady = true;
      debugPrint('[MAIN] Supabase initialized OK');
    } catch (e) {
      debugPrint('[MAIN] Supabase init FAILED: $e');
    }
  } else {
    debugPrint('[MAIN] SUPABASE_URL or SUPABASE_ANON_KEY not set via --dart-define');
  }

  debugPrint('[MAIN] supabaseReady=$supabaseReady, launching app');

  // runApp() ALWAYS executes — the user sees UI no matter what
  runApp(const ProviderScope(child: InchambaApp()));
}

class InchambaApp extends ConsumerWidget {
  const InchambaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'Inchamba',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
