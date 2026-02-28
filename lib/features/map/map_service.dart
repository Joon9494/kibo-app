// =====================================================
// 📁 lib/features/map/map_service.dart
// =====================================================

abstract class PlaceResult {
  String get name;
  String get address;
  double get lat;
  double get lng;
}

abstract class MapService {
  Future<List<PlaceResult>> searchPlace(String query);

  Future<int?> getRouteMinutes({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
  });
}