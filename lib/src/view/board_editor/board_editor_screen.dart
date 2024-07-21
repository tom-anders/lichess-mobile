import 'package:chessground/chessground.dart' as cg;
import 'package:dartchess/dartchess.dart' as dc;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lichess_mobile/src/constants.dart';
import 'package:lichess_mobile/src/model/analysis/analysis_controller.dart';
import 'package:lichess_mobile/src/model/board_editor/board_editor_controller.dart';
import 'package:lichess_mobile/src/model/common/chess.dart';
import 'package:lichess_mobile/src/model/settings/board_preferences.dart';
import 'package:lichess_mobile/src/styles/lichess_icons.dart';
import 'package:lichess_mobile/src/styles/styles.dart';
import 'package:lichess_mobile/src/utils/l10n_context.dart';
import 'package:lichess_mobile/src/utils/navigation.dart';
import 'package:lichess_mobile/src/utils/screen.dart';
import 'package:lichess_mobile/src/utils/share.dart';
import 'package:lichess_mobile/src/view/analysis/analysis_screen.dart';
import 'package:lichess_mobile/src/view/board_editor/board_editor_settings.dart';
import 'package:lichess_mobile/src/widgets/adaptive_bottom_sheet.dart';
import 'package:lichess_mobile/src/widgets/bottom_bar_button.dart';
import 'package:lichess_mobile/src/widgets/buttons.dart';
import 'package:lichess_mobile/src/widgets/platform.dart';

class BoardEditorScreen extends StatelessWidget {
  const BoardEditorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PlatformWidget(
      androidBuilder: _androidBuilder,
      iosBuilder: _iosBuilder,
    );
  }

  Widget _androidBuilder(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.boardEditor),
        actions: [
          AppBarIconButton(
            onPressed: () => showAdaptiveBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              showDragHandle: true,
              isDismissible: true,
              builder: (_) => const BoardEditorSettings(),
            ),
            semanticsLabel: context.l10n.settingsSettings,
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
      body: const _Body(),
    );
  }

  Widget _iosBuilder(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        backgroundColor: Styles.cupertinoScaffoldColor.resolveFrom(context),
        border: null,
        middle: Text(context.l10n.boardEditor),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBarIconButton(
              onPressed: () => showAdaptiveBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                showDragHandle: true,
                isDismissible: true,
                builder: (_) => BoardEditorSettings(),
              ),
              semanticsLabel: context.l10n.settingsSettings,
              icon: const Icon(Icons.settings),
            ),
          ],
        ),
      ),
      child: const _Body(),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body();

  //cg.Side orientation = cg.Side.white;
  //
  //cg.Pieces pieces = cg.readFen(dc.kInitialBoardFEN);
  //
  //dc.Chess? position;

  @override
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.read(boardEditorControllerProvider.notifier);
    //.loadFen(dc.kInitialBoardFEN);

    final boardEditorState = ref.watch(boardEditorControllerProvider);

    //final fen = cg.writeFen(pieces);
    //final board = dc.Board.parseFen(fen);
    //
    //final dc.Chess? position;
    //try {
    //  position = dc.Chess.fromSetup(
    //    dc.Setup(
    //      board: board,
    //      unmovedRooks: dc.SquareSet.corners,
    //      turn: dc.Side.white,
    //      halfmoves: 0,
    //      fullmoves: 1,
    //    ),
    //  );
    //} catch (_) {
    //  position = null;
    //}

    return Column(
      children: [
        Expanded(
          child: SafeArea(
            bottom: false,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final aspectRatio = constraints.biggest.aspectRatio;

                final defaultBoardSize = constraints.biggest.shortestSide;
                final isTablet = isTabletOrLarger(context);
                final remainingHeight =
                    constraints.maxHeight - defaultBoardSize;
                final isSmallScreen =
                    remainingHeight < kSmallRemainingHeightLeftBoardThreshold;
                final boardSize = isTablet || isSmallScreen
                    ? defaultBoardSize - kTabletBoardTableSidePadding * 2
                    : defaultBoardSize;

                final direction =
                    aspectRatio > 1 ? Axis.horizontal : Axis.vertical;

                return Flex(
                  direction: direction,
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  mainAxisSize: MainAxisSize.max,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _BoardEditor(
                      boardSize,
                      orientation: boardEditorState.orientation,
                      isTablet: isTablet,
                      pieces: boardEditorState.pieces.unlock,
                      onDiscardedPiece: ref
                          .read(boardEditorControllerProvider.notifier)
                          .discardPiece,
                      onDroppedPiece: ref
                          .read(boardEditorControllerProvider.notifier)
                          .movePiece,
                    ),
                    Container(
                      clipBehavior: Clip.hardEdge,
                      decoration: BoxDecoration(
                        borderRadius:
                            const BorderRadius.all(Radius.circular(4.0)),
                        boxShadow: boardShadows,
                      ),
                      child: ColoredBox(
                        color: Colors.grey,
                        child: Flex(
                          direction: direction,
                          children: [
                            _PieceMenu(
                              boardSize,
                              direction: flipAxis(direction),
                              side: boardEditorState.orientation.opposite,
                            ),
                            _PieceMenu(
                              boardSize,
                              direction: flipAxis(direction),
                              side: boardEditorState.orientation,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        const _BottomBar(),
      ],
    );
  }
}

class _BoardEditor extends ConsumerWidget {
  const _BoardEditor(
    this.boardSize, {
    required this.isTablet,
    required this.orientation,
    required this.onDroppedPiece,
    required this.onDiscardedPiece,
    required this.pieces,
  });

  final double boardSize;
  final bool isTablet;
  final cg.Side orientation;
  final cg.Pieces pieces;

  final void Function(
    cg.SquareId? origin,
    cg.SquareId destination,
    cg.Piece piece,
  )? onDroppedPiece;
  final void Function(cg.SquareId square)? onDiscardedPiece;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boardPrefs = ref.watch(boardPreferencesProvider);

    return cg.BoardEditor(
      size: boardSize,
      pieces: pieces,
      orientation: orientation,
      settings: cg.BoardEditorSettings(
        pieceAssets: boardPrefs.pieceSet.assets,
        colorScheme: boardPrefs.boardTheme.colors,
        enableCoordinates: boardPrefs.coordinates,
        borderRadius: isTablet
            ? const BorderRadius.all(Radius.circular(4.0))
            : BorderRadius.zero,
        boxShadow: isTablet ? boardShadows : const <BoxShadow>[],
      ),
      onDiscardedPiece: onDiscardedPiece,
      onDroppedPiece: onDroppedPiece,
    );
  }
}

class _PieceMenu extends ConsumerStatefulWidget {
  const _PieceMenu(
    this.boardSize, {
    required this.direction,
    required this.side,
  });

  final double boardSize;

  final Axis direction;

  final cg.Side side;

  @override
  ConsumerState<_PieceMenu> createState() => _PieceMenuState();
}

class _PieceMenuState extends ConsumerState<_PieceMenu> {
  @override
  Widget build(BuildContext context) {
    final boardPrefs = ref.watch(boardPreferencesProvider);

    return Flex(
      direction: widget.direction,
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: cg.Role.values.map(
        (role) {
          final piece = cg.Piece(role: role, color: widget.side);
          final size = widget.boardSize / 8;
          final pieceWidget = cg.PieceWidget(
            piece: piece,
            size: size,
            pieceAssets: boardPrefs.pieceSet.assets,
          );

          return Draggable(
            data: cg.Piece(role: role, color: widget.side),
            feedback: Transform.translate(
              offset: const Offset(-0.5, -1.5) * size,
              child: cg.PieceWidget(
                piece: piece,
                size: 2 * size,
                pieceAssets: boardPrefs.pieceSet.assets,
              ),
            ),
            child: pieceWidget,
          );
        },
      ).toList(),
    );
  }
}

class _BottomBar extends ConsumerWidget {
  const _BottomBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pgn = ref.watch(boardEditorControllerProvider).pgn;
    final orientation = ref.read(boardEditorControllerProvider).orientation;

    return Container(
      color: Theme.of(context).platform == TargetPlatform.iOS
          ? CupertinoTheme.of(context).barBackgroundColor
          : Theme.of(context).bottomAppBarTheme.color,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: kBottomBarHeight,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Expanded(
                child: BottomBarButton(
                  label: context.l10n.flipBoard,
                  onTap: ref
                      .read(boardEditorControllerProvider.notifier)
                      .flipBoard,
                  icon: Icons.flip,
                ),
              ),
              Expanded(
                child: BottomBarButton(
                  label: context.l10n.analysis,
                  onTap: pgn != null
                      ? () {
                          pushPlatformRoute(
                            context,
                            rootNavigator: true,
                            builder: (context) => AnalysisScreen(
                              pgnOrId: pgn,
                              options: AnalysisOptions(
                                isLocalEvaluationAllowed: true,
                                variant: Variant.fromPosition,
                                orientation: (orientation == cg.Side.white)
                                    ? dc.Side.white
                                    : dc.Side.black,
                                id: standaloneAnalysisId,
                              ),
                            ),
                          );
                        }
                      : null,
                  icon: LichessIcons.microscope,
                ),
              ),
              Expanded(
                child: BottomBarButton(
                  label: context.l10n.mobileSharePositionAsFEN,
                  onTap: () => launchShareDialog(
                    context,
                    text: ref.read(boardEditorControllerProvider).fen,
                  ),
                  icon: Icons.share,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
