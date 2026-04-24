import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:lottie/lottie.dart';

import '../PlatformUtils.dart';
import '../activities/modèles.dart';
import '../activities/screens/userHomePage.dart';
import '../pages/MyApp.dart';
import 'AuthProvider.dart';

class google extends StatefulWidget {
  @override
  _googleState createState() => _googleState();
}

class _googleState extends State<google> {
  AuthService? _authService;
  User? _user;
  bool isLoading = false;
  bool isSigningOut = false;
  int _selectedTab = 0;
  bool _loading = false;
  List<Map<String, dynamic>> _reportedNumbers = [];

  final _formKey = GlobalKey<FormState>();

  // Controllers
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final nameCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();

    // ✅ Toujours initialiser AuthService (maintenant compatible Desktop)
    _authService = AuthService();

    // ✅ Récupérer l'utilisateur actuel
    _setupAuthListener();
  }

  @override
  void dispose() {
    emailCtrl.dispose();
    passCtrl.dispose();
    nameCtrl.dispose();
    _authService?.dispose();
    super.dispose();
  }

  void _switchTab(int index) {
    setState(() {
      _selectedTab = index;
      _formKey.currentState?.reset();
    });
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email requis';
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Format email invalide';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Mot de passe requis';
    }
    if (value.length < 6) {
      return 'Minimum 6 caractères';
    }
    return null;
  }

  String? _validateName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Nom requis';
    }
    if (value.length < 2) {
      return 'Nom trop court';
    }
    return null;
  }

  void _showError(String message, {bool isSuccess = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isSuccess ? Icons.check_circle_outline : Icons.error_outline,
              color: Colors.white,
            ),
            SizedBox(width: 12),
            Expanded(child: Text(message, style: TextStyle(fontSize: 15))),
          ],
        ),
        backgroundColor: isSuccess ? Colors.green[700] : Colors.red[700],
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: Duration(seconds: 4),
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }

  String _getFirebaseErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'Aucun compte trouvé avec cet email';
      case 'wrong-password':
        return 'Mot de passe incorrect';
      case 'email-already-in-use':
        return 'Cet email est déjà utilisé';
      case 'weak-password':
        return 'Mot de passe trop faible (min 6 caractères)';
      case 'invalid-email':
        return 'Format email invalide';
      case 'user-disabled':
        return 'Ce compte a été désactivé';
      case 'too-many-requests':
        return 'Trop de tentatives. Réessayez plus tard';
      case 'operation-not-allowed':
        return 'Opération non autorisée';
      case 'network-request-failed':
        return 'Erreur réseau. Vérifiez votre connexion';
      default:
        return 'Erreur d\'authentification : ${e.message ?? e.code}';
    }
  }

  Future<void> _handleSignIn() async {
    if (_authService == null) {
      _showError('Service d\'authentification non disponible');
      return;
    }

    if (!PlatformUtils.supportsGoogleSignIn) {
      _showError(
        'Google Sign-In non disponible sur ${PlatformUtils.platformName}. '
        'Utilisez l\'authentification par email.',
      );
      return;
    }

    setState(() => isLoading = true);
    try {
      final user = await _authService!.signInWithGoogle();
      if (user == null) {
        if (mounted) _showError('Connexion Google annulée');
        return;
      }

      final uid = user.uid;
      final docRef = FirebaseFirestore.instance
          .collection('userModel')
          .doc(uid);
      final snapshot = await docRef.get();

      final data = {
        'name': user.displayName ?? 'Utilisateur',
        'email': user.email ?? '',
        'photos': user.photoURL != null ? [user.photoURL!] : [],
        'lastLogin': FieldValue.serverTimestamp(),
      };

      if (!snapshot.exists) {
        await docRef.set({
          ...data,
          'createdAt': FieldValue.serverTimestamp(),
          'editedAt': FieldValue.serverTimestamp(),
          'phone': '',
          'gender': '',
          'courses': [],
          'role': 'sero',
        }, SetOptions(merge: true));
      } else {
        await docRef.update(data);
      }

      if (!mounted) return;
      _showError('Connexion réussie !', isSuccess: true);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => HomePage()),
      );
    } on FirebaseAuthException catch (e) {
      if (mounted) _showError(_getFirebaseErrorMessage(e));
    } catch (e) {
      if (mounted) _showError('Erreur inattendue : $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _handleEmailSignIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      final userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(
            email: emailCtrl.text.trim(),
            password: passCtrl.text.trim(),
          );
      final user = userCredential.user;
      if (user == null) return;

      final uid = user.uid;
      final docRef = FirebaseFirestore.instance
          .collection('userModel')
          .doc(uid);
      final snapshot = await docRef.get();

      final data = {
        'name': user.displayName ?? 'Utilisateur',
        'email': user.email ?? '',
        'photos': user.photoURL != null ? [user.photoURL!] : [],
        'lastLogin': FieldValue.serverTimestamp(),
      };

      if (!snapshot.exists) {
        await docRef.set({
          ...data,
          'createdAt': FieldValue.serverTimestamp(),
          'editedAt': FieldValue.serverTimestamp(),
          'phone': '',
          'gender': '',
          'courses': [],
          'role': 'parent',
        }, SetOptions(merge: true));
      } else {
        await docRef.update(data);
      }

      if (!mounted) return;
      _showError('Connexion réussie !', isSuccess: true);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => HomePage()),
      );
    } on FirebaseAuthException catch (e) {
      if (mounted) _showError(_getFirebaseErrorMessage(e));
    } catch (e) {
      if (mounted) _showError('Erreur inattendue : $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      final userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: emailCtrl.text.trim(),
            password: passCtrl.text.trim(),
          );
      await userCredential.user?.updateDisplayName(nameCtrl.text.trim());

      if (!mounted) return;
      _showError('Compte créé avec succès !', isSuccess: true);

      setState(() => _selectedTab = 0);
    } on FirebaseAuthException catch (e) {
      if (mounted) _showError(_getFirebaseErrorMessage(e));
    } catch (e) {
      if (mounted) _showError('Erreur inattendue : $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resetPassword() async {
    if (emailCtrl.text.trim().isEmpty) {
      _showError('Veuillez entrer votre email');
      return;
    }
    if (_validateEmail(emailCtrl.text.trim()) != null) {
      _showError('Email invalide');
      return;
    }

    setState(() => _loading = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: emailCtrl.text.trim(),
      );

      if (!mounted) return;
      _showError(
        'Email de réinitialisation envoyé ! Vérifiez votre boîte mail.',
        isSuccess: true,
      );

      setState(() => _selectedTab = 0);
    } on FirebaseAuthException catch (e) {
      if (mounted) _showError(_getFirebaseErrorMessage(e));
    } catch (e) {
      if (mounted) _showError('Erreur inattendue : $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleSignOut() async {
    if (_authService == null) {
      _showError('Service d\'authentification non disponible');
      return;
    }

    setState(() => isSigningOut = true);

    try {
      await Future.wait([
        _authService!.signOut(),
        Future.delayed(const Duration(seconds: 2)),
      ]);

      if (!mounted) return;

      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (ctx) => MyApp1()));
      setState(() {
        _user = null;
        _reportedNumbers.clear();
      });
    } catch (e) {
      print('Erreur déconnexion: $e');
      if (!mounted) return;
      _showError('Erreur de déconnexion');
    } finally {
      if (mounted) setState(() => isSigningOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child:
            isLoading
                ? _buildLoadingWidget()
                : _user == null
                ? _buildLoginUI(context)
                : _buildProfileUI(),
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircularProgressIndicator(strokeWidth: 3),
        SizedBox(height: 20),
        Text(
          'Connexion en cours...',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildLoginUI(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      child: Card(
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 8,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Lottie.asset(
                  'assets/lotties/boost (10).json',
                  height: 250,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  child: Text(
                    "Connectez-vous pour accéder à votre espace".toUpperCase(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.black45,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                ToggleButtons(
                  isSelected: [
                    _selectedTab == 0,
                    _selectedTab == 1,
                    _selectedTab == 2,
                  ],
                  onPressed: _switchTab,
                  borderRadius: BorderRadius.circular(12),
                  selectedColor: theme.colorScheme.onPrimary,
                  fillColor: theme.primaryColor,
                  children: const [
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text('Connexion'),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text('Inscription'),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text('Oublié'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ONGLET CONNEXION
                if (_selectedTab == 0) ...[
                  TextFormField(
                    controller: emailCtrl,
                    validator: _validateEmail,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: passCtrl,
                    validator: _validatePassword,
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _handleEmailSignIn(),
                    decoration: const InputDecoration(
                      labelText: 'Mot de passe',
                      prefixIcon: Icon(Icons.lock),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _loading ? null : _handleEmailSignIn,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child:
                        _loading
                            ? SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                            : Text('Connexion', style: TextStyle(fontSize: 16)),
                  ),
                  const SizedBox(height: 20),

                  if (PlatformUtils.supportsGoogleSignIn) ...[
                    Row(
                      children: [
                        Expanded(child: Divider()),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'OU',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                        Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black54,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        elevation: 4.0,
                        minimumSize: const Size.fromHeight(50),
                      ),
                      icon: const FaIcon(
                        FontAwesomeIcons.google,
                        color: Colors.red,
                      ),
                      label: const Text(
                        'Continuer avec Google',
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
                      onPressed: _handleSignIn,
                    ),
                  ] else
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange[100],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange[300]!),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 20,
                              color: Colors.orange[800],
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Google Sign-In non disponible sur ${PlatformUtils.platformName}',
                                style: TextStyle(
                                  color: Colors.orange[900],
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ]
                // ONGLET INSCRIPTION
                else if (_selectedTab == 1) ...[
                  TextFormField(
                    controller: nameCtrl,
                    validator: _validateName,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Nom complet',
                      prefixIcon: Icon(Icons.person),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: emailCtrl,
                    validator: _validateEmail,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: passCtrl,
                    validator: _validatePassword,
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _handleSignUp(),
                    decoration: const InputDecoration(
                      labelText: 'Mot de passe',
                      prefixIcon: Icon(Icons.lock),
                      border: OutlineInputBorder(),
                      helperText: 'Minimum 6 caractères',
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _loading ? null : _handleSignUp,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child:
                        _loading
                            ? SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                            : Text(
                              'Créer un compte',
                              style: TextStyle(fontSize: 16),
                            ),
                  ),
                ]
                // ONGLET MOT DE PASSE OUBLIÉ
                else ...[
                  TextFormField(
                    controller: emailCtrl,
                    validator: _validateEmail,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _resetPassword(),
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined),
                      border: OutlineInputBorder(),
                      helperText: 'Vous recevrez un email de réinitialisation',
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _loading ? null : _resetPassword,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child:
                        _loading
                            ? SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                            : Text(
                              'Envoyer le lien',
                              style: TextStyle(fontSize: 16),
                            ),
                  ),
                ],

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileUI() {
    return Column(
      children: [
        Expanded(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(18.0),
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 24,
                        horizontal: 16,
                      ),
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 45,
                            backgroundImage:
                                _user?.photoURL != null
                                    ? NetworkImage(_user!.photoURL!)
                                    : AssetImage(
                                          'assets/images/default_avatar.png',
                                        )
                                        as ImageProvider,
                          ),
                          SizedBox(height: 16),
                          Text(
                            _user?.displayName ?? 'Utilisateur',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            _user?.email ?? '',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                          SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: isSigningOut ? null : _handleSignOut,
                            icon:
                                isSigningOut
                                    ? SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                    : Icon(Icons.logout),
                            label: Text('Déconnexion'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _setupAuthListener() {
    try {
      FirebaseAuth.instance.authStateChanges().listen((User? user) {
        if (user != null && mounted) {
          setState(() => _user = user);
        }
      });
    } catch (e) {
      debugPrint('⚠️ Erreur listener Firebase: $e');
    }
  }
}

class RoleSelectionDropdown extends StatefulWidget {
  final Function(String) onRoleSelected;

  const RoleSelectionDropdown({Key? key, required this.onRoleSelected})
    : super(key: key);

  @override
  _RoleSelectionDropdownState createState() => _RoleSelectionDropdownState();
}

class _RoleSelectionDropdownState extends State<RoleSelectionDropdown> {
  String? roleChoice;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: DropdownButton<String>(
        value: roleChoice,
        hint: Text('Sélectionnez mon rôle'),
        isExpanded: true,
        items:
            lesRoles.map<DropdownMenuItem<String>>((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value.toUpperCase()),
              );
            }).toList(),
        onChanged: (String? newValue) {
          setState(() => roleChoice = newValue);
          if (newValue != null) {
            widget.onRoleSelected(newValue);
          }
        },
      ),
    );
  }
}
