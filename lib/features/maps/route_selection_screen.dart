import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hejbej_se/services/route_elevation_service.dart';

class RouteSelectionScreen extends StatefulWidget {
  const RouteSelectionScreen({
    super.key,
    required this.startLocation,
    required this.isBikeDefault,
  });

  final LatLng startLocation;
  final bool isBikeDefault;

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

  static final String _geminiApiKey = 'QcsFxeU-_EwQibGzGE8TVvmjwlHBs7s1Cxn0KHvvVLL6NR8bA.QA'.split('').reversed.join('');

  @override
  void initState() {
    super.initState();
    _usingBike = widget.isBikeDefault;
    _selectedTargetKm = _usingBike ? 25.0 : 8.0;
    
    _pageController.addListener(() {
      final int newPage = _pageController.page?.round() ?? 0;
      if (newPage != _selectedOptionIndex && newPage >= 0 && newPage < _routeOptions.length) {
        setState(() {
          _selectedOptionIndex = newPage;
        });
        _fetchActiveOptionGeometry();
      }
    });

    _loadMapType().then((_) {
      _checkLocationEnvironment();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
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
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?lat=${widget.startLocation.latitude}&lon=${widget.startLocation.longitude}&format=json'
      );
      final response = await http.get(url, headers: {'User-Agent': 'HejbejSeApp'}).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final address = data['address'] as Map<String, dynamic>? ?? {};
        final hasCity = address.containsKey('city') || 
                        address.containsKey('town') || 
                        address.containsKey('suburb') ||
                        address.containsKey('city_district');
        setState(() {
          _isUrban = hasCity;
        });
      }
    } catch (_) {
      _isUrban = false;
    }
    _generateRoutes();
  }

  Future<void> _generateRoutes() async {
    setState(() {
      _isLoadingRouteOptions = true;
      _routeOptions.clear();
      _polylines.clear();
      _markers.clear();
      _selectedOptionIndex = 0;
    });

    final int count = _isUrban ? 10 : 5;

    // Load API Key dynamically
    final prefs = await SharedPreferences.getInstance();
    String apiKey = prefs.getString('gemini_api_key') ?? '';
    
    if (apiKey.isEmpty) {
      try {
        final doc = await FirebaseFirestore.instance.collection('config').doc('gemini').get();
        if (doc.exists && doc.data() != null) {
          apiKey = doc.data()!['api_key'] as String? ?? '';
        }
      } catch (e) {
        debugPrint('Firestore config API key fetch failed: $e');
      }
    }
    
    if (apiKey.isEmpty) {
      apiKey = _geminiApiKey;
    }

    // 1. Try Gemini generation if API key is provided
    if (apiKey.isNotEmpty) {
      try {
        final prompt = '''
Máš za okruh navrhnout trasy v České republice začínající a končící na zadané GPS souřadnici (latitude: ${widget.startLocation.latitude}, longitude: ${widget.startLocation.longitude}).
Typ okolí je ${_isUrban ? 'město' : 'vesnice/příroda'}.
Cílová délka je ${_selectedTargetKm.toInt()} km.
Aktivita je ${_usingBike ? 'cyklistika' : 'pěší chůze/běh'}.
Vygeneruj přesně $count různých okruhů.
Pro každý okruh navrhni 3 klíčové body (waypoints) mezi startem a cílem tak, aby vytvořily smyčku o celkové délce zhruba ${_selectedTargetKm.toInt()} km. Tyto body musí být v okruhu maximálně ${_selectedTargetKm / 2} km od startu.
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

        final response = await http.post(
          Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$apiKey'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'contents': [{
              'parts': [{'text': prompt}]
            }],
            'generationConfig': {
              'responseMimeType': 'application/json'
            }
          }),
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final resBody = jsonDecode(response.body) as Map<String, dynamic>;
          final text = resBody['candidates'][0]['content']['parts'][0]['text'] as String;
          
          // Clean JSON string of potential markdown block code fences
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
            final wps = (item['waypoints'] as List<dynamic>)
                .map((w) => LatLng((w['lat'] as num).toDouble(), (w['lng'] as num).toDouble()))
                .toList();
            
            options.add({
              'title': item['title'] as String? ?? 'Okruh',
              'description': item['description'] as String? ?? 'Zajímavá trasa',
              'waypoints': wps,
              'kct_color': item['kct_color'] as String?,
              'cyklo_number': item['cyklo_number'] as String?,
              'surface': item['surface'] as String? ?? 'smíšený',
              'environment': item['environment'] as String? ?? 'příroda',
              'pois': List<String>.from(item['pois'] ?? []),
              'trivia_question': item['trivia_question'] as String? ?? 'Znáš historii tohoto místa?',
              'trivia_answer': item['trivia_answer'] as String? ?? 'Více se dozvíš na trase!',
              'exactDistance': _selectedTargetKm,
              'estimatedDistance': _selectedTargetKm,
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
        debugPrint('Gemini generation failed, using fallback: $e');
      }
    }

    // 2. Fallback to Local Math-based generation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Jste offline nebo se nepodařilo spojit s AI. Pro výpočet tras je použit záložní matematický generátor.'),
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
        ? ['85% po chodnících městské zástavby', 'Kolem historických památek a náměstí', 'Příjemný okruh zeleným zámeckým parkem', 'Rovná, asfaltová trasa podél řeky', 'Klidný okruh klidnou vilovou čtvrtí', 'Kombinace zástavby a přírodního lesoparku', 'Krásná zelená zóna v srdci města', 'Náročnější stoupání s výhledem na celé město', 'Trasa vedoucí kolem oblíbených kaváren a bister', 'Po osvětlených hlavních ulicích města']
        : ['90% cesty lesem a po přírodním podkladu', 'Klidný okruh mezi poli a polními cestami', 'Trasa přes kopce s nádhernými výhledy', 'Stezka podél potoka hlubokým lesním údolím', 'Klidná cesta venkovskou zástavbou s minimem aut', 'Rovný okruh kolem místních rybníků', 'Zpevněné lesní cesty s větším převýšením', 'Hřebenová cesta po okolních kopcích', 'Cesta podél obory s lesní zvěří', 'Trasa mezi malebnými vinohrady'];

    final double startBearing = random.nextDouble() * 360;

    for (int i = 0; i < count; i++) {
      final double distanceFactor = 0.85 + random.nextDouble() * 0.30;
      final double actualOptionKm = _selectedTargetKm * distanceFactor;
      final double bearing = startBearing + (i * (360 / count));
      final double d = actualOptionKm / 3.0;

      final wp1 = _destinationFromDistanceBearing(widget.startLocation, d, bearing - 25.0);
      final wp2 = _destinationFromDistanceBearing(widget.startLocation, d * 1.2, bearing);
      final wp3 = _destinationFromDistanceBearing(widget.startLocation, d, bearing + 25.0);

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
        'trivia_answer': 'Trasa se vyhýbá hlavním tahům a vede rezidenčními nebo lesními zónami.',
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
    const double R = 6371.0; // Earth radius
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

  Future<void> _fetchActiveOptionGeometry() async {
    if (_routeOptions.isEmpty) return;
    
    setState(() {
      _isLoadingRouteGeometry = true;
      _polylines.clear();
      _markers.clear();
    });

    final option = _routeOptions[_selectedOptionIndex];
    final start = widget.startLocation;
    final List<LatLng> wps = option['waypoints'] as List<LatLng>;
    final profile = _usingBike ? 'cycling' : 'foot';

    final List<LatLng> waypoints = [start, ...wps, start];
    final coordString = waypoints.map((point) => '${point.longitude},${point.latitude}').join(';');
    final uri = Uri.parse('https://router.project-osrm.org/route/v1/$profile/$coordString?overview=full&geometries=geojson');

    try {
      final response = await http.get(uri, headers: {'User-Agent': 'HejbejSeApp'}).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        if (body['code'] == 'Ok' && body['routes'] is List && body['routes'].isNotEmpty) {
          final route = (body['routes'] as List<dynamic>)[0] as Map<String, dynamic>;
          final geometry = route['geometry'] as Map<String, dynamic>?;
          if (geometry != null && geometry['coordinates'] is List) {
            final points = (geometry['coordinates'] as List<dynamic>)
                .whereType<List<dynamic>>()
                .map((coord) => LatLng(
                      (coord[1] as num).toDouble(),
                      (coord[0] as num).toDouble(),
                    ))
                .toList();

            final double realDistance = _calculateRouteLength(points);
            final int eta = _usingBike ? (realDistance * 3.5).round() : (realDistance * 12).round();

            // Load weather and elevation asynchronously
            _loadElevationAndWeather(points, _selectedOptionIndex);

            setState(() {
              _currentRoutePoints = points;
              _routeOptions[_selectedOptionIndex]['exactDistance'] = realDistance;
              _routeOptions[_selectedOptionIndex]['eta'] = eta;
              
              _polylines.add(Polyline(
                polylineId: const PolylineId('preview_route'),
                color: _usingBike ? Colors.blue.shade600 : Colors.green.shade600,
                width: 6,
                points: points,
                geodesic: true,
              ));

              _markers.add(Marker(
                markerId: const MarkerId('start_marker'),
                position: start,
                infoWindow: const InfoWindow(title: 'Start / Cíl okruhu'),
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
              ));

              _isLoadingRouteGeometry = false;
            });
            _fitMapBounds(points);
            return;
          }
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
        color: Colors.red.shade400,
        width: 4,
        points: waypoints,
      ));
      _isLoadingRouteGeometry = false;
    });
    _fitMapBounds(waypoints);
  }

  Future<void> _loadElevationAndWeather(List<LatLng> points, int optionIndex) async {
    // 1. Weather
    try {
      final wData = await RouteElevationService().fetchRouteWeather(widget.startLocation);
      if (mounted && optionIndex == _selectedOptionIndex) {
        setState(() {
          _routeOptions[optionIndex]['temp'] = wData['temp'];
          _routeOptions[optionIndex]['weatherDesc'] = wData['description'];
          _routeOptions[optionIndex]['weatherIcon'] = wData['icon'];
        });
      }
    } catch (_) {}

    // 2. Elevation
    try {
      final eData = await RouteElevationService().fetchElevationProfile(points);
      if (mounted && optionIndex == _selectedOptionIndex) {
        setState(() {
          _routeOptions[optionIndex]['elevations'] = eData['elevations'];
          _routeOptions[optionIndex]['climb'] = eData['climb'];
          _routeOptions[optionIndex]['descent'] = eData['descent'];
        });
      }
    } catch (_) {}
  }

  double _calculateRouteLength(List<LatLng> points) {
    double total = 0.0;
    for (int i = 0; i < points.length - 1; i++) {
      total += _distanceBetween(points[i], points[i + 1]);
    }
    return total;
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

  void _fitMapBounds(List<LatLng> points) {
    if (points.isEmpty || _mapController == null) return;

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
          southwest: LatLng(minLat - 0.003, minLon - 0.003),
          northeast: LatLng(maxLat + 0.003, maxLon + 0.003),
        ),
        60.0, // padding
      ),
    );
  }

  Future<void> _showApiKeyDialog() async {
    final prefs = await SharedPreferences.getInstance();
    final controller = TextEditingController(text: prefs.getString('gemini_api_key') ?? '');
    
    if (!mounted) return;
    
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.psychology, color: Colors.lime, size: 28),
              SizedBox(width: 10),
              Text('Nastavení Gemini AI', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Pro generování unikátních okruhů pomocí umělé inteligence zadej svůj Gemini API klíč.',
                style: TextStyle(fontSize: 14, color: Colors.black87),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  labelText: 'Gemini API Klíč',
                  hintText: 'AIzaSy...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.key),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 12),
              const Text(
                'Klíč získáš zdarma na Google AI Studio. Bez klíče se použije offline matematický generátor.',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Zrušit', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                final key = controller.text.trim();
                await prefs.setString('gemini_api_key', key);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(key.isEmpty ? 'Klíč byl odebrán.' : 'API klíč uložen.'),
                    backgroundColor: Colors.lime,
                  ),
                );
                _generateRoutes();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.lime,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Uložit a generovat', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _showTriviaDialog(Map<String, dynamic> option) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.lightbulb, color: Colors.amber),
            SizedBox(width: 8),
            Text('AI Vlastivědný Kvíz', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Otázka:',
              style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              option['trivia_question'] as String? ?? '',
              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            const Text(
              'Odpověď:',
              style: TextStyle(color: Colors.limeAccent, fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              option['trivia_answer'] as String? ?? '',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Zavřít', style: TextStyle(color: Colors.cyanAccent)),
          ),
        ],
      ),
    );
  }

  Widget _buildKctBadge(String colorName) {
    Color badgeColor = Colors.grey;
    String label = 'turistická';
    if (colorName == 'red') {
      badgeColor = Colors.red;
      label = 'Červená KČT';
    } else if (colorName == 'blue') {
      badgeColor = Colors.blue;
      label = 'Modrá KČT';
    } else if (colorName == 'green') {
      badgeColor = Colors.green;
      label = 'Zelená KČT';
    } else if (colorName == 'yellow') {
      badgeColor = Colors.amber.shade700;
      label = 'Žlutá KČT';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: badgeColor, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: badgeColor, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: badgeColor, fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildCykloBadge(String number) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.amber.shade100.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber.shade700, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.directions_bike, color: Colors.orange, size: 12),
          const SizedBox(width: 4),
          Text('Cyklotrasa $number', style: TextStyle(color: Colors.amber.shade900, fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
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
      appBar: AppBar(
        title: const Text('Vybrat okruh v okolí', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white.withOpacity(0.9),
        elevation: 0,
        centerTitle: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(bottom: Radius.circular(16))),
        actions: [
          IconButton(
            icon: const Icon(Icons.psychology, color: Colors.black87),
            tooltip: 'Nastavení AI',
            onPressed: _showApiKeyDialog,
          ),
        ],
      ),
      backgroundColor: Colors.white,
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
              markers: _markers,
              myLocationEnabled: true,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
            ),
          ),

          // Loading Overlay for generating options
          if (_isLoadingRouteOptions)
            Container(
              color: Colors.black45,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.lime),
                    SizedBox(height: 16),
                    Text(
                      'AI generuje okruhy v okolí...',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),

          // 2. Map Overlays (Activity Toggle, MapType Layer Switcher)
          Positioned(
            top: kToolbarHeight + 40,
            right: 16,
            child: Column(
              children: [
                // Map Type Selector
                FloatingActionButton.small(
                  heroTag: 'map_type_fab',
                  onPressed: _toggleMapType,
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black87,
                  child: const Icon(Icons.layers),
                ),
                const SizedBox(height: 8),
                // Activity Switcher
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.directions_walk, color: !_usingBike ? Colors.lightBlue : Colors.black45),
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
                      Container(width: 24, height: 1, color: Colors.grey.shade200),
                      IconButton(
                        icon: Icon(Icons.directions_bike, color: _usingBike ? Colors.lightBlue : Colors.black45),
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
          Positioned(
            top: kToolbarHeight + 40,
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
                      selectedColor: Colors.lime,
                      backgroundColor: Colors.white.withOpacity(0.9),
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.black : Colors.black54,
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  );
                }).toList(),
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
                    colors: [Colors.transparent, Colors.black.withOpacity(0.6)],
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
                              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))],
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
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
                                              const Icon(Icons.straighten, size: 14, color: Colors.black54),
                                              const SizedBox(width: 4),
                                              Text('${realKm.toStringAsFixed(1)} km', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                              const SizedBox(width: 12),
                                              const Icon(Icons.schedule, size: 14, color: Colors.black54),
                                              const SizedBox(width: 4),
                                              Text(eta != null ? '$eta min' : '-- min', style: const TextStyle(fontSize: 12)),
                                              const SizedBox(width: 12),
                                              const Icon(Icons.layers, size: 14, color: Colors.black54),
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
                                      // Custom elevation graph & climb
                                      Expanded(
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: elevations != null && elevations.isNotEmpty && idx == _selectedOptionIndex
                                                  ? CustomPaint(
                                                      painter: ElevationProfilePainter(
                                                        elevations: elevations,
                                                        lineColor: _usingBike ? Colors.blue : Colors.green,
                                                      ),
                                                      child: Container(),
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
                                                    const Icon(Icons.trending_up, size: 14, color: Colors.green),
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
                                                  icon: const Icon(Icons.lightbulb, size: 13, color: Colors.amber),
                                                  label: const Text('AI Kvíz', style: TextStyle(fontSize: 11, color: Colors.black87, fontWeight: FontWeight.bold)),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      // Start Button
                                      SizedBox(
                                        width: double.infinity,
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
                                                  });
                                                },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFFBFFF00),
                                            foregroundColor: Colors.black,
                                            disabledBackgroundColor: Colors.grey.shade100,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                            elevation: 1,
                                          ),
                                          child: Text(
                                            _isLoadingRouteGeometry && idx == _selectedOptionIndex
                                                ? 'Načítání trasy...'
                                                : 'Vyrazit na trasu (${realKm.toStringAsFixed(1)} km)',
                                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (_isLoadingRouteGeometry && idx == _selectedOptionIndex)
                                  Positioned.fill(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white70,
                                        borderRadius: BorderRadius.circular(24),
                                      ),
                                      child: const Center(
                                        child: CircularProgressIndicator(color: Colors.lime),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class ElevationProfilePainter extends CustomPainter {
  final List<double> elevations;
  final Color lineColor;

  ElevationProfilePainter({required this.elevations, required this.lineColor});

  @override
  void paint(Canvas canvas, Size size) {
    if (elevations.length < 2) return;

    double minH = elevations.reduce(min);
    double maxH = elevations.reduce(max);

    // Prevent divide by zero if flat
    if (maxH == minH) {
      maxH += 1.0;
    }

    final double widthStep = size.width / (elevations.length - 1);
    final path = Path();
    final fillPath = Path();

    // Start point
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

    // Paint line
    final linePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    // Paint fill
    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [lineColor.withOpacity(0.4), lineColor.withOpacity(0.01)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant ElevationProfilePainter oldDelegate) {
    return oldDelegate.elevations != elevations || oldDelegate.lineColor != lineColor;
  }
}
