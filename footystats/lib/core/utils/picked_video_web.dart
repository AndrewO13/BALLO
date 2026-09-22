import 'package:video_player/video_player.dart';

Future<int?> readVideoDurationSeconds(String videoPath) async {
  VideoPlayerController? controller;
  try {
    controller = VideoPlayerController.networkUrl(Uri.parse(videoPath));
    await controller.initialize();
    return controller.value.duration.inSeconds;
  } catch (_) {
    return null;
  } finally {
    await controller?.dispose();
  }
}
