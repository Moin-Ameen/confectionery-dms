import 'base_model.dart';

enum UserRole { owner, manager, accountant, cashier, storekeeper, booker, salesman }

extension UserRoleX on UserRole {
  String get label => const {
        UserRole.owner: 'Owner / Admin',
        UserRole.manager: 'Manager',
        UserRole.accountant: 'Accountant',
        UserRole.cashier: 'Cashier',
        UserRole.storekeeper: 'Store Keeper',
        UserRole.booker: 'Booker',
        UserRole.salesman: 'Salesman',
      }[this]!;

  bool get isField => this == UserRole.booker || this == UserRole.salesman;
  bool get isAdminLevel => this == UserRole.owner || this == UserRole.manager;
}

UserRole roleFromString(String s) =>
    UserRole.values.firstWhere((r) => r.name == s, orElse: () => UserRole.salesman);

/// Permission actions per screen.
class PermAction {
  static const view = 'view';
  static const add = 'add';
  static const edit = 'edit';
  static const delete = 'delete';
  static const approve = 'approve';
  static const all = [view, add, edit, delete, approve];
}

class AppUser implements BaseModel {
  @override
  final String id;
  String name;
  String username;
  String passwordHash;
  UserRole role;
  String phone;
  String routeId;
  String vanName;
  bool active;

  /// Set of "screen:action" strings. Empty = use role defaults.
  Set<String> permissions;
  bool customPermissions;
  double commissionSalePct;
  double commissionRecoveryPct;
  double monthlyTarget;
  DateTime createdAt;

  AppUser({
    required this.id,
    required this.name,
    required this.username,
    required this.passwordHash,
    required this.role,
    this.phone = '',
    this.routeId = '',
    this.vanName = '',
    this.active = true,
    Set<String>? permissions,
    this.customPermissions = false,
    this.commissionSalePct = 0,
    this.commissionRecoveryPct = 0,
    this.monthlyTarget = 0,
    DateTime? createdAt,
  })  : permissions = permissions ?? <String>{},
        createdAt = createdAt ?? DateTime.now();

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  @override
  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'username': username,
        'passwordHash': passwordHash,
        'role': role.name,
        'phone': phone,
        'routeId': routeId,
        'vanName': vanName,
        'active': active,
        'permissions': permissions.toList(),
        'customPermissions': customPermissions,
        'commissionSalePct': commissionSalePct,
        'commissionRecoveryPct': commissionRecoveryPct,
        'monthlyTarget': monthlyTarget,
        'createdAt': createdAt.toIso8601String(),
      };

  factory AppUser.fromMap(Map<String, dynamic> m) => AppUser(
        id: toS(m['id']),
        name: toS(m['name']),
        username: toS(m['username']),
        passwordHash: toS(m['passwordHash']),
        role: roleFromString(toS(m['role'])),
        phone: toS(m['phone']),
        routeId: toS(m['routeId']),
        vanName: toS(m['vanName']),
        active: m['active'] != false,
        permissions: toSList(m['permissions']).toSet(),
        customPermissions: m['customPermissions'] == true,
        commissionSalePct: toD(m['commissionSalePct']),
        commissionRecoveryPct: toD(m['commissionRecoveryPct']),
        monthlyTarget: toD(m['monthlyTarget']),
        createdAt: toDt(m['createdAt']),
      );
}
