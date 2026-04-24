import 'package:skillgrowth/activities/providers.dart';
import 'package:skillgrowth/activities/screens/childDetail.dart';
import 'package:skillgrowth/activities/screens/userHomePage.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/AuthProvider.dart';
import '../fonctions/AppLocalizations.dart';
import '../fonctions/DeleteUserButton.dart';
import 'modèles.dart';
import '../pages/MyApp.dart';
import 'AddChildScreen.dart';
import 'AllButtons.dart';
import 'data_populator.dart';

class ParentHomePage extends StatefulWidget {
  const ParentHomePage({super.key});

  @override
  State<ParentHomePage> createState() => _ParentHomePageState();
}

class _ParentHomePageState extends State<ParentHomePage> {
  bool _isSigningOut = false;
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
  }

  // Logout handler with confirmation dialog
  Future<void> _handleSignOut() async {
    setState(() => _isSigningOut = true);

    try {
      await _authService.signOut();

      if (!mounted) return;

      // Attendre un peu pour l'animation
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;

      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const MyApp1()));
    } catch (e) {
      debugPrint('Erreur déconnexion: $e');
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).translate('connexErreur')),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSigningOut = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final childProvider = Provider.of<ChildProvider>(context);
    final userProvider = Provider.of<UserProvider>(context);
    final user = userProvider.user;

    return user == null
        ? CustomShimmerEffect()
        : Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: InkWell(
              onTap:
                  () => Navigator.of(
                    context,
                  ).push(MaterialPageRoute(builder: (ctx) => const AllButtons())),
              child: const Text('SkillGrowth'),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed:
                    () =>
                        childProvider.loadChildren(user.id, forceRefresh: true),
              ),
              IconButton(
                onPressed: () async {
                  await DataPopulatorClaude().populateData();
                },
                icon: const Icon(Icons.add_road, color: Colors.deepPurple),
              ),
              IconButton(
                onPressed:
                    _isSigningOut
                        ? null
                        : () async {
                          childProvider.clearCache();
                          await _handleSignOut();
                        },
                icon:
                    _isSigningOut
                        ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Icons.logout),
                tooltip: 'Logout',
              ),

               DeleteAccountButton(),
            ],
          ),
          body: SingleChildScrollView(
            child: Center(
              child: Column(
                children: [
                  Text(
                    '${user.role.toUpperCase()} ${user.name.toUpperCase()}',
                    style: const TextStyle(fontSize: 20),
                  ),
                  const SizedBox(height: 20),
                  _buildBody(childProvider, user),
                ],
              ),
            ),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: _navigateToAddChild,
            child: const Icon(Icons.add),
          ),
        );
  }

  Widget _buildBody(ChildProvider provider, UserModel parent) {
    if (provider.isLoading && provider.children.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.error != null) {
      return Center(child: Text(provider.error!));
    }

    if (provider.children.isEmpty) {
      return const Center(child: Text('Aucun enfant enregistré'));
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.85,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: provider.children.length,
      itemBuilder: (context, index) {
        final child = provider.children[index];
        return Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 2,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (ctx) => ChildDetailScreen(child: child),
              ),
            ),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Hero(
                        tag: 'child-image-${child.id}',
                        child: CircleAvatar(
                          radius: 35,
                          backgroundColor: child.gender == 'male'
                              ? Colors.blue.shade50
                              : child.gender == 'female'
                              ? Colors.pink.shade50
                              : Colors.grey.shade100,
                          child: Icon(
                            child.gender == 'male'
                                ? Icons.face
                                : child.gender == 'female'
                                ? Icons.face_3
                                : Icons.account_circle,
                            size: 40,
                            color: child.gender == 'male'
                                ? Colors.blue
                                : child.gender == 'female'
                                ? Colors.pink
                                : Colors.grey,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        child.name,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${child.age} ans',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 20),
                    onSelected: (value) async {
                      if (value == 'edit') {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AddChildScreen(
                              parent: parent,
                              child: child,
                            ),
                          ),
                        );
                      } else if (value == 'delete') {
                        _showDeleteConfirmation(child, parent);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: ListTile(
                          leading: Icon(Icons.edit, size: 20),
                          title: Text('Modifier'),
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          leading: Icon(Icons.delete, color: Colors.red, size: 20),
                          title: Text('Supprimer', style: TextStyle(color: Colors.red)),
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showDeleteConfirmation(
    Child child,
    UserModel parent,
  ) async {
    final bool confirmed =
        await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: Text('Voulez-vous vraiment supprimer ${child.name} ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
        ) ??
        false;

    if (confirmed == true && mounted) {
      await context.read<ChildProvider>().deleteChild(child.id, parent.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enfant supprimé avec succès')),
      );
    }
  }

  Future<void> _navigateToAddChild() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final user = userProvider.user;
    if (user == null) return;
    
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AddChildScreen(parent: user)),
    );

    // Seulement rafraîchir si un nouvel enfant a été ajouté
    if (result == true && mounted) {
      Provider.of<ChildProvider>(
        context,
        listen: false,
      ).loadChildren(user.id, forceRefresh: true);
    }
  }
}
