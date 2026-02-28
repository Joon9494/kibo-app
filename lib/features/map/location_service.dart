// =====================================================
// 📁 lib/features/map/location_service.dart
// 역할: 현재 위치 가져오기
// =====================================================

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class LocationService {
  // 현재 위치 반환 (위도, 경도)
  Future<Position?> getCurrentPosition() async {
    try {
      // 위치 서비스 활성화 확인
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('위치 서비스 비활성화');
        return null;
      }

      // 권한 확인
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('위치 권한 거부');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('위치 권한 영구 거부');
        return null;
      }

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (e) {
      debugPrint('위치 오류: $e');
      return null;
    }
  }
}