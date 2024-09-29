import 'package:dartchess/dartchess.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lichess_mobile/src/model/challenge/challenge.dart';
import 'package:lichess_mobile/src/model/common/http.dart';
import 'package:lichess_mobile/src/model/common/id.dart';
import 'package:lichess_mobile/src/model/common/time_increment.dart';
import 'package:lichess_mobile/src/model/game/archived_game.dart';
import 'package:lichess_mobile/src/model/game/game.dart';
import 'package:lichess_mobile/src/model/game/game_share_service.dart';
import 'package:lichess_mobile/src/model/lobby/game_seek.dart';
import 'package:lichess_mobile/src/utils/l10n_context.dart';
import 'package:lichess_mobile/src/utils/navigation.dart';
import 'package:lichess_mobile/src/utils/share.dart';
import 'package:lichess_mobile/src/view/game/archived_game_screen.dart';
import 'package:lichess_mobile/src/view/game/game_screen.dart';
import 'package:lichess_mobile/src/widgets/adaptive_action_sheet.dart';
import 'package:lichess_mobile/src/widgets/adaptive_bottom_sheet.dart';
import 'package:lichess_mobile/src/widgets/buttons.dart';
import 'package:lichess_mobile/src/widgets/feedback.dart';
import 'package:lichess_mobile/src/widgets/platform_scaffold.dart';

import 'game_screen_providers.dart';
import 'game_settings.dart';
import 'ping_rating.dart';

final _gameTitledateFormat = DateFormat.yMMMd();

void openGameScreen(
  LightArchivedGame game,
  Side orientation,
  BuildContext context,
) {
  if (game.variant.isReadSupported) {
    pushPlatformRoute(
      context,
      rootNavigator: true,
      builder: (context) => game.fullId != null
          ? GameScreen(initialGameId: game.fullId)
          : ArchivedGameScreen(
              gameData: game,
              orientation: orientation,
            ),
    );
  } else {
    showPlatformSnackbar(
      context,
      'This variant is not supported yet.',
      type: SnackBarType.info,
    );
  }
}

class GameAppBar extends ConsumerWidget {
  const GameAppBar({
    this.id,
    this.seek,
    this.challenge,
    this.lastMoveAt,
    super.key,
  });

  final GameSeek? seek;
  final ChallengeRequest? challenge;
  final GameFullId? id;

  /// The date of the last move played in the game. If null, the game is in progress.
  final DateTime? lastMoveAt;

  static const pingRating = Padding(
    padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 18.0),
    child: PingRating(size: 24.0),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shouldPreventGoingBackAsync = id != null
        ? ref.watch(shouldPreventGoingBackProvider(id!))
        : const AsyncValue.data(true);

    return PlatformAppBar(
      leading: shouldPreventGoingBackAsync.maybeWhen<Widget?>(
        data: (prevent) => prevent ? pingRating : null,
        orElse: () => pingRating,
      ),
      title: id != null
          ? _StandaloneGameTitle(id: id!, lastMoveAt: lastMoveAt)
          : seek != null
              ? _LobbyGameTitle(seek: seek!)
              : challenge != null
                  ? _ChallengeGameTitle(challenge: challenge!)
                  : const SizedBox.shrink(),
      actions: [
        if (id != null)
          AppBarIconButton(
            onPressed: () => showAdaptiveBottomSheet<void>(
              context: context,
              isDismissible: true,
              isScrollControlled: true,
              showDragHandle: true,
              builder: (_) => GameSettings(id: id!),
            ),
            semanticsLabel: context.l10n.settingsSettings,
            icon: const Icon(Icons.settings),
          ),
      ],
    );
  }
}

List<BottomSheetAction> makeFinishedGameShareActions(
  BaseGame game, {
  required Position currentGamePosition,
  required Side orientation,
  Move? lastMove,
  required BuildContext context,
  required WidgetRef ref,
}) {
  return [
    BottomSheetAction(
      makeLabel: (_) => Text(context.l10n.studyShareAndExport),
      dismissOnPress: true,
      onPressed: (context) {
        showAdaptiveBottomSheet<void>(
          context: context,
          useRootNavigator: true,
          isDismissible: true,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (context) => GameShareBottomSheet(
            game: game,
            currentGamePosition: currentGamePosition,
            orientation: orientation,
            lastMove: lastMove,
          ),
        );
      },
    ),
  ];
}

class GameShareBottomSheet extends ConsumerWidget {
  const GameShareBottomSheet({
    required this.game,
    required this.currentGamePosition,
    required this.orientation,
    this.lastMove,
    super.key,
  });

  final BaseGame game;
  final Position currentGamePosition;
  final Side orientation;
  final Move? lastMove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BottomSheetScrollableContainer(
      children: [
        BottomSheetContextMenuAction(
          icon: CupertinoIcons.link,
          closeOnPressed: false,
          onPressed: () {
            launchShareDialog(
              context,
              uri: lichessUri('/${game.id}'),
            );
          },
          child: Text(context.l10n.mobileShareGameURL),
        ),
        // Builder is used to retrieve the context immediately surrounding the
        // BottomSheetContextMenuAction
        // This is necessary to get the correct context for the iPad share dialog
        // which needs the position of the action to display the share dialog
        Builder(
          builder: (context) {
            return BottomSheetContextMenuAction(
              icon: Icons.gif,
              closeOnPressed: false, // needed for the share dialog on iPad
              child: Text(context.l10n.gameAsGIF),
              onPressed: () async {
                try {
                  final gif = await ref
                      .read(gameShareServiceProvider)
                      .gameGif(game.id, orientation);
                  if (context.mounted) {
                    launchShareDialog(
                      context,
                      files: [gif],
                      subject: '${game.meta.perf.title} • ${context.l10n.resVsX(
                        game.white.fullName(context),
                        game.black.fullName(context),
                      )}',
                    );
                  }
                } catch (e) {
                  debugPrint(e.toString());
                  if (context.mounted) {
                    showPlatformSnackbar(
                      context,
                      'Failed to get GIF',
                      type: SnackBarType.error,
                    );
                  }
                }
              },
            );
          },
        ),
        if (lastMove != null)
          // Builder is used to retrieve the context immediately surrounding the
          // BottomSheetContextMenuAction
          // This is necessary to get the correct context for the iPad share dialog
          // which needs the position of the action to display the share dialog
          Builder(
            builder: (context) {
              return BottomSheetContextMenuAction(
                icon: Icons.image,
                closeOnPressed: false, // needed for the share dialog on iPad
                child: Text(context.l10n.screenshotCurrentPosition),
                onPressed: () async {
                  try {
                    final image = await ref
                        .read(gameShareServiceProvider)
                        .screenshotPosition(
                          game.id,
                          orientation,
                          currentGamePosition.fen,
                          lastMove,
                        );
                    if (context.mounted) {
                      launchShareDialog(
                        context,
                        files: [image],
                        subject: context.l10n.puzzleFromGameLink(
                          lichessUri('/${game.id}').toString(),
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      showPlatformSnackbar(
                        context,
                        'Failed to get GIF',
                        type: SnackBarType.error,
                      );
                    }
                  }
                },
              );
            },
          ),
        // Builder is used to retrieve the context immediately surrounding the
        // BottomSheetContextMenuAction
        // This is necessary to get the correct context for the iPad share dialog
        // which needs the position of the action to display the share dialog
        Builder(
          builder: (context) {
            return BottomSheetContextMenuAction(
              icon: Icons.text_snippet,
              closeOnPressed: false, // needed for the share dialog on iPad
              child: Text('PGN: ${context.l10n.downloadAnnotated}'),
              onPressed: () async {
                try {
                  final pgn = await ref
                      .read(gameShareServiceProvider)
                      .annotatedPgn(game.id);
                  if (context.mounted) {
                    launchShareDialog(
                      context,
                      text: pgn,
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    showPlatformSnackbar(
                      context,
                      'Failed to get PGN',
                      type: SnackBarType.error,
                    );
                  }
                }
              },
            );
          },
        ),
        // Builder is used to retrieve the context immediately surrounding the
        // BottomSheetContextMenuAction
        // This is necessary to get the correct context for the iPad share dialog
        // which needs the position of the action to display the share dialog
        Builder(
          builder: (context) {
            return BottomSheetContextMenuAction(
              icon: Icons.text_snippet,
              closeOnPressed: false, // needed for the share dialog on iPad
              // TODO improve translation
              child: Text('PGN: ${context.l10n.downloadRaw}'),
              onPressed: () async {
                try {
                  final pgn =
                      await ref.read(gameShareServiceProvider).rawPgn(game.id);
                  if (context.mounted) {
                    launchShareDialog(
                      context,
                      text: pgn,
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    showPlatformSnackbar(
                      context,
                      'Failed to get PGN',
                      type: SnackBarType.error,
                    );
                  }
                }
              },
            );
          },
        ),
      ],
    );
  }
}

class _LobbyGameTitle extends ConsumerWidget {
  const _LobbyGameTitle({required this.seek});

  final GameSeek seek;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode =
        seek.rated ? ' • ${context.l10n.rated}' : ' • ${context.l10n.casual}';
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          seek.perf.icon,
          color: DefaultTextStyle.of(context).style.color,
        ),
        const SizedBox(width: 4.0),
        Text('${seek.timeIncrement?.display}$mode'),
      ],
    );
  }
}

class _ChallengeGameTitle extends ConsumerWidget {
  const _ChallengeGameTitle({
    required this.challenge,
  });

  final ChallengeRequest challenge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = challenge.rated
        ? ' • ${context.l10n.rated}'
        : ' • ${context.l10n.casual}';
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          challenge.perf.icon,
          color: DefaultTextStyle.of(context).style.color,
        ),
        const SizedBox(width: 4.0),
        if (challenge.timeIncrement != null)
          Text('${challenge.timeIncrement?.display}$mode')
        else if (challenge.days != null)
          Text(
            '${context.l10n.nbDays(challenge.days!)}$mode',
          ),
      ],
    );
  }
}

class _StandaloneGameTitle extends ConsumerWidget {
  const _StandaloneGameTitle({
    required this.id,
    this.lastMoveAt,
  });

  final GameFullId id;

  final DateTime? lastMoveAt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metaAsync = ref.watch(gameMetaProvider(id));
    return metaAsync.maybeWhen<Widget>(
      data: (meta) {
        final mode = meta.rated
            ? ' • ${context.l10n.rated}'
            : ' • ${context.l10n.casual}';

        final info = lastMoveAt != null
            ? ' • ${_gameTitledateFormat.format(lastMoveAt!)}'
            : mode;

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              meta.perf.icon,
              color: DefaultTextStyle.of(context).style.color,
            ),
            const SizedBox(width: 4.0),
            if (meta.clock != null)
              Text(
                '${TimeIncrement(meta.clock!.initial.inSeconds, meta.clock!.increment.inSeconds).display}$info',
              )
            else if (meta.daysPerTurn != null)
              Text(
                '${context.l10n.nbDays(meta.daysPerTurn!)}$info',
              )
            else
              Text('${meta.perf.title}$info'),
          ],
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}
