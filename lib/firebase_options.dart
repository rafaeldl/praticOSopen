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
    apiKey: 'AIzaSyAd93aSERNbfNt7QU_ki1duzd7zppF6SvA',
    appId: '1:940190275097:web:e627978b56523419a2fc88',
    messagingSenderId: '940190275097',
    projectId: 'praticos',
    authDomain: 'praticos.firebaseapp.com',
    databaseURL: 'https://praticos.firebaseio.com',
    storageBucket: 'praticos.appspot.com',
    measurementId: 'G-5L7Z0GSM2W',
  );

}