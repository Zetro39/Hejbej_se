import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

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
  bool _isUrban = false;
  bool _usingBike = false;
  double _selectedTargetKm = 8.0;
  
  // List of generated options
  List<Map<String, dynamic>> _routeOptions = [];
  int _selectedOptionIndex = 0;
  
  bool _isLoadingRouteGeometry = false;
  List<LatLng> _currentRoutePoints = [];
  final Set<Polyline> _polylines = {};
  final Set<Marker> _markers = {};

  final List<double> _walkDistances = [3.0, 5.0, 8.0, 10.0, 12.0, 15.0, 20.0, 30.0];
  final List<double> _bikeDistances = [15.0, 20.0, 25.0, 30.0, 35.0, 40.0, 50.0];

  @override
  void initState() {
    super.initState();
    _usingBike = widget.isBikeDefault;
    _selectedTargetKm = _usingBike ? 25.0 : 8.0;
    _checkLocationEnvironment();
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
        // If there's city, town or suburb, classify as urban
        final hasCity = address.containsKey('city') || 
                        address.containsKey('town') || 
                        address.containsKey('suburb') ||
                        address.containsKey('city_district');
        setState(() {
          _isUrban = hasCity;
        });
      }
    } catch (_) {
      // Default to rural/mixed if request fails
      _isUrban = false;
    }
    _generate10Options();
  }

  void _generate10Options() {
    final random = Random(widget.startLocation.latitude.toInt() + _selectedTargetKm.toInt());
    final List<Map<String, dynamic>> options = [];
    
    // Choose route names based on environment
    final List<String> names = _isUrban 
        ? [
            'Městské uličky',
            'Historické jádro',
            'Zámecký park',
            'Nábřežní promenáda',
            'Rezidenční čtvrť',
            'Městský lesopark',
            'Parková stezka',
            'Vyhlídka nad městem',
            'Kavárenský okruh',
            'Noční osvětlená trasa'
          ]
        : [
            'Lesní stezka',
            'Polní okruh',
            'Horská hřebenovka',
            'Říční kaňon',
            'Vesnické uličky',
            'Kolem rybníka',
            'Kopcovitý okruh',
            'Vyhlídkový hřeben',
            'Lesní obora',
            'Okolo vinic'
          ];

    final List<String> descriptions = _isUrban
        ? [
            '85% po chodnících městské zástavby',
            'Kolem historických památek a náměstí',
            'Příjemný okruh zeleným zámeckým parkem',
            'Rovná, asfaltová trasa podél řeky',
            'Klidný okruh klidnou vilovou čtvrtí',
            'Kombinace zástavby a přírodního lesoparku',
            'Krásná zelená zóna v srdci města',
            'Náročnější stoupání s výhledem na celé město',
            'Trasa vedoucí kolem oblíbených kaváren a bister',
            'Po osvětlených hlavních ulicích města'
          ]
        : [
            '90% cesty lesem a po přírodním podkladu',
            'Klidný okruh mezi poli a polními cestami',
            'Trasa přes kopce s nádhernými výhledy',
            'Stezka podél potoka hlubokým lesním údolím',
            'Klidná cesta venkovskou zástavbou s minimem aut',
            'Rovný okruh kolem místních rybníků',
            'Zpevněné lesní cesty s větším převýšením',
            'Hřebenová cesta po okolních kopcích',
            'Cesta podél obory s lesní zvěří',
            'Trasa mezi malebnými vinohrady'
          ];

    final double startBearing = random.nextDouble() * 360;

    for (int i = 0; i < 10; i++) {
      // Slightly randomize target distance (+/- 15%) to make it look authentic (e.g. 5.2 km instead of exactly 5.0)
      final double distanceFactor = 0.85 + random.nextDouble() * 0.30;
      final double actualOptionKm = _selectedTargetKm * distanceFactor;
      
      final String name = names[i % names.length];
      final String desc = descriptions[i % descriptions.length];
      
      options.add({
        'title': name,
        'description': desc,
        'targetDistance': _selectedTargetKm,
        'exactDistance': actualOptionKm, // Store expected distance before OSRM resolves
        'estimatedDistance': actualOptionKm, // Keep constant estimated base distance to prevent accumulation bug
        'bearing': startBearing + (i * 36), // Distribute in 10 directions
        'poi_count': random.nextInt(3) + 1,
      });
    }

    setState(() {
      _routeOptions = options;
      _selectedOptionIndex = 0;
    });

    _fetchActiveOptionGeometry();
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
    final double bearing = option['bearing'] as double;
    final double targetDistance = option['estimatedDistance'] as double? ?? option['exactDistance'] as double;
    final profile = _usingBike ? 'cycling' : 'foot';

    // Calculate a teardrop loop starting and ending at the user's location
    final double d = targetDistance / 3.0;
    final wp1 = _destinationFromDistanceBearing(start, d, bearing - 25.0);
    final wp2 = _destinationFromDistanceBearing(start, d * 1.2, bearing);
    final wp3 = _destinationFromDistanceBearing(start, d, bearing + 25.0);

    final List<LatLng> waypoints = [start, wp1, wp2, wp3, start];
    final coordString = waypoints.map((point) => '${point.longitude},${point.latitude}').join(';');
    final uri = Uri.https('router.project-osrm.org', '/route/v1/$profile/$coordString', {
      'overview': 'full',
      'geometries': 'geojson',
    });

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

            setState(() {
              _currentRoutePoints = points;
              // Update the actual exact distance and eta in option metadata
              _routeOptions[_selectedOptionIndex]['exactDistance'] = realDistance;
              _routeOptions[_selectedOptionIndex]['eta'] = eta;
              
              _polylines.add(Polyline(
                polylineId: const PolylineId('preview_route'),
                color: _usingBike ? Colors.blue.shade600 : Colors.green.shade600,
                width: 5,
                points: points,
                geodesic: true,
              ));

              _markers.add(Marker(
                markerId: const MarkerId('start_marker'),
                position: start,
                infoWindow: const InfoWindow(title: 'Start / Cíl'),
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
      debugPrint('OSRM Outhouse failed: $e');
    }

    // Fallback direct loop if OSRM fails
    setState(() {
      _currentRoutePoints = waypoints;
      _polylines.add(Polyline(
        polylineId: const PolylineId('preview_route'),
        color: Colors.grey.shade600,
        width: 4,
        points: waypoints,
        geodesic: true,
      ));
      
      _routeOptions[_selectedOptionIndex]['eta'] = _usingBike ? (targetDistance * 3.5).round() : (targetDistance * 12).round();

      _markers.add(Marker(
        markerId: const MarkerId('start_marker'),
        position: start,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
      ));

      _isLoadingRouteGeometry = false;
    });
    _fitMapBounds(waypoints);
  }

  LatLng _destinationFromDistanceBearing(LatLng start, double distanceKm, double bearingDegrees) {
    final double bearingRad = bearingDegrees * pi / 180.0;
    
    // 1 degree of latitude is approximately 111.0 km
    final double latOffset = (distanceKm * cos(bearingRad)) / 111.0;
    
    // 1 degree of longitude is approximately 111.0 * cos(latitude) km
    final double cosLat = cos(start.latitude * pi / 180.0);
    // Guard against poles just in case
    final double divisor = 111.0 * (cosLat == 0 ? 0.0001 : cosLat);
    final double lonOffset = (distanceKm * sin(bearingRad)) / divisor;
    
    return LatLng(start.latitude + latOffset, start.longitude + lonOffset);
  }

  double _calculateRouteLength(List<LatLng> points) {
    double total = 0.0;
    for (int i = 0; i < points.length - 1; i++) {
      final double lat1 = points[i].latitude;
      final double lon1 = points[i].longitude;
      final double lat2 = points[i + 1].latitude;
      final double lon2 = points[i + 1].longitude;
      
      // Haversine formula
      const p = 0.017453292519943295;
      final a = 0.5 - cos((lat2 - lat1) * p)/2 + 
            cos(lat1 * p) * cos(lat2 * p) * 
            (1 - cos((lon2 - lon1) * p))/2;
      total += 12742 * asin(sqrt(a)); // 2 * R; R = 6371 km
    }
    return total;
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
          southwest: LatLng(minLat - 0.002, minLon - 0.002),
          northeast: LatLng(maxLat + 0.002, maxLon + 0.002),
        ),
        40.0, // padding
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final distances = _usingBike ? _bikeDistances : _walkDistances;
    final selectedOption = _routeOptions.isNotEmpty ? _routeOptions[_selectedOptionIndex] : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vybrat okruh v okolí'),
        elevation: 0,
      ),
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Large Map Preview
            Expanded(
              flex: 4,
              child: Stack(
                children: [
                  GoogleMap(
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
                    polylines: _polylines,
                    markers: _markers,
                    myLocationEnabled: true,
                    zoomControlsEnabled: false,
                    mapToolbarEnabled: false,
                  ),
                  if (_isLoadingRouteGeometry)
                    Container(
                      color: Colors.black26,
                      child: const Center(
                        child: CircularProgressIndicator(color: Colors.lime),
                      ),
                    ),
                  // Floating activity type toggle on map
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.directions_walk, color: !_usingBike ? Colors.lightBlue : Colors.black45),
                            onPressed: () {
                              if (_usingBike) {
                                setState(() {
                                  _usingBike = false;
                                  _selectedTargetKm = 8.0;
                                  _generate10Options();
                                });
                              }
                            },
                          ),
                          Container(width: 1, height: 24, color: Colors.grey.shade300),
                          IconButton(
                            icon: Icon(Icons.directions_bike, color: _usingBike ? Colors.lightBlue : Colors.black45),
                            onPressed: () {
                              if (!_usingBike) {
                                setState(() {
                                  _usingBike = true;
                                  _selectedTargetKm = 25.0;
                                  _generate10Options();
                                });
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 2. Horizontal Distance Selector
            Container(
              height: 60,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Colors.grey.shade200, width: 1)),
              ),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                itemCount: distances.length,
                itemBuilder: (context, idx) {
                  final target = distances[idx];
                  final isSelected = target == _selectedTargetKm;
                  return Padding(
                    padding: const EdgeInsets.only(right: 10.0),
                    child: ChoiceChip(
                      label: Text('${target.toInt()} km okruh'),
                      selected: isSelected,
                      onSelected: (_) {
                        setState(() {
                          _selectedTargetKm = target;
                          _generate10Options();
                        });
                      },
                      selectedColor: Colors.lime,
                      backgroundColor: Colors.grey.shade100,
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.black : Colors.black54,
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  );
                },
              ),
            ),

            // 3. 10 Options List
            Expanded(
              flex: 5,
              child: _routeOptions.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      itemCount: _routeOptions.length,
                      padding: const EdgeInsets.all(16),
                      itemBuilder: (context, idx) {
                        final option = _routeOptions[idx];
                        final isSelected = idx == _selectedOptionIndex;
                        final double realKm = option['exactDistance'] as double;
                        final int? eta = option['eta'] as int?;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: isSelected ? Colors.lime : Colors.grey.shade200,
                              width: isSelected ? 3.0 : 1.5,
                            ),
                          ),
                          elevation: isSelected ? 4 : 1,
                          color: isSelected ? Colors.lightBlue.shade50.withOpacity(0.3) : Colors.white,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              if (idx != _selectedOptionIndex) {
                                setState(() {
                                  _selectedOptionIndex = idx;
                                });
                                _fetchActiveOptionGeometry();
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(14.0),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: (isSelected ? Colors.lime : Colors.lightBlue.shade50).withOpacity(0.8),
                                    foregroundColor: isSelected ? Colors.black87 : Colors.lightBlue,
                                    child: Text('${idx + 1}'),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          option['title'] as String,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          option['description'] as String,
                                          style: const TextStyle(color: Colors.black54, fontSize: 12),
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            Icon(Icons.straighten, size: 14, color: Colors.grey.shade600),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${realKm.toStringAsFixed(1)} km',
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                            ),
                                            const SizedBox(width: 12),
                                            Icon(Icons.schedule, size: 14, color: Colors.grey.shade600),
                                            const SizedBox(width: 4),
                                            Text(
                                              eta != null ? '$eta min' : '-- min',
                                              style: const TextStyle(fontSize: 12),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isSelected)
                                    const Icon(Icons.check_circle, color: Colors.lime, size: 28),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),

            // 4. Select Button
            if (selectedOption != null)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoadingRouteGeometry || _currentRoutePoints.length < 2
                        ? null
                        : () {
                            // Return selected route points and metadata to MapsScreen
                            final double dist = selectedOption['exactDistance'] as double;
                            Navigator.pop(context, {
                              'points': _currentRoutePoints,
                              'title': selectedOption['title'] as String,
                              'distance': dist,
                              'eta': selectedOption['eta'] as int? ?? (dist * 12).round(),
                            });
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFBFFF00),
                      foregroundColor: Colors.black,
                      disabledBackgroundColor: Colors.grey.shade200,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 4,
                    ),
                    child: Text(
                      _isLoadingRouteGeometry
                          ? 'Načítání trasy...'
                          : 'Vybrat okruh (${(selectedOption['exactDistance'] as double).toStringAsFixed(1)} km)',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
