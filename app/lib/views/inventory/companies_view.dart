import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../controllers/accounts_controller.dart';
// ignore_for_file: use_build_context_synchronously
import '../../controllers/auth_controller.dart';
import '../../controllers/inventory_controller.dart';
import '../../controllers/permissions.dart';
import '../../models/accounts.dart';
import '../../models/base_model.dart';
import '../../models/product.dart';
import '../../models/user.dart';
import '../accounts/ledgers_view.dart';
import '../shell/shell_page.dart';
import '../widgets/common.dart';

class CompaniesView extends StatelessWidget {
  const CompaniesView({super.key});

  @override
  Widget build(BuildContext context) {
    final inv = context.watch<InventoryController>();
    final acc = context.watch<AccountsController>();
    final auth = context.watch<AuthController>();
    final list = inv.companies;
    return ShellPage(
      title: 'Companies / Suppliers',
      fab: auth.can(Scr.companies, PermAction.add)
          ? FloatingActionButton(onPressed: () => _edit(context, null), child: const Icon(Icons.add_rounded))
          : null,
      body: list.isEmpty
          ? const EmptyState(icon: Icons.factory_outlined, text: 'No companies yet')
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final c = list[i];
                final payable = acc.partyBalance(PartyType.company, c.id);
                final count = inv.products.where((p) => p.companyId == c.id).length;
                return AppCard(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PartyLedgerPage(partyType: PartyType.company, partyId: c.id, title: c.name),
                    ),
                  ),
                  child: Row(children: [
                    Avatar(c.name.isEmpty ? '?' : c.name[0].toUpperCase(), color: AppColors.purple),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text('$count products${c.phone.isEmpty ? '' : ' · ${c.phone}'}',
                            style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                      ]),
                    ),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(money(payable), style: const TextStyle(fontWeight: FontWeight.w700)),
                      const Text('payable', style: TextStyle(fontSize: 11, color: AppColors.muted)),
                    ]),
                    if (auth.can(Scr.companies, PermAction.edit))
                      IconButton(icon: const Icon(Icons.edit_outlined, size: 20), onPressed: () => _edit(context, c)),
                  ]),
                ).entrance(i);
              },
            ),
    );
  }

  Future<void> _edit(BuildContext context, Company? c) async {
    final isNew = c == null;
    final co = c ?? Company(id: newId(), name: '');
    final name = TextEditingController(text: co.name);
    final phone = TextEditingController(text: co.phone);
    final addr = TextEditingController(text: co.address);
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (c2) => Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(c2).viewInsets.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(isNew ? 'New company' : 'Edit company', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const Gap(),
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Company name')),
          const Gap(),
          TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone')),
          const Gap(),
          TextField(controller: addr, decoration: const InputDecoration(labelText: 'Address')),
          const Gap(16),
          FilledButton(
            onPressed: () async {
              co.name = name.text.trim();
              co.phone = phone.text.trim();
              co.address = addr.text.trim();
              final err = await context.read<InventoryController>().saveCompany(co, isNew: isNew);
              if (!c2.mounted) return;
              if (handleResult(c2, err)) Navigator.pop(c2);
            },
            child: const Text('Save'),
          ),
        ]),
      ),
    );
  }
}
