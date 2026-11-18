import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import 'providers.dart';
import 'router.dart';

class CotopoleApp extends ConsumerStatefulWidget {
  const CotopoleApp({super.key});

  @override
  ConsumerState<CotopoleApp> createState() => _CotopoleAppState();
}

class _CotopoleAppState extends ConsumerState<CotopoleApp> {
  late final AppLifecycleListener _lifecycle;
  DateTime? _backgroundedAt;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onHide: () => _backgroundedAt = DateTime.now(),
      onShow: _maybeAutoLock,
    );
  }

  /// Re-locks the app with the PIN after it has been in the background
  /// longer than the configured auto-lock window (lost/borrowed phones at a
  /// busy stand).
  Future<void> _maybeAutoLock() async {
    final since = _backgroundedAt;
    _backgroundedAt = null;
    if (since == null || ref.read(sessionProvider) == null) return;
    final minutes = await ref.read(settingsRepoProvider).autoLockMinutes();
    if (minutes <= 0) return;
    if (DateTime.now().difference(since) >= Duration(minutes: minutes)) {
      ref.read(sessionProvider.notifier).signOut();
    }
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Cotopole',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.dark,
      routerConfig: router,
      builder: (context, child) {
        // Respect user font scaling but cap it so dense cards stay legible.
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(textScaler: mq.textScaler.clamp(maxScaleFactor: 1.3)),
          child: GestureDetector(
            // Tap outside a field dismisses the keyboard (iOS has no back key).
            onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
            behavior: HitTestBehavior.translucent,
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
    );
  }
}
