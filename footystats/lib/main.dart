import 'dart:async';

import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/adaptive/adaptive.dart';
import 'core/config/env_config.dart';
import 'core/onboarding/onboarding_completion.dart';
import 'core/theme/theme.dart';
import 'core/utils/pending_shared_video.dart';
import 'core/utils/referee_whistle_player.dart';
import 'core/utils/video_share.dart';
import 'core/utils/util.dart';
import 'domain/models/onboarding_draft.dart';
import 'presentation/pages/home_page.dart';
import 'presentation/pages/onboarding_intro_page.dart';
import 'presentation/pages/onboarding_join_team_page.dart';
import 'presentation/pages/shared_video_page.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  unawaited(RefereeWhistlePlayer.instance.warmUp());
  EnvConfig.validate();
  await Supabase.initialize(
    url: EnvConfig.supabaseUrl,
    anonKey: EnvConfig.supabaseAnonKey,
  );
  _listenForSharedVideoLinks();

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

void _listenForSharedVideoLinks() {
  PendingSharedVideo.offer(VideoShare.incomingVideoId());
  try {
    final appLinks = AppLinks();
    appLinks.getInitialLink().then((uri) {
      if (uri != null) {
        PendingSharedVideo.offer(VideoShare.incomingVideoId(uri));
      }
    });
    appLinks.uriLinkStream.listen((uri) {
      PendingSharedVideo.offer(VideoShare.incomingVideoId(uri));
    });
  } catch (_) {}
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brightness = View.of(context).platformDispatcher.platformBrightness;

    TextTheme textTheme = createTextTheme(context, "Roboto", "Roboto");

    MaterialTheme theme = MaterialTheme(textTheme);
    return MaterialApp(
      navigatorKey: rootNavigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Ballo',
      theme: brightness == Brightness.light ? theme.light() : theme.dark(),
      builder: (context, child) {
        return MobileResponsiveScope(
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const _LaunchShell(),
    );
  }
}

/// Opens a shared `?v=` highlight on top of the normal auth flow.
class _LaunchShell extends StatefulWidget {
  const _LaunchShell();

  @override
  State<_LaunchShell> createState() => _LaunchShellState();
}

class _LaunchShellState extends State<_LaunchShell> {
  @override
  void initState() {
    super.initState();
    PendingSharedVideo.id.addListener(_onPending);
  }

  @override
  void dispose() {
    PendingSharedVideo.id.removeListener(_onPending);
    super.dispose();
  }

  void _onPending() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final videoId = PendingSharedVideo.id.value;
    if (videoId != null) {
      return SharedVideoPage(videoId: videoId);
    }
    return const _AuthGate();
  }
}

/// Signed-out users start onboarding. Signed-in users only reach home after
/// the join-team step marks onboarding complete.
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final session = snapshot.data?.session;

        if (session == null) {
          return const OnboardingIntroPage();
        }

        if (session.user.isAnonymous) {
          return const HomePage();
        }

        if (OnboardingCompletion.isCompleteFromUser(session.user)) {
          return const HomePage();
        }

        return FutureBuilder<bool>(
          future: OnboardingCompletion.isComplete(),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (snapshot.data == true) {
              return const HomePage();
            }

            return const OnboardingJoinTeamPage(
              draft: OnboardingDraft(),
            );
          },
        );
      },
    );
  }
}
