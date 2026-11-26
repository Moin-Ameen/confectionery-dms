import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Order / bill / voucher numbers reserved from the server in blocks,
/// so two phones working offline never give the same number.
class NumberService {
  NumberService._();
  static final NumberService instance = NumberService._();

  /// Collections whose `no` is a running number (must match backend NUMBERED_COLLECTIONS).
  static const numbered = ['orders', 'purchases', 'load_sheets', 'returns', 'vouchers'];
  static const blockSize = 50;
  static const lowWater = 15;

  late SharedPreferences _p;

  Future<void> init() async {
    _p = await SharedPreferences.getInstance();
  }

  String _key(String col) => 'numblocks:$col';

  /// List of [next, to] ranges still unused.
  List<List<int>> _blocks(String col) {
    final s = _p.getString(_key(col));
    if (s == null || s.isEmpty) return [];
    try {
      return (jsonDecode(s) as List).map((e) => [(e as List)[0] as int, e[1] as int]).toList();
    } catch (_) {
      return [];
    }
  }

  void _save(String col, List<List<int>> blocks) => _p.setString(_key(col), jsonEncode(blocks));

  int remaining(String col) => _blocks(col).fold(0, (s, b) => s + (b[1] - b[0] + 1));

  /// Next reserved number, or null when no block is available (offline before first sync).
  int? take(String col) {
    final blocks = _blocks(col);
    while (blocks.isNotEmpty && blocks.first[0] > blocks.first[1]) {
      blocks.removeAt(0);
    }
    if (blocks.isEmpty) {
      _save(col, blocks);
      return null;
    }
    final n = blocks.first[0];
    blocks.first[0] = n + 1;
    if (blocks.first[0] > blocks.first[1]) blocks.removeAt(0);
    _save(col, blocks);
    return n;
  }

  void addBlock(String col, int from, int to) {
    if (to < from) return;
    final blocks = _blocks(col)..add([from, to]);
    _save(col, blocks);
  }
}
