// File generated manually for web platform support.
// For iOS/Android, native config files (GoogleService-Info.plist / google-services.json)
// are used automatically by the Firebase SDK.
//
// To regenerate: flutterfire configure

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    // On iOS/Android, Firebase.initializeApp() reads from native config files
    // (GoogleService-Info.plist / google-services.json) automatically.
    // We return a minimal options object; the native SDK will override with
    // the values from the config files.
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        // Return web options as fallback; native plugins will use their own config files.
        return web;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAQplCVRqUqJkmYxLr-jdQKIKR8cnXFal0',
    appId: '1:839332459506:web:907b70ea129edf52',
    messagingSenderId: '839332459506',
    projectId: 'caaac-dev',
    authDomain: 'caaac-dev.firebaseapp.com',
    databaseURL: 'https://caaac-dev.firebaseio.com',
    storageBucket: 'caaac-dev.appspot.com',
  );
}
