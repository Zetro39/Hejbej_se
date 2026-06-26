import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdService {
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal();

  RewardedAd? _rewardedAd;
  bool _isRewardedAdLoading = false;

  // Real AdMob unit IDs provided by the user
  static const String androidRewardedId = 'ca-app-pub-6543788544174221/4230807471';
  static const String iosRewardedId = 'ca-app-pub-6543788544174221/8403198229';

  String get rewardedAdUnitId {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return androidRewardedId;
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      return iosRewardedId;
    }
    return '';
  }

  Future<void> initialize() async {
    try {
      await MobileAds.instance.initialize();
      loadRewardedAd();
    } catch (e) {
      debugPrint('AdService initialization failed: $e');
    }
  }

  void loadRewardedAd() {
    final adUnitId = rewardedAdUnitId;
    if (adUnitId.isEmpty || _isRewardedAdLoading || _rewardedAd != null) return;
    _isRewardedAdLoading = true;

    RewardedAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isRewardedAdLoading = false;
          debugPrint('Rewarded ad loaded successfully.');
          
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _rewardedAd = null;
              loadRewardedAd(); // Load next ad in background
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _rewardedAd = null;
              loadRewardedAd();
            },
          );
        },
        onAdFailedToLoad: (error) {
          _isRewardedAdLoading = false;
          _rewardedAd = null;
          debugPrint('Failed to load rewarded ad: $error');
        },
      ),
    );
  }

  void showRewardedAd({
    required Function(RewardItem) onRewardEarned,
    required VoidCallback onAdFailed,
  }) {
    if (_rewardedAd != null) {
      _rewardedAd!.show(
        onUserEarnedReward: (adWithoutView, reward) {
          onRewardEarned(reward);
        },
      );
    } else {
      onAdFailed();
      loadRewardedAd(); // Try reloading
    }
  }

  bool isRewardedAdReady() {
    return _rewardedAd != null;
  }

  // Daily limit controls (Max 3 rewarded ads per day)
  Future<bool> canWatchRewardedAd() async {
    final prefs = await SharedPreferences.getInstance();
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    final lastAdDate = prefs.getString('last_rewarded_ad_date') ?? '';
    int count = prefs.getInt('rewarded_ads_count') ?? 0;
    
    if (lastAdDate != todayStr) {
      // New day, reset counts
      await prefs.setString('last_rewarded_ad_date', todayStr);
      await prefs.setInt('rewarded_ads_count', 0);
      return true;
    }
    
    return count < 3;
  }

  Future<void> incrementRewardedAdCount() async {
    final prefs = await SharedPreferences.getInstance();
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    int count = prefs.getInt('rewarded_ads_count') ?? 0;
    
    await prefs.setString('last_rewarded_ad_date', todayStr);
    await prefs.setInt('rewarded_ads_count', count + 1);
  }

  Future<int> getRemainingRewardedAds() async {
    final prefs = await SharedPreferences.getInstance();
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    final lastAdDate = prefs.getString('last_rewarded_ad_date') ?? '';
    int count = prefs.getInt('rewarded_ads_count') ?? 0;
    
    if (lastAdDate != todayStr) {
      return 3;
    }
    return (3 - count).clamp(0, 3);
  }
}
