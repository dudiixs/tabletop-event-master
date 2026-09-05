import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

/// The `tableagenda` Firebase project, as registered for `com.tabletop.events`.
///
/// Written out here rather than left to the native config files alone, for two
/// reasons. `Firebase.initializeApp()` with no options reads
/// `android/app/google-services.json` on Android and `GoogleService-Info.plist`
/// on iOS, which means the Dart side cannot say which project it is talking to
/// and a mismatch only shows up as a silent delivery failure. And it makes the
/// values greppable: when the project changes, this file and the two platform
/// files are the whole list of what has to change.
///
/// These keys identify the app; they do not authenticate it. A Firebase client
/// API key is designed to ship inside the binary — unlike the Notion token,
/// which is exactly why `PROXY.md` exists. Sending a push still requires the
/// service account's private key, which lives on the server and never here.
///
/// Regenerate with `flutterfire configure` if the project is ever replaced.
abstract final class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'O alvo web não recebe push: nenhum app web está registrado no projeto '
        'tableagenda e o build web usa fixtures. Guarde as chamadas com '
        'PushGateway.isSupported.',
      );
    }

    return switch (defaultTargetPlatform) {
      TargetPlatform.android => android,
      TargetPlatform.iOS => ios,
      _ => throw UnsupportedError(
          'Sem configuração Firebase para $defaultTargetPlatform.',
        ),
    };
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBdrxgkR_H95cH6I3XJM9WhaoEISIWyeTc',
    appId: '1:800808510901:android:1ff7cb866e65beef4465fc',
    messagingSenderId: '800808510901',
    projectId: 'tableagenda',
    storageBucket: 'tableagenda.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyD6o5tynrPNPIDG9XPb0NRHCwSG2cKGfHU',
    appId: '1:800808510901:ios:0c2155e8ac8ed0374465fc',
    messagingSenderId: '800808510901',
    projectId: 'tableagenda',
    storageBucket: 'tableagenda.firebasestorage.app',
    iosBundleId: 'com.tabletop.events',
  );
}
