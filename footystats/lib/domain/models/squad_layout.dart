import 'dart:ui';

/// Parsed squad pitch layout stored in [teams.squad_layout] or match lineups.
class SquadLayoutData {
  const SquadLayoutData({
    required this.players,
    this.canvasWidth = 380,
    this.canvasHeight = 474,
  });

  static const double defaultCanvasWidth = 380;
  static const double defaultCanvasBgHeight = 380;
  static const double defaultCanvasPitchHeight = 274;
  static const double defaultCanvasBenchHeight = 94;
  static const double defaultCanvasTotalHeight =
      defaultCanvasBgHeight + defaultCanvasBenchHeight;
  static const double playerSize = 60;

  final Map<String, SquadPlayerLayout> players;
  final double canvasWidth;
  final double canvasHeight;

  factory SquadLayoutData.fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) {
      return const SquadLayoutData(players: {});
    }

    final layout = json['layout'];
    final canvasWidth = layout is Map
        ? (layout['width'] as num?)?.toDouble() ?? defaultCanvasWidth
        : defaultCanvasWidth;
    final canvasHeight = layout is Map
        ? (layout['height'] as num?)?.toDouble() ?? defaultCanvasTotalHeight
        : defaultCanvasTotalHeight;

    final rawPlayers = json['players'];
    if (rawPlayers is! Map) {
      return SquadLayoutData(
        players: const {},
        canvasWidth: canvasWidth,
        canvasHeight: canvasHeight,
      );
    }

    final players = <String, SquadPlayerLayout>{};
    rawPlayers.forEach((key, value) {
      if (key is! String || value is! Map) return;
      final map = Map<String, dynamic>.from(value);
      final absX = (map['abs_x'] as num?)?.toDouble();
      final absY = (map['abs_y'] as num?)?.toDouble();
      final x = (map['x'] as num?)?.toDouble();
      final y = (map['y'] as num?)?.toDouble();
      players[key] = SquadPlayerLayout(
        normalized: x != null && y != null
            ? Offset(x.clamp(0.0, 1.0), y.clamp(0.0, 1.0))
            : null,
        absolute: absX != null && absY != null ? Offset(absX, absY) : null,
        onBench: map['bench'] == true,
      );
    });

    return SquadLayoutData(
      players: players,
      canvasWidth: canvasWidth,
      canvasHeight: canvasHeight,
    );
  }

  Offset resolveOffset(String playerId) {
    final maxX = (canvasWidth - playerSize).clamp(1.0, double.infinity);
    final maxY = (canvasHeight - playerSize).clamp(1.0, double.infinity);
    final canvasPitchTop = defaultCanvasBgHeight - defaultCanvasPitchHeight;
    final fallback = Offset(
      (canvasWidth - playerSize) / 2,
      canvasPitchTop + (defaultCanvasPitchHeight - playerSize) / 2,
    );

    final layout = players[playerId];
    if (layout == null) return fallback;

    if (layout.absolute != null) {
      return Offset(
        layout.absolute!.dx.clamp(0.0, maxX),
        layout.absolute!.dy.clamp(0.0, maxY),
      );
    }
    if (layout.normalized != null) {
      return Offset(
        layout.normalized!.dx * maxX,
        layout.normalized!.dy * maxY,
      );
    }
    return fallback;
  }

  bool isOnBench(String playerId) => players[playerId]?.onBench ?? false;
}

class SquadPlayerLayout {
  const SquadPlayerLayout({
    this.normalized,
    this.absolute,
    this.onBench = false,
  });

  final Offset? normalized;
  final Offset? absolute;
  final bool onBench;
}

class SquadMemberDisplay {
  const SquadMemberDisplay({
    required this.playerId,
    required this.name,
    this.imageUrl,
  });

  final String playerId;
  final String name;
  final String? imageUrl;
}
