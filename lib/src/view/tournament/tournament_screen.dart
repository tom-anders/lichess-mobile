import 'dart:math';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lichess_mobile/src/model/common/id.dart';
import 'package:lichess_mobile/src/model/tournament/tournament.dart';
import 'package:lichess_mobile/src/model/tournament/tournament_controller.dart';
import 'package:lichess_mobile/src/styles/lichess_colors.dart';
import 'package:lichess_mobile/src/styles/lichess_icons.dart';
import 'package:lichess_mobile/src/styles/styles.dart';
import 'package:lichess_mobile/src/utils/l10n_context.dart';
import 'package:lichess_mobile/src/utils/navigation.dart';
import 'package:lichess_mobile/src/widgets/platform_scaffold.dart';
import 'package:lichess_mobile/src/widgets/user_full_name.dart';

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
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: _Verdicts(state.tournament.verdicts),
              ),
              _Standing(state),
            ],
          ),
        ),
      ),
    );
  }
}

class _Standing extends ConsumerWidget {
  const _Standing(this.state);

  final TournamentState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final standing = state.tournament.standing;
    if (standing == null) {
      return const SizedBox.shrink();
    }
    return Column(
      children: [
        ListView.builder(
          shrinkWrap: true,
          itemBuilder: (context, i) {
            final player = standing.players.getOrNull(i);
            if (player == null) {
              return null;
            }
            return GestureDetector(
              onTap: () {
                // TODO show player detail page
              },
              child: ColoredBox(
                color:
                    i.isEven
                        ? ColorScheme.of(context).surfaceContainerLow
                        : ColorScheme.of(context).surfaceContainerHigh,
                child: Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 12, right: 8, left: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              WidgetSpan(
                                child: SizedBox(
                                  width: 30,
                                  child:
                                      player.withdraw
                                          ? const Icon(
                                            Icons.pause,
                                            color: LichessColors.grey,
                                            size: 20,
                                          )
                                          : Text(
                                            '${state.firstRankOfPage + i}',
                                            textAlign: TextAlign.center,
                                          ),
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
                      if (player.sheet.fire) ...[
                        const Icon(LichessIcons.blitz, size: 17, color: LichessColors.brag),
                        const SizedBox(width: 5),
                      ],
                      Text('${player.score}'),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        _StandingControls(state: state),
      ],
    );
  }
}

class _StandingControls extends ConsumerWidget {
  const _StandingControls({required this.state});

  final TournamentState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed:
              state.hasPreviousPage
                  ? ref.read(tournamentControllerProvider(state.id).notifier).loadFirstStandingsPage
                  : null,
          icon: const Icon(Icons.first_page),
        ),
        IconButton(
          onPressed:
              state.hasPreviousPage
                  ? ref
                      .read(tournamentControllerProvider(state.id).notifier)
                      .loadPreviousStandingsPage
                  : null,
          icon: const Icon(Icons.skip_previous),
        ),
        Text(
          '${state.firstRankOfPage}-${min(state.firstRankOfPage + kStandingsPageSize - 1, state.tournament.nbPlayers)} / ${state.tournament.nbPlayers}',
        ),
        IconButton(
          onPressed:
              state.hasNextPage
                  ? ref.read(tournamentControllerProvider(state.id).notifier).loadNextStandingsPage
                  : null,
          icon: const Icon(Icons.skip_next),
        ),
        IconButton(
          onPressed:
              state.hasNextPage
                  ? ref.read(tournamentControllerProvider(state.id).notifier).loadLastStandingsPage
                  : null,
          icon: const Icon(Icons.last_page),
        ),
        if (state.tournament.me != null)
          IconButton(
            onPressed: ref.read(tournamentControllerProvider(state.id).notifier).jumpToMyPage,
            icon: const Icon(LichessIcons.target),
          ),
      ],
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
          size: 30,
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
