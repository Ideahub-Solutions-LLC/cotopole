import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/setup_screen.dart';
import '../features/auth/splash_screen.dart';
import '../features/auth/unlock_screen.dart';
import '../features/auth/welcome_screen.dart';
import '../features/capture/capture_screen.dart';
import '../features/capture/contact_form_screen.dart';
import '../features/events/event_detail_screen.dart';
import '../features/events/event_form_screen.dart';
import '../features/events/events_screen.dart';
import '../features/home/home_screen.dart';
import '../features/leads/lead_detail_screen.dart';
import '../features/leads/lead_edit_screen.dart';
import '../features/leads/leads_screen.dart';
import '../features/profile/change_pin_screen.dart';
import '../features/profile/data_privacy_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/profile/team_screen.dart';
import '../features/shell/main_shell.dart';
import 'providers.dart';

abstract final class Routes {
  static const splash = '/';
  static const welcome = '/welcome';
  static const setup = '/setup';
  static const unlock = '/unlock';
  static const home = '/home';
  static const leads = '/leads';
  static const events = '/events';
  static const profile = '/profile';
  static const capture = '/capture';
  static const review = '/review';
  static const manual = '/manual';
  static const eventNew = '/event/new';
  static String event(String id) => '/event/$id';
  static String eventEdit(String id) => '/event/$id/edit';
  static String lead(String id) => '/lead/$id';
  static String leadEdit(String id) => '/lead/$id/edit';
  static const team = '/settings/team';
  static const changePin = '/settings/pin';
  static const dataPrivacy = '/settings/data';

  static const _public = {splash, welcome, setup, unlock};
  static bool isPublic(String loc) => _public.contains(loc);
}

final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

/// Smooth fade-through used for full-screen flows.
CustomTransitionPage<void> _fade(GoRouterState state, Widget child) => CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 380),
      transitionsBuilder: (context, animation, _, child) => FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: child,
      ),
    );

/// Slide-up sheet transition used for the capture flow.
CustomTransitionPage<void> _slideUp(GoRouterState state, Widget child) => CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 420),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      transitionsBuilder: (context, animation, _, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return SlideTransition(
          position: Tween(begin: const Offset(0, 0.12), end: Offset.zero).animate(curved),
          child: FadeTransition(opacity: curved, child: child),
        );
      },
    );

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(sessionProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: Routes.splash,
    refreshListenable: refresh,
    redirect: (context, state) {
      final signedIn = ref.read(sessionProvider) != null;
      final loc = state.matchedLocation;
      final public = Routes.isPublic(loc);
      if (!signedIn && !public) return Routes.splash;
      if (signedIn && public) return Routes.home;
      return null;
    },
    routes: [
      GoRoute(path: Routes.splash, pageBuilder: (c, s) => _fade(s, const SplashScreen())),
      GoRoute(path: Routes.welcome, pageBuilder: (c, s) => _fade(s, const WelcomeScreen())),
      GoRoute(path: Routes.setup, builder: (c, s) => const SetupScreen()),
      GoRoute(path: Routes.unlock, pageBuilder: (c, s) => _fade(s, const UnlockScreen())),

      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => MainShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.home, builder: (c, s) => const HomeScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.leads, builder: (c, s) => const LeadsScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.events, builder: (c, s) => const EventsScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.profile, builder: (c, s) => const ProfileScreen()),
          ]),
        ],
      ),

      // Full-screen flows above the tab bar.
      GoRoute(path: Routes.capture, pageBuilder: (c, s) => _slideUp(s, const CaptureScreen())),
      GoRoute(
        path: Routes.review,
        builder: (c, s) => ContactFormScreen(args: s.extra as CaptureFormArgs? ?? const CaptureFormArgs()),
      ),
      GoRoute(
        path: Routes.manual,
        pageBuilder: (c, s) => _slideUp(s, const ContactFormScreen(args: CaptureFormArgs())),
      ),
      GoRoute(path: Routes.eventNew, builder: (c, s) => const EventFormScreen()),
      GoRoute(
        path: '/event/:id',
        builder: (c, s) => EventDetailScreen(eventId: s.pathParameters['id']!),
        routes: [
          GoRoute(
            path: 'edit',
            builder: (c, s) => EventFormScreen(eventId: s.pathParameters['id']),
          ),
        ],
      ),
      GoRoute(
        path: '/lead/:id',
        builder: (c, s) => LeadDetailScreen(contactId: s.pathParameters['id']!),
        routes: [
          GoRoute(
            path: 'edit',
            builder: (c, s) => LeadEditScreen(contactId: s.pathParameters['id']!),
          ),
        ],
      ),
      GoRoute(path: Routes.team, builder: (c, s) => const TeamScreen()),
      GoRoute(path: Routes.changePin, builder: (c, s) => const ChangePinScreen()),
      GoRoute(path: Routes.dataPrivacy, builder: (c, s) => const DataPrivacyScreen()),
    ],
  );
});
