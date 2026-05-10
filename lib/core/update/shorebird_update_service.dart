import 'package:flutter/foundation.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

class ShorebirdUpdateService {
  const ShorebirdUpdateService();

  bool get isUpdaterAvailable {
    if (!kReleaseMode) return false;
    return ShorebirdUpdater().isAvailable;
  }

  Future<Patch?> getCurrentPatch() async {
    if (!isUpdaterAvailable) return null;

    return ShorebirdUpdater().readCurrentPatch();
  }

  Future<UpdateStatus> checkForUpdate() async {
    if (!isUpdaterAvailable) return UpdateStatus.unavailable;

    return ShorebirdUpdater().checkForUpdate();
  }

  Future<void> downloadUpdate() async {
    if (!isUpdaterAvailable) {
      throw const UpdateException(
        message: 'Shorebird updater is unavailable in this build.',
        reason: UpdateFailureReason.unknown,
      );
    }

    await ShorebirdUpdater().update();
  }
}
