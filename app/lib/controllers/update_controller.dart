import 'dart:async';

import 'package:flutter/foundation.dart';

import '../services/update_service.dart';

/// Holds in-app update state for the views.
class UpdateController extends ChangeNotifier {
  final _svc = UpdateService.instance;

  ReleaseInfo? available;
  bool checking = false;
  bool downloading = false;
  double progress = 0;
  String error = '';
  String currentLabel = '';
  DateTime? _lastCheck;
  Timer? _timer;

  Future<void> start() async {
    currentLabel = await _svc.currentVersionLabel();
    notifyListeners();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(hours: 3), (_) => check());
  }

  /// Returns true when a newer version is available.
  Future<bool> check({bool force = false}) async {
    if (checking) return available != null;
    if (!force && _lastCheck != null && DateTime.now().difference(_lastCheck!) < const Duration(minutes: 30)) {
      return available != null;
    }
    checking = true;
    notifyListeners();
    available = await _svc.check();
    _lastCheck = DateTime.now();
    checking = false;
    notifyListeners();
    return available != null;
  }

  /// Download + open installer. Returns error or null.
  Future<String?> update() async {
    final r = available;
    if (r == null || downloading) return null;
    downloading = true;
    progress = 0;
    error = '';
    notifyListeners();
    try {
      final path = await _svc.download(r, (p) {
        progress = p;
        notifyListeners();
      });
      downloading = false;
      notifyListeners();
      return await _svc.install(path);
    } catch (e) {
      downloading = false;
      error = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return error.isEmpty ? 'Download failed' : error;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
