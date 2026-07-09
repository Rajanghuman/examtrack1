// File generated manually from GoogleService-Info.plist
// and google-services.json for ExamTrack project

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web - '
        'you can reconfigure this by running the FlutterFire CLI again.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyC2OtJ6T6nBSLihDRriBgpbi1aZ3u7V-s8',
    appId: '1:631082617337:android:278307653e373dcf6b5528',
    messagingSenderId: '631082617337',
    projectId: 'examtrack-b64e9',
    storageBucket: 'examtrack-b64e9.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyC2OtJ6T6nBSLihDRriBgpbi1aZ3u7V-s8',
    appId: '1:631082617337:ios:68cefbf37e5e5ebb6b5528',
    messagingSenderId: '631082617337',
    projectId: 'examtrack-b64e9',
    storageBucket: 'examtrack-b64e9.firebasestorage.app',
    iosClientId: '631082617337-l40lumnjbbrm8a4i1hkj2cj8b8ehblnu.apps.googleusercontent.com',
    iosBundleId: 'com.examtrack.app.ios',
  );
}
