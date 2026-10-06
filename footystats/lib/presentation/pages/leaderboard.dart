import 'package:flutter/material.dart';

class LeaderboardPage extends StatelessWidget {
  const LeaderboardPage({
    super.key,
    this.isCurrentNavTab = true,
    this.isGuest = false,
  });

  final bool isCurrentNavTab;
  final bool isGuest;

  @override
  Widget build(BuildContext context) {
    return const Scaffold();
  }
}
