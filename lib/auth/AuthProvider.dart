import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as su;

import '../PlatformUtils.dart';
import '../activities/providers.dart';

class AuthService {
  FirebaseAuth? _auth;
  final ChildProvider? childProvider;
  FirestoreUserService? _firestoreService;

  // État de connexion Google (null sur Windows/Linux)
  GoogleSignIn? _googleSignIn;
  GoogleSignInAccount? _currentUser;
  bool _isAuthorized = false;
  StreamSubscription<GoogleSignInAuthenticationEvent>? _authSubscription;
  bool _isInitialized = false;

  // ✅ Constructeur qui attend l'initialisation Firebase
  AuthService({this.childProvider}) {
    _initializeAsync();
  }

  /// Initialisation asynchrone complète
  Future<void> _initializeAsync() async {
    // ✅ Attendre que Firebase soit initialisé (déjà fait dans main.dart)
    try {
      // Vérifier si Firebase est déjà initialisé
      await Firebase.initializeApp();
    } catch (e) {
      // Déjà initialisé, c'est OK
      print('ℹ️ Firebase déjà initialisé');
    }

    // ✅ Maintenant on peut accéder à FirebaseAuth
    try {
      _auth = FirebaseAuth.instance;
      _firestoreService = FirestoreUserService();
      print('✅ Firebase Auth initialisé');
    } catch (e) {
      print('❌ Erreur initialisation Firebase Auth: $e');
    }

    // ✅ Initialiser Google Sign-In si supporté
    if (PlatformUtils.supportsGoogleSignIn) {
      await _initializeGoogleSignIn();
    } else {
      print('⚠️ Google Sign-In désactivé sur ${PlatformUtils.platformName}');
      _isInitialized = true;
    }
  }

  /// Initialisation de Google Sign In (Android/iOS/Web uniquement)
  Future<void> _initializeGoogleSignIn() async {
    if (_googleSignIn == null) {
      _isInitialized = true;
      return;
    }

    try {
      // Initialiser
      await _googleSignIn!.initialize();
      _isInitialized = true;

      // Écouter les événements d'authentification
      _authSubscription = _googleSignIn!.authenticationEvents.listen(
        _handleAuthenticationEvent,
      )..onError(_handleAuthenticationError);

      // Tentative de connexion silencieuse
      await _googleSignIn!.attemptLightweightAuthentication();

      print('✅ Google Sign In initialisé avec succès');
    } catch (e) {
      print('⚠️ Initialisation Google Sign In: $e');
      _isInitialized = true;
    }
  }

  /// S'assurer que GoogleSignIn est initialisé
  Future<void> _ensureInitialized() async {
    if (!_isInitialized && _googleSignIn != null) {
      await _initializeGoogleSignIn();
    }
  }

  /// Gestion des événements d'authentification
  Future<void> _handleAuthenticationEvent(
    GoogleSignInAuthenticationEvent event,
  ) async {
    final GoogleSignInAccount? user = switch (event) {
      GoogleSignInAuthenticationEventSignIn() => event.user,
      GoogleSignInAuthenticationEventSignOut() => null,
    };

    _currentUser = user;
    _isAuthorized = user != null;

    if (user != null) {
      print('✅ Événement: Utilisateur connecté - ${user.email}');
    } else {
      print('ℹ️ Événement: Utilisateur déconnecté');
    }
  }

  /// Gestion des erreurs d'authentification
  Future<void> _handleAuthenticationError(Object e) async {
    print('❌ Erreur d\'authentification Google: $e');
    _currentUser = null;
    _isAuthorized = false;
  }

  /// S'assurer que tout est initialisé
  Future<void> ensureInitialized() async {
    if (_isInitialized) return;

    // Attendre max 10 secondes (augmenté pour Desktop)
    final stopwatch = Stopwatch()..start();
    while (!_isInitialized && stopwatch.elapsed.inSeconds < 10) {
      await Future.delayed(Duration(milliseconds: 100));
    }

    if (!_isInitialized) {
      print('⚠️ Timeout lors de l\'initialisation');
    }
  }

  /// Connexion avec Google (Android/iOS/Web uniquement)
  Future<User?> signInWithGoogle() async {
    // ✅ Attendre l'initialisation
    await ensureInitialized();

    // ✅ Vérifications complètes
    if (_auth == null) {
      print('❌ Firebase Auth non disponible');
      return null;
    }

    if (!PlatformUtils.supportsGoogleSignIn || _googleSignIn == null) {
      print('❌ Google Sign-In non supporté sur ${PlatformUtils.platformName}');
      return null;
    }

    try {
      await _ensureInitialized();

      // Vérifier si authenticate() est supporté
      if (!_googleSignIn!.supportsAuthenticate()) {
        print('❌ authenticate() non supporté sur cette plateforme');
        return null;
      }

      // Authentification Google
      final GoogleSignInAccount? googleUser =
          await _googleSignIn!.authenticate();

      if (googleUser == null) {
        print('ℹ️ Connexion annulée par l\'utilisateur');
        return null;
      }

      _currentUser = googleUser;

      // Obtenir les tokens
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      if (googleAuth.idToken == null) {
        print('❌ Impossible d\'obtenir le token ID');
        return null;
      }

      // Créer le credential Firebase
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      // Se connecter à Firebase
      final UserCredential userCredential = await _auth!.signInWithCredential(
        credential,
      );
      final User? firebaseUser = userCredential.user;

      if (firebaseUser != null) {
        print('✅ Connexion Firebase réussie: ${firebaseUser.email}');

        // Créer/mettre à jour dans Supabase
        await createUserInSupabase(firebaseUser);

        // Créer/mettre à jour dans Firestore
        if (_firestoreService != null) {
          await _firestoreService!.createOrUpdateUser(firebaseUser);
        }
      }

      return firebaseUser;
    } on GoogleSignInException catch (e) {
      String errorMessage = switch (e.code) {
        GoogleSignInExceptionCode.canceled =>
          'Connexion annulée par l\'utilisateur',
        _ => 'Erreur Google Sign In ${e.code}: ${e.description}',
      };
      print('❌ $errorMessage');
      return null;
    } catch (e, stackTrace) {
      print('❌ Erreur lors de la connexion avec Google: $e');
      print('Stacktrace: $stackTrace');
      return null;
    }
  }

  /// Déconnexion
  Future<void> signOut() async {
    try {
      // Déconnexion Google (si disponible)
      if (_googleSignIn != null && PlatformUtils.supportsGoogleSignIn) {
        try {
          await _googleSignIn!.disconnect();
        } catch (e) {
          print('⚠️ Erreur déconnexion Google: $e');
        }
      }

      // Déconnexion Firebase (si disponible)
      if (_auth != null) {
        await _auth!.signOut();
      }

      // Nettoyage du cache local
      childProvider?.clearCache();

      // Réinitialiser l'état
      _currentUser = null;
      _isAuthorized = false;

      print('✅ Déconnexion réussie');
    } catch (e) {
      print('⚠️ Erreur lors de la déconnexion: $e');
      // On continue même en cas d'erreur
      try {
        if (_auth != null) await _auth!.signOut();
        _currentUser = null;
        _isAuthorized = false;
      } catch (_) {}
    }
  }

  /// Suppression définitive du compte
  Future<bool> deleteUserAccountPermanently() async {
    if (_auth == null) {
      print('❌ Firebase Auth non disponible');
      return false;
    }

    try {
      final user = _auth!.currentUser;
      if (user == null) {
        print('❌ Aucun utilisateur connecté');
        return false;
      }

      final uid = user.uid;

      // 1. Suppression Supabase
      try {
        await su.Supabase.instance.client
            .from('signalements')
            .delete()
            .eq('user', uid);
        print('✅ Signalements Supabase supprimés');

        await su.Supabase.instance.client
            .from('users')
            .delete()
            .eq('firebase_id', uid);
        print('✅ Utilisateur Supabase supprimé');
      } catch (e) {
        print('⚠️ Erreur Supabase (on continue): $e');
      }

      // 2. Suppression Firestore + Firebase Auth
      if (_firestoreService != null) {
        final firestoreDeleted =
            await _firestoreService!.deleteUserCompletely();

        if (!firestoreDeleted) {
          print('⚠️ Erreur lors de la suppression Firestore/Auth');
          return false;
        }
      }

      // 3. Déconnexion
      await signOut();

      print('✅ Compte supprimé complètement');
      return true;
    } catch (e) {
      print('❌ Erreur suppression compte: $e');
      return false;
    }
  }

  // Getters
  GoogleSignInAccount? get currentGoogleUser => _currentUser;
  User? get currentFirebaseUser => _auth?.currentUser;
  bool get isSignedIn => _auth?.currentUser != null;
  bool get isAuthorized => _isAuthorized;

  /// Stream pour écouter les changements d'état Firebase
  Stream<User?> get authStateChanges {
    if (_auth == null) {
      return Stream.value(null);
    }
    return _auth!.authStateChanges();
  }

  /// Nettoyage des ressources
  void dispose() {
    _authSubscription?.cancel();
  }
}

/// Création/mise à jour dans Supabase
Future<void> createUserInSupabase(User firebaseUser) async {
  try {
    final supabase = su.Supabase.instance.client;

    final existing =
        await supabase
            .from('users')
            .select()
            .eq('firebase_id', firebaseUser.uid)
            .maybeSingle();

    if (existing != null) {
      print('ℹ️ Utilisateur déjà enregistré dans Supabase');
      return;
    }

    await supabase.from('users').insert({
      'firebase_id': firebaseUser.uid,
      'email': firebaseUser.email,
      'full_name': firebaseUser.displayName,
      'phone': firebaseUser.phoneNumber,
      'created_at': DateTime.now().toIso8601String(),
      'metadata': {'photo_url': firebaseUser.photoURL},
    });

    print('✅ Utilisateur créé dans Supabase');
  } catch (e) {
    print('❌ Erreur insertion Supabase: $e');
  }
}

/// Service Firestore
class FirestoreUserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _usersCollection = 'userModel';

  Future<bool> createOrUpdateUser(
    User user, {
    Map<String, dynamic>? additionalData,
    bool forceCreate = false,
  }) async {
    try {
      final uid = user.uid;
      final docRef = _firestore.collection(_usersCollection).doc(uid);

      final baseData = {
        'name': user.displayName ?? 'Utilisateur',
        'email': user.email ?? '',
        'photos': user.photoURL != null ? [user.photoURL!] : [],
        'lastLogin': FieldValue.serverTimestamp(),
      };

      final snapshot = await docRef.get();

      if (!snapshot.exists || forceCreate) {
        final createData = {
          ...baseData,
          'createdAt': FieldValue.serverTimestamp(),
          'editedAt': FieldValue.serverTimestamp(),
          'phone': '',
          'gender': '',
          'courses': [],
          'role': 'sero',
          ...?additionalData,
        };

        await docRef.set(createData, SetOptions(merge: true));
        print('✅ Utilisateur créé dans Firestore: $uid');
      } else {
        final updateData = {
          ...baseData,
          'editedAt': FieldValue.serverTimestamp(),
          ...?additionalData,
        };

        await docRef.update(updateData);
        print('✅ Utilisateur mis à jour dans Firestore: $uid');
      }

      return true;
    } catch (e) {
      print('❌ Erreur Firestore: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> getUserData(String uid) async {
    try {
      final doc = await _firestore.collection(_usersCollection).doc(uid).get();
      return doc.exists ? doc.data() : null;
    } catch (e) {
      print('❌ Erreur récupération: $e');
      return null;
    }
  }

  Future<bool> updateUserFields(String uid, Map<String, dynamic> fields) async {
    try {
      await _firestore.collection(_usersCollection).doc(uid).update({
        ...fields,
        'editedAt': FieldValue.serverTimestamp(),
      });
      print('✅ Champs mis à jour: $uid');
      return true;
    } catch (e) {
      print('❌ Erreur mise à jour: $e');
      return false;
    }
  }

  Future<bool> deleteUser(String uid) async {
    try {
      await _firestore.collection(_usersCollection).doc(uid).delete();
      print('✅ Utilisateur supprimé de Firestore: $uid');
      return true;
    } catch (e) {
      print('❌ Erreur suppression: $e');
      return false;
    }
  }

  Future<bool> deleteUserCompletely() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('❌ Aucun utilisateur connecté');
        return false;
      }

      final uid = user.uid;

      await _firestore.collection(_usersCollection).doc(uid).delete();
      print('✅ Document Firestore supprimé: $uid');

      await user.delete();
      print('✅ Compte Firebase Auth supprimé: $uid');

      return true;
    } catch (e) {
      print('❌ Erreur suppression complète: $e');
      return false;
    }
  }

  Future<bool> addCourse(String uid, String courseId) async {
    try {
      await _firestore.collection(_usersCollection).doc(uid).update({
        'courses': FieldValue.arrayUnion([courseId]),
        'editedAt': FieldValue.serverTimestamp(),
      });
      print('✅ Cours ajouté: $uid');
      return true;
    } catch (e) {
      print('❌ Erreur ajout cours: $e');
      return false;
    }
  }

  Future<bool> removeCourse(String uid, String courseId) async {
    try {
      await _firestore.collection(_usersCollection).doc(uid).update({
        'courses': FieldValue.arrayRemove([courseId]),
        'editedAt': FieldValue.serverTimestamp(),
      });
      print('✅ Cours retiré: $uid');
      return true;
    } catch (e) {
      print('❌ Erreur retrait cours: $e');
      return false;
    }
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> userStream(String uid) {
    return _firestore.collection(_usersCollection).doc(uid).snapshots();
  }
}
