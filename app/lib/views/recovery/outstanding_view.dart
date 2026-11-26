import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/recovery_controller.dart';
import '../../controllers/shop_controller.dart';
import '../../models/user.dart';
import '../../services/pdf_service.dart';
import '../booking/shops_view.dart';
import '../shell/shell_page.dart';
import '../widgets/common.dart';

class OutstandingView extends StatefulWidget {
  const OutstandingView({super.key});

  @override
  State<OutstandingView> createState() => _OutstandingViewState();
}

class _OutstandingViewState extends State<OutstandingView> {
  String? _route;
  bool _init = false;

  @override
  Widget build(BuildContext context) {
    final rc = context.watch<RecoveryController>();
    final shops = context.watch<ShopController>();
    final me = context.watch<AuthController>().user!;
    if (!_init) {
      _init = true;
      if (me.role.isField && me.routeId.isNotEmpty) _route = me.routeId;
    }
    final rows = rc.aging().where((r) => _route == null || shops.shop(r.shopId)?.routeId == _route).toList();
    final total = rows.fold(0.0, (s, r) => s + r.balance);
    double sum(double Function(AgingRow) f) => rows.fold(0.0, (s, r) => s + f(r));

    PrintDoc doc() => PrintDoc(
          title: 'OUTSTANDING & AGING',
          partyLines: [_route == null ? 'All routes' : 'Route: ${shops.routeName(_route!)}'],
          headers: ['Shop', 'Khata', 'Bills', '0-7', '8-15', '16-30', '30+', 'Balance'],
          rows: [
            for (final r in rows)
              [
                shops.shopName(r.shopId),
                shops.shop(r.shopId)?.khataNo ?? '',
                '${r.bills}',
                num0(r.d0to7),
                num0(r.d8to15),
                num0(r.d16to30),
                num0(r.d30plus),
                num0(r.balance),
              ]
          ],
          totals: [MapEntry('Total outstanding', money(total))],
        );

    return ShellPage(
      title: 'Outstanding & Aging',
      actions: [
        PrintMenu(
          onShare: () => PdfService.instance.share(doc(), 'outstanding.pdf', landscape: true),
          onPrint: () => PdfService.instance.printDoc(doc(), landscape: true),
        ),
      ],
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
        SizedBox(
          height: 42,
          child: ListView(scrollDirection: Axis.horizontal, children: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(label: const Text('All'), selected: _route == null, onSelected: (_) => setState(() => _route = null)),
            ),
            for (final r in shops.routes)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(label: Text(r.name), selected: _route == r.id, onSelected: (_) => setState(() => _route = r.id)),
              ),
          ]),
        ),
        const Gap(),
        AppCard(
          gradient: AppColors.soft(AppColors.amber),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Total market outstanding', style: TextStyle(color: Colors.white70)),
            Text(money(total), style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
            const Gap(10),
            Row(children: [
              _age('0-7 days', sum((r) => r.d0to7)),
              _age('8-15', sum((r) => r.d8to15)),
              _age('16-30', sum((r) => r.d16to30)),
              _age('30+', sum((r) => r.d30plus)),
            ]),
          ]),
        ).entrance(0),
        const Gap(),
        if (rows.isEmpty) const EmptyState(icon: Icons.celebration_outlined, text: 'No outstanding – all recovered!'),
        for (var i = 0; i < rows.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AppCard(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ShopDetailView(shopId: rows[i].shopId))),
              child: Column(children: [
                Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(shops.shopName(rows[i].shopId), style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text('${shops.shop(rows[i].shopId)?.khataNo ?? ''} · ${rows[i].bills} pending bills',
                          style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                    ]),
                  ),
                  Text(money(rows[i].balance), style: const TextStyle(fontWeight: FontWeight.w800)),
                ]),
                if (rows[i].d30plus > 0 || rows[i].d16to30 > 0) ...[
                  const Gap(6),
                  Row(children: [
                    if (rows[i].d16to30 > 0) StatusChip('16-30d: ${num0(rows[i].d16to30)}', color: AppColors.amber),
                    const SizedBox(width: 6),
                    if (rows[i].d30plus > 0) StatusChip('30+d: ${num0(rows[i].d30plus)}', color: AppColors.red),
                  ]),
                ],
              ]),
            ).entrance(i + 1),
          ),
      ]),
    );
  }

  Widget _age(String k, double v) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          FittedBox(child: Text(num0(v), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
          Text(k, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ]),
      );
}
