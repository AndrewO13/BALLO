import 'package:flutter/material.dart';
import '../../../../core/constants/app_assets.dart';

enum MatchInfo {
  match0(
    'Bugujju league',
    'GW11',
    'LCF',
    'GAL',
    '0',
    '0',
    '49:30',
    AppAssets.leftersLogo,
    AppAssets.galacticosLogo,
  ),
  match1(
    'Bugujju league',
    'GW11',
    'LCF',
    'LAF',
    '6',
    '1',
    'FT',
    AppAssets.leftersLogo,
    AppAssets.laFamilleLogo,
  ),
  match2(
    'Bugujju league',
    'GW11',
    'EFC',
    'GAL',
    '1',
    '2',
    'FT',
    AppAssets.dragonsLogo,
    AppAssets.galacticosLogo,
  );

  const MatchInfo(
    this.league,
    this.gameweek,
    this.team1,
    this.team2,
    this.score1,
    this.score2,
    this.time,
    this.logo1,
    this.logo2,
  );
  final String league;
  final String gameweek;
  final String team1;
  final String team2;
  final String score1;
  final String score2;
  final String time;
  final String logo1;
  final String logo2;
}

class MatchCard extends StatelessWidget {
  const MatchCard({super.key, required this.matchInfo});

  final MatchInfo matchInfo;

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return ClipRect(
      child: OverflowBox(
        maxWidth: width * 7 / 8,
        minWidth: width * 7 / 8,
        child: Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(28),
          ),
          padding: const EdgeInsetsDirectional.only(
            start: 70.0,
            end: 70.0,
            top: 16.0,
            bottom: 0.0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(matchInfo.league, style: textTheme.titleSmall),
                  Text(matchInfo.gameweek, style: textTheme.titleSmall),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        ClipOval(
                          child: Image.asset(
                            matchInfo.logo1,
                            width: 46.4,
                            height: 46.4,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          matchInfo.team1,
                          style: textTheme.bodyLarge,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            matchInfo.score1,
                            style: textTheme.displayMedium,
                          ),
                          Text(' - ', style: textTheme.displayMedium),
                          Text(
                            matchInfo.score2,
                            style: textTheme.displayMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 0,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          matchInfo.time,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSecondaryContainer,
                              ),
                        ),
                      ),
                    ],
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        ClipOval(
                          child: Image.asset(
                            matchInfo.logo2,
                            width: 46.4,
                            height: 46.4,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          matchInfo.team2,
                          style: textTheme.bodyLarge,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ActionChip(
                    label: const Text('1.8'),
                    onPressed: () {
                      // Handle betting odds click
                    },
                    backgroundColor: colorScheme.surfaceContainerHigh,
                  ),
                  ActionChip(
                    label: const Text('2.1'),
                    onPressed: () {
                      // Handle betting odds click
                    },
                    backgroundColor: colorScheme.surfaceContainerHigh,
                  ),
                  ActionChip(
                    label: const Text('1.3'),
                    onPressed: () {
                      // Handle betting odds click
                    },
                    backgroundColor: colorScheme.surfaceContainerHigh,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
