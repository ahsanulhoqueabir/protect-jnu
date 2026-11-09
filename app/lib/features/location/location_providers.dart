import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_providers.dart';
import '../sos/sos_providers.dart';
import 'data/geolocator_position_source.dart';
import 'data/location_queue.dart';
import 'data/location_uploader.dart';
import 'domain/location_sharing.dart';

final locationQueueProvider = Provider<LocationQueue>(
  (_) => SqfliteLocationQueue(SqfliteLocationQueue.openDefault),
);

final locationUploaderProvider = Provider<LocationUploader>(
  (_) => SupabaseLocationUploader(() => Supabase.instance.client),
);

final positionSourceProvider = Provider<PositionSource>((_) => const GeolocatorPositionSource());

final locationSharingProvider = Provider<LocationSharing>((ref) {
  final sharing = LocationSharing(
    source: ref.watch(positionSourceProvider),
    queue: ref.watch(locationQueueProvider),
    uploader: ref.watch(locationUploaderProvider),
  );
  ref.onDispose(sharing.stop);
  return sharing;
});

/// Shares the live location exactly while the student's alert is open (active or acknowledged).
/// Any other state (cancelled, resolved, no alert, signed out) stops the foreground service.
/// Watched once from the app shell.
final liveLocationControllerProvider = Provider<void>((ref) {
  final sharing = ref.watch(locationSharingProvider);
  final alert = ref.watch(openAlertProvider).value;
  final userId = ref.watch(currentUserIdProvider);
  if (alert != null && alert.status.isOpen && userId != null) {
    sharing.start(alertId: alert.id, userId: userId);
  } else {
    sharing.stop();
  }
});
