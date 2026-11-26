import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../controllers/update_controller.dart';
import 'common.dart';

/// Checks the server and, if a new version exists, shows the update sheet.
/// [manual] = user tapped "Check for update" (shows "up to date" message).
Future<void> checkForUpdate(BuildContext context, {bool manual = false}) async {
  final uc = context.read<UpdateController>();
  final has = await uc.check(force: manual);
  if (!context.mounted) return;
  if (!has) {
    if (manual) showSnack(context, 'App is up to date');
    return;
  }
  await showModalBottomSheet(
    context: context,
    isDismissible: true,
    showDragHandle: true,
    builder: (_) => const _UpdateSheet(),
  );
}

class _UpdateSheet extends StatelessWidget {
  const _UpdateSheet();

  @override
  Widget build(BuildContext context) {
    final uc = context.watch<UpdateController>();
    final r = uc.available;
    if (r == null) return const SizedBox(height: 120);
    final mb = r.size > 0 ? '${(r.size / 1024 / 1024).toStringAsFixed(1)} MB' : '';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Center(
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(22)),
            child: const Icon(Icons.system_update_rounded, color: Colors.white, size: 36),
          ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
        ),
        const Gap(14),
        const Text('Naya update aaya hai', textAlign: TextAlign.center, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
        Text('Build ${r.build}${mb.isEmpty ? '' : ' · $mb'}  ·  current ${uc.currentLabel}',
            textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
        if (r.notes.isNotEmpty) ...[
          const Gap(10),
          Text(r.notes, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13)),
        ],
        const Gap(18),
        if (uc.downloading) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(value: uc.progress <= 0 ? null : uc.progress, minHeight: 10),
          ),
          const Gap(8),
          Text('Downloading… ${(uc.progress * 100).toStringAsFixed(0)}%',
              textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
        ] else ...[
          FilledButton.icon(
            icon: const Icon(Icons.download_rounded),
            label: const Text('Update karein'),
            onPressed: () async {
              final err = await context.read<UpdateController>().update();
              if (!context.mounted) return;
              if (err != null) {
                showSnack(context, err, error: true);
              } else {
                Navigator.pop(context);
              }
            },
          ),
          const Gap(6),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Baad mein')),
          const Text('Install screen aaye to "Update" dabayein. Data safe rehta hai.',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: AppColors.muted)),
        ],
      ]),
    );
  }
}
