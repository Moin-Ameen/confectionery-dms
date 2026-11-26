import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../../config/app_config.dart';

// ---------------- Formatting ----------------
final _nf = NumberFormat('#,##0');
final _nf2 = NumberFormat('#,##0.##');

String money(num v) => '${AppConfig.currency} ${_nf.format(v)}';
String num0(num v) => _nf.format(v);
String num2(num v) => _nf2.format(v);
String dateFmt(DateTime d) => DateFormat('dd MMM yyyy').format(d);
String dateTimeFmt(DateTime d) => DateFormat('dd MMM, hh:mm a').format(d);
String timeFmt(DateTime d) => DateFormat('hh:mm a').format(d);

// ---------------- Animations ----------------
extension EntranceX on Widget {
  /// Smooth staggered entrance for list items / cards.
  Widget entrance(int index) => this
      .animate()
      .fadeIn(duration: 320.ms, delay: (35 * (index > 12 ? 12 : index)).ms)
      .slideY(begin: 0.08, end: 0, duration: 320.ms, curve: Curves.easeOutCubic);
}

// ---------------- Feedback ----------------
void showSnack(BuildContext context, String msg, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? AppColors.red : AppColors.navy,
    ));
}

/// Shows result of a controller call (null = success).
bool handleResult(BuildContext context, String? err, {String? success}) {
  if (err != null) {
    showSnack(context, err, error: true);
    return false;
  }
  if (success != null) showSnack(context, success);
  return true;
}

Future<bool> confirmDialog(BuildContext context, String title, String message,
    {String ok = 'Yes', Color? color}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
        FilledButton(
          style: color == null ? null : FilledButton.styleFrom(backgroundColor: color),
          onPressed: () => Navigator.pop(c, true),
          child: Text(ok),
        ),
      ],
    ),
  );
  return r ?? false;
}

Future<String?> promptText(BuildContext context, String title,
    {String hint = '', String initial = '', bool number = false, bool required = false}) async {
  final ctrl = TextEditingController(text: initial);
  final r = await showDialog<String>(
    context: context,
    builder: (c) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(title),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        keyboardType: number ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
        decoration: InputDecoration(hintText: hint),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (required && ctrl.text.trim().isEmpty) return;
            Navigator.pop(c, ctrl.text.trim());
          },
          child: const Text('OK'),
        ),
      ],
    ),
  );
  return r;
}

// ---------------- Building blocks ----------------
class AppCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Gradient? gradient;

  const AppCard({super.key, required this.child, this.onTap, this.padding = const EdgeInsets.all(14), this.color, this.gradient});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: gradient == null ? (color ?? Theme.of(context).cardTheme.color) : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(18),
        boxShadow: dark
            ? null
            : [BoxShadow(color: AppColors.navy.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final String? badge;

  const StatCard({super.key, required this.title, required this.value, required this.icon, required this.color, this.onTap, this.badge});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.red, borderRadius: BorderRadius.circular(10)),
                  child: Text(badge!, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 2),
          Text(title, style: const TextStyle(fontSize: 12, color: AppColors.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionTitle(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 18, 4, 10),
        child: Row(children: [
          Expanded(child: Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
          if (trailing != null) trailing!,
        ]),
      );
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String text;
  final String? sub;
  const EmptyState({super.key, this.icon = Icons.inbox_outlined, required this.text, this.sub});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(color: AppColors.blue.withValues(alpha: 0.12), shape: BoxShape.circle),
              child: Icon(icon, size: 42, color: AppColors.blue),
            ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
            const SizedBox(height: 16),
            Text(text, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600)),
            if (sub != null) ...[
              const SizedBox(height: 6),
              Text(sub!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
            ],
          ]),
        ),
      );
}

Color statusColor(String s) {
  switch (s.toLowerCase()) {
    case 'pending':
    case 'submitted':
    case 'partial':
      return AppColors.amber;
    case 'approved':
    case 'loaded':
    case 'open':
      return AppColors.teal;
    case 'delivered':
    case 'paid':
    case 'closed':
      return AppColors.green;
    case 'rejected':
    case 'cancelled':
    case 'nil':
    case 'short':
      return AppColors.red;
    default:
      return AppColors.muted;
  }
}

class StatusChip extends StatelessWidget {
  final String status;
  final Color? color;
  const StatusChip(this.status, {super.key, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(20)),
      child: Text(
        status.isEmpty ? '-' : status[0].toUpperCase() + status.substring(1),
        style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class SearchField extends StatelessWidget {
  final ValueChanged<String> onChanged;
  final String hint;
  const SearchField({super.key, required this.onChanged, this.hint = 'Search...'});

  @override
  Widget build(BuildContext context) => TextField(
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: const Icon(Icons.search_rounded),
          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
        ),
      );
}

class Avatar extends StatelessWidget {
  final String text;
  final Color color;
  final double size;
  const Avatar(this.text, {super.key, this.color = AppColors.navy, this.size = 42});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(gradient: AppColors.soft(color), borderRadius: BorderRadius.circular(size / 3)),
        child: Text(text, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: size * 0.36)),
      );
}

class KV extends StatelessWidget {
  final String k;
  final String v;
  final bool bold;
  final Color? color;
  const KV(this.k, this.v, {super.key, this.bold = false, this.color});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Expanded(child: Text(k, style: TextStyle(color: bold ? null : AppColors.muted, fontWeight: bold ? FontWeight.w700 : null))),
          Text(v, style: TextStyle(fontWeight: bold ? FontWeight.w700 : FontWeight.w600, color: color)),
        ]),
      );
}

class QtyStepper extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  final int step;
  const QtyStepper({super.key, required this.value, required this.onChanged, this.step = 1});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        _btn(Icons.remove_rounded, () => onChanged((value - step) < 0 ? 0 : value - step)),
        InkWell(
          onTap: () async {
            final v = await promptText(context, 'Enter quantity (pieces)', initial: '$value', number: true);
            if (v != null) onChanged(int.tryParse(v) ?? value);
          },
          child: SizedBox(
            width: 46,
            child: Text('$value', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
        _btn(Icons.add_rounded, () => onChanged(value + step)),
      ]),
    );
  }

  Widget _btn(IconData i, VoidCallback f) => InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          HapticFeedback.selectionClick();
          f();
        },
        child: Padding(padding: const EdgeInsets.all(8), child: Icon(i, size: 18, color: AppColors.navy)),
      );
}

/// Day selector used by daily screens.
class DayBar extends StatelessWidget {
  final DateTime day;
  final ValueChanged<DateTime> onChanged;
  const DayBar({super.key, required this.day, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(children: [
        IconButton(icon: const Icon(Icons.chevron_left_rounded), onPressed: () => onChanged(day.subtract(const Duration(days: 1)))),
        Expanded(
          child: InkWell(
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: day,
                firstDate: DateTime(2020),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (d != null) onChanged(d);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.calendar_month_rounded, size: 18, color: AppColors.blue),
                const SizedBox(width: 8),
                Text(dateFmt(day), style: const TextStyle(fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        ),
        IconButton(icon: const Icon(Icons.chevron_right_rounded), onPressed: () => onChanged(day.add(const Duration(days: 1)))),
      ]),
    );
  }
}

/// Month selector for monthly reports.
class MonthBar extends StatelessWidget {
  final DateTime month;
  final ValueChanged<DateTime> onChanged;
  const MonthBar({super.key, required this.month, required this.onChanged});

  @override
  Widget build(BuildContext context) => AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(children: [
          IconButton(
              icon: const Icon(Icons.chevron_left_rounded),
              onPressed: () => onChanged(DateTime(month.year, month.month - 1, 1))),
          Expanded(
            child: Text(DateFormat('MMMM yyyy').format(month),
                textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          IconButton(
              icon: const Icon(Icons.chevron_right_rounded),
              onPressed: () => onChanged(DateTime(month.year, month.month + 1, 1))),
        ]),
      );
}

/// Bottom sheet list picker with search.
Future<T?> pickFromList<T>(
  BuildContext context, {
  required String title,
  required List<T> items,
  required String Function(T) label,
  String Function(T)? subtitle,
  Widget Function(T)? leading,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (c) {
      var q = '';
      return StatefulBuilder(builder: (c, set) {
        final filtered = items
            .where((i) => q.isEmpty ||
                label(i).toLowerCase().contains(q) ||
                (subtitle?.call(i).toLowerCase().contains(q) ?? false))
            .toList();
        return SizedBox(
          height: MediaQuery.of(c).size.height * 0.75,
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                SearchField(onChanged: (v) => set(() => q = v.toLowerCase())),
              ]),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? const EmptyState(text: 'Nothing found')
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (c, i) {
                        final it = filtered[i];
                        return ListTile(
                          leading: leading?.call(it),
                          title: Text(label(it), style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: subtitle == null ? null : Text(subtitle(it)),
                          onTap: () => Navigator.pop(c, it),
                        );
                      },
                    ),
            ),
          ]),
        );
      });
    },
  );
}

/// Share / print menu used on invoices & reports.
class PrintMenu extends StatelessWidget {
  final VoidCallback onShare;
  final VoidCallback onPrint;
  final VoidCallback? onBluetooth;
  const PrintMenu({super.key, required this.onShare, required this.onPrint, this.onBluetooth});

  @override
  Widget build(BuildContext context) => PopupMenuButton<int>(
        icon: const Icon(Icons.ios_share_rounded),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        onSelected: (v) {
          if (v == 0) onShare();
          if (v == 1) onPrint();
          if (v == 2) onBluetooth?.call();
        },
        itemBuilder: (_) => [
          const PopupMenuItem(value: 0, child: ListTile(leading: Icon(Icons.share_rounded), title: Text('Share PDF / WhatsApp'))),
          const PopupMenuItem(value: 1, child: ListTile(leading: Icon(Icons.print_rounded), title: Text('Print (A4)'))),
          if (onBluetooth != null)
            const PopupMenuItem(value: 2, child: ListTile(leading: Icon(Icons.bluetooth_rounded), title: Text('Bluetooth printer'))),
        ],
      );
}

/// Labeled numeric text field helper.
class NumField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool decimal;
  final ValueChanged<String>? onChanged;
  const NumField(this.controller, this.label, {super.key, this.decimal = true, this.onChanged});

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        onChanged: onChanged,
        keyboardType: TextInputType.numberWithOptions(decimal: decimal),
        decoration: InputDecoration(labelText: label),
      );
}

class Gap extends StatelessWidget {
  final double h;
  const Gap([this.h = 12, Key? key]) : super(key: key);
  @override
  Widget build(BuildContext context) => SizedBox(height: h, width: h);
}
