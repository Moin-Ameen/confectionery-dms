import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'number_service.dart';

/// Collection (table) names.
class Col {
  static const users = 'users';
  static const companies = 'companies';
  static const products = 'products';
  static const stockMoves = 'stock_moves';
  static const purchases = 'purchases';
  static const routes = 'routes';
  static const shops = 'shops';
  static const schemes = 'schemes';
  static const orders = 'orders';
  static const loadSheets = 'load_sheets';
  static const returns = 'returns';
  static const recoveries = 'recoveries';
  static const slips = 'recovery_slips';
  static const accounts = 'accounts';
  static const vouchers = 'vouchers';
  static const pings = 'pings';
  static const logs = 'activity_logs';

  static const all = [
    users, companies, products, stockMoves, purchases, routes, shops, schemes, orders,
    loadSheets, returns, recoveries, slips, accounts, vouchers, pings, logs,
  ];
}

class SyncChange {
  final String col;
  final String id;
  final Map<String, dynamic> data;
  final bool deleted;
  final int updatedAt;

  SyncChange(this.col, this.id, this.data, this.deleted, this.updatedAt);

  Map<String, dynamic> toJson() =>
      {'col': col, 'id': id, 'data': data, 'deleted': deleted, 'updatedAt': updatedAt};
}

/// Offline-first document store on top of SQLite.
/// Every record is kept as JSON in one table + an in-memory cache for speed.
/// `dirty = 1` means the change still has to be pushed to the server.
class LocalDb {
  LocalDb._();
  static final LocalDb instance = LocalDb._();

  Database? _db;
  final Map<String, Map<String, Map<String, dynamic>>> _cache = {};

  Database get db => _db!;

  Future<void> init() async {
    final path = p.join(await getDatabasesPath(), 'confectionery_distribution.db');
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, v) async {
        await db.execute('''
          CREATE TABLE docs (
            col TEXT NOT NULL,
            id TEXT NOT NULL,
            data TEXT NOT NULL,
            updated_at INTEGER NOT NULL,
            dirty INTEGER NOT NULL DEFAULT 1,
            deleted INTEGER NOT NULL DEFAULT 0,
            PRIMARY KEY (col, id)
          )
        ''');
        await db.execute('CREATE INDEX idx_docs_dirty ON docs(dirty)');
      },
    );
    await _loadCache();
  }

  Future<void> _loadCache() async {
    _cache.clear();
    final rows = await db.query('docs', where: 'deleted = 0');
    for (final r in rows) {
      final col = r['col'] as String;
      final id = r['id'] as String;
      try {
        _cache.putIfAbsent(col, () => {})[id] =
            Map<String, dynamic>.from(jsonDecode(r['data'] as String) as Map);
      } catch (_) {}
    }
  }

  List<Map<String, dynamic>> all(String col) => _cache[col]?.values.toList() ?? [];

  Map<String, dynamic>? get(String col, String id) => _cache[col]?[id];

  int count(String col) => _cache[col]?.length ?? 0;

  /// Next running number for a collection field (e.g. order no).
  /// Uses a number block reserved from the server when available (unique across phones),
  /// otherwise falls back to local max + 1 (single-phone / not yet synced).
  int nextNo(String col, [String field = 'no']) {
    if (field == 'no' && NumberService.numbered.contains(col)) {
      final n = NumberService.instance.take(col);
      if (n != null) return n;
    }
    var max = 0;
    for (final m in all(col)) {
      final v = m[field];
      final n = v is num ? v.toInt() : int.tryParse('$v') ?? 0;
      if (n > max) max = n;
    }
    return max + 1;
  }

  Future<void> put(String col, Map<String, dynamic> data, {bool dirty = true}) async {
    final id = data['id'] as String;
    _cache.putIfAbsent(col, () => {})[id] = data;
    await db.insert(
      'docs',
      {
        'col': col,
        'id': id,
        'data': jsonEncode(data),
        'updated_at': DateTime.now().millisecondsSinceEpoch,
        'dirty': dirty ? 1 : 0,
        'deleted': 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> putMany(String col, List<Map<String, dynamic>> list, {bool dirty = true}) async {
    final batch = db.batch();
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final data in list) {
      final id = data['id'] as String;
      _cache.putIfAbsent(col, () => {})[id] = data;
      batch.insert(
        'docs',
        {
          'col': col,
          'id': id,
          'data': jsonEncode(data),
          'updated_at': now,
          'dirty': dirty ? 1 : 0,
          'deleted': 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  /// Soft delete so the deletion can be synced.
  Future<void> delete(String col, String id, {bool dirty = true}) async {
    final data = _cache[col]?.remove(id);
    await db.insert(
      'docs',
      {
        'col': col,
        'id': id,
        'data': jsonEncode(data ?? {'id': id}),
        'updated_at': DateTime.now().millisecondsSinceEpoch,
        'dirty': dirty ? 1 : 0,
        'deleted': 1,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<SyncChange>> dirtyChanges({int limit = 500}) async {
    final rows = await db.query('docs', where: 'dirty = 1', limit: limit);
    return rows
        .map((r) => SyncChange(
              r['col'] as String,
              r['id'] as String,
              Map<String, dynamic>.from(jsonDecode(r['data'] as String) as Map),
              (r['deleted'] as int) == 1,
              r['updated_at'] as int,
            ))
        .toList();
  }

  Future<int> dirtyCount() async {
    final r = await db.rawQuery('SELECT COUNT(*) AS c FROM docs WHERE dirty = 1');
    return (r.first['c'] as int?) ?? 0;
  }

  Future<void> markClean(List<SyncChange> changes) async {
    final batch = db.batch();
    for (final c in changes) {
      // only clean if not modified again after we read it
      batch.update('docs', {'dirty': 0},
          where: 'col = ? AND id = ? AND updated_at = ?', whereArgs: [c.col, c.id, c.updatedAt]);
    }
    await batch.commit(noResult: true);
  }

  /// Apply changes pulled from the server. Local unsynced edits win.
  Future<void> applyRemote(List<SyncChange> changes) async {
    for (final c in changes) {
      final local = await db.query('docs',
          columns: ['dirty'], where: 'col = ? AND id = ?', whereArgs: [c.col, c.id], limit: 1);
      if (local.isNotEmpty && (local.first['dirty'] as int) == 1) continue;
      if (c.deleted) {
        await delete(c.col, c.id, dirty: false);
      } else {
        await put(c.col, c.data, dirty: false);
      }
    }
  }

  Future<void> wipe() async {
    await db.delete('docs');
    _cache.clear();
  }
}
