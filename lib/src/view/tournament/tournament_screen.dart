import 'dart:math';

import 'package:collection/collection.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lichess_mobile/src/model/auth/auth_controller.dart';
import 'package:lichess_mobile/src/model/auth/auth_session.dart';
import 'package:lichess_mobile/src/model/common/id.dart';
import 'package:lichess_mobile/src/model/game/game.dart';
import 'package:lichess_mobile/src/model/game/playable_game.dart';
import 'package:lichess_mobile/src/model/tournament/tournament.dart';
import 'package:lichess_mobile/src/model/tournament/tournament_controller.dart';
import 'package:lichess_mobile/src/model/tv/tv_channel.dart';
import 'package:lichess_mobile/src/model/tv/tv_controller.dart';
import 'package:lichess_mobile/src/styles/lichess_colors.dart';
import 'package:lichess_mobile/src/styles/lichess_icons.dart';
import 'package:lichess_mobile/src/styles/styles.dart';
import 'package:lichess_mobile/src/utils/l10n_context.dart';
import 'package:lichess_mobile/src/utils/navigation.dart';
import 'package:lichess_mobile/src/view/game/game_loading_board.dart';
import 'package:lichess_mobile/src/view/game/game_player.dart';
import 'package:lichess_mobile/src/widgets/board_table.dart';
import 'package:lichess_mobile/src/widgets/board_thumbnail.dart';
import 'package:lichess_mobile/src/widgets/bottom_bar.dart';
import 'package:lichess_mobile/src/widgets/bottom_bar_button.dart';
import 'package:lichess_mobile/src/widgets/clock.dart';
import 'package:lichess_mobile/src/widgets/platform_scaffold.dart';
import 'package:lichess_mobile/src/widgets/shimmer.dart';
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
    // open game screen if me?.gameId changes
    ref.listen(tournamentControllerProvider, (prev, next) {
      if (prev?.currentGame != next.currentGame && next.currentGame != null) {
        print('Got pairing ${next.currentGame}');
        // TODO open game screen  here
      }
    });

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
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: Styles.bodySectionPadding,
              child: SingleChildScrollView(
                child: Column(
                  spacing: 20,
                  children: [
                    _Verdicts(state.tournament.verdicts),
                    _Standing(state),
                    if (state.tournament.featuredGame != null)
                      _FeaturedGame(state.tournament.featuredGame!),
                  ],
                ),
              ),
            ),
          ),
          _BottomBar(state),
        ],
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
          padding: EdgeInsets.zero,
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

class _FeaturedGame extends ConsumerWidget {
  const _FeaturedGame(this.featuredGame);

  final FeaturedGame featuredGame;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boardSize = constraints.maxWidth;
        // TODO create a separate provider for watching the game...?
        switch (ref.watch(
          tvControllerProvider(TvChannel.best, (featuredGame.id, featuredGame.orientation)),
        )) {
          case AsyncData(:final value):
            {
              final game = value.game;
              final position = game.steps.last.position;

              final whitePlayer = _FeaturedGamePlayer(game: game, side: Side.white);

              final blackPlayer = _FeaturedGamePlayer(game: game, side: Side.black);

              return BoardThumbnail(
                size: boardSize,
                orientation: featuredGame.orientation,
                fen: position.fen,
                header: featuredGame.orientation == Side.white ? blackPlayer : whitePlayer,
                footer: featuredGame.orientation == Side.white ? whitePlayer : blackPlayer,
                lastMove: game.steps.last.sanMove?.move,
              );
            }
          case _:
            return BoardThumbnail(
              size: boardSize,
              fen: featuredGame.fen,
              orientation: featuredGame.orientation,
              header: const Shimmer(child: LoadingPlayerWidget()),
              footer: const Shimmer(child: LoadingPlayerWidget()),
            );
        }
      },
    );
  }
}

class _FeaturedGamePlayer extends StatelessWidget {
  const _FeaturedGamePlayer({super.key, required this.game, required this.side});

  final PlayableGame game;
  final Side side;

  @override
  Widget build(BuildContext context) {
    final activeClockSide = game.lastPosition.fullmoves > 1 ? game.lastPosition.turn : null;
    // TODO extend GamePlayer to display rank and berserk
    return GamePlayer(
      game: game,
      side: side,
      clock:
          game.clock != null
              ? CountdownClockBuilder(
                key: key,
                timeLeft: game.clock!.black,
                delay: game.clock!.lag ?? const Duration(milliseconds: 10),
                clockUpdatedAt: game.clock!.at,
                active: activeClockSide == side,
                builder: (context, timeLeft) {
                  return Clock(timeLeft: timeLeft, active: activeClockSide == side);
                },
              )
              : null,
    );
  }
}

class _BottomBar extends ConsumerWidget {
  const _BottomBar(this.state);

  final TournamentState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoggedIn = ref.watch(authSessionProvider)?.user.id != null;
    return PlatformBottomBar(
      children: [
        if (isLoggedIn)
          BottomBarButton(
            label: state.joined ? context.l10n.pause : context.l10n.join,
            icon: state.joined ? Icons.pause : Icons.play_arrow,
            showLabel: true,
            onTap: ref.read(tournamentControllerProvider(state.id).notifier).joinOrPause,
          )
        else
          BottomBarButton(
            label: context.l10n.signIn,
            showLabel: true,
            icon: Icons.login,
            onTap: () {
              final authController = ref.watch(authControllerProvider);

              if (!authController.isLoading) {
                ref.read(authControllerProvider.notifier).signIn();
              }
            },
          ),
      ],
    );
  }
}
