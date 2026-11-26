import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'controllers/accounts_controller.dart';
import 'controllers/auth_controller.dart';
import 'controllers/inventory_controller.dart';
import 'controllers/order_controller.dart';
import 'controllers/recovery_controller.dart';
import 'controllers/report_controller.dart';
import 'controllers/return_controller.dart';
import 'controllers/shop_controller.dart';
import 'controllers/sync_controller.dart';
import 'controllers/tracking_controller.dart';
import 'controllers/user_controller.dart';
import 'services/local_db.dart';
import 'services/number_service.dart';
import 'services/settings_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: Colors.transparent));
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  await SettingsService.instance.init();
  await NumberService.instance.init();
  await LocalDb.instance.init();

  // ---- Controllers (C of MVC), wired once ----
  final auth = AuthController();
  final users = UserController();
  final accounts = AccountsController();
  final inventory = InventoryController(accounts);
  final shops = ShopController(accounts);
  final tracking = TrackingController();
  final orders = OrderController(inventory, accounts, shops, tracking);
  final returns = ReturnController(inventory, accounts, shops);
  final recovery = RecoveryController(accounts, shops, tracking);
  final reports = ReportController(orders, recovery, returns, inventory, accounts, shops, users);
  final sync = SyncController();

  await accounts.ensureChart();
  // Offline-only install: create admin/1234 right away.
  // With a server: users come from the server first (see AuthController.bootstrap on the login screen).
  if (!sync.configured) await auth.ensureDefaultAdmin();
  await auth.restoreSession();
  tracking.resume();
  sync.start();

  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: auth),
      ChangeNotifierProvider.value(value: users),
      ChangeNotifierProvider.value(value: accounts),
      ChangeNotifierProvider.value(value: inventory),
      ChangeNotifierProvider.value(value: shops),
      ChangeNotifierProvider.value(value: tracking),
      ChangeNotifierProvider.value(value: orders),
      ChangeNotifierProvider.value(value: returns),
      ChangeNotifierProvider.value(value: recovery),
      ChangeNotifierProvider.value(value: reports),
      ChangeNotifierProvider.value(value: sync),
    ],
    child: const DistributionApp(),
  ));
}
