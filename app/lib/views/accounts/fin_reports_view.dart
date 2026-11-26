import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../controllers/accounts_controller.dart';
import '../../services/pdf_service.dart';
import '../shell/shell_page.dart';
import '../widgets/common.dart';

class FinReportsView extends StatefulWidget {
  const FinReportsView({super.key});

  @override
  State<FinReportsView> createState() => _FinReportsViewState();
}

class _FinReportsViewState extends State<FinReportsView> with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 4, vsync: this);
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month, 1);
  bool _wholeYear = false;

  DateTime get _from => _wholeYear ? DateTime(_month.year, 1, 1) : _month;
  DateTime get _to => _wholeYear ? DateTime(_month.year + 1, 1, 1) : DateTime(_month.year, _month.month + 1, 1);
  String get _period => _wholeYear ? 'Year ${_month.year}' : DateFormat('MMMM yyyy').format(_month);

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  PrintDoc _doc(AccountsController acc) {
    switch (_tab.index) {
      case 0:
        final tb = acc.trialBalance(to: _to);
        return PrintDoc(
          title: 'TRIAL BALANCE',
          partyLines: ['As of ${dateFmt(_to.subtract(const Duration(days: 1)))}'],
          headers: ['Code', 'Account', 'Debit', 'Credit'],
          rows: [for (final r in tb) [r.account.code, r.account.name, r.debit == 0 ? '' : num0(r.debit), r.credit == 0 ? '' : num0(r.credit)]],
          totals: [
            MapEntry('Total debit', money(tb.fold(0.0, (s, r) => s + r.debit))),
            MapEntry('Total credit', money(tb.fold(0.0, (s, r) => s + r.credit))),
          ],
        );
      case 1:
        final p = acc.profitLoss(from: _from, to: _to);
        return PrintDoc(
          title: 'PROFIT & LOSS',
          partyLines: [_period],
          headers: ['Particular', 'Amount'],
          rows: [
            ['Sales', num0(p.sales)],
            ['Less: sales returns', num0(p.salesReturns)],
            ['Net sales', num0(p.netSales)],
            ['Less: cost of goods sold', num0(p.cogs)],
            ['Gross profit', num0(p.grossProfit)],
            ['Other income', num0(p.otherIncome)],
            for (final e in p.expenses.entries) ['Expense: ${e.key}', num0(e.value)],
          ],
          totals: [MapEntry('Net profit', money(p.netProfit))],
        );
      case 2:
        final bs = acc.balanceSheet(asOf: _to);
        return PrintDoc(
          title: 'BALANCE SHEET',
          partyLines: ['As of ${dateFmt(_to.subtract(const Duration(days: 1)))}'],
          headers: ['Section', 'Account', 'Amount'],
          rows: [
            for (final s in bs.entries)
              for (final e in s.value.entries) [s.key, e.key, num0(e.value)],
          ],
          totals: [for (final s in bs.entries) MapEntry('Total ${s.key.toLowerCase()}', money(s.value.values.fold(0.0, (a, b) => a + b)))],
        );
      default:
        final mp = acc.monthlyProfit(months: 12);
        return PrintDoc(
          title: 'MONTHLY PROFIT',
          headers: ['Month', 'Net profit'],
          rows: [for (final e in mp) [e.key, num0(e.value)]],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final acc = context.watch<AccountsController>();
    return ShellPage(
      title: 'Financial Reports',
      actions: [
        PrintMenu(
          onShare: () => PdfService.instance.share(_doc(acc), 'financial_report.pdf'),
          onPrint: () => PdfService.instance.printDoc(_doc(acc)),
        ),
      ],
      bottom: TabBar(controller: _tab, isScrollable: true, tabAlignment: TabAlignment.start, tabs: const [
        Tab(text: 'Trial balance'),
        Tab(text: 'Profit & loss'),
        Tab(text: 'Balance sheet'),
        Tab(text: 'Monthly profit'),
      ]),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Row(children: [
            Expanded(child: MonthBar(month: _month, onChanged: (m) => setState(() => _month = m))),
            const SizedBox(width: 8),
            FilterChip(label: const Text('Full year'), selected: _wholeYear, onSelected: (v) => setState(() => _wholeYear = v)),
          ]),
        ),
        Expanded(
          child: TabBarView(controller: _tab, children: [
            _trial(acc),
            _pnl(acc),
            _bs(acc),
            _monthly(acc),
          ]),
        ),
      ]),
    );
  }

  Widget _trial(AccountsController acc) {
    final tb = acc.trialBalance(to: _to);
    final dr = tb.fold(0.0, (s, r) => s + r.debit);
    final cr = tb.fold(0.0, (s, r) => s + r.credit);
    return ListView(padding: const EdgeInsets.all(16), children: [
      AppCard(
        padding: const EdgeInsets.all(8),
        child: Column(children: [
          const Padding(
            padding: EdgeInsets.all(6),
            child: Row(children: [
              Expanded(child: Text('Account', style: TextStyle(fontWeight: FontWeight.w700))),
              SizedBox(width: 90, child: Text('Debit', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w700))),
              SizedBox(width: 90, child: Text('Credit', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w700))),
            ]),
          ),
          const Divider(height: 1),
          for (final r in tb)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
              child: Row(children: [
                Expanded(child: Text('${r.account.code} ${r.account.name}', style: const TextStyle(fontSize: 13))),
                SizedBox(width: 90, child: Text(r.debit == 0 ? '' : num0(r.debit), textAlign: TextAlign.right)),
                SizedBox(width: 90, child: Text(r.credit == 0 ? '' : num0(r.credit), textAlign: TextAlign.right)),
              ]),
            ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(6),
            child: Row(children: [
              const Expanded(child: Text('Total', style: TextStyle(fontWeight: FontWeight.w800))),
              SizedBox(width: 90, child: Text(num0(dr), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w800))),
              SizedBox(width: 90, child: Text(num0(cr), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w800))),
            ]),
          ),
        ]),
      ).entrance(0),
      const Gap(8),
      Center(
        child: StatusChip((dr - cr).abs() < 1 ? 'balanced' : 'not balanced',
            color: (dr - cr).abs() < 1 ? AppColors.green : AppColors.red),
      ),
    ]);
  }

  Widget _pnl(AccountsController acc) {
    final p = acc.profitLoss(from: _from, to: _to);
    Widget row(String k, double v, {bool bold = false, bool minus = false, Color? color}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(children: [
            Expanded(child: Text(k, style: TextStyle(fontWeight: bold ? FontWeight.w700 : null))),
            Text('${minus ? '- ' : ''}${num0(v)}', style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w500, color: color)),
          ]),
        );
    return ListView(padding: const EdgeInsets.all(16), children: [
      AppCard(
        gradient: AppColors.soft(p.netProfit >= 0 ? AppColors.green : AppColors.red),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Net profit · $_period', style: const TextStyle(color: Colors.white70)),
          Text(money(p.netProfit), style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)),
        ]),
      ).entrance(0),
      const Gap(),
      AppCard(
        child: Column(children: [
          row('Sales', p.sales),
          row('Sales returns', p.salesReturns, minus: true),
          const Divider(),
          row('Net sales', p.netSales, bold: true),
          row('Cost of goods sold', p.cogs, minus: true),
          const Divider(),
          row('Gross profit', p.grossProfit, bold: true, color: AppColors.teal),
          row('Other income', p.otherIncome),
          for (final e in p.expenses.entries) row(e.key, e.value, minus: true),
          const Divider(),
          row('Net profit', p.netProfit, bold: true, color: p.netProfit >= 0 ? AppColors.green : AppColors.red),
        ]),
      ).entrance(1),
    ]);
  }

  Widget _bs(AccountsController acc) {
    final bs = acc.balanceSheet(asOf: _to);
    final colors = {'Assets': AppColors.teal, 'Liabilities': AppColors.amber, 'Equity': AppColors.purple};
    return ListView(padding: const EdgeInsets.all(16), children: [
      for (final (i, s) in bs.entries.indexed) ...[
        SectionTitle(s.key, trailing: Text(money(s.value.values.fold(0.0, (a, b) => a + b)),
            style: TextStyle(fontWeight: FontWeight.w800, color: colors[s.key]))),
        AppCard(
          child: Column(children: [
            if (s.value.isEmpty) const Text('—', style: TextStyle(color: AppColors.muted)),
            for (final e in s.value.entries) KV(e.key, num0(e.value)),
          ]),
        ).entrance(i),
      ],
      const Gap(),
      Builder(builder: (_) {
        final a = bs['Assets']!.values.fold(0.0, (x, y) => x + y);
        final le = bs['Liabilities']!.values.fold(0.0, (x, y) => x + y) + bs['Equity']!.values.fold(0.0, (x, y) => x + y);
        return Center(
          child: StatusChip((a - le).abs() < 1 ? 'assets = liabilities + equity' : 'difference ${num0(a - le)}',
              color: (a - le).abs() < 1 ? AppColors.green : AppColors.red),
        );
      }),
    ]);
  }

  Widget _monthly(AccountsController acc) {
    final mp = acc.monthlyProfit(months: 12);
    final maxAbs = mp.fold<double>(1, (m, e) => e.value.abs() > m ? e.value.abs() : m);
    return ListView(padding: const EdgeInsets.all(16), children: [
      for (final (i, e) in mp.reversed.indexed)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text(DateFormat('MMMM yyyy').format(DateTime.parse('${e.key}-01')),
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                Text(money(e.value), style: TextStyle(fontWeight: FontWeight.w800, color: e.value >= 0 ? AppColors.green : AppColors.red)),
              ]),
              const Gap(8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: e.value.abs() / maxAbs),
                  duration: Duration(milliseconds: 500 + i * 50),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, __) => LinearProgressIndicator(
                    value: v,
                    minHeight: 8,
                    color: e.value >= 0 ? AppColors.green : AppColors.red,
                    backgroundColor: AppColors.muted.withValues(alpha: 0.12),
                  ),
                ),
              ),
            ]),
          ).entrance(i),
        ),
      Center(child: Text('Amounts in ${AppConfig.currency}', style: const TextStyle(fontSize: 11, color: AppColors.muted))),
    ]);
  }
}
