import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/theme.dart';
import 'core/utils/util.dart';
import 'presentation/pages/home_page.dart';
import 'presentation/pages/welcome_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// TODO: Initialize Supabase when credentials are available
// import 'data/datasources/remote/supabase_client.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://dcpltazuzyyhxtkpbuiu.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRjcGx0YXp1enl5aHh0a3BidWl1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njk3NzI2NzgsImV4cCI6MjA4NTM0ODY3OH0.7fAERtevC9DfpHaBLhXJfzb_DBCbkSbU6G505lrb_Iw',
  );

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brightness = View.of(context).platformDispatcher.platformBrightness;

    // Use with Google Fonts package to use downloadable fonts
    TextTheme textTheme = createTextTheme(context, "Roboto", "Roboto");

    MaterialTheme theme = MaterialTheme(textTheme);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'FootyStats',
      theme: brightness == Brightness.light ? theme.light() : theme.dark(),
      home: const _AuthGate(),
    );
  }
}

/// Simple auth gate that decides whether to show the main app shell
/// or the onboarding / auth flow.
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;

    if (session != null) {
      return const HomePage();
    }

    return const WelcomePage();
  }
}
