import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../controllers/accounts_controller.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/base_controller.dart';
import '../../controllers/inventory_controller.dart';
import '../../controllers/permissions.dart';
import '../../controllers/shop_controller.dart';
import '../../controllers/user_controller.dart';
import '../../models/accounts.dart';
import '../../models/base_model.dart';
import '../../models/user.dart';
import '../../services/pdf_service.dart';
import '../shell/shell_page.dart';
import '../widgets/common.dart';

/// Returns the party label for a voucher line (shop / company / salesman).
String partyLabel(BuildContext context, VoucherLine l) {
  if (l.partyId.isEmpty) return '';
  switch (l.partyType) {
    case PartyType.shop:
      return context.read<ShopController>().shopName(l.partyId);
    case PartyType.company:
      return context.read<InventoryController>().companyName(l.partyId);
    case PartyType.salesman:
      return context.read<UserController>().nameOf(l.partyId);
  }
  return '';
}

class VouchersView extends StatefulWidget {
  const VouchersView({super.key});

  @override
  State<VouchersView> createState() => _VouchersViewState();
}

class _VouchersViewState extends State<VouchersView> {
  String _type = 'All';

  @override
  Widget build(BuildContext context) {
    final acc = context.watch<AccountsController>();
    final auth = context.watch<AuthController>();
    final types = ['All', ...acc.vouchers.map((v) => v.type).toSet()];
    final list = acc.vouchers.where((v) => _type == 'All' || v.type == _type).take(300).toList();
    return ShellPage(
      title: 'Vouchers',
      fab: auth.can(Scr.vouchers, PermAction.add)
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VoucherForm())),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Voucher'),
            )
          : null,
      body: Column(children: [
        SizedBox(
          height: 46,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12), children: [
            for (final t in types)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(label: Text(t), selected: _type == t, onSelected: (_) => setState(() => _type = t)),
              ),
          ]),
        ),
        Expanded(
          child: list.isEmpty
              ? const EmptyState(icon: Icons.receipt_outlined, text: 'No vouchers')
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final v = list[i];
                    return AppCard(
                      onTap: () => _detail(context, v),
                      child: Row(children: [
                        Avatar(v.type.isEmpty ? '?' : v.type[0], color: v.auto ? AppColors.teal : AppColors.purple, size: 38),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('${v.type} #${v.no}', style: const TextStyle(fontWeight: FontWeight.w600)),
                            Text('${dateTimeFmt(v.date)} · ${v.narration}',
                                style: const TextStyle(fontSize: 12, color: AppColors.muted),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ]),
                        ),
                        Text(num0(v.totalDebit), style: const TextStyle(fontWeight: FontWeight.w700)),
                      ]),
                    ).entrance(i);
                  },
                ),
        ),
      ]),
    );
  }

  void _detail(BuildContext context, Voucher v) {
    final acc = context.read<AccountsController>();
    final auth = context.read<AuthController>();
    final users = context.read<UserController>();
    PrintDoc doc() => PrintDoc(
          title: v.type.toUpperCase(),
          number: '#${v.no}',
          date: v.date,
          partyLines: [if (v.narration.isNotEmpty) v.narration, 'Entered by ${users.nameOf(v.userId)}'],
          headers: ['Account', 'Party', 'Debit', 'Credit'],
          rows: [
            for (final l in v.lines)
              [acc.byId(l.accountId)?.name ?? '-', partyLabel(context, l), l.debit == 0 ? '' : num0(l.debit), l.credit == 0 ? '' : num0(l.credit)]
          ],
          totals: [MapEntry('Total', money(v.totalDebit))],
        );
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (c) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: Text('${v.type} #${v.no}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
            PrintMenu(
              onShare: () => PdfService.instance.share(doc(), 'voucher_${v.no}.pdf'),
              onPrint: () => PdfService.instance.printDoc(doc()),
            ),
          ]),
          Text('${dateTimeFmt(v.date)} · ${v.auto ? 'Automatic' : 'Manual'} · ${users.nameOf(v.userId)}',
              style: const TextStyle(color: AppColors.muted)),
          if (v.narration.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(v.narration)),
          const Gap(),
          for (final l in v.lines)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(acc.byId(l.accountId)?.name ?? '-'),
              subtitle: Text([partyLabel(context, l), l.memo].where((e) => e.isNotEmpty).join(' · ')),
              trailing: Text(l.debit > 0 ? 'Dr ${num0(l.debit)}' : 'Cr ${num0(l.credit)}',
                  style: TextStyle(fontWeight: FontWeight.w700, color: l.debit > 0 ? AppColors.navy : AppColors.green)),
            ),
          if (!v.auto && auth.can(Scr.vouchers, PermAction.delete)) ...[
            const Gap(),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.red),
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('Delete voucher'),
              onPressed: () async {
                final ok = await confirmDialog(c, 'Delete voucher', 'Delete ${v.type} #${v.no}?', ok: 'Delete', color: AppColors.red);
                if (!ok) return;
                final err = await acc.deleteVoucher(v);
                if (!c.mounted) return;
                if (handleResult(c, err)) Navigator.pop(c);
              },
            ),
          ],
        ]),
      ),
    );
  }
}

class _Line {
  String accountId = '';
  String partyType = '';
  String partyId = '';
  final debit = TextEditingController();
  final credit = TextEditingController();
  final memo = TextEditingController();
}

/// Manual cash / bank / journal voucher.
class VoucherForm extends StatefulWidget {
  final String type;
  const VoucherForm({super.key, this.type = VoucherType.journal});

  @override
  State<VoucherForm> createState() => _VoucherFormState();
}

class _VoucherFormState extends State<VoucherForm> {
  late String _type = widget.type;
  DateTime _date = DateTime.now();
  final _narr = TextEditingController();
  final List<_Line> _lines = [_Line(), _Line()];

  double _sum(bool debit) => _lines.fold(0.0, (s, l) => s + (double.tryParse((debit ? l.debit : l.credit).text) ?? 0));

  String _partyTypeFor(Account? a) {
    if (a == null) return '';
    if (a.sysKey == SysAcc.receivable) return PartyType.shop;
    if (a.sysKey == SysAcc.payable) return PartyType.company;
    if (a.sysKey == SysAcc.salesmanRecv) return PartyType.salesman;
    return '';
  }

  Future<void> _pickParty(_Line l) async {
    final shops = context.read<ShopController>();
    final inv = context.read<InventoryController>();
    final users = context.read<UserController>();
    String? id;
    if (l.partyType == PartyType.shop) {
      id = (await pickFromList(context, title: 'Select shop', items: shops.shops, label: (s) => s.name, subtitle: (s) => s.khataNo))?.id;
    } else if (l.partyType == PartyType.company) {
      id = (await pickFromList(context, title: 'Select company', items: inv.companies, label: (c) => c.name))?.id;
    } else if (l.partyType == PartyType.salesman) {
      id = (await pickFromList(context, title: 'Select staff', items: users.fieldUsers, label: (u) => u.name, subtitle: (u) => u.role.label))?.id;
    }
    if (id != null) setState(() => l.partyId = id!);
  }

  Future<void> _save() async {
    final acc = context.read<AccountsController>();
    final lines = <VoucherLine>[];
    for (final l in _lines) {
      final d = double.tryParse(l.debit.text) ?? 0;
      final c = double.tryParse(l.credit.text) ?? 0;
      if (l.accountId.isEmpty || (d == 0 && c == 0)) continue;
      if (l.partyType.isNotEmpty && l.partyId.isEmpty) {
        showSnack(context, 'Select party for ${acc.byId(l.accountId)?.name}', error: true);
        return;
      }
      lines.add(VoucherLine(accountId: l.accountId, debit: d, credit: c, partyType: l.partyType, partyId: l.partyId, memo: l.memo.text.trim()));
    }
    final v = Voucher(id: newId(), no: 0, type: _type, date: _date, narration: _narr.text.trim(), lines: lines, userId: Session.userId);
    final err = await acc.saveManualVoucher(v);
    if (!mounted) return;
    if (handleResult(context, err, success: 'Voucher saved')) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final acc = context.watch<AccountsController>();
    final shops = context.watch<ShopController>();
    final inv = context.watch<InventoryController>();
    final users = context.watch<UserController>();
    final dr = _sum(true), cr = _sum(false);
    final balanced = (dr - cr).abs() < 0.01 && dr > 0;
    String partyName(_Line l) => l.partyType == PartyType.shop
        ? shops.shopName(l.partyId)
        : l.partyType == PartyType.company
            ? inv.companyName(l.partyId)
            : users.nameOf(l.partyId);

    return Scaffold(
      appBar: AppBar(title: const Text('New Voucher')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Wrap(spacing: 6, children: [
          for (final t in VoucherType.manual)
            ChoiceChip(label: Text(t), selected: _type == t, onSelected: (_) => setState(() => _type = t)),
        ]),
        const Gap(),
        Row(children: [
          Expanded(child: TextField(controller: _narr, decoration: const InputDecoration(labelText: 'Narration'))),
          const Gap(),
          OutlinedButton.icon(
            icon: const Icon(Icons.event_rounded, size: 18),
            label: Text(dateFmt(_date)),
            onPressed: () async {
              final d = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2020), lastDate: DateTime.now());
              if (d != null) setState(() => _date = DateTime(d.year, d.month, d.day, DateTime.now().hour, DateTime.now().minute));
            },
          ),
        ]),
        const SectionTitle('Lines'),
        for (var i = 0; i < _lines.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AppCard(
              child: Column(children: [
                Row(children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _lines[i].accountId.isEmpty ? null : _lines[i].accountId,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Account', isDense: true),
                      items: [
                        for (final a in acc.accounts.where((a) => a.active))
                          DropdownMenuItem(value: a.id, child: Text('${a.code} ${a.name}', overflow: TextOverflow.ellipsis)),
                      ],
                      onChanged: (v) => setState(() {
                        _lines[i].accountId = v ?? '';
                        _lines[i].partyType = _partyTypeFor(acc.byId(_lines[i].accountId));
                        _lines[i].partyId = '';
                      }),
                    ),
                  ),
                  if (_lines.length > 2)
                    IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => setState(() => _lines.removeAt(i))),
                ]),
                if (_lines[i].partyType.isNotEmpty) ...[
                  const Gap(8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.person_search_rounded, size: 18),
                    label: Text(_lines[i].partyId.isEmpty ? 'Select ${_lines[i].partyType}' : partyName(_lines[i])),
                    onPressed: () => _pickParty(_lines[i]),
                  ),
                ],
                const Gap(8),
                Row(children: [
                  Expanded(child: NumField(_lines[i].debit, 'Debit', onChanged: (_) => setState(() {}))),
                  const Gap(),
                  Expanded(child: NumField(_lines[i].credit, 'Credit', onChanged: (_) => setState(() {}))),
                ]),
                const Gap(8),
                TextField(controller: _lines[i].memo, decoration: const InputDecoration(labelText: 'Memo (optional)', isDense: true)),
              ]),
            ),
          ),
        TextButton.icon(
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add line'),
          onPressed: () => setState(() => _lines.add(_Line())),
        ),
        const Gap(),
        AppCard(
          color: balanced ? AppColors.green.withValues(alpha: 0.08) : AppColors.red.withValues(alpha: 0.06),
          child: Column(children: [
            KV('Total debit', money(dr)),
            KV('Total credit', money(cr)),
            KV(balanced ? 'Balanced' : 'Difference', balanced ? '✓' : money((dr - cr).abs()),
                bold: true, color: balanced ? AppColors.green : AppColors.red),
          ]),
        ),
        const Gap(20),
        FilledButton.icon(
          icon: const Icon(Icons.check_rounded),
          label: Text('Save ${_type.toLowerCase()} voucher'),
          onPressed: balanced ? _save : null,
        ),
        const Gap(8),
        Text('Example – pay a company: Dr Company Payable (select company) / Cr Cash. Amounts in ${AppConfig.currency}.',
            textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
      ]),
    );
  }
}
