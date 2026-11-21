import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/utils/extensions.dart';
import '../../domain/admin_alert.dart';
import 'admin_widgets.dart';

/// Whether to load OpenStreetMap tiles. Widget tests override it with `false` (no network).
final mapTilesEnabledProvider = Provider<bool>((_) => true);

/// OSM tile server (PRD 7.3). The public service has no SLA, so failures show a banner and the
/// coordinates stay readable below the map.
const _osmTiles = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

/// Live location of one alert: newest point as a marker, the short trail, "updated Xs ago", OSM
/// attribution (D-079; same content as the dashboard's Leaflet map).
class AlertLiveMap extends ConsumerStatefulWidget {
  const AlertLiveMap({super.key, required this.points, this.fallback});

  /// Oldest first.
  final List<TrailPoint> points;

  /// First coordinates stored on the alert, used when no trail point exists yet.
  final LatLng? fallback;

  @override
  ConsumerState<AlertLiveMap> createState() => _AlertLiveMapState();
}

class _AlertLiveMapState extends ConsumerState<AlertLiveMap> {
  final _map = MapController();
  Timer? _ticker;
  var _tilesFailed = false;
  var _mapReady = false;

  @override
  void initState() {
    super.initState();
    // Refresh the "updated Xs ago" label.
    _ticker = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(AlertLiveMap old) {
    super.didUpdateWidget(old);
    final latest = _latest;
    final before = old.points.isEmpty ? null : old.points.last;
    if (_mapReady && latest != null && before?.id != widget.points.lastOrNull?.id) {
      _map.move(latest, _map.camera.zoom);
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _map.dispose();
    super.dispose();
  }

  LatLng? get _latest {
    final last = widget.points.lastOrNull;
    return last == null ? widget.fallback : LatLng(last.latitude, last.longitude);
  }

  @override
  Widget build(BuildContext context) {
    final latest = _latest;
    if (latest == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Text('No location received yet (the student may have denied location access).'),
      );
    }
    final colors = context.colors;
    final tiles = ref.watch(mapTilesEnabledProvider);
    final last = widget.points.lastOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_tilesFailed)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Text(
              'Map tiles unavailable. The coordinates below are still live.',
              style: context.textTheme.bodySmall?.copyWith(color: colors.error),
            ),
          ),
        ClipRRect(
          borderRadius: AppRadius.mdAll,
          child: SizedBox(
            height: 280,
            child: FlutterMap(
              mapController: _map,
              options: MapOptions(
                initialCenter: latest,
                initialZoom: 16,
                onMapReady: () => _mapReady = true,
              ),
              children: [
                if (tiles)
                  TileLayer(
                    urlTemplate: _osmTiles,
                    userAgentPackageName: 'com.protectjnu.app',
                    errorTileCallback: (_, _, _) {
                      if (!_tilesFailed && mounted) setState(() => _tilesFailed = true);
                    },
                  )
                else
                  ColoredBox(color: colors.surfaceContainerHighest),
                if (widget.points.length > 1)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: [for (final p in widget.points) LatLng(p.latitude, p.longitude)],
                        strokeWidth: 4,
                        color: colors.primary.withValues(alpha: 0.7),
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: latest,
                      width: 28,
                      height: 28,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: colors.error,
                          shape: BoxShape.circle,
                          border: Border.all(color: colors.onError, width: 3),
                        ),
                      ),
                    ),
                  ],
                ),
                // Required OSM attribution (PRD 7.3). Wraps instead of overflowing on narrow maps.
                Align(
                  alignment: Alignment.bottomRight,
                  child: Container(
                    margin: const EdgeInsets.all(AppSpacing.xxs),
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
                    color: colors.surface.withValues(alpha: 0.85),
                    child: Text(
                      '© OpenStreetMap contributors',
                      textAlign: TextAlign.right,
                      style: context.textTheme.labelSmall,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const Gap(AppSpacing.xs),
        Text(
          '${latest.latitude.toStringAsFixed(6)}, ${latest.longitude.toStringAsFixed(6)}'
          '${last == null ? ' (first position)' : ' · updated ${timeAgo(last.recordedAt)}'}',
          style: context.textTheme.bodySmall,
        ),
      ],
    );
  }
}
