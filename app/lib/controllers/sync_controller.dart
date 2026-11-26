import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../config/app_config.dart';
import '../services/local_db.dart';
import '../services/settings_service.dart';
import '../services/sync_service.dart';
import 'base_controller.dart';

class SyncController extends BaseController {
  final _sync = SyncService.instance;
  final _s = SettingsService.instance;

  bool online = false;
  bool syncing = false;
  int pendingChanges = 0;
  String lastMessage = '';
  Timer? _timer;
  StreamSubscription<List<ConnectivityResult>>? _sub;

  bool get configured => _sync.configured;
  DateTime? get lastSyncAt => _s.lastSyncAt;

  Future<void> start() async {
    final r = await Connectivity().checkConnectivity();
    online = !r.contains(ConnectivityResult.none);
    _sub = Connectivity().onConnectivityChanged.listen((res) {
      final was = online;
      online = !res.contains(ConnectivityResult.none);
      notifyListeners();
      if (!was && online) syncNow(); // back online → push offline work
    });
    _timer = Timer.periodic(AppConfig.syncInterval, (_) => syncNow());
    await refreshPending();
    if (online) syncNow();
  }

  Future<void> refreshPending() async {
    pendingChanges = await LocalDb.instance.dirtyCount();
    notifyListeners();
  }

  Future<void> syncNow() async {
    if (syncing) return;
    if (!configured) {
      lastMessage = 'Offline mode – server not configured';
      await refreshPending();
      return;
    }
    syncing = true;
    notifyListeners();
    final r = await _sync.syncNow();
    syncing = false;
    lastMessage = r.ok ? 'Synced: ${r.pushed} sent, ${r.pulled} received' : r.message;
    await refreshPending();
    if (r.pulled > 0) BaseController.notifyAll();
    notifyListeners();
  }

  void saveServer(String url, String token) {
    _s.apiBaseUrl = url;
    _s.apiToken = token;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _sub?.cancel();
    super.dispose();
  }
}
