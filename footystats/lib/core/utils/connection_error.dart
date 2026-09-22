import 'dart:async';

import 'connection_error_io.dart'
    if (dart.library.html) 'connection_error_web.dart' as platform;

/// Whether [error] likely indicates a network or connectivity problem.
bool isConnectionError(Object? error) {
  if (error == null) return false;
  if (error is TimeoutException) return true;
  if (platform.isSocketConnectionError(error)) return true;
  final msg = error.toString().toLowerCase();
  return msg.contains('socket') ||
      msg.contains('network') ||
      msg.contains('connection') ||
      msg.contains('internet') ||
      msg.contains('failed host lookup') ||
      msg.contains('timed out') ||
      msg.contains('network is unreachable');
}
