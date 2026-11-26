import 'dart:convert';

import 'package:http/http.dart' as http;

import 'local_db.dart';
import 'number_service.dart';
import 'settings_service.dart';

/// Server contract (to be implemented by the Node/Express backend):
///
///   POST {base}/api/sync/push
///     body: { deviceId, changes: [ {col, id, data, deleted, updatedAt} ] }
///     200 -> { ok: true }
///
///   GET  {base}/api/sync/pull?since=<seq>&deviceId=<id>
///     200 -> { serverTime: <seq>, hasMore: bool, changes: [ {col, id, data, deleted} ] }
///
///   POST {base}/api/sync/reserve   body: { deviceId, col, count } -> { from, to }
///
/// Header: Authorization: Bearer <apiToken>
class SyncResult {
  final bool ok;
  final int pushed;
  final int pulled;
  final String message;

  SyncResult(this.ok, this.pushed, this.pulled, this.message);
}

class SyncService {
  SyncService._();
  static final SyncService instance = SyncService._();

  final _db = LocalDb.instance;
  final _s = SettingsService.instance;
  bool _running = false;

  bool get configured => _s.apiBaseUrl.isNotEmpty;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_s.apiToken.isNotEmpty) 'Authorization': 'Bearer ${_s.apiToken}',
      };

  String _url(String path) {
    var base = _s.apiBaseUrl;
    if (base.endsWith('/')) base = base.substring(0, base.length - 1);
    return '$base$path';
  }

  Future<void> _topUpNumbers() async {
    final ns = NumberService.instance;
    for (final col in NumberService.numbered) {
      if (ns.remaining(col) >= NumberService.lowWater) continue;
      final res = await http
          .post(Uri.parse(_url('/api/sync/reserve')),
              headers: _headers,
              body: jsonEncode({'deviceId': _s.deviceId, 'col': col, 'count': NumberService.blockSize}))
          .timeout(const Duration(seconds: 30));
      if (res.statusCode != 200) continue;
      final b = jsonDecode(res.body) as Map<String, dynamic>;
      final from = b['from'], to = b['to'];
      if (from is num && to is num) ns.addBlock(col, from.toInt(), to.toInt());
    }
  }

  Future<SyncResult> syncNow() async {
    if (!configured) return SyncResult(false, 0, 0, 'Server URL not set (offline mode)');
    if (_running) return SyncResult(false, 0, 0, 'Sync already running');
    _running = true;
    var pushed = 0;
    var pulled = 0;
    try {
      // ---- PUSH ----
      while (true) {
        final changes = await _db.dirtyChanges(limit: 300);
        if (changes.isEmpty) break;
        final res = await http
            .post(Uri.parse(_url('/api/sync/push')),
                headers: _headers,
                body: jsonEncode({
                  'deviceId': _s.deviceId,
                  'changes': changes.map((c) => c.toJson()).toList(),
                }))
            .timeout(const Duration(seconds: 40));
        if (res.statusCode != 200) {
          return SyncResult(false, pushed, pulled, 'Push failed (${res.statusCode})');
        }
        await _db.markClean(changes);
        pushed += changes.length;
        if (changes.length < 300) break;
      }

      // ---- PULL (pages until the server says there is no more) ----
      for (var page = 0; page < 200; page++) {
        final uri = Uri.parse(_url('/api/sync/pull'))
            .replace(queryParameters: {'since': '${_s.lastPull}', 'deviceId': _s.deviceId});
        final res = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 60));
        if (res.statusCode != 200) {
          return SyncResult(false, pushed, pulled, 'Pull failed (${res.statusCode})');
        }
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final list = (body['changes'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .map((m) => SyncChange(
                  m['col'].toString(),
                  m['id'].toString(),
                  Map<String, dynamic>.from((m['data'] ?? {'id': m['id']}) as Map),
                  m['deleted'] == true,
                  0,
                ))
            .toList();
        await _db.applyRemote(list);
        pulled += list.length;
        final st = body['serverTime'];
        if (st is num) _s.lastPull = st.toInt();
        if (body['hasMore'] != true) break;
      }

      // ---- Reserve unique number blocks (orders / bills / vouchers) ----
      await _topUpNumbers();

      _s.lastSyncAt = DateTime.now();
      return SyncResult(true, pushed, pulled, 'Synced');
    } catch (e) {
      return SyncResult(false, pushed, pulled, 'No connection to server');
    } finally {
      _running = false;
    }
  }
}
