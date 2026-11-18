import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'app/app.dart';
import 'app/providers.dart';
import 'core/theme/app_colors.dart';
import 'data/database/app_database.dart';
import 'data/repositories/settings_repository.dart';
import 'data/services/image_store.dart';
import 'data/services/retention_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarBrightness: Brightness.dark, // iOS: light status-bar content
      statusBarIconBrightness: Brightness.light, // Android
      systemNavigationBarColor: AppColors.background,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  try {
    final db = await AppDatabase.open();
    final docs = await getApplicationDocumentsDirectory();
    final images = ImageStore(docs.path);

    // Enforce the photo-retention policy on launch (best effort).
    try {
      final days = await SettingsRepository(db).retentionDays();
      await RetentionService(db, images).purge(days: days);
    } catch (_) {}

    runApp(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          imageStoreProvider.overrideWithValue(images),
        ],
        child: const CotopoleApp(),
      ),
    );
  } catch (e) {
    runApp(_StartupErrorApp(error: e));
  }
}

class _StartupErrorApp extends StatelessWidget {
  const _StartupErrorApp({required this.error});
  final Object error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.storage_rounded, color: AppColors.danger, size: 48),
                const SizedBox(height: 16),
                const Text(
                  'Unable to open local storage',
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  '$error',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
