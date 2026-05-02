# iOS Release Preparation Checklist

## Completed Tasks ✅

### 1. Dependencies Added to pubspec.yaml
- [x] **geolocator** (^11.0.0) - For GPS location tracking and finding nearest parks
- [x] **pedometer** (^3.1.0) - For step counting to support the game module

### 2. Info.plist Configuration
- [x] Created `ios/Runner/Info.plist` with proper XML structure
- [x] Added `NSLocationWhenInUseUsageDescription`: "Potřebujeme tvou polohu pro mapu úkolů"
- [x] Added `NSMotionUsageDescription`: "Potřebujeme počítat tvé kroky pro hru"

### 3. Bundle ID Configuration
- [x] Created `ios/Flutter/Flutter.xcconfig` with Bundle ID configuration
- [x] Set default Bundle ID: `com.tvojejmeno.hejbejse`
- [x] Created configuration guide for customization

## Next Steps for Release

### 1. Update Bundle ID
Before building for release, update the Bundle ID in one of these locations:

**Option A - Via Xcode (Recommended)**
```
Xcode → Runner project → Build Settings → Search "Bundle Identifier"
Set to: com.yourcompany.hejbejse
```

**Option B - Via ios/Flutter/Flutter.xcconfig**
```
PRODUCT_BUNDLE_IDENTIFIER = com.yourcompany.hejbejse
```

### 2. Run Flutter Pub Get
```bash
flutter pub get
cd ios
pod install --repo-update
cd ..
```

### 3. Configure Permissions at Runtime
Add runtime permission handling using `permission_handler` or `geolocator`'s built-in permission methods:
```dart
// Example usage via geolocator
import 'package:geolocator/geolocator.dart';

LocationPermission permission = await Geolocator.requestLocationPermission();
```

### 4. Build and Test
```bash
# Test build
flutter build ios --debug

# Release build
flutter build ios --release

# Archive for App Store
xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -configuration Release -archivePath Runner.xcarchive archive
```

### 5. App Store Connect
1. Create bundle ID in App Store Connect
2. Configure app capabilities (Location Services, Motion & Fitness)
3. Set privacy policy if required
4. Upload build via Xcode or Transporter

## Files Created/Modified

### Modified:
- `pubspec.yaml` - Added geolocator and pedometer dependencies

### Created:
- `ios/Runner/Info.plist` - Application metadata and permissions
- `ios/Flutter/Generated.xcconfig` - Auto-generated build configuration
- `ios/Flutter/Flutter.xcconfig` - Flutter framework and bundle ID configuration
- `ios/Podfile` - CocoaPods dependency specification
- `ios/.gitignore` - Ignore iOS build artifacts
- `ios/BUILD_CONFIG_GUIDE.md` - Detailed build configuration documentation

## Important Notes

⚠️ **Before submitting to App Store:**
1. Update Bundle ID to your organization's domain
2. Configure Apple Developer signing certificates
3. Set up provisioning profiles for release
4. Update App version and build number in pubspec.yaml
5. Configure privacy labels for location and motion permissions
6. Test location and step counting features on real device

🔐 **Security:**
- Keep provisioning profiles secure
- Store credentials outside version control
- Review permission usage in privacy policy