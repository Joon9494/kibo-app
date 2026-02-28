// =====================================================
// 📁 lib/features/map/tmap_service.dart
// 역할: Tmap API 구현체
// =====================================================

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../core/constants.dart';
import 'map_service.dart';

// ── Tmap 장소 검색 결과 ───────────────────────────────
class TmapPlaceResult implements PlaceResult {
  @override final String name;
  @override final String address;
  @override final double lat;
  @override final double lng;

  TmapPlaceResult({
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
  });
}

// ── Tmap 서비스 구현체 ────────────────────────────────
class TmapService implements MapService {
  static const _baseUrl = 'https://apis.openapi.sk.com';

  // 장소 검색
  @override
  Future<List<PlaceResult>> searchPlace(String query) async {
    try {
      final uri = Uri.parse('$_baseUrl/tmap/pois').replace(
        queryParameters: {
          'version': '1',
          'searchKeyword': query,
          'count': '5',
          'appKey': AppConstants.tmapApiKey,
        },
      );

      final response = await http.get(uri).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode != 200) {
        debugPrint('Tmap 장소 검색 오류: ${response.statusCode}');
        return [];
      }

      final data = jsonDecode(response.body);
      final pois = data['searchPoiInfo']?['pois']?['poi'] as List?;
      if (pois == null) return [];

      return pois.map((poi) {
        return TmapPlaceResult(
          name: poi['name'] ?? '',
          address:
              '${poi['upperAddrName'] ?? ''} ${poi['middleAddrName'] ?? ''} ${poi['roadName'] ?? ''}',
          lat: double.tryParse(poi['frontLat'] ?? '0') ?? 0,
          lng: double.tryParse(poi['frontLon'] ?? '0') ?? 0,
        );
      }).toList();
    } catch (e) {
      debugPrint('Tmap 장소 검색 예외: $e');
      return [];
    }
  }

  // 자동차 경로 소요시간 (분)
  @override
  Future<int?> getRouteMinutes({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/tmap/routes').replace(
        queryParameters: {'version': '1'},
      );

      final body = jsonEncode({
        'startX': startLng.toString(),
        'startY': startLat.toString(),
        'endX': endLng.toString(),
        'endY': endLat.toString(),
        'reqCoordType': 'WGS84GEO',
        'resCoordType': 'WGS84GEO',
        'searchOption': '0',
      });

      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'appKey': AppConstants.tmapApiKey,
            },
            body: body,
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        debugPrint('Tmap 경로 오류: ${response.statusCode}');
        return null;
      }

      final data = jsonDecode(response.body);
      final features = data['features'] as List?;
      if (features == null || features.isEmpty) return null;

      final totalTime =
          features.first['properties']?['totalTime'] as int?;
      if (totalTime == null) return null;

      // 초 → 분 변환
      return (totalTime / 60).ceil();
    } catch (e) {
      debugPrint('Tmap 경로 예외: $e');
      return null;
    }
  }
}