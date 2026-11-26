import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../models/base_model.dart';
import '../models/user.dart';
import '../services/local_db.dart';
import '../services/settings_service.dart';
import 'base_controller.dart';
import 'permissions.dart';

String hashPassword(String password) => sha256.convert(utf8.encode('cd::$password')).toString();

class AuthController extends BaseController {
  AppUser? get user => Session.user;
  bool get loggedIn => Session.user != null;

  /// Creates the first owner account (admin / 1234) on a fresh install.
  Future<void> ensureDefaultAdmin() async {
    if (db.count(Col.users) > 0) return;
    final u = AppUser(
      id: newId(),
      name: 'Owner',
      username: 'admin',
      passwordHash: hashPassword('1234'),
      role: UserRole.owner,
    );
    await db.put(Col.users, u.toMap());
  }

  bool get isFreshInstall {
    final users = db.all(Col.users);
    return users.length == 1 && users.first['username'] == 'admin';
  }

  Future<void> restoreSession() async {
    final id = SettingsService.instance.sessionUserId;
    if (id.isEmpty) return;
    final m = db.get(Col.users, id);
    if (m == null) return;
    final u = AppUser.fromMap(m);
    if (!u.active) return;
    Session.user = u;
  }

  /// Returns error message or null on success.
  Future<String?> login(String username, String password) async {
    final uname = username.trim().toLowerCase();
    final found = db.all(Col.users).map(AppUser.fromMap).where((u) => u.username.toLowerCase() == uname);
    if (found.isEmpty) return 'User not found';
    final u = found.first;
    if (!u.active) return 'This user is disabled';
    if (u.passwordHash != hashPassword(password)) return 'Wrong password';
    Session.user = u;
    SettingsService.instance.sessionUserId = u.id;
    await log('login', 'User', refId: u.id);
    changed();
    return null;
  }

  Future<void> logout() async {
    await log('logout', 'User', refId: Session.userId);
    Session.user = null;
    SettingsService.instance.sessionUserId = '';
    SettingsService.instance.onDuty = false;
    changed();
  }

  Future<String?> changePassword(String oldPass, String newPass) async {
    final u = Session.user;
    if (u == null) return 'Not logged in';
    if (u.passwordHash != hashPassword(oldPass)) return 'Old password is wrong';
    if (newPass.length < 4) return 'Password must be at least 4 characters';
    u.passwordHash = hashPassword(newPass);
    await db.put(Col.users, u.toMap());
    await log('edited', 'User', refId: u.id, details: 'Password changed');
    return null;
  }

  /// Reload the logged-in user's record (e.g. after admin changed rights).
  void reloadUser() {
    final id = Session.userId;
    if (id.isEmpty) return;
    final m = db.get(Col.users, id);
    if (m != null) Session.user = AppUser.fromMap(m);
  }

  Set<String> get _perms {
    final u = Session.user;
    if (u == null) return {};
    if (u.role == UserRole.owner) return defaultPermissions(UserRole.owner);
    return u.customPermissions ? u.permissions : defaultPermissions(u.role);
  }

  bool can(String screen, [String action = PermAction.view]) => _perms.contains('$screen:$action');

  @override
  void invalidate() => reloadUser();
}
