import 'share_boot_overlay_stub.dart'
    if (dart.library.html) 'share_boot_overlay_web.dart' as impl;

void removeShareBootOverlay() => impl.removeShareBootOverlay();

bool shareBootHasVideo() => impl.shareBootHasVideo();

double shareBootPlaybackSeconds() => impl.shareBootPlaybackSeconds();
