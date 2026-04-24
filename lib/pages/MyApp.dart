import 'package:feedback/feedback.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import '../activities/screens/userHomePage.dart';
import '../ads_provider.dart';
import '../auth/google.dart';
import '../fonctions/AppLocalizations.dart';

class MyApp1 extends StatefulWidget {
  const MyApp1({super.key});

  @override
  State<MyApp1> createState() => _MyApp1State();
}

class _MyApp1State extends State<MyApp1> {
  @override
  Widget build(BuildContext context) {
    return PageLance();
  }
}

class PageLance extends StatefulWidget {
  const PageLance({super.key});

  @override
  State<PageLance> createState() => _PageLanceState();
}

class _PageLanceState extends State<PageLance> {
  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, () {
      final localizationModel = Provider.of<LocalizationModel>(
        context,
        listen: false,
      );
      localizationModel.initLocale().then((_) {
        print("Locale initialisée : ${localizationModel.locale}");
        setState(() {});
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<ThemeProvider, LocalizationModel>(
      builder: (context, themeProvider, localizationModel, child) {
        String fontAr = 'KHALED';
        print("Locale actuelle : ${localizationModel.locale}");
        return BetterFeedback(
          localeOverride: localizationModel.locale,
          child: MaterialApp(
            title: 'NextGen',
            supportedLocales: [
              Locale('en'),
              Locale('fr'),
              Locale('ar'),
              Locale('es'),
              Locale('zh'),
              Locale('ja'),
              Locale('it'),
              Locale('ru'),
              Locale('th'),
            ],
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            locale: localizationModel.locale,
            theme: ThemeData(
              fontFamily:
                  localizationModel.locale.languageCode == 'ar'
                      ? fontAr
                      : 'oswald',
              brightness: Brightness.light,
              primarySwatch: Colors.blue,
              chipTheme: ChipThemeData(
                backgroundColor: Colors.grey[800]!,
                selectedColor: Colors.blue[700]!,
                checkmarkColor: Colors.white,
                labelStyle: TextStyle(
                  fontFamily:
                      localizationModel.locale.languageCode == 'ar'
                          ? fontAr
                          : 'oswald',
                ),
                secondaryLabelStyle: TextStyle(color: Colors.white),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20.0),
                ),
                padding: EdgeInsets.all(8.0),
              ),
              textTheme: TextTheme(
                bodyMedium: TextStyle(color: Colors.black),
                bodyLarge: TextStyle(color: Colors.black),
                bodySmall: TextStyle(color: Colors.black),
                titleMedium: TextStyle(color: Colors.black),
                titleLarge: TextStyle(color: Colors.black),
                labelLarge: TextStyle(color: Colors.black),
              ),
              dropdownMenuTheme: DropdownMenuThemeData(
                menuStyle: MenuStyle(
                  backgroundColor: WidgetStateProperty.all(Colors.white),
                ),
                inputDecorationTheme: InputDecorationTheme(
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            darkTheme: ThemeData(
              fontFamily:
                  localizationModel.locale.languageCode == 'ar'
                      ? fontAr
                      : 'oswald',
              brightness: Brightness.dark,
              primaryColor: Colors.blueGrey,
              chipTheme: ChipThemeData(
                backgroundColor: Colors.grey[800]!,
                selectedColor: Colors.blue[700]!,
                labelStyle: TextStyle(
                  fontFamily:
                      localizationModel.locale.languageCode == 'ar'
                          ? fontAr
                          : 'oswald',
                ),
                secondaryLabelStyle: TextStyle(color: Colors.white),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
                padding: EdgeInsets.all(8.0),
              ),
              textTheme: TextTheme(
                bodyMedium: TextStyle(color: Colors.white),
                bodyLarge: TextStyle(color: Colors.white),
                bodySmall: TextStyle(color: Colors.white),
                titleMedium: TextStyle(color: Colors.white),
                titleLarge: TextStyle(color: Colors.white),
                labelLarge: TextStyle(color: Colors.white),
              ),
              dropdownMenuTheme: DropdownMenuThemeData(
                menuStyle: MenuStyle(
                  backgroundColor: WidgetStateProperty.all(Colors.white),
                ),
                inputDecorationTheme: InputDecorationTheme(
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            themeMode:
                themeProvider.isDarkTheme ? ThemeMode.dark : ThemeMode.light,
            home: Scaffold(body: AuthScreen()),
          ),
        );
      },
    );
  }
}

class test extends StatelessWidget {
  const test({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('reussit')));
  }
}

class AuthScreen extends StatefulWidget {
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  @override
  Widget build(BuildContext context) {
    // ✅ Attendre que Firebase soit complètement initialisé
    return FutureBuilder(
      future: Firebase.initializeApp(),
      builder: (context, snapshot) {
        // En cours d'initialisation
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Initialisation...'),
              ],
            ),
          );
        }

        // Erreur d'initialisation
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red),
                  SizedBox(height: 16),
                  Text(
                    'Erreur d\'initialisation Firebase',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    snapshot.error.toString(),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {}); // Réessayer
                    },
                    icon: Icon(Icons.refresh),
                    label: Text('Réessayer'),
                  ),
                ],
              ),
            ),
          );
        }

        // ✅ Firebase initialisé, maintenant on peut utiliser FirebaseAuth
        return StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, authSnapshot) {
            if (authSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (authSnapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: Colors.red),
                    SizedBox(height: 16),
                    Text(
                      'Erreur de connexion',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      authSnapshot.error.toString(),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => google()),
                        );
                      },
                      child: Text('Retour à la connexion'),
                    ),
                  ],
                ),
              );
            }

            if (authSnapshot.hasData) {
              return HomePage();
            } else {
              return google();
            }
          },
        );
      },
    );
  }
}
