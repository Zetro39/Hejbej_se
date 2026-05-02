# iOS Build Configuration Guide for Hejbej se

## Bundle ID Configuration

The Bundle ID uniquely identifies your iOS app on the App Store. Follow these steps to configure it:

### Option 1: Using Xcode
1. Open `ios/Runner.xcworkspace` in Xcode
2. Select the "Runner" project in the left sidebar
3. Select the "Runner" target
4. Go to the "Build Settings" tab
5. Search for "Bundle Identifier" or "PRODUCT_BUNDLE_IDENTIFIER"
6. Set the value to: `com.tvojejmeno.hejbejse` (or your custom identifier)

### Option 2: Using the Configuration File
The Bundle ID can also be set in `ios/Flutter/Flutter.xcconfig`:
```
PRODUCT_BUNDLE_IDENTIFIER = com.tvojejmeno.hejbejse
```

## Permissions Configuration

The following permissions have been configured in `ios/Runner/Info.plist`:

### Location Permission
- **Key**: NSLocationWhenInUseUsageDescription
- **Value**: Potřebujeme tvou polohu pro mapu úkolů
- **Purpose**: Required for the Maps module to access user's location

### Motion Permission
- **Key**: NSMotionUsageDescription
- **Value**: Potřebujeme počítat tvé kroky pro hru
- **Purpose**: Required for the Game module to count steps via pedometer

## Dependencies

The following packages have been added to `pubspec.yaml`:
- **geolocator**: ^11.0.0 - For GPS location tracking
- **pedometer**: ^3.1.0 - For step counting

## Build Instructions

Run the following commands to build for iOS:

```bash
flutter clean
flutter pub get
cd ios
pod install --repo-update
cd ..
flutter build ios --release
```

## Xcode Project Files

The following iOS configuration files have been created:
- `ios/Flutter/Generated.xcconfig` - Auto-generated build configuration
- `ios/Flutter/Flutter.xcconfig` - Flutter framework configuration
- `ios/Podfile` - CocoaPods dependency specification
- `ios/Runner/Info.plist` - Application metadata and permissions

## Important Notes

1. Replace `com.tvojejmeno.hejbejse` with your actual organization identifier
2. Ensure you have an Apple Developer account for building for a real device
3. The app requires iOS 11.0 or later
4. Both location and motion permissions require explicit user consent at runtime using permission_handler or similar package