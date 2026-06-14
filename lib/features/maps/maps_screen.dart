import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:pedometer/pedometer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart' hide GeoPoint;

import '../../services/location_service.dart';
import '../../services/auth_service.dart';
import '../../services/notification_manager.dart';
import '../../services/step_tracker_service.dart';
import '../../services/anticheat_service.dart';
import '../../theme_config.dart';
import '../profile/notification_inbox_screen.dart';
import '../leaderboard/friend_profile_screen.dart';
import 'qr_scanner_screen.dart';
import 'package:pay/pay.dart';
import 'ar_navigation_screen.dart';
import 'route_selection_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../gamification/models/wheel_of_fortune_model.dart';
import '../gamification/services/wheel_of_fortune_service.dart';
import '../gamification/wheel_of_fortune_screen.dart';

class PlacePrediction {
  final String description;
  final String placeId;

  PlacePrediction({required this.description, required this.placeId});

  factory PlacePrediction.fromJson(Map<String, dynamic> json) {
    return PlacePrediction(
      description: json['description'] as String? ?? '',
      placeId: json['place_id'] as String? ?? '',
    );
  }
}

class MapsScreen extends StatefulWidget {
  final bool showMapType;
  final bool showMapStyle;
  final bool showShareLocation;
  final bool showArNav;

  const MapsScreen({
    super.key,
    this.showMapType = true,
    this.showMapStyle = true,
    this.showShareLocation = true,
    this.showArNav = true,
  });

  static final ValueNotifier<String?> pendingSharedRouteNotifier = ValueNotifier<String?>(null);

  @override
  State<MapsScreen> createState() => _MapsScreenState();
}

class _MapsScreenState extends State<MapsScreen> with TickerProviderStateMixin {
  GoogleMapController? _mapController;
  late LocationService _locationService;
  late Stream<Position> _positionStream;
  StreamSubscription<Position>? _positionSubscription;

  final Set<Polyline> _polylines = {};
  final Set<Marker> _markers = {};
  final List<LatLng> _polylineCoordinates = [];
  final List<LatLng> _breadcrumbsCoordinates = [];
  List<LatLng> _activeRoutePoints = [];

  BitmapDescriptor? _avatarIcon;
  String _currentMapStyle = 'default'; // 'default', 'light', 'dark'
  BitmapDescriptor? _companionIcon;
  String? _activeCompanionId;
  int _unreadNotificationsCount = 0;
  bool _usingBike = false;
  double _walkRangeMin = 2.0;
  double _walkRangeMax = 5.0;
  double _bikeRangeMin = 10.0;
  double _bikeRangeMax = 30.0;
  final double _dailyTargetKm = 1.0;
  bool _routeActive = false;
  double _remainingDistance = 0.0;
  int _remainingEta = 0;
  WheelOfFortune? _activeRouteGame;
  bool _isGroupMode = false;
  double _gameLastTriggeredDistance = 0.0;
  List<String> _gamePlayers = [];
  Map<String, List<String>> _gamePlayerHistory = {};
  Map<String, WheelTask> _gameActiveAssignments = {};
  int _closestWaypointIndex = 0;
  String _navigationInstruction = 'Sledujte vyznačenou trasu';
  IconData _navigationIcon = Icons.navigation;
  bool _isLoadingRoutes = false;
  bool _showRouteSuggestions = false;
  List<Map<String, dynamic>> _routeSuggestions = [];
  int _selectedRouteSuggestionIndex = 0;
  bool _showRouteSearch = false;
  late final PageController _routePageController;
  StreamSubscription<StepCount>? _stepCountSubscription;

  // Removed dummy Prague checkpoints left from testing.
  static const List<Map<String, dynamic>> _checkpoints = [];

  final Set<String> _reachedCheckpoints = {};
  double _todayDistance = 0.0;

  bool _isFollowingUser = true;
  Position? _lastPosition;
  Position? _initialPosition;
  Position? _previousPosition;
  bool _shareLocation = false;
  DateTime? _lastLocationShareTime;
  StreamSubscription<QuerySnapshot>? _friendsLocationsSubscription;
  final Map<String, BitmapDescriptor> _cachedFriendIcons = {};
  final Map<String, String> _geocodingCache = {};

  double _totalDistance = 0.0;
  int _limetkyBalance = 0;
  int _streak = 0;
  DateTime? _lastActivityDate;
  bool _isStreakFrozen = false;

  static const String _googleApiKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
    defaultValue: 'AIzaSyDxxxxxxxxxxxxxxxxxxxxxxxxx',
  );

  MapType _mapType = MapType.normal;
  List<Map<String, dynamic>> _partners = [];
  final Set<String> _alertedPartnerIds = {};

  double _searchWalkLength = 5.0;
  double _searchDrivingRadius = 25.0;

  String? _activeRouteKctColor;
  String? _activeRouteCykloNumber;
  String? _activeRouteTriviaQuestion;
  String? _activeRouteTriviaAnswer;

  final TextEditingController _destinationController = TextEditingController();

  bool _isSelectingDestination = false;
  LatLng? _destinationPoint;

  // UI & routing control
  bool _taskCardExpanded = false;
  bool _trackingEnabled = false; // accumulate distance only when true
  bool _routePlotted = false; // route geometry present but not yet started

  List<PlacePrediction> _placePredictions = [];
  bool _showSuggestions = false;

  // Elevation & Rewards

  @override
  void initState() {
    super.initState();
    AntiCheatService().reset();
    _routePageController = PageController(viewportFraction: 0.88);
    _locationService = LocationService();
    _positionStream = _locationService.positionUpdateStream;
    _loadSelectedAvatar();
    _loadReachedCheckpoints();
    _loadRangePreferences();
    _loadPersistentData();
    _setupMap();
    _initPedometer();
    _loadPremiumStatus();
    _loadLocationSharingPreference();
    _fetchPartners();
    StepTrackerService().stepsNotifier.addListener(_updateDistanceBySteps);
    _updateDistanceBySteps();
    MapsScreen.pendingSharedRouteNotifier.addListener(_handlePendingSharedRoute);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (MapsScreen.pendingSharedRouteNotifier.value != null) {
        _handlePendingSharedRoute();
      }
    });
  }

  Future<void> _loadReachedCheckpoints() async {
    final prefs = await SharedPreferences.getInstance();
    final reached = <String>{};
    for (final checkpoint in _checkpoints) {
      final id = checkpoint['id'] as String;
      if (prefs.getBool('achievement_${id}_reached') ?? false) {
        reached.add(id);
      }
    }
    if (mounted) {
      setState(() {
        _reachedCheckpoints.addAll(reached);
      });
    }
  }

  Future<void> _loadPersistentData() async {
    final prefs = await SharedPreferences.getInstance();
    _totalDistance = prefs.getDouble('totalDistance') ?? 0.0;
    _limetkyBalance = prefs.getInt('limetkyBalance') ?? 0;
    _streak = prefs.getInt('streak') ?? 0;
    _isStreakFrozen = prefs.getBool('isStreakFrozen') ?? false;
    final lastActivityString = prefs.getString('lastActivityDate');
    if (lastActivityString != null) {
      _lastActivityDate = DateTime.tryParse(lastActivityString);
    }
    await _loadActiveGameState();
    
    final mapTypeStr = prefs.getString('preferred_map_type') ?? 'normal';
    if (mounted) {
      setState(() {
        if (mapTypeStr == 'terrain') {
          _mapType = MapType.terrain;
        } else if (mapTypeStr == 'satellite') {
          _mapType = MapType.satellite;
        } else if (mapTypeStr == 'hybrid') {
          _mapType = MapType.hybrid;
        } else {
          _mapType = MapType.normal;
        }
      });
    }
  }

  Future<void> _savePersistentData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('totalDistance', _totalDistance);
    await prefs.setInt('limetkyBalance', _limetkyBalance);
    await prefs.setInt('streak', _streak);
    await prefs.setBool('isStreakFrozen', _isStreakFrozen);
    if (_lastActivityDate != null) {
      await prefs.setString('lastActivityDate', _lastActivityDate!.toIso8601String());
    }

    // Sync to Firestore
    await AuthService().updateDistance(_totalDistance, _limetkyBalance);
    await AuthService().updateStreak(_streak);
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _isConsecutiveDay(DateTime last, DateTime now) {
    final difference = now.difference(last).inDays;
    return difference == 1;
  }

  Future<void> _loadSelectedAvatar() async {
    final prefs = await SharedPreferences.getInstance();
    final avatar = prefs.getString('selected_avatar');
    _currentMapStyle = prefs.getString('map_style') ?? 'default';
    _activeCompanionId = prefs.getString('selected_companion');
    
    if (!mounted) return;

    if (avatar != null) {
      await _createAvatarIcon(avatar);
    }
    
    if (_activeCompanionId != null) {
      await _loadCompanionIcon(_activeCompanionId!);
    }
    
    await _loadUnreadNotificationsCount();
    await _restoreActiveRoute();
  }

  Future<void> _loadCompanionIcon(String companionId) async {
    try {
      final ByteData data = await rootBundle.load('assets/images/$companionId.png');
      final bytes = data.buffer.asUint8List();
      final circularIcon = await _getCircularMarker(bytes, 100, const Color(0xFFBFFF00));
      if (!mounted) return;
      setState(() {
        _companionIcon = circularIcon;
      });
    } catch (e) {
      debugPrint('Failed to load companion icon: $e');
    }
  }

  Future<void> _loadUnreadNotificationsCount() async {
    await NotificationManager.updateUnreadCount();
  }

  Future<void> _cacheActiveRoute(List<LatLng> points, String title, double distance, int eta) async {
    final prefs = await SharedPreferences.getInstance();
    final listJson = points.map((p) => [p.latitude, p.longitude]).toList();
    await prefs.setString('offline_route_points', jsonEncode(listJson));
    await prefs.setString('offline_route_title', title);
    await prefs.setDouble('offline_route_distance', distance);
    await prefs.setInt('offline_route_eta', eta);
    await prefs.setBool('offline_route_active', true);
  }

  Future<void> _clearCachedRoute() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('offline_route_points');
    await prefs.remove('offline_route_title');
    await prefs.remove('offline_route_distance');
    await prefs.remove('offline_route_eta');
    await prefs.setBool('offline_route_active', false);
  }

  Future<void> _restoreActiveRoute() async {
    final prefs = await SharedPreferences.getInstance();
    final hasActive = prefs.getBool('offline_route_active') ?? false;
    if (hasActive) {
      final pointsStr = prefs.getString('offline_route_points');
      if (pointsStr != null) {
        try {
          final list = jsonDecode(pointsStr) as List<dynamic>;
          final points = list.map((coord) => LatLng(coord[0] as double, coord[1] as double)).toList();
          final title = prefs.getString('offline_route_title') ?? 'Uložená trasa';
          final distance = prefs.getDouble('offline_route_distance') ?? 0.0;
          final eta = prefs.getInt('offline_route_eta') ?? 0;
          
          final polyline = Polyline(
            polylineId: const PolylineId('active_route'),
            color: _usingBike ? Colors.blue : Colors.green,
            width: 5,
            points: points,
            geodesic: true,
          );
          
          setState(() {
            _activeRoutePoints = points;
            _routePlotted = true; // plotted but not started
            _routeActive = false;
            _polylines.removeWhere((p) => p.polylineId.value == 'active_route');
            _polylines.add(polyline);
            _destinationPoint = points.last;
            _routeSuggestions = [
              {
                'title': title,
                'coordinates': points,
                'distance': distance,
                'eta': eta,
                'poi_count': 0,
              }
            ];
            _selectedRouteSuggestionIndex = 0;
          });
          
          // Defer fitting bounds until map controller is ready
          Future.delayed(const Duration(milliseconds: 600), () {
            if (mounted && _activeRoutePoints.isNotEmpty) {
              _fitMapBounds(_activeRoutePoints);
            }
          });
        } catch (_) {}
      }
    }
  }

  Future<void> _loadRangePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _walkRangeMin = prefs.getDouble('walk_range_min') ?? 2.0;
      _walkRangeMax = prefs.getDouble('walk_range_max') ?? 5.0;
      _bikeRangeMin = prefs.getDouble('bike_range_min') ?? 10.0;
      _bikeRangeMax = prefs.getDouble('bike_range_max') ?? 30.0;
      _usingBike = prefs.getBool('preferred_bike_mode') ?? false;
    });
  }

  void _initPedometer() {
    try {
      _stepCountSubscription = Pedometer.stepCountStream.listen((event) {
        // Step tracking prepared for later use.
      }, onError: (error) {
        debugPrint('Pedometer error: $error');
      });
    } catch (e) {
      debugPrint('Pedometer initialization failed: $e');
    }
  }

  void _updateDistanceBySteps() {
    if (mounted && !_routeActive) {
      setState(() {
        _todayDistance = StepTrackerService().stepsNotifier.value * 0.75;
      });
    }
  }

  void dispose() {
    _mapController?.dispose();
    _positionSubscription?.cancel();
    _friendsLocationsSubscription?.cancel();
    _destinationController.dispose();
    _routePageController.dispose();
    _stepCountSubscription?.cancel();
    StepTrackerService().stepsNotifier.removeListener(_updateDistanceBySteps);
    MapsScreen.pendingSharedRouteNotifier.removeListener(_handlePendingSharedRoute);
    super.dispose();
  }

  Future<void> _loadLocationSharingPreference() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _shareLocation = prefs.getBool('share_location') ?? false;
      });
      if (_shareLocation) {
        _startListeningToFriendsLocations();
      }
    }
  }

  Future<void> _startListeningToFriendsLocations() async {
    _friendsLocationsSubscription?.cancel();
    _friendsLocationsSubscription = null;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final friendsSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('friends')
          .where('status', isEqualTo: 'friends')
          .get();

      final friendUids = friendsSnap.docs.map((doc) => doc.id).toList();
      if (friendUids.isEmpty) return;

      final queryUids = friendUids.take(30).toList();

      _friendsLocationsSubscription = FirebaseFirestore.instance
          .collection('users')
          .where(FieldPath.documentId, whereIn: queryUids)
          .snapshots()
          .listen((snapshot) async {
        if (!mounted) return;

        final newMarkers = <Marker>[];
        final now = DateTime.now();

        for (final doc in snapshot.docs) {
          final data = doc.data();
          final shareLoc = data['share_location'] as bool? ?? false;
          if (!shareLoc) continue;

          final locationGeo = data['last_location'] as GeoPoint?;
          final lastUpdateTs = data['last_location_time'] as Timestamp?;

          if (locationGeo == null || lastUpdateTs == null) continue;

          final lastUpdate = lastUpdateTs.toDate();
          if (now.difference(lastUpdate).inHours >= 24) continue;

          final username = data['username'] as String? ?? 'Uživatel';
          final latLng = LatLng(locationGeo.latitude, locationGeo.longitude);
          final avatarStr = data['selected_avatar'] as String? ?? 'boy';

          BitmapDescriptor iconDescriptor;
          try {
            if (_cachedFriendIcons.containsKey(avatarStr)) {
              iconDescriptor = _cachedFriendIcons[avatarStr]!;
            } else {
              Uint8List bytes;
              if (avatarStr.startsWith('base64:')) {
                bytes = base64Decode(avatarStr.substring(7));
              } else {
                final ByteData data = await rootBundle.load('assets/images/$avatarStr.png');
                bytes = data.buffer.asUint8List();
              }
              final circularIcon = await _getCircularMarker(bytes, 100, Colors.white);
              _cachedFriendIcons[avatarStr] = circularIcon;
              iconDescriptor = circularIcon;
            }
          } catch (e) {
            debugPrint('Failed to load friend avatar marker: $e');
            iconDescriptor = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
          }

          newMarkers.add(
            Marker(
              markerId: MarkerId('friend_${doc.id}'),
              position: latLng,
              icon: iconDescriptor,
              onTap: () {
                _showFriendBottomSheet(
                  friendUid: doc.id,
                  username: username,
                  avatar: avatarStr,
                  latLng: latLng,
                  lastUpdate: lastUpdate,
                );
              },
            ),
          );
        }

        if (mounted) {
          setState(() {
            _markers.removeWhere((m) => m.markerId.value.startsWith('friend_'));
            _markers.addAll(newMarkers);
          });
        }
      });
    } catch (_) {}
  }

  Future<String> _reverseGeocode(double lat, double lng) async {
    final cacheKey = '${lat.toStringAsFixed(5)},${lng.toStringAsFixed(5)}';
    if (_geocodingCache.containsKey(cacheKey)) {
      return _geocodingCache[cacheKey]!;
    }

    try {
      final url = Uri.parse('https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&zoom=18&addressdetails=1');
      final response = await http.get(url, headers: {
        'User-Agent': 'HejbejSeApp/1.0 (contact@zetro39.cz)',
        'Accept-Language': 'cs',
      }).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final addressMap = data['address'] as Map<String, dynamic>?;
        if (addressMap != null) {
          final road = addressMap['road'] as String?;
          final houseNumber = addressMap['house_number'] as String?;
          final suburb = addressMap['suburb'] as String?;
          final city = (addressMap['city'] ?? addressMap['town'] ?? addressMap['village'] ?? addressMap['municipality']) as String?;

          List<String> parts = [];
          if (road != null) {
            if (houseNumber != null) {
              parts.add('$road $houseNumber');
            } else {
              parts.add(road);
            }
          } else if (suburb != null) {
            parts.add(suburb);
          }

          if (city != null) {
            parts.add(city);
          }

          if (parts.isNotEmpty) {
            final result = parts.join(', ');
            _geocodingCache[cacheKey] = result;
            return result;
          }
        }
        final displayName = data['display_name'] as String?;
        if (displayName != null) {
          final shortAddress = displayName.split(', ').take(3).join(', ');
          _geocodingCache[cacheKey] = shortAddress;
          return shortAddress;
        }
      }
    } catch (e) {
      debugPrint('Reverse geocoding failed: $e');
    }

    return 'Souřadnice: ${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
  }

  void _showFriendBottomSheet({
    required String friendUid,
    required String username,
    required String avatar,
    required LatLng latLng,
    required DateTime lastUpdate,
  }) {
    final isWhiteTheme = appThemeNotifier.value == 'white';
    final bgColor = isWhiteTheme ? Colors.white : const Color(0xFF1E272C);
    final textColor = isWhiteTheme ? Colors.black87 : Colors.white;
    final subTextColor = isWhiteTheme ? Colors.black54 : Colors.white70;

    String addressStr = 'Načítám adresu...';

    showModalBottomSheet(
      context: context,
      backgroundColor: bgColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            if (addressStr == 'Načítám adresu...') {
              _reverseGeocode(latLng.latitude, latLng.longitude).then((resolvedAddress) {
                if (context.mounted) {
                  setSheetState(() {
                    addressStr = resolvedAddress;
                  });
                }
              });
            }

            final now = DateTime.now();
            final difference = now.difference(lastUpdate);
            String timeAgoText = '';
            if (difference.inMinutes < 1) {
              timeAgoText = 'před chvílí';
            } else if (difference.inMinutes < 60) {
              timeAgoText = 'před ${difference.inMinutes} min';
            } else {
              timeAgoText = 'před ${difference.inHours} hod';
            }

            Widget avatarWidget;
            if (avatar.startsWith('base64:')) {
              avatarWidget = CircleAvatar(
                radius: 30,
                backgroundImage: MemoryImage(base64Decode(avatar.substring(7))),
              );
            } else {
              avatarWidget = CircleAvatar(
                radius: 30,
                backgroundImage: AssetImage('assets/images/$avatar.png'),
              );
            }

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 5,
                        decoration: BoxDecoration(
                          color: isWhiteTheme ? Colors.black12 : Colors.white24,
                          borderRadius: BorderRadius.circular(2.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isWhiteTheme ? Colors.grey.shade300 : Colors.white24,
                              width: 2,
                            ),
                          ),
                          child: avatarWidget,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                username,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.access_time_rounded,
                                    size: 14,
                                    color: Colors.greenAccent.shade700,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Aktivní $timeAgoText',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.greenAccent.shade700,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isWhiteTheme ? Colors.grey.shade100 : const Color(0xFF263238),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.location_on_rounded,
                                size: 16,
                                color: isWhiteTheme ? Colors.lightBlue : const Color(0xFFBFFF00),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Aktuální poloha',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: subTextColor,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            addressStr,
                            style: TextStyle(
                              fontSize: 14,
                              color: textColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => FriendProfileScreen(friendUid: friendUid),
                                ),
                              );
                            },
                            icon: const Icon(Icons.person_search_rounded),
                            label: const Text('Zobrazit profil'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFBFFF00),
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded),
                          style: IconButton.styleFrom(
                            backgroundColor: isWhiteTheme ? Colors.grey.shade200 : Colors.white10,
                            foregroundColor: textColor,
                            padding: const EdgeInsets.all(14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _toggleLocationSharing() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final newShare = !_shareLocation;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('share_location', newShare);

    setState(() {
      _shareLocation = newShare;
    });

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'share_location': newShare,
      });

      if (newShare) {
        _startListeningToFriendsLocations();
        if (_lastPosition != null) {
          await _uploadMyLocation(_lastPosition!);
        }
      } else {
        _friendsLocationsSubscription?.cancel();
        _friendsLocationsSubscription = null;
        setState(() {
          _markers.removeWhere((m) => m.markerId.value.startsWith('friend_'));
        });
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'last_location': FieldValue.delete(),
          'last_location_time': FieldValue.delete(),
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newShare 
                ? 'Sdílení polohy zapnuto. Přátelé tě uvidí na své mapě.' 
                : 'Sdílení polohy vypnuto.'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chyba při změně sdílení polohy: $e')),
        );
      }
    }
  }

  Future<void> _uploadMyLocation(Position position) async {
    if (!_shareLocation) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final now = DateTime.now();
    if (_lastLocationShareTime != null && now.difference(_lastLocationShareTime!).inSeconds < 60) {
      return;
    }

    _lastLocationShareTime = now;

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'last_location': GeoPoint(position.latitude, position.longitude),
        'last_location_time': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  Future<void> _createAvatarIcon(String avatar) async {
    try {
      Uint8List bytes;
      if (avatar.startsWith('base64:')) {
        bytes = base64Decode(avatar.substring(7));
      } else {
        final ByteData data = await rootBundle.load('assets/images/$avatar.png');
        bytes = data.buffer.asUint8List();
      }
      final circularIcon = await _getCircularMarker(bytes, 120, Colors.lightBlue);
      if (!mounted) return;
      setState(() {
        _avatarIcon = circularIcon;
      });
    } catch (e) {
      debugPrint('Failed to create circular avatar icon: $e');
    }
  }

  Future<ui.Image> _loadUiImage(String assetPath) async {
    final ByteData data = await rootBundle.load(assetPath);
    final ui.Codec codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final ui.FrameInfo fi = await codec.getNextFrame();
    return fi.image;
  }

  Future<BitmapDescriptor> _getCircularMarker(Uint8List bytes, int size, Color borderColor) async {
    try {
      final ui.Codec codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: size,
        targetHeight: size,
      );
      final ui.FrameInfo fi = await codec.getNextFrame();
      final ui.Image image = fi.image;

      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder, Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()));
      final Paint paint = Paint()..isAntiAlias = true;

      final double radius = size / 2.0;

      // 1. Draw soft shadow
      canvas.drawCircle(
        Offset(radius, radius),
        radius - 2,
        Paint()
          ..color = Colors.black26
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );

      // 2. Draw solid border background
      canvas.drawCircle(
        Offset(radius, radius),
        radius - 2,
        Paint()
          ..color = borderColor
          ..style = PaintingStyle.fill,
      );

      // 3. Clip path to make the image circular inside the border
      final Path clipPath = Path()..addOval(Rect.fromCircle(center: Offset(radius, radius), radius: radius - 6));
      canvas.save();
      canvas.clipPath(clipPath);

      // 4. Draw image inside clipped area
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        Rect.fromLTWH(6, 6, size.toDouble() - 12, size.toDouble() - 12),
        paint,
      );
      
      canvas.restore();

      final ui.Picture picture = recorder.endRecording();
      final ui.Image markerImage = await picture.toImage(size, size);
      final ByteData? byteData = await markerImage.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('Failed to serialize image');
      
      // Determine device pixel ratio for correct scaling on high-res displays
      double pixelRatio = 2.0;
      if (mounted) {
        try {
          pixelRatio = MediaQuery.of(context).devicePixelRatio;
        } catch (_) {
          try {
            pixelRatio = ui.PlatformDispatcher.instance.views.first.devicePixelRatio;
          } catch (_) {}
        }
      } else {
        try {
          pixelRatio = ui.PlatformDispatcher.instance.views.first.devicePixelRatio;
        } catch (_) {}
      }

      return BitmapDescriptor.bytes(
        byteData.buffer.asUint8List(),
        imagePixelRatio: pixelRatio,
      );
    } catch (e) {
      debugPrint('Error creating circular marker: $e');
      // Fallback
      return BitmapDescriptor.defaultMarker;
    }
  }

  Future<void> _setupMap() async {
    final initialPosition = await _locationService.getCurrentLocation();
    if (initialPosition != null) {
      _initialPosition = initialPosition;
      if (mounted) {
        _polylineCoordinates.add(
          LatLng(initialPosition.latitude, initialPosition.longitude),
        );
        _addMarker(initialPosition);
        _updatePolyline();
      }
    }
    // Checkpoints list intentionally empty after cleanup
    _addAllCheckpointMarkers();
  }

  void _checkCheckpointProximity(Position userPosition) {
    for (final checkpoint in _checkpoints) {
      final id = checkpoint['id'] as String;
      if (_reachedCheckpoints.contains(id)) continue;

      final checkpointPosition = checkpoint['position'] as LatLng;
      final distance = Geolocator.distanceBetween(
        userPosition.latitude,
        userPosition.longitude,
        checkpointPosition.latitude,
        checkpointPosition.longitude,
      );

      if (distance < 20.0) {
        setState(() {
          _reachedCheckpoints.add(id);
        });
        _saveCheckpointAchievement(id);
        _updateCheckpointMarker(id, reached: true);
        _triggerCheckpointCelebration();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('🎉 ${checkpoint['title']} dosažen! Úspěch odemčen!'),
              duration: const Duration(seconds: 3),
              backgroundColor: Colors.lime,
            ),
          );
        }
        _checkLevelUp();
      }
    }
  }

  void _triggerCheckpointCelebration() {
    HapticFeedback.mediumImpact();
  }

  void _checkLevelUp() {
    if (_checkpoints.isNotEmpty && _reachedCheckpoints.length == _checkpoints.length) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Všechny body dokončeny! Skvělá práce.'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  LatLng _destinationFromDistanceBearing(LatLng start, double distanceKm, double bearingDegrees) {
    const earthRadiusKm = 6371.0;
    final bearing = bearingDegrees * pi / 180.0;
    final lat1 = start.latitude * pi / 180.0;
    final lon1 = start.longitude * pi / 180.0;
    final angularDistance = distanceKm / earthRadiusKm;

    final lat2 = asin(sin(lat1) * cos(angularDistance) + cos(lat1) * sin(angularDistance) * cos(bearing));
    final lon2 = lon1 + atan2(
      sin(bearing) * sin(angularDistance) * cos(lat1),
      cos(angularDistance) - sin(lat1) * sin(lat2),
    );

    return LatLng(lat2 * 180.0 / pi, lon2 * 180.0 / pi);
  }

  double _calculateRouteLength(List<LatLng> points) {
    double distance = 0.0;
    for (int i = 1; i < points.length; i++) {
      distance += Geolocator.distanceBetween(
        points[i - 1].latitude,
        points[i - 1].longitude,
        points[i].latitude,
        points[i].longitude,
      );
    }
    return distance / 1000.0;
  }

  int _calculateRouteEta(double distanceKm) {
    final speedKmH = _usingBike ? 15.0 : 5.0;
    return max(1, (distanceKm / speedKmH * 60).round());
  }

  double _calculateBearing(LatLng from, LatLng to) {
    final lat1 = from.latitude * pi / 180.0;
    final lon1 = from.longitude * pi / 180.0;
    final lat2 = to.latitude * pi / 180.0;
    final lon2 = to.longitude * pi / 180.0;
    
    final dLon = lon2 - lon1;
    final y = sin(dLon) * cos(lat2);
    final x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon);
    
    final radians = atan2(y, x);
    return (radians * 180.0 / pi + 360.0) % 360.0;
  }

  void _updateNavigationInstruction(LatLng currentPoint, int closestIndex) {
    if (_activeRoutePoints.isEmpty || closestIndex >= _activeRoutePoints.length - 1) {
      setState(() {
        _navigationInstruction = 'Jste v cíli!';
        _navigationIcon = Icons.stars;
      });
      return;
    }

    if (closestIndex + 2 >= _activeRoutePoints.length) {
      setState(() {
        _navigationInstruction = 'Cíl je blízko';
        _navigationIcon = Icons.flag;
      });
      return;
    }

    final p1 = _activeRoutePoints[closestIndex];
    final p2 = _activeRoutePoints[closestIndex + 1];
    final p3 = _activeRoutePoints[closestIndex + 2];

    final double b1 = _calculateBearing(p1, p2);
    final double b2 = _calculateBearing(p2, p3);

    double diff = b2 - b1;
    while (diff < -180) {
      diff += 360;
    }
    while (diff > 180) {
      diff -= 360;
    }

    String instr = 'Jděte rovně';
    IconData icon = Icons.arrow_upward;

    if (diff > 25 && diff <= 75) {
      instr = 'Zahněte mírně doprava';
      icon = Icons.turn_slight_right;
    } else if (diff > 75) {
      instr = 'Zahněte doprava';
      icon = Icons.turn_right;
    } else if (diff < -25 && diff >= -75) {
      instr = 'Zahněte mírně doleva';
      icon = Icons.turn_slight_left;
    } else if (diff < -75) {
      instr = 'Zahněte doleva';
      icon = Icons.turn_left;
    }

    final double distToTurn = Geolocator.distanceBetween(
      currentPoint.latitude,
      currentPoint.longitude,
      p2.latitude,
      p2.longitude,
    );

    if (distToTurn > 10) {
      instr = 'Za ${(distToTurn.toInt())} m: $instr';
    }

    setState(() {
      _navigationInstruction = instr;
      _navigationIcon = icon;
    });
  }

  int _findClosestRoutePointIndex(LatLng currentPos) {
    if (_activeRoutePoints.isEmpty) return 0;
    int closestIndex = 0;
    double minDistance = double.infinity;
    for (int i = 0; i < _activeRoutePoints.length; i++) {
      final d = Geolocator.distanceBetween(
        currentPos.latitude,
        currentPos.longitude,
        _activeRoutePoints[i].latitude,
        _activeRoutePoints[i].longitude,
      );
      if (d < minDistance) {
        minDistance = d;
        closestIndex = i;
      }
    }
    return closestIndex;
  }

  double _calculateRemainingDistance(LatLng currentPos, int closestIndex) {
    if (_activeRoutePoints.isEmpty) return 0.0;
    double distance = 0.0;
    
    if (closestIndex + 1 < _activeRoutePoints.length) {
      distance += Geolocator.distanceBetween(
        currentPos.latitude,
        currentPos.longitude,
        _activeRoutePoints[closestIndex + 1].latitude,
        _activeRoutePoints[closestIndex + 1].longitude,
      );
      
      for (int i = closestIndex + 1; i < _activeRoutePoints.length - 1; i++) {
        distance += Geolocator.distanceBetween(
          _activeRoutePoints[i].latitude,
          _activeRoutePoints[i].longitude,
          _activeRoutePoints[i + 1].latitude,
          _activeRoutePoints[i + 1].longitude,
        );
      }
    }
    
    return distance / 1000.0; // in km
  }

  Future<List<LatLng>> _fetchRouteGeometryFromOSRM(List<LatLng> coordinates, String profile) async {
    if (coordinates.length < 2) return [];
    final coordString = coordinates.map((point) => '${point.longitude},${point.latitude}').join(';');
    final uri = Uri.https('router.project-osrm.org', '/route/v1/$profile/$coordString', {
      'overview': 'full',
      'geometries': 'geojson',
    });
    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 12));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        if (body['code'] == 'Ok' && body['routes'] is List && body['routes'].isNotEmpty) {
          final route = (body['routes'] as List<dynamic>)[0] as Map<String, dynamic>;
          final geometry = route['geometry'] as Map<String, dynamic>?;
          if (geometry != null && geometry['coordinates'] is List) {
            return (geometry['coordinates'] as List<dynamic>)
                .whereType<List<dynamic>>()
                .map((coord) => LatLng(
                      (coord[1] as num).toDouble(),
                      (coord[0] as num).toDouble(),
                    ))
                .toList();
          }
        }
      }
    } catch (e) {
      debugPrint('OSRM route fetch error: $e');
    }
    return [];
  }

  Future<void> _selectRouteSuggestion(int index) async {
    if (index < 0 || index >= _routeSuggestions.length) return;
    final route = _routeSuggestions[index];
    final points = route['coordinates'] as List<LatLng>?;
    if (points == null || points.length < 2) return;

    final polyline = Polyline(
      polylineId: const PolylineId('active_route'),
      color: _usingBike ? Colors.blue : Colors.green,
      width: 5,
      points: points,
      geodesic: true,
    );

    setState(() {
      // plot route but don't start tracking until explicit START
      _routePlotted = true;
      _routeActive = false;
      _activeRoutePoints = points;
      _selectedRouteSuggestionIndex = index;
      _polylines.removeWhere((p) => p.polylineId.value == 'active_route');
      _polylines.add(polyline);
      _destinationPoint = points.last;
      _showRouteSuggestions = true;
      _taskCardExpanded = false; // collapse top card so map is more visible
    });

    final title = route['title'] as String? ?? 'Okruh v okolí';
    final distance = route['distance'] as double? ?? 0.0;
    final eta = route['eta'] as int? ?? 0;
    await _cacheActiveRoute(points, title, distance, eta);

    await _fetchElevationData(points).catchError((_) {});
  }

  Future<void> _generateNearbyRoutes() async {
    if (_lastPosition == null) return;
    final start = LatLng(_lastPosition!.latitude, _lastPosition!.longitude);
    final profile = _usingBike ? 'cycling' : 'foot';
    final minRange = _usingBike ? _bikeRangeMin : _walkRangeMin;
    final maxRange = _usingBike ? _bikeRangeMax : _walkRangeMax;
    setState(() {
      _isLoadingRoutes = true;
      _showRouteSuggestions = true;
      _routeSuggestions.clear();
      _routeActive = false;
      _polylines.removeWhere((p) => p.polylineId.value == 'active_route');
      _markers.removeWhere((m) => m.markerId.value.startsWith('route_'));
    });

    final routeNames = ['Lesní okruh', 'Říční cesta', 'Městský okruh', 'Zelená stezka', 'Vyhlídkový okruh'];
    final random = Random();
    
    final List<Future<List<LatLng>>> futures = [];
    final List<int> poiCounts = [];
    final List<String> names = [];

    for (int i = 0; i < 5; i++) {
      final distanceKm = minRange + random.nextDouble() * (maxRange - minRange);
      final bearing = random.nextDouble() * 360;
      // create a teardrop loop with 3 waypoints to form a smooth loop
      final d = distanceKm / 3.0;
      final wp1 = _destinationFromDistanceBearing(start, d, bearing - 25.0);
      final wp2 = _destinationFromDistanceBearing(start, d * 1.2, bearing);
      final wp3 = _destinationFromDistanceBearing(start, d, bearing + 25.0);
      
      futures.add(_fetchRouteGeometryFromOSRM([start, wp1, wp2, wp3, start], profile));
      poiCounts.add(random.nextInt(3) + 1);
      names.add(routeNames[i % routeNames.length]);
    }

    // Fetch all route geometries concurrently
    final results = await Future.wait(futures);
    final suggestions = <Map<String, dynamic>>[];

    for (int i = 0; i < results.length; i++) {
      final routePoints = results[i];
      if (routePoints.length < 2) continue;
      final actualDistance = _calculateRouteLength(routePoints);
      suggestions.add({
        'title': '${names[i]} ${actualDistance.toStringAsFixed(1)} km',
        'coordinates': routePoints,
        'distance': actualDistance,
        'eta': _calculateRouteEta(actualDistance),
        'poi_count': poiCounts[i],
      });
      if (suggestions.length >= 4) break;
    }

    if (!mounted) return;
    setState(() {
      _routeSuggestions = suggestions;
      _selectedRouteSuggestionIndex = 0;
      _isLoadingRoutes = false;
    });

    if (_routeSuggestions.isNotEmpty) {
      await _selectRouteSuggestion(0);
    }
  }

  Future<void> _generateDestinationRoute(LatLng destination) async {
    if (_lastPosition == null) return;
    final start = LatLng(_lastPosition!.latitude, _lastPosition!.longitude);
    final profile = _usingBike ? 'cycling' : 'foot';
    final routePoints = await _fetchRouteGeometryFromOSRM([start, destination], profile);
    if (routePoints.isEmpty) {
      if (!mounted) return;
      final prefs = await SharedPreferences.getInstance();
      final hasActive = prefs.getBool('offline_route_active') ?? false;
      if (hasActive) {
        final confirmOffline = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Jste offline 📶'),
            content: const Text('Nepodařilo se připojit k serveru pro vyhledání trasy. Chcete načíst vaši naposledy uloženou trasu offline?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Zrušit'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Načíst offline'),
              ),
            ],
          ),
        );
        if (confirmOffline == true) {
          await _restoreActiveRoute();
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nepodařilo se načíst trasu. Zkontrolujte připojení.')),
        );
      }
      return;
    }

    final polyline = Polyline(
      polylineId: const PolylineId('active_route'),
      color: Colors.green,
      width: 5,
      points: routePoints,
      geodesic: true,
    );

    final distance = _calculateRouteLength(routePoints);
    final eta = _calculateRouteEta(distance);

    setState(() {
      // plot destination route but wait for explicit START
      _routePlotted = true;
      _routeActive = false;
      _activeRoutePoints = routePoints;
      _destinationPoint = destination;
      _polylines.removeWhere((p) => p.polylineId.value == 'active_route');
      _polylines.add(polyline);
      _showRouteSearch = false;
      _showRouteSuggestions = false;
      _routeSuggestions = [
        {
          'title': 'Cesta do cíle',
          'coordinates': routePoints,
          'distance': distance,
          'eta': eta,
          'poi_count': 0,
        }
      ];
      _taskCardExpanded = false;
    });

    await _cacheActiveRoute(routePoints, 'Cesta do cíle', distance, eta);

    await _fetchElevationData(routePoints).catchError((_) {});
  }

  void _cancelRoute() {
    setState(() {
      _routeActive = false;
      _routePlotted = false;
      _trackingEnabled = false;
      _destinationPoint = null;
      _showRouteSearch = false;
      _showRouteSuggestions = false;
      _routeSuggestions.clear();
      _polylines.removeWhere((p) => p.polylineId.value == 'active_route');
      _markers.removeWhere((m) => m.markerId.value.startsWith('route_'));
      _activeRouteGame = null;
      _gamePlayers.clear();
      _gameActiveAssignments.clear();
      _gamePlayerHistory.clear();
      _todayDistance = StepTrackerService().stepsNotifier.value * 0.75;
    });
    _clearCachedRoute();
    _saveActiveGameState();
  }

  Future<void> _saveRouteToCommunity() async {
    final title = _routeSuggestions.isNotEmpty ? _routeSuggestions.first['title'] as String : 'Neznámý okruh';
    final points = _activeRoutePoints;
    if (points.isEmpty) return;

    final String routeId = 'route_${points.first.latitude.toStringAsFixed(4)}_${points.first.longitude.toStringAsFixed(4)}_${points.last.latitude.toStringAsFixed(4)}_${points.last.longitude.toStringAsFixed(4)}';

    try {
      final docRef = FirebaseFirestore.instance.collection('community_routes').doc(routeId);
      final List<Map<String, double>> coords = points.map((p) => {'lat': p.latitude, 'lng': p.longitude}).toList();
      
      await docRef.set({
        'id': routeId,
        'title': title,
        'description': 'Uložený okruh o délce ${_routeSuggestions.first['distance'].toStringAsFixed(1)} km.',
        'points': coords,
        'start_lat': points.first.latitude,
        'start_lng': points.first.longitude,
        'distance': _routeSuggestions.first['distance'] as double,
        'eta': _routeSuggestions.first['eta'] as int,
        'ratings_count': 1,
        'ratings_sum': 5.0,
        'average_rating': 5.0,
        'is_top': false,
        'photos': [],
        'kct_color': _activeRouteKctColor,
        'cyklo_number': _activeRouteCykloNumber,
        'created_by': FirebaseAuth.instance.currentUser?.uid,
        'created_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Trasa byla úspěšně uložena do komunitních tras! 💾'),
            backgroundColor: Color(0xFF1B5E20),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chyba při ukládání trasy: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _showCancelRouteDialog() async {
    final isWhite = appThemeNotifier.value == 'white';
    final dialogBg = isWhite ? Colors.white : const Color(0xFF37474F);
    final textColor = isWhite ? Colors.black : Colors.white;
    final textSecondary = isWhite ? Colors.black54 : Colors.white70;
    final borderColor = isWhite ? Colors.grey.shade300 : Colors.white10;

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: dialogBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: borderColor),
        ),
        title: Text(
          'Zrušit trasu nebo okruh?',
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Opravdu si přejete zrušit tuto trasu nebo okruh? Můžete si ji/jej před zrušením uložit do komunitních okruhů.',
          style: TextStyle(color: textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'zrusit'),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Zrušit bez uložení'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'ulozit'),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFBFFF00)),
            child: const Text('Uložit a zrušit', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'storno'),
            child: Text('Zpět na trasu', style: TextStyle(color: textSecondary)),
          ),
        ],
      ),
    );

    if (result == 'zrusit') {
      _cancelRoute();
    } else if (result == 'ulozit') {
      await _saveRouteToCommunity();
      _cancelRoute();
    }
  }

  void _showActiveAssignmentsDialog() {
    final isWhite = appThemeNotifier.value == 'white';
    final dialogBg = isWhite ? Colors.white : const Color(0xFF37474F);
    final textColor = isWhite ? Colors.black : Colors.white;
    final textSecondary = isWhite ? Colors.black54 : Colors.white70;
    final borderColor = isWhite ? Colors.grey.shade300 : Colors.white10;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: dialogBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: borderColor),
        ),
        title: Text(
          '🎯 Aktivní úkoly na trase',
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ..._gameActiveAssignments.entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6.0),
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(color: textColor, fontSize: 14),
                    children: [
                      TextSpan(text: '${entry.key}: ', style: const TextStyle(fontWeight: FontWeight.bold)),
                      TextSpan(text: entry.value.title),
                    ],
                  ),
                ),
              );
            }).toList(),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() {
                  for (var entry in _gameActiveAssignments.entries) {
                    final list = _gamePlayerHistory[entry.key] ?? [];
                    list.add(entry.value.id);
                    _gamePlayerHistory[entry.key] = list;
                  }
                  _gameActiveAssignments.clear();
                });
                _saveActiveGameState();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Úkoly označeny za splněné! 🏆')),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFBFFF00),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Označit úkoly za splněné ✓', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Zavřít', style: TextStyle(color: textSecondary)),
          ),
        ],
      ),
    );
  }

  Future<void> _completeRoute() async {
    final title = _routeSuggestions.isNotEmpty ? _routeSuggestions.first['title'] as String? ?? 'Neznámá trasa' : 'Neznámá trasa';
    final distance = _routeSuggestions.isNotEmpty ? (_routeSuggestions.first['distance'] as num?)?.toDouble() ?? 0.0 : 0.0;

    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    final prefs = await SharedPreferences.getInstance();
    final key = 'daily_routes_$todayStr';
    final List<String> currentRoutes = prefs.getStringList(key) ?? [];
    currentRoutes.add('$title|$distance');
    await prefs.setStringList(key, currentRoutes);

    setState(() {
      _routeActive = false;
      _trackingEnabled = false;
      _routePlotted = false;
      _destinationPoint = null;
      _showRouteSearch = false;
      _showRouteSuggestions = false;
      _routeSuggestions.clear();
      _polylines.removeWhere((p) => p.polylineId.value == 'active_route');
      _markers.removeWhere((m) => m.markerId.value.startsWith('route_'));
      _activeRouteGame = null;
      _gamePlayers.clear();
      _gameActiveAssignments.clear();
      _gamePlayerHistory.clear();
      _todayDistance = StepTrackerService().stepsNotifier.value * 0.75;
    });
    
    await _clearCachedRoute();
    await _saveActiveGameState();

    if (mounted) {
      HapticFeedback.vibrate();
      _showRouteCompletionDialog();
    }
  }

  void _showRouteCompletionDialog() {
    double selectedRating = 5.0;
    XFile? selectedPhoto;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E24),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: const Text(
                '🎉 Trasa dokončena!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Skvělá práce! Jak se ti okruh líbil?',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  // Stars Row (1 to 5 with half-stars support)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      final starValue = index + 1.0;
                      IconData icon;
                      if (selectedRating >= starValue) {
                        icon = Icons.star;
                      } else if (selectedRating >= starValue - 0.5) {
                        icon = Icons.star_half;
                      } else {
                        icon = Icons.star_border;
                      }
                      return GestureDetector(
                        onTapDown: (details) {
                          final double tapX = details.localPosition.dx;
                          const double width = 32.0;
                          final double rating = starValue - (tapX < width / 2 ? 0.5 : 0.0);
                          setDialogState(() {
                            selectedRating = rating;
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: Icon(icon, color: Colors.amber, size: 36),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$selectedRating / 5.0',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 20),
                  // Photo selector
                  const Text(
                    'Přidej fotku z trasy pro ostatní:',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () async {
                      final ImagePicker picker = ImagePicker();
                      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
                      if (image != null) {
                        setDialogState(() {
                          selectedPhoto = image;
                        });
                      }
                    },
                    child: Container(
                      height: 100,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white24, style: BorderStyle.solid),
                      ),
                      child: selectedPhoto != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.file(
                                File(selectedPhoto!.path),
                                fit: BoxFit.cover,
                              ),
                            )
                          : const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_a_photo, color: Colors.white54, size: 28),
                                SizedBox(height: 6),
                                Text('Vybrat z galerie', style: TextStyle(color: Colors.white38, fontSize: 11)),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Podle pravidel hry nezískáváš za splnění okruhu žádné Limetky (ochrana proti zneužití).',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white38, fontSize: 10, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
              actions: [
                Center(
                  child: ElevatedButton(
                    onPressed: () async {
                      await _submitRouteRating(selectedRating, selectedPhoto);
                      Navigator.pop(context);
                      
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Děkujeme za hodnocení trasy! 🎉'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFBFFF00),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    ),
                    child: const Text('Odeslat a dokončit', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _submitRouteRating(double rating, XFile? photo) async {
    final title = _routeSuggestions.isNotEmpty ? _routeSuggestions.first['title'] as String : 'Neznámý okruh';
    final points = _activeRoutePoints;
    if (points.isEmpty) return;
    
    final String routeId = 'route_${points.first.latitude.toStringAsFixed(4)}_${points.first.longitude.toStringAsFixed(4)}_${points.last.latitude.toStringAsFixed(4)}_${points.last.longitude.toStringAsFixed(4)}';

    try {
      String? photoUrl;
      if (photo != null) {
        photoUrl = 'https://picsum.photos/300/200';
      }

      final docRef = FirebaseFirestore.instance.collection('community_routes').doc(routeId);
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) {
          final List<Map<String, double>> coords = points.map((p) => {'lat': p.latitude, 'lng': p.longitude}).toList();
          transaction.set(docRef, {
            'id': routeId,
            'title': title,
            'description': 'Komunitní okruh o délce ${_routeSuggestions.first['distance'].toStringAsFixed(1)} km.',
            'points': coords,
            'start_lat': points.first.latitude,
            'start_lng': points.first.longitude,
            'distance': _routeSuggestions.first['distance'] as double,
            'eta': _routeSuggestions.first['eta'] as int,
            'ratings_count': 1,
            'ratings_sum': rating,
            'average_rating': rating,
            'is_top': false,
            'photos': photoUrl != null ? [photoUrl] : [],
            'kct_color': _activeRouteKctColor,
            'cyklo_number': _activeRouteCykloNumber,
          });
        } else {
          final data = snapshot.data() ?? {};
          final int count = (data['ratings_count'] as num?)?.toInt() ?? 0;
          final double sum = (data['ratings_sum'] as num?)?.toDouble() ?? 0.0;
          final List<dynamic> photos = data['photos'] as List<dynamic>? ?? [];
          
          final newCount = count + 1;
          final newSum = sum + rating;
          final double newAvg = newSum / newCount;
          
          final updates = {
            'ratings_count': newCount,
            'ratings_sum': newSum,
            'average_rating': newAvg,
            'is_top': newCount >= 10 && newAvg >= 4.0,
          };
          
          if (photoUrl != null) {
            photos.add(photoUrl);
            updates['photos'] = photos;
          }
          
          transaction.update(docRef, updates);
        }
      });
    } catch (e) {
      debugPrint('Error saving route rating: $e');
    }
  }

  Future<void> _toggleMapType() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (_mapType == MapType.normal) {
        _mapType = MapType.terrain;
        prefs.setString('preferred_map_type', 'terrain');
      } else if (_mapType == MapType.terrain) {
        _mapType = MapType.satellite;
        prefs.setString('preferred_map_type', 'satellite');
      } else if (_mapType == MapType.satellite) {
        _mapType = MapType.hybrid;
        prefs.setString('preferred_map_type', 'hybrid');
      } else {
        _mapType = MapType.normal;
        prefs.setString('preferred_map_type', 'normal');
      }
    });
  }

  Future<void> _fetchPartners() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('partners').get();
      final List<Map<String, dynamic>> temp = [];
      for (var doc in snapshot.docs) {
        final data = doc.data();
        data['id'] = doc.id;
        temp.add(data);
      }
      setState(() {
        _partners = temp;
      });
      _updatePartnerMarkers();
    } catch (_) {
      final LatLng center = _lastPosition != null
          ? LatLng(_lastPosition!.latitude, _lastPosition!.longitude)
          : const LatLng(50.0755, 14.4378);
      setState(() {
        _partners = [
          {
            'id': 'partner_kavarna',
            'name': 'Kavárna Pod Dubem ☕',
            'type': 'cafe',
            'lat': center.latitude + 0.002,
            'lng': center.longitude + 0.002,
            'promo_text': 'Zastav se u nás na teplou kávu a koláč! Prokaž se touto kartou a získej 10% slevu na espresso.',
            'coupon_code': 'KAVA10',
            'opening_hours': '8:00 - 20:00',
            'verification_qr_token': 'partner_kavarna_token_123',
          },
          {
            'id': 'partner_pivovar',
            'name': 'Pivovar U Chodce 🍺',
            'type': 'brewery',
            'lat': center.latitude - 0.003,
            'lng': center.longitude - 0.003,
            'promo_text': 'Výborné točené pivo z lokálních chmelů. Ukaž kupón a získej 15% slevu na první pivo!',
            'coupon_code': 'PIVO15',
            'opening_hours': '11:00 - 22:00',
            'verification_qr_token': 'partner_pivovar_token_456',
          }
        ];
      });
      _updatePartnerMarkers();
    }
  }

  void _updatePartnerMarkers() {
    setState(() {
      _markers.removeWhere((m) => m.markerId.value.startsWith('partner_'));

      for (var partner in _partners) {
        final type = partner['type'] as String? ?? 'cafe';
        final double hue = type == 'brewery' ? BitmapDescriptor.hueOrange : BitmapDescriptor.hueRose;
        
        _markers.add(Marker(
          markerId: MarkerId('partner_${partner['id']}'),
          position: LatLng(partner['lat'] as double, partner['lng'] as double),
          infoWindow: InfoWindow(
            title: partner['name'] as String? ?? '',
            snippet: partner['opening_hours'] as String? ?? '',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(hue),
        ));
      }
    });
  }

  void _checkPartnerProximity(LatLng userPos) {
    for (var partner in _partners) {
      final double dist = _distanceBetween(userPos, LatLng(partner['lat'] as double, partner['lng'] as double)) * 1000;
      final String id = partner['id'] as String;
      
      if (dist < 50.0 && !_alertedPartnerIds.contains(id)) {
        _alertedPartnerIds.add(id);
        HapticFeedback.vibrate();
        _showPartnerCouponBottomSheet(partner);
      }
    }
  }

  double _distanceBetween(LatLng p1, LatLng p2) {
    const double R = 6371.0;
    final double dLat = (p2.latitude - p1.latitude) * pi / 180.0;
    final double dLon = (p2.longitude - p1.longitude) * pi / 180.0;
    
    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(p1.latitude * pi / 180.0) * cos(p2.latitude * pi / 180.0) *
        sin(dLon / 2) * sin(dLon / 2);
        
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  void _showPartnerCouponBottomSheet(Map<String, dynamic> partner) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E24),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) {
        final String type = partner['type'] as String? ?? 'cafe';
        final IconData icon = type == 'brewery' ? Icons.sports_bar : Icons.local_cafe;
        final Color color = type == 'brewery' ? Colors.amber : Colors.brown.shade300;

        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: color.withOpacity(0.2),
                    child: Icon(icon, color: color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          partner['name'] as String? ?? '',
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Otevírací doba: ${partner['opening_hours'] as String? ?? ''}',
                          style: const TextStyle(color: Colors.white38, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Sponzorská nabídka:',
                style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                partner['promo_text'] as String? ?? '',
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('KÓD KUPÓNU:', style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
                    Text(
                      partner['coupon_code'] as String? ?? '',
                      style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () => _openQrScanner(partner),
                  icon: const Icon(Icons.qr_code_scanner, color: Colors.black),
                  label: const Text('Získat 3 Limetky (Ověřit na pokladně)', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFBFFF00),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  void _openQrScanner(Map<String, dynamic> partner) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('Naskenujte QR kód u pokladny', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 280,
            height: 280,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: MobileScanner(
                onDetect: (capture) async {
                  final List<Barcode> barcodes = capture.barcodes;
                  if (barcodes.isNotEmpty) {
                    final String? codeVal = barcodes.first.rawValue;
                    final String expectedToken = partner['verification_qr_token'] as String;
                    
                    if (codeVal == expectedToken) {
                      Navigator.pop(context);
                      Navigator.pop(context);
                      
                      setState(() {
                        _limetkyBalance += 3;
                      });
                      await _savePersistentData();
                      
                      final todayStr = DateTime.now().toIso8601String().substring(0, 10);
                      final prefs = await SharedPreferences.getInstance();
                      List<String> list = prefs.getStringList('daily_achievements_$todayStr') ?? [];
                      final achName = 'Návštěva: ${partner['name']}';
                      if (!list.contains(achName)) {
                        list.add(achName);
                        await prefs.setStringList('daily_achievements_$todayStr', list);
                      }
                      
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Kód úspěšně ověřen! Získal jsi 3 Limetky 🍋 a odznak!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Neplatný QR kód pro tohoto partnera.'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Zrušit', style: TextStyle(color: Colors.white70)),
            ),
            if (kDebugMode)
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  Navigator.pop(context);
                  
                  setState(() {
                    _limetkyBalance += 3;
                  });
                  await _savePersistentData();

                  final todayStr = DateTime.now().toIso8601String().substring(0, 10);
                  final prefs = await SharedPreferences.getInstance();
                  List<String> list = prefs.getStringList('daily_achievements_$todayStr') ?? [];
                  final achName = 'Návštěva: ${partner['name']}';
                  if (!list.contains(achName)) {
                    list.add(achName);
                    await prefs.setStringList('daily_achievements_$todayStr', list);
                  }

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Simulované ověření! Získal jsi 3 Limetky 🍋 a odznak!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
                child: const Text('Simulovat (Debug)', style: TextStyle(color: Colors.orange)),
              ),
          ],
        );
      },
    );
  }

  void _showSearchCommunityRoutesDialog() {
    LatLng currentPos = _lastPosition != null
        ? LatLng(_lastPosition!.latitude, _lastPosition!.longitude)
        : const LatLng(50.0755, 14.4378);

    showDialog(
      context: context,
      builder: (context) {
        double tempWalkLength = _searchWalkLength;
        double tempDrivingRadius = _searchDrivingRadius.clamp(1.0, 50.0);
        bool isSearching = false;
        List<Map<String, dynamic>> results = [];

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E24),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: const Row(
                children: [
                  Icon(Icons.stars, color: Colors.amber),
                  SizedBox(width: 8),
                  Text('Nejlepší komunitní okruhy', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: isSearching
                    ? const SizedBox(
                        height: 200,
                        child: Center(child: CircularProgressIndicator(color: Colors.lime)),
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Vzdálenost k začátku trasy: ${tempDrivingRadius.round()} km',
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          Slider(
                            value: tempDrivingRadius,
                            min: 1.0,
                            max: 50.0,
                            divisions: 49,
                            activeColor: Colors.lime,
                            inactiveColor: Colors.white24,
                            onChanged: (val) {
                              setDialogState(() {
                                tempDrivingRadius = val;
                              });
                            },
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Požadovaná délka okruhu: ${tempWalkLength.round()} km',
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          Slider(
                            value: tempWalkLength,
                            min: 2.0,
                            max: 30.0,
                            divisions: 28,
                            activeColor: Colors.lightBlueAccent,
                            inactiveColor: Colors.white24,
                            onChanged: (val) {
                              setDialogState(() {
                                tempWalkLength = val;
                              });
                            },
                          ),
                          const SizedBox(height: 16),
                          if (results.isEmpty)
                            const Center(
                              child: Text(
                                'Nastavte filtry a vyhledejte doporučené okruhy.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.white38, fontSize: 12),
                              ),
                            )
                          else ...[
                            const Text(
                              'Nalezené top okruhy:',
                              style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            SizedBox(
                              height: 180,
                              child: ListView.builder(
                                shrinkWrap: true,
                                itemCount: results.length,
                                itemBuilder: (context, idx) {
                                  final route = results[idx];
                                  final double distFromUser = route['distFromUser'] as double;
                                  final double distance = route['distance'] as double;
                                  final double rating = route['average_rating'] as double? ?? 0.0;
                                  
                                  return Card(
                                    color: Colors.white.withOpacity(0.08),
                                    margin: const EdgeInsets.only(bottom: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    child: ListTile(
                                      title: Text(
                                        route['title'] as String? ?? 'Okruh',
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                      subtitle: Text(
                                        'Délka: ${distance.toStringAsFixed(1)} km • Od tebe: ${distFromUser.toStringAsFixed(1)} km',
                                        style: const TextStyle(color: Colors.white54, fontSize: 11),
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.star, color: Colors.amber, size: 16),
                                          const SizedBox(width: 2),
                                          Text(
                                            rating.toStringAsFixed(1),
                                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                          ),
                                        ],
                                      ),
                                      onTap: () {
                                        Navigator.pop(context);
                                        _loadSelectedCommunityRoute(route);
                                      },
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ],
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Zavřít', style: TextStyle(color: Colors.white70)),
                ),
                if (!isSearching)
                  ElevatedButton(
                    onPressed: () async {
                      setDialogState(() {
                        isSearching = true;
                      });

                      _searchWalkLength = tempWalkLength;
                      _searchDrivingRadius = tempDrivingRadius;

                      final List<Map<String, dynamic>> found = [];
                      try {
                        final snapshot = await FirebaseFirestore.instance
                            .collection('community_routes')
                            .where('is_top', isEqualTo: true)
                            .get();
                            
                        for (var doc in snapshot.docs) {
                          final data = doc.data();
                          final double startLat = (data['start_lat'] as num).toDouble();
                          final double startLng = (data['start_lng'] as num).toDouble();
                          final double dist = (data['distance'] as num).toDouble();
                          
                          final double distFromUser = Geolocator.distanceBetween(
                            currentPos.latitude,
                            currentPos.longitude,
                            startLat,
                            startLng,
                          ) / 1000.0;

                          if (distFromUser <= tempDrivingRadius && (dist - tempWalkLength).abs() <= 3.0) {
                            data['distFromUser'] = distFromUser;
                            found.add(data);
                          }
                        }
                      } catch (e) {
                        debugPrint('Query top routes error: $e');
                      }

                      if (found.isEmpty) {
                        found.add({
                          'id': 'mock_top_route',
                          'title': 'Krásný lesní okruh Podlesí 🌲',
                          'description': 'Velmi oblíbený komunitní okruh s minimem zpevněných cest a krásným výhledem.',
                          'start_lat': currentPos.latitude + 0.005,
                          'start_lng': currentPos.longitude + 0.005,
                          'distance': tempWalkLength,
                          'eta': (tempWalkLength * 12).round(),
                          'average_rating': 4.8,
                          'ratings_count': 12,
                          'points': [
                            {'lat': currentPos.latitude, 'lng': currentPos.longitude},
                            {'lat': currentPos.latitude + 0.005, 'lng': currentPos.longitude + 0.005},
                            {'lat': currentPos.latitude + 0.008, 'lng': currentPos.longitude + 0.002},
                            {'lat': currentPos.latitude, 'lng': currentPos.longitude},
                          ],
                          'distFromUser': 0.8,
                        });
                      }

                      found.sort((a, b) => (b['average_rating'] as num).compareTo(a['average_rating'] as num));

                      setDialogState(() {
                        results = found;
                        isSearching = false;
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFBFFF00),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Vyhledat', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  void _loadSelectedCommunityRoute(Map<String, dynamic> route) {
    final rawPoints = route['points'] as List<dynamic>;
    final List<LatLng> points = rawPoints
        .map((p) => LatLng((p['lat'] as num).toDouble(), (p['lng'] as num).toDouble()))
        .toList();

    final title = route['title'] as String;
    final distance = (route['distance'] as num).toDouble();
    final eta = (route['eta'] as num).toInt();

    final polyline = Polyline(
      polylineId: const PolylineId('active_route'),
      color: _usingBike ? Colors.blue : Colors.green,
      width: 5,
      points: points,
      geodesic: true,
    );

    setState(() {
      _activeRoutePoints = points;
      _routePlotted = true;
      _routeActive = false;
      _polylines.removeWhere((p) => p.polylineId.value == 'active_route');
      _polylines.add(polyline);
      _destinationPoint = points.last;
      
      _routeSuggestions = [
        {
          'title': title,
          'coordinates': points,
          'distance': distance,
          'eta': eta,
          'poi_count': 0,
        }
      ];
      _selectedRouteSuggestionIndex = 0;
      _showRouteSuggestions = false;
      _showRouteSearch = false;
      _taskCardExpanded = false;
      
      _activeRouteKctColor = route['kct_color'] as String?;
      _activeRouteCykloNumber = route['cyklo_number'] as String?;
      _activeRouteTriviaQuestion = route['trivia_question'] as String?;
      _activeRouteTriviaAnswer = route['trivia_answer'] as String?;
    });

    _fitMapBounds(points);
  }

  void _startRoute() {
    double initialRemaining = 0.0;
    int initialEta = 0;
    if (_activeRoutePoints.isNotEmpty) {
      LatLng currentPos = _lastPosition != null
          ? LatLng(_lastPosition!.latitude, _lastPosition!.longitude)
          : _activeRoutePoints.first;
      initialRemaining = _calculateRemainingDistance(currentPos, 0);
      initialEta = _calculateRouteEta(initialRemaining);
    }

    AntiCheatService().reset();

    setState(() {
      _trackingEnabled = true;
      _routeActive = true;
      _routePlotted = false;
      _closestWaypointIndex = 0;
      _remainingDistance = initialRemaining;
      _remainingEta = initialEta;
    });

    if (_lastPosition != null && _activeRoutePoints.isNotEmpty) {
      final currentPos = LatLng(_lastPosition!.latitude, _lastPosition!.longitude);
      final closestIndex = _findClosestRoutePointIndex(currentPos);
      _updateNavigationInstruction(currentPos, closestIndex);
      final nextWp = _activeRoutePoints[min(closestIndex + 1, _activeRoutePoints.length - 1)];
      final bearing = _calculateBearing(currentPos, nextWp);
      
      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: currentPos,
            zoom: 17.5,
            bearing: bearing,
            tilt: 45.0,
          ),
        ),
      );
    }
  }

  Widget _buildRouteInfoChip(String text, {Color? color, Color? textColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color ?? Colors.lightBlue.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 12, color: textColor ?? Colors.black87, fontWeight: textColor != null ? FontWeight.bold : FontWeight.normal),
      ),
    );
  }

  Future<void> _saveCheckpointAchievement(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('achievement_${id}_reached', true);

    final names = {
      'checkpoint_1': 'Severovýchodní checkpoint',
      'checkpoint_2': 'Jihovýchodní checkpoint',
      'checkpoint_3': 'Jihozápadní checkpoint',
      'checkpoint_4': 'Severozápadní checkpoint',
      'checkpoint_5': 'Východní checkpoint',
    };
    final title = names[id] ?? 'Checkpoint';
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    List<String> list = prefs.getStringList('daily_achievements_$todayStr') ?? [];
    if (!list.contains(title)) {
      list.add(title);
      await prefs.setStringList('daily_achievements_$todayStr', list);
    }
  }


  Future<void> _fetchElevationData(List<LatLng> routePoints) async {
    if (routePoints.isEmpty) return;

    try {
      final path = routePoints.map((p) => '${p.latitude},${p.longitude}').join('|');
      final uri = Uri.https('maps.googleapis.com', '/maps/api/elevation/json', {
        'locations': path,
        'key': _googleApiKey,
      });
      
      final response = await http.get(uri).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Elevation API timeout'),
      );
      
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        if (body['status'] == 'OK' && body['results'] is List) {
          final results = body['results'] as List<dynamic>;
          if (results.isNotEmpty) {
            double previousElevation = (results.first['elevation'] as num).toDouble();
            double elevationGain = 0.0;
            for (final result in results.skip(1)) {
              final elevation = (result['elevation'] as num).toDouble();
              if (elevation > previousElevation) {
                elevationGain += elevation - previousElevation;
              }
              previousElevation = elevation;
            }
            final extraLimetkas = (elevationGain / 10).floor();
            if (extraLimetkas > 0) {
              _limetkyBalance += extraLimetkas;
              await _savePersistentData();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Bonus za převýšení: +$extraLimetkas Limetků!')),
                );
              }
            }
          }
        } else {
          debugPrint('Elevation API error: ${body['status']}');
        }
      } else {
        debugPrint('Elevation API HTTP error: ${response.statusCode}');
      }
    } on SocketException catch (e) {
      debugPrint('Network error fetching elevation: $e');
    } on TimeoutException catch (e) {
      debugPrint('Timeout fetching elevation: $e');
    } catch (e) {
      debugPrint('Unexpected error fetching elevation: $e');
    }
  }


  Future<void> _fetchPlacePredictions(String input) async {
    if (input.isEmpty || input.trim().length < 2) {
      setState(() {
        _placePredictions = [];
        _showSuggestions = false;
      });
      return;
    }

    try {
      final uri = Uri.https('maps.googleapis.com', '/maps/api/place/autocomplete/json', {
        'input': input,
        'components': 'country:cz',
        'language': 'cs',
        'key': _googleApiKey,
      });
      final response = await http.get(uri).timeout(
        const Duration(seconds: 8),
        onTimeout: () => throw Exception('Place Autocomplete API timeout'),
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        if (body['status'] == 'OK' && body['predictions'] is List) {
          setState(() {
            _placePredictions = (body['predictions'] as List<dynamic>)
                .whereType<Map<String, dynamic>>()
                .map(PlacePrediction.fromJson)
                .toList();
            _showSuggestions = true;
          });
          return;
        }
      }
    } on SocketException catch (e) {
      debugPrint('Network error fetching place predictions: $e');
    } on TimeoutException catch (e) {
      debugPrint('Timeout fetching place predictions: $e');
    } catch (e) {
      debugPrint('Place Autocomplete API error: $e');
    }

    setState(() {
      _placePredictions = [];
      _showSuggestions = false;
    });
  }

  Future<void> _selectPlace(PlacePrediction prediction) async {
    try {
      final uri = Uri.https('maps.googleapis.com', '/maps/api/place/details/json', {
        'place_id': prediction.placeId,
        'fields': 'formatted_address,geometry',
        'language': 'cs',
        'key': _googleApiKey,
      });
      final response = await http.get(uri).timeout(
        const Duration(seconds: 8),
        onTimeout: () => throw Exception('Place Details API timeout'),
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        if (body['status'] == 'OK' && body['result'] is Map<String, dynamic>) {
          final place = body['result'] as Map<String, dynamic>;
          final geometry = place['geometry'] as Map<String, dynamic>?;
          final location = geometry?['location'] as Map<String, dynamic>?;
          if (location != null) {
            final lat = (location['lat'] as num).toDouble();
            final lng = (location['lng'] as num).toDouble();
            final latLng = LatLng(lat, lng);
            if (!mounted) return;
            setState(() {
              _destinationController.text = place['formatted_address'] as String? ?? prediction.description;
              _showSuggestions = false;
              _showRouteSearch = false;
            });
            _generateDestinationRoute(latLng);
            FocusScope.of(context).unfocus();
            return;
          }
        }
      }
    } on SocketException catch (e) {
      debugPrint('Network error fetching place details: $e');
    } on TimeoutException catch (e) {
      debugPrint('Timeout fetching place details: $e');
    } catch (e) {
      debugPrint('Place Details API error: $e');
    }
  }

  Future<void> _snapBreadcrumbsToRoads() async {
    if (_breadcrumbsCoordinates.length < 2) return;

    try {
      final path = _breadcrumbsCoordinates
          .map((p) => '${p.latitude},${p.longitude}')
          .join('|');
      final uri = Uri.https('roads.googleapis.com', '/v1/snapToRoads', {
        'path': path,
        'interpolate': 'true',
        'key': _googleApiKey,
      });
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        if (body['snappedPoints'] is List) {
          final snappedPoints = (body['snappedPoints'] as List<dynamic>)
              .map((point) {
                final location = point['location'] as Map<String, dynamic>;
                return LatLng(
                  (location['latitude'] as num).toDouble(),
                  (location['longitude'] as num).toDouble(),
                );
              })
              .toList();
          if (snappedPoints.isNotEmpty && mounted) {
            setState(() {
              _breadcrumbsCoordinates
                ..clear()
                ..addAll(snappedPoints);
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Snap to Roads API error: $e');
    }
  }

  void _updateCheckpointMarker(String checkpointId, {required bool reached}) {
    final markerId = MarkerId(checkpointId);
    final existingMarker = _markers.firstWhere(
      (marker) => marker.markerId == markerId,
      orElse: () => const Marker(markerId: MarkerId('')),
    );

    if (existingMarker.markerId.value.isNotEmpty) {
      final updatedMarker = existingMarker.copyWith(
        iconParam: reached
            ? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen)
            : BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow),
      );
      setState(() {
        _markers.removeWhere((marker) => marker.markerId == markerId);
        _markers.add(updatedMarker);
      });
    }
  }

  void _addAllCheckpointMarkers() {
    for (final checkpoint in _checkpoints) {
      final id = checkpoint['id'] as String;
      final position = checkpoint['position'] as LatLng;
      final title = checkpoint['title'] as String;
      final isReached = _reachedCheckpoints.contains(id);
      final marker = Marker(
        markerId: MarkerId(id),
        position: position,
        infoWindow: InfoWindow(title: title),
        icon: isReached
            ? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen)
            : BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow),
      );
      setState(() {
        _markers.add(marker);
      });
    }
  }

  void _addMarker(Position position) {
    final userMarkerId = const MarkerId('user_location');
    final userPosition = LatLng(position.latitude, position.longitude);
    final marker = Marker(
      markerId: userMarkerId,
      position: userPosition,
      rotation: position.heading,
      anchor: const Offset(0.5, 0.5),
      icon: _avatarIcon ?? BitmapDescriptor.defaultMarker,
      infoWindow: const InfoWindow(title: 'Vaše poloha'),
    );
    setState(() {
      _markers.removeWhere((m) => m.markerId == userMarkerId);
      _markers.add(marker);
    });

    // Add companion marker if active
    if (_activeCompanionId != null && _companionIcon != null) {
      final companionMarkerId = const MarkerId('companion_location');
      final compPosition = LatLng(position.latitude + 0.00006, position.longitude + 0.00006);
      final String compName = _activeCompanionId == 'bear' ? 'Medvěd' :
                              _activeCompanionId == 'fox' ? 'Liška' :
                              _activeCompanionId == 'wolf' ? 'Vlk' : 'Jelen';
      final compMarker = Marker(
        markerId: companionMarkerId,
        position: compPosition,
        rotation: position.heading,
        anchor: const Offset(0.5, 0.5),
        icon: _companionIcon!,
        infoWindow: InfoWindow(
          title: compName,
          snippet: 'Tvůj společník',
        ),
      );
      setState(() {
        _markers.removeWhere((m) => m.markerId == companionMarkerId);
        _markers.add(compMarker);
      });
    } else {
      setState(() {
        _markers.removeWhere((m) => m.markerId == const MarkerId('companion_location'));
      });
    }
  }

  double _calculatePolylineDistance() {
    double totalDistance = 0.0;
    for (int i = 1; i < _polylineCoordinates.length; i++) {
      totalDistance += Geolocator.distanceBetween(
        _polylineCoordinates[i - 1].latitude,
        _polylineCoordinates[i - 1].longitude,
        _polylineCoordinates[i].latitude,
        _polylineCoordinates[i].longitude,
      );
    }
    return totalDistance;
  }

  void _updatePolyline() {
    if (_polylineCoordinates.length < 2) return;
    const polylineId = PolylineId('user_path');
    final polyline = Polyline(
      polylineId: polylineId,
      color: Colors.lime,
      width: 5,
      points: _polylineCoordinates,
      geodesic: true,
    );
    setState(() {
      _polylines.removeWhere((p) => p.polylineId == polylineId);
      _polylines.add(polyline);
    });
  }

  void _updateBreadcrumbsPolyline() {
    if (_breadcrumbsCoordinates.length < 2) return;
    const polylineId = PolylineId('breadcrumbs');
    final polyline = Polyline(
      polylineId: polylineId,
      color: const Color(0xFFBFFF00),
      width: 3,
      points: _breadcrumbsCoordinates,
      geodesic: true,
    );
    setState(() {
      _polylines.removeWhere((p) => p.polylineId == polylineId);
      _polylines.add(polyline);
    });
  }

  Future<void> _applyMapStyle(String style) async {
    if (_mapController == null) return;
    if (style == 'default') {
      await _mapController!.setMapStyle(null);
    } else {
      try {
        final file = style == 'light' ? 'assets/map_style_light.json' : 'assets/map_style_dark.json';
        final styleJson = await rootBundle.loadString(file);
        await _mapController!.setMapStyle(styleJson);
      } catch (e) {
        debugPrint('Error loading map style $style: $e');
      }
    }
  }

  Future<void> _toggleMapStyle() async {
    if (!_isPremium) {
      _showPaywall();
      return;
    }
    
    String nextStyle;
    if (_currentMapStyle == 'default') {
      nextStyle = 'light';
    } else if (_currentMapStyle == 'light') {
      nextStyle = 'dark';
    } else {
      nextStyle = 'default';
    }
    
    setState(() {
      _currentMapStyle = nextStyle;
    });
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('map_style', nextStyle);
    await _applyMapStyle(nextStyle);
    
    final label = nextStyle == 'default' ? 'Výchozí' : nextStyle == 'light' ? 'Světlý' : 'Tmavý';
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Styl mapy změněn na: $label'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    if (_currentMapStyle != 'default') {
      _applyMapStyle(_currentMapStyle);
    }
    
    // If we already obtained an initial location, center the camera immediately
    if (_initialPosition != null) {
      try {
        final cameraPosition = CameraPosition(
          target: LatLng(_initialPosition!.latitude, _initialPosition!.longitude),
          zoom: 16.0,
        );
        _mapController?.animateCamera(CameraUpdate.newCameraPosition(cameraPosition));
      } catch (_) {}
    }

    _positionSubscription = _positionStream.listen((position) async {
      if (!mounted) return;
      final newPoint = LatLng(position.latitude, position.longitude);

      // Sync position to Firestore for friends location map tracking
      _uploadMyLocation(position);

      // Update streak
      final today = DateTime.now();
      if (_lastActivityDate == null || !_isSameDay(_lastActivityDate!, today)) {
        if (_lastActivityDate != null && _isConsecutiveDay(_lastActivityDate!, today)) {
          _streak++;
        } else if (_lastActivityDate == null) {
          _streak = 1;
        } else {
          if (!_isStreakFrozen) {
            _streak = 1;
          }
        }
        _lastActivityDate = today;
        await _savePersistentData();
      }

      // Update distance only when tracking is enabled
      if (_previousPosition != null && _trackingEnabled) {
        final distanceKm = Geolocator.distanceBetween(
          _previousPosition!.latitude,
          _previousPosition!.longitude,
          position.latitude,
          position.longitude,
        ) / 1000.0;
        _totalDistance += distanceKm;
        _limetkyBalance += distanceKm.toInt();
        await _savePersistentData();

        // Game Integration check - trigger every 1.5 km
        if (_activeRouteGame != null && _routeActive) {
          if (_totalDistance - _gameLastTriggeredDistance >= 1.5) {
            _gameLastTriggeredDistance = _totalDistance;
            await _saveActiveGameState();
            _triggerRouteGameRoll();
          }
        }
      }
      _previousPosition = position;

      if (_breadcrumbsCoordinates.isEmpty ||
          Geolocator.distanceBetween(
            _breadcrumbsCoordinates.last.latitude,
            _breadcrumbsCoordinates.last.longitude,
            newPoint.latitude,
            newPoint.longitude,
          ) > 10.0) {
        setState(() {
          _breadcrumbsCoordinates.add(newPoint);
        });
        _snapBreadcrumbsToRoads();
        _updateBreadcrumbsPolyline();
      }
      if (_polylineCoordinates.isEmpty ||
          _polylineCoordinates.last.latitude != newPoint.latitude ||
          _polylineCoordinates.last.longitude != newPoint.longitude) {
        setState(() {
          _polylineCoordinates.add(newPoint);
        });
        _updatePolyline();
      }
      _addMarker(position);
      _checkCheckpointProximity(position);

      // Active navigation tracking details
      int closestIndex = 0;
      double remainingD = 0.0;
      int remainingE = 0;
      double bearing = position.heading;

      if (_routeActive && _activeRoutePoints.isNotEmpty) {
        closestIndex = _findClosestRoutePointIndex(newPoint);
        remainingD = _calculateRemainingDistance(newPoint, closestIndex);
        remainingE = _calculateRouteEta(remainingD);
        _updateNavigationInstruction(newPoint, closestIndex);

        // Compute segment direction bearing if user is stationary or has invalid heading
        if (position.speed < 1.0 && closestIndex + 1 < _activeRoutePoints.length) {
          bearing = _calculateBearing(newPoint, _activeRoutePoints[closestIndex + 1]);
        }

        // Check if destination was reached
        if (closestIndex == _activeRoutePoints.length - 1 || 
            Geolocator.distanceBetween(
              newPoint.latitude,
              newPoint.longitude,
              _activeRoutePoints.last.latitude,
              _activeRoutePoints.last.longitude,
            ) < 20.0) {
          _completeRoute();
          return;
        }
      }

      setState(() {
        _todayDistance = _calculatePolylineDistance();
        _lastPosition = position;
        if (_routeActive) {
          _closestWaypointIndex = closestIndex;
          _remainingDistance = remainingD;
          _remainingEta = remainingE;
        }
      });

      _checkPartnerProximity(LatLng(position.latitude, position.longitude));

      if (_routeActive) {
        final cameraPosition = CameraPosition(
          target: newPoint,
          zoom: 17.5,
          bearing: bearing,
          tilt: 45.0,
        );
        _mapController?.animateCamera(
          CameraUpdate.newCameraPosition(cameraPosition),
        );
      } else if (_isFollowingUser) {
        double baseZoom = 16.0;
        if (position.speed > 0) {
          final speedFactor = position.speed.clamp(0.0, 5.0) / 5.0;
          baseZoom = 16.0 - (speedFactor * 2.0);
        }
        final cameraPosition = CameraPosition(
          target: LatLng(position.latitude, position.longitude),
          zoom: baseZoom,
          bearing: position.heading,
          tilt: 0.0,
        );
        _mapController?.animateCamera(
          CameraUpdate.newCameraPosition(cameraPosition),
        );
      }
    });
  }

  void _showLongPressMenu(BuildContext context, LatLng latLng) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Akce na místě',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.place, color: Color(0xFFBFFF00)),
              title: const Text('Nahlásit POI'),
              subtitle: const Text('Označit zajímavé místo'),
              onTap: () {
                Navigator.pop(context);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('POI nahlášeno!')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.directions, color: Color(0xFFBFFF00)),
              title: const Text('Nastavit cíl'),
              subtitle: const Text('Vytvořit trasu do tohoto místa'),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _destinationPoint = latLng;
                  _showRouteSearch = false;
                  _generateDestinationRoute(latLng);
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showNavigationMenu() {
    final theme = appThemeNotifier.value;
    final isWhite = theme == 'white';
    final cardColor = isWhite ? Colors.white : const Color(0xFF1E272C);
    final textColor = isWhite ? const Color(0xFF263238) : Colors.white;
    final textSecondary = isWhite ? Colors.black54 : Colors.white70;

    showModalBottomSheet(
      context: context,
      backgroundColor: cardColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).padding.bottom + 16,
            ),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                  Text(
                    'Vyberte režim mapy',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isWhite ? Colors.lightBlue.shade50 : Colors.lightBlue.shade900.withOpacity(0.3),
                      child: Icon(Icons.loop, color: isWhite ? Colors.lightBlue : Colors.lightBlueAccent),
                    ),
                    title: Text('Okruh v okolí', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                    subtitle: Text('Najděte snadné okruhy start-cíl ve vašem dosahu', style: TextStyle(color: textSecondary, fontSize: 12)),
                    onTap: () async {
                      Navigator.pop(context);
                      
                      // Check if GPS is enabled
                      final gpsEnabled = await _locationService.isLocationServiceEnabled();
                      if (!gpsEnabled) {
                        if (mounted) {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('GPS vypnuto'),
                              content: const Text('Zapněte prosím GPS (služby polohy) v nastavení telefonu, abyste mohli vybrat okruh ve svém okolí.'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Rozumím'),
                                ),
                              ],
                            ),
                          );
                        }
                        return;
                      }

                      // Check location permissions
                      final permission = await Geolocator.checkPermission();
                      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
                        final requested = await _locationService.requestLocationPermission();
                        if (!requested) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Přístup k poloze byl zamítnut. Povolte polohu v nastavení.')),
                            );
                          }
                          return;
                        }
                      }

                      // If _lastPosition is still null, try to actively fetch it
                      Position? currentPos = _lastPosition;
                      if (currentPos == null) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Získávám GPS polohu...'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                        currentPos = await _locationService.getCurrentLocation();
                      }

                      if (currentPos == null) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Nepodařilo se získat GPS polohu. Zkontrolujte signál.')),
                          );
                        }
                        return;
                      }

                      // Update _lastPosition
                      _lastPosition = currentPos;

                      if (!mounted) return;
                      
                      final result = await Navigator.of(context).push<Map<String, dynamic>>(
                        MaterialPageRoute(
                          builder: (context) => RouteSelectionScreen(
                            startLocation: LatLng(currentPos!.latitude, currentPos!.longitude),
                            isBikeDefault: _usingBike,
                          ),
                        ),
                      );

                      if (result != null) {
                        final points = result['points'] as List<LatLng>;
                        final title = result['title'] as String;
                        final distance = result['distance'] as double;
                        final eta = result['eta'] as int;
                        final isBike = result['using_bike'] as bool? ?? _usingBike;

                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool('preferred_bike_mode', isBike);

                        final polyline = Polyline(
                          polylineId: const PolylineId('active_route'),
                          color: isBike ? Colors.blue : Colors.green,
                          width: 5,
                          points: points,
                          geodesic: true,
                        );

                        setState(() {
                          _usingBike = isBike;
                          _activeRoutePoints = points;
                          _polylines.removeWhere((p) => p.polylineId.value == 'active_route');
                          _polylines.add(polyline);
                          _destinationPoint = points.last;
                          
                          _routeSuggestions = [
                            {
                              'title': title,
                              'coordinates': points,
                              'distance': distance,
                              'eta': eta,
                              'poi_count': 0,
                              'trivia_question': result['trivia_question'] as String?,
                              'trivia_answer': result['trivia_answer'] as String?,
                            }
                          ];
                          _selectedRouteSuggestionIndex = 0;
                          _showRouteSuggestions = false;
                          _showRouteSearch = false;
                          _taskCardExpanded = false;
                          _routePlotted = true;

                          if (result['selected_game'] != null) {
                            _activeRouteGame = result['selected_game'] as WheelOfFortune?;
                            _gamePlayers = List<String>.from(result['game_players'] as List<dynamic>? ?? ['Já']);
                            _isGroupMode = result['is_group_mode'] as bool? ?? false;
                            _gameLastTriggeredDistance = distance;
                            _gameActiveAssignments.clear();
                            _gamePlayerHistory.clear();
                          } else {
                            _activeRouteGame = null;
                          }
                        });
                      }
                    },
                  ),
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isWhite ? Colors.lightBlue.shade50 : Colors.lightBlue.shade900.withOpacity(0.3),
                      child: Icon(Icons.location_pin, color: isWhite ? Colors.lightBlue : Colors.lightBlueAccent),
                    ),
                    title: Text('Cesta do cíle', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                    subtitle: Text('Zadejte adresu nebo vyberte cíl na mapě', style: TextStyle(color: textSecondary, fontSize: 12)),
                    onTap: () async {
                      Navigator.pop(context);
                      
                      // Check GPS enabled
                      final gpsEnabled = await _locationService.isLocationServiceEnabled();
                      if (!gpsEnabled) {
                        if (mounted) {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('GPS vypnuto'),
                              content: const Text('Zapněte prosím GPS (služby polohy) v nastavení telefonu, abyste mohli vybrat cestu do cíle.'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Rozumím'),
                                ),
                              ],
                            ),
                          );
                        }
                        return;
                      }

                      // Check location permissions
                      final permission = await Geolocator.checkPermission();
                      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
                        final requested = await _locationService.requestLocationPermission();
                        if (!requested) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Přístup k poloze byl zamítnut. Povolte polohu v nastavení.')),
                            );
                          }
                          return;
                        }
                      }

                      Position? currentPos = _lastPosition;
                      if (currentPos == null) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Získávám GPS polohu...'), duration: Duration(seconds: 2)),
                          );
                        }
                        currentPos = await _locationService.getCurrentLocation();
                      }

                      if (currentPos == null) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Nepodařilo se získat GPS polohu. Zkontrolujte signál.')),
                          );
                        }
                        return;
                      }

                      _lastPosition = currentPos;
                      if (!mounted) return;

                      final result = await Navigator.of(context).push<Map<String, dynamic>>(
                        MaterialPageRoute(
                          builder: (context) => RouteSelectionScreen(
                            startLocation: LatLng(currentPos!.latitude, currentPos!.longitude),
                            isBikeDefault: _usingBike,
                            isAtoBMode: true,
                          ),
                        ),
                      );

                      if (result != null) {
                        final points = result['points'] as List<LatLng>;
                        final title = result['title'] as String;
                        final distance = result['distance'] as double;
                        final eta = result['eta'] as int;
                        final isBike = result['using_bike'] as bool? ?? _usingBike;

                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool('preferred_bike_mode', isBike);

                        final polyline = Polyline(
                          polylineId: const PolylineId('active_route'),
                          color: isBike ? Colors.blue : Colors.green,
                          width: 5,
                          points: points,
                          geodesic: true,
                        );

                        setState(() {
                          _usingBike = isBike;
                          _activeRoutePoints = points;
                          _polylines.removeWhere((p) => p.polylineId.value == 'active_route');
                          _polylines.add(polyline);
                          _destinationPoint = points.last;
                          
                          _routeSuggestions = [
                            {
                              'title': title,
                              'coordinates': points,
                              'distance': distance,
                              'eta': eta,
                              'poi_count': 0,
                              'trivia_question': result['trivia_question'] as String?,
                              'trivia_answer': result['trivia_answer'] as String?,
                            }
                          ];
                          _selectedRouteSuggestionIndex = 0;
                          _showRouteSuggestions = false;
                          _showRouteSearch = false;
                          _taskCardExpanded = false;
                          _routePlotted = true;

                          if (result['selected_game'] != null) {
                            _activeRouteGame = result['selected_game'] as WheelOfFortune?;
                            _gamePlayers = List<String>.from(result['game_players'] as List<dynamic>? ?? ['Já']);
                            _isGroupMode = result['is_group_mode'] as bool? ?? false;
                            _gameLastTriggeredDistance = distance;
                            _gameActiveAssignments.clear();
                            _gamePlayerHistory.clear();
                          } else {
                            _activeRouteGame = null;
                          }
                        });
                      }
                    },
                  ),
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isWhite ? Colors.lightBlue.shade50 : Colors.lightBlue.shade900.withOpacity(0.3),
                      child: Icon(Icons.qr_code_scanner, color: isWhite ? Colors.lightBlue : Colors.lightBlueAccent),
                    ),
                    title: Text('Načíst trasu z QR kódu', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                    subtitle: Text('Naskenujte trasu od kamaráda offline', style: TextStyle(color: textSecondary, fontSize: 12)),
                    onTap: () {
                      Navigator.pop(context);
                      _scanRouteQr();
                    },
                  ),
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isWhite ? Colors.amber.shade50 : Colors.amber.shade900.withOpacity(0.3),
                      child: Icon(Icons.stars, color: isWhite ? Colors.amber : Colors.amberAccent),
                    ),
                    title: Text('Top komunitní okruhy', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                    subtitle: Text('Vyhledat nejlépe hodnocené trasy v okolí', style: TextStyle(color: textSecondary, fontSize: 12)),
                    onTap: () {
                      Navigator.pop(context);
                      _showSearchCommunityRoutesDialog();
                    },
                  ),
                ],
              ),
            ),
          ),
         ),
        );
      },
    );
  }

  Widget _buildAntiCheatOverlay() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 80,
      left: 16,
      right: 16,
      child: ValueListenableBuilder<bool>(
        valueListenable: AntiCheatService().isCheatingNotifier,
        builder: (context, isCheating, child) {
          if (!isCheating) return const SizedBox.shrink();
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFD32F2F).withOpacity(0.92), // Solid premium crimson red
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.redAccent.withOpacity(0.5), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    color: Color(0xFFFFFF00), // Pure yellow
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Rychlý pohyb detekován!',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      ValueListenableBuilder<String>(
                        valueListenable: AntiCheatService().cheatReasonNotifier,
                        builder: (context, reason, _) {
                          return Text(
                            reason.isNotEmpty ? reason : 'Zpomalte pro obnovení sbírání km.',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Sbírání vzdálenosti je dočasně pozastaveno.',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomOffset = MediaQuery.of(context).padding.bottom + 80;
    final double fabBaseOffset;
    if (_routeActive) {
      fabBaseOffset = bottomOffset + 100;
    } else if (_routePlotted) {
      fabBaseOffset = bottomOffset + 150;
    } else {
      fabBaseOffset = bottomOffset + 76;
    }

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(0),
              child: GoogleMap(
                onMapCreated: _onMapCreated,
                mapType: _mapType,
                onCameraMoveStarted: () {
                  setState(() {
                    _isFollowingUser = false;
                  });
                },
                onTap: (latLng) {
                  if (_isSelectingDestination) {
                    setState(() {
                      _isSelectingDestination = false;
                      _destinationPoint = latLng;
                      _generateDestinationRoute(latLng);
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Cíl zvolen. Trasa vytvořena.')),
                    );
                  }
                },
                onLongPress: (latLng) {
                  _showLongPressMenu(context, latLng);
                },
                initialCameraPosition: const CameraPosition(
                  target: LatLng(50.0755, 14.4378),
                  zoom: 13,
                ),
                polylines: _polylines,
                markers: _markers,
                myLocationEnabled: true,
                myLocationButtonEnabled: true,
                padding: const EdgeInsets.only(top: 150, right: 16),
                compassEnabled: true,
                zoomControlsEnabled: true,
              ),
            ),
          ),
          if (!_routeActive)
            Positioned(
              top: topPadding + 12,
              left: 16,
              right: 80,
              child: GestureDetector(
                onTap: () => setState(() => _taskCardExpanded = !_taskCardExpanded),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  height: _taskCardExpanded ? 170 : 72,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withOpacity(0.6), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.directions_walk_rounded, color: Color(0xFF5C9E00), size: 26),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Úkol: Ujdi 1 km dnes',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF263238),
                                      ),
                                ),
                              ),
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: _todayDistance >= _dailyTargetKm * 1000 ? const Color(0xFF5C9E00) : const Color(0xFFE8F5E9),
                                child: Icon(
                                  _todayDistance >= _dailyTargetKm * 1000 ? Icons.check : Icons.timer_outlined,
                                  color: _todayDistance >= _dailyTargetKm * 1000 ? Colors.white : const Color(0xFF5C9E00),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(_taskCardExpanded ? Icons.expand_less : Icons.expand_more, color: Colors.grey.shade600),
                            ],
                          ),
                          if (_taskCardExpanded) ...[
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: LinearProgressIndicator(
                                value: min(_todayDistance / 1000.0 / _dailyTargetKm, 1.0),
                                minHeight: 8,
                                backgroundColor: Colors.grey.shade100,
                                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFBFFF00)),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFBFFF00).withOpacity(0.3),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFFD4FF00),
                                      Color(0xFFBFFF00),
                                    ],
                                  ),
                                ),
                                child: ElevatedButton.icon(
                                  onPressed: _showNavigationMenu,
                                  icon: const Icon(Icons.menu_rounded, color: Color(0xFF1B5E20)),
                                  label: const Text('Výběr trasy', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1B5E20))),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                  ),
                                ),
                              ),
                            ),
                          ]
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            bottom: bottomOffset - 40,
            left: 16,
            right: 16,
            child: AnimatedOpacity(
              opacity: (!_routeActive && _routePlotted) ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 250),
              child: IgnorePointer(
                ignoring: !(!_routeActive && _routePlotted),
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if ((_routeActive || _routePlotted) && _routeSuggestions.isNotEmpty) ...[
                          Text(
                            _routeSuggestions[_selectedRouteSuggestionIndex]['title'] as String,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            children: [
                              _buildRouteInfoChip('${(_routeSuggestions[_selectedRouteSuggestionIndex]['distance'] as double).toStringAsFixed(1)} km'),
                              _buildRouteInfoChip('${_routeSuggestions[_selectedRouteSuggestionIndex]['eta']} min'),
                              _buildRouteInfoChip('${_routeSuggestions[_selectedRouteSuggestionIndex]['poi_count']} POI'),
                              if (_activeRouteGame != null)
                                _buildRouteInfoChip(
                                  '🎮 ${_activeRouteGame!.name}',
                                  color: Colors.orange.shade50,
                                  textColor: Colors.orange.shade900,
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (_routePlotted && !_trackingEnabled) ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: _startRoute,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.lightBlue,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    child: const Text('START / VYRAZIT', style: TextStyle(fontWeight: FontWeight.bold)),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _showQrShareDialog,
                                    icon: const Icon(Icons.qr_code, size: 20),
                                    label: const Text('Pozvat (QR)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.lightBlue,
                                      side: const BorderSide(color: Colors.lightBlue),
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_showRouteSearch)
            Positioned(
              bottom: bottomOffset + 220,
              left: 16,
              right: 16,
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: _destinationController,
                        decoration: const InputDecoration(
                          labelText: 'Hledat destinaci',
                          hintText: 'Například Pardubice',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                        ),
                        onChanged: _fetchPlacePredictions,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _showRouteSearch = false;
                                _showRouteSuggestions = false;
                                _isSelectingDestination = true;
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Klikněte na mapu pro výběr cíle.')),
                              );
                            },
                            child: const Text('Vybrat na mapě'),
                          ),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _showRouteSearch = false;
                                _showRouteSuggestions = false;
                                _isSelectingDestination = false;
                              });
                            },
                            child: const Text('Zrušit'),
                          ),
                        ],
                      ),
                      if (_showSuggestions && _placePredictions.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        ListView.builder(
                          shrinkWrap: true,
                          itemCount: _placePredictions.length,
                          itemBuilder: (context, index) {
                            final prediction = _placePredictions[index];
                            return ListTile(
                              title: Text(prediction.description),
                              onTap: () => _selectPlace(prediction),
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          if (_showRouteSuggestions)
            Positioned(
              bottom: bottomOffset + 120,
              left: 16,
              right: 16,
              child: SizedBox(
                height: 180,
                child: _isLoadingRoutes
                    ? Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        elevation: 8,
                        child: const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24.0),
                            child: CircularProgressIndicator(),
                          ),
                        ),
                      )
                    : PageView.builder(
                        controller: _routePageController,
                        onPageChanged: (index) {
                          _selectRouteSuggestion(index);
                        },
                        itemCount: _routeSuggestions.length,
                        itemBuilder: (context, index) {
                          final route = _routeSuggestions[index];
                          return Card(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            elevation: 8,
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    route['title'] as String,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  const SizedBox(height: 10),
                                  Text('Vzdálenost: ${(route['distance'] as double).toStringAsFixed(1)} km'),
                                  Text('Čas: ${route['eta']} min'),
                                  Text('POI: ${route['poi_count']}'),
                                  const Spacer(),
                                  ElevatedButton(
                                    onPressed: () => _selectRouteSuggestion(index),
                                    style: const ButtonStyle(
                                      backgroundColor: WidgetStatePropertyAll(Colors.lightBlue),
                                      foregroundColor: WidgetStatePropertyAll(Colors.white),
                                    ),
                                    child: const Text('Vybrat trasu'),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
          if (!_routeActive)
            Positioned(
              bottom: bottomOffset,
              left: 20,
              right: 20,
              child: ElevatedButton.icon(
                onPressed: _showNavigationMenu,
                icon: const Icon(Icons.menu),
                label: const Text('Výběr trasy'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFBFFF00),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          if (_routeActive)
            Positioned(
              bottom: bottomOffset - 40,
              left: 16,
              right: 16,
              child: Card(
                elevation: 6,
                color: const Color(0xFF263238),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _routeSuggestions.isNotEmpty && _selectedRouteSuggestionIndex < _routeSuggestions.length
                                      ? (_routeSuggestions[_selectedRouteSuggestionIndex]['title'] as String).toUpperCase()
                                      : 'AKTIVNÍ NAVIGACE',
                                  style: const TextStyle(
                                    color: Color(0xFFBFFF00),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.1,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${_remainingDistance.toStringAsFixed(1)} km  •  $_remainingEta min',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_gameActiveAssignments.isNotEmpty) ...[
                            GestureDetector(
                              onTap: _showActiveAssignmentsDialog,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade900,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.star, color: Colors.white, size: 12),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${_gameActiveAssignments.length} ${_gameActiveAssignments.length == 1 ? 'úkol' : _gameActiveAssignments.length < 5 ? 'úkoly' : 'úkolů'}',
                                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ] else if (_activeRouteGame != null) ...[
                            GestureDetector(
                              onTap: _openGameWheelScreen,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFBFFF00), width: 1),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.casino_outlined, color: Color(0xFFBFFF00), size: 12),
                                    const SizedBox(width: 4),
                                    Text(
                                      _activeRouteGame!.name,
                                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          ElevatedButton(
                            onPressed: _showCancelRouteDialog,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              minimumSize: const Size(0, 0),
                            ),
                            child: const Text(
                              'Konec',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      if (_navigationInstruction.isNotEmpty) ...[
                        const Divider(color: Colors.white12, height: 12),
                        Row(
                          children: [
                            Icon(
                              _navigationIcon,
                              color: const Color(0xFFBFFF00),
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _navigationInstruction,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          Positioned(
            bottom: fabBaseOffset,
            right: 20,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (widget.showMapType) ...[
                  FloatingActionButton(
                    heroTag: 'map_type_button',
                    onPressed: _toggleMapType,
                    backgroundColor: _mapType != MapType.normal ? const Color(0xFFBFFF00) : Colors.white,
                    foregroundColor: Colors.black,
                    child: const Icon(Icons.layers, size: 28),
                  ),
                  if (widget.showMapStyle || widget.showShareLocation || widget.showArNav)
                    const SizedBox(height: 16),
                ],
                if (widget.showMapStyle) ...[
                  FloatingActionButton(
                    heroTag: 'map_style_button',
                    onPressed: _toggleMapStyle,
                    backgroundColor: _currentMapStyle != 'default' ? const Color(0xFFBFFF00) : Colors.white,
                    foregroundColor: Colors.black,
                    child: Icon(
                      _currentMapStyle == 'default'
                          ? Icons.map
                          : _currentMapStyle == 'light'
                              ? Icons.light_mode
                              : Icons.dark_mode,
                      size: 28,
                    ),
                  ),
                  if (widget.showShareLocation || widget.showArNav)
                    const SizedBox(height: 16),
                ],
                if (widget.showShareLocation) ...[
                  FloatingActionButton(
                    heroTag: 'share_location_button',
                    onPressed: _toggleLocationSharing,
                    backgroundColor: _shareLocation ? Colors.lime : Colors.white,
                    foregroundColor: _shareLocation ? Colors.black : Colors.black54,
                    child: Icon(
                      _shareLocation ? Icons.location_on : Icons.location_off_outlined,
                      size: 28,
                    ),
                  ),
                  if (widget.showArNav)
                    const SizedBox(height: 16),
                ],
                if (widget.showArNav)
                  FloatingActionButton(
                    heroTag: 'ar_nav_button',
                    onPressed: _onArPressed,
                    backgroundColor: const Color(0xFFBFFF00),
                    foregroundColor: Colors.black,
                    child: const Icon(Icons.remove_red_eye, size: 28),
                  ),
              ],
            ),
          ),
          // Top Notification Bell Button
          Positioned(
            top: topPadding + 16,
            right: 16,
            child: ValueListenableBuilder<int>(
              valueListenable: NotificationManager.unreadCountNotifier,
              builder: (context, count, child) {
                return Stack(
                  children: [
                    GestureDetector(
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(builder: (context) => const NotificationInboxScreen()),
                        );
                        _loadUnreadNotificationsCount();
                      },
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.notifications_active, color: Colors.lightBlue, size: 26),
                      ),
                    ),
                    if (count > 0)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.redAccent,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 18,
                            minHeight: 18,
                          ),
                          child: Text(
                            '$count',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          // Anti-cheat warning overlay
          _buildAntiCheatOverlay(),
        ],
      ),
    );
  }

  // Premium & AR Methods
  bool _isPremium = false;

  Future<void> _loadPremiumStatus() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _isPremium = prefs.getBool('isPremium') ?? false;
      });
    }
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        final data = doc.data() ?? {};
        final isPremiumDb = data['isPremium'] as bool? ?? false;
        if (isPremiumDb != _isPremium && mounted) {
          setState(() {
            _isPremium = isPremiumDb;
          });
          await prefs.setBool('isPremium', isPremiumDb);
        }
      }
    } catch (_) {}
  }

  void _onArPressed() {
    if (_activeRoutePoints.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nejprve vyberte nebo zapněte trasu na mapě.')),
      );
      return;
    }

    if (_isPremium) {
      _openArNavigation();
    } else {
      _showPaywall();
    }
  }

  void _openArNavigation() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ArNavigationScreen(routePoints: _activeRoutePoints),
      ),
    );
  }

  void _fitMapBounds(List<LatLng> points) {
    if (_mapController == null || points.isEmpty) return;
    
    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLon = points.first.longitude;
    double maxLon = points.first.longitude;

    for (final point in points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLon) minLon = point.longitude;
      if (point.longitude > maxLon) maxLon = point.longitude;
    }

    _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat - 0.001, minLon - 0.001),
          northeast: LatLng(maxLat + 0.001, maxLon + 0.001),
        ),
        50.0,
      ),
    );
  }

  void _showPaywall() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      backgroundColor: Colors.white,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(28.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.stars, size: 72, color: Colors.amber),
              const SizedBox(height: 16),
              const Text(
                'Aktivujte Hejbej se Premium!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'Získejte přístup k AR Navigaci přímo na silnici! Uvidíte trasu vykreslenou v rozšířené realitě přímo před sebou.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54, fontSize: 14),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.lime.shade50.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.lime),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text(
                      'Měsíční předplatné',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Text(
                      '25 Kč / měsíc',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.lightBlue),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              if (Platform.isAndroid)
                GooglePayButton(
                  paymentConfiguration: PaymentConfiguration.fromJsonString(
                    r'''{
                      "provider": "google_pay",
                      "data": {
                        "environment": "TEST",
                        "apiVersion": 2,
                        "apiVersionMinor": 0,
                        "allowedPaymentMethods": [
                          {
                            "type": "CARD",
                            "tokenizationSpecification": {
                              "type": "PAYMENT_GATEWAY",
                              "parameters": {
                                "gateway": "example",
                                "gatewayMerchantId": "exampleGatewayMerchantId"
                              }
                            },
                            "parameters": {
                              "allowedAuthMethods": ["PAN_ONLY", "CRYPTOGRAM_3DS"],
                              "allowedCardNetworks": ["AMEX", "DISCOVER", "JCB", "MASTERCARD", "VISA"]
                            }
                          }
                        ],
                        "merchantInfo": {
                          "merchantName": "Hejbej se"
                        },
                        "transactionInfo": {
                          "countryCode": "CZ",
                          "currencyCode": "CZK",
                          "totalPriceStatus": "FINAL",
                          "totalPrice": "25.00"
                        }
                      }
                    }'''
                  ),
                  paymentItems: const [
                    PaymentItem(
                      label: 'Hejbej se Premium',
                      amount: '25.00',
                      status: PaymentItemStatus.final_price,
                    )
                  ],
                  type: GooglePayButtonType.subscribe,
                  width: double.infinity,
                  height: 50,
                  margin: const EdgeInsets.only(top: 8.0),
                  onPaymentResult: (result) => _unlockPremium(),
                  loadingIndicator: const Center(child: CircularProgressIndicator()),
                )
              else if (Platform.isIOS)
                ApplePayButton(
                  paymentConfiguration: PaymentConfiguration.fromJsonString(
                    r'''{
                      "provider": "apple_pay",
                      "data": {
                        "merchantIdentifier": "merchant.com.zetro39.hejbejse",
                        "supportedNetworks": ["visa", "masterCard", "amex"],
                        "countryCode": "CZ",
                        "currencyCode": "CZK"
                      }
                    }'''
                  ),
                  paymentItems: const [
                    PaymentItem(
                      label: 'Hejbej se Premium',
                      amount: '25.00',
                      status: PaymentItemStatus.final_price,
                    )
                  ],
                  style: ApplePayButtonStyle.black,
                  width: double.infinity,
                  height: 50,
                  margin: const EdgeInsets.only(top: 8.0),
                  onPaymentResult: (result) => _unlockPremium(),
                ),
              
              const SizedBox(height: 12),
              
              OutlinedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _unlockPremium();
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.lime, width: 2),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text(
                  '[Test Bypass] Odemknout zdarma',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _unlockPremium() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isPremium', true);
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'isPremium': true,
      }, SetOptions(merge: true));
    }
    
    setState(() {
      _isPremium = true;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 Premium aktivováno! Nyní můžete používat AR navigaci.'),
          backgroundColor: Colors.green,
        ),
      );
      
      if (_activeRoutePoints.isNotEmpty) {
        _openArNavigation();
      }
    }
  }

  void _showQrShareDialog() {
    if (_activeRoutePoints.isEmpty) return;
    
    // Sample points if too many (limit to 30) to fit in QR payload
    List<LatLng> sampled = [];
    if (_activeRoutePoints.length <= 30) {
      sampled = _activeRoutePoints;
    } else {
      final step = _activeRoutePoints.length / 30;
      for (int i = 0; i < 30; i++) {
        sampled.add(_activeRoutePoints[(i * step).toInt()]);
      }
      sampled.add(_activeRoutePoints.last);
    }
    
    final coordinates = sampled.map((p) => [
      double.parse(p.latitude.toStringAsFixed(5)),
      double.parse(p.longitude.toStringAsFixed(5))
    ]).toList();
    
    final title = _routeSuggestions.isNotEmpty && _selectedRouteSuggestionIndex < _routeSuggestions.length
        ? _routeSuggestions[_selectedRouteSuggestionIndex]['title'] as String? ?? 'Cesta do cíle'
        : 'Cesta do cíle';
        
    final payload = jsonEncode({
      't': title,
      'p': coordinates,
    });

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Přizvat kamaráda na cestu 🤝'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Nechte kamaráda naskenovat tento QR kód ve své aplikaci Hejbej Se pro okamžité offline sdílení trasy.',
              style: TextStyle(fontSize: 13, color: Colors.black54),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 200,
              height: 200,
              child: QrImageView(
                data: payload,
                version: QrVersions.auto,
                size: 200.0,
                gapless: false,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Zavřít'),
          ),
        ],
      ),
    );
  }

  void _handlePendingSharedRoute() {
    final data = MapsScreen.pendingSharedRouteNotifier.value;
    if (data != null) {
      MapsScreen.pendingSharedRouteNotifier.value = null;
      _loadRouteFromData(data);
    }
  }

  Future<void> _loadRouteFromData(String data) async {
    try {
      final map = jsonDecode(data) as Map<String, dynamic>;
      final title = map['t'] as String;
      final coordsList = map['p'] as List<dynamic>;
      final points = coordsList.map((c) {
        final list = c as List<dynamic>;
        return LatLng((list[0] as num).toDouble(), (list[1] as num).toDouble());
      }).toList();
      
      if (points.length < 2) {
        throw Exception('Nedostatek bodů trasy');
      }

      final polyline = Polyline(
        polylineId: const PolylineId('active_route'),
        color: _usingBike ? Colors.blue : Colors.green,
        width: 5,
        points: points,
        geodesic: true,
      );
      
      final distance = _calculateRouteLength(points);
      final eta = _calculateRouteEta(distance);

      setState(() {
        _activeRoutePoints = points;
        _routePlotted = true;
        _routeActive = false;
        _polylines.removeWhere((p) => p.polylineId.value == 'active_route');
        _polylines.add(polyline);
        _destinationPoint = points.last;
        
        _routeSuggestions = [
          {
            'title': title,
            'coordinates': points,
            'distance': distance,
            'eta': eta,
            'poi_count': 0,
          }
        ];
        _selectedRouteSuggestionIndex = 0;
        _showRouteSuggestions = false;
        _showRouteSearch = false;
        _taskCardExpanded = false;
      });

      await _cacheActiveRoute(points, title, distance, eta);
      
      _fitMapBounds(points);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Trasa "$title" úspěšně načtena!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Neplatný formát sdílené trasy: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _scanRouteQr() async {
    final scannedData = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (context) => const QrScannerScreen()),
    );
    
    if (scannedData == null || scannedData.isEmpty) return;
    await _loadRouteFromData(scannedData);
  }

  Future<void> _saveActiveGameState() async {
    final prefs = await SharedPreferences.getInstance();
    if (_activeRouteGame == null) {
      await prefs.remove('active_game_id');
      await prefs.remove('active_game_players');
      await prefs.remove('active_game_mode');
      await prefs.remove('active_game_last_triggered_dist');
      await prefs.remove('active_game_assignments');
      await prefs.remove('active_game_player_history');
    } else {
      await prefs.setString('active_game_id', _activeRouteGame!.id);
      await prefs.setStringList('active_game_players', _gamePlayers);
      await prefs.setBool('active_game_mode', _isGroupMode);
      await prefs.setDouble('active_game_last_triggered_dist', _gameLastTriggeredDistance);
      await prefs.setString('active_game_assignments', jsonEncode(
        _gameActiveAssignments.map((k, v) => MapEntry(k, v.toJson()))
      ));
      await prefs.setString('active_game_player_history', jsonEncode(_gamePlayerHistory));
    }
  }

  Future<void> _loadActiveGameState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final gameId = prefs.getString('active_game_id');
      if (gameId == null) return;

      final customWheels = await WheelOfFortuneService().getCustomWheels();
      final officialWheels = WheelOfFortuneService().getOfficialWheels();
      
      WheelOfFortune? wheel;
      for (final w in customWheels) {
        if (w.id == gameId) {
          wheel = w;
          break;
        }
      }
      if (wheel == null) {
        for (final w in officialWheels) {
          if (w.id == gameId) {
            wheel = w;
            break;
          }
        }
      }

      if (wheel == null) return;

      setState(() {
        _activeRouteGame = wheel;
        _gamePlayers = prefs.getStringList('active_game_players') ?? ['Já'];
        _isGroupMode = prefs.getBool('active_game_mode') ?? false;
        _gameLastTriggeredDistance = prefs.getDouble('active_game_last_triggered_dist') ?? 0.0;
        
        final assignmentsJson = prefs.getString('active_game_assignments');
        if (assignmentsJson != null) {
          final decoded = jsonDecode(assignmentsJson) as Map<String, dynamic>;
          _gameActiveAssignments = decoded.map((k, v) => MapEntry(k, WheelTask.fromJson(v)));
        } else {
          _gameActiveAssignments = {};
        }

        final historyJson = prefs.getString('active_game_player_history');
        if (historyJson != null) {
          final decoded = jsonDecode(historyJson) as Map<String, dynamic>;
          _gamePlayerHistory = decoded.map((k, v) => MapEntry(k, List<String>.from(v)));
        } else {
          _gamePlayerHistory = {};
        }
      });
    } catch (_) {}
  }

  Future<void> _triggerRouteGameRoll() async {
    if (_activeRouteGame == null) return;
    HapticFeedback.vibrate();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('🎰 Losování úkolu!', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Ušli jste dalších 1.5 km. Je čas vylosovat úkoly pro tuto část trasy!'),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _openGameWheelScreen();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.lime,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('SPUSTIT KOLO ŠTĚSTÍ'),
          ),
        ],
      ),
    );
  }

  void _openGameWheelScreen() {
    if (_activeRouteGame == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WheelOfFortuneScreen(
          playerNames: _gamePlayers,
          wheel: _activeRouteGame!,
          playerHistory: _gamePlayerHistory,
          onComplete: (assignments) {
            setState(() {
              _gameActiveAssignments = assignments;
            });
            _saveActiveGameState();
          },
        ),
      ),
    );
  }

  void _showAddGameToRouteBottomSheet() async {
    final official = WheelOfFortuneService().getOfficialWheels();
    final custom = await WheelOfFortuneService().getCustomWheels();
    final allWheels = [...official, ...custom];

    if (!mounted) return;

    WheelOfFortune? selectedWheel = allWheels.isNotEmpty ? allWheels.first : null;
    final playersController = TextEditingController(text: 'Já');
    String selectedMode = 'individual';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.black12,
                          borderRadius: BorderRadius.all(Radius.circular(10)),
                        ),
                        child: SizedBox(
                          width: 40,
                          height: 5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Nastavit hru pro trasu',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                    ),
                    const SizedBox(height: 16),
                    const Text('Vyberte Kolo štěstí:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<WheelOfFortune>(
                      value: selectedWheel,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      items: allWheels.map((w) {
                        return DropdownMenuItem<WheelOfFortune>(
                          value: w,
                          child: Text(w.name),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() {
                            selectedWheel = val;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text('Hráči na trase (oddělte čárkou):', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: playersController,
                      decoration: InputDecoration(
                        hintText: 'Já, Tomáš, Pepa',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.people),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Herní režim:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('Každý sám')),
                            selected: selectedMode == 'individual',
                            onSelected: (val) {
                              if (val) setModalState(() => selectedMode = 'individual');
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('Celá parta')),
                            selected: selectedMode == 'group',
                            onSelected: (val) {
                              if (val) setModalState(() => selectedMode = 'group');
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        if (selectedWheel == null) return;
                        final pList = playersController.text
                            .split(',')
                            .map((s) => s.trim())
                            .where((s) => s.isNotEmpty)
                            .toList();
                        
                        setState(() {
                          _activeRouteGame = selectedWheel;
                          _gamePlayers = pList.isEmpty ? ['Já'] : pList;
                          _isGroupMode = selectedMode == 'group';
                          _gameLastTriggeredDistance = _totalDistance;
                          _gameActiveAssignments.clear();
                          _gamePlayerHistory.clear();
                        });
                        _saveActiveGameState();
                        Navigator.pop(context);
                        
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Hra "${selectedWheel!.name}" byla úspěšně přidána na trasu!')),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.lime,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text('ULOŽIT HRU NA TRASU', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
