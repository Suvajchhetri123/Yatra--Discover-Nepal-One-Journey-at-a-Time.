import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'screens/splash/splash_screen.dart';
import 'services/firestore_package_service.dart';
import 'services/firestore_place_service.dart';
import 'services/firestore_service.dart';
import 'services/profile_session.dart';
import 'services/session_manager.dart';
import 'services/tourist_catalog_controller.dart';
import 'theme/app_theme.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  SessionManager.instance.initialize(navigatorKey);

  runApp(const YatraApp());
}

class YatraApp extends StatefulWidget {
  const YatraApp({super.key});

  @override
  State<YatraApp> createState() => _YatraAppState();
}

class _YatraAppState extends State<YatraApp> {
  /// One snapshot of the signed-in profile for the whole app.
  ///
  /// Firestore remains the source of truth. The session simply avoids
  /// repeatedly reading the same profile from individual screens.
  final ProfileSession _profileSession = ProfileSession(
    loader: () async {
      if (Firebase.apps.isEmpty) {
        return null;
      }

      return FirestoreService().getCurrentUserProfile();
    },
  );

  /// Shared tourist catalog for the application navigator.
  ///
  /// The controller lives above MaterialApp so every tourist route pushed by
  /// the Navigator can access the same Place/Package catalog. It does not load
  /// Firestore merely by existing; Home/Preview explicitly trigger loading.
  late final TouristCatalogController _touristCatalog;

  @override
  void initState() {
    super.initState();

    // Normal production startup has already initialized Firebase in main().
    // Widget tests may construct YatraApp directly without Firebase, so keep
    // the controller repository-less in that environment.
    _touristCatalog = TouristCatalogController(
      packageRepository: Firebase.apps.isEmpty
          ? null
          : FirestorePackageService(),
      placeRepository: Firebase.apps.isEmpty ? null : FirestorePlaceService(),
    );
  }

  @override
  void dispose() {
    _touristCatalog.dispose();
    _profileSession.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ProfileSessionScope(
      session: _profileSession,
      child: TouristCatalogScope(
        controller: _touristCatalog,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Yatra',
          theme: AppTheme.light,
          navigatorKey: navigatorKey,
          builder: (context, child) {
            return Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (_) {
                SessionManager.instance.userActivity();
              },
              onPointerMove: (_) {
                SessionManager.instance.userActivity();
              },
              onPointerUp: (_) {
                SessionManager.instance.userActivity();
              },
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: const SplashScreen(),
        ),
      ),
    );
  }
}
