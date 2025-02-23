import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lichess_mobile/src/model/common/id.dart';
import 'package:lichess_mobile/src/model/tournament/tournament.dart';
import 'package:lichess_mobile/src/model/tournament/tournament_controller.dart';
import 'package:lichess_mobile/src/styles/lichess_colors.dart';
import 'package:lichess_mobile/src/styles/styles.dart';
import 'package:lichess_mobile/src/utils/l10n_context.dart';
import 'package:lichess_mobile/src/utils/navigation.dart';
import 'package:lichess_mobile/src/widgets/platform_scaffold.dart';
import 'package:lichess_mobile/src/widgets/user_full_name.dart';
import 'package:logging/logging.dart';

class TournamentScreen extends ConsumerWidget {
  const TournamentScreen({required this.id});

  final TournamentId id;

  static Route<void> buildRoute(BuildContext context, TournamentId id) {
    return buildScreenRoute(
      context,
      title: context.l10n.tournament,
      screen: TournamentScreen(id: id),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (ref.watch(tournamentControllerProvider(id))) {
      AsyncError(:final error) => Center(child: Text('Could not load tournament: $error')),
      AsyncValue(:final value?) => _Body(state: value),
      _ => const PlatformScaffold(
        appBarTitle: SizedBox.shrink(),
        body: Center(child: CircularProgressIndicator()),
      ),
    };
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.state});

  final TournamentState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PlatformScaffold(
      appBarTitle: Text(state.name),
      body: Padding(
        padding: Styles.bodySectionPadding,
        child: SingleChildScrollView(
          child: Column(children: [_Verdicts(state.tournament.verdicts)]),
        ),
      ),
    );
  }
}

class _Standings extends ConsumerWidget {
  const _Standings(this.standings);

  final StandingPage standings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SliverList.list(
      children: standings.players
          .mapIndexed((i, player) {
            final rank = (kStandingsPageSize ~/ standings.page) + i + 2;
            return GestureDetector(
              onTap: () {
                // TODO show player detail page
              },
              child: ColoredBox(
                color:
                    i.isEven
                        ? ColorScheme.of(context).surfaceContainerLow
                        : ColorScheme.of(context).surfaceContainerHigh,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            WidgetSpan(
                              child: SizedBox(
                                width: 50,
                                child: player.withdraw ? const Icon(Icons.pause) : Text('$rank.'),
                              ),
                            ),
                            WidgetSpan(
                              child: UserFullNameWidget(
                                user: player.user,
                                rating: player.rating,
                                provisional: player.provisional,
                                shouldShowOnline: false,
                                showFlair: false,
                                showPatron: false,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (player.sheet.fire) const Icon(Icons.fireplace),
                    Text('${player.score}'),
                  ],
                ),
              ),
            );
          })
          .toList(growable: false),
    );
  }
}

class _Verdicts extends StatelessWidget {
  const _Verdicts(this.verdicts);

  final Verdicts verdicts;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          verdicts.accepted ? Icons.check : Icons.lock,
          color: verdicts.accepted ? LichessColors.good : LichessColors.error,
          size: 40,
        ),
        Column(
          children: verdicts.list
              .map(
                (verdict) => Text(
                  verdict.condition,
                  style: TextStyle(color: verdict.ok ? LichessColors.good : LichessColors.error),
                ),
              )
              .toList(growable: false),
        ),
      ],
    );
  }
}
