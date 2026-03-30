import 'package:flutter/material.dart';

import 'profile.dart';

/// Same layout as the main Profile tab, with a standard back [AppBar].
class PlayerProfilePage extends StatelessWidget {
  const PlayerProfilePage({super.key, required this.playerId});

  final String playerId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: ProfileScrollView(viewedPlayerId: playerId),
    );
  }
}
