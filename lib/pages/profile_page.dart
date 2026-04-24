import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../fonctions/AppLocalizations.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).translate('profile')),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              backgroundImage: user?.photoURL != null 
                  ? NetworkImage(user!.photoURL!) 
                  : const AssetImage('assets/images/icon.png') as ImageProvider,
              radius: 40,
              child: user?.photoURL == null ? const Icon(Icons.person, size: 40) : null,
            ),
            const SizedBox(height: 10),
            Text(user?.displayName ?? "Utilisateur", style: const TextStyle(fontSize: 18)),
            Text(user?.email ?? "Pas d'email", style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 20),
            // ElevatedButton.icon(
            //   icon: const Icon(Icons.logout),
            //   label: Text(
            //     "${AppLocalizations.of(context).translate('logout')}",
            //   ),
            //   onPressed: () {
            //     auth.signOut();
            //     _handleSignOut();
            //     Navigator.pop(context);
            //   },
            // ),
          ],
        ),
      ),
    );
  }
}
