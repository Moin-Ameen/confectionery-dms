import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../controllers/accounts_controller.dart';
import '../../controllers/inventory_controller.dart';
import '../../controllers/shop_controller.dart';
import '../../controllers/user_controller.dart';
import '../../models/accounts.dart';
import '../../services/pdf_service.dart';
import '../shell/shell_page.dart';
import '../widgets/common.dart';

class LedgersView extends StatefulWidget {
  const LedgersView({super.key});

  @override
  State<LedgersView> createState() => _LedgersViewState();
}

class _LedgersViewState extends State<LedgersView> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final acc = context.watch<AccountsController>();
    final shops = context.watch<ShopController>();
    final inv = context.watch<InventoryController>();
    final users = context.watch<UserController>();
    final shopBal = acc.allShopBalances();
    bool m(String s) => _q.isEmpty || s.toLowerCase().contains(_q);

    Widget tile(String title, String sub, double bal, VoidCallback onTap, int i) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: AppCard(
            onTap: onTap,
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                  if (sub.isNotEmpty) Text(sub, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                ]),
              ),
              Text(money(bal), style: const TextStyle(fontWeight: FontWeight.w700)),
              const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
            ]),
          ).entrance(i),
        );

    void open(Widget page) => Navigator.push(context, MaterialPageRoute(builder: (_) => page));

    return DefaultTabController(
      length: 4,
      child: ShellPage(
        title: 'Ledgers',
        bottom: const TabBar(isScrollable: true, tabAlignment: TabAlignment.start, tabs: [
          Tab(text: 'Shop khata'),
          Tab(text: 'Companies'),
          Tab(text: 'Salesmen'),
          Tab(text: 'Accounts'),
        ]),
        body: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: SearchField(onChanged: (v) => setState(() => _q = v.toLowerCase())),
          ),
          Expanded(
            child: TabBarView(children: [
              ListView(padding: const EdgeInsets.all(16), children: [
                for (final (i, s) in shops.shops.where((s) => m(s.name) || m(s.khataNo)).indexed)
                  tile(s.name, s.khataNo, shopBal[s.id] ?? 0,
                      () => open(PartyLedgerPage(partyType: PartyType.shop, partyId: s.id, title: '${s.name} – Khata')), i),
              ]),
              ListView(padding: const EdgeInsets.all(16), children: [
                for (final (i, c) in inv.companies.where((c) => m(c.name)).indexed)
                  tile(c.name, 'Payable', acc.partyBalance(PartyType.company, c.id),
                      () => open(PartyLedgerPage(partyType: PartyType.company, partyId: c.id, title: c.name)), i),
              ]),
              ListView(padding: const EdgeInsets.all(16), children: [
                for (final (i, u) in users.fieldUsers.where((u) => m(u.name)).indexed)
                  tile(u.name, 'Short / advance receivable', acc.partyBalance(PartyType.salesman, u.id),
                      () => open(PartyLedgerPage(partyType: PartyType.salesman, partyId: u.id, title: u.name)), i),
              ]),
              ListView(padding: const EdgeInsets.all(16), children: [
                for (final (i, a) in acc.accounts.where((a) => m(a.name) || m(a.code)).indexed)
                  tile('${a.code}  ${a.name}', a.type.label, acc.balance(a.id),
                      () => open(AccountLedgerPage(accountId: a.id)), i),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

class PartyLedgerPage extends StatelessWidget {
  final String partyType;
  final String partyId;
  final String title;
  const PartyLedgerPage({super.key, required this.partyType, required this.partyId, required this.title});

  @override
  Widget build(BuildContext context) {
    final acc = context.watch<AccountsController>();
    String? accountId;
    if (partyType == PartyType.shop) accountId = acc.sys(SysAcc.receivable).id;
    if (partyType == PartyType.company) accountId = acc.sys(SysAcc.payable).id;
    return _LedgerPage(
      title: title,
      build: (from, to) => acc.ledger(accountId: accountId, partyType: partyType, partyId: partyId, from: from, to: to),
      balanceLabel: partyType == PartyType.company ? 'Payable' : 'Receivable',
    );
  }
}

class AccountLedgerPage extends StatelessWidget {
  final String accountId;
  const AccountLedgerPage({super.key, required this.accountId});

  @override
  Widget build(BuildContext context) {
    final acc = context.watch<AccountsController>();
    final a = acc.byId(accountId);
    return _LedgerPage(
      title: a == null ? 'Ledger' : '${a.code} ${a.name}',
      build: (from, to) => acc.ledger(accountId: accountId, from: from, to: to),
      balanceLabel: 'Balance',
    );
  }
}

class _LedgerPage extends StatefulWidget {
  final String title;
  final List<LedgerRow> Function(DateTime? from, DateTime? to) build;
  final String balanceLabel;
  const _LedgerPage({required this.title, required this.build, required this.balanceLabel});

  @override
  State<_LedgerPage> createState() => _LedgerPageState();
}

class _LedgerPageState extends State<_LedgerPage> {
  DateTimeRange? _range;

  PrintDoc _doc(List<LedgerRow> rows) => PrintDoc(
        title: 'LEDGER',
        partyLines: [
          widget.title,
          if (_range != null) 'From ${dateFmt(_range!.start)} to ${dateFmt(_range!.end)}',
        ],
        headers: ['Date', 'Voucher', 'Narration', 'Debit', 'Credit', 'Balance'],
        rows: [
          for (final r in rows)
            [
              dateFmt(r.date),
              r.voucherNo == 0 ? r.voucherType : '${r.voucherType} #${r.voucherNo}',
              r.narration,
              r.debit == 0 ? '' : num0(r.debit),
              r.credit == 0 ? '' : num0(r.credit),
              num0(r.balance),
            ]
        ],
        totals: [MapEntry('Closing ${widget.balanceLabel.toLowerCase()}', money(rows.isEmpty ? 0 : rows.last.balance))],
      );

  @override
  Widget build(BuildContext context) {
    final to = _range == null ? null : _range!.end.add(const Duration(days: 1));
    final rows = widget.build(_range?.start, to);
    final closing = rows.isEmpty ? 0.0 : rows.last.balance;
    final dr = rows.fold(0.0, (s, r) => s + r.debit);
    final cr = rows.fold(0.0, (s, r) => s + r.credit);
    return Scaffold(
      appBar: AppBar(title: Text(widget.title), actions: [
        IconButton(
          icon: Icon(_range == null ? Icons.date_range_rounded : Icons.event_busy_rounded),
          onPressed: () async {
            if (_range != null) {
              setState(() => _range = null);
              return;
            }
            final r = await showDateRangePicker(
              context: context,
              firstDate: DateTime(2020),
              lastDate: DateTime.now().add(const Duration(days: 1)),
            );
            if (r != null) setState(() => _range = r);
          },
        ),
        PrintMenu(
          onShare: () => PdfService.instance.share(_doc(rows), 'ledger.pdf'),
          onPrint: () => PdfService.instance.printDoc(_doc(rows)),
        ),
      ]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        AppCard(
          gradient: AppColors.primaryGradient,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_range == null ? 'All time' : '${dateFmt(_range!.start)} – ${dateFmt(_range!.end)}',
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
            Text('${widget.balanceLabel}: ${money(closing)}',
                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
            const Gap(6),
            Text('Debit ${num0(dr)}  ·  Credit ${num0(cr)}', style: const TextStyle(color: Colors.white70)),
          ]),
        ).entrance(0),
        const Gap(),
        if (rows.isEmpty) const EmptyState(icon: Icons.menu_book_outlined, text: 'No entries'),
        for (var i = rows.length - 1; i >= 0; i--)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(rows[i].narration.isEmpty ? rows[i].voucherType : rows[i].narration,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    Text(
                        '${dateTimeFmt(rows[i].date)} · ${rows[i].voucherNo == 0 ? rows[i].voucherType : '${rows[i].voucherType} #${rows[i].voucherNo}'}',
                        style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                  ]),
                ),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  if (rows[i].debit > 0)
                    Text('Dr ${num0(rows[i].debit)}', style: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.w700)),
                  if (rows[i].credit > 0)
                    Text('Cr ${num0(rows[i].credit)}', style: const TextStyle(color: AppColors.green, fontWeight: FontWeight.w700)),
                  Text('Bal ${num0(rows[i].balance)}', style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                ]),
              ]),
            ),
          ),
        Center(child: Text('Amounts in ${AppConfig.currency}', style: const TextStyle(fontSize: 11, color: AppColors.muted))),
      ]),
    );
  }
}
