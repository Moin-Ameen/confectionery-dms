import '../models/base_model.dart';
import '../models/product.dart';
import '../models/shop.dart';
import '../models/user.dart';
import '../services/local_db.dart';
import 'auth_controller.dart';
import 'base_controller.dart';
import 'inventory_controller.dart';
import 'shop_controller.dart';

/// Loads sample data so the client can try every screen.
/// All demo users have password 1234.
class DemoSeeder {
  final InventoryController inv;
  final ShopController shops;
  DemoSeeder(this.inv, this.shops);

  final _db = LocalDb.instance;

  Future<String?> run() async {
    if (_db.count(Col.products) > 0) return 'Data already exists – demo data is only for a fresh install';

    // Routes
    final r1 = RouteModel(id: newId(), name: 'Saddar Route', area: 'Saddar', days: ['Mon', 'Thu']);
    final r2 = RouteModel(id: newId(), name: 'Gulshan Route', area: 'Gulshan-e-Iqbal', days: ['Tue', 'Fri']);
    final r3 = RouteModel(id: newId(), name: 'Korangi Route', area: 'Korangi', days: ['Wed', 'Sat']);
    await _db.putMany(Col.routes, [r1, r2, r3].map((e) => e.toMap()).toList());

    // Users (one per role)
    final pw = hashPassword('1234');
    final demoUsers = [
      AppUser(id: newId(), name: 'Imran Manager', username: 'manager', passwordHash: pw, role: UserRole.manager),
      AppUser(id: newId(), name: 'Asad Accountant', username: 'accountant', passwordHash: pw, role: UserRole.accountant),
      AppUser(id: newId(), name: 'Kashif Cashier', username: 'cashier', passwordHash: pw, role: UserRole.cashier),
      AppUser(id: newId(), name: 'Sohail Store', username: 'store', passwordHash: pw, role: UserRole.storekeeper),
      AppUser(
          id: newId(), name: 'Bilal Booker', username: 'booker', passwordHash: pw, role: UserRole.booker,
          routeId: r1.id, monthlyTarget: 500000, commissionSalePct: 1),
      AppUser(
          id: newId(), name: 'Saleem Salesman', username: 'salesman', passwordHash: pw, role: UserRole.salesman,
          routeId: r1.id, vanName: 'Van KHI-1234', monthlyTarget: 500000, commissionSalePct: 0.5, commissionRecoveryPct: 0.5),
    ];
    await _db.putMany(Col.users, demoUsers.map((e) => e.toMap()).toList());

    // Companies
    final c1 = Company(id: newId(), name: 'Candyland', phone: '021-111-000-001');
    final c2 = Company(id: newId(), name: 'Hilal Foods', phone: '021-111-000-002');
    final c3 = Company(id: newId(), name: 'Mayfair', phone: '021-111-000-003');
    await _db.putMany(Col.companies, [c1, c2, c3].map((e) => e.toMap()).toList());

    // Products (prices per piece)
    final products = [
      Product(id: newId(), name: 'Jelly Beans Rs 10', companyId: c1.id, category: 'Candy', piecesPerBox: 24, boxesPerCarton: 12, costPrice: 7.6, tp: 8.5, rp: 10, lowStockPieces: 288),
      Product(id: newId(), name: 'Choco Bar Rs 20', companyId: c1.id, category: 'Chocolate', piecesPerBox: 24, boxesPerCarton: 8, costPrice: 15.5, tp: 17, rp: 20, lowStockPieces: 192),
      Product(id: newId(), name: 'Toffee Jar 100pc', companyId: c2.id, category: 'Candy', piecesPerBox: 1, boxesPerCarton: 6, costPrice: 360, tp: 400, rp: 500, lowStockPieces: 12),
      Product(id: newId(), name: 'Cream Biscuit Rs 10', companyId: c3.id, category: 'Biscuit', piecesPerBox: 12, boxesPerCarton: 12, costPrice: 7.8, tp: 8.6, rp: 10, lowStockPieces: 144),
      Product(id: newId(), name: 'Bubble Gum Rs 5', companyId: c2.id, category: 'Gum', piecesPerBox: 50, boxesPerCarton: 20, costPrice: 3.6, tp: 4.1, rp: 5, lowStockPieces: 500),
      Product(id: newId(), name: 'Wafer Rs 30', companyId: c3.id, category: 'Biscuit', piecesPerBox: 12, boxesPerCarton: 6, costPrice: 23, tp: 25.5, rp: 30, lowStockPieces: 72),
    ];
    await _db.putMany(Col.products, products.map((e) => e.toMap()).toList());

    // Shops
    final shopList = [
      Shop(id: newId(), name: 'Imran Store', owner: 'Imran', phone: '0300-1111111', area: 'Saddar', khataNo: 'K-101', routeId: r1.id, creditLimit: 20000),
      Shop(id: newId(), name: 'Muzamil Traders', owner: 'Muzamil', phone: '0300-2222222', area: 'Saddar', khataNo: 'K-102', routeId: r1.id, creditLimit: 15000),
      Shop(id: newId(), name: 'Al-Tahir', owner: 'Tahir', phone: '0300-3333333', area: 'Saddar', khataNo: 'K-104', routeId: r1.id, creditLimit: 25000),
      Shop(id: newId(), name: 'Muslim Store', owner: 'Aslam', phone: '0300-4444444', area: 'Saddar', khataNo: 'K-105', routeId: r1.id, creditLimit: 30000),
      Shop(id: newId(), name: 'Gulshan Mart', owner: 'Rehan', phone: '0300-5555555', area: 'Gulshan', khataNo: 'K-201', routeId: r2.id, creditLimit: 40000),
      Shop(id: newId(), name: 'Bismillah General', owner: 'Javed', phone: '0300-6666666', area: 'Gulshan', khataNo: 'K-202', routeId: r2.id, creditLimit: 10000),
      Shop(id: newId(), name: 'Korangi Kiryana', owner: 'Nadeem', phone: '0300-7777777', area: 'Korangi', khataNo: 'K-301', routeId: r3.id, creditLimit: 12000),
    ];
    await _db.putMany(Col.shops, shopList.map((e) => e.toMap()).toList());

    // Schemes
    await _db.putMany(Col.schemes, [
      Scheme(id: newId(), name: 'Jelly 12+1', type: SchemeType.free, productId: products[0].id, minQty: 288, freeQty: 24),
      Scheme(id: newId(), name: 'Biscuit slab 2%', type: SchemeType.slab, productId: products[3].id, minQty: 144, percent: 2),
    ].map((e) => e.toMap()).toList());

    BaseController.notifyAll();

    // Opening stock via purchases (posts accounts too)
    final now = DateTime.now();
    final p1 = Purchase(id: newId(), no: 0, companyId: c1.id, items: [
      PurchaseItem(productId: products[0].id, qty: 2880, bonus: 144, rate: 7.6, batchNo: 'CL-${now.month}01', expiry: now.add(const Duration(days: 180))),
      PurchaseItem(productId: products[1].id, qty: 1920, rate: 15.5, batchNo: 'CL-${now.month}02', expiry: now.add(const Duration(days: 25))),
    ]);
    final p2 = Purchase(id: newId(), no: 0, companyId: c2.id, items: [
      PurchaseItem(productId: products[2].id, qty: 60, rate: 360, batchNo: 'HF-77', expiry: now.add(const Duration(days: 365))),
      PurchaseItem(productId: products[4].id, qty: 5000, rate: 3.6, batchNo: 'HF-78', expiry: now.add(const Duration(days: 300))),
    ]);
    final p3 = Purchase(id: newId(), no: 0, companyId: c3.id, items: [
      PurchaseItem(productId: products[3].id, qty: 1728, rate: 7.8, batchNo: 'MF-12', expiry: now.add(const Duration(days: 120))),
      PurchaseItem(productId: products[5].id, qty: 60, rate: 23, batchNo: 'MF-13', expiry: now.add(const Duration(days: 90))),
    ]);
    for (final p in [p1, p2, p3]) {
      await inv.savePurchase(p);
    }
    BaseController.notifyAll();
    return null;
  }
}
