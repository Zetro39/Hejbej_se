import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:hejbej_se/services/route_elevation_service.dart';
import 'package:hejbej_se/features/gamification/models/wheel_of_fortune_model.dart';
import 'package:hejbej_se/features/gamification/services/wheel_of_fortune_service.dart';
import 'package:firebase_ai/firebase_ai.dart' hide LatLng;
import 'package:hejbej_se/services/remote_config_service.dart';
import 'package:hejbej_se/features/shop/shop_screen.dart';
import 'package:flutter/services.dart';
import 'qr_scanner_screen.dart';

class PlacePrediction {
  final String description;
  final String placeId;
  final double? lat;
  final double? lng;

  PlacePrediction({
    required this.description,
    required this.placeId,
    this.lat,
    this.lng,
  });

  factory PlacePrediction.fromNominatimJson(Map<String, dynamic> json) {
    return PlacePrediction(
      description: json['display_name'] as String? ?? '',
      placeId: (json['place_id'] ?? '').toString(),
      lat: double.tryParse((json['lat'] ?? '').toString()),
      lng: double.tryParse((json['lon'] ?? '').toString()),
    );
  }
}

class RouteSelectionScreen extends StatefulWidget {
  const RouteSelectionScreen({
    super.key,
    required this.startLocation,
    required this.isBikeDefault,
    this.initialDestinationLocation,
    this.initialDestinationAddress,
    this.isAtoBMode = false,
  });

  final LatLng startLocation;
  final bool isBikeDefault;
  final LatLng? initialDestinationLocation;
  final String? initialDestinationAddress;
  final bool isAtoBMode;

  @override
  State<RouteSelectionScreen> createState() => _RouteSelectionScreenState();
}

class _RouteSelectionScreenState extends State<RouteSelectionScreen> {
  GoogleMapController? _mapController;
  final PageController _pageController = PageController();

  bool _isUrban = false;
  bool _usingBike = false;
  double _selectedTargetKm = 8.0;
  MapType _mapType = MapType.normal;
  bool _isPremium = false;
  bool _showSimulatedAd = false;
  int _adCountdown = 10;
  Timer? _adTimer;

  // Hover elevation states
  double? _hoverFraction;
  int? _hoverElevationIndex;

  // List of generated options
  List<Map<String, dynamic>> _routeOptions = [];
  int _selectedOptionIndex = 0;
  List<Map<String, dynamic>> _savedRoutes = [];

  bool _isLoadingRouteOptions = false;
  bool _isLoadingRouteGeometry = false;
  List<LatLng> _currentRoutePoints = [];
  final Set<Polyline> _polylines = {};
  final Set<Marker> _markers = {};

  final List<double> _walkDistances = [3.0, 5.0, 8.0, 10.0, 12.0, 15.0, 20.0, 30.0];
  final List<double> _bikeDistances = [15.0, 20.0, 25.0, 30.0, 35.0, 40.0, 50.0];

  // A-to-B navigation states
  LatLng? _destinationLocation;
  final TextEditingController _searchController = TextEditingController();
  List<PlacePrediction> _suggestions = [];
  bool _showSuggestionsOverlay = false;
  Timer? _debounceTimer;

  // Active game choice state variables
  WheelOfFortune? _selectedGame;
  List<String> _gamePlayers = ['Já'];
  bool _isGroupMode = false;

  @override
  void initState() {
    super.initState();
    _usingBike = widget.isBikeDefault;
    _selectedTargetKm = _usingBike ? 25.0 : 8.0;
    _destinationLocation = widget.initialDestinationLocation;
    if (widget.initialDestinationAddress != null) {
      _searchController.text = widget.initialDestinationAddress!;
    }
    _loadSavedRoutes();

    _pageController.addListener(() {
      final int newPage = _pageController.page?.round() ?? 0;
      if (newPage != _selectedOptionIndex && newPage >= 0 && newPage < _routeOptions.length) {
        setState(() {
          _selectedOptionIndex = newPage;
          _hoverFraction = null;
          _hoverElevationIndex = null;
        });
        _fetchActiveOptionGeometry();
      }
    });

    _loadPremiumStatus().then((_) {
      _loadMapType().then((_) {
        _checkLocationEnvironment();
      });
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _searchController.dispose();
    _debounceTimer?.cancel();
    _adTimer?.cancel();
    super.dispose();
  }

  void _showAddGameBottomSheetInRouteSelection() async {
    final official = WheelOfFortuneService().getOfficialWheels();
    final custom = await WheelOfFortuneService().getCustomWheels();
    final allWheels = [...official, ...custom];

    if (!mounted) return;

    WheelOfFortune? selectedWheel = _selectedGame ?? (allWheels.isNotEmpty ? allWheels.first : null);
    final playersController = TextEditingController(text: _gamePlayers.join(', '));
    String selectedMode = _isGroupMode ? 'group' : 'individual';

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
                          _selectedGame = selectedWheel;
                          _gamePlayers = pList.isEmpty ? ['Já'] : pList;
                          _isGroupMode = selectedMode == 'group';
                        });
                        Navigator.pop(context);
                        
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Hra "${selectedWheel!.name}" byla vybrána pro trasu!')),
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
                    if (_selectedGame != null) ...[
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _selectedGame = null;
                            _gamePlayers = ['Já'];
                            _isGroupMode = false;
                          });
                          Navigator.pop(context);
                        },
                        child: const Text('Odebrat hru z trasy', style: TextStyle(color: Colors.redAccent)),
                      ),
                    ],
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

  Future<void> _loadPremiumStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isPremium = prefs.getBool('isPremium') ?? false;
    });
  }

  Future<void> _loadMapType() async {
    final prefs = await SharedPreferences.getInstance();
    final typeStr = prefs.getString('preferred_map_type') ?? 'normal';
    setState(() {
      if (typeStr == 'terrain') {
        _mapType = MapType.terrain;
      } else if (typeStr == 'satellite') {
        _mapType = MapType.satellite;
      } else if (typeStr == 'hybrid') {
        _mapType = MapType.hybrid;
      } else {
        _mapType = MapType.normal;
      }
    });
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

  Future<void> _checkLocationEnvironment() async {
    // Check if within municipal centers by approximate bounding box (Prague, Brno etc.)
    // If nearby urban areas, set _isUrban = true
    final lat = widget.startLocation.latitude;
    final lng = widget.startLocation.longitude;

    // Simple Prague/Brno bounding approximations
    final isPrague = (lat > 49.95 && lat < 50.18 && lng > 14.20 && lng < 14.70);
    final isBrno = (lat > 49.10 && lat < 49.28 && lng > 16.48 && lng < 16.72);

    setState(() {
      _isUrban = isPrague || isBrno;
    });
    if (!widget.isAtoBMode || _destinationLocation != null) {
      _generateRoutes();
    }
  }

  String _getCacheKey() {
    final lat = widget.startLocation.latitude;
    final lng = widget.startLocation.longitude;
    if (widget.isAtoBMode) {
      final destLat = _destinationLocation?.latitude ?? 0.0;
      final destLng = _destinationLocation?.longitude ?? 0.0;
      return "atob_${_usingBike}_${lat.toStringAsFixed(4)}_${lng.toStringAsFixed(4)}_${destLat.toStringAsFixed(4)}_${destLng.toStringAsFixed(4)}";
    } else {
      return "loop_${_usingBike}_${lat.toStringAsFixed(4)}_${lng.toStringAsFixed(4)}_${_selectedTargetKm.toStringAsFixed(1)}";
    }
  }

  Map<String, dynamic> _serializeRouteOption(Map<String, dynamic> opt) {
    final List<LatLng> wps = opt['waypoints'] as List<LatLng>? ?? [];
    final List<LatLng>? geom = opt['geometryPoints'] as List<LatLng>?;
    final List<double> elev = opt['elevations'] as List<double>? ?? [];

    List<Map<String, dynamic>> triviaData = [];
    if (opt['trivia'] != null) {
      final triviaRaw = opt['trivia'] as List<dynamic>;
      triviaData = triviaRaw.map((t) {
        final tMap = t as Map<String, dynamic>;
        return {
          'question': tMap['question'] as String? ?? '',
          'answer': tMap['answer'] as String? ?? '',
        };
      }).toList();
    } else if (opt['trivia_question'] != null) {
      triviaData = [
        {
          'question': opt['trivia_question'] as String? ?? '',
          'answer': opt['trivia_answer'] as String? ?? '',
        }
      ];
    }

    return {
      'title': opt['title'] as String? ?? '',
      'description': opt['description'] as String? ?? '',
      'waypoints': wps.map((w) => {'lat': w.latitude, 'lng': w.longitude}).toList(),
      if (geom != null)
        'geometryPoints': geom.map((g) => {'lat': g.latitude, 'lng': g.longitude}).toList(),
      'elevations': elev,
      'climb': opt['climb'] ?? 0.0,
      'exactDistance': opt['exactDistance'] ?? 0.0,
      'estimatedDistance': opt['estimatedDistance'] ?? 0.0,
      'eta': opt['eta'] ?? 0,
      'kct_color': opt['kct_color'],
      'cyklo_number': opt['cyklo_number'],
      'surface': opt['surface'] ?? 'smíšený',
      'environment': opt['environment'] ?? 'příroda',
      'pois': opt['pois'] ?? [],
      'trivia': triviaData,
      'is_bike': _usingBike,
      'is_a_to_b': widget.isAtoBMode,
    };
  }

  Map<String, dynamic> _deserializeRouteOption(Map<String, dynamic> opt) {
    final wpsRaw = opt['waypoints'] as List<dynamic>? ?? [];
    final List<LatLng> wps = wpsRaw
        .map((w) => LatLng((w['lat'] as num).toDouble(), (w['lng'] as num).toDouble()))
        .toList();

    List<LatLng>? geomPoints;
    if (opt['geometryPoints'] != null) {
      final geomRaw = opt['geometryPoints'] as List<dynamic>;
      geomPoints = geomRaw
          .map((g) => LatLng((g['lat'] as num).toDouble(), (g['lng'] as num).toDouble()))
          .toList();
    }

    final List<double> elevations = (opt['elevations'] as List<dynamic>?)
            ?.map((e) => (e as num).toDouble())
            .toList() ??
        [];

    List<Map<String, dynamic>> triviaList = [];
    if (opt['trivia'] != null) {
      final triviaRaw = opt['trivia'] as List<dynamic>;
      triviaList = triviaRaw.map((t) {
        final tMap = t as Map<String, dynamic>;
        return {
          'question': tMap['question'] as String? ?? '',
          'answer': tMap['answer'] as String? ?? '',
        };
      }).toList();
    }

    return {
      'title': opt['title'] as String? ?? '',
      'description': opt['description'] as String? ?? '',
      'waypoints': wps,
      if (geomPoints != null) 'geometryPoints': geomPoints,
      'elevations': elevations,
      'climb': (opt['climb'] as num?)?.toDouble() ?? 0.0,
      'exactDistance': (opt['exactDistance'] as num?)?.toDouble() ?? 0.0,
      'estimatedDistance': (opt['estimatedDistance'] as num?)?.toDouble() ?? 0.0,
      'eta': (opt['eta'] as num?)?.toInt() ?? 0,
      'kct_color': opt['kct_color'] as String?,
      'cyklo_number': opt['cyklo_number'] as String?,
      'surface': opt['surface'] as String? ?? 'smíšený',
      'environment': opt['environment'] as String? ?? 'příroda',
      'pois': List<String>.from(opt['pois'] ?? []),
      'trivia': triviaList,
      'trivia_question': triviaList.isNotEmpty ? triviaList[0]['question'] : 'Znáš historii tohoto místa?',
      'trivia_answer': triviaList.isNotEmpty ? triviaList[0]['answer'] : 'Více se dozvíš na trase!',
    };
  }

  Future<void> _loadSavedRoutes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedRaw = prefs.getStringList('saved_routes_list') ?? [];
      final List<Map<String, dynamic>> loaded = [];
      for (var raw in savedRaw) {
        try {
          final decoded = jsonDecode(raw) as Map<String, dynamic>;
          loaded.add(_deserializeRouteOption(decoded));
        } catch (e) {
          debugPrint('Chyba při dekódování uložené trasy: $e');
        }
      }
      setState(() {
        _savedRoutes = loaded;
      });
    } catch (e) {
      debugPrint('Chyba při načítání uložených tras: $e');
    }
  }

  bool _isRouteSaved(Map<String, dynamic> option) {
    final title = option['title'] as String? ?? '';
    final wps = option['waypoints'] as List<LatLng>? ?? [];
    if (wps.isEmpty) return false;
    for (var saved in _savedRoutes) {
      final sWps = saved['waypoints'] as List<LatLng>? ?? [];
      if (saved['title'] == title && sWps.isNotEmpty &&
          (sWps.first.latitude - wps.first.latitude).abs() < 0.0001 &&
          (sWps.first.longitude - wps.first.longitude).abs() < 0.0001) {
        return true;
      }
    }
    return false;
  }

  Future<void> _toggleSaveRoute(Map<String, dynamic> option) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isSaved = _isRouteSaved(option);
      final savedRaw = prefs.getStringList('saved_routes_list') ?? [];
      
      final title = option['title'] as String? ?? '';
      final wps = option['waypoints'] as List<LatLng>? ?? [];

      if (isSaved) {
        // Remove from list
        int targetIdx = -1;
        for (int i = 0; i < _savedRoutes.length; i++) {
          final sWps = _savedRoutes[i]['waypoints'] as List<LatLng>? ?? [];
          if (_savedRoutes[i]['title'] == title && sWps.isNotEmpty &&
              (sWps.first.latitude - wps.first.latitude).abs() < 0.0001 &&
              (sWps.first.longitude - wps.first.longitude).abs() < 0.0001) {
            targetIdx = i;
            break;
          }
        }
        if (targetIdx != -1) {
          savedRaw.removeAt(targetIdx);
          await prefs.setStringList('saved_routes_list', savedRaw);
          setState(() {
            _savedRoutes.removeAt(targetIdx);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Trasa byla odebrána z uložených.'), backgroundColor: Colors.orange),
          );
        }
      } else {
        // Add to list
        final serialized = _serializeRouteOption(option);
        savedRaw.add(jsonEncode(serialized));
        await prefs.setStringList('saved_routes_list', savedRaw);
        setState(() {
          _savedRoutes.add(option);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Trasa byla uložena na později.'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      debugPrint('Chyba při ukládání trasy: $e');
    }
  }

  Future<void> _deleteSavedRoute(int index) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedRaw = prefs.getStringList('saved_routes_list') ?? [];
      if (index >= 0 && index < savedRaw.length) {
        savedRaw.removeAt(index);
        await prefs.setStringList('saved_routes_list', savedRaw);
        setState(() {
          _savedRoutes.removeAt(index);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Trasa smazána.'), backgroundColor: Colors.orange),
        );
      }
    } catch (e) {
      debugPrint('Chyba při mazání trasy: $e');
    }
  }

  void _loadSavedRoute(Map<String, dynamic> option) {
    setState(() {
      _routeOptions = [option];
      _selectedOptionIndex = 0;
      _isLoadingRouteOptions = false;
    });
    _fetchActiveOptionGeometry();
  }

  String _generateShareCode() {
    final random = Random();
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return List.generate(6, (index) => chars[random.nextInt(chars.length)]).join();
  }

  Future<void> _shareRoute(Map<String, dynamic> option) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Color(0xFFBFFF00)),
      ),
    );

    try {
      final code = _generateShareCode();
      final serialized = _serializeRouteOption(option);
      serialized['created_at'] = FieldValue.serverTimestamp();

      await FirebaseFirestore.instance
          .collection('shared_routes')
          .doc(code)
          .set(serialized);

      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        _showShareSuccessDialog(code, option);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sdílení selhalo: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _showShareSuccessDialog(String code, Map<String, dynamic> option) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF263238),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'Trasa sdílena',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Sdílejte tento kód s přáteli, aby si mohli načíst stejnou trasu.',
              style: TextStyle(color: Colors.white70, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    code,
                    style: const TextStyle(
                      color: Color(0xFFBFFF00),
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, color: Colors.white70),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: code));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Kód zkopírován do schránky.')),
                      );
                    },
                    tooltip: 'Kopírovat kód',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Nebo nechte kamaráda naskenovat tento QR kód:',
              style: TextStyle(color: Colors.white70, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: SizedBox(
                width: 160,
                height: 160,
                child: QrImageView(
                  data: code,
                  version: QrVersions.auto,
                  size: 160.0,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Zavřít', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  Future<void> _loadSharedRouteByCode(String code) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Color(0xFFBFFF00)),
      ),
    );

    try {
      final doc = await FirebaseFirestore.instance
          .collection('shared_routes')
          .doc(code)
          .get()
          .timeout(const Duration(seconds: 8));

      if (!mounted) return;
      Navigator.pop(context); // Close loading indicator

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final routeOption = _deserializeRouteOption(data);

        setState(() {
          _routeOptions = [routeOption];
          _selectedOptionIndex = 0;
          _isLoadingRouteOptions = false;
        });

        _fetchActiveOptionGeometry();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Trasa "${routeOption['title']}" načtena z kódu $code!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Trasa s tímto kódem nebyla nalezena.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading indicator
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Chyba při načítání sdílené trasy: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _scanSharedRouteQr() async {
    final scannedData = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (context) => const QrScannerScreen()),
    );
    if (scannedData == null || scannedData.isEmpty) return;

    final code = scannedData.trim().toUpperCase();
    if (RegExp(r'^[A-Z0-9]{6}$').hasMatch(code)) {
      _loadSharedRouteByCode(code);
    } else {
      if (code.startsWith('{')) {
        try {
          final decoded = jsonDecode(scannedData);
          final Map<String, dynamic> mockOption = {
            'title': decoded['t'] ?? 'Načtená trasa',
            'description': 'Offline sdílená trasa',
            'waypoints': (decoded['p'] as List<dynamic>)
                .map((c) => LatLng((c[0] as num).toDouble(), (c[1] as num).toDouble()))
                .toList(),
            'surface': 'smíšený',
            'environment': 'příroda/město',
            'pois': ['Sdílené místo'],
            'trivia': [],
          };
          _loadSavedRoute(mockOption);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Offline trasa úspěšně načtena!'), backgroundColor: Colors.green),
          );
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Neplatný QR kód trasy: $e'), backgroundColor: Colors.redAccent),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Neplatný formát kódu trasy.'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  void _showSavedSharedRoutesBottomSheet() {
    final codeController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E272C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          final keyboardPadding = MediaQuery.of(context).viewInsets.bottom;
          return Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + keyboardPadding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Uložené a sdílené trasy',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: codeController,
                        style: const TextStyle(color: Colors.white),
                        textCapitalization: TextCapitalization.characters,
                        maxLength: 6,
                        decoration: const InputDecoration(
                          hintText: 'Zadejte 6místný kód trasy',
                          hintStyle: TextStyle(color: Colors.white30),
                          counterText: '',
                          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                          focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFBFFF00))),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.qr_code_scanner, color: Color(0xFFBFFF00)),
                      onPressed: () {
                        Navigator.pop(context);
                        _scanSharedRouteQr();
                      },
                      tooltip: 'Skenovat QR kód',
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFBFFF00),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        final code = codeController.text.trim().toUpperCase();
                        if (code.length == 6) {
                          Navigator.pop(context);
                          _loadSharedRouteByCode(code);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Zadejte platný 6místný kód.')),
                          );
                        }
                      },
                      child: const Text('Načíst', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Text(
                  'Moje uložené trasy',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                if (_savedRoutes.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24.0),
                    child: Text(
                      'Zatím nemáte žádné uložené trasy.',
                      style: TextStyle(color: Colors.white38, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  )
                else
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.4,
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _savedRoutes.length,
                      itemBuilder: (context, index) {
                        final opt = _savedRoutes[index];
                        final isBike = opt['is_bike'] as bool? ?? false;
                        final double dist = opt['estimatedDistance'] as double? ?? 0.0;
                        return Card(
                          color: const Color(0xFF263238),
                          margin: const EdgeInsets.only(bottom: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            leading: Icon(
                              isBike ? Icons.directions_bike_rounded : Icons.directions_walk_rounded,
                              color: const Color(0xFFBFFF00),
                            ),
                            title: Text(
                              opt['title'] as String? ?? 'Bez názvu',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              '${dist.toStringAsFixed(1)} km · ${opt['surface'] ?? 'smíšený'}',
                              style: const TextStyle(color: Colors.white54, fontSize: 12),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                              onPressed: () {
                                _deleteSavedRoute(index);
                                setSheetState(() {});
                              },
                              tooltip: 'Smazat',
                            ),
                            onTap: () {
                              Navigator.pop(context);
                              _loadSavedRoute(opt);
                            },
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _saveTodayRoutesCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = _getCacheKey();
      final todayStr = DateTime.now().toLocal().toString().substring(0, 10);

      final List<Map<String, dynamic>> serialized = _routeOptions.map((opt) => _serializeRouteOption(opt)).toList();
      await prefs.setString('today_route_date_$cacheKey', todayStr);
      await prefs.setString('today_route_options_$cacheKey', jsonEncode(serialized));
      debugPrint('Dnešní trasy uloženy do lokální cache pro klíč $cacheKey.');
    } catch (e) {
      debugPrint('Chyba při ukládání dnešních tras do lokální cache: $e');
    }
  }

  Future<void> _generateRoutes() async {
    if (widget.isAtoBMode && _destinationLocation == null) {
      setState(() {
        _isLoadingRouteOptions = false;
      });
      return;
    }
    final prefs = await SharedPreferences.getInstance();

    final todayStr = DateTime.now().toLocal().toString().substring(0, 10);
    final cacheKey = _getCacheKey();
    final cachedDate = prefs.getString('today_route_date_$cacheKey');
    if (cachedDate == todayStr) {
      final cachedOptionsJson = prefs.getString('today_route_options_$cacheKey');
      if (cachedOptionsJson != null) {
        try {
          final List<dynamic> parsed = jsonDecode(cachedOptionsJson);
          final List<Map<String, dynamic>> options = parsed.map((item) => _deserializeRouteOption(item as Map<String, dynamic>)).toList();
          if (options.isNotEmpty) {
            debugPrint('Dnes již vygenerováno pro tyto parametry. Načítám z lokální cache.');
            setState(() {
              _routeOptions = options;
              _isLoadingRouteOptions = false;
            });
            _fetchActiveOptionGeometry();
            return;
          }
        } catch (e) {
          debugPrint('Chyba při načítání lokální cache dnešních tras: $e');
        }
      }
    }

    final user = FirebaseAuth.instance.currentUser;
    final userEmail = user?.email?.toLowerCase() ?? '';
    final username = prefs.getString('username')?.toLowerCase() ?? '';
    final isReviewer = userEmail.contains('apple') || 
                       userEmail.contains('google') ||
                       userEmail.contains('test') ||
                       username.contains('reviewer') ||
                       username.contains('test');

    final isPremium = (prefs.getBool('isPremium') ?? false) || isReviewer;
    setState(() {
      _isPremium = isPremium;
    });

    int limit = 1;
    if (isReviewer) {
      limit = 99;
    } else if (isPremium) {
      final String tier = prefs.getString('premiumTier') ?? '25';
      if (tier == '25') {
        limit = 3;
      } else if (tier == '50') {
        limit = 4;
      } else if (tier == '100') {
        limit = 5;
      } else if (tier == '500') {
        limit = 6;
      } else {
        limit = 3;
      }
    }

    final String? cachedLimitDate = prefs.getString('route_generation_date');
    int currentCount = 0;
    if (cachedLimitDate == todayStr) {
      currentCount = prefs.getInt('route_generation_count') ?? 0;
    }

    if (currentCount >= limit) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF263238),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Row(
              children: [
                const Icon(Icons.lock_clock, color: Colors.amber, size: 28),
                const SizedBox(width: 10),
                Text(
                  isPremium ? 'Limit vyčerpán' : 'Limit vyčerpán',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ],
            ),
            content: Text(
              isPremium
                  ? 'Jako předplatitel ($limit trasy denně) jste již vyčerpal svůj denní limit pro generování AI tras. Pro navýšení limitu můžete přejít na vyšší úroveň předplatného v Obchodě!'
                  : 'Jako neprémiový uživatel můžete generovat trasy pouze jednou denně. Pro generování až 3 tras denně a odstranění reklam si aktivujte Premium za 25 Kč!',
              style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.45),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Zavřít', style: TextStyle(color: Colors.white70)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.lime,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ShopScreen()),
                  );
                },
                child: Text(
                  isPremium ? 'Zvýšit předplatné' : 'Koupit Premium',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
      }
      return;
    }

    if (!isPremium) {
      // Start full-screen loading ad countdown
      setState(() {
        _showSimulatedAd = true;
        _adCountdown = 10;
      });
      _adTimer?.cancel();
      _adTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        setState(() {
          if (_adCountdown > 1) {
            _adCountdown--;
          } else {
            _adCountdown = 0;
            timer.cancel();
          }
        });
      });
    }

    setState(() {
      _isLoadingRouteOptions = true;
      _routeOptions.clear();
      _polylines.clear();
      _markers.clear();
      _selectedOptionIndex = 0;
      _hoverFraction = null;
      _hoverElevationIndex = null;
    });

    // 1. Check Firestore cache first to save tokens and load instantly
    try {
      final cachedOptions = await _checkFirestoreCache();
      if (cachedOptions != null && cachedOptions.isNotEmpty) {
        debugPrint('Cache hit! Loaded ${cachedOptions.length} routes from Firestore.');
        await _incrementGenerationCount(prefs);
        setState(() {
          _routeOptions = cachedOptions;
          _isLoadingRouteOptions = false;
        });
        _fetchActiveOptionGeometry();
        return;
      }
    } catch (e) {
      debugPrint('Firestore cache check failed: $e');
    }

    final int count = _isPremium ? 10 : 3;
    String? aiError;
    final List<Map<String, dynamic>> options = [];

    if (widget.isAtoBMode) {
      try {
        if (RemoteConfigService().useMathFallback) {
          throw Exception("Vzdálená konfigurace (Remote Config) vynutila matematický generátor.");
        }
        final prompt = '''
Navrhni 3 trasy (start: lat:${widget.startLocation.latitude}, lng:${widget.startLocation.longitude}) -> (cíl: lat:${_destinationLocation!.latitude}, lng:${_destinationLocation!.longitude}).
Aktivita: ${_usingBike ? 'cyklistika' : 'pěší chůze/běh'}.
Pro každou navrhni 2-3 body (waypoints) na různých cestách.
Uveď reálné "kct_color" a "cyklo_number" nebo null.
Navrhni 3 velmi stručné kvízové otázky o okolí.

Odpověz POUZE JSON polem objektů:
[
  {
    "title": "Stručný název (max 3 slova)",
    "description": "Velmi krátký popis (max 1 věta, do 12 slov)",
    "waypoints": [{"lat": 50.1234, "lng": 14.5678}],
    "kct_color": "red"|"blue"|"green"|"yellow"|null,
    "cyklo_number": "č. 12"|null,
    "surface": "asfalt"|"lesní cesta"|"smíšený",
    "environment": "příroda"|"město",
    "pois": ["Místo (max 2 slova)", "Místo 2"],
    "trivia": [
      {"question": "Otázka (max 10 slov)", "answer": "Odpověď (max 5 slov)"},
      {"question": "Otázka (max 10 slov)", "answer": "Odpověď (max 5 slov)"},
      {"question": "Otázka (max 10 slov)", "answer": "Odpověď (max 5 slov)"}
    ]
  }
]
''';

        final model = FirebaseAI.googleAI().generativeModel(
          model: RemoteConfigService().geminiModel,
        );

        final response = await model.generateContent([
          Content.text(prompt),
        ]).timeout(const Duration(minutes: 5));

        final text = response.text;
        if (text != null && text.isNotEmpty) {
          String cleanedText = text.trim();
          if (cleanedText.startsWith('```')) {
            final firstNewline = cleanedText.indexOf('\n');
            if (firstNewline != -1) {
              cleanedText = cleanedText.substring(firstNewline + 1);
            }
            if (cleanedText.endsWith('```')) {
              cleanedText = cleanedText.substring(0, cleanedText.length - 3);
            }
            cleanedText = cleanedText.trim();
          }

          final parsed = jsonDecode(cleanedText) as List<dynamic>;
          for (var item in parsed) {
            final wpsRaw = (item['waypoints'] as List<dynamic>)
                .map((w) => LatLng((w['lat'] as num).toDouble(), (w['lng'] as num).toDouble()))
                .toList();

            final triviaList = (item['trivia'] as List<dynamic>?)?.map((t) {
              final tMap = t as Map<String, dynamic>;
              return {
                'question': tMap['question'] as String? ?? '',
                'answer': tMap['answer'] as String? ?? '',
              };
            }).toList() ?? [];

            options.add({
              'title': item['title'] as String? ?? 'Trasa k cíli',
              'description': item['description'] as String? ?? 'Zajímavá trasa',
              'waypoints': wpsRaw,
              'kct_color': item['kct_color'] as String?,
              'cyklo_number': item['cyklo_number'] as String?,
              'surface': item['surface'] as String? ?? 'smíšený',
              'environment': item['environment'] as String? ?? 'příroda',
              'pois': List<String>.from(item['pois'] ?? []),
              'trivia': triviaList,
              'trivia_question': triviaList.isNotEmpty ? triviaList[0]['question'] : 'Znáš historii tohoto místa?',
              'trivia_answer': triviaList.isNotEmpty ? triviaList[0]['answer'] : 'Více se dozvíš na trase!',
              'exactDistance': _distanceBetween(widget.startLocation, _destinationLocation!) / 1000.0,
              'estimatedDistance': _distanceBetween(widget.startLocation, _destinationLocation!) / 1000.0,
            });
          }
        }
      } catch (e) {
        debugPrint('Gemini A-to-B failed: $e');
        aiError = e.toString();
      }

      if (options.isEmpty) {
        // Fallback for A-to-B mode
        final start = widget.startLocation;
        final dest = _destinationLocation!;
        double dLat = dest.latitude - start.latitude;
        double dLng = dest.longitude - start.longitude;
        LatLng mid = LatLng(start.latitude + dLat / 2, start.longitude + dLng / 2);
        double pLat = -dLng;
        double pLng = dLat;

        options.addAll([
          {
            'title': 'Přímá trasa',
            'description': 'Nejkratší cesta k cíli.',
            'waypoints': [mid],
            'surface': 'smíšený',
            'environment': 'město/příroda',
            'pois': ['Hlavní cesta'],
            'trivia': [
              {
                'question': 'Víte, jaká je nejkratší cesta mezi dvěma body?',
                'answer': 'Přímka.'
              }
            ],
            'trivia_question': 'Víte, jaká je nejkratší cesta mezi dvěma body?',
            'trivia_answer': 'Přímka.',
            'estimatedDistance': _distanceBetween(start, dest) / 1000.0,
          },
          {
            'title': 'Trasa přes okolí (vlevo)',
            'description': 'Alternativní klidnější trasa s mírnou zacházkou vlevo.',
            'waypoints': [
              LatLng(start.latitude + dLat * 0.25 + pLat * 0.15, start.longitude + dLng * 0.25 + pLng * 0.15),
              LatLng(start.latitude + dLat * 0.75 + pLat * 0.15, start.longitude + dLng * 0.75 + pLng * 0.15),
            ],
            'surface': 'smíšený',
            'environment': 'příroda/klidná zóna',
            'pois': ['Klidná stezka'],
            'trivia': [
              {
                'question': 'Máte rádi objevování nových míst?',
                'answer': 'Tato trasa vám ukáže novou cestu.'
              }
            ],
            'trivia_question': 'Máte rádi objevování nových míst?',
            'trivia_answer': 'Tato trasa vám ukáže novou cestu.',
            'estimatedDistance': (_distanceBetween(start, dest) * 1.25) / 1000.0,
          },
          {
            'title': 'Trasa přes okolí (vpravo)',
            'description': 'Alternativní trasa s mírnou zacházkou vpravo.',
            'waypoints': [
              LatLng(start.latitude + dLat * 0.25 - pLat * 0.15, start.longitude + dLng * 0.25 - pLng * 0.15),
              LatLng(start.latitude + dLat * 0.75 - pLat * 0.15, start.longitude + dLng * 0.75 - pLng * 0.15),
            ],
            'surface': 'smíšený',
            'environment': 'příroda/klidná zóna',
            'pois': ['Alternativní stezka'],
            'trivia': [
              {
                'question': 'Jaké je vaše oblíbené zákoutí v této oblasti?',
                'answer': 'Tato trasa vás provede pravou stranou.'
              }
            ],
            'trivia_question': 'Jaké je vaše oblíbené zákoutí v této oblasti?',
            'trivia_answer': 'Tato trasa vás provede pravou stranou.',
            'estimatedDistance': (_distanceBetween(start, dest) * 1.25) / 1000.0,
          },
        ]);
      }
    } else {
      // Loop Mode: ORS-based round trip generation with fallback to mathematical generator
      bool orsFailed = false;
      final List<Map<String, dynamic>> tempOrsRoutes = [];

      for (int i = 0; i < count; i++) {
        final result = await _fetchOrsRoundTrip(
          widget.startLocation,
          _selectedTargetKm,
          i, // seed
          _usingBike,
        );
        if (result != null) {
          tempOrsRoutes.add(result);
        } else {
          orsFailed = true;
          break;
        }
      }

      final List<Map<String, dynamic>> preparedBaseRoutes = [];
      if (!orsFailed && tempOrsRoutes.length == count) {
        for (int i = 0; i < count; i++) {
          final r = tempOrsRoutes[i];
          final points = r['points'] as List<LatLng>;
          final List<LatLng> wps = [];
          if (points.length >= 4) {
            wps.add(points[(points.length * 0.25).round()]);
            wps.add(points[(points.length * 0.50).round()]);
            wps.add(points[(points.length * 0.75).round()]);
          } else {
            wps.addAll(points);
          }
          preparedBaseRoutes.add({
            'geometryPoints': points,
            'elevations': r['elevations'] as List<double>,
            'climb': r['climb'] as double,
            'exactDistance': r['distance'] as double,
            'estimatedDistance': r['distance'] as double,
            'eta': r['eta'] as int,
            'waypoints': wps,
          });
        }
      } else {
        // Local mathematical loop generator fallback
        final random = Random(widget.startLocation.latitude.toInt() + _selectedTargetKm.toInt());
        final double startBearing = random.nextDouble() * 360;

        for (int i = 0; i < count; i++) {
          final double distanceFactor = 0.85 + random.nextDouble() * 0.30;
          final double actualOptionKm = _selectedTargetKm * distanceFactor;
          final double bearing = startBearing + (i * (360 / count));
          final double segmentD = actualOptionKm / 3.0;

          final wp1 = _destinationFromDistanceBearing(widget.startLocation, segmentD * 0.85, bearing - 70.0);
          final wp2 = _destinationFromDistanceBearing(widget.startLocation, segmentD * 1.4, bearing);
          final wp3 = _destinationFromDistanceBearing(widget.startLocation, segmentD * 0.85, bearing + 70.0);

          preparedBaseRoutes.add({
            'waypoints': [wp1, wp2, wp3],
            'exactDistance': actualOptionKm,
            'estimatedDistance': actualOptionKm,
          });
        }
      }

      try {
        if (RemoteConfigService().useMathFallback) {
          throw Exception("Vynuceno nastavením Remote Config");
        }

        String routesDesc = '';
        for (int i = 0; i < preparedBaseRoutes.length; i++) {
          final r = preparedBaseRoutes[i];
          final wps = r['waypoints'] as List<LatLng>;
          final wpsStr = wps.map((w) => '(${w.latitude.toStringAsFixed(5)}, ${w.longitude.toStringAsFixed(5)})').join(', ');
          routesDesc += 'Okruh č. ${i + 1}: Začátek na (${widget.startLocation.latitude.toStringAsFixed(5)}, ${widget.startLocation.longitude.toStringAsFixed(5)}), průjezdní body: $wpsStr.\n';
        }

        final prompt = '''
Máš za úkol popsat a pojmenovat $count různých okružních turistických tras v České republice, které byly předem vygenerovány plánovačem.
Zde jsou jejich souřadnice a průjezdní body:
$routesDesc

Aktivita je ${_usingBike ? 'cyklistika' : 'pěší chůze/běh'}.
Typ okolí je ${_isUrban ? 'město' : 'vesnice/příroda'}.

Pro každou z těchto $count tras vymysli:
1. Vyber atraktivní, krátký český název (max 3 slova).
2. Napiš velmi krátký popis v češtině (max 1 věta, do 12 slov).
3. Seznam 2 až 3 konkrétních bodů zájmu (POIs) (max 2 slova každý).
4. Navrhni 3 velmi stručné kvízové otázky o okolí (otázka max 10 slov, odpověď max 5 slov).
DŮLEŽITÉ UPOZORNĚNÍ: Nikdy si nevymýšlej turistické značení KČT ani čísla cyklotras. Pole "kct_color" a "cyklo_number" vyplň hodnotou null, pokud si nejsi 100% jistý z reálných mapových dat.

Odpověz POUZE JSON polem objektů (přesně $count prvků):
[
  {
    "title": "Název trasy",
    "description": "Velmi krátký popis",
    "kct_color": "red" | "blue" | "green" | "yellow" | null,
    "cyklo_number": "č. 12" | null,
    "surface": "asfalt" | "lesní cesta" | "smíšený",
    "environment": "příroda" | "město",
    "pois": ["Místo 1", "Místo 2"],
    "trivia": [
      {"question": "Otázka 1", "answer": "Odpověď 1"},
      {"question": "Otázka 2", "answer": "Odpověď 2"},
      {"question": "Otázka 3", "answer": "Odpověď 3"}
    ]
  }
]
''';

        final model = FirebaseAI.googleAI().generativeModel(
          model: RemoteConfigService().geminiModel,
        );

        final response = await model.generateContent([
          Content.text(prompt),
        ]).timeout(const Duration(minutes: 5));

        final text = response.text;
        if (text != null && text.isNotEmpty) {
          String cleanedText = text.trim();
          if (cleanedText.startsWith('```')) {
            final firstNewline = cleanedText.indexOf('\n');
            if (firstNewline != -1) {
              cleanedText = cleanedText.substring(firstNewline + 1);
            }
            if (cleanedText.endsWith('```')) {
              cleanedText = cleanedText.substring(0, cleanedText.length - 3);
            }
            cleanedText = cleanedText.trim();
          }

          final parsed = jsonDecode(cleanedText) as List<dynamic>;
          for (int i = 0; i < parsed.length && i < preparedBaseRoutes.length; i++) {
            final item = parsed[i];
            final base = preparedBaseRoutes[i];
            
            final triviaList = (item['trivia'] as List<dynamic>?)?.map((t) {
              final tMap = t as Map<String, dynamic>;
              return {
                'question': tMap['question'] as String? ?? '',
                'answer': tMap['answer'] as String? ?? '',
              };
            }).toList() ?? [];

            options.add({
              ...base,
              'title': item['title'] as String? ?? 'Okruh ${i + 1}',
              'description': item['description'] as String? ?? 'Zajímavá okružní trasa',
              'kct_color': item['kct_color'] as String?,
              'cyklo_number': item['cyklo_number'] as String?,
              'surface': item['surface'] as String? ?? 'smíšený',
              'environment': item['environment'] as String? ?? 'příroda',
              'pois': List<String>.from(item['pois'] ?? []),
              'trivia': triviaList,
              'trivia_question': triviaList.isNotEmpty ? triviaList[0]['question'] : 'Znáš historii tohoto místa?',
              'trivia_answer': triviaList.isNotEmpty ? triviaList[0]['answer'] : 'Více se dozvíš na trase!',
            });
          }
        }
      } catch (e) {
        debugPrint('Gemini loop enrichment failed: $e');
        aiError = e.toString();
      }

      if (options.length < preparedBaseRoutes.length) {
        final List<String> names = _isUrban
            ? ['Městské uličky', 'Historické jádro', 'Zámecký park', 'Nábřežní promenáda', 'Rezidenční čtvrť', 'Městský lesopark', 'Parková stezka', 'Vyhlídka nad městem', 'Kavárenský okruh', 'Noční osvětlená trasa']
            : ['Lesní stezka', 'Polní okruh', 'Horská hřebenovka', 'Říční kaňon', 'Vesnické uličky', 'Kolem rybníka', 'Kopcovitý okruh', 'Vyhlídkový hřeben', 'Lesní obora', 'Okolo vinic'];

        final List<String> descs = _isUrban
            ? ['85% po chodnících městské zástavby', 'Kolem historických památek a náměstí', 'Příjemný okruh zeleným zámeckým parkem', 'Rovná, asfaltová trasa podél řeky', 'Klidný okruh vilovou čtvrtí', 'Kombinace zástavby a přírodního lesoparku', 'Krásná zelená zóna v srdci města', 'Náročnější stoupání s výhledem na celé město', 'Trasa vedoucí kolem kaváren a bister', 'Po osvětlených hlavních ulicích města']
            : ['90% cesty lesem a po přírodním podkladu', 'Klidný okruh mezi poli a polními cestami', 'Trasa přes kopce s výhledy do kraje', 'Stezka podél potoka hlukým lesním údolím', 'Klidná cesta venkovskou zástavbou', 'Rovný okruh kolem místních rybníků', 'Zpevněné lesní cesty s větším převýšením', 'Hřebenová cesta po okolních kopcích', 'Cesta podél obory s lesní zvěří', 'Trasa mezi malebnými vinohrady'];

        for (int i = options.length; i < preparedBaseRoutes.length; i++) {
          final base = preparedBaseRoutes[i];
          options.add({
            ...base,
            'title': names[i % names.length],
            'description': descs[i % descs.length],
            'surface': _isUrban ? 'asfalt' : 'lesní cesta',
            'environment': _isUrban ? 'město' : 'příroda',
            'pois': ['Vyhlídkové místo', 'Klidné spočinutí'],
            'trivia': [
              {
                'question': 'Víte, že tato trasa je navržena pro maximální klid od dopravy?',
                'answer': 'Trasa se vyhýbá hlavním silničním tahům.'
              }
            ],
            'trivia_question': 'Víte, že tato trasa je navržena pro maximální klid od dopravy?',
            'trivia_answer': 'Trasa se vyhýbá hlavním silničním tahům.',
          });
        }
      }

      if (orsFailed) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(aiError != null
                    ? 'Načítání ORS okruhů selhalo ($aiError). Používám záložní matematický generátor.'
                    : 'Načítání ORS okruhů selhalo. Používám záložní matematický generátor.'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        });
      }
    }

    if (options.isNotEmpty) {
      // 4. Save newly generated routes to Firestore cache
      await _saveToFirestoreCache(options);
    }

    await _incrementGenerationCount(prefs);

    setState(() {
      _routeOptions = options;
      _isLoadingRouteOptions = false;
    });

    await _saveTodayRoutesCache();

    _fetchActiveOptionGeometry();
  }

  Future<void> _incrementGenerationCount(SharedPreferences prefs) async {
    final todayStr = DateTime.now().toLocal().toString().substring(0, 10);
    final String? cachedDate = prefs.getString('route_generation_date');
    int currentCount = 0;
    if (cachedDate == todayStr) {
      currentCount = prefs.getInt('route_generation_count') ?? 0;
    }
    await prefs.setString('route_generation_date', todayStr);
    await prefs.setInt('route_generation_count', currentCount + 1);
  }

  Future<List<Map<String, dynamic>>?> _checkFirestoreCache() async {
    try {
      final start = widget.startLocation;
      final querySnapshot = await FirebaseFirestore.instance
          .collection('cached_ai_routes')
          .where('start_lat', isGreaterThanOrEqualTo: start.latitude - 0.0045)
          .where('start_lat', isLessThanOrEqualTo: start.latitude + 0.0045)
          .get()
          .timeout(const Duration(seconds: 5));

      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        final double lng = (data['start_lng'] as num).toDouble();
        if ((lng - start.longitude).abs() > 0.0045) continue;

        final bool isAtoB = data['is_a_to_b'] as bool? ?? false;
        if (isAtoB != widget.isAtoBMode) continue;

        final bool isBike = data['is_bike'] as bool? ?? false;
        if (isBike != _usingBike) continue;

        if (widget.isAtoBMode) {
          if (_destinationLocation == null) continue;
          final double? destLat = (data['destination_lat'] as num?)?.toDouble();
          final double? destLng = (data['destination_lng'] as num?)?.toDouble();
          if (destLat == null || destLng == null) continue;
          if ((destLat - _destinationLocation!.latitude).abs() > 0.0045) continue;
          if ((destLng - _destinationLocation!.longitude).abs() > 0.0045) continue;
        } else {
          final bool isUrban = data['is_urban'] as bool? ?? false;
          if (isUrban != _isUrban) continue;

          final double targetDist = (data['target_distance'] as num?)?.toDouble() ?? 0.0;
          if ((targetDist - _selectedTargetKm).abs() > 1.0) continue;
        }

        // We found a cache hit!
        final rawOptions = data['options'] as List<dynamic>?;
        if (rawOptions == null || rawOptions.isEmpty) continue;

        final List<Map<String, dynamic>> options = [];
        for (var optRaw in rawOptions) {
          final opt = optRaw as Map<String, dynamic>;
          final wpsRaw = opt['waypoints'] as List<dynamic>? ?? [];
          final List<LatLng> wps = wpsRaw
              .map((w) => LatLng((w['lat'] as num).toDouble(), (w['lng'] as num).toDouble()))
              .toList();

          List<LatLng>? geomPoints;
          if (opt['geometryPoints'] != null) {
            final geomRaw = opt['geometryPoints'] as List<dynamic>;
            geomPoints = geomRaw
                .map((g) => LatLng((g['lat'] as num).toDouble(), (g['lng'] as num).toDouble()))
                .toList();
          }

          final List<double> elevations = (opt['elevations'] as List<dynamic>?)
                  ?.map((e) => (e as num).toDouble())
                  .toList() ??
              [];

          List<Map<String, dynamic>> triviaList = [];
          if (opt['trivia'] != null) {
            final triviaRaw = opt['trivia'] as List<dynamic>;
            triviaList = triviaRaw.map((t) {
              final tMap = t as Map<String, dynamic>;
              return {
                'question': tMap['question'] as String? ?? '',
                'answer': tMap['answer'] as String? ?? '',
              };
            }).toList();
          } else if (opt['trivia_question'] != null) {
            triviaList = [
              {
                'question': opt['trivia_question'] as String? ?? '',
                'answer': opt['trivia_answer'] as String? ?? '',
              }
            ];
          }

          options.add({
            'title': opt['title'] as String? ?? '',
            'description': opt['description'] as String? ?? '',
            'waypoints': wps,
            if (geomPoints != null) 'geometryPoints': geomPoints,
            'elevations': elevations,
            'climb': (opt['climb'] as num?)?.toDouble() ?? 0.0,
            'exactDistance': (opt['exactDistance'] as num?)?.toDouble() ?? 0.0,
            'estimatedDistance': (opt['estimatedDistance'] as num?)?.toDouble() ?? 0.0,
            'eta': (opt['eta'] as num?)?.toInt() ?? 0,
            'kct_color': opt['kct_color'] as String?,
            'cyklo_number': opt['cyklo_number'] as String?,
            'surface': opt['surface'] as String? ?? 'smíšený',
            'environment': opt['environment'] as String? ?? 'příroda',
            'pois': List<String>.from(opt['pois'] ?? []),
            'trivia': triviaList,
            'trivia_question': triviaList.isNotEmpty ? triviaList[0]['question'] : 'Znáš historii tohoto místa?',
            'trivia_answer': triviaList.isNotEmpty ? triviaList[0]['answer'] : 'Více se dozvíš na trase!',
          });
        }
        return options;
      }
    } catch (e) {
      debugPrint('Error checking Firestore cache: $e');
    }
    return null;
  }

  Future<void> _saveToFirestoreCache(List<Map<String, dynamic>> options) async {
    try {
      final List<Map<String, dynamic>> optionsData = [];
      for (var opt in options) {
        final List<LatLng> wps = opt['waypoints'] as List<LatLng>;
        final List<LatLng>? geom = opt['geometryPoints'] as List<LatLng>?;
        final List<double> elev = opt['elevations'] as List<double>? ?? [];

        List<Map<String, dynamic>> triviaData = [];
        if (opt['trivia'] != null) {
          final triviaRaw = opt['trivia'] as List<dynamic>;
          triviaData = triviaRaw.map((t) {
            final tMap = t as Map<String, dynamic>;
            return {
              'question': tMap['question'] as String? ?? '',
              'answer': tMap['answer'] as String? ?? '',
            };
          }).toList();
        } else if (opt['trivia_question'] != null) {
          triviaData = [
            {
              'question': opt['trivia_question'] as String? ?? '',
              'answer': opt['trivia_answer'] as String? ?? '',
            }
          ];
        }

        optionsData.add({
          'title': opt['title'] as String? ?? '',
          'description': opt['description'] as String? ?? '',
          'waypoints': wps.map((w) => {'lat': w.latitude, 'lng': w.longitude}).toList(),
          if (geom != null)
            'geometryPoints': geom.map((g) => {'lat': g.latitude, 'lng': g.longitude}).toList(),
          'elevations': elev,
          'climb': opt['climb'] ?? 0.0,
          'exactDistance': opt['exactDistance'] ?? 0.0,
          'estimatedDistance': opt['estimatedDistance'] ?? 0.0,
          'eta': opt['eta'] ?? 0,
          'kct_color': opt['kct_color'],
          'cyklo_number': opt['cyklo_number'],
          'surface': opt['surface'] ?? 'smíšený',
          'environment': opt['environment'] ?? 'příroda',
          'pois': opt['pois'] ?? [],
          'trivia': triviaData,
        });
      }

      await FirebaseFirestore.instance.collection('cached_ai_routes').add({
        'start_lat': widget.startLocation.latitude,
        'start_lng': widget.startLocation.longitude,
        'target_distance': _selectedTargetKm,
        'is_bike': _usingBike,
        'is_urban': _isUrban,
        'is_a_to_b': widget.isAtoBMode,
        'destination_lat': _destinationLocation?.latitude,
        'destination_lng': _destinationLocation?.longitude,
        'created_at': FieldValue.serverTimestamp(),
        'options': optionsData,
      });
    } catch (e) {
      debugPrint('Error saving to Firestore cache: $e');
    }
  }

  Future<Map<String, dynamic>?> _fetchOrsRoundTrip(
      LatLng start, double targetDistanceKm, int seed, bool isBike) async {
    final String apiKey = RemoteConfigService().openRouteServiceApiKey;
    if (apiKey.isEmpty) {
      debugPrint('ORS API key is empty.');
      return null;
    }

    final String profile = isBike ? 'cycling-regular' : 'foot-walking';
    final Uri url = Uri.parse('https://api.openrouteservice.org/v2/directions/$profile/geojson');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': apiKey,
        },
        body: jsonEncode({
          'coordinates': [
            [start.longitude, start.latitude]
          ],
          'options': {
            'round_trip': {
              'length': (targetDistanceKm * 1000).toInt(),
              'points': 4,
              'seed': seed,
            }
          },
          'elevation': true,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final features = data['features'] as List<dynamic>?;
        if (features != null && features.isNotEmpty) {
          final feature = features[0] as Map<String, dynamic>;
          final geometry = feature['geometry'] as Map<String, dynamic>?;
          final properties = feature['properties'] as Map<String, dynamic>?;
          
          if (geometry != null && geometry['coordinates'] != null) {
            final coords = geometry['coordinates'] as List<dynamic>;
            final List<LatLng> points = [];
            final List<double> elevations = [];
            for (var c in coords) {
              final double lng = (c[0] as num).toDouble();
              final double lat = (c[1] as num).toDouble();
              points.add(LatLng(lat, lng));
              if (c.length > 2) {
                elevations.add((c[2] as num).toDouble());
              }
            }

            final summary = properties?['summary'] as Map<String, dynamic>?;
            final double distanceKm = (summary?['distance'] as num? ?? (targetDistanceKm * 1000)).toDouble() / 1000.0;
            final double durationMin = (summary?['duration'] as num? ?? 0.0).toDouble() / 60.0;

            // Calculate total climb from elevations
            double climb = 0.0;
            for (int i = 1; i < elevations.length; i++) {
              final diff = elevations[i] - elevations[i - 1];
              if (diff > 0) climb += diff;
            }

            return {
              'points': points,
              'elevations': elevations,
              'climb': climb,
              'distance': distanceKm,
              'eta': durationMin.round(),
            };
          }
        }
      } else {
        debugPrint('ORS API failed with status code ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('ORS API call failed: $e');
    }
    return null;
  }

  LatLng _destinationFromDistanceBearing(LatLng start, double distanceKm, double bearingDegrees) {
    const double R = 6371.0;
    final double bearingRad = bearingDegrees * pi / 180.0;
    final double lat1Rad = start.latitude * pi / 180.0;
    final double lon1Rad = start.longitude * pi / 180.0;

    final double lat2Rad = asin(sin(lat1Rad) * cos(distanceKm / R) +
        cos(lat1Rad) * sin(distanceKm / R) * cos(bearingRad));
    final double lon2Rad = lon1Rad +
        atan2(sin(bearingRad) * sin(distanceKm / R) * cos(lat1Rad),
            cos(distanceKm / R) - sin(lat1Rad) * sin(lat2Rad));

    return LatLng(lat2Rad * 180.0 / pi, lon2Rad * 180.0 / pi);
  }

  double _bearingBetween(LatLng start, LatLng end) {
    final lat1 = start.latitude * pi / 180.0;
    final lon1 = start.longitude * pi / 180.0;
    final lat2 = end.latitude * pi / 180.0;
    final lon2 = end.longitude * pi / 180.0;

    final dLon = lon2 - lon1;
    final y = sin(dLon) * cos(lat2);
    final x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon);
    final brng = atan2(y, x) * 180.0 / pi;
    return (brng + 360.0) % 360.0;
  }

  double _distanceBetween(LatLng start, LatLng end) {
    final lat1 = start.latitude * pi / 180.0;
    final lon1 = start.longitude * pi / 180.0;
    final lat2 = end.latitude * pi / 180.0;
    final lon2 = end.longitude * pi / 180.0;

    final dLat = lat2 - lat1;
    final dLon = lon2 - lon1;

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return 6371000.0 * c; // in meters
  }

  Future<void> _fetchActiveOptionGeometry() async {
    if (_routeOptions.isEmpty) return;

    setState(() {
      _isLoadingRouteGeometry = true;
      _polylines.clear();
      _markers.clear();
    });

    final option = _routeOptions[_selectedOptionIndex];
    final start = widget.startLocation;
    final waypoints = option['waypoints'] as List<LatLng>;

    // If we already have the pre-calculated geometry from ORS, use it directly!
    if (option.containsKey('geometryPoints')) {
      final List<LatLng> points = option['geometryPoints'] as List<LatLng>;
      _fetchSimulatedWeather();
      setState(() {
        _currentRoutePoints = points;
        _polylines.add(Polyline(
          polylineId: const PolylineId('preview_route'),
          color: _usingBike ? const Color(0xFFBFFF00) : const Color(0xFF5C9E00),
          width: 6,
          points: points,
          geodesic: true,
        ));
        _markers.add(Marker(
          markerId: const MarkerId('start_marker'),
          position: start,
          infoWindow: InfoWindow(title: widget.isAtoBMode ? 'Start' : 'Start / Cíl okruhu'),
          icon: BitmapDescriptor.defaultMarkerWithHue(widget.isAtoBMode ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueOrange),
        ));
        _isLoadingRouteGeometry = false;
      });
      _fitMapBounds(points);
      return;
    }

    // Call OSRM API to fetch exact road geometry
    try {
      final List<String> coords = [
        '${start.longitude},${start.latitude}',
        ...waypoints.map((w) => '${w.longitude},${w.latitude}'),
        if (widget.isAtoBMode && _destinationLocation != null)
          '${_destinationLocation!.longitude},${_destinationLocation!.latitude}'
        else
          '${start.longitude},${start.latitude}'
      ];
      final service = _usingBike ? 'routed-bike' : 'routed-foot';
      final url = Uri.parse('https://routing.openstreetmap.de/$service/route/v1/driving/${coords.join(';')}?overview=full&geometries=geojson');
      final res = await http.get(url).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        if (data['code'] == 'Ok' && data['routes'] != null && (data['routes'] as List).isNotEmpty) {
          final route = data['routes'][0];
          final geometry = route['geometry']['coordinates'] as List<dynamic>;
          final List<LatLng> points = geometry
              .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
              .toList();

          final double realDistance = (route['distance'] as num).toDouble() / 1000.0;
          final int eta = (route['duration'] as num).round() ~/ 60;

          // Fetch elevations asynchronously
          RouteElevationService().fetchElevationProfile(points).then((result) {
            final elevations = result['elevations'] as List<double>? ?? [];
            if (mounted && elevations.isNotEmpty) {
              setState(() {
                _routeOptions[_selectedOptionIndex]['elevations'] = elevations;
                _routeOptions[_selectedOptionIndex]['climb'] = result['climb'] as double? ?? 0.0;
              });
              _saveTodayRoutesCache();
            }
          });

          // Fetch simulated weather
          _fetchSimulatedWeather();

          setState(() {
            _currentRoutePoints = points;
            _routeOptions[_selectedOptionIndex]['exactDistance'] = realDistance;
            _routeOptions[_selectedOptionIndex]['eta'] = eta;
            _routeOptions[_selectedOptionIndex]['geometryPoints'] = points;

            _polylines.add(Polyline(
              polylineId: const PolylineId('preview_route'),
              color: _usingBike ? const Color(0xFFBFFF00) : const Color(0xFF5C9E00),
              width: 6,
              points: points,
              geodesic: true,
            ));

            _markers.add(Marker(
              markerId: const MarkerId('start_marker'),
              position: start,
              infoWindow: InfoWindow(title: widget.isAtoBMode ? 'Start' : 'Start / Cíl okruhu'),
              icon: BitmapDescriptor.defaultMarkerWithHue(widget.isAtoBMode ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueOrange),
            ));

            if (widget.isAtoBMode && _destinationLocation != null) {
              _markers.add(Marker(
                markerId: const MarkerId('dest_marker'),
                position: _destinationLocation!,
                infoWindow: const InfoWindow(title: 'Cíl'),
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
              ));
            }

            _isLoadingRouteGeometry = false;
          });

          _saveTodayRoutesCache();
          _fitMapBounds(points);
          return;
        }
      }
    } catch (e) {
      debugPrint('OSRM routing failed: $e');
    }

    // Fallback if OSRM fails
    setState(() {
      _currentRoutePoints = waypoints;
      _routeOptions[_selectedOptionIndex]['exactDistance'] = option['estimatedDistance'] as double;
      _routeOptions[_selectedOptionIndex]['eta'] = _usingBike
          ? ((option['estimatedDistance'] as double) * 3.5).round()
          : ((option['estimatedDistance'] as double) * 12).round();

      _polylines.add(Polyline(
        polylineId: const PolylineId('preview_route'),
        color: _usingBike ? const Color(0xFFBFFF00) : const Color(0xFF5C9E00),
        width: 6,
        points: _currentRoutePoints,
        geodesic: true,
      ));

      _markers.add(Marker(
        markerId: const MarkerId('start_marker'),
        position: start,
        infoWindow: InfoWindow(title: widget.isAtoBMode ? 'Start' : 'Start / Cíl okruhu'),
        icon: BitmapDescriptor.defaultMarkerWithHue(widget.isAtoBMode ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueOrange),
      ));

      if (widget.isAtoBMode && _destinationLocation != null) {
        _markers.add(Marker(
          markerId: const MarkerId('dest_marker'),
          position: _destinationLocation!,
          infoWindow: const InfoWindow(title: 'Cíl'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ));
      }

      _isLoadingRouteGeometry = false;
    });
    _fitMapBounds(_currentRoutePoints);
  }

  void _fetchSimulatedWeather() {
    final random = Random();
    final temp = 14.0 + random.nextInt(12);
    final icons = ['☀️', '⛅', '☁️', '🌦️'];
    final descs = ['Jasno', 'Polojasno', 'Zataženo', 'Přeháňky'];
    final idx = random.nextInt(icons.length);

    if (mounted && _selectedOptionIndex < _routeOptions.length) {
      setState(() {
        _routeOptions[_selectedOptionIndex]['temp'] = temp;
        _routeOptions[_selectedOptionIndex]['weatherIcon'] = icons[idx];
        _routeOptions[_selectedOptionIndex]['weatherDesc'] = descs[idx];
      });
    }
  }

  void _fitMapBounds(List<LatLng> points) {
    if (_mapController == null || points.isEmpty) return;

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
  }



  void _showTriviaDialog(Map<String, dynamic> option) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF263238),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.lightbulb_outline_rounded, color: Color(0xFFBFFF00), size: 28),
            SizedBox(width: 10),
            Text('AI Kvíz z okolí', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              option['trivia_question'] as String,
              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold, height: 1.45),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('ODPOVĚĎ:', style: TextStyle(color: Color(0xFFBFFF00), fontWeight: FontWeight.w900, fontSize: 11)),
                  const SizedBox(height: 6),
                  Text(option['trivia_answer'] as String, style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13.5)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Super, jdeme na to!', style: TextStyle(color: Color(0xFFBFFF00), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _onSearchChanged(String val) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _fetchNominatimSuggestions(val);
    });
  }

  Future<void> _fetchNominatimSuggestions(String input) async {
    if (input.isEmpty || input.trim().length < 2) {
      setState(() {
        _suggestions = [];
        _showSuggestionsOverlay = false;
      });
      return;
    }

    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': input,
        'format': 'json',
        'limit': '5',
        'addressdetails': '1',
        'countrycodes': 'cz',
        'accept-language': 'cs',
      });
      final response = await http.get(
        uri,
        headers: {'User-Agent': 'HejbejSeApp/1.0'},
      ).timeout(
        const Duration(seconds: 8),
        onTimeout: () => throw Exception('Nominatim timeout'),
      );

      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List<dynamic>;
        setState(() {
          _suggestions = list
              .whereType<Map<String, dynamic>>()
              .map(PlacePrediction.fromNominatimJson)
              .toList();
          _showSuggestionsOverlay = true;
        });
        return;
      }
    } catch (e) {
      debugPrint('Nominatim suggestion error: $e');
    }

    setState(() {
      _suggestions = [];
      _showSuggestionsOverlay = false;
    });
  }

  void _onSuggestionSelected(PlacePrediction sug) {
    if (sug.lat != null && sug.lng != null) {
      setState(() {
        _destinationLocation = LatLng(sug.lat!, sug.lng!);
        _searchController.text = sug.description;
        _showSuggestionsOverlay = false;
        _suggestions.clear();
      });
      _generateRoutes();
      FocusScope.of(context).unfocus();
    }
  }

  Future<void> _onMapTapped(LatLng latLng) async {
    setState(() {
      _destinationLocation = latLng;
      _isLoadingRouteGeometry = true;
      _isLoadingRouteOptions = true;
      _suggestions.clear();
      _showSuggestionsOverlay = false;
    });

    // Start reverse geocoding to update address text
    try {
      final url = Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?format=json&lat=${latLng.latitude}&lon=${latLng.longitude}&zoom=18&addressdetails=1&accept-language=cs');
      final response = await http.get(
        url,
        headers: {'User-Agent': 'HejbejSeApp/1.0'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final displayName = data['display_name'] as String?;
        if (displayName != null) {
          setState(() {
            _searchController.text = displayName;
          });
        }
      }
    } catch (e) {
      debugPrint('Reverse geocoding failed: $e');
      setState(() {
        _searchController.text = '${latLng.latitude.toStringAsFixed(5)}, ${latLng.longitude.toStringAsFixed(5)}';
      });
    }

    _generateRoutes();
  }

  @override
  Widget build(BuildContext context) {
    final selectedOption = _routeOptions.isNotEmpty ? _routeOptions[_selectedOptionIndex] : null;
    final double? temp = selectedOption != null ? selectedOption['temp'] as double? : null;
    final String? weatherDesc = selectedOption != null ? selectedOption['weatherDesc'] as String? : null;
    final String? weatherIcon = selectedOption != null ? selectedOption['weatherIcon'] as String? : null;
    final List<double>? elevations = selectedOption != null ? (selectedOption['elevations'] as List<dynamic>?)?.cast<double>() : null;
    final double climb = selectedOption != null ? (selectedOption['climb'] as double? ?? 0.0) : 0.0;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: widget.isAtoBMode
          ? null
          : AppBar(
              title: const Text('Vybrat okruh v okolí', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.5)),
              backgroundColor: const Color(0xFF263238).withOpacity(0.95),
              foregroundColor: Colors.white,
              elevation: 0,
              centerTitle: true,
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(bottom: Radius.circular(20))),
            ),
      backgroundColor: const Color(0xFF161C20),
      body: Stack(
        children: [
          // 1. Fullscreen Google Map
          Positioned.fill(
            child: GoogleMap(
              onMapCreated: (c) {
                _mapController = c;
                if (_currentRoutePoints.isNotEmpty) {
                  _fitMapBounds(_currentRoutePoints);
                }
              },
              initialCameraPosition: CameraPosition(
                target: widget.startLocation,
                zoom: 14,
              ),
              mapType: _mapType,
              polylines: _polylines,
              markers: {
                ..._markers,
                if (_hoverElevationIndex != null && _hoverElevationIndex! < _currentRoutePoints.length)
                  Marker(
                    markerId: const MarkerId('hover_marker'),
                    position: _currentRoutePoints[_hoverElevationIndex!],
                    infoWindow: InfoWindow(
                      title: 'Pozice na profilu',
                      snippet: selectedOption != null && elevations != null && elevations.isNotEmpty
                          ? 'Výška: ${elevations[(_hoverFraction! * (elevations.length - 1)).round()].round()} m'
                          : '',
                    ),
                    icon: BitmapDescriptor.defaultMarkerWithHue(80.0),
                  ),
              },
              myLocationEnabled: true,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
              onTap: widget.isAtoBMode ? _onMapTapped : null,
            ),
          ),

          // Loading Overlay for generating options
          if (_isLoadingRouteOptions)
            Container(
              color: Colors.black54,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: Color(0xFFBFFF00)),
                    const SizedBox(height: 16),
                    Text(
                      widget.isAtoBMode ? 'AI generuje trasy k cíli...' : 'AI generuje okruhy v okolí...',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),

          // 2. Map Overlays (Activity Toggle, MapType Layer Switcher)
          Positioned(
            top: widget.isAtoBMode
                ? MediaQuery.of(context).padding.top + 80
                : MediaQuery.of(context).padding.top + kToolbarHeight + 16,
            right: 16,
            child: Column(
              children: [
                // Map Type Selector
                FloatingActionButton.small(
                  heroTag: 'map_type_fab',
                  onPressed: _toggleMapType,
                  backgroundColor: const Color(0xFF263238),
                  foregroundColor: Colors.white,
                  child: const Icon(Icons.layers_outlined),
                ),
                const SizedBox(height: 8),
                // Activity Switcher
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF263238),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2))],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.directions_walk_rounded, color: !_usingBike ? const Color(0xFFBFFF00) : Colors.white60),
                        onPressed: () {
                          if (_usingBike) {
                            setState(() {
                              _usingBike = false;
                              _selectedTargetKm = 8.0;
                            });
                            _generateRoutes();
                          }
                        },
                      ),
                      Container(width: 24, height: 1, color: Colors.white12),
                      IconButton(
                        icon: Icon(Icons.directions_bike_rounded, color: _usingBike ? const Color(0xFFBFFF00) : Colors.white60),
                        onPressed: () {
                          if (!_usingBike) {
                            setState(() {
                              _usingBike = true;
                              _selectedTargetKm = 25.0;
                            });
                            _generateRoutes();
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'saved_routes_fab',
                  onPressed: _showSavedSharedRoutesBottomSheet,
                  backgroundColor: const Color(0xFF263238),
                  foregroundColor: Colors.white,
                  child: const Icon(Icons.bookmark_outline_rounded),
                ),
              ],
            ),
          ),

          // 3. Top Distance Chips (overlaying map)
          if (!widget.isAtoBMode)
            Positioned(
              top: MediaQuery.of(context).padding.top + kToolbarHeight + 16,
              left: 0,
              right: 80,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: (_usingBike ? _bikeDistances : _walkDistances).map((target) {
                    final isSelected = target == _selectedTargetKm;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        label: Text('${target.toInt()} km'),
                        selected: isSelected,
                        onSelected: (_) {
                          setState(() {
                            _selectedTargetKm = target;
                          });
                          _generateRoutes();
                        },
                        selectedColor: const Color(0xFFBFFF00),
                        backgroundColor: const Color(0xFF263238).withOpacity(0.95),
                        labelStyle: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.black : Colors.white70,
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

          // Custom Search header for A-to-B mode
          if (widget.isAtoBMode)
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              left: 12,
              right: 12,
              child: Card(
                elevation: 6,
                color: const Color(0xFF263238).withOpacity(0.95),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Colors.white12, width: 1),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          style: const TextStyle(color: Colors.white, fontSize: 15),
                          decoration: const InputDecoration(
                            hintText: 'Zadejte cíl trasy...',
                            hintStyle: TextStyle(color: Colors.white54, fontSize: 15),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                          onChanged: _onSearchChanged,
                        ),
                      ),
                      if (_searchController.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.clear, color: Colors.white54, size: 20),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _suggestions.clear();
                              _showSuggestionsOverlay = false;
                            });
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ),

          // Nominatim suggestion list overlay
          if (widget.isAtoBMode && _showSuggestionsOverlay && _suggestions.isNotEmpty)
            Positioned(
              top: MediaQuery.of(context).padding.top + 74,
              left: 20,
              right: 20,
              child: Card(
                elevation: 8,
                color: const Color(0xFF263238),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Colors.white10, width: 1),
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 250),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: _suggestions.length,
                    itemBuilder: (context, index) {
                      final sug = _suggestions[index];
                      return ListTile(
                        leading: const Icon(Icons.location_on_outlined, color: Color(0xFFBFFF00)),
                        title: Text(
                          sug.description,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => _onSuggestionSelected(sug),
                      );
                    },
                  ),
                ),
              ),
            ),

          // Welcome card for A-to-B Mode when no destination is defined
          if (widget.isAtoBMode && _destinationLocation == null && _routeOptions.isEmpty)
            Positioned(
              bottom: 40,
              left: 16,
              right: 16,
              child: Card(
                color: const Color(0xFF263238).withOpacity(0.95),
                elevation: 6,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: const BorderSide(color: Colors.white12, width: 1.5),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.map_outlined, color: Color(0xFFBFFF00), size: 40),
                      const SizedBox(height: 12),
                      const Text(
                        'Cesta do cíle',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Zadejte cíl trasy do vyhledávače nahoře, nebo klikněte kdekoli na mapě pro určení cíle.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 4. Bottom PageView Card Carousel
          if (_routeOptions.isNotEmpty)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 310,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.transparent, Colors.black.withOpacity(0.75)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    SizedBox(
                      height: 270,
                      child: PageView.builder(
                        controller: _pageController,
                        itemCount: _routeOptions.length,
                        itemBuilder: (context, idx) {
                          final option = _routeOptions[idx];
                          final double realKm = option['exactDistance'] as double;
                          final int? eta = option['eta'] as int?;
                          final String? kctColor = option['kct_color'] as String?;
                          final String? cykloNum = option['cyklo_number'] as String?;
                          final String surface = option['surface'] as String;

                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 12, offset: Offset(0, 4))],
                            ),
                            child: Stack(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Header with Title & Badge
                                      GestureDetector(
                                        onTap: () => _showRouteDetailsDialog(option),
                                        behavior: HitTestBehavior.opaque,
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      option['title'] as String,
                                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF263238)),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  const Icon(Icons.info_outline, size: 16, color: Colors.black45),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            if (kctColor != null) _buildKctBadge(kctColor),
                                            if (cykloNum != null) _buildCykloBadge(cykloNum),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      // Description
                                      GestureDetector(
                                        onTap: () => _showRouteDetailsDialog(option),
                                        behavior: HitTestBehavior.opaque,
                                        child: Text(
                                          _isPremium 
                                              ? option['description'] as String
                                              : '${option['description'] as String} (Více informací...)',
                                          style: TextStyle(
                                            color: _isPremium ? Colors.black54 : Colors.amber.shade900,
                                            fontSize: 12,
                                            fontWeight: _isPremium ? FontWeight.normal : FontWeight.w600,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      // Row of statistics (distance, ETA, weather, surface)
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              const Icon(Icons.straighten_rounded, size: 14, color: Colors.black54),
                                              const SizedBox(width: 4),
                                              Text('${realKm.toStringAsFixed(1)} km', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                              const SizedBox(width: 12),
                                              const Icon(Icons.schedule_rounded, size: 14, color: Colors.black54),
                                              const SizedBox(width: 4),
                                              Text(eta != null ? '$eta min' : '-- min', style: const TextStyle(fontSize: 12)),
                                              const SizedBox(width: 12),
                                              const Icon(Icons.layers_rounded, size: 14, color: Colors.black54),
                                              const SizedBox(width: 4),
                                              Text(surface, style: const TextStyle(fontSize: 11, color: Colors.black54)),
                                            ],
                                          ),
                                          // Weather
                                          if (temp != null && weatherIcon != null && idx == _selectedOptionIndex)
                                            Row(
                                              children: [
                                                Text(weatherIcon, style: const TextStyle(fontSize: 14)),
                                                const SizedBox(width: 3),
                                                Text('${temp.round()}°C', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                              ],
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      
                                      // Custom elevation graph & climb with drag gesture detection
                                      Expanded(
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: elevations != null && elevations.isNotEmpty && idx == _selectedOptionIndex
                                                  ? LayoutBuilder(
                                                      builder: (context, constraints) {
                                                        final double width = constraints.maxWidth;
                                                        return GestureDetector(
                                                          behavior: HitTestBehavior.opaque,
                                                          onHorizontalDragUpdate: (details) {
                                                            final double fraction = (details.localPosition.dx / width).clamp(0.0, 1.0);
                                                            setState(() {
                                                              _hoverFraction = fraction;
                                                              _hoverElevationIndex = (fraction * (elevations.length - 1)).round();
                                                            });
                                                          },
                                                          onHorizontalDragEnd: (_) {
                                                            setState(() {
                                                              _hoverFraction = null;
                                                              _hoverElevationIndex = null;
                                                            });
                                                          },
                                                          onTapDown: (details) {
                                                            final double fraction = (details.localPosition.dx / width).clamp(0.0, 1.0);
                                                            setState(() {
                                                              _hoverFraction = fraction;
                                                              _hoverElevationIndex = (fraction * (elevations.length - 1)).round();
                                                            });
                                                          },
                                                          onTapUp: (_) {
                                                            setState(() {
                                                              _hoverFraction = null;
                                                              _hoverElevationIndex = null;
                                                            });
                                                          },
                                                          child: CustomPaint(
                                                            painter: ElevationProfilePainter(
                                                              elevations: elevations,
                                                              lineColor: _usingBike ? const Color(0xFFBFFF00) : const Color(0xFF5C9E00),
                                                              hoverFraction: _hoverFraction,
                                                            ),
                                                            child: Container(),
                                                          ),
                                                        );
                                                      },
                                                    )
                                                  : Container(
                                                      color: Colors.grey.shade50,
                                                      child: const Center(
                                                        child: Text('Načítání převýšení...', style: TextStyle(color: Colors.black38, fontSize: 11)),
                                                      ),
                                                    ),
                                            ),
                                            const SizedBox(width: 12),
                                            Row(
                                              children: [
                                                const Icon(Icons.trending_up_rounded, size: 14, color: Colors.green),
                                                const SizedBox(width: 4),
                                                Text('+${climb.round()} m', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      
                                      // Start Button and Invite Friend QR Row
                                      Row(
                                        children: [
                                          Expanded(
                                            child: SizedBox(
                                              height: 44,
                                              child: ElevatedButton(
                                                onPressed: _isLoadingRouteGeometry || _currentRoutePoints.length < 2 || idx != _selectedOptionIndex
                                                    ? null
                                                    : () {
                                                        final double dist = option['exactDistance'] as double;
                                                        Navigator.pop(context, {
                                                          'points': _currentRoutePoints,
                                                          'title': option['title'] as String,
                                                          'distance': dist,
                                                          'eta': option['eta'] as int? ?? (dist * 12).round(),
                                                          'kct_color': option['kct_color'] as String?,
                                                          'cyklo_number': option['cyklo_number'] as String?,
                                                          'trivia_question': option['trivia_question'] as String?,
                                                          'trivia_answer': option['trivia_answer'] as String?,
                                                          'trivia': option['trivia'] as List<dynamic>?,
                                                          'using_bike': _usingBike,
                                                        });
                                                      },
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: const Color(0xFFBFFF00),
                                                  foregroundColor: Colors.black,
                                                  elevation: 0,
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                ),
                                                child: const Text('SPUSTIT TRASU', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          IconButton(
                                            icon: Icon(
                                              _isRouteSaved(option)
                                                  ? Icons.bookmark_rounded
                                                  : Icons.bookmark_outline_rounded,
                                              color: const Color(0xFF5C9E00),
                                            ),
                                            onPressed: () => _toggleSaveRoute(option),
                                            tooltip: 'Uložit na později',
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.share_rounded, color: Color(0xFF5C9E00)),
                                            onPressed: () => _shareRoute(option),
                                            tooltip: 'Sdílet s přáteli',
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (!_isPremium && _routeOptions.isNotEmpty)
            Positioned(
              bottom: 295,
              left: 16,
              right: 16,
              child: _SimulatedAdBanner(
                onUpgrade: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ShopScreen()),
                  );
                },
              ),
            ),
          if (_showSimulatedAd)
            Positioned.fill(
              child: Container(
                color: const Color(0xFF161C20),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.amber,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'REKLAMA',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ),
                            if (_adCountdown > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.black45,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.white24),
                                ),
                                child: Text(
                                  'Přeskočit za $_adCountdown s',
                                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                              )
                            else
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFBFFF00),
                                  foregroundColor: Colors.black,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                ),
                                onPressed: () {
                                  setState(() {
                                    _showSimulatedAd = false;
                                  });
                                },
                                icon: const Icon(Icons.close, size: 18),
                                label: const Text('ZAVŘÍT REKLAMU', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              ),
                          ],
                        ),
                        const Spacer(),
                        Center(
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 400),
                            decoration: BoxDecoration(
                              color: const Color(0xFF263238),
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(color: Colors.lime.withOpacity(0.3), width: 2),
                              boxShadow: const [
                                BoxShadow(color: Colors.black54, blurRadius: 20, offset: Offset(0, 10)),
                              ],
                            ),
                            padding: const EdgeInsets.all(28),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF1B5E20),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.campaign_rounded,
                                    color: Color(0xFFBFFF00),
                                    size: 56,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                const Text(
                                  'ALPINE PRO',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 26,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 2,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Česká značka outdoorového oblečení a obuvi. Vybavte se na výlety do přírody!',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.white70, fontSize: 15, height: 1.4),
                                ),
                                const SizedBox(height: 24),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: Colors.white10),
                                  ),
                                  child: Column(
                                    children: const [
                                      Text(
                                        'SPECIÁLNÍ KÓD NA 20% SLEVU:',
                                        style: TextStyle(color: Color(0xFFBFFF00), fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 0.5),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'HEJBEJSE20',
                                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _showSimulatedAd = false;
                            });
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const ShopScreen()),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF263238), Color(0xFF161C20)],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.amber.withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.stars, color: Colors.amber, size: 28),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: const [
                                      Text(
                                        'Už žádné reklamy a limity?',
                                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                      Text(
                                        'Aktivujte si Hejbej se Premium ještě dnes.',
                                        style: TextStyle(color: Colors.white70, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 14),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildKctBadge(String color) {
    Color badgeColor = Colors.grey;
    String text = 'Turistická';
    switch (color) {
      case 'red':
        badgeColor = Colors.red.shade600;
        text = 'Červená KČT';
        break;
      case 'blue':
        badgeColor = Colors.blue.shade600;
        text = 'Modrá KČT';
        break;
      case 'green':
        badgeColor = Colors.green.shade600;
        text = 'Zelená KČT';
        break;
      case 'yellow':
        badgeColor = Colors.yellow.shade700;
        text = 'Žlutá KČT';
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildCykloBadge(String number) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.amber.shade700,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '🚴 Cyklo $number',
        style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  void _showShareQrDialog(Map<String, dynamic> option) {
    // Generate route share payload
    final payload = {
      'title': option['title'],
      'distance': option['estimatedDistance'],
      'pois': option['pois'],
      'start_lat': widget.startLocation.latitude,
      'start_lng': widget.startLocation.longitude,
    };
    final jsonStr = jsonEncode(payload);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF263238),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Sdílet trasu QR kódem', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Nechte kamaráda naskenovat tento kód, aby mohl jít stejnou trasu s vámi.',
              style: TextStyle(color: Colors.white70, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: SizedBox(
                width: 180,
                height: 180,
                child: QrImageView(
                  data: jsonStr,
                  version: QrVersions.auto,
                  size: 180.0,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Zavřít', style: TextStyle(color: Color(0xFFBFFF00), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  double _angularDifference(double a, double b) {
    double diff = (a - b).abs() % 360;
    return diff > 180 ? 360 - diff : diff;
  }

  void _showPremiumRequiredDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF263238),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.lock_rounded, color: Colors.amber, size: 28),
            SizedBox(width: 10),
            Text('AI Detaily Trasy', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Podrobné informace o AI trase, typy povrchů, prostředí a seznam zajímavých míst (POIs) jsou dostupné pouze pro prémiové členy. Aktivujte si Premium a získejte přístup!',
          style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Zavřít', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFBFFF00),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ShopScreen()),
              );
            },
            child: const Text('Koupit Premium', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showRouteDetailsDialog(Map<String, dynamic> option) {
    if (!_isPremium) {
      _showPremiumRequiredDialog();
      return;
    }
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF263238),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          option['title'] as String,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                option['description'] as String,
                style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
              ),
              const SizedBox(height: 16),
              if (option['surface'] != null) ...[
                const Text('Povrch:', style: TextStyle(color: const Color(0xFFBFFF00), fontWeight: FontWeight.bold, fontSize: 12)),
                Text(option['surface'] as String, style: const TextStyle(color: Colors.white, fontSize: 14)),
                const SizedBox(height: 12),
              ],
              if (option['environment'] != null) ...[
                const Text('Prostředí:', style: TextStyle(color: const Color(0xFFBFFF00), fontWeight: FontWeight.bold, fontSize: 12)),
                Text(option['environment'] as String, style: const TextStyle(color: Colors.white, fontSize: 14)),
                const SizedBox(height: 12),
              ],
              if (option['pois'] != null && (option['pois'] as List).isNotEmpty) ...[
                const Text('Zajímavá místa:', style: TextStyle(color: const Color(0xFFBFFF00), fontWeight: FontWeight.bold, fontSize: 12)),
                ...((option['pois'] as List).map((poi) => Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on, color: Colors.lime, size: 16),
                      const SizedBox(width: 6),
                      Expanded(child: Text(poi.toString(), style: const TextStyle(color: Colors.white70, fontSize: 13))),
                    ],
                  ),
                ))),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Zavřít', style: TextStyle(color: const Color(0xFFBFFF00), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class ElevationProfilePainter extends CustomPainter {
  final List<double> elevations;
  final Color lineColor;
  final double? hoverFraction;

  ElevationProfilePainter({
    required this.elevations,
    required this.lineColor,
    this.hoverFraction,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (elevations.length < 2) return;

    double minH = elevations.reduce(min);
    double maxH = elevations.reduce(max);

    if (maxH == minH) {
      maxH += 1.0;
    }

    final double widthStep = size.width / (elevations.length - 1);
    final path = Path();
    final fillPath = Path();

    double startY = size.height - ((elevations.first - minH) / (maxH - minH) * size.height * 0.8) - (size.height * 0.1);
    path.moveTo(0, startY);
    fillPath.moveTo(0, size.height);
    fillPath.lineTo(0, startY);

    for (int i = 1; i < elevations.length; i++) {
      double x = i * widthStep;
      double y = size.height - ((elevations[i] - minH) / (maxH - minH) * size.height * 0.8) - (size.height * 0.1);
      path.lineTo(x, y);
      fillPath.lineTo(x, y);
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    // Paint fill
    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [lineColor.withOpacity(0.35), lineColor.withOpacity(0.01)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, fillPaint);

    // Paint line
    final linePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    canvas.drawPath(path, linePaint);

    // Draw hover cursor and indicator
    if (hoverFraction != null) {
      final double hoverX = hoverFraction! * size.width;
      
      // Interpolate height corresponding to hover x position
      final double indexD = hoverFraction! * (elevations.length - 1);
      final int indexL = indexD.floor();
      final int indexH = indexD.ceil();
      final double weight = indexD - indexL;
      
      final double interpHeight = elevations[indexL] * (1.0 - weight) + elevations[indexH] * weight;
      final double hoverY = size.height - ((interpHeight - minH) / (maxH - minH) * size.height * 0.8) - (size.height * 0.1);

      // Draw vertical dotted indicator line
      final cursorPaint = Paint()
        ..color = lineColor.withOpacity(0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      
      double curY = 0.0;
      const double dashHeight = 4.0;
      const double spaceHeight = 4.0;
      while (curY < size.height) {
        canvas.drawLine(Offset(hoverX, curY), Offset(hoverX, curY + dashHeight), cursorPaint);
        curY += dashHeight + spaceHeight;
      }

      // Draw outer glowing ring at cursor point
      final glowPaint = Paint()
        ..color = const Color(0xFFBFFF00).withOpacity(0.5)
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
      canvas.drawCircle(Offset(hoverX, hoverY), 8.0, glowPaint);

      // Draw center bullet point
      final bulletPaint = Paint()
        ..color = const Color(0xFF263238)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(hoverX, hoverY), 5.0, bulletPaint);

      final innerPaint = Paint()
        ..color = const Color(0xFFBFFF00)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(hoverX, hoverY), 3.0, innerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant ElevationProfilePainter oldDelegate) {
    return oldDelegate.elevations != elevations ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.hoverFraction != hoverFraction;
  }
}

class _SimulatedAdBanner extends StatelessWidget {
  const _SimulatedAdBanner({required this.onUpgrade});
  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        color: const Color(0xFF263238),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.withOpacity(0.4), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Colors.black38,
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Stack(
          children: [
            Positioned(
              right: -10,
              top: -10,
              child: Icon(
                Icons.campaign_outlined,
                size: 70,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.amber,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'AD',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Alpine Pro: Sleva 20% s kódem HEJBEJSE20',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Vybavení na turistiku a outdoorové aktivity.',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: onUpgrade,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Bez reklam',
                      style: TextStyle(
                        color: const Color(0xFFBFFF00),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
