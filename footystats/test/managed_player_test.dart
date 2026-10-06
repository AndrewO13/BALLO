import 'package:ballo/domain/models/managed_player.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ManagedPlayer.fromJson maps claim state', () {
    final player = ManagedPlayer.fromJson({
      'id': '11111111-1111-1111-1111-111111111111',
      'player_name': 'Sam Cole',
      'username': 'samcole',
      'position': 'Midfielder',
      'login_enabled_at': '2026-10-03T10:00:00Z',
    });

    expect(player.playerName, 'Sam Cole');
    expect(player.username, 'samcole');
    expect(player.position, 'Midfielder');
    expect(player.hasLogin, isTrue);
  });

  test('ManagedPlayerDraftInput includes required position and photo', () {
    const input = ManagedPlayerDraftInput(
      playerName: 'Sam Cole',
      username: 'samcole',
      position: 'Midfielder',
      imageUrl: 'lib/assets/images/avatars/3d_avatar_13.png',
    );
    expect(input.toJson(), {
      'player_name': 'Sam Cole',
      'username': 'samcole',
      'position': 'Midfielder',
      'image_url': 'lib/assets/images/avatars/3d_avatar_13.png',
    });
  });
}
