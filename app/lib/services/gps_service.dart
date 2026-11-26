import 'package:geolocator/geolocator.dart';

class GpsService {
  GpsService._();
  static final GpsService instance = GpsService._();

  Position? last;

  Future<bool> ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    return perm == LocationPermission.always || perm == LocationPermission.whileInUse;
  }

  /// Returns current position or null (no GPS / no permission). Never throws.
  Future<Position?> current() async {
    try {
      if (!await ensurePermission()) return null;
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      last = pos;
      return pos;
    } catch (_) {
      try {
        final pos = await Geolocator.getLastKnownPosition();
        if (pos != null) last = pos;
        return pos;
      } catch (_) {
        return null;
      }
    }
  }

  static double distanceMeters(double lat1, double lng1, double lat2, double lng2) =>
      Geolocator.distanceBetween(lat1, lng1, lat2, lng2);
}
