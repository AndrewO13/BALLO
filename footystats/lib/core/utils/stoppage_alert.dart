import 'stoppage_alert_stub.dart'
    if (dart.library.io) 'stoppage_alert_mobile.dart' as impl;

/// Plays a beep and haptics when the pill turns red (stoppage time).
void playStoppageAlert() {
  impl.playStoppageAlert();
}
