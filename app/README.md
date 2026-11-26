# Confectionery Distribution – Android App (Flutter, MVC)

CASHLIFYPOS · Quotation CPOS-2026-112-R1 · 33 modules / 10 groups · Online + Offline

## Run / build the APK

```bash
cd app
flutter create . --org com.cashlifypos --platforms android   # generates android/ files (keeps lib/, pubspec, AndroidManifest)
flutter pub get
flutter analyze
flutter run                     # on a phone / emulator
flutter build apk --release     # build/app/outputs/flutter-apk/app-release.apk
```

Requires Flutter 3.27 or newer.

**First login:** `admin` / `1234`. Then go to **Settings → Load demo data** to get sample shops, products, stock and one
user per role (all with password `1234`: `manager`, `accountant`, `cashier`, `store`, `booker`, `salesman`).

## MVC structure

```
lib/
├─ main.dart                 creates controllers, wires them, starts the app
├─ app.dart                  MaterialApp, theme, login ↔ home switch
├─ config/                   app name, colours, theme (navy #0F3460 / blue #71A2FF)
├─ models/          (M)      plain data classes + toMap/fromMap
│   user, product (company, product, stock move, purchase), shop (route, shop, scheme),
│   order (order, load sheet), sale_return, recovery (recovery, slip), accounts, tracking
├─ controllers/     (C)      all business logic, ChangeNotifier + Provider
│   auth, permissions, user, inventory, shop, order, return, recovery,
│   accounts (auto-posting), report, tracking (GPS + activity log), sync, demo_seeder
├─ services/                 local DB (SQLite), sync, GPS, PDF, Bluetooth printer, settings
└─ views/           (V)      screens only – no business logic
    shell (drawer + role bottom nav), dashboard, inventory, booking, dispatch,
    returns, recovery, accounts, reports, gps, admin, widgets
```

## Module map (quotation → screen)

| Group | Modules | Screens |
|---|---|---|
| A. Users, Roles | 1–3 | Users & Roles (role + screen-wise view/add/edit/delete/approve), Activity Log |
| B. Stock | 4–8 | Products (carton→box→piece, TP/RP), Companies, Purchases & returns (bonus pcs, batch, expiry), Warehouse stock, Van stock (load-in), Stock count / damage, Alerts |
| C. Booker & Shops | 9–12 | Routes (day-wise), Shops & credit limits, Book Order (offline, GPS check-in, schemes, credit block/override), Schemes |
| D. Dispatch | 13–16 | Orders & Approval, Load Sheets, Delivery (salesman edit before invoice, logged), Invoice (Bluetooth print / WhatsApp PDF, posts to khata) |
| E. Returns | 17–18 | Returns (fresh / damaged / expired) + approval |
| F. Recovery | 19–22 | Recovery entry (bill-wise), Digital Wasooli Slip, cashier approval (short/excess), Outstanding & aging |
| G. Reports | 23–25 | Salesman daily report, Performance (target vs achieved, productive shops), Commission |
| H. GPS | 26–27 | Live location (duty on/off), Route history with check-ins |
| I. Accounts | 28–31 | Chart of accounts, Vouchers, Ledgers (shop / company / salesman / account), Cash book, Expenses, Trial balance, P&L, Balance sheet, Monthly profit |
| J. Dashboard & Sync | 32–33 | Owner dashboard, PDF/share on every report, offline-first DB + auto sync |

## Offline + online

Everything is saved first to the phone (SQLite). Every change is marked *dirty* and pushed automatically when the
phone is online and a server URL is set in **Settings & Sync**. Without a server the app runs fully offline on one phone.

Server contract the Node/Express backend must implement:

```
POST {base}/api/sync/push   body { deviceId, changes:[{col,id,data,deleted,updatedAt}] }  → 200 {ok:true}
GET  {base}/api/sync/pull?since=<ms>&deviceId=<id>  → 200 { serverTime:<ms>, changes:[{col,id,data,deleted}] }
Header: Authorization: Bearer <token>
```

Collections: users, companies, products, stock_moves, purchases, routes, shops, schemes, orders, load_sheets,
returns, recoveries, recovery_slips, accounts, vouchers, pings, activity_logs.

## Automatic accounting

| Event | Entry |
|---|---|
| Purchase | Dr Stock / Cr Company payable |
| Invoice | Dr Shop khata / Cr Sales; Dr COGS / Cr Stock |
| Sale return (approved) | Dr Sales returns / Cr Shop khata; fresh: Dr Stock / Cr COGS |
| Recovery slip (approved) | Dr Cash / Cr Shop khata (per shop); short → Dr Salesman; excess → Cr Other income |
| Damage / short | Dr Stock damage / Cr Stock |
| Expense | Dr Expense head / Cr Cash or Bank |
