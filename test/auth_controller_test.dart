import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabletop_events/core/theme/theme_controller.dart';
import 'package:tabletop_events/domain/user_model.dart';
import 'package:tabletop_events/features/auth/auth_controller.dart';
import 'package:tabletop_events/features/auth/auth_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late ProviderContainer container;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  test('Starts unauthenticated when no user is saved', () {
    final state = container.read(authProvider);
    expect(state, isA<AuthUnauthenticated>());
  });

  test('Login with Google sets authenticated state', () async {
    final controller = container.read(authProvider.notifier);
    final success = await controller.loginWithGoogle();

    expect(success, isTrue);
    final state = container.read(authProvider);
    expect(state, isA<AuthAuthenticated>());

    final user = (state as AuthAuthenticated).user;
    expect(user.authProvider, AuthProviderType.google);
    expect(user.email, contains('google'));
  });

  test('Register with email creates user and persists state', () async {
    final controller = container.read(authProvider.notifier);
    final success = await controller.registerWithEmail(
      name: 'Eduardo Martins',
      email: 'eduardo@exemplo.com',
      phone: '(11) 99999-8888',
      password: 'password123',
    );

    expect(success, isTrue);
    final user = controller.currentUser;
    expect(user, isNotNull);
    expect(user!.name, 'Eduardo Martins');
    expect(user.phone, '(11) 99999-8888');
  });

  test('Update profile modifies TCGs and user details', () async {
    final controller = container.read(authProvider.notifier);
    await controller.loginWithEmail(
      email: 'test@exemplo.com',
      password: 'password123',
    );

    await controller.updateProfile(
      name: 'Nome Atualizado',
      phone: '(11) 97777-6666',
      favoriteTcgs: {'⚡ Pokémon TCG', '🛡️ Flesh and Blood'},
    );

    final user = controller.currentUser;
    expect(user!.name, 'Nome Atualizado');
    expect(user.phone, '(11) 97777-6666');
    expect(user.favoriteTcgs, contains('🛡️ Flesh and Blood'));
  });
}
