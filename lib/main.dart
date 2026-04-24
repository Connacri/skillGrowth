import 'dart:io';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'activities/generated/multiphoto/photo_provider.dart';
import 'activities/providers.dart';
import 'ads_provider.dart';
import 'firebase_options.dart';
import 'pages/MyApp.dart';

// 🌍 Global navigator key
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  await initializeDateFormatting('fr_FR', null);
  timeago.setLocaleMessages('fr', timeago.FrMessages());
  timeago.setLocaleMessages('fr_short', timeago.FrShortMessages());

  // ✅ Firebase fonctionne maintenant sur TOUTES les plateformes
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('✅ Firebase initialisé sur ${Platform.operatingSystem}');

    // App Check (mobile uniquement - pas supporté sur Desktop)
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      try {
        await FirebaseAppCheck.instance.activate(
          androidProvider: AndroidProvider.playIntegrity,
          appleProvider: AppleProvider.deviceCheck,
        );
        debugPrint('✅ Firebase App Check activé');
      } catch (e) {
        debugPrint('⚠️ App Check non disponible: $e');
      }
    }

    // Firebase Messaging (mobile uniquement)
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      try {
        FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler,
        );
        debugPrint('✅ Firebase Messaging configuré');
      } catch (e) {
        debugPrint('⚠️ Firebase Messaging non disponible: $e');
      }
    }
  } catch (e, stackTrace) {
    debugPrint('❌ Erreur critique initialisation Firebase: $e');
    debugPrint('StackTrace: $stackTrace');
    // Ne pas bloquer l'application, continuer sans Firebase
  }

  // Mobile Ads (Android/iOS uniquement)
  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    try {
      await MobileAds.instance.initialize();
      debugPrint('✅ Google Ads initialisé');
    } catch (e) {
      debugPrint('⚠️ Erreur initialisation Ads: $e');
    }
  }

  // 🌍 Locale
  final localizationModel = LocalizationModel();
  await localizationModel.initLocale();

  FlutterNativeSplash.remove();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => localizationModel),
        ChangeNotifierProvider(create: (_) => AdsProvider()),
        ChangeNotifierProvider(create: (_) => ChildProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => CourseProvider()),
        ChangeNotifierProvider(create: (_) => ProfProvider()),
        ChangeNotifierProvider(create: (_) => PhotoProvider()),
        ChangeNotifierProvider(create: (_) => StepProvider()),
        ChangeNotifierProvider(create: (_) => StepProvider1()),
      ],
      child: MyApp1(),
    ),
  );
}

// Background message handler for Firebase Cloud Messaging
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint("📩 Background message received: ${message.messageId}");
}
