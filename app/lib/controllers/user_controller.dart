import '../models/user.dart';
import '../services/local_db.dart';
import 'auth_controller.dart';
import 'base_controller.dart';

class UserController extends BaseController {
  List<AppUser> get users {
    final l = db.all(Col.users).map(AppUser.fromMap).toList();
    l.sort((a, b) => a.role.index != b.role.index ? a.role.index.compareTo(b.role.index) : a.name.compareTo(b.name));
    return l;
  }

  List<AppUser> byRole(UserRole r) => users.where((u) => u.role == r && u.active).toList();
  List<AppUser> get salesmen => byRole(UserRole.salesman);
  List<AppUser> get bookers => byRole(UserRole.booker);
  List<AppUser> get fieldUsers => users.where((u) => u.role.isField && u.active).toList();

  AppUser? byId(String id) {
    final m = db.get(Col.users, id);
    return m == null ? null : AppUser.fromMap(m);
  }

  String nameOf(String id) => byId(id)?.name ?? '-';

  /// Returns error or null. [password] empty = keep existing.
  Future<String?> save(AppUser u, {String password = '', bool isNew = false}) async {
    if (u.name.trim().isEmpty) return 'Name is required';
    if (u.username.trim().isEmpty) return 'Username is required';
    final dup = users.any((x) => x.id != u.id && x.username.toLowerCase() == u.username.trim().toLowerCase());
    if (dup) return 'Username already exists';
    if (isNew && password.length < 4) return 'Password must be at least 4 characters';
    if (password.isNotEmpty) u.passwordHash = hashPassword(password);
    u.username = u.username.trim();
    if (u.id == Session.userId && !u.active) return 'You cannot disable your own account';
    await db.put(Col.users, u.toMap());
    await log(isNew ? 'created' : 'edited', 'User', refId: u.id, details: '${u.name} (${u.role.label})');
    changed();
    return null;
  }

  Future<String?> delete(AppUser u) async {
    if (u.id == Session.userId) return 'You cannot delete yourself';
    if (u.role == UserRole.owner && byRole(UserRole.owner).length <= 1) return 'At least one owner is required';
    await db.delete(Col.users, u.id);
    await log('deleted', 'User', refId: u.id, details: u.name);
    changed();
    return null;
  }
}
