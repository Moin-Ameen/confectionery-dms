import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/tracking_controller.dart';
import '../../controllers/user_controller.dart';
import '../../models/tracking.dart';
import '../../models/user.dart';
import '../shell/shell_page.dart';
import '../widgets/common.dart';
import 'live_map_view.dart';

class RouteHistoryView extends StatefulWidget {
  final String? userId;
  const RouteHistoryView({super.key, this.userId});

  @override
  State<RouteHistoryView> createState() => _RouteHistoryViewState();
}

class _RouteHistoryViewState extends State<RouteHistoryView> {
  String _user = '';
  DateTime _day = DateTime.now();
  final _map = MapController();

  @override
  void initState() {
    super.initState();
    _user = widget.userId ?? '';
  }

  Color _kindColor(String k) => switch (k) {
        PingKind.orderCheckIn => AppColors.navy,
        PingKind.recoveryCheckIn => AppColors.green,
        PingKind.visit => AppColors.purple,
        _ => AppColors.blue,
      };

  IconData _kindIcon(String k) => switch (k) {
        PingKind.orderCheckIn => Icons.add_shopping_cart_rounded,
        PingKind.recoveryCheckIn => Icons.payments_rounded,
        PingKind.visit => Icons.local_shipping_rounded,
        _ => Icons.circle,
      };

  @override
  Widget build(BuildContext context) {
    final tracking = context.watch<TrackingController>();
    final users = context.watch<UserController>();
    final me = context.watch<AuthController>().user!;
    final staff = me.role.isField ? [me] : users.fieldUsers;
    if (_user.isEmpty && staff.isNotEmpty) _user = staff.first.id;
    final path = _user.isEmpty ? <LocationPing>[] : tracking.history(_user, _day);
    final checkIns = path.where((p) => p.kind != PingKind.track).toList();
    final points = path.map((p) => LatLng(p.lat, p.lng)).toList();
    final km = tracking.distanceKm(path);

    return ShellPage(
      title: 'Route History',
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Column(children: [
            if (staff.length > 1)
              DropdownButtonFormField<String>(
                value: _user.isEmpty ? null : _user,
                decoration: const InputDecoration(labelText: 'Booker / salesman', isDense: true),
                items: [for (final u in staff) DropdownMenuItem(value: u.id, child: Text('${u.name} · ${u.role.label}'))],
                onChanged: (v) => setState(() => _user = v ?? ''),
              ),
            const Gap(8),
            DayBar(day: _day, onChanged: (d) => setState(() => _day = d)),
          ]),
        ),
        Expanded(
          flex: 3,
          child: FlutterMap(
            key: ValueKey('$_user${_day.day}'),
            mapController: _map,
            options: MapOptions(
              initialCenter: points.isEmpty ? defaultCenter : points.first,
              initialZoom: points.isEmpty ? 11 : 14,
            ),
            children: [
              osmTiles(),
              if (points.length > 1)
                PolylineLayer(polylines: [
                  Polyline(points: points, strokeWidth: 4.5, color: AppColors.blue),
                ]),
              MarkerLayer(markers: [
                if (points.isNotEmpty)
                  Marker(
                    point: points.first,
                    width: 26,
                    height: 26,
                    child: const Icon(Icons.flag_rounded, color: AppColors.green, size: 24),
                  ),
                if (points.length > 1)
                  Marker(
                    point: points.last,
                    width: 30,
                    height: 30,
                    child: const Icon(Icons.person_pin_circle_rounded, color: AppColors.red, size: 30),
                  ),
                for (final c in checkIns)
                  Marker(
                    point: LatLng(c.lat, c.lng),
                    width: 28,
                    height: 28,
                    child: Container(
                      decoration: BoxDecoration(color: _kindColor(c.kind), shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2)),
                      child: Icon(_kindIcon(c.kind), color: Colors.white, size: 14),
                    ),
                  ),
              ]),
            ],
          ),
        ),
        Expanded(
          flex: 2,
          child: ListView(padding: const EdgeInsets.all(16), children: [
            Row(children: [
              Expanded(child: StatCard(title: 'Distance', value: '${km.toStringAsFixed(1)} km', icon: Icons.route_rounded, color: AppColors.blue)),
              const Gap(),
              Expanded(child: StatCard(title: 'Shop visits', value: '${checkIns.length}', icon: Icons.storefront_rounded, color: AppColors.purple)),
            ]),
            if (path.isNotEmpty) ...[
              const Gap(8),
              Text('Duty ${timeFmt(path.first.time)} – ${timeFmt(path.last.time)} · ${path.length} GPS points',
                  textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
            ],
            const SectionTitle('Check-ins (order / recovery / delivery)'),
            if (checkIns.isEmpty) const Text('No check-ins on this day', style: TextStyle(color: AppColors.muted)),
            for (final c in checkIns)
              ListTile(
                contentPadding: EdgeInsets.zero,
                onTap: () => _map.move(LatLng(c.lat, c.lng), 16),
                leading: CircleAvatar(backgroundColor: _kindColor(c.kind), child: Icon(_kindIcon(c.kind), color: Colors.white, size: 18)),
                title: Text(c.label.isEmpty ? c.kind : c.label, style: const TextStyle(fontSize: 13)),
                subtitle: Text(timeFmt(c.time)),
              ),
            Center(child: Text('Map © OpenStreetMap · ${AppConfig.poweredBy}', style: const TextStyle(fontSize: 10, color: AppColors.muted))),
          ]),
        ),
      ]),
    );
  }
}
