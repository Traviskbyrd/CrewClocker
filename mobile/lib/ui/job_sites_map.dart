import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

/// A read-only view of the assignments already loaded for the signed-in user.
class JobSitesMap extends StatefulWidget {
  const JobSitesMap({super.key, required this.sites, this.initialSiteId});
  final List<Map<String, dynamic>> sites;
  final String? initialSiteId;

  @override
  State<JobSitesMap> createState() => _JobSitesMapState();
}

class _JobSitesMapState extends State<JobSitesMap> {
  final controller = MapController();
  int? selected;
  static const colors = [Colors.teal, Colors.deepOrange, Colors.indigo,
    Colors.purple, Colors.green, Colors.brown];
  LatLng point(Map<String, dynamic> s) => LatLng(
    (s['lat'] as num).toDouble(), (s['lng'] as num).toDouble());
  double radius(Map<String, dynamic> s) => (s['radius_meters'] as num).toDouble();

  LatLngBounds bounds(List<Map<String, dynamic>> sites) {
    const distance = Distance();
    return LatLngBounds.fromPoints([
      for (final s in sites)
        for (final bearing in [0.0, 90.0, 180.0, 270.0])
          distance.offset(point(s), radius(s), bearing),
    ]);
  }

  CameraFit fit(List<Map<String, dynamic>> sites) => CameraFit.bounds(
    bounds: bounds(sites), padding: const EdgeInsets.all(48), maxZoom: 18);

  @override
  void initState() {
    super.initState();
    final index = widget.sites.indexWhere((s) => s['id'] == widget.initialSiteId);
    if (index >= 0) selected = index;
  }

  @override
  void dispose() { controller.dispose(); super.dispose(); }

  void choose(int index) {
    setState(() => selected = index);
    controller.fitCamera(fit([widget.sites[index]]));
  }

  @override
  Widget build(BuildContext context) {
    final sites = widget.sites;
    if (sites.isEmpty) return Scaffold(
      appBar: AppBar(title: const Text('Job map')),
      body: const Center(child: Padding(padding: EdgeInsets.all(24),
        child: Text('No assigned sites yet. Add a site from Jobs to see it here.'))),
    );
    final active = selected == null ? null : sites[selected!];
    return Scaffold(
      appBar: AppBar(title: const Text('Job map'), actions: [
        IconButton(tooltip: 'Show all sites', icon: const Icon(Icons.zoom_out_map),
          onPressed: () { setState(() => selected = null); controller.fitCamera(fit(sites)); }),
      ]),
      body: SafeArea(child: Column(children: [
        const Padding(padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Text('Pins mark saved sites. Shaded circles show their tracking radius. Overlapping circles can trigger both sites.')),
        Expanded(child: FlutterMap(
          mapController: controller,
          options: MapOptions(
            initialCameraFit: fit(active == null ? sites : [active]),
            minZoom: 2, maxZoom: 19,
          ),
          children: [
            TileLayer(
              urlTemplate: const String.fromEnvironment('MAP_TILE_URL',
                defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'),
              userAgentPackageName: 'com.tbyrd.crewclocker.preview',
            ),
            CircleLayer(circles: [for (var i = 0; i < sites.length; i++)
              CircleMarker(point: point(sites[i]), radius: radius(sites[i]),
                useRadiusInMeter: true, color: colors[i % colors.length].withValues(alpha: 0.18),
                borderColor: colors[i % colors.length], borderStrokeWidth: selected == i ? 4 : 2),
            ]),
            MarkerLayer(markers: [for (var i = 0; i < sites.length; i++)
              Marker(point: point(sites[i]), width: 48, height: 48,
                child: Semantics(button: true, label: 'Show ${sites[i]['name']}',
                  child: Tooltip(message: sites[i]['name'].toString(),
                    child: InkWell(onTap: () => choose(i), child: Container(
                      decoration: BoxDecoration(color: colors[i % colors.length], shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3)),
                      alignment: Alignment.center,
                      child: Text('${i + 1}', style: const TextStyle(color: Colors.white,
                        fontWeight: FontWeight.bold, fontSize: 18)),
                    )))),
              ),
            ]),
            Align(alignment: Alignment.bottomRight, child: Material(color: Colors.white,
              child: InkWell(onTap: () => launchUrl(Uri.parse('https://www.openstreetmap.org/copyright')),
                child: const Padding(padding: EdgeInsets.all(8), child: Text('© OpenStreetMap contributors',
                  style: TextStyle(fontSize: 11, color: Colors.black))))),
            ),
          ],
        )),
        if (active != null) Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Text('${active['name']} • ${active['radius_meters']} m radius\n${active['address'] ?? ''}',
            textAlign: TextAlign.center)),
        SizedBox(height: 64, child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 12), scrollDirection: Axis.horizontal,
          itemCount: sites.length, separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (_, i) => Center(child: ChoiceChip(
            avatar: CircleAvatar(backgroundColor: colors[i % colors.length],
              child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontSize: 12))),
            label: Text(sites[i]['name'].toString()), selected: selected == i,
            onSelected: (_) => choose(i),
          )),
        )),
      ])),
    );
  }
}
