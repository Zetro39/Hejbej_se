import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Default Firebase configuration options for each supported platform.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions are not supported for web. Please configure Firebase separately for web.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCdP-VjtCDjKXuxRGyfZ3Yufk19U_AIC5s',
    appId: '1:684627309697:android:783789c860a6cc565f8980',
    messagingSenderId: '684627309697',
    projectId: 'hejbej-450a5',
    storageBucket: 'hejbej-450a5.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAuGfOqje4ZO2WaxOpeNpmxeIxoFH8go_k',
    appId: '1:684627309697:ios:c2947090c5e2e8915f8980',
    messagingSenderId: '684627309697',
    projectId: 'hejbej-450a5',
    storageBucket: 'hejbej-450a5.firebasestorage.app',
    iosBundleId: 'com.zetro39.hejbejse',
  );
}
