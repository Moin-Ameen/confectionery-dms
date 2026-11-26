import 'package:flutter/foundation.dart';

import '../models/base_model.dart';
import '../models/tracking.dart';
import '../models/user.dart';
import '../services/local_db.dart';

/// Holds the logged-in user so every controller can stamp records & logs.
class Session {
  static AppUser? user;
  static String get userId => user?.id ?? '';
  static bool get isField => user?.role.isField ?? false;
}

/// Base for all controllers: DB access, activity logging and global refresh.
abstract class BaseController extends ChangeNotifier {
  static final List<BaseController> _all = [];

  BaseController() {
    _all.add(this);
  }

  final LocalDb db = LocalDb.instance;

  /// Call after a sync pull or bulk change so every screen rebuilds.
  static void notifyAll() {
    for (final c in _all) {
      c.invalidate();
      c.notifyListeners();
    }
  }

  /// Override to clear cached computed data.
  void invalidate() {}

  Future<void> log(String action, String entity, {String refId = '', String details = ''}) async {
    final l = ActivityLog(
      id: newId(),
      userId: Session.userId,
      action: action,
      entity: entity,
      refId: refId,
      details: details,
    );
    await db.put(Col.logs, l.toMap());
  }

  /// Notify every controller (data in one module affects others' screens).
  void changed() => notifyAll();
}
