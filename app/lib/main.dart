import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'core/config/env.dart';
import 'core/error/error_handling.dart';
import 'core/network/network_providers.dart';
import 'core/notifications/app_notifier.dart';
import 'core/storage/storage_providers.dart';
import 'core/storage/token_store.dart';
import 'features/auth/auth_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  setupErrorHandling();

  // Load anything async that providers need synchronously, then inject it.
  final prefs = await SharedPreferences.getInstance();
  final tokens = await TokenStore.load(const FlutterSecureStorage());

  final container = ProviderContainer(
    retry: retryPolicy,
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      tokenStoreProvider.overrideWithValue(tokens),
      sessionExpiredProvider.overrideWith(
        (ref) =>
            () => ref.read(authProvider.notifier).expireSession(),
      ),
      tokenRefresherProvider.overrideWith(
        (ref) =>
            () => ref.read(authProvider.notifier).refreshTokens(),
      ),
    ],
  );

  // Supabase is used only for RLS-protected reads and writes (D-054). It borrows the session
  // our login API issued, refreshed shortly before expiry, and never signs in on its own.
  await Supabase.initialize(
    url: Env.supabaseUrl,
    publishableKey: Env.supabasePublishableKey,
    accessToken: () => container.read(authProvider.notifier).freshAccessToken(),
  );

  // Notification channels and tap handling (D-081). Failure leaves the app working without them.
  await container.read(appNotifierProvider).init();

  runApp(UncontrolledProviderScope(container: container, child: const App()));
}
