import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../controllers/report_controller.dart';
import '../../models/user.dart';
import '../../services/pdf_service.dart';
import '../shell/shell_page.dart';
import '../widgets/common.dart';

class PerformanceView extends StatefulWidget {
  const PerformanceView({super.key});

  @override
  State<PerformanceView> createState() => _PerformanceViewState();
}

class _PerformanceViewState extends State<PerformanceView> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month, 1);

  @override
  Widget build(BuildContext context) {
    final rep = context.watch<ReportController>();
    final rows = rep.performance(_month);

    PrintDoc doc() => PrintDoc(
          title: 'PERFORMANCE REPORT',
          number: DateFormat('MMMM yyyy').format(_month),
          headers: ['Name', 'Role', 'Target', 'Achieved', '%', 'Orders', 'Productive shops', 'Recovery'],
          rows: [
            for (final r in rows)
              [
                r.user.name,
                r.user.role.label,
                num0(r.target),
                num0(r.achieved),
                r.target > 0 ? '${r.pct.toStringAsFixed(0)}%' : '-',
                '${r.orders}',
                '${r.productiveShops}/${r.totalShops}',
                num0(r.recovery),
              ]
          ],
        );

    return ShellPage(
      title: 'Performance',
      actions: [
        PrintMenu(
          onShare: () => PdfService.instance.share(doc(), 'performance.pdf', landscape: true),
          onPrint: () => PdfService.instance.printDoc(doc(), landscape: true),
        ),
      ],
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
        MonthBar(month: _month, onChanged: (m) => setState(() => _month = m)),
        const Gap(),
        if (rows.isEmpty) const EmptyState(icon: Icons.emoji_events_outlined, text: 'No bookers / salesmen yet'),
        for (var i = 0; i < rows.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _card(rows[i], i).entrance(i),
          ),
      ]),
    );
  }

  Widget _card(PerfRow r, int rank) {
    final pct = r.target > 0 ? (r.achieved / r.target).clamp(0.0, 1.0) : 0.0;
    final color = pct >= 1
        ? AppColors.green
        : pct >= 0.7
            ? AppColors.teal
            : pct >= 0.4
                ? AppColors.amber
                : AppColors.red;
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Stack(clipBehavior: Clip.none, children: [
            Avatar(r.user.initials, color: r.user.role == UserRole.booker ? AppColors.navy : AppColors.teal),
            if (rank < 3)
              Positioned(
                right: -6,
                top: -6,
                child: Icon(Icons.emoji_events_rounded,
                    size: 20, color: [const Color(0xFFFFC107), const Color(0xFFB0BEC5), const Color(0xFFCD7F32)][rank]),
              ),
          ]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.user.name, style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(r.user.role.label, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(money(r.achieved), style: const TextStyle(fontWeight: FontWeight.w800)),
            Text(r.target > 0 ? 'of ${num0(r.target)} target' : 'no target', style: const TextStyle(fontSize: 11, color: AppColors.muted)),
          ]),
        ]),
        if (r.target > 0) ...[
          const Gap(10),
          Row(children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: pct),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, __) =>
                      LinearProgressIndicator(value: v, minHeight: 8, color: color, backgroundColor: color.withValues(alpha: 0.12)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text('${r.pct.toStringAsFixed(0)}%', style: TextStyle(fontWeight: FontWeight.w800, color: color)),
          ]),
        ],
        const Gap(10),
        Row(children: [
          _mini('Orders', '${r.orders}'),
          _mini('Productive shops', '${r.productiveShops}/${r.totalShops}'),
          _mini('Recovery', num0(r.recovery)),
        ]),
      ]),
    );
  }

  Widget _mini(String k, String v) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(v, style: const TextStyle(fontWeight: FontWeight.w700)),
          Text(k, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
        ]),
      );
}
