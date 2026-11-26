import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../controllers/shop_controller.dart';
import '../../controllers/sync_controller.dart';
import '../../controllers/tracking_controller.dart';
import '../../controllers/user_controller.dart';
import '../../models/tracking.dart';
import '../../models/user.dart';
import '../shell/shell_page.dart';
import '../widgets/common.dart';
import 'route_history_view.dart';

final defaultCenter = LatLng(24.8607, 67.0011); // Karachi

TileLayer osmTiles() => TileLayer(
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      userAgentPackageName: 'com.cashlifypos.confectionery_distribution',
    );

String agoText(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes} min ago';
  if (d.inHours < 24) return '${d.inHours} h ago';
  return dateTimeFmt(t);
}

class LiveMapView extends StatefulWidget {
  const LiveMapView({super.key});

  @override
  State<LiveMapView> createState() => _LiveMapViewState();
}

class _LiveMapViewState extends State<LiveMapView> {
  final _map = MapController();
  bool _showShops = false;

  @override
  Widget build(BuildContext context) {
    final tracking = context.watch<TrackingController>();
    final users = context.watch<UserController>();
    final shops = context.watch<ShopController>();
    final sync = context.watch<SyncController>();
    final latest = tracking.latestByUser();
    final staff = users.fieldUsers.where((u) => latest.containsKey(u.id)).toList()
      ..sort((a, b) => latest[b.id]!.time.compareTo(latest[a.id]!.time));
    final center = staff.isEmpty ? defaultCenter : LatLng(latest[staff.first.id]!.lat, latest[staff.first.id]!.lng);

    return ShellPage(
      title: 'Live Location',
      actions: [
        IconButton(
          tooltip: 'Show shops',
          icon: Icon(_showShops ? Icons.store_rounded : Icons.store_outlined),
          onPressed: () => setState(() => _showShops = !_showShops),
        ),
        IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: () => sync.syncNow()),
      ],
      body: Column(children: [
        Expanded(
          flex: 3,
          child: FlutterMap(
            mapController: _map,
            options: MapOptions(initialCenter: center, initialZoom: 12),
            children: [
              osmTiles(),
              if (_showShops)
                MarkerLayer(markers: [
                  for (final s in shops.activeShops.where((s) => s.lat != null))
                    Marker(
                      point: LatLng(s.lat!, s.lng!),
                      width: 26,
                      height: 26,
                      child: const Icon(Icons.store_rounded, color: AppColors.purple, size: 22),
                    ),
                ]),
              MarkerLayer(markers: [
                for (final u in staff)
                  Marker(
                    point: LatLng(latest[u.id]!.lat, latest[u.id]!.lng),
                    width: 130,
                    height: 62,
                    alignment: Alignment.topCenter,
                    child: _Pin(user: u, ping: latest[u.id]!),
                  ),
              ]),
            ],
          ),
        ),
        Expanded(
          flex: 2,
          child: staff.isEmpty
              ? const EmptyState(
                  icon: Icons.location_off_outlined,
                  text: 'No live locations yet',
                  sub: 'Bookers & salesmen must turn "On duty" ON (drawer). With a server, all phones show here.')
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: staff.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final u = staff[i];
                    final p = latest[u.id]!;
                    final fresh = DateTime.now().difference(p.time).inMinutes < 15;
                    return AppCard(
                      onTap: () => _map.move(LatLng(p.lat, p.lng), 15),
                      child: Row(children: [
                        Stack(children: [
                          Avatar(u.initials, color: u.role == UserRole.booker ? AppColors.navy : AppColors.teal, size: 40),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: fresh ? AppColors.green : AppColors.muted,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                            ),
                          ),
                        ]),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(u.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                            Text('${u.role.label} · ${agoText(p.time)}${p.label.isEmpty ? '' : ' · ${p.label}'}',
                                style: const TextStyle(fontSize: 12, color: AppColors.muted),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ]),
                        ),
                        IconButton(
                          icon: const Icon(Icons.timeline_rounded),
                          onPressed: () => Navigator.push(
                              context, MaterialPageRoute(builder: (_) => RouteHistoryView(userId: u.id))),
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

class _Pin extends StatelessWidget {
  final AppUser user;
  final LocationPing ping;
  const _Pin({required this.user, required this.ping});

  @override
  Widget build(BuildContext context) {
    final c = user.role == UserRole.booker ? AppColors.navy : AppColors.teal;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: c,
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
        ),
        child: Text(user.name.split(' ').first,
            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
      ),
      Icon(Icons.location_on_rounded, color: c, size: 32),
    ]);
  }
}
