import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:hejbej_se/services/route_elevation_service.dart';
import 'package:hejbej_se/features/gamification/models/wheel_of_fortune_model.dart';
import 'package:hejbej_se/features/gamification/services/wheel_of_fortune_service.dart';
import 'package:firebase_ai/firebase_ai.dart' hide LatLng;
import 'package:hejbej_se/services/remote_config_service.dart';

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

  // Hover elevation states
  double? _hoverFraction;
  int? _hoverElevationIndex;

  // List of generated options
  List<Map<String, dynamic>> _routeOptions = [];
  int _selectedOptionIndex = 0;

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

  Future<void> _generateRoutes() async {
    if (widget.isAtoBMode && _destinationLocation == null) {
      setState(() {
        _isLoadingRouteOptions = false;
      });
      return;
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

    final int count = _isPremium ? 10 : 5;

    // 1. Try Gemini generation using Firebase AI SDK
    String? aiError;
    try {
      if (RemoteConfigService().useMathFallback) {
        throw Exception("Vzdálená konfigurace (Remote Config) vynutila matematický generátor tras.");
      }
      final prompt = widget.isAtoBMode
          ? '''
Máš za úkol navrhnout 3 různé pěší/cyklistické trasy v České republice začínající na GPS souřadnici (start: lat: ${widget.startLocation.latitude}, lng: ${widget.startLocation.longitude}) a končící na cílové GPS souřadnici (cíl: lat: ${_destinationLocation!.latitude}, lng: ${_destinationLocation!.longitude}).
Aktivita je ${_usingBike ? 'cyklistika' : 'pěší chůze/běh'}.
Vygeneruj přesně 3 různé alternativní trasy.
Pro každou trasu navrhni 2 až 3 klíčové body (waypoints) mezi startem a cílem tak, aby každá trasa vedla jinudy (např. jedna nejkratší, druhá přes park/les, třetí kolem historických památek nebo vyhlídek). Body musí ležet geograficky rozumně na cestě mezi startem a cílem.
Zkus zjistit, zda trasa nebo její část vede po nějaké oficiální turistické značce KČT (červená, modrá, zelená, žlutá) nebo po očíslované cyklotrase, a uveď to.
U každé trasy navrhni jednu zajímavou kvízovou otázku týkající se historie, geografie nebo zajímavostí okolí trasy (se zaručenou faktickou správností).

Odpověz VÝHRADNĚ ve formátu JSON jako pole objektů s tímto schématem:
[
  {
    "title": "Název trasy v češtině (např. Trasa přes park, Historická cesta)",
    "description": "Stručný atraktivní popis trasy v češtině",
    "waypoints": [
      {"lat": 50.1234, "lng": 14.5678},
      {"lat": 50.1256, "lng": 14.5712}
    ],
    "kct_color": "red" | "blue" | "green" | "yellow" | null,
    "cyklo_number": "č. 2043" | null,
    "surface": "asfalt" | "lesní cesta" | "smíšený",
    "environment": "příroda" | "město" | "historické centrum",
    "pois": ["Zajímavé místo 1", "Zajímavé místo 2"],
    "trivia_question": "Otázka týkající se zajímavosti na trase",
    "trivia_answer": "Správná a ověřená odpověď na otázku"
  }
]
Nevkládej žádný doprovodný text, pouze čistý JSON.
'''
          : '''
Máš za úkol navrhnout okružní turistické trasy v České republice začínající a končící na zadané GPS souřadnici (latitude: ${widget.startLocation.latitude}, longitude: ${widget.startLocation.longitude}).
Typ okolí je ${_isUrban ? 'město' : 'vesnice/příroda'}.
Cílová délka je ${_selectedTargetKm.toInt()} km.
Aktivita je ${_usingBike ? 'cyklistika' : 'pěší chůze/běh'}.
Vygeneruj přesně $count různých okruhů.
Pro každý okruh navrhni 3 klíčové body (waypoints) mezi startem a cílem tak, aby vytvořily smyčku o celkové délce zhruba ${_selectedTargetKm.toInt()} km. Tyto body must být v okruhu maximálně ${_selectedTargetKm / 2} km od startu.
Zkus zjistit, zda trasa nebo její část vede po nějaké oficiální turistické značce KČT (červená, modrá, zelená, žlutá) nebo po očíslované cyklotrase, a uveď to.
U každé trasy navrhni jednu zajímavou kvízovou otázku týkající se historie, geografie nebo zajímavostí okolí trasy (se zaručenou faktickou správností).

Odpověz VÝHRADNĚ ve formátu JSON jako pole objektů s tímto schématem:
[
  {
    "title": "Název trasy v češtině",
    "description": "Stručný atraktivní popis trasy v češtině",
    "waypoints": [
      {"lat": 50.1234, "lng": 14.5678},
      {"lat": 50.1256, "lng": 14.5712},
      {"lat": 50.1221, "lng": 14.5699}
    ],
    "kct_color": "red" | "blue" | "green" | "yellow" | null,
    "cyklo_number": "č. 2043" | null,
    "surface": "asfalt" | "lesní cesta" | "smíšený",
    "environment": "příroda" | "město" | "historické centrum",
    "pois": ["Zajímavé místo 1", "Zajímavé místo 2"],
    "trivia_question": "Otázka týkající se zajímavosti na trase",
    "trivia_answer": "Správná a ověřená odpověď na otázku"
  }
]
Nevkládej žádný doprovodný text, pouze čistý JSON.
''';

      final model = FirebaseAI.googleAI().generativeModel(
        model: RemoteConfigService().geminiModel,
      );

      final response = await model.generateContent([
        Content.text(prompt),
      ]).timeout(const Duration(seconds: 30));

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

        final List<Map<String, dynamic>> options = [];
        for (var item in parsed) {
          final wpsRaw = (item['waypoints'] as List<dynamic>)
              .map((w) => LatLng((w['lat'] as num).toDouble(), (w['lng'] as num).toDouble()))
              .toList();

          final List<LatLng> wps = [];
          if (widget.isAtoBMode) {
            wps.addAll(wpsRaw);
          } else {
            final double targetWpDistance = _selectedTargetKm / 3.2; // Optimized loop distance
            for (int wIdx = 0; wIdx < wpsRaw.length; wIdx++) {
              final wp = wpsRaw[wIdx];
              final bearing = _bearingBetween(widget.startLocation, wp);
              final double factor = (wIdx == 1) ? 1.4 : 0.85;
              final scaledWp = _destinationFromDistanceBearing(
                widget.startLocation,
                targetWpDistance * factor,
                bearing,
              );
              wps.add(scaledWp);
            }
          }

          options.add({
            'title': item['title'] as String? ?? (widget.isAtoBMode ? 'Trasa k cíli' : 'Okruh'),
            'description': item['description'] as String? ?? 'Zajímavá trasa',
            'waypoints': wps,
            'kct_color': item['kct_color'] as String?,
            'cyklo_number': item['cyklo_number'] as String?,
            'surface': item['surface'] as String? ?? 'smíšený',
            'environment': item['environment'] as String? ?? 'příroda',
            'pois': List<String>.from(item['pois'] ?? []),
            'trivia_question': item['trivia_question'] as String? ?? 'Znáš historii tohoto místa?',
            'trivia_answer': item['trivia_answer'] as String? ?? 'Více se dozvíš na trase!',
            'exactDistance': widget.isAtoBMode
                ? (_distanceBetween(widget.startLocation, _destinationLocation!) / 1000.0)
                : _selectedTargetKm,
            'estimatedDistance': widget.isAtoBMode
                ? (_distanceBetween(widget.startLocation, _destinationLocation!) / 1000.0)
                : _selectedTargetKm,
          });
        }

        if (options.isNotEmpty) {
          setState(() {
            _routeOptions = options;
            _isLoadingRouteOptions = false;
          });
          _fetchActiveOptionGeometry();
          return;
        }
      }
    } catch (e) {
      debugPrint('Firebase AI generation failed, using fallback: $e');
      aiError = e.toString();
    }

    if (widget.isAtoBMode) {
      // Fallback for A-to-B mode
      final start = widget.startLocation;
      final dest = _destinationLocation!;

      double dLat = dest.latitude - start.latitude;
      double dLng = dest.longitude - start.longitude;
      LatLng mid = LatLng(start.latitude + dLat / 2, start.longitude + dLng / 2);

      double pLat = -dLng;
      double pLng = dLat;

      final List<Map<String, dynamic>> options = [
        {
          'title': 'Přímá trasa',
          'description': 'Nejkratší cesta k cíli.',
          'waypoints': [mid],
          'surface': 'smíšený',
          'environment': 'město/příroda',
          'pois': ['Hlavní cesta'],
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
          'trivia_question': 'Jaké je vaše oblíbené zákoutí v této oblasti?',
          'trivia_answer': 'Tato trasa vás provede pravou stranou.',
          'estimatedDistance': (_distanceBetween(start, dest) * 1.25) / 1000.0,
        },
      ];

      setState(() {
        _routeOptions = options;
        _isLoadingRouteOptions = false;
      });
      _fetchActiveOptionGeometry();
      return;
    }

    // 2. Fallback to Local Math-based generation for loops
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(aiError != null
                ? 'AI selhalo ($aiError). Generuji trasy záložním matematickým výpočtem.'
                : 'Generuji trasy záložním matematickým výpočtem.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    });
    final random = Random(widget.startLocation.latitude.toInt() + _selectedTargetKm.toInt());
    final List<Map<String, dynamic>> options = [];
    final List<String> names = _isUrban
        ? ['Městské uličky', 'Historické jádro', 'Zámecký park', 'Nábřežní promenáda', 'Rezidenční čtvrť', 'Městský lesopark', 'Parková stezka', 'Vyhlídka nad městem', 'Kavárenský okruh', 'Noční osvětlená trasa']
        : ['Lesní stezka', 'Polní okruh', 'Horská hřebenovka', 'Říční kaňon', 'Vesnické uličky', 'Kolem rybníka', 'Kopcovitý okruh', 'Vyhlídkový hřeben', 'Lesní obora', 'Okolo vinic'];

    final List<String> descriptions = _isUrban
        ? ['85% po chodnících městské zástavby', 'Kolem historických památek a náměstí', 'Příjemný okruh zeleným zámeckým parkem', 'Rovná, asfaltová trasa podél řeky', 'Klidný okruh vilovou čtvrtí', 'Kombinace zástavby a přírodního lesoparku', 'Krásná zelená zóna v srdci města', 'Náročnější stoupání s výhledem na celé město', 'Trasa vedoucí kolem kaváren a bister', 'Po osvětlených hlavních ulicích města']
        : ['90% cesty lesem a po přírodním podkladu', 'Klidný okruh mezi poli a polními cestami', 'Trasa přes kopce s výhledy do kraje', 'Stezka podél potoka hlukým lesním údolím', 'Klidná cesta venkovskou zástavbou', 'Rovný okruh kolem místních rybníků', 'Zpevněné lesní cesty s větším převýšením', 'Hřebenová cesta po okolních kopcích', 'Cesta podél obory s lesní zvěří', 'Trasa mezi malebnými vinohrady'];

    final double startBearing = random.nextDouble() * 360;

    for (int i = 0; i < count; i++) {
      final double distanceFactor = 0.85 + random.nextDouble() * 0.30;
      final double actualOptionKm = _selectedTargetKm * distanceFactor;
      final double bearing = startBearing + (i * (360 / count));
      final double d = actualOptionKm / 3.0;

      // Spreads the loop bearings wider (70 degrees left and right) to prevent out-and-back routing
      final wp1 = _destinationFromDistanceBearing(widget.startLocation, d * 0.85, bearing - 70.0);
      final wp2 = _destinationFromDistanceBearing(widget.startLocation, d * 1.4, bearing);
      final wp3 = _destinationFromDistanceBearing(widget.startLocation, d * 0.85, bearing + 70.0);

      options.add({
        'title': names[i % names.length],
        'description': descriptions[i % descriptions.length],
        'waypoints': [wp1, wp2, wp3],
        'kct_color': i % 4 == 0 ? ['red', 'blue', 'green', 'yellow'][i % 4] : null,
        'cyklo_number': i % 5 == 1 ? 'č. ${2000 + i * 13}' : null,
        'surface': _isUrban ? 'asfalt' : 'lesní cesta',
        'environment': _isUrban ? 'město' : 'příroda',
        'pois': ['Vyhlídkové místo', 'Klidné spočinutí'],
        'trivia_question': 'Víte, že tato trasa je navržena pro maximální klid od dopravy?',
        'trivia_answer': 'Trasa se vyhýbá hlavním silničním tahům.',
        'exactDistance': actualOptionKm,
        'estimatedDistance': actualOptionKm,
      });
    }

    setState(() {
      _routeOptions = options;
      _isLoadingRouteOptions = false;
    });

    _fetchActiveOptionGeometry();
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
            }
          });

          // Fetch simulated weather
          _fetchSimulatedWeather();

          setState(() {
            _currentRoutePoints = points;
            _routeOptions[_selectedOptionIndex]['exactDistance'] = realDistance;
            _routeOptions[_selectedOptionIndex]['eta'] = eta;

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
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              option['title'] as String,
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF263238)),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          if (kctColor != null) _buildKctBadge(kctColor),
                                          if (cykloNum != null) _buildCykloBadge(cykloNum),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      // Description
                                      Text(
                                        option['description'] as String,
                                        style: const TextStyle(color: Colors.black54, fontSize: 12),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
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
                                            Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    const Icon(Icons.trending_up_rounded, size: 14, color: Colors.green),
                                                    const SizedBox(width: 4),
                                                    Text('+${climb.round()} m', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                // Trivia button
                                                TextButton.icon(
                                                  style: TextButton.styleFrom(
                                                    padding: EdgeInsets.zero,
                                                    minimumSize: const Size(50, 24),
                                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                  ),
                                                  onPressed: () => _showTriviaDialog(option),
                                                  icon: const Icon(Icons.lightbulb_rounded, size: 13, color: Colors.amber),
                                                  label: const Text('AI Kvíz', style: TextStyle(fontSize: 11, color: Color(0xFF263238), fontWeight: FontWeight.bold)),
                                                ),
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
                                            icon: const Icon(Icons.share_rounded, color: Color(0xFF5C9E00)),
                                            onPressed: () => _showShareQrDialog(option),
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
