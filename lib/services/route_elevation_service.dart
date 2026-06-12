import 'dart:convert';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

class RouteElevationService {
  static final RouteElevationService _instance = RouteElevationService._internal();
  factory RouteElevationService() => _instance;
  RouteElevationService._internal();

  /// Fetches the elevation profile (sampled to 15 points) for a given list of coordinates.
  /// Returns a map containing:
  /// - 'elevations': List of doubles (height in meters)
  /// - 'climb': double (total height gained in meters)
  /// - 'descent': double (total height lost in meters)
  Future<Map<String, dynamic>> fetchElevationProfile(List<LatLng> points) async {
    if (points.isEmpty) {
      return {'elevations': <double>[], 'climb': 0.0, 'descent': 0.0};
    }

    // Sample to 15 points to keep HTTP request compact and fast
    const int sampleCount = 15;
    final List<LatLng> sampled = [];
    if (points.length <= sampleCount) {
      sampled.addAll(points);
    } else {
      final double step = (points.length - 1) / (sampleCount - 1);
      for (int i = 0; i < sampleCount; i++) {
        sampled.add(points[(i * step).round()]);
      }
    }

    try {
      final lats = sampled.map((p) => p.latitude.toStringAsFixed(5)).join(',');
      final lons = sampled.map((p) => p.longitude.toStringAsFixed(5)).join(',');
      final uri = Uri.parse('https://api.open-meteo.com/v1/elevation?latitude=$lats&longitude=$lons');

      final response = await http.get(uri).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final elevationsJson = data['elevation'] as List<dynamic>?;
        if (elevationsJson != null) {
          final List<double> elevations = elevationsJson.map((e) => (e as num).toDouble()).toList();
          
          // Calculate total climb and descent
          double climb = 0.0;
          double descent = 0.0;
          for (int i = 0; i < elevations.length - 1; i++) {
            final diff = elevations[i + 1] - elevations[i];
            if (diff > 0) {
              climb += diff;
            } else {
              descent += diff.abs();
            }
          }
          return {
            'elevations': elevations,
            'climb': climb,
            'descent': descent,
          };
        }
      }
    } catch (_) {}

    // Fallback if API fails
    return {'elevations': <double>[], 'climb': 0.0, 'descent': 0.0};
  }

  /// Fetches weather info at a start coordinate.
  /// Returns a map containing:
  /// - 'temp': double (temperature in °C)
  /// - 'description': String (Czech description like "Jasno", "Zataženo")
  /// - 'icon': String (emoji representation like "☀️", "🌧️")
  Future<Map<String, dynamic>> fetchRouteWeather(LatLng location) async {
    try {
      final uri = Uri.parse(
        'https://api.open-meteo.com/v1/forecast?latitude=${location.latitude}&longitude=${location.longitude}&current=temperature_2m,weather_code'
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final current = data['current'] as Map<String, dynamic>?;
        if (current != null) {
          final temp = (current['temperature_2m'] as num).toDouble();
          final int code = current['weather_code'] as int? ?? 0;

          // Map weather code (WMO code) to description
          String desc = "Polooblačno";
          String icon = "⛅";

          if (code == 0) {
            desc = "Jasno";
            icon = "☀️";
          } else if (code >= 1 && code <= 3) {
            desc = "Skoro jasno / oblačno";
            icon = "🌤️";
          } else if (code >= 45 && code <= 48) {
            desc = "Mlha";
            icon = "🌫️";
          } else if (code >= 51 && code <= 55) {
            desc = "Mrholení";
            icon = "🌧️";
          } else if (code >= 61 && code <= 65) {
            desc = "Déšť";
            icon = "🌧️";
          } else if (code >= 71 && code <= 77) {
            desc = "Sněžení";
            icon = "❄️";
          } else if (code >= 80 && code <= 82) {
            desc = "Přeháňky";
            icon = "🌦️";
          } else if (code >= 95 && code <= 99) {
            desc = "Bouřky";
            icon = "⛈️";
          }

          return {
            'temp': temp,
            'description': desc,
            'icon': icon,
          };
        }
      }
    } catch (_) {}

    return {'temp': 20.0, 'description': "Jasno", 'icon': "☀️"};
  }
}
