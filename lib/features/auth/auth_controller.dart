import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/secure_storage_service.dart';
import '../../core/theme/theme_controller.dart';
import '../../domain/event_category.dart';
import '../../domain/user_model.dart';
import '../../notifications/interests_controller.dart';
import 'auth_state.dart';

final authProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

class AuthController extends Notifier<AuthState> {
  static const _userKey = 'tabletop_current_user_secure';
  static const _legacyUserKey = 'tabletop_current_user';

  @override
  AuthState build() {
    _loadUser();
    return const AuthUnauthenticated();
  }

  Future<void> _loadUser() async {
    final secureStorage = ref.read(secureStorageProvider);
    var jsonStr = await secureStorage.read(_userKey);

    // Migration from unencrypted legacy storage if present
    if (jsonStr == null || jsonStr.isEmpty) {
      final prefs = ref.read(sharedPreferencesProvider);
      final legacyStr = prefs.getString(_legacyUserKey);
      if (legacyStr != null && legacyStr.isNotEmpty) {
        jsonStr = legacyStr;
        await secureStorage.write(_userKey, legacyStr);
        await prefs.remove(_legacyUserKey);
      }
    }

    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        final Map<String, dynamic> data = jsonDecode(jsonStr);
        final user = UserModel.fromJson(data);
        state = AuthAuthenticated(user);
      } catch (_) {
        state = const AuthUnauthenticated();
      }
    }
  }

  bool get isAuthenticated => state is AuthAuthenticated;

  UserModel? get currentUser => switch (state) {
        AuthAuthenticated(:final user) => user,
        _ => null,
      };

  Future<bool> loginWithEmail({
    required String email,
    required String password,
  }) async {
    state = const AuthAuthenticating();
    await Future.delayed(const Duration(milliseconds: 600));

    if (email.trim().isEmpty || password.isEmpty) {
      state = const AuthError('Por favor, informe e-mail e senha.');
      return false;
    }

    if (!email.contains('@')) {
      state = const AuthError('Insira um e-mail válido.');
      return false;
    }

    // Mock successful authentication
    final user = UserModel(
      id: 'user_${DateTime.now().millisecondsSinceEpoch}',
      name: email.split('@').first.capitalize(),
      email: email.trim(),
      phone: '(11) 98765-4321',
      authProvider: AuthProviderType.email,
      favoriteTcgs: {'Pokémon TCG', 'Magic: The Gathering'},
      createdAt: DateTime.now(),
    );

    await _persistUser(user);
    _syncInterestsWithTcgs(user.favoriteTcgs);
    state = AuthAuthenticated(user);
    return true;
  }

  Future<bool> registerWithEmail({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    state = const AuthAuthenticating();
    await Future.delayed(const Duration(milliseconds: 700));

    final cleanName = name.trim();
    final cleanEmail = email.trim().toLowerCase();
    final cleanPhone = phone.trim();

    if (cleanName.isEmpty) {
      state = const AuthError('Informe seu nome completo.');
      return false;
    }

    if (!cleanEmail.contains('@')) {
      state = const AuthError('Informe um e-mail válido.');
      return false;
    }

    if (password.length < 8) {
      state = const AuthError('A senha deve ter pelo menos 8 caracteres.');
      return false;
    }

    final user = UserModel(
      id: 'user_${DateTime.now().millisecondsSinceEpoch}',
      name: cleanName,
      email: cleanEmail,
      phone: cleanPhone,
      authProvider: AuthProviderType.email,
      favoriteTcgs: {'Pokémon TCG'},
      createdAt: DateTime.now(),
    );

    await _persistUser(user);
    _syncInterestsWithTcgs(user.favoriteTcgs);
    state = AuthAuthenticated(user);
    return true;
  }

  Future<bool> loginWithGoogle() async {
    state = const AuthAuthenticating();
    await Future.delayed(const Duration(milliseconds: 700));

    final user = UserModel(
      id: 'google_${DateTime.now().millisecondsSinceEpoch}',
      name: 'Jogador Google',
      email: 'jogador.google@gmail.com',
      phone: '(11) 91234-5678',
      authProvider: AuthProviderType.google,
      favoriteTcgs: {'Pokémon TCG', 'Magic: The Gathering', 'Yu-Gi-Oh!'},
      createdAt: DateTime.now(),
    );

    await _persistUser(user);
    _syncInterestsWithTcgs(user.favoriteTcgs);
    state = AuthAuthenticated(user);
    return true;
  }

  Future<bool> loginWithApple() async {
    state = const AuthAuthenticating();
    await Future.delayed(const Duration(milliseconds: 700));

    final user = UserModel(
      id: 'apple_${DateTime.now().millisecondsSinceEpoch}',
      name: 'Treinador Apple',
      email: 'treinador@icloud.com',
      phone: '(11) 97654-3210',
      authProvider: AuthProviderType.apple,
      favoriteTcgs: {'Pokémon TCG', 'Digimon'},
      createdAt: DateTime.now(),
    );

    await _persistUser(user);
    _syncInterestsWithTcgs(user.favoriteTcgs);
    state = AuthAuthenticated(user);
    return true;
  }

  Future<bool> resetPassword(String email) async {
    if (!email.contains('@')) {
      state = const AuthError('Informe um e-mail válido.');
      return false;
    }
    await Future.delayed(const Duration(milliseconds: 500));
    return true;
  }

  Future<void> updateProfile({
    String? name,
    String? phone,
    Set<String>? favoriteTcgs,
    String? avatarUrl,
  }) async {
    final current = currentUser;
    if (current == null) return;

    final updatedUser = current.copyWith(
      name: name?.trim(),
      phone: phone?.trim(),
      favoriteTcgs: favoriteTcgs,
      avatarUrl: avatarUrl,
    );

    await _persistUser(updatedUser);
    if (favoriteTcgs != null) {
      _syncInterestsWithTcgs(favoriteTcgs);
    }
    state = AuthAuthenticated(updatedUser);
  }

  Future<void> logout() async {
    final secureStorage = ref.read(secureStorageProvider);
    final prefs = ref.read(sharedPreferencesProvider);
    await secureStorage.delete(_userKey);
    await prefs.remove(_legacyUserKey);
    state = const AuthUnauthenticated();
  }

  Future<void> _persistUser(UserModel user) async {
    final secureStorage = ref.read(secureStorageProvider);
    await secureStorage.write(_userKey, jsonEncode(user.toJson()));
  }

  void _syncInterestsWithTcgs(Set<String> tcgs) {
    final interestsNotifier = ref.read(interestsProvider.notifier);
    final categoriesToSelect = EventCategory.values.where(
      (cat) => tcgs.contains(cat.label) || tcgs.contains(cat.name),
    );

    for (final cat in categoriesToSelect) {
      if (!interestsNotifier.follows(cat)) {
        interestsNotifier.toggle(cat);
      }
    }
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}
