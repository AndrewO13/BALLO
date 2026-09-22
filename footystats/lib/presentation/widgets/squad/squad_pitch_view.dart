import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../domain/models/lineup_player_match_stats.dart';
import '../../../domain/models/squad_layout.dart';
import 'team_player.dart';

/// Read-only squad pitch (matches the team detail Squad tab visuals).
class SquadPitchView extends StatelessWidget {
  const SquadPitchView({
    super.key,
    required this.layout,
    required this.members,
    this.captainId,
    this.onPlayerTap,
    this.playerStatsById = const {},
  });

  final SquadLayoutData layout;
  final List<SquadMemberDisplay> members;
  final String? captainId;
  final void Function(String playerId)? onPlayerTap;
  final Map<String, LineupPlayerMatchStats> playerStatsById;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final pitchWidth = constraints.maxWidth;
          final pitchHeight = pitchWidth * (274 / 380);
          final benchHeight = pitchWidth * (94 / 380);
          final bgHeight = pitchWidth;
          final pitchTop = bgHeight - pitchHeight;

          final scaleX = pitchWidth / SquadLayoutData.defaultCanvasWidth;
          final scaleY =
              (bgHeight + benchHeight) / SquadLayoutData.defaultCanvasTotalHeight;

          return Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: pitchWidth,
              height: bgHeight + benchHeight,
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    top: 0,
                    width: pitchWidth,
                    child: Image.asset(
                      'lib/assets/images/pitch bg.png',
                      fit: BoxFit.contain,
                      alignment: Alignment.bottomCenter,
                      color: const Color(0xFF107F6B),
                      colorBlendMode: BlendMode.color,
                    ),
                  ),
                  Positioned(
                    left: 0,
                    top: pitchTop,
                    width: pitchWidth,
                    height: pitchHeight,
                    child: SvgPicture.asset(
                      'lib/assets/icons/squad/pitch.svg',
                      fit: BoxFit.contain,
                    ),
                  ),
                  Positioned(
                    left: 0,
                    top: bgHeight,
                    width: pitchWidth,
                    height: benchHeight,
                    child: SvgPicture.asset(
                      'lib/assets/icons/squad/bench.svg',
                      fit: BoxFit.contain,
                    ),
                  ),
                  for (final member in members)
                    Builder(
                      builder: (context) {
                        if (member.playerId.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        final offset = layout.resolveOffset(member.playerId);
                        return Positioned(
                          left: offset.dx * scaleX,
                          top: offset.dy * scaleY,
                          child: GestureDetector(
                            onTap: onPlayerTap == null
                                ? null
                                : () => onPlayerTap!(member.playerId),
                            child: TeamPlayer(
                              name: member.name,
                              imageAsset: member.imageUrl ?? '',
                              showCaptainBadge: captainId == member.playerId,
                              matchStats: playerStatsById[member.playerId],
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
