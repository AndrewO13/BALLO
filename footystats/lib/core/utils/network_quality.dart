import 'package:connectivity_plus/connectivity_plus.dart';

/// Lightweight network-class checks so media features can stay cheap on cellular.
class NetworkQuality {
  NetworkQuality._();

  static Future<List<ConnectivityResult>> _results() async {
    try {
      return await Connectivity().checkConnectivity();
    } catch (_) {
      return const [ConnectivityResult.other];
    }
  }

  static Future<bool> get isWifiOrEthernet async {
    final results = await _results();
    return results.contains(ConnectivityResult.wifi) ||
        results.contains(ConnectivityResult.ethernet);
  }

  static Future<bool> get isCellular async {
    final results = await _results();
    return results.contains(ConnectivityResult.mobile);
  }

  /// Explore / feed autoplay is Wi-Fi (or ethernet) only so cellular sessions
  /// do not start buffering highlight clips in the background.
  static Future<bool> get allowsVideoAutoplay => isWifiOrEthernet;
}
