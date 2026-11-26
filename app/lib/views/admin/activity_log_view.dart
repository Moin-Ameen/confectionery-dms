import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../controllers/tracking_controller.dart';
import '../../controllers/user_controller.dart';
import '../shell/shell_page.dart';
import '../widgets/common.dart';

class ActivityLogView extends StatefulWidget {
  const ActivityLogView({super.key});

  @override
  State<ActivityLogView> createState() => _ActivityLogViewState();
}

class _ActivityLogViewState extends State<ActivityLogView> {
  DateTime _day = DateTime.now();
  String _user = '';

  IconData _icon(String a) => switch (a) {
        'created' => Icons.add_circle_rounded,
        'edited' => Icons.edit_rounded,
        'deleted' => Icons.delete_rounded,
        'approved' => Icons.verified_rounded,
        'rejected' || 'cancelled' => Icons.cancel_rounded,
        'login' || 'logout' => Icons.login_rounded,
        'invoiced' => Icons.receipt_long_rounded,
        _ => Icons.circle_outlined,
      };

  Color _color(String a) => switch (a) {
        'created' => AppColors.green,
        'edited' || 'adjusted' => AppColors.amber,
        'deleted' || 'rejected' || 'cancelled' => AppColors.red,
        'approved' || 'invoiced' => AppColors.teal,
        _ => AppColors.blue,
      };

  @override
  Widget build(BuildContext context) {
    final tracking = context.watch<TrackingController>();
    final users = context.watch<UserController>();
    final logs = tracking.logs(userId: _user, day: _day);
    return ShellPage(
      title: 'Activity Log',
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Column(children: [
            DayBar(day: _day, onChanged: (d) => setState(() => _day = d)),
            const Gap(8),
            DropdownButtonFormField<String>(
              value: _user,
              isDense: true,
              decoration: const InputDecoration(labelText: 'User', isDense: true),
              items: [
                const DropdownMenuItem(value: '', child: Text('All users')),
                for (final u in users.users) DropdownMenuItem(value: u.id, child: Text(u.name)),
              ],
              onChanged: (v) => setState(() => _user = v ?? ''),
            ),
          ]),
        ),
        Expanded(
          child: logs.isEmpty
              ? const EmptyState(icon: Icons.history_rounded, text: 'No activity on this day')
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: logs.length,
                  itemBuilder: (_, i) {
                    final l = logs[i];
                    return IntrinsicHeight(
                      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        SizedBox(
                          width: 30,
                          child: Column(children: [
                            Icon(_icon(l.action), size: 20, color: _color(l.action)),
                            if (i < logs.length - 1)
                              Expanded(child: Container(width: 2, color: AppColors.muted.withValues(alpha: 0.2))),
                          ]),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text.rich(TextSpan(children: [
                                TextSpan(text: users.nameOf(l.userId), style: const TextStyle(fontWeight: FontWeight.w700)),
                                TextSpan(text: ' ${l.action} '),
                                TextSpan(text: l.entity, style: const TextStyle(fontWeight: FontWeight.w600)),
                              ])),
                              if (l.details.isNotEmpty)
                                Text(l.details, style: const TextStyle(fontSize: 12)),
                              Text(timeFmt(l.time), style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                            ]),
                          ),
                        ),
                      ]),
                    ).entrance(i);
                  },
                ),
        ),
      ]),
    );
  }
}
