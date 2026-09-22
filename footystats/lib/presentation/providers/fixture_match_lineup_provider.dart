import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/match_model.dart';
import '../../domain/models/squad_layout.dart';

class FixtureMatchLineupRequest {
  const FixtureMatchLineupRequest({
    required this.matchId,
    required this.isTeamA,
  });

  final String matchId;
  final bool isTeamA;

  @override
  bool operator ==(Object other) {
    return other is FixtureMatchLineupRequest &&
        other.matchId == matchId &&
        other.isTeamA == isTeamA;
  }

  @override
  int get hashCode => Object.hash(matchId, isTeamA);
}

class FixtureMatchLineupData {
  const FixtureMatchLineupData({
    required this.layout,
    required this.members,
    this.captainId,
  });

  final SquadLayoutData layout;
  final List<SquadMemberDisplay> members;
  final String? captainId;
}

final fixtureMatchLineupProvider = FutureProvider.autoDispose
    .family<FixtureMatchLineupData, FixtureMatchLineupRequest>((
      ref,
      request,
    ) async {
      final client = Supabase.instance.client;
      final matchRes = await client
          .from('matches')
          .select(
            'id, status, teamA, teamB, team_a_lineup, team_b_lineup',
          )
          .eq('id', request.matchId)
          .maybeSingle();

      if (matchRes == null) {
        return const FixtureMatchLineupData(
          layout: SquadLayoutData(players: {}),
          members: [],
        );
      }

      final matchMap = Map<String, dynamic>.from(matchRes);
      final status = MatchStatusX.fromString(matchMap['status']?.toString());
      final teamId = request.isTeamA
          ? matchMap['teamA']?.toString()
          : matchMap['teamB']?.toString();

      if (teamId == null || teamId.isEmpty) {
        return const FixtureMatchLineupData(
          layout: SquadLayoutData(players: {}),
          members: [],
        );
      }

      Map<String, dynamic>? layoutJson;
      final storedLayout = request.isTeamA
          ? matchMap['team_a_lineup']
          : matchMap['team_b_lineup'];
      if (storedLayout is Map) {
        layoutJson = Map<String, dynamic>.from(storedLayout);
      }

      if ((layoutJson == null || layoutJson.isEmpty) &&
          status == MatchStatus.upcoming) {
        final teamRes = await client
            .from('teams')
            .select('squad_layout')
            .eq('id', teamId)
            .maybeSingle();
        final liveLayout = teamRes?['squad_layout'];
        if (liveLayout is Map) {
          layoutJson = Map<String, dynamic>.from(liveLayout);
        }
      }

      final layout = SquadLayoutData.fromJson(layoutJson);

      String? captainId;
      try {
        final capRes = await client
            .from('teams')
            .select('captain_id')
            .eq('id', teamId)
            .maybeSingle();
        captainId = capRes?['captain_id']?.toString();
      } catch (_) {}

      final members = await _loadMembers(
        client: client,
        teamId: teamId,
        layout: layout,
        matchStarted: status != MatchStatus.upcoming,
      );

      return FixtureMatchLineupData(
        layout: layout,
        members: members,
        captainId: captainId,
      );
    });

Future<List<SquadMemberDisplay>> _loadMembers({
  required SupabaseClient client,
  required String teamId,
  required SquadLayoutData layout,
  required bool matchStarted,
}) async {
  if (matchStarted) {
    final playerIds = layout.players.keys
        .where((id) => id.isNotEmpty && id != 'fallback')
        .toList();
    if (playerIds.isEmpty) return const [];

    final res = await client
        .from('players')
        .select('id, player_name, image_url')
        .inFilter('id', playerIds);
    final rows = List<Map<String, dynamic>>.from(res as List);
    final byId = {
      for (final row in rows)
        row['id']?.toString() ?? '': row,
    };

    return playerIds.map((id) {
      final row = byId[id];
      return SquadMemberDisplay(
        playerId: id,
        name: row?['player_name']?.toString().trim().isNotEmpty == true
            ? row!['player_name'].toString()
            : 'Player',
        imageUrl: row?['image_url']?.toString(),
      );
    }).toList();
  }

  final res = await client
      .from('player_team_memberships')
      .select(
        'player_id, players!player_team_memberships_player_id_fkey(player_name, image_url)',
      )
      .eq('team_id', teamId)
      .isFilter('end_date', null);

  final rows = List<Map<String, dynamic>>.from(res as List);
  return rows.map((row) {
    final playerId = row['player_id']?.toString() ?? '';
    final player = row['players'];
    final playerMap = player is Map ? Map<String, dynamic>.from(player) : null;
    return SquadMemberDisplay(
      playerId: playerId,
      name: playerMap?['player_name']?.toString().trim().isNotEmpty == true
          ? playerMap!['player_name'].toString()
          : 'Player',
      imageUrl: playerMap?['image_url']?.toString(),
    );
  }).where((m) => m.playerId.isNotEmpty).toList();
}
