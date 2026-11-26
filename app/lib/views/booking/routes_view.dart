import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/permissions.dart';
import '../../controllers/shop_controller.dart';
import '../../controllers/user_controller.dart';
import '../../models/base_model.dart';
import '../../models/shop.dart';
import '../../models/user.dart';
import '../shell/shell_page.dart';
import '../widgets/common.dart';

class RoutesView extends StatelessWidget {
  const RoutesView({super.key});

  @override
  Widget build(BuildContext context) {
    final shops = context.watch<ShopController>();
    final users = context.watch<UserController>();
    final auth = context.watch<AuthController>();
    final today = weekDays[DateTime.now().weekday - 1];
    final list = shops.routes;
    return ShellPage(
      title: 'Routes – Day-wise Plan',
      fab: auth.can(Scr.routes, PermAction.add)
          ? FloatingActionButton(onPressed: () => _edit(context, null), child: const Icon(Icons.add_rounded))
          : null,
      body: list.isEmpty
          ? const EmptyState(icon: Icons.alt_route_outlined, text: 'No routes yet', sub: 'Create routes and assign days')
          : ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 90), children: [
              // weekly plan strip
              AppCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Weekly plan', style: TextStyle(fontWeight: FontWeight.w700)),
                  const Gap(8),
                  for (final d in weekDays)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(children: [
                        Container(
                          width: 42,
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: d == today ? AppColors.navy : AppColors.blue.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(d,
                              style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w700, color: d == today ? Colors.white : AppColors.navy)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            list.where((r) => r.days.contains(d)).map((r) => r.name).join(', ').ifEmpty('—'),
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ]),
                    ),
                ]),
              ).entrance(0),
              const Gap(),
              for (var i = 0; i < list.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AppCard(
                    onTap: auth.can(Scr.routes, PermAction.edit) ? () => _edit(context, list[i]) : null,
                    child: Row(children: [
                      Avatar(list[i].name.isEmpty ? '?' : list[i].name[0].toUpperCase(), color: AppColors.teal),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(list[i].name, style: const TextStyle(fontWeight: FontWeight.w600)),
                          Text(
                            '${list[i].area} · ${shops.shopsOnRoute(list[i].id).length} shops · '
                            '${users.fieldUsers.where((u) => u.routeId == list[i].id).map((u) => u.name).join(', ').ifEmpty('no staff')}',
                            style: const TextStyle(fontSize: 12, color: AppColors.muted),
                          ),
                          const Gap(6),
                          Wrap(spacing: 4, children: [
                            for (final d in list[i].days) StatusChip(d, color: d == today ? AppColors.green : AppColors.navy),
                          ]),
                        ]),
                      ),
                    ]),
                  ).entrance(i + 1),
                ),
            ]),
    );
  }

  Future<void> _edit(BuildContext context, RouteModel? r) async {
    final isNew = r == null;
    final route = r ?? RouteModel(id: newId(), name: '');
    final name = TextEditingController(text: route.name);
    final area = TextEditingController(text: route.area);
    final days = {...route.days};
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(c).viewInsets.bottom + 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(isNew ? 'New route' : 'Edit route', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const Gap(),
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Route name')),
            const Gap(),
            TextField(controller: area, decoration: const InputDecoration(labelText: 'Area')),
            const Gap(),
            const Text('Visit days', style: TextStyle(fontWeight: FontWeight.w600)),
            const Gap(6),
            Wrap(spacing: 6, children: [
              for (final d in weekDays)
                FilterChip(
                  label: Text(d),
                  selected: days.contains(d),
                  onSelected: (v) => set(() => v ? days.add(d) : days.remove(d)),
                ),
            ]),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Active'),
              value: route.active,
              onChanged: (v) => set(() => route.active = v),
            ),
            const Gap(),
            FilledButton(
              onPressed: () async {
                route.name = name.text.trim();
                route.area = area.text.trim();
                route.days = weekDays.where(days.contains).toList();
                final err = await context.read<ShopController>().saveRoute(route, isNew: isNew);
                if (!c.mounted) return;
                if (handleResult(c, err)) Navigator.pop(c);
              },
              child: const Text('Save route'),
            ),
          ]),
        ),
      ),
    );
  }
}

extension on String {
  String ifEmpty(String other) => isEmpty ? other : this;
}
