import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_palette.dart';
import '../../domain/user_model.dart';
import '../auth/auth_controller.dart';
import '../auth/auth_state.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  late Set<String> _selectedTcgs;
  bool _isEditing = false;

  static const _availableTcgs = [
    '⚡ Pokémon TCG',
    '✨ Magic: The Gathering',
    '🌟 Yu-Gi-Oh!',
    '🔥 Digimon',
    '🤖 Gundam',
    '🎲 Board Games',
    '🐉 RPG',
    '⚔️ One Piece TCG',
    '🛡️ Flesh and Blood',
    '🏰 Disney Lorcana',
  ];

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider.notifier).currentUser;
    _nameController.text = user?.name ?? '';
    _phoneController.text = user?.phone ?? '';
    _selectedTcgs = Set.from(user?.favoriteTcgs ?? {'⚡ Pokémon TCG'});
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _toggleTcg(String tcg) {
    setState(() {
      if (_selectedTcgs.contains(tcg)) {
        _selectedTcgs.remove(tcg);
      } else {
        _selectedTcgs.add(tcg);
      }
    });
  }

  Future<void> _saveChanges() async {
    await ref.read(authProvider.notifier).updateProfile(
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          favoriteTcgs: _selectedTcgs,
        );

    if (mounted) {
      setState(() => _isEditing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Perfil atualizado e TCGs sincronizados!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sair da Conta?'),
        content: const Text('Você precisará entrar novamente para acessar seu perfil.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sair'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(authProvider.notifier).logout();
      if (mounted) {
        context.go(AppRoutes.home);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final authState = ref.watch(authProvider);

    if (authState is! AuthAuthenticated) {
      return Scaffold(
        appBar: AppBar(title: const Text('Perfil')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Você não está conectado.'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.go(AppRoutes.login),
                child: const Text('Fazer Login'),
              ),
            ],
          ),
        ),
      );
    }

    final user = authState.user;

    return Scaffold(
      backgroundColor: palette.surface,
      appBar: AppBar(
        title: const Text('Meu Perfil'),
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.check : Icons.edit_outlined),
            tooltip: _isEditing ? 'Salvar' : 'Editar Perfil',
            onPressed: () {
              if (_isEditing) {
                _saveChanges();
              } else {
                setState(() => _isEditing = true);
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            // User Header Card
            Card(
              elevation: 0,
              color: palette.card,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: palette.border),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: palette.primary,
                      child: Text(
                        user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      user.name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.email,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: palette.textSecondary,
                          ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: palette.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            switch (user.authProvider) {
                              AuthProviderType.google => Icons.g_mobiledata,
                              AuthProviderType.apple => Icons.apple,
                              AuthProviderType.email => Icons.email_outlined,
                            },
                            size: 18,
                            color: palette.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Entrou via ${user.authProvider.label}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: palette.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Personal Information Card
            Card(
              elevation: 0,
              color: palette.card,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: palette.border),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Informações Pessoais',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 16),
                    if (_isEditing) ...[
                      TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Nome Completo',
                          prefixIcon: Icon(Icons.person_outline),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Telefone / WhatsApp',
                          prefixIcon: Icon(Icons.phone_outlined),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ] else ...[
                      _ProfileDetailItem(
                        icon: Icons.person_outline,
                        label: 'Nome',
                        value: user.name,
                      ),
                      const Divider(height: 24),
                      _ProfileDetailItem(
                        icon: Icons.email_outlined,
                        label: 'E-mail',
                        value: user.email,
                      ),
                      const Divider(height: 24),
                      _ProfileDetailItem(
                        icon: Icons.phone_outlined,
                        label: 'Telefone / WhatsApp',
                        value: user.phone.isNotEmpty ? user.phone : 'Não informado',
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Favorite TCGs Card (Multi-select)
            Card(
              elevation: 0,
              color: palette.card,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: palette.border),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(AppIcons.quality, color: palette.warning, size: 22),
                        const SizedBox(width: 8),
                        Text(
                          'TCGs Favoritos',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Selecione um ou mais jogos que você joga. Suas escolhas sincronizam os avisos de novos eventos!',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: palette.textSecondary,
                          ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _availableTcgs.map((tcg) {
                        final isSelected = _selectedTcgs.contains(tcg);
                        return FilterChip(
                          label: Text(tcg),
                          selected: isSelected,
                          onSelected: (_) => _toggleTcg(tcg),
                          selectedColor: palette.primary.withValues(alpha: 0.2),
                          checkmarkColor: palette.primary,
                          labelStyle: TextStyle(
                            color: isSelected ? palette.primary : palette.text,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                          backgroundColor: palette.surface,
                          side: BorderSide(
                            color: isSelected
                                ? palette.primary
                                : palette.border,
                          ),
                        );
                      }).toList(),
                    ),
                    if (_isEditing) ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _saveChanges,
                          child: const Text('Salvar TCGs Favoritos'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Logout Action
            OutlinedButton.icon(
              onPressed: _handleLogout,
              style: OutlinedButton.styleFrom(
                foregroundColor: palette.error,
                side: BorderSide(color: palette.error),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: const Icon(Icons.logout),
              label: const Text(
                'Sair da Conta',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _ProfileDetailItem extends StatelessWidget {
  const _ProfileDetailItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Row(
      children: [
        Icon(icon, size: 20, color: palette.textSecondary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: palette.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: palette.text,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
